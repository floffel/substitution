#!/bin/bash
################################################################################
# Unified Test Runner for Substitution
#
# Single entry point for running all test types across all platforms.
# Automatically manages Docker infrastructure when needed.
#
# Usage:
#   ./scripts/test.sh <targets...> [options]
#
# Targets (combine multiple):
#   unit          Run unit tests (test/unit/) — no Docker needed
#   widget        Run widget tests (test/ except unit/) — no Docker needed
#   web           Run tests on Chrome (headless)
#   ios           Run integration tests on iOS simulator
#   android       Run integration tests on Android emulator
#   integration   Run integration tests on default platform
#   all           Run unit + widget + all available platforms
#
# Options:
#   --verbose                Enable verbose logging
#   --no-docker              Skip Docker service management (assume running)
#   --no-docker-cleanup      Keep Docker services running after tests
#   --no-cleanup             Keep simulator/emulator running after tests
#   --matrix-server <url>    Matrix server URL (default: http://localhost:8008)
#   --renderer <html|canvaskit>  Web renderer (default: html)
#   --device-name <name>     iOS simulator device name
#   --simulator-id <id>      iOS simulator UDID
#   --avd-name <name>        Android AVD name (default: android_test)
#   --help                   Show this help message
#
# Examples:
#   ./scripts/test.sh unit                    # Fast unit tests only
#   ./scripts/test.sh unit widget             # Unit + widget tests
#   ./scripts/test.sh web                     # Web tests with auto Docker
#   ./scripts/test.sh web --no-docker         # Web tests, Docker already running
#   ./scripts/test.sh ios --device-name "iPhone 16"
#   ./scripts/test.sh android --verbose
#   ./scripts/test.sh all                     # Everything available
#
# Environment Variables:
#   VERBOSE                 Enable verbose output (default: false)
#   MATRIX_SERVER           Matrix server URL (default: http://localhost:8008)
#   MATRIX_TEST_USER        Test user (default: testuser1)
#   MATRIX_TEST_PASSWORD    Test password (default: testpass123)
#   WEB_TEST_TIMEOUT        Web test timeout in seconds (default: 900)
#   WEB_RENDERER            Web renderer: html or canvaskit (default: html)
#   IOS_BOOT_TIMEOUT        iOS simulator boot timeout (default: 300)
#   IOS_TEST_TIMEOUT        iOS test timeout (default: 1800)
#   IOS_DEVICE_NAME         iOS simulator name
#   IOS_SIMULATOR_ID        iOS simulator UDID
#   ANDROID_BOOT_TIMEOUT    Android emulator boot timeout (default: 180)
#   ANDROID_TEST_TIMEOUT    Android test timeout (default: 600)
#   ANDROID_AVD_NAME        Android AVD name (default: android_test)
#   CHROME_EXECUTABLE       Path to Chrome/Chromium binary
################################################################################

set -o pipefail
IFS=$'\n\t'

# ---------------------------------------------------------------------------
# Bootstrap: source all library modules
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

