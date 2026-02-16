#!/bin/bash
################################################################################
# Flutter Web Test Runner Script
#
# This script provides a fast CI/CD alternative for testing Flutter apps
# without requiring simulators or emulators. Web tests run in a headless
# browser environment and are significantly faster than mobile platforms.
#
# Features:
# - Fast execution (10-15 minutes vs 25-35 min for iOS/Android)
# - No simulator/emulator setup required
# - Cross-platform (runs on macOS, Linux, Windows with WSL)
# - Integrates with Matrix test server
# - Detailed result reporting
#
# Usage: ./scripts/run-web-tests.sh [OPTIONS]
#
# Options:
#   --renderer <html|canvaskit>  Use specific web renderer (default: html)
#   --chrome-path <path>         Path to Chrome/Chromium binary
#   --headless                   Run in headless mode (default: true)
#   --no-cleanup                 Keep browser process running after tests
#   --verbose                    Enable verbose logging
#   --matrix-server <url>        Matrix server URL (default: http://localhost:8008)
#   --port <port>                Web server port (default: auto)
#   --help                       Show this help message
#
# Environment Variables:
#   WEB_TEST_TIMEOUT            - Test execution timeout (default: 900s = 15 min)
#   WEB_RENDERER                - Web renderer to use (default: html)
#   CHROME_EXECUTABLE           - Path to Chrome/Chromium binary
#   MATRIX_SERVER               - Matrix server URL (default: http://localhost:8008)
#   MATRIX_TEST_USER            - Test user name (default: testuser1)
#   MATRIX_TEST_PASSWORD        - Test user password (default: testpass123)
#   HEADLESS                    - Run in headless mode (default: true)
#   VERBOSE                     - Enable verbose logging (default: false)
#
# Exit Codes:
#   0  - Tests passed
#   1  - Tests failed
#   2  - Chrome/Chromium not found
#   3  - Environment validation failed
#   4  - Test timeout
#   5  - Setup failed
#
################################################################################

set -o pipefail
IFS=$'\n\t'

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${PROJECT_ROOT:-.}"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}ℹ${NC} $*"
}

log_success() {
    echo -e "${GREEN}✓${NC} $*"
}

log_error() {
    echo -e "${RED}✗${NC} $*" >&2
}

log_warn() {
    echo -e "${YELLOW}⚠${NC} $*"
}

log_debug() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "${BLUE}◇${NC} $*"
    fi
}

# Configuration
WEB_TEST_TIMEOUT="${WEB_TEST_TIMEOUT:-900}"
WEB_RENDERER="${WEB_RENDERER:-html}"
CHROME_EXECUTABLE="${CHROME_EXECUTABLE:-}"
HEADLESS="${HEADLESS:-true}"
MATRIX_SERVER="${MATRIX_SERVER:-http://localhost:8008}"
MATRIX_TEST_USER="${MATRIX_TEST_USER:-testuser1}"
MATRIX_TEST_PASSWORD="${MATRIX_TEST_PASSWORD:-testpass123}"
VERBOSE="${VERBOSE:-false}"
PORT=""
RESULTS_DIR="${PROJECT_ROOT}/test-results"
CHROME_PATH=""
TEST_START_TIME=""
TEST_END_TIME=""

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --renderer)
                WEB_RENDERER="$2"
                shift 2
                ;;
            --chrome-path)
                CHROME_EXECUTABLE="$2"
                shift 2
                ;;
            --headless)
                HEADLESS="true"
                shift
                ;;
            --no-headless)
                HEADLESS="false"
                shift
                ;;
            --no-cleanup)
                # Note: Currently not used for web tests (browsers auto-cleanup)
                shift
                ;;
            --verbose)
                VERBOSE="true"
                shift
                ;;
            --matrix-server)
                MATRIX_SERVER="$2"
                shift 2
                ;;
            --port)
                PORT="$2"
                shift 2
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# Show help message
show_help() {
    grep "^#" "$0" | head -50
}

