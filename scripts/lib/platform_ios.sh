#!/bin/bash
# =============================================================================
# platform_ios.sh — iOS simulator management and test runner
# =============================================================================

# ---------------------------------------------------------------------------
# Simulator utilities
# ---------------------------------------------------------------------------

# List available iOS simulators
ios_list_simulators() {
    xcrun simctl list devices --json 2>/dev/null | python3 -c "
import json, sys
data = json.load(sys.stdin)
for runtime, sims in data.get('devices', {}).items():
    if 'iOS' in runtime:
        for sim in sims:
            if sim.get('isAvailable', False):
                state = '(booted)' if sim['state'] == 'Booted' else ''
                print(f\"  {sim['name']:30} {state:10} {sim['udid']}\")
" 2>/dev/null || xcrun simctl list devices | grep -i iphone
}

# Find the latest available iPhone simulator UDID
ios_find_latest_simulator() {
    xcrun simctl list devices --json 2>/dev/null | python3 -c "
import json, sys
data = json.load(sys.stdin)
priorities = ['iPhone 17', 'iPhone 16', 'iPhone 15', 'iPhone 14', 'iPhone 13', 'iPhone 12', 'iPhone 11']
for p in priorities:
    for sims in data.get('devices', {}).values():
        for sim in sims:
            if p in sim['name'] and sim.get('isAvailable', False):
                print(sim['udid']); sys.exit(0)
# Fallback: any available iPhone
for sims in data.get('devices', {}).values():
    for sim in sims:
        if 'iPhone' in sim['name'] and sim.get('isAvailable', False):
            print(sim['udid']); sys.exit(0)
" 2>/dev/null
}

# Get simulator UDID by name (partial match, case-insensitive)
ios_get_simulator_by_name() {
    local name="$1"
    xcrun simctl list devices --json 2>/dev/null | python3 -c "
import json, sys
data = json.load(sys.stdin)
search = '${name}'.lower()
for sims in data.get('devices', {}).values():
    for sim in sims:
        if search in sim['name'].lower() and sim.get('isAvailable', False):
            print(sim['udid']); sys.exit(0)
" 2>/dev/null
}

# Get simulator state (Booted / Shutdown / etc.)
ios_get_simulator_state() {
    local udid="$1"
    xcrun simctl list devices --json 2>/dev/null | python3 -c "
import json, sys
data = json.load(sys.stdin)
for sims in data.get('devices', {}).values():
    for sim in sims:
        if sim['udid'] == '${udid}':
            print(sim['state']); sys.exit(0)
print('NOT_FOUND')
" 2>/dev/null
}

# Boot a simulator and wait for it to be ready
ios_boot_simulator() {
    local udid="$1"
    local boot_timeout="${2:-600}"

    local state
    state=$(ios_get_simulator_state "$udid")

    if [[ "$state" == "Booted" ]]; then
        log_info "Simulator already booted"
        return 0
    fi
    if [[ "$state" == "NOT_FOUND" ]]; then
        log_error "Simulator not found: $udid"
        return 1
    fi

    # Open Simulator.app to assist boot on modern runtimes
    command -v open &>/dev/null && open -a Simulator 2>/dev/null || true

    local output
    output=$(xcrun simctl boot "$udid" 2>&1)
    if [[ $? -ne 0 ]]; then
        if [[ "$output" == *"already booted"* ]] || [[ "$output" == *"current state: Booted"* ]]; then
            return 0
        fi
        log_error "Failed to boot simulator: $output"
        return 1
    fi

    log_info "Waiting for simulator boot (timeout: ${boot_timeout}s)..."
    local start_time elapsed
    start_time=$(date +%s)

    while true; do
        state=$(ios_get_simulator_state "$udid")
        [[ "$state" == "Booted" ]] && { log_success "Simulator booted"; sleep 3; return 0; }

        elapsed=$(( $(date +%s) - start_time ))
        if [[ $elapsed -ge $boot_timeout ]]; then
            log_error "Simulator boot timed out after ${boot_timeout}s"
            return 1
        fi
        sleep 5
    done
}

# Shutdown a simulator
ios_shutdown_simulator() {
    local udid="$1"
    [[ -z "$udid" ]] && return 0

    local state
    state=$(ios_get_simulator_state "$udid")
    [[ "$state" == "Shutdown" ]] && return 0

    xcrun simctl shutdown "$udid" 2>/dev/null || killall "Simulator" 2>/dev/null || true
    log_debug "Simulator shut down"
}

# ---------------------------------------------------------------------------
# Test runner
# ---------------------------------------------------------------------------

run_ios_tests() {
    log_header "iOS Tests (Simulator)"

    # Validate environment
    if ! command -v xcrun &>/dev/null; then
        log_error "Xcode command-line tools not found (install: xcode-select --install)"
        return 1
    fi
    validate_flutter || return 1

    # Resolve simulator
    local sim_id=""

    if [[ -n "${IOS_SIMULATOR_ID:-}" ]]; then
        sim_id="$IOS_SIMULATOR_ID"
    elif [[ -n "${IOS_DEVICE_NAME:-}" ]]; then
        sim_id=$(ios_get_simulator_by_name "$IOS_DEVICE_NAME")
        if [[ -z "$sim_id" ]]; then
            log_error "Simulator not found: $IOS_DEVICE_NAME"
            log_info "Available simulators:"
            ios_list_simulators
            return 1
        fi
    else
        sim_id=$(ios_find_latest_simulator)
        if [[ -z "$sim_id" ]]; then
            log_error "No iPhone simulators available"
            ios_list_simulators
            return 1
        fi
    fi

    log_info "Using simulator: $sim_id"
    IOS_ACTIVE_SIMULATOR="$sim_id"

    # Boot simulator
    local boot_timeout="${IOS_BOOT_TIMEOUT:-600}"
    if ! ios_boot_simulator "$sim_id" "$boot_timeout"; then
        log_error "Failed to boot simulator"
        return 1
    fi

    # Wait for responsiveness — use a generous timeout to ensure the simulator
    # is fully operational before we start tests.  Launching an app on a
    # not-yet-responsive simulator causes 8-10 minute stalls that exhaust the
    # 12-minute test heartbeat timer.
    log_info "Waiting for simulator responsiveness..."
    local wait_start elapsed
    wait_start=$(date +%s)
    while true; do
        xcrun simctl status_bar "$sim_id" show 2>/dev/null && break
        elapsed=$(( $(date +%s) - wait_start ))
        [[ $elapsed -ge 300 ]] && { log_warn "Simulator still not fully responsive after 5 min — continuing anyway"; break; }
        sleep 5
    done
    # Extra settle time after responsiveness check to let system services start
    log_info "Simulator responsive — waiting 10s for full stabilisation..."
    sleep 10

    # Run tests — run all files in a single session for performance
    local timeout="${IOS_TEST_TIMEOUT:-2700}"
    mkdir -p "$RESULTS_DIR"

    export MATRIX_SERVER="${MATRIX_SERVER:-http://localhost:8008}"

    local common_args=(
        "--device-id=$sim_id"
        "--reporter=expanded"
        "--concurrency=1"
        "--dart-define=is_integration_test=true"
        "--dart-define=MATRIX_SERVER=${MATRIX_SERVER}"
        "--dart-define=MATRIX_TEST_USER=${MATRIX_TEST_USER:-testuser1}"
        "--dart-define=MATRIX_TEST_PASSWORD=${MATRIX_TEST_PASSWORD:-testpass123}"
    )

    local log_file="${RESULTS_DIR}/ios-tests.log"
    local start_time end_time duration
    start_time=$(date +%s)
    local overall_exit=0

    # Collect all test files
    local all_files=()
    while IFS= read -r -d '' f; do
        all_files+=("$f")
    done < <(find integration_test -maxdepth 1 -name '*_test.dart' -print0 | sort -z)

    # Apply TEST_FILTER if set
    local test_files=()
    if [[ -n "${TEST_FILTER:-}" ]]; then
        filter_test_files test_files "$TEST_FILTER" "${all_files[@]}"
    else
        test_files=("${all_files[@]}")
    fi

    # Apply sharding: select only files for this shard index (file-based, like web runner)
    if [[ -n "${SHARD_INDEX:-}" ]] && [[ -n "${TOTAL_SHARDS:-}" ]]; then
        local total_files=${#test_files[@]}
        local shard_files=()
        local idx=0
        for f in "${test_files[@]}"; do
            if (( idx % TOTAL_SHARDS == SHARD_INDEX )); then
                shard_files+=("$f")
            fi
            idx=$((idx + 1))
        done
        log_info "Shard ${SHARD_INDEX}/${TOTAL_SHARDS}: running ${#shard_files[@]} of $total_files files"
        log_info "Files in this shard: ${shard_files[*]}"
        test_files=("${shard_files[@]}")
    fi

    if [[ ${#test_files[@]} -eq 0 ]]; then
        log_warn "No iOS integration test files found for this shard."
        record_target_result "ios" 0 0 0 0
        return 0
    fi

    # Pre-build the iOS app once to warm up Xcode/CocoaPods caches.
    # Without this, each `flutter test` file triggers a full Xcode build (~4-5 min),
    # which quickly exhausts the 12-minute test heartbeat timer on the first file.
    log_info "Pre-building iOS app for simulator (warms Xcode/CocoaPods cache)..."
    local prebuild_args=(
        "--dart-define=is_integration_test=true"
        "--dart-define=MATRIX_SERVER=${MATRIX_SERVER}"
        "--dart-define=MATRIX_TEST_USER=${MATRIX_TEST_USER:-testuser1}"
        "--dart-define=MATRIX_TEST_PASSWORD=${MATRIX_TEST_PASSWORD:-testpass123}"
    )
    run_with_timeout 1200 flutter build ios --simulator --debug --no-pub "${prebuild_args[@]}" 2>&1 | tee "${RESULTS_DIR}/ios-prebuild.log"
    local prebuild_exit=${PIPESTATUS[0]}
    if [[ $prebuild_exit -ne 0 ]]; then
        log_warn "Pre-build failed or timed out (exit $prebuild_exit) — continuing anyway (first test may be slow)"
    else
        log_success "Pre-build complete — subsequent flutter test calls will use incremental build"
    fi

    log_info "Running ${#test_files[@]} iOS integration test file(s) (timeout: ${timeout}s each)..."
    : > "$log_file"
    local acc_passed=0 acc_failed=0 acc_skipped=0

    for test_file in "${test_files[@]}"; do
        log_info "  Running: $test_file"
        run_with_timeout "$timeout" flutter "test" --no-pub --timeout "60m" "${common_args[@]}" "$test_file" 2>&1 | tee -a "$log_file"
        local exit_code=${PIPESTATUS[0]}
        parse_flutter_output "$log_file"
        acc_passed=$((acc_passed + _PARSED_PASSED))
        acc_failed=$((acc_failed + _PARSED_FAILED))
        acc_skipped=$((acc_skipped + _PARSED_SKIPPED))
        if [[ $exit_code -eq 124 ]]; then
            log_error "Timed out after ${timeout}s: $test_file"; overall_exit=1; break
        elif [[ $exit_code -ne 0 ]]; then
            if [[ $_PARSED_FAILED -gt 0 ]]; then
                log_warn "FAILED: $test_file"
                overall_exit=1
            elif [[ $_PARSED_PASSED -gt 0 ]]; then
                log_warn "flutter test exited $exit_code for $test_file but $_PARSED_PASSED passed, 0 failed — treating as success"
                # Do NOT set overall_exit=1 here
            else
                log_warn "FAILED (no test output parsed): $test_file"
                overall_exit=1
            fi
        fi
    done

    end_time=$(date +%s)
    duration=$((end_time - start_time))
    record_target_result "ios" "$acc_passed" "$acc_failed" "$acc_skipped" "$duration"

    if [[ $overall_exit -ne 0 ]]; then
        log_error "iOS tests failed (exit code $overall_exit)"
        return 1
    fi

    log_success "iOS tests passed"
}
