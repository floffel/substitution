#!/bin/bash
# =============================================================================
# platform_web.sh — Chrome/web test runner
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

# Validate Chrome is available
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

# Run web tests (unit + widget tests on Chrome platform)
run_web_tests() {
    log_header "Web Tests (Chrome)"

    validate_flutter || return 1
    validate_chrome  || return 1

    local log_file="${RESULTS_DIR}/web-tests.log"
    mkdir -p "$RESULTS_DIR"

    local timeout="${WEB_TEST_TIMEOUT:-900}"
    local renderer="${WEB_RENDERER:-html}"

    log_info "Configuration:"
    log_info "  Renderer:  $renderer"
    log_info "  Browser:   $CHROME_PATH"
    log_info "  Timeout:   ${timeout}s"

    export CHROME_EXECUTABLE="$CHROME_PATH"

    # Build flutter test args
    local test_args=(
        "test"
        "--platform=chrome"
        "--reporter=compact"
    )

    # Add dart-defines for Matrix credentials if integration tests need them
    if [[ -n "${MATRIX_SERVER:-}" ]]; then
        test_args+=(
            "--dart-define=MATRIX_SERVER=$MATRIX_SERVER"
            "--dart-define=MATRIX_TEST_USER=${MATRIX_TEST_USER:-testuser1}"
            "--dart-define=MATRIX_TEST_PASSWORD=${MATRIX_TEST_PASSWORD:-testpass123}"
        )
    fi

    # Discover test files
    local test_files=()
    while IFS= read -r -d '' file; do
        test_files+=("$file")
    done < <(find test -name '*_test.dart' -print0 2>/dev/null)

    if [[ ${#test_files[@]} -eq 0 ]]; then
        log_warn "No test files found under test/"
        record_target_result "web" 0 0 0 0
        return 0
    fi

    local total_files=${#test_files[@]}
    local start_time
    start_time=$(date +%s)

    log_info "Running $total_files test files on Chrome..."
    : > "$log_file"

    local overall_exit=0
    local idx=0
    local accumulated_passed=0
    local accumulated_failed=0
    local accumulated_skipped=0

    for test_file in "${test_files[@]}"; do
        idx=$((idx + 1))
        log_info "[$idx/$total_files] $test_file"

        local file_log="${RESULTS_DIR}/web-file-${idx}.log"
        run_with_timeout "$timeout" flutter "${test_args[@]}" "$test_file" 2>&1 | tee "$file_log" | tee -a "$log_file"
        local exit_code=${PIPESTATUS[0]}

        # Accumulate counts per file
        parse_flutter_output "$file_log"
        accumulated_passed=$((accumulated_passed + _PARSED_PASSED))
        accumulated_failed=$((accumulated_failed + _PARSED_FAILED))
        accumulated_skipped=$((accumulated_skipped + _PARSED_SKIPPED))
        rm -f "$file_log"

        if [[ $exit_code -eq 124 ]]; then
            log_error "Timed out after ${timeout}s: $test_file"
            overall_exit=1
            break
        elif [[ $exit_code -ne 0 ]]; then
            log_error "Failed: $test_file"
            overall_exit=1
        fi
    done

    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))

    record_target_result "web" "$accumulated_passed" "$accumulated_failed" "$accumulated_skipped" "$duration"

    if [[ $overall_exit -ne 0 ]]; then
        log_error "Web tests failed"
        return 1
    fi

    log_success "Web tests passed"
}