for lib in "$SCRIPT_DIR"/lib/*.sh; do
    # shellcheck source=/dev/null
    source "$lib"
done

# ---------------------------------------------------------------------------
# Configuration (defaults, overridable via env or CLI flags)
# ---------------------------------------------------------------------------
VERBOSE="${VERBOSE:-false}"
MATRIX_SERVER="${MATRIX_SERVER:-http://localhost:8008}"
MATRIX_TEST_USER="${MATRIX_TEST_USER:-testuser1}"
MATRIX_TEST_PASSWORD="${MATRIX_TEST_PASSWORD:-testpass123}"
RESULTS_DIR="${PROJECT_ROOT}/test-results"

NO_DOCKER=false
NO_DOCKER_CLEANUP=false
NO_CLEANUP=false
DOCKER_STARTED=false

TARGETS=()

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
show_help() {
    grep '^#' "$0" | sed 's/^# \?//' | head -60
}

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            unit|widget|web|ios|android|integration|all)
                TARGETS+=("$1")
                shift
                ;;
            --verbose)
                VERBOSE="true"
                shift
                ;;
            --no-docker)
                NO_DOCKER=true
                shift
                ;;
            --no-docker-cleanup)
                NO_DOCKER_CLEANUP=true
                shift
                ;;
            --no-cleanup)
                NO_CLEANUP=true
                export KEEP_SIMULATOR=true
                export KEEP_EMULATOR=true
                shift
                ;;
            --matrix-server)
                MATRIX_SERVER="$2"
                shift 2
                ;;
            --renderer)
                WEB_RENDERER="$2"
                shift 2
                ;;
            --device-name)
                IOS_DEVICE_NAME="$2"
                shift 2
                ;;
            --simulator-id)
                IOS_SIMULATOR_ID="$2"
                shift 2
                ;;
            --avd-name)
                ANDROID_AVD_NAME="$2"
                shift 2
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                log_error "Unknown argument: $1"
                echo "Run with --help for usage."
                exit 1
                ;;
        esac
    done

    if [[ ${#TARGETS[@]} -eq 0 ]]; then
        log_error "No target specified."
        echo ""
        echo "Usage: ./scripts/test.sh <target> [options]"
        echo "Targets: unit, widget, web, ios, android, integration, all"
        echo "Run with --help for full usage."
        exit 1
    fi
}

# ---------------------------------------------------------------------------
# Expand the 'all' and 'integration' meta-targets
# ---------------------------------------------------------------------------
expand_targets() {
    local expanded=()
    local os
    os=$(detect_os)

    for target in "${TARGETS[@]}"; do
        case "$target" in
            all)
                expanded+=("unit" "widget" "web")
                # Add platform-specific targets if available
                if [[ "$os" == "darwin" ]] && command -v xcrun &>/dev/null; then
                    expanded+=("ios")
                fi
                if command -v emulator &>/dev/null || [[ -n "${ANDROID_SDK_ROOT:-}" ]]; then
                    expanded+=("android")
                fi
                ;;
            integration)
                # Pick best available platform
                if [[ "$os" == "darwin" ]] && command -v xcrun &>/dev/null; then
                    expanded+=("ios")
                elif command -v emulator &>/dev/null; then
                    expanded+=("android")
                else
                    expanded+=("web")
                fi
                ;;
            *)
                expanded+=("$target")
                ;;
        esac
    done

    # Deduplicate while preserving order
    local seen=""
    TARGETS=()
    for t in "${expanded[@]}"; do
        if [[ ":$seen:" != *":$t:"* ]]; then
            TARGETS+=("$t")
            seen="$seen:$t"
        fi
    done
}

# ---------------------------------------------------------------------------
# Determine if any target requires Docker
# ---------------------------------------------------------------------------
needs_docker() {
    for target in "${TARGETS[@]}"; do
        case "$target" in
            web|ios|android) return 0 ;;
        esac
    done
    return 1
}

# ---------------------------------------------------------------------------
# Cleanup trap
# ---------------------------------------------------------------------------
cleanup() {
    local exit_code=$?
    log_info "Cleaning up..."

    # Stop Android emulator
    if [[ "$NO_CLEANUP" != "true" ]]; then
        android_stop_emulator 2>/dev/null || true

        # Shutdown iOS simulator
        if [[ -n "${IOS_ACTIVE_SIMULATOR:-}" ]]; then
            ios_shutdown_simulator "$IOS_ACTIVE_SIMULATOR" 2>/dev/null || true
        fi
    fi

    # Kill lingering Chrome processes from web tests
    if [[ -n "${CHROME_PATH:-}" ]]; then
        pkill -f "$CHROME_PATH" 2>/dev/null || true
    fi

    # Stop virtual display
    stop_virtual_display 2>/dev/null || true

    # Stop Docker services
    if [[ "$DOCKER_STARTED" == "true" ]] && [[ "$NO_DOCKER_CLEANUP" != "true" ]]; then
        docker_stop_services 2>/dev/null || true
    fi

    log_info "Cleanup complete"
    return $exit_code
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
    parse_arguments "$@"
    expand_targets

    echo -e "${BOLD}"
    echo "  Substitution Test Runner"
    echo "  $(date +'%Y-%m-%d %H:%M:%S')"
    echo "  Targets: ${TARGETS[*]}"
    echo -e "${NC}"

    # Move to project root
    cd "$PROJECT_ROOT" || { log_error "Cannot cd to $PROJECT_ROOT"; exit 1; }

    # Validate flutter is available
    validate_flutter || exit 1

    # Fetch dependencies once
    fetch_dependencies || exit 1

    # Start Docker if needed
    if needs_docker && [[ "$NO_DOCKER" != "true" ]]; then
        docker_start_services || exit 1
        DOCKER_STARTED=true
    fi

    # Set up cleanup trap
    trap cleanup EXIT INT TERM

    # Create results directory
    mkdir -p "$RESULTS_DIR"

    # Run each target
    local overall_exit=0

    for target in "${TARGETS[@]}"; do
        case "$target" in
            unit)
                run_unit_tests || overall_exit=1
                ;;
            widget)
                run_widget_tests || overall_exit=1
                ;;
            web)
                run_web_tests || overall_exit=1
                ;;
            ios)
                run_ios_tests || overall_exit=1
                ;;
            android)
                run_android_tests || overall_exit=1
                ;;
            *)
                log_error "Unknown target: $target"
                overall_exit=1
                ;;
        esac
    done

    # Print summary
    print_summary

    return $overall_exit
}

main "$@"
exit $?