# Find Chrome/Chromium executable
find_chrome() {
    log_info "Looking for Chrome/Chromium..."
    
    # If CHROME_EXECUTABLE is explicitly set, use it
    if [[ -n "$CHROME_EXECUTABLE" ]] && [[ -x "$CHROME_EXECUTABLE" ]]; then
        log_debug "Using Chrome at: $CHROME_EXECUTABLE"
        echo "$CHROME_EXECUTABLE"
        return 0
    fi
    
    # Search for Chrome/Chromium in common locations
    local chrome_candidates=(
        # macOS
        "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
        "/Applications/Chromium.app/Contents/MacOS/Chromium"
        
        # Linux
        "/usr/bin/google-chrome"
        "/usr/bin/google-chrome-stable"
        "/usr/bin/chromium-browser"
        "/usr/bin/chromium"
        "/snap/bin/chromium"
        
        # Windows/WSL
        "/mnt/c/Program Files/Google/Chrome/Application/chrome.exe"
        "/mnt/c/Program Files (x86)/Google/Chrome/Application/chrome.exe"
        
        # Common alternative paths
        "/opt/google/chrome/google-chrome"
        "/usr/local/bin/chrome"
        "/usr/local/bin/chromium"
    )
    
    for candidate in "${chrome_candidates[@]}"; do
        if [[ -x "$candidate" ]]; then
            log_debug "Found Chrome: $candidate"
            echo "$candidate"
            return 0
        fi
    done
    
    # Try to find via 'which' command
    if command -v google-chrome &>/dev/null; then
        local which_result=$(command -v google-chrome)
        log_debug "Found Chrome via which: $which_result"
        echo "$which_result"
        return 0
    fi
    
    if command -v chromium-browser &>/dev/null; then
        local which_result=$(command -v chromium-browser)
        log_debug "Found Chromium via which: $which_result"
        echo "$which_result"
        return 0
    fi
    
    if command -v chromium &>/dev/null; then
        local which_result=$(command -v chromium)
        log_debug "Found Chromium via which: $which_result"
        echo "$which_result"
        return 0
    fi
    
    return 1
}

# Validate Chrome is available and functional
validate_chrome() {
    log_info "Validating Chrome/Chromium..."
    
    if ! CHROME_PATH=$(find_chrome); then
        log_error "Chrome or Chromium not found!"
        log_info ""
        log_info "To fix this, install one of the following:"
        log_info "  macOS:   brew install google-chrome"
        log_info "  Ubuntu:  sudo apt-get install chromium-browser"
        log_info "  Fedora:  sudo dnf install chromium"
        log_info "  Arch:    sudo pacman -S chromium"
        log_info ""
        log_info "Or set CHROME_EXECUTABLE=/path/to/chrome"
        return 2
    fi
    
    log_success "Chrome found at: $CHROME_PATH"
    
    # Test Chrome version
    local chrome_version=$("$CHROME_PATH" --version 2>/dev/null || echo "unknown")
    log_info "Chrome version: $chrome_version"
    
    # Test Chrome responsiveness
    log_debug "Testing Chrome responsiveness..."
    if ! timeout 5 "$CHROME_PATH" --version > /dev/null 2>&1; then
        log_error "Chrome failed responsiveness test"
        return 2
    fi
    
    log_success "Chrome validation passed"
    return 0
}

# Validate environment
validate_environment() {
    log_info "Validating environment..."
    
    local errors=0
    
    # Check for Flutter
    if ! command -v flutter &>/dev/null; then
        log_error "flutter not found in PATH"
        ((errors++))
    else
        log_success "Flutter found"
    fi
    
    # Check for web platform support
    log_debug "Checking Flutter web support..."
    if ! flutter config --list 2>/dev/null | grep -q "web"; then
        log_warn "Web platform may not be enabled"
        log_info "Attempting to enable web platform..."
        flutter config --enable-web 2>/dev/null || true
    fi
    
    # Validate Chrome
    if ! validate_chrome; then
        ((errors++))
    fi
    
    # Validate web renderer
    if [[ ! "$WEB_RENDERER" =~ ^(html|canvaskit)$ ]]; then
        log_error "Invalid web renderer: $WEB_RENDERER (must be 'html' or 'canvaskit')"
        ((errors++))
    fi
    
    if [[ $errors -gt 0 ]]; then
        log_error "Environment validation failed with $errors errors"
        return 3
    fi
    
    log_success "Environment validation passed"
    return 0
}

