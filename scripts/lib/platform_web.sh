#!/bin/bash
# =============================================================================
# platform_web.sh — Chrome/web test runner
#
# Two phases:
#   1. Unit/widget tests compiled to Chrome (test/)
#   2. Full integration tests on web device (integration_test/)
# =============================================================================

# Find a Chrome or Chromium executable. Prints the path on success.
find_chrome() {
    # Explicit override
    if [[ -n "${CHROME_EXECUTABLE:-}" ]] && [[ -x "$CHROME_EXECUTABLE" ]]; then
        echo "$CHROME_EXECUTABLE"; return 0
    fi

    local candidates=(
        # macOS
        "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
        "/Applications/Chromium.app/Contents/MacOS/Chromium"
        # Linux
        "/usr/bin/google-chrome"
        "/usr/bin/google-chrome-stable"
        "/usr/bin/chromium-browser"
        "/usr/bin/chromium"
        "/snap/bin/chromium"
        # WSL
        "/mnt/c/Program Files/Google/Chrome/Application/chrome.exe"
        "/mnt/c/Program Files (x86)/Google/Chrome/Application/chrome.exe"
        # Other
        "/opt/google/chrome/google-chrome"
        "/usr/local/bin/chrome"
        "/usr/local/bin/chromium"
    )

    for c in "${candidates[@]}"; do
        [[ -x "$c" ]] && { echo "$c"; return 0; }
    done

    # Try PATH lookup
    for name in google-chrome chromium-browser chromium; do
        if command -v "$name" &>/dev/null; then
            command -v "$name"; return 0
        fi
    done

    return 1
}

# Validate Chrome is available; sets CHROME_PATH and exports CHROME_EXECUTABLE.
validate_chrome() {
    log_info "Validating Chrome/Chromium..."

    local chrome_path
    if ! chrome_path=$(find_chrome); then
        log_error "Chrome/Chromium not found"
        log_info "Install Chrome or set CHROME_EXECUTABLE=/path/to/chrome"
        return 1
    fi

    CHROME_PATH="$chrome_path"
    export CHROME_EXECUTABLE="$CHROME_PATH"
    log_success "Chrome found: $CHROME_PATH"

    local version
    version=$("$CHROME_PATH" --version 2>/dev/null || echo "unknown")
    log_debug "Chrome version: $version"
    return 0
}

