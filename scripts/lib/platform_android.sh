#!/bin/bash
# =============================================================================
# platform_android.sh — Android emulator management and test runner
# =============================================================================

# ---------------------------------------------------------------------------
# Android SDK utilities
# ---------------------------------------------------------------------------

# Detect ANDROID_SDK_ROOT from common locations
android_detect_sdk() {
    if [[ -n "${ANDROID_SDK_ROOT:-}" ]] && [[ -d "$ANDROID_SDK_ROOT" ]]; then
        return 0
    fi
    if [[ -n "${ANDROID_HOME:-}" ]] && [[ -d "$ANDROID_HOME" ]]; then
        ANDROID_SDK_ROOT="$ANDROID_HOME"
        return 0
    fi

    local candidates=(
        "$HOME/Library/Android/sdk"
        "$HOME/Android/Sdk"
        "/opt/android-sdk"
    )
    for c in "${candidates[@]}"; do
        if [[ -d "$c" ]]; then
            ANDROID_SDK_ROOT="$c"
            ANDROID_HOME="$c"
            return 0
        fi
    done
    return 1
}

# Add Android SDK tools to PATH
android_setup_path() {
    [[ -z "${ANDROID_SDK_ROOT:-}" ]] && return 1

    for subdir in platform-tools emulator "cmdline-tools/latest/bin"; do
        local p="$ANDROID_SDK_ROOT/$subdir"
        [[ -d "$p" ]] && export PATH="$p:$PATH"
    done
}

# ---------------------------------------------------------------------------
# Emulator lifecycle
# ---------------------------------------------------------------------------

ANDROID_EMULATOR_PID=""
ANDROID_DEVICE_ID="emulator-5554"
ANDROID_AVD_NAME="${ANDROID_AVD_NAME:-android_test}"

# Start the Android emulator in headless mode
android_start_emulator() {
    local avd_name="$ANDROID_AVD_NAME"

    # Check if a device is already running (e.g. on CI)
    if adb devices 2>/dev/null | grep -q "device$"; then
        log_info "Detected an already running Android device/emulator. Skipping start."
        return 0
    fi

    # Kill any existing emulator (only if we are the ones starting it)
    pkill -f emulator 2>/dev/null || true
    sleep 1

    # Verify AVD exists
    local avds
    avds=$(emulator -list-avds 2>/dev/null | tr -d '\r')
    if [[ -z "$avds" ]]; then
        log_error "No AVDs found. Create one in Android Studio or with avdmanager."
        log_info "Environment: ANDROID_AVD_HOME=$ANDROID_AVD_HOME"
        log_info "Home directory contents:"
        ls -a "$HOME" | sed 's/^/  /'
        
        # Record failure so it shows in summary
        record_target_result "android" 0 1 0 0
        return 1
    fi
    if ! echo "$avds" | grep -q "^${avd_name}$"; then
        local fallback
        fallback=$(echo "$avds" | head -1)
        log_warn "AVD '$avd_name' not found; using '$fallback'"
        avd_name="$fallback"
    fi

    log_info "Starting emulator: $avd_name"

    local accel_args=("-accel" "off")
    if [[ -x /usr/bin/kvm ]] || [[ -c /dev/kvm ]]; then
        log_info "KVM available — using hardware acceleration"
        accel_args=("-accel" "on" "-qemu" "-enable-kvm")
    fi

    emulator -avd "$avd_name" \
        -no-window -no-audio \
        "${accel_args[@]}" \
        -prop persist.sys.usb.config=adb \
        -prop persist.sys.dalvik.vm.heapsize=512m \
        &>/tmp/emulator.log &
    ANDROID_EMULATOR_PID=$!

    sleep 3
    if ! kill -0 "$ANDROID_EMULATOR_PID" 2>/dev/null; then
        log_error "Emulator failed to start"
        cat /tmp/emulator.log >&2
        return 1
    fi

    log_success "Emulator started (PID $ANDROID_EMULATOR_PID)"
}

# Wait for the emulator to finish booting
android_wait_for_boot() {
    local boot_timeout="${ANDROID_BOOT_TIMEOUT:-900}"

    log_info "Waiting for emulator boot (timeout: ${boot_timeout}s)..."
    adb start-server 2>/dev/null

    # Wait for device to appear
    local start_time elapsed
    start_time=$(date +%s)

    while true; do
        adb devices 2>/dev/null | grep -q emulator && break
        elapsed=$(( $(date +%s) - start_time ))
        if [[ $elapsed -ge $boot_timeout ]]; then
            log_error "Timed out waiting for emulator device"
            adb devices
            return 1
        fi
        sleep 5
    done

    # Wait for boot_completed
    while true; do
        local completed
        completed=$(adb shell getprop sys.boot_completed 2>/dev/null || echo "0")
        [[ "$completed" == "1" ]] && break

        elapsed=$(( $(date +%s) - start_time ))
        if [[ $elapsed -ge $boot_timeout ]]; then
            log_error "Timed out waiting for boot completion"
            log_info "Last 20 lines of logcat:"
            adb logcat -d | tail -20 || true
            return 1
        fi
        sleep 5
    done

    sleep 3
    log_success "Emulator is ready"
}

# Stop the Android emulator
android_stop_emulator() {
    if [[ -n "${ANDROID_EMULATOR_PID:-}" ]]; then
        adb -s "$ANDROID_DEVICE_ID" emu kill 2>/dev/null || true
        sleep 1
        kill "$ANDROID_EMULATOR_PID" 2>/dev/null || true
        ANDROID_EMULATOR_PID=""
    fi
    pkill -f emulator 2>/dev/null || true
    adb kill-server 2>/dev/null || true
}

