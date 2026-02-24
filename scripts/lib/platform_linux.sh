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

    # Note: Sharding for Linux is handled by picking files from the list
    local all_files=()
    while IFS= read -r -d '' f; do
        all_files+=("$f")
    done < <(find integration_test -maxdepth 1 -name '*_test.dart' -print0 | sort -z)

    # Filter by user-provided pattern if set
    local filtered_files=()
    if [[ -n "${TEST_FILTER:-}" ]]; then
        filter_test_files filtered_files "$TEST_FILTER" "${all_files[@]}"
    else
        filtered_files=("${all_files[@]}")
    fi

    # Sharding logic
    local test_files=()
    if [[ -n "${SHARD_INDEX:-}" ]] && [[ -n "${TOTAL_SHARDS:-}" ]]; then
        local idx=0
        for f in "${filtered_files[@]}"; do
            if (( idx % TOTAL_SHARDS == SHARD_INDEX )); then
                test_files+=("$f")
            fi
            idx=$((idx + 1))
        done
        log_info "Shard ${SHARD_INDEX}/${TOTAL_SHARDS}: running ${#test_files[@]} of ${#filtered_files[@]} files"
    else
        test_files=("${filtered_files[@]}")
    fi

    if [[ ${#test_files[@]} -eq 0 ]]; then
        log_warn "No Linux integration test files to run for this shard/filter."
        record_target_result "linux" 0 0 0 0
        return 0
    fi

    log_info "Running ${#test_files[@]} integration test(s) on Linux..."
    : > "$log_file"
    local acc_passed=0 acc_failed=0 acc_skipped=0

    for test_file in "${test_files[@]}"; do
        log_info "  Running: $test_file"
        
        # Cleanup stale processes before each test to prevent launch failures
        pkill -f substitution || true
        
        # Temporary log for this specific file to parse results
        local file_log="${RESULTS_DIR}/linux-file-$(basename "$test_file").log"
        run_with_timeout "$timeout" flutter "test" "${common_args[@]}" "$test_file" 2>&1 | tee "$file_log" | tee -a "$log_file"
        local exit_code=${PIPESTATUS[0]}
        
        parse_flutter_output "$file_log"
        acc_passed=$((acc_passed + _PARSED_PASSED))
        acc_failed=$((acc_failed + _PARSED_FAILED))
        acc_skipped=$((acc_skipped + _PARSED_SKIPPED))
        rm -f "$file_log"

        if [[ $exit_code -eq 124 ]]; then
            log_error "Timed out: $test_file"
            overall_exit=1; break
        fi
        [[ $exit_code -ne 0 ]] && [[ $_PARSED_FAILED -gt 0 ]] && overall_exit=1
    done

    local duration=$(( $(date +%s) - start_time ))
    record_target_result "linux" "$acc_passed" "$acc_failed" "$acc_skipped" "$duration"

    [[ $overall_exit -ne 0 ]] && { log_error "Linux tests had failures"; return 1; }
    log_success "Linux tests passed"
}