# ---------------------------------------------------------------------------
# Phase 1: unit + widget tests compiled to Chrome (test/)
# ---------------------------------------------------------------------------
_run_web_unit_tests() {
    local timeout="${WEB_TEST_TIMEOUT:-900}"
    local renderer="${WEB_RENDERER:-html}"

    log_info "Phase 1: unit/widget tests on Chrome"
    log_info "  Renderer: $renderer  Timeout: ${timeout}s"

    local common_args=(
        "test"
        "--platform=chrome"
        "--reporter=compact"
        "--dart-define=MATRIX_SERVER=${MATRIX_SERVER:-http://localhost:8008}"
        "--dart-define=MATRIX_TEST_USER=${MATRIX_TEST_USER:-testuser1}"
        "--dart-define=MATRIX_TEST_PASSWORD=${MATRIX_TEST_PASSWORD:-testpass123}"
    )

    # Discover unit/widget test files (test/, excluding helpers/)
    local all_test_files=()
    while IFS= read -r -d '' file; do
        all_test_files+=("$file")
    done < <(find test -name '*_test.dart' -print0 2>/dev/null)

    local test_files=()
    if [[ -n "${TEST_FILTER:-}" ]]; then
        filter_test_files test_files "$TEST_FILTER" "${all_test_files[@]}"
    else
        test_files=("${all_test_files[@]}")
    fi

    if [[ ${#test_files[@]} -eq 0 ]]; then
        log_warn "No test files found matching filter or in test/"
        record_target_result "web-unit" 0 0 0 0
        return 0
    fi

    local total_files=${#test_files[@]}
    local start_time
    start_time=$(date +%s)
    local log_file="${RESULTS_DIR}/web-unit-tests.log"
    : > "$log_file"

    log_info "Running $total_files test files on Chrome..."

    local overall_exit=0 idx=0
    local acc_passed=0 acc_failed=0 acc_skipped=0

    for test_file in "${test_files[@]}"; do
        idx=$((idx + 1))
        log_info "  [$idx/$total_files] $test_file"

        local file_log="${RESULTS_DIR}/web-unit-file-${idx}.log"
        run_with_timeout "$timeout" flutter "${common_args[@]}" "$test_file" \
            2>&1 | tee "$file_log" | tee -a "$log_file"
        local exit_code=${PIPESTATUS[0]}

        parse_flutter_output "$file_log"
        acc_passed=$((acc_passed + _PARSED_PASSED))
        acc_failed=$((acc_failed + _PARSED_FAILED))
        acc_skipped=$((acc_skipped + _PARSED_SKIPPED))
        rm -f "$file_log"

        if [[ $exit_code -eq 124 ]]; then
            log_error "Timed out after ${timeout}s: $test_file"
            overall_exit=1; break
        elif [[ $exit_code -ne 0 ]]; then
            log_error "Failed: $test_file"
            overall_exit=1
        fi
    done

    local duration=$(( $(date +%s) - start_time ))
    record_target_result "web-unit" "$acc_passed" "$acc_failed" "$acc_skipped" "$duration"

    [[ $overall_exit -eq 0 ]] && log_success "Phase 1 passed" || log_error "Phase 1 failed"
    return $overall_exit
}

# ---------------------------------------------------------------------------
# Phase 2: full integration tests on Chrome (integration_test/)
#
# Uses `flutter test integration_test/ -d chrome` which is supported since
# Flutter 2.5+. ChromeDriver is required and is pre-installed on ubuntu-latest
# at $CHROMEWEBDRIVER/chromedriver.
# ---------------------------------------------------------------------------
_run_web_integration_tests() {
    if [[ ! -d integration_test ]]; then
        log_warn "integration_test/ directory not found — skipping web integration tests"
        return 0
    fi
    if [[ ! -f test_driver/integration_test.dart ]]; then
        log_error "test_driver/integration_test.dart not found — required for web integration tests"
        return 1
    fi

    log_info "Phase 2: web integration tests via flutter drive on Chrome"

    # On Linux CI, Chrome needs --no-sandbox to run. Flutter respects CHROME_EXECUTABLE,
    # so we wrap the real Chrome binary in a small script that adds the required flags.
    local real_chrome="${CHROME_PATH:-}"
    if [[ -z "$real_chrome" ]]; then
        real_chrome=$(find_chrome) || true
    fi
    if [[ -n "$real_chrome" ]] && [[ "$(detect_os)" == "linux" ]]; then
        local wrapper="/tmp/chrome-ci-wrapper.sh"
        printf '#!/bin/bash\nexec "%s" --no-sandbox --disable-dev-shm-usage "$@"\n' "$real_chrome" > "$wrapper"
        chmod +x "$wrapper"
        export CHROME_EXECUTABLE="$wrapper"
        log_debug "Using Chrome wrapper with --no-sandbox: $wrapper"
    fi

    # Check for ChromeDriver (required for flutter drive on web)
    if [[ -z "${CHROMEWEBDRIVER:-}" ]]; then
        if [[ "$(detect_os)" == "linux" ]]; then
            # Common GHA location if not set
            if [[ -d "/usr/local/share/chrome_driver" ]]; then
                CHROMEWEBDRIVER="/usr/local/share/chrome_driver"
            fi
        fi
    fi

    if [[ -n "${CHROMEWEBDRIVER:-}" ]]; then
        log_info "Found ChromeDriver at: $CHROMEWEBDRIVER"
        # Ensure it is in PATH
        export PATH="$CHROMEWEBDRIVER:$PATH"
    else
        log_warn "CHROMEWEBDRIVER not set. flutter drive may fail to find chromedriver."
    fi

    # Collect integration test files for this shard
    local all_test_files=()
    while IFS= read -r -d '' f; do
        all_test_files+=("$f")
    done < <(find integration_test -maxdepth 1 -name '*_test.dart' -print0 2>/dev/null | sort -z)

    local total_files=${#all_test_files[@]}
    if [[ $total_files -eq 0 ]]; then
        log_warn "No integration test files found"
        return 0
    fi

    # Apply test filter
    local filtered_files=()
    filter_test_files filtered_files "$TEST_FILTER" "${all_test_files[@]}"
    all_test_files=("${filtered_files[@]}")
    total_files=${#all_test_files[@]}

    if [[ $total_files -eq 0 ]]; then
        log_warn "No web integration test files remain after applying filter."
        record_target_result "web-integration" 0 0 0 0
        return 0
    fi

    # Apply sharding: select files for this shard
    local shard_files=()
    if [[ -n "${SHARD_INDEX:-}" ]] && [[ -n "${TOTAL_SHARDS:-}" ]]; then
        local idx=0
        for f in "${all_test_files[@]}"; do
            if (( idx % TOTAL_SHARDS == SHARD_INDEX )); then
                shard_files+=("$f")
            fi
            idx=$((idx + 1))
        done
        log_info "Shard ${SHARD_INDEX}/${TOTAL_SHARDS}: running ${#shard_files[@]} of $total_files files"
    else
        shard_files=("${all_test_files[@]}")
        log_info "No sharding: running all $total_files files"
    fi

    if [[ ${#shard_files[@]} -eq 0 ]]; then
        log_info "No test files assigned to this shard — nothing to run"
        record_target_result "web-integration" 0 0 0 0
        return 0
    fi

    local log_file="${RESULTS_DIR}/web-integration-tests.log"
    local timeout="${WEB_TEST_TIMEOUT:-900}"
    mkdir -p "$RESULTS_DIR"
    : > "$log_file"

    local common_args=(
        "drive"
        "--driver=test_driver/integration_test.dart"
        "--device-id=chrome"
        "--dart-define=MATRIX_SERVER=${MATRIX_SERVER:-http://localhost:8008}"
        "--dart-define=MATRIX_TEST_USER=${MATRIX_TEST_USER:-testuser1}"
        "--dart-define=MATRIX_TEST_PASSWORD=${MATRIX_TEST_PASSWORD:-testpass123}"
    )

    if [[ -n "${CHROMEWEBDRIVER:-}" ]]; then
        # Explicitly pass chromedriver path if known (improves GHA reliability)
        if [[ -f "$CHROMEWEBDRIVER/chromedriver" ]]; then
            common_args+=("--chromedriver=$CHROMEWEBDRIVER/chromedriver")
        elif [[ -f "$CHROMEWEBDRIVER" ]]; then # In case CHROMEWEBDRIVER points to the file itself
             common_args+=("--chromedriver=$CHROMEWEBDRIVER")
        fi
    fi

    local overall_exit=0
    local acc_passed=0 acc_failed=0 acc_skipped=0
    local start_time
    start_time=$(date +%s)

    for test_file in "${shard_files[@]}"; do
        log_info "  Running: $test_file"
        local file_log="${RESULTS_DIR}/web-drive-$(basename "$test_file").log"

        run_with_timeout "$timeout" flutter "${common_args[@]}" "--target=$test_file" \
            2>&1 | tee "$file_log" | tee -a "$log_file"
        local exit_code=${PIPESTATUS[0]}

        parse_flutter_output "$file_log"
        acc_passed=$((acc_passed + _PARSED_PASSED))
        acc_failed=$((acc_failed + _PARSED_FAILED))
        acc_skipped=$((acc_skipped + _PARSED_SKIPPED))
        rm -f "$file_log"

        if [[ $exit_code -eq 124 ]]; then
            log_error "Timed out after ${timeout}s: $test_file"
            overall_exit=1; break
        elif [[ $exit_code -ne 0 ]]; then
            # flutter drive is known to exit non-zero even when all tests pass.
            # Trust the parsed counts: only fail if we saw actual test failures
            # or if no tests ran at all (which would also indicate a problem).
            if [[ $_PARSED_FAILED -gt 0 ]]; then
                log_error "Failed: $test_file (exit $exit_code, $_PARSED_FAILED failed)"
                overall_exit=1
            elif [[ $_PARSED_PASSED -eq 0 ]]; then
                log_error "Failed: $test_file (exit $exit_code, no tests ran)"
                overall_exit=1
            else
                log_warn "flutter drive exited $exit_code but $_PARSED_PASSED tests passed, 0 failed — treating as success"
            fi
        fi
    done

    local duration=$(( $(date +%s) - start_time ))
    record_target_result "web-integration" "$acc_passed" "$acc_failed" "$acc_skipped" "$duration"

    if [[ $overall_exit -ne 0 ]]; then
        log_error "Web integration tests failed"
        return 1
    fi

    log_success "Phase 2 passed"
}

# ---------------------------------------------------------------------------
# Main entry point called by test.sh
# ---------------------------------------------------------------------------
run_web_tests() {
    log_header "Web Tests (Chrome)"

    validate_flutter || return 1
    validate_chrome  || return 1

    mkdir -p "$RESULTS_DIR"

    local overall_exit=0

    # Only run unit tests on the first shard (or if not sharding)
    if [[ -z "${SHARD_INDEX:-}" ]] || [[ "$SHARD_INDEX" == "0" ]]; then
        _run_web_unit_tests || overall_exit=1
    else
        log_info "Skipping web unit tests (shard $SHARD_INDEX > 0)"
    fi

    _run_web_integration_tests || overall_exit=1

    if [[ $overall_exit -ne 0 ]]; then
        log_error "Web tests failed"
        return 1
    fi

    log_success "Web tests passed"
}
