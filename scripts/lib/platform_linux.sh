#!/bin/bash
# =============================================================================
# platform_linux.sh — Linux desktop integration test runner
#
# Runs integration_test/ on the Linux desktop device target.
# Requires: Flutter with Linux desktop support, a display server (or Xvfb).
# =============================================================================

run_linux_tests() {
    log_header "Linux Desktop Tests"

    validate_flutter || return 1

    # Virtual display for headless Linux runners
    start_virtual_display || true

    # Verify Linux desktop is enabled
    if ! flutter config 2>/dev/null | grep -q "enable-linux-desktop: true"; then
        log_info "Enabling Linux desktop support..."
        flutter config --enable-linux-desktop 2>&1 | tail -3
        flutter doctor -v > /dev/null 2>&1
    fi

    # Verify linux device is available
    if ! flutter devices 2>/dev/null | grep -qi linux; then
        log_error "Linux desktop device not available"
        log_info "Ensure you are on Linux and Flutter linux desktop is enabled"
        return 1
    fi

    if [[ ! -d integration_test ]]; then
        log_warn "integration_test/ directory not found — skipping Linux integration tests"
        return 0
    fi

    local log_file="${RESULTS_DIR}/linux-tests.log"
    local timeout="${LINUX_TEST_TIMEOUT:-600}"
    mkdir -p "$RESULTS_DIR"

    local test_args=(
        "test" "integration_test/"
        "--device-id=linux"
        "--reporter=compact"
        "--dart-define=MATRIX_SERVER=${MATRIX_SERVER:-http://localhost:8008}"
        "--dart-define=MATRIX_TEST_USER=${MATRIX_TEST_USER:-testuser1}"
        "--dart-define=MATRIX_TEST_PASSWORD=${MATRIX_TEST_PASSWORD:-testpass123}"
    )

    log_info "Running Linux integration tests (timeout: ${timeout}s)..."
    local start_time
    start_time=$(date +%s)

    run_with_timeout "$timeout" flutter "${test_args[@]}" 2>&1 | tee "$log_file"
    local exit_code=${PIPESTATUS[0]}

    local duration=$(( $(date +%s) - start_time ))
    parse_flutter_output "$log_file"
    record_target_result "linux" "$_PARSED_PASSED" "$_PARSED_FAILED" "$_PARSED_SKIPPED" "$duration"

    if [[ $exit_code -eq 124 ]]; then
        log_error "Linux tests timed out after ${timeout}s"
        return 1
    elif [[ $exit_code -ne 0 ]]; then
        log_error "Linux tests failed (exit code $exit_code)"
        return 1
    fi

    log_success "Linux tests passed"
}
