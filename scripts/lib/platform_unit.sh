#!/bin/bash
# =============================================================================
# platform_unit.sh — Unit and widget test runners (no Docker needed)
# =============================================================================

# Run unit tests (test/unit/)
run_unit_tests() {
    log_header "Unit Tests"

    validate_flutter || return 1

    local log_file="${RESULTS_DIR}/unit-tests.log"
    mkdir -p "$RESULTS_DIR"

    log_info "Running unit tests..."
    local start_time
    start_time=$(date +%s)

    flutter test test/unit/ --reporter=expanded 2>&1 | tee "$log_file"
    local exit_code=${PIPESTATUS[0]}

    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))

    parse_flutter_output "$log_file"
    record_target_result "unit" "$_PARSED_PASSED" "$_PARSED_FAILED" "$_PARSED_SKIPPED" "$duration"

    if [[ $exit_code -ne 0 ]]; then
        log_error "Unit tests failed (exit code $exit_code)"
        return 1
    fi

    log_success "Unit tests passed"
}

# Run widget tests (all test files outside test/unit/)
run_widget_tests() {
    log_header "Widget Tests"

    validate_flutter || return 1

    local log_file="${RESULTS_DIR}/widget-tests.log"
    mkdir -p "$RESULTS_DIR"

    log_info "Running widget tests..."
    local start_time
    start_time=$(date +%s)

    # Run all tests under test/ excluding unit/ directory
    # Flutter doesn't have a built-in exclude-dir, so we find files manually
    local test_files=()
    while IFS= read -r -d '' file; do
        test_files+=("$file")
    done < <(find test -name '*_test.dart' -not -path 'test/unit/*' -print0 2>/dev/null)

    if [[ ${#test_files[@]} -eq 0 ]]; then
        log_warn "No widget test files found"
        record_target_result "widget" 0 0 0 0
        return 0
    fi

    flutter test "${test_files[@]}" --reporter=expanded 2>&1 | tee "$log_file"
    local exit_code=${PIPESTATUS[0]}

    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))

    parse_flutter_output "$log_file"
    record_target_result "widget" "$_PARSED_PASSED" "$_PARSED_FAILED" "$_PARSED_SKIPPED" "$duration"

    if [[ $exit_code -ne 0 ]]; then
        log_error "Widget tests failed (exit code $exit_code)"
        return 1
    fi

    log_success "Widget tests passed"
}
