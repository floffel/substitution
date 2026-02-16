#!/bin/bash
################################################################################
# Android Emulator Test Runner Script
#
# This script:
# 1. Starts the Android emulator in headless mode
# 2. Waits for the emulator to fully boot
# 3. Runs Flutter integration tests
# 4. Captures and reports results
# 5. Cleans up gracefully on exit
#
# Usage: ./scripts/run-android-tests.sh [OPTIONS]
# 
# Environment Variables:
#   ANDROID_DEVICE_TIMEOUT  - Emulator boot timeout (default: 300s)
#   EMULATOR_BOOT_TIMEOUT   - Max time waiting for boot completion (default: 180s)
#   TEST_TIMEOUT            - Flutter test timeout (default: 600s)
#   MATRIX_SERVER           - Matrix server URL for tests (default: http://localhost:8008)
#   KEEP_EMULATOR           - Keep emulator running after tests (default: false)
#   VERBOSE                 - Verbose logging (default: false)
################################################################################

set -o pipefail
IFS=$'\n\t'

# Configuration
ANDROID_DEVICE_TIMEOUT="${ANDROID_DEVICE_TIMEOUT:-300}"
EMULATOR_BOOT_TIMEOUT="${EMULATOR_BOOT_TIMEOUT:-180}"
TEST_TIMEOUT="${TEST_TIMEOUT:-600}"
MATRIX_SERVER="${MATRIX_SERVER:-http://localhost:8008}"
KEEP_EMULATOR="${KEEP_EMULATOR:-false}"
VERBOSE="${VERBOSE:-false}"

# Derived configuration
ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-/opt/android-sdk}"
ANDROID_HOME="${ANDROID_HOME:-$ANDROID_SDK_ROOT}"
EMULATOR_DEVICE_ID="emulator-5554"
AVD_NAME="android_test"
PROJECT_ROOT="${PROJECT_ROOT:-.}"
RESULTS_DIR="${PROJECT_ROOT}/test-results"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

# Verbose logging
log_debug() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "${BLUE}[DEBUG]${NC} $*"
    fi
}

# Cleanup function
cleanup() {
    local exit_code=$?
    log_info "Cleaning up..."
    
    # Kill emulator if running (unless KEEP_EMULATOR is true)
    if [[ "$KEEP_EMULATOR" != "true" ]]; then
        if pgrep -x "emulator" > /dev/null; then
            log_info "Stopping emulator..."
            adb -s $EMULATOR_DEVICE_ID emu kill 2>/dev/null || \
            pkill -f emulator || true
            sleep 2
        fi
    fi
    
    # Kill adb server
    log_debug "Killing adb server..."
    adb kill-server 2>/dev/null || true
    
    # Kill xvfb if running (fallback display)
    pkill -f Xvfb || true
    
    log_info "Cleanup complete"
    return $exit_code
}

# Set trap for cleanup
trap cleanup EXIT INT TERM

# Start xvfb virtual display (fallback if needed)
start_virtual_display() {
    if [[ -z "$DISPLAY" ]]; then
        log_info "Starting Xvfb virtual display..."
        Xvfb :99 -screen 0 1280x720x24 -ac -retro &
        export DISPLAY=:99
        sleep 2
    fi
}

# Validate environment
validate_environment() {
    log_info "Validating environment..."
    
    local errors=0
    
    if ! command -v emulator &> /dev/null; then
        log_error "emulator not found in PATH"
        ((errors++))
    fi
    
    if ! command -v adb &> /dev/null; then
        log_error "adb not found in PATH"
        ((errors++))
    fi
    
    if ! command -v flutter &> /dev/null; then
        log_error "flutter not found in PATH"
        ((errors++))
    fi
    
    if ! command -v java &> /dev/null; then
        log_error "java not found in PATH"
        ((errors++))
    fi
    
    if [[ ! -d "$ANDROID_SDK_ROOT" ]]; then
        log_error "ANDROID_SDK_ROOT not found: $ANDROID_SDK_ROOT"
        ((errors++))
    fi
    
    if [[ $errors -gt 0 ]]; then
        log_error "Environment validation failed with $errors errors"
        return 1
    fi
    
    log_success "Environment validation passed"
    return 0
}

