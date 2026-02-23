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
    local boot_timeout="${2:-300}"

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
    local boot_timeout="${IOS_BOOT_TIMEOUT:-300}"
    if ! ios_boot_simulator "$sim_id" "$boot_timeout"; then
        log_error "Failed to boot simulator"
        return 1
    fi

    # Wait for responsiveness
    log_info "Waiting for simulator responsiveness..."
    local wait_start elapsed
    wait_start=$(date +%s)
    while true; do
        xcrun simctl status_bar "$sim_id" show 2>/dev/null && break
        elapsed=$(( $(date +%s) - wait_start ))
        [[ $elapsed -ge 60 ]] && { log_warn "Simulator may not be fully responsive"; break; }
        sleep 2
    done

    # Run tests — run all files in a single session for performance
    local timeout="${IOS_TEST_TIMEOUT:-1800}"
    mkdir -p "$RESULTS_DIR"

    export MATRIX_SERVER="${MATRIX_SERVER:-http://localhost:8008}"

    local common_args=(
        "--device-id=$sim_id"
        "--reporter=compact"
        "--dart-define=MATRIX_SERVER=${MATRIX_SERVER}"
        "--dart-define=MATRIX_TEST_USER=${MATRIX_TEST_USER:-testuser1}"
        "--dart-define=MATRIX_TEST_PASSWORD=${MATRIX_TEST_PASSWORD:-testpass123}"
    )

    local log_file="${RESULTS_DIR}/ios-tests.log"
    local start_time end_time duration
    start_time=$(date +%s)
    local overall_exit=0

    if [[ -n "${TEST_FILTER:-}" ]]; then
        # Per-file filtered mode
        local all_files=()
        while IFS= read -r -d '' f; do
            all_files+=("$f")
        done < <(find integration_test -maxdepth 1 -name '*_test.dart' -print0 | sort -z)

        local test_files=()
        filter_test_files test_files "$TEST_FILTER" "${all_files[@]}"

        if [[ ${#test_files[@]} -eq 0 ]]; then
            log_warn "No iOS integration test files remain after applying filter."
            record_target_result "ios" 0 0 0 0
            return 0
        fi

        log_info "Running ${#test_files[@]} filtered integration test(s) on iOS (timeout: ${timeout}s each)..."
        : > "$log_file"
        local acc_passed=0 acc_failed=0 acc_skipped=0

        for test_file in "${test_files[@]}"; do
            log_info "  Running: $test_file"
            run_with_timeout "$timeout" flutter "test" "${common_args[@]}" "$test_file" 2>&1 | tee -a "$log_file"
            local exit_code=${PIPESTATUS[0]}
            parse_flutter_output "$log_file"
            acc_passed=$((acc_passed + _PARSED_PASSED))
            acc_failed=$((acc_failed + _PARSED_FAILED))
            acc_skipped=$((acc_skipped + _PARSED_SKIPPED))
            if [[ $exit_code -eq 124 ]]; then
                log_error "Timed out after ${timeout}s: $test_file"; overall_exit=1; break
            elif [[ $exit_code -ne 0 ]] && [[ $_PARSED_FAILED -gt 0 ]]; then
                overall_exit=1
            fi
        done

        end_time=$(date +%s)
        duration=$((end_time - start_time))
        record_target_result "ios" "$acc_passed" "$acc_failed" "$acc_skipped" "$duration"
    else
        # Bulk mode
        log_info "Running all integration tests on iOS (timeout: ${timeout}s)..."
        local shard_args=()
        read -r -a shard_args <<< "$(get_shard_args)"

        run_with_timeout "$timeout" flutter "test" "integration_test/" \
            "${common_args[@]}" "${shard_args[@]}" 2>&1 | tee "$log_file"
        overall_exit=${PIPESTATUS[0]}

        end_time=$(date +%s)
        duration=$((end_time - start_time))
        parse_flutter_output "$log_file"
        record_target_result "ios" "$_PARSED_PASSED" "$_PARSED_FAILED" "$_PARSED_SKIPPED" "$duration"
    fi

    if [[ $overall_exit -eq 124 ]]; then
        log_error "iOS tests timed out after ${timeout}s"
        return 1
    elif [[ $overall_exit -ne 0 ]]; then
        log_error "iOS tests failed (exit code $overall_exit)"
        return 1
    fi

    log_success "iOS tests passed"
}