# Check Matrix server connectivity
check_matrix_server() {
    log_info "Checking Matrix server: $MATRIX_SERVER"
    
    local max_retries=10
    local retry=0
    
    while [[ $retry -lt $max_retries ]]; do
        if curl -sf "$MATRIX_SERVER/_matrix/client/versions" > /dev/null 2>&1; then
            log_success "Matrix server is accessible"
            return 0
        fi
        
        ((retry++))
        if [[ $retry -lt $max_retries ]]; then
            log_debug "Retrying Matrix server check... ($retry/$max_retries)"
            sleep 2
        fi
    done
    
    log_warn "Matrix server not accessible at $MATRIX_SERVER"
    log_info "Make sure Matrix server is running: docker-compose up"
    log_info "Tests will continue but may fail if server connectivity is required"
    return 0
}

# Fetch Flutter dependencies
fetch_dependencies() {
    log_info "Fetching Flutter dependencies..."
    
    cd "$PROJECT_ROOT" || {
        log_error "Failed to change to project directory: $PROJECT_ROOT"
        return 5
    }
    
    if ! flutter pub get 2>&1 | tail -5; then
        log_error "Failed to fetch dependencies"
        return 5
    fi
    
    log_success "Dependencies fetched"
    return 0
}

# Run Flutter web tests
run_web_tests() {
    log_info "Running Flutter web integration tests..."
    log_info "Configuration:"
    log_info "  Renderer: $WEB_RENDERER"
    log_info "  Browser: $CHROME_PATH"
    log_info "  Headless: $HEADLESS"
    log_info "  Timeout: ${WEB_TEST_TIMEOUT}s"
    log_info ""
    
    mkdir -p "$RESULTS_DIR"
    
    local test_result_file="$RESULTS_DIR/web-test-results.txt"
    local test_json_file="$RESULTS_DIR/web-test-results.json"
    local test_log_file="$RESULTS_DIR/web-test.log"
    
    cd "$PROJECT_ROOT" || {
        log_error "Failed to change to project directory: $PROJECT_ROOT"
        return 5
    }
    
    # Set environment variables for tests
    export MATRIX_SERVER="$MATRIX_SERVER"
    export MATRIX_TEST_USER="$MATRIX_TEST_USER"
    export MATRIX_TEST_PASSWORD="$MATRIX_TEST_PASSWORD"
    export CHROME_EXECUTABLE="$CHROME_PATH"
    
    # Build test command
    local test_args=(
        "test"
        "integration_test/"
        "--device-id=web"
        "--web-renderer=$WEB_RENDERER"
        "--verbose"
        "--dart-define=MATRIX_SERVER=$MATRIX_SERVER"
        "--dart-define=MATRIX_TEST_USER=$MATRIX_TEST_USER"
        "--dart-define=MATRIX_TEST_PASSWORD=$MATRIX_TEST_PASSWORD"
    )
    
    # Add chrome path if needed
    if [[ -n "$CHROME_PATH" ]]; then
        test_args+=("--dart-define=CHROME_EXECUTABLE=$CHROME_PATH")
    fi
    
    log_debug "Test command: flutter ${test_args[*]}"
    log_info "Environment: MATRIX_SERVER=$MATRIX_SERVER"
    log_info ""
    log_info "═══════════════════════════════════════════════════════════"
    log_info "Test Output:"
    log_info "═══════════════════════════════════════════════════════════"
    
    # Run tests with timeout and capture output
    TEST_START_TIME=$(date +%s)
    
    if timeout $((WEB_TEST_TIMEOUT + 60)) flutter "${test_args[@]}" 2>&1 | tee "$test_log_file"; then
        local test_exit_code=0
    else
        local test_exit_code=$?
        if [[ $test_exit_code -eq 124 ]]; then
            log_error "Test execution timed out after ${WEB_TEST_TIMEOUT}s"
            test_exit_code=4
        fi
    fi
    
    TEST_END_TIME=$(date +%s)
    
    # Copy to results file for parsing
    cp "$test_log_file" "$test_result_file"
    
    # Parse and display results
    log_info "═══════════════════════════════════════════════════════════"
    parse_test_results "$test_result_file" "$test_log_file"
    
    return $test_exit_code
}