# Start emulator
start_emulator() {
    log_info "Starting Android emulator ($AVD_NAME)..."
    
    # Kill any existing emulator processes
    pkill -f emulator || true
    sleep 1
    
    # Start emulator in headless mode with no graphics
    # -no-window: Run in headless mode
    # -no-audio: Disable audio
    # -accel off: Disable acceleration (for nested virtualization compatibility)
    # -prop persist.sys.usb.config=adb: Enable ADB
    log_debug "Emulator command: emulator -avd $AVD_NAME -no-window -no-audio -accel off -prop persist.sys.usb.config=adb"
    
    # Try with KVM first if available
    if [[ -c /dev/kvm ]]; then
        log_info "KVM device detected, using KVM acceleration..."
        emulator -avd $AVD_NAME \
            -no-window \
            -no-audio \
            -accel on \
            -prop persist.sys.usb.config=adb \
            -prop persist.sys.dalvik.vm.heapsize=512m \
            -qemu -enable-kvm \
            2>&1 | tee /tmp/emulator.log &
    else
        log_warn "KVM device not available, using software emulation..."
        emulator -avd $AVD_NAME \
            -no-window \
            -no-audio \
            -accel off \
            -prop persist.sys.usb.config=adb \
            -prop persist.sys.dalvik.vm.heapsize=512m \
            2>&1 | tee /tmp/emulator.log &
    fi
    
    EMULATOR_PID=$!
    log_info "Emulator started with PID $EMULATOR_PID"
    
    # Validate emulator started
    sleep 3
    if ! kill -0 $EMULATOR_PID 2>/dev/null; then
        log_error "Emulator failed to start"
        cat /tmp/emulator.log
        return 1
    fi
    
    log_success "Emulator process started successfully"
    return 0
}

# Wait for emulator to be ready
wait_for_emulator() {
    log_info "Waiting for emulator to boot (timeout: ${EMULATOR_BOOT_TIMEOUT}s)..."
    
    local start_time=$(date +%s)
    local timeout=$EMULATOR_BOOT_TIMEOUT
    local wait_interval=5
    local elapsed=0
    
    # Start adb server
    log_debug "Starting adb server..."
    adb start-server 2>&1 | head -5
    
    # Wait for device to be visible
    log_info "Waiting for device to appear..."
    while [[ $elapsed -lt $timeout ]]; do
        local devices=$(adb devices 2>/dev/null | grep emulator)
        if [[ -n "$devices" ]]; then
            log_success "Device found: $devices"
            break
        fi
        
        elapsed=$(($(date +%s) - start_time))
        log_debug "Waiting for device... ($elapsed/$timeout)"
        sleep $wait_interval
    done
    
    if [[ $elapsed -ge $timeout ]]; then
        log_error "Timeout waiting for device"
        adb devices
        return 1
    fi
    
    # Wait for device to be online
    log_info "Waiting for device to be online..."
    start_time=$(date +%s)
    elapsed=0
    
    while [[ $elapsed -lt $timeout ]]; do
        local state=$(adb shell getprop sys.boot_from_charger_mode 2>/dev/null || echo "unknown")
        log_debug "Device boot state: $state"
        
        # Try to get system property indicating boot complete
        local boot_complete=$(adb shell getprop sys.boot_completed 2>/dev/null || echo "0")
        if [[ "$boot_complete" == "1" ]]; then
            log_success "Device boot complete"
            break
        fi
        
        elapsed=$(($(date +%s) - start_time))
        log_debug "Waiting for boot completion... ($elapsed/$timeout)"
        sleep $wait_interval
    done
    
    if [[ $elapsed -ge $timeout ]]; then
        log_warn "Timeout waiting for boot completion (continuing anyway)"
    fi
    
    # Give device a moment to settle
    sleep 3
    
    # Verify device is accessible
    log_info "Verifying device accessibility..."
    if ! adb -s $EMULATOR_DEVICE_ID shell getprop ro.boot.serialno &>/dev/null; then
        log_error "Device is not responding to adb commands"
        adb devices -l
        adb logcat --help > /dev/null 2>&1 || true
        return 1
    fi
    
    log_success "Device is ready and accessible"
    return 0
}

