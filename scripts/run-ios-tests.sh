#!/bin/bash
################################################################################
# iOS Simulator Test Runner Script
#
# This script:
# 1. Checks for available iOS simulators (iPhone 15 or latest)
# 2. Boots the iOS simulator
# 3. Waits for simulator to fully boot and become responsive
# 4. Starts the Matrix test server (if not running)
# 5. Runs Flutter integration tests on the simulator
# 6. Captures and reports results
# 7. Cleans up gracefully on exit
#
# Usage: ./scripts/run-ios-tests.sh [OPTIONS]
#
# Options:
#   --device-name <name>    Use specific device (e.g., "iPhone 15")
#   --simulator-id <id>     Use specific simulator UDID
#   --no-cleanup            Keep simulator running after tests
#   --verbose               Enable verbose logging
#   --matrix-server <url>   Matrix server URL (default: http://localhost:8008)
#   --help                  Show this help message
#
# Environment Variables:
#   IOS_DEVICE_TIMEOUT      - Simulator boot timeout (default: 300s)
#   TEST_TIMEOUT            - Flutter test timeout (default: 1800s = 30 min)
#   MATRIX_SERVER           - Matrix server URL (default: http://localhost:8008)
#   MATRIX_TEST_USER        - Test user name (default: testuser1)
#   MATRIX_TEST_PASSWORD    - Test user password (default: testpass123)
#   KEEP_SIMULATOR          - Keep simulator running (default: false)
#   VERBOSE                 - Enable verbose logging (default: false)
################################################################################

set -o pipefail
IFS=$'\n\t'

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${PROJECT_ROOT:-.}"

# Source utility functions
if [[ ! -f "$SCRIPT_DIR/ios-simulator-utils.sh" ]]; then
    echo "ERROR: iOS simulator utilities not found: $SCRIPT_DIR/ios-simulator-utils.sh"
    exit 1
fi
source "$SCRIPT_DIR/ios-simulator-utils.sh"

# Configuration
IOS_DEVICE_TIMEOUT="${IOS_DEVICE_TIMEOUT:-300}"
TEST_TIMEOUT="${TEST_TIMEOUT:-1800}"
MATRIX_SERVER="${MATRIX_SERVER:-http://localhost:8008}"
MATRIX_TEST_USER="${MATRIX_TEST_USER:-testuser1}"
MATRIX_TEST_PASSWORD="${MATRIX_TEST_PASSWORD:-testpass123}"
KEEP_SIMULATOR="${KEEP_SIMULATOR:-false}"
VERBOSE="${VERBOSE:-false}"
DEVICE_NAME=""
SIMULATOR_ID=""
RESULTS_DIR="${PROJECT_ROOT}/test-results"

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --device-name)
                DEVICE_NAME="$2"
                shift 2
                ;;
            --simulator-id)
                SIMULATOR_ID="$2"
                shift 2
                ;;
            --no-cleanup)
                KEEP_SIMULATOR="true"
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
    grep "^#" "$0" | head -45
}

# Cleanup function
cleanup() {
    local exit_code=$?
    log_info "Cleaning up..."
    
    # Stop simulator if running (unless KEEP_SIMULATOR is true)
    if [[ "$KEEP_SIMULATOR" != "true" ]] && [[ -n "$SIMULATOR_ID" ]]; then
        log_info "Stopping simulator..."
        shutdown_simulator "$SIMULATOR_ID" 2>/dev/null || true
    fi
    
    log_info "Cleanup complete"
    return $exit_code
}

# Set trap for cleanup
trap cleanup EXIT INT TERM

# Validate environment
validate_environment() {
    log_info "Validating environment..."
    
    local errors=0
    
    # Check for Xcode tools
    if ! check_xcode; then
        ((errors++))
    fi
    
    # Check for Flutter
    if ! command -v flutter &> /dev/null; then
        log_error "flutter not found in PATH"
        ((errors++))
    fi
    
    # Check for iOS development files
    if ! xcode-select -p &>/dev/null; then
        log_error "Xcode developer path not set"
        log_info "Run: sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer"
        ((errors++))
    fi
    
    if [[ $errors -gt 0 ]]; then
        log_error "Environment validation failed with $errors errors"
        return 1
    fi
    
    log_success "Environment validation passed"
    return 0
}