# ---------------------------------------------------------------------------
# Test runner
# ---------------------------------------------------------------------------

run_android_tests() {
    log_header "Android Tests (Emulator)"

    # Validate environment
    if ! android_detect_sdk; then
        log_error "Android SDK not found. Set ANDROID_SDK_ROOT or ANDROID_HOME."
        return 1
    fi
    android_setup_path
    log_debug "ANDROID_SDK_ROOT=$ANDROID_SDK_ROOT"

    for tool in emulator adb; do
        if ! command -v "$tool" &>/dev/null; then
            log_error "$tool not found in PATH"
            return 1
        fi
    done

    validate_flutter || return 1

    # Virtual display (Linux headless)
    start_virtual_display || true

    # Start emulator
    android_start_emulator || return 1
    android_wait_for_boot  || return 1

    # Run tests
    local log_file="${RESULTS_DIR}/android-tests.log"
    local timeout="${ANDROID_TEST_TIMEOUT:-2400}"
    mkdir -p "$RESULTS_DIR"

    export MATRIX_SERVER="${MATRIX_SERVER:-http://localhost:8008}"

    local common_args=(
        "test"
        "--device-id=$ANDROID_DEVICE_ID"
        "--reporter=expanded"
        "--concurrency=1"
        "--dart-define=INTEGRATION_TEST=true"
        "--dart-define=MATRIX_SERVER=${MATRIX_SERVER}"
        "--dart-define=MATRIX_TEST_USER=${MATRIX_TEST_USER:-testuser1}"
        "--dart-define=MATRIX_TEST_PASSWORD=${MATRIX_TEST_PASSWORD:-testpass123}"
    )

    local start_time
    start_time=$(date +%s)
    local overall_exit=0

    if [[ -n "${TEST_FILTER:-}" ]]; then
        # Per-file mode: collect files and apply filter
        local all_files=()
        while IFS= read -r -d '' f; do
            all_files+=("$f")
        done < <(find integration_test -maxdepth 1 -name '*_test.dart' -print0 | sort -z)

        local test_files=()
        filter_test_files test_files "$TEST_FILTER" "${all_files[@]}"

        if [[ ${#test_files[@]} -eq 0 ]]; then
            log_warn "No Android integration test files remain after applying filter."
            record_target_result "android" 0 0 0 0
            return 0
        fi

        log_info "Running ${#test_files[@]} filtered integration test(s) on Android (timeout: ${timeout}s each)..."
        : > "$log_file"
        local acc_passed=0 acc_failed=0 acc_skipped=0

        for test_file in "${test_files[@]}"; do
            log_info "  Running: $test_file"
            run_with_timeout "$timeout" flutter "${common_args[@]}" --no-pub "$test_file" 2>&1 | tee -a "$log_file"
            local exit_code=${PIPESTATUS[0]}
            parse_flutter_output "$log_file"
            acc_passed=$((acc_passed + _PARSED_PASSED))
            acc_failed=$((acc_failed + _PARSED_FAILED))
            acc_skipped=$((acc_skipped + _PARSED_SKIPPED))
            if [[ $exit_code -eq 124 ]]; then
                log_error "Timed out after ${timeout}s: $test_file"
                overall_exit=1; break
            elif [[ $exit_code -ne 0 ]] && [[ $_PARSED_FAILED -gt 0 ]]; then
                log_warn "FAILED: $test_file"
                overall_exit=1
            fi
        done

        local end_time
        end_time=$(date +%s)
        local duration=$((end_time - start_time))

        adb -s "$ANDROID_DEVICE_ID" logcat -d > "$RESULTS_DIR/android-device.log" 2>/dev/null || true
        record_target_result "android" "$acc_passed" "$acc_failed" "$acc_skipped" "$duration"
    else
        # Bulk mode: run entire integration_test/ directory at once
        log_info "Running integration tests on Android (timeout: ${timeout}s)..."
        local shard_args=()
        read -r -a shard_args <<< "$(get_shard_args)"

        run_with_timeout "$timeout" flutter "${common_args[@]}" --no-pub "${shard_args[@]}" "integration_test/" \
            2>&1 | tee "$log_file"
        overall_exit=${PIPESTATUS[0]}

        local end_time
        end_time=$(date +%s)
        local duration=$((end_time - start_time))

        adb -s "$ANDROID_DEVICE_ID" logcat -d > "$RESULTS_DIR/android-device.log" 2>/dev/null || true
        parse_flutter_output "$log_file"
        record_target_result "android" "$_PARSED_PASSED" "$_PARSED_FAILED" "$_PARSED_SKIPPED" "$duration"

        if [[ $overall_exit -ne 0 ]]; then
            if [[ $_PARSED_FAILED -gt 0 ]]; then
                log_error "Android tests failed (exit $overall_exit, $_PARSED_FAILED failed)"
            elif [[ $_PARSED_PASSED -eq 0 ]]; then
                log_error "Android tests failed (exit $overall_exit, no tests ran)"
            else
                log_warn "flutter test exited $overall_exit but $_PARSED_PASSED passed, 0 failed — treating as success"
                overall_exit=0
            fi
        fi
    fi

    if [[ $overall_exit -eq 0 ]]; then
        log_success "Android tests passed"
    else
        log_error "Android tests had failures"
        return 1
    fi
}