# Run Flutter tests
run_tests() {
    log_info "Running Flutter integration tests..."
    
    mkdir -p "$RESULTS_DIR"
    
    local test_result_file="$RESULTS_DIR/test-results.txt"
    local test_json_file="$RESULTS_DIR/test-results.json"
    
    cd "$PROJECT_ROOT" || {
        log_error "Failed to change to project directory: $PROJECT_ROOT"
        return 1
    }
    
    # Get dependencies
    log_info "Fetching Flutter dependencies..."
    if ! flutter pub get 2>&1 | tail -10; then
        log_error "Failed to fetch dependencies"
        return 1
    fi
    
    # Build test app
    log_info "Building test app..."
    if ! flutter build apk --debug 2>&1 | tail -20; then
        log_warn "APK build had issues (continuing)"
    fi
    
    # Run integration tests
    log_info "Starting integration tests (timeout: ${TEST_TIMEOUT}s)..."
    
    local test_args=(
        "test"
        "integration_test/"
        "--device-id=$EMULATOR_DEVICE_ID"
        "--verbose"
        "--timeout=${TEST_TIMEOUT}s"
        "--dart-define=MATRIX_SERVER=$MATRIX_SERVER"
        "--dart-define=MATRIX_TEST_USER=$MATRIX_TEST_USER"
        "--dart-define=MATRIX_TEST_PASSWORD=$MATRIX_TEST_PASSWORD"
    )
    
    # Add Matrix server environment variable
    export MATRIX_SERVER="$MATRIX_SERVER"
    export MATRIX_TEST_USER="${MATRIX_TEST_USER:-testuser1}"
    export MATRIX_TEST_PASSWORD="${MATRIX_TEST_PASSWORD:-testpass123}"
    
    log_debug "Test command: flutter ${test_args[*]}"
    
    # Run tests with timeout
    if timeout $((TEST_TIMEOUT + 30)) flutter "${test_args[@]}" 2>&1 | tee "$test_result_file"; then
        local test_exit_code=${PIPESTATUS[0]}
    else
        local test_exit_code=$?
    fi
    
    # Capture device logs
    log_info "Capturing device logs..."
    adb -s $EMULATOR_DEVICE_ID logcat -d > "$RESULTS_DIR/device.log" 2>&1 || true
    
    # Parse test results
    parse_test_results "$test_result_file"
    
    return $test_exit_code
}

# Parse and display test results
parse_test_results() {
    local result_file="$1"
    
    if [[ ! -f "$result_file" ]]; then
        log_warn "Test result file not found: $result_file"
        return 0
    fi
    
    log_info "Test Results Summary:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Count test results
    local total_tests=$(grep -c "^test/" "$result_file" || echo "unknown")
    local passed=$(grep -c "✓" "$result_file" || echo "0")
    local failed=$(grep -c "✗\|FAILED\|ERROR" "$result_file" || echo "0")
    
    echo "Total Tests:    $total_tests"
    echo "Passed:         $passed ✓"
    echo "Failed:         $failed ✗"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Show last 30 lines of test output
    log_info "Last 30 lines of test output:"
    tail -30 "$result_file"
    
    return 0
}

# Main execution
main() {
    log_info "╔════════════════════════════════════════════════════════╗"
    log_info "║     Android Emulator Test Runner                       ║"
    log_info "║     $(date +"%Y-%m-%d %H:%M:%S")                            ║"
    log_info "╚════════════════════════════════════════════════════════╝"
    
    # Start virtual display if needed
    start_virtual_display
    
    # Validate environment
    if ! validate_environment; then
        log_error "Environment validation failed"
        return 1
    fi
    
    # Start emulator
    if ! start_emulator; then
        log_error "Failed to start emulator"
        return 1
    fi
    
    # Wait for emulator to boot
    if ! wait_for_emulator; then
        log_error "Emulator failed to boot"
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

# Run main function
main "$@"
exit $?