# Setup simulator
setup_simulator() {
    log_info "Setting up iOS simulator..."
    
    # Determine which simulator to use
    if [[ -n "$SIMULATOR_ID" ]]; then
        log_info "Using specified simulator: $SIMULATOR_ID"
    elif [[ -n "$DEVICE_NAME" ]]; then
        log_info "Looking for simulator: $DEVICE_NAME"
        if ! SIMULATOR_ID=$(get_simulator_id_by_name "$DEVICE_NAME"); then
            log_error "Failed to find simulator: $DEVICE_NAME"
            list_simulators
            return 1
        fi
        log_success "Found simulator: $SIMULATOR_ID"
    else
        log_info "Looking for latest iPhone simulator..."
        if ! SIMULATOR_ID=$(find_latest_iphone_simulator); then
            log_error "No iPhone simulators available"
            list_simulators
            return 1
        fi
        log_success "Found simulator: $SIMULATOR_ID"
    fi
    
    # Display available simulators
    log_debug "Available simulators:"
    list_simulators | head -10
    
    return 0
}

# Check Matrix server connectivity
check_matrix_server() {
    log_info "Checking Matrix server connectivity: $MATRIX_SERVER"
    
    local max_retries=10
    local retry=0
    
    while [[ $retry -lt $max_retries ]]; do
        if curl -sf "$MATRIX_SERVER/_matrix/client/versions" > /dev/null 2>&1; then
            log_success "Matrix server is accessible"
            return 0
        fi
        
        ((retry++))
        if [[ $retry -lt $max_retries ]]; then
            log_info "Retrying... ($retry/$max_retries)"
            sleep 2
        fi
    done
    
    log_warn "Matrix server not accessible at $MATRIX_SERVER"
    log_info "Make sure the Matrix server is running (docker-compose up)"
    log_info "Tests will continue but may fail if server connectivity is required"
    return 0
}

# Boot simulator and wait for readiness
boot_and_wait() {
    log_info "Booting simulator (timeout: ${IOS_DEVICE_TIMEOUT}s)..."
    
    # Boot simulator
    if ! boot_simulator "$SIMULATOR_ID" "$IOS_DEVICE_TIMEOUT"; then
        log_error "Failed to boot simulator"
        return 1
    fi
    
    # Wait for simulator to be fully responsive
    log_info "Waiting for simulator to be fully responsive..."
    
    local start_time=$(date +%s)
    local timeout=60
    local elapsed=0
    
    while [[ $elapsed -lt $timeout ]]; do
        # Try to get system information to verify simulator is responsive
        if xcrun simctl status_bar "$SIMULATOR_ID" show 2>/dev/null; then
            log_success "Simulator is fully responsive"
            sleep 2
            return 0
        fi
        
        elapsed=$(($(date +%s) - start_time))
        log_debug "Waiting for simulator responsiveness... ($elapsed/$timeout)s"
        sleep 2
    done
    
    log_warn "Simulator may not be fully responsive (continuing anyway)"
    return 0
}