# Parse and display test results
parse_test_results() {
    local result_file="$1"
    local log_file="$2"
    
    if [[ ! -f "$result_file" ]]; then
        log_warn "Test result file not found: $result_file"
        return 0
    fi
    
    local test_duration=$((TEST_END_TIME - TEST_START_TIME))
    
    log_info "Test Results Summary:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Count test results
    local total_tests=0
    local passed=0
    local failed=0
    local skipped=0
    
    # Try to extract counts from flutter test output
    if grep -q "passed\|failed" "$result_file"; then
        local summary=$(grep -E "[0-9]+ passed" "$result_file" | tail -1)
        if [[ -n "$summary" ]]; then
            passed=$(echo "$summary" | grep -oE "[0-9]+ passed" | grep -oE "[0-9]+")
            failed=$(echo "$summary" | grep -oE "[0-9]+ failed" | grep -oE "[0-9]+" || echo "0")
            skipped=$(echo "$summary" | grep -oE "[0-9]+ skipped" | grep -oE "[0-9]+" || echo "0")
            total_tests=$((passed + failed + skipped))
        fi
    fi
    
    # Fallback: count test file executions
    if [[ $total_tests -eq 0 ]]; then
        total_tests=$(grep -c "^[0-9]*:[0-9]* [+-] " "$result_file" 2>/dev/null || echo "0")
    fi
    
    # Display results
    printf "Total Tests:    %d\n" "$total_tests"
    if [[ $passed -gt 0 ]]; then
        printf "Passed:         %d %s\n" "$passed" "✓"
    fi
    if [[ $failed -gt 0 ]]; then
        printf "Failed:         %d %s\n" "$failed" "✗"
    fi
    if [[ $skipped -gt 0 ]]; then
        printf "Skipped:        %d\n" "$skipped"
    fi
    
    if [[ $test_duration -gt 0 ]]; then
        local minutes=$((test_duration / 60))
        local seconds=$((test_duration % 60))
        printf "Duration:       %dm %ds\n" "$minutes" "$seconds"
    fi
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Show last 50 lines of test output
    log_info "Last 50 lines of test output:"
    echo "---"
    tail -50 "$result_file"
    echo "---"
    
    # Show summary statistics
    log_info "Test Statistics:"
    echo "Result file:    $result_file"
    echo "Log file:       $log_file"
    
    return 0
}

# Cleanup function
cleanup() {
    local exit_code=$?
    log_info "Cleaning up..."
    
    # Kill any lingering Chrome processes (if they exist)
    if pkill -f "$CHROME_PATH" 2>/dev/null; then
        log_debug "Chrome processes cleaned up"
    fi
    
    log_info "Cleanup complete"
    return $exit_code
}

# Set trap for cleanup
trap cleanup EXIT INT TERM

# Main execution
main() {
    log_info "╔════════════════════════════════════════════════════════╗"
    log_info "║     Flutter Web Test Runner                            ║"
    log_info "║     $(date +"%Y-%m-%d %H:%M:%S")                            ║"
    log_info "╚════════════════════════════════════════════════════════╝"
    log_info ""
    
    # Parse arguments
    parse_arguments "$@"
    
    # Validate environment
    if ! validate_environment; then
        return $?
    fi
    
    log_info ""
    
    # Check Matrix server
    check_matrix_server
    
    log_info ""
    
    # Fetch dependencies
    if ! fetch_dependencies; then
        return $?
    fi
    
    log_info ""
    
    # Run tests
    if ! run_web_tests; then
        local test_exit_code=$?
        log_error "Tests failed with exit code: $test_exit_code"
        return $test_exit_code
    fi
    
    log_info ""
    log_success "Web tests completed successfully!"
    return 0
}

# Run main function with arguments
main "$@"
exit $?
