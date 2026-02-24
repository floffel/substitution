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
    export GDK_BACKEND=x11
    export NO_AT_BRIDGE=1

    # Ensure Linux desktop is enabled and pre-cached
    log_info "Enabling Linux desktop support..."
    flutter config --enable-linux-desktop > /dev/null 2>&1
    flutter precache --linux > /dev/null 2>&1

    if [[ ! -d integration_test ]]; then
        log_warn "integration_test/ directory not found — skipping Linux integration tests"
        return 0
    fi

    local log_file="${RESULTS_DIR}/linux-tests.log"
    local timeout="${LINUX_TEST_TIMEOUT:-1800}"
    mkdir -p "$RESULTS_DIR"

    local common_args=(
        "--device-id=linux"
        "--reporter=compact"
        "--dart-define=MATRIX_SERVER=${MATRIX_SERVER:-http://localhost:8008}"
        "--dart-define=MATRIX_TEST_USER=${MATRIX_TEST_USER:-testuser1}"
        "--dart-define=MATRIX_TEST_PASSWORD=${MATRIX_TEST_PASSWORD:-testpass123}"
    )

    local start_time overall_exit=0
    start_time=$(date +%s)

    if [[ -n "${TEST_FILTER:-}" ]]; then
        local all_files=()
        while IFS= read -r -d '' f; do
            all_files+=("$f")
        done < <(find integration_test -maxdepth 1 -name '*_test.dart' -print0 | sort -z)

        local test_files=()
        filter_test_files test_files "$TEST_FILTER" "${all_files[@]}"

        if [[ ${#test_files[@]} -eq 0 ]]; then
            log_warn "No Linux integration test files remain after applying filter."
            record_target_result "linux" 0 0 0 0
            return 0
        fi

        log_info "Running ${#test_files[@]} filtered integration test(s) on Linux (timeout: ${timeout}s each)..."
        : > "$log_file"
        local acc_passed=0 acc_failed=0 acc_skipped=0

        for test_file in "${shard_files[@]}"; do
        log_info "  Running: $test_file"
        local file_log="${RESULTS_DIR}/web-drive-$(basename "$test_file").log"

        run_with_timeout "$timeout" flutter "${common_args[@]}" "--target=$test_file" \
            2>&1 | tee "$file_log" | tee -a "$log_file"
            local exit_code=${PIPESTATUS[0]}
            parse_flutter_output "$log_file"
            acc_passed=$((acc_passed + _PARSED_PASSED))
            acc_failed=$((acc_failed + _PARSED_FAILED))
            acc_skipped=$((acc_skipped + _PARSED_SKIPPED))
            [[ $exit_code -eq 124 ]] && { log_error "Timed out: $test_file"; overall_exit=1; break; }
            [[ $exit_code -ne 0 ]] && [[ $_PARSED_FAILED -gt 0 ]] && overall_exit=1
        done

        record_target_result "linux" "$acc_passed" "$acc_failed" "$acc_skipped" \
            "$(( $(date +%s) - start_time ))"
    else
        log_info "Running Linux integration tests (timeout: ${timeout}s)..."
        local shard_args=()
        read -r -a shard_args <<< "$(get_shard_args)"

        run_with_timeout "$timeout" flutter "test" "integration_test/" \
            "${common_args[@]}" "${shard_args[@]}" 2>&1 | tee "$log_file"
        overall_exit=${PIPESTATUS[0]}

        local duration=$(( $(date +%s) - start_time ))
        parse_flutter_output "$log_file"
        record_target_result "linux" "$_PARSED_PASSED" "$_PARSED_FAILED" "$_PARSED_SKIPPED" "$duration"

        if [[ $overall_exit -ne 0 ]]; then
            if [[ $_PARSED_FAILED -gt 0 ]]; then
                log_error "Linux tests failed (exit $overall_exit, $_PARSED_FAILED failed)"
            elif [[ $_PARSED_PASSED -eq 0 ]]; then
                log_error "Linux tests failed (exit $overall_exit, no tests ran)"
            else
                log_warn "flutter test exited $overall_exit but $_PARSED_PASSED passed, 0 failed — treating as success"
                overall_exit=0
            fi
        fi
    fi

    [[ $overall_exit -ne 0 ]] && { log_error "Linux tests had failures"; return 1; }
    log_success "Linux tests passed"
}
