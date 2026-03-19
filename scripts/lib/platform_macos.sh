#!/bin/bash
# =============================================================================
# platform_macos.sh — macOS desktop integration test runner
#
# Runs integration_test/ on the macOS desktop device target.
# Requires: Flutter with macOS desktop support.
# =============================================================================

run_macos_tests() {
    log_header "macOS Desktop Tests"

    validate_flutter || return 1

    # Verify macOS desktop is enabled
    if ! flutter config 2>/dev/null | grep -q "enable-macos-desktop: true"; then
        log_info "Enabling macOS desktop support..."
        flutter config --enable-macos-desktop 2>&1 | tail -3
    fi

    # Verify macos device is available
    local devices_output
    devices_output=$(flutter devices 2>/dev/null)
    log_info "Devices found:"
    echo "$devices_output"
    
    if ! echo "$devices_output" | grep -qi "macos"; then
        log_error "macOS desktop device not available"
        log_info "Ensure you are on macOS and Flutter macos desktop is enabled"
        return 1
    fi

    if [[ ! -d integration_test ]]; then
        log_warn "integration_test/ directory not found — skipping macOS integration tests"
        return 0
    fi

    local log_file="${RESULTS_DIR}/macos-tests.log"
    local timeout="${MACOS_TEST_TIMEOUT:-1200}"
    mkdir -p "$RESULTS_DIR"

    # Collect all integration test files
    local test_files=()
    while IFS= read -r -d '' f; do
        test_files+=("$f")
    done < <(find integration_test -maxdepth 1 -name '*_test.dart' ! -name 'screenshot_test.dart' -print0 | sort -z)

    if [[ ${#test_files[@]} -eq 0 ]]; then
        log_warn "No integration test files found."
        record_target_result "macos" 0 0 0 0
        return 0
    fi

    # Apply test filter if set
    local filtered_files=()
    filter_test_files filtered_files "$TEST_FILTER" "${test_files[@]}"
    test_files=("${filtered_files[@]}")

    if [[ ${#test_files[@]} -eq 0 ]]; then
        log_warn "No integration test files remain after applying filter."
        record_target_result "macos" 0 0 0 0
        return 0
    fi

    log_info "Found ${#test_files[@]} integration test files"
    log_info "Running each file separately on macOS (timeout: ${timeout}s per file)..."

    local total_passed=0
    local total_failed=0
    local total_skipped=0
    local any_failure=0
    local start_time end_time duration
    start_time=$(date +%s)

    for test_file in "${test_files[@]}"; do
        local file_base
        file_base=$(basename "${test_file%.dart}")
        local file_log="${RESULTS_DIR}/macos-${file_base}.log"
        
        log_info "  Running: $test_file"

        local test_args=(
            "test" "$test_file"
            "--device-id=macos"
            "--reporter=compact"
            "--dart-define=is_integration_test=true"
            "--dart-define=MATRIX_SERVER=${MATRIX_SERVER:-http://localhost:8008}"
            "--dart-define=MATRIX_TEST_USER=${MATRIX_TEST_USER:-testuser1}"
            "--dart-define=MATRIX_TEST_PASSWORD=${MATRIX_TEST_PASSWORD:-testpass123}"
        )

        run_with_timeout "$timeout" flutter "${test_args[@]}" 2>&1 | tee "$file_log"
        local exit_code=${PIPESTATUS[0]}

        parse_flutter_output "$file_log"
        total_passed=$((total_passed + _PARSED_PASSED))
        total_failed=$((total_failed + _PARSED_FAILED))
        total_skipped=$((total_skipped + _PARSED_SKIPPED))

        if [[ $exit_code -eq 124 ]]; then
            log_error "  Timed out after ${timeout}s: $test_file"
            any_failure=1
        elif [[ $exit_code -ne 0 ]]; then
            log_warn "  FAILED: $test_file (exit code $exit_code)"
            any_failure=1
        else
            log_success "  PASSED: $test_file"
        fi
    done

    end_time=$(date +%s)
    duration=$((end_time - start_time))

    record_target_result "macos" "$total_passed" "$total_failed" "$total_skipped" "$duration"

    if [[ $any_failure -ne 0 ]]; then
        log_error "macOS tests had failures"
        return 1
    fi

    log_success "macOS tests passed"
}
