#!/bin/bash
# =============================================================================
# results.sh — Flutter test result parsing and summary display
# =============================================================================

# Global counters (accumulated across targets)
TOTAL_PASSED=0
TOTAL_FAILED=0
TOTAL_SKIPPED=0
TOTAL_ERRORS=0
TARGET_RESULTS=()  # array of "target:passed:failed:skipped:duration"

# Parse flutter test output and extract counts.
# Usage: parse_flutter_output <log_file>
# Sets: _PARSED_PASSED, _PARSED_FAILED, _PARSED_SKIPPED
parse_flutter_output() {
    local log_file="$1"
    _PARSED_PASSED=0
    _PARSED_FAILED=0
    _PARSED_SKIPPED=0

    if [[ ! -f "$log_file" ]]; then
        return
    fi

    # Flutter test output ends with lines like:
    #   00:02 +51: All tests passed!
    #   00:05 +10 -2: Some tests failed.
    # The last status line has the format: MM:SS +passed -failed ~skipped
    # Note: compact reporter uses \r (carriage return) and ANSI escapes,
    # so we convert \r to newlines and strip ANSI codes before matching.
    # We also allow leading spaces which occur in expanded reporter.
    local last_status
    last_status=$(tr '\r' '\n' < "$log_file" | sed 's/\x1b\[[0-9;]*m//g' | grep -E '^[[:space:]]*[0-9]+:[0-9]+ \+' | tail -1)

    if [[ -n "$last_status" ]]; then
        _PARSED_PASSED=$(echo "$last_status" | grep -oE '\+[0-9]+' | head -1 | tr -d '+')
        _PARSED_FAILED=$(echo "$last_status" | grep -oE '\-[0-9]+' | head -1 | tr -d '-')
        _PARSED_SKIPPED=$(echo "$last_status" | grep -oE '~[0-9]+' | head -1 | tr -d '~')
    fi

    _PARSED_PASSED=${_PARSED_PASSED:-0}
    _PARSED_FAILED=${_PARSED_FAILED:-0}
    _PARSED_SKIPPED=${_PARSED_SKIPPED:-0}
}

# Record results for a target.
# Usage: record_target_result <target_name> <passed> <failed> <skipped> <duration_seconds>
record_target_result() {
    local target="$1"
    local passed="${2:-0}"
    local failed="${3:-0}"
    local skipped="${4:-0}"
    local duration="${5:-0}"

    TARGET_RESULTS+=("${target}:${passed}:${failed}:${skipped}:${duration}")
    TOTAL_PASSED=$((TOTAL_PASSED + passed))
    TOTAL_FAILED=$((TOTAL_FAILED + failed))
    TOTAL_SKIPPED=$((TOTAL_SKIPPED + skipped))
}

# Print a formatted summary of all test results
print_summary() {
    echo ""
    echo -e "${BOLD}══════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}  Test Results Summary${NC}"
    echo -e "${BOLD}══════════════════════════════════════════════════════════${NC}"
    echo ""

    if [[ ${#TARGET_RESULTS[@]} -eq 0 ]]; then
        log_warn "No test results recorded"
        return
    fi

    printf "  %-16s %8s %8s %8s %10s\n" "TARGET" "PASSED" "FAILED" "SKIPPED" "DURATION"
    printf "  %-16s %8s %8s %8s %10s\n" "────────────────" "────────" "────────" "────────" "──────────"

    for entry in "${TARGET_RESULTS[@]}"; do
        IFS=':' read -r target passed failed skipped duration <<< "$entry"
        local mins=$((duration / 60))
        local secs=$((duration % 60))
        local dur_str="${mins}m ${secs}s"

        local status_color="$GREEN"
        [[ "$failed" -gt 0 ]] && status_color="$RED"

        printf "  ${status_color}%-16s${NC} %8s %8s %8s %10s\n" \
            "$target" "$passed" "$failed" "$skipped" "$dur_str"
    done

    echo ""
    printf "  %-16s %8s %8s %8s\n" "────────────────" "────────" "────────" "────────"

    local total_color="$GREEN"
    [[ "$TOTAL_FAILED" -gt 0 ]] && total_color="$RED"

    printf "  ${total_color}%-16s %8s %8s %8s${NC}\n" \
        "TOTAL" "$TOTAL_PASSED" "$TOTAL_FAILED" "$TOTAL_SKIPPED"

    echo ""
    if [[ "$TOTAL_FAILED" -gt 0 ]]; then
        echo -e "  ${RED}${BOLD}RESULT: FAILED${NC}"
    else
        echo -e "  ${GREEN}${BOLD}RESULT: PASSED${NC}"
    fi
    echo ""
    echo -e "${BOLD}══════════════════════════════════════════════════════════${NC}"
    echo ""
}