# Run Flutter integration tests
run_tests() {
    log_info "Running Flutter integration tests..."
    
    mkdir -p "$RESULTS_DIR"
    
    local test_result_file="$RESULTS_DIR/ios-test-results.txt"
    local device_info_file="$RESULTS_DIR/ios-device-info.txt"
    
    cd "$PROJECT_ROOT" || {
        log_error "Failed to change to project directory: $PROJECT_ROOT"
        return 1
    }
    
    # Get device information
    log_info "Capturing device information..."
    {
        echo "Simulator ID: $SIMULATOR_ID"
        echo "Test started: $(date)"
        echo "Matrix server: $MATRIX_SERVER"
        echo "---"
        xcrun simctl list devices --json | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    devices = data.get('devices', {})
    search_id = '$SIMULATOR_ID'
    for runtime, sims in devices.items():
        for sim in sims:
            if sim['udid'] == search_id:
                print(f'Runtime: {runtime}')
                print(f'Name: {sim[\"name\"]}')
                print(f'Availability: {\"Available\" if sim[\"isAvailable\"] else \"Not Available\"}')
                break
except:
    pass
" 2>/dev/null || true
    } | tee "$device_info_file"
    
    # Fetch dependencies
    log_info "Fetching Flutter dependencies..."
    if ! flutter pub get 2>&1 | tail -10; then
        log_error "Failed to fetch dependencies"
        return 1
    fi
    
    # Run integration tests
    log_info "Starting integration tests (timeout: ${TEST_TIMEOUT}s)..."
    
    local test_args=(
        "test"
        "integration_test/"
        "--device-id=$SIMULATOR_ID"
        "--verbose"
        "--timeout=${TEST_TIMEOUT}s"
        "--dart-define=MATRIX_SERVER=$MATRIX_SERVER"
        "--dart-define=MATRIX_TEST_USER=$MATRIX_TEST_USER"
        "--dart-define=MATRIX_TEST_PASSWORD=$MATRIX_TEST_PASSWORD"
    )
    
    # Set environment variables for tests
    export MATRIX_SERVER="$MATRIX_SERVER"
    export MATRIX_TEST_USER="$MATRIX_TEST_USER"
    export MATRIX_TEST_PASSWORD="$MATRIX_TEST_PASSWORD"
    
    log_debug "Test command: flutter ${test_args[*]}"
    log_info "Environment: MATRIX_SERVER=$MATRIX_SERVER, MATRIX_TEST_USER=$MATRIX_TEST_USER"
    
    # Run tests with timeout
    local test_start=$(date +%s)
    
    if timeout $((TEST_TIMEOUT + 60)) flutter "${test_args[@]}" 2>&1 | tee "$test_result_file"; then
        local test_exit_code=${PIPESTATUS[0]}
    else
        local test_exit_code=$?
    fi
    
    local test_end=$(date +%s)
    local test_duration=$((test_end - test_start))
    
    # Parse and display results
    parse_test_results "$test_result_file" "$test_duration"
    
    return $test_exit_code
}

# Parse and display test results
parse_test_results() {
    local result_file="$1"
    local duration="${2:-0}"
    
    if [[ ! -f "$result_file" ]]; then
        log_warn "Test result file not found: $result_file"
        return 0
    fi
    
    log_info "Test Results Summary:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Count test results using safer patterns
    local total_tests=0
    local passed=0
    local failed=0
    
    # Try to extract counts from flutter test output
    if grep -q "passed\|failed" "$result_file"; then
        # Look for the summary line: "X passed, Y failed in Z seconds"
        local summary=$(grep -E "[0-9]+ passed" "$result_file" | tail -1)
        if [[ -n "$summary" ]]; then
            passed=$(echo "$summary" | grep -oE "[0-9]+ passed" | grep -oE "[0-9]+")
            failed=$(echo "$summary" | grep -oE "[0-9]+ failed" | grep -oE "[0-9]+" || echo "0")
            total_tests=$((passed + failed))
        fi
    fi
    
    # Fallback: count test file executions
    if [[ $total_tests -eq 0 ]]; then
        total_tests=$(grep -c "^[0-9]*:[0-9]* [+-] " "$result_file" 2>/dev/null || echo "0")
    fi
    
    echo "Total Tests:    $total_tests"
    echo "Passed:         $passed ✓"
    echo "Failed:         $failed ✗"
    
    if [[ $duration -gt 0 ]]; then
        local minutes=$((duration / 60))
        local seconds=$((duration % 60))
        echo "Duration:       ${minutes}m ${seconds}s"
    fi
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Show last 40 lines of test output
    log_info "Last 40 lines of test output:"
    echo "---"
    tail -40 "$result_file"
    echo "---"
    
    return 0
}

# Main execution
main() {
    log_info "╔════════════════════════════════════════════════════════╗"
    log_info "║     iOS Simulator Test Runner                          ║"
    log_info "║     $(date +"%Y-%m-%d %H:%M:%S")                            ║"
    log_info "╚════════════════════════════════════════════════════════╝"
    
    # Parse arguments
    parse_arguments "$@"
    
    # Validate environment
    if ! validate_environment; then
        log_error "Environment validation failed"
        return 1
    fi
    
    # Setup simulator
    if ! setup_simulator; then
        log_error "Failed to setup simulator"
        return 1
    fi
    
    # Check Matrix server
    check_matrix_server
    
    # Boot simulator
    if ! boot_and_wait; then
        log_error "Failed to boot simulator"
        return 1
    fi
    
    # Run tests
    if ! run_tests; then
        local test_exit_code=$?
        log_error "Tests failed with exit code: $test_exit_code"
        return $test_exit_code
    fi
    
    log_success "All tests completed successfully!"
    return 0
}

# Run main function with arguments
main "$@"
exit $?
