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

    # Kill any existing emulator
    pkill -f emulator 2>/dev/null || true
    sleep 1

    # Verify AVD exists
    local avds
    avds=$(emulator -list-avds 2>/dev/null | tr -d '\r')
    if [[ -z "$avds" ]]; then
        log_error "No AVDs found. Create one in Android Studio or with avdmanager."
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
    if [[ -c /dev/kvm ]]; then
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
    local boot_timeout="${ANDROID_BOOT_TIMEOUT:-180}"

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
            log_warn "Boot completion timed out (continuing anyway)"
            break
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
    local timeout="${ANDROID_TEST_TIMEOUT:-600}"
    mkdir -p "$RESULTS_DIR"

    local test_args=(
        "test" "integration_test/"
        "--device-id=$ANDROID_DEVICE_ID"
        "--reporter=compact"
        "--dart-define=MATRIX_SERVER=${MATRIX_SERVER:-http://localhost:8008}"
        "--dart-define=MATRIX_TEST_USER=${MATRIX_TEST_USER:-testuser1}"
        "--dart-define=MATRIX_TEST_PASSWORD=${MATRIX_TEST_PASSWORD:-testpass123}"
    )

    export MATRIX_SERVER="${MATRIX_SERVER:-http://localhost:8008}"

    log_info "Running integration tests on Android (timeout: ${timeout}s)..."
    local start_time
    start_time=$(date +%s)

    run_with_timeout "$timeout" flutter "${test_args[@]}" 2>&1 | tee "$log_file"
    local exit_code=${PIPESTATUS[0]}

    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))

    # Capture logcat
    adb -s "$ANDROID_DEVICE_ID" logcat -d > "$RESULTS_DIR/android-device.log" 2>/dev/null || true

    parse_flutter_output "$log_file"
    record_target_result "android" "$_PARSED_PASSED" "$_PARSED_FAILED" "$_PARSED_SKIPPED" "$duration"

    if [[ $exit_code -eq 124 ]]; then
        log_error "Android tests timed out after ${timeout}s"
        return 1
    elif [[ $exit_code -ne 0 ]]; then
        log_error "Android tests failed (exit code $exit_code)"
        return 1
    fi

    log_success "Android tests passed"
}
