#!/bin/bash
################################################################################
# iOS Simulator Utility Functions
#
# Helper functions for managing iOS simulators on macOS
# Provides functions to list, create, boot, shutdown, and manage simulators
#
# Usage: source ./scripts/ios-simulator-utils.sh
################################################################################

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

log_debug() {
    if [[ "${VERBOSE:-false}" == "true" ]]; then
        echo -e "${BLUE}[DEBUG]${NC} $*"
    fi
}

# Check if Xcode command line tools are available
check_xcode() {
    if ! command -v xcrun &> /dev/null; then
        log_error "Xcode command line tools not found"
        log_info "Install with: xcode-select --install"
        return 1
    fi
    
    if ! command -v xcrun &> /dev/null; then
        log_error "xcrun not found in PATH"
        return 1
    fi
    
    log_success "Xcode command line tools are available"
    return 0
}

# List all available iOS simulators
list_simulators() {
    log_info "Available iOS simulators:"
    xcrun simctl list devices --json | python3 -c "
import json, sys
data = json.load(sys.stdin)
devices = data.get('devices', {})
for runtime, sims in devices.items():
    if 'iOS' in runtime or 'iPhone' in str(sims):
        print(f'\n{runtime}:')
        for sim in sims:
            state = '(running)' if sim['state'] == 'Booted' else '(available)'
            print(f'  {sim[\"name\"]:30} {state:15} UDID: {sim[\"udid\"]}')" 2>/dev/null || \
    xcrun simctl list devices | grep -i iphone
}

# Find the latest iPhone simulator
find_latest_iphone_simulator() {
    log_debug "Finding latest iPhone simulator..."
    
    # Try to find iPhone 15 or latest
    local simulator_id=$(xcrun simctl list devices --json 2>/dev/null | python3 -c "
import json, sys, re
try:
    data = json.load(sys.stdin)
    devices = data.get('devices', {})
    
    # Prioritize iPhone 15 first, then iPhone 14, etc.
    priorities = ['iPhone 15', 'iPhone 14', 'iPhone 13', 'iPhone 12', 'iPhone 11']
    
    for priority in priorities:
        for runtime, sims in devices.items():
            for sim in sims:
                if priority in sim['name'] and sim['isAvailable']:
                    print(sim['udid'])
                    sys.exit(0)
    
    # Fallback: get any available iPhone
    for runtime, sims in devices.items():
        for sim in sims:
            if 'iPhone' in sim['name'] and sim['isAvailable']:
                print(sim['udid'])
                sys.exit(0)
    
    print('')
except:
    print('')
" 2>/dev/null)
    
    if [[ -z "$simulator_id" ]]; then
        log_error "No iPhone simulators found"
        return 1
    fi
    
    echo "$simulator_id"
    return 0
}

# Get simulator ID by name
get_simulator_id_by_name() {
    local sim_name="$1"
    
    if [[ -z "$sim_name" ]]; then
        log_error "Simulator name required"
        return 1
    fi
    
    log_debug "Looking for simulator: $sim_name"
    
    local simulator_id=$(xcrun simctl list devices --json 2>/dev/null | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    devices = data.get('devices', {})
    search_name = '$sim_name'
    
    for runtime, sims in devices.items():
        for sim in sims:
            if search_name.lower() in sim['name'].lower():
                print(sim['udid'])
                sys.exit(0)
    print('')
except:
    print('')
" 2>/dev/null)
    
    if [[ -z "$simulator_id" ]]; then
        log_error "Simulator not found: $sim_name"
        return 1
    fi
    
    echo "$simulator_id"
    return 0
}

# Get simulator status
get_simulator_status() {
    local simulator_id="$1"
    
    if [[ -z "$simulator_id" ]]; then
        log_error "Simulator ID required"
        return 1
    fi
    
    log_debug "Checking status of simulator: $simulator_id"
    
    local status=$(xcrun simctl list devices --json 2>/dev/null | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    devices = data.get('devices', {})
    search_id = '$simulator_id'
    
    for runtime, sims in devices.items():
        for sim in sims:
            if sim['udid'] == search_id:
                print(sim['state'])
                sys.exit(0)
    print('NOT_FOUND')
except:
    print('ERROR')
" 2>/dev/null)
    
    echo "$status"
    return 0
}

# Boot iOS simulator
boot_simulator() {
    local simulator_id="$1"
    local timeout="${2:-300}"
    
    if [[ -z "$simulator_id" ]]; then
        log_error "Simulator ID required"
        return 1
    fi
    
    log_info "Booting simulator: $simulator_id"
    
    # Check current status
    local status=$(get_simulator_status "$simulator_id")
    
    if [[ "$status" == "Booted" ]]; then
        log_info "Simulator is already booted"
        return 0
    fi
    
    if [[ "$status" == "NOT_FOUND" ]]; then
        log_error "Simulator not found: $simulator_id"
        return 1
    fi
    
    # Boot the simulator
    if ! xcrun simctl boot "$simulator_id" 2>&1; then
        log_error "Failed to boot simulator"
        return 1
    fi
    
    # Wait for simulator to boot
    log_info "Waiting for simulator to boot (timeout: ${timeout}s)..."
    
    local start_time=$(date +%s)
    local elapsed=0
    
    while [[ $elapsed -lt $timeout ]]; do
        local status=$(get_simulator_status "$simulator_id")
        
        if [[ "$status" == "Booted" ]]; then
            log_success "Simulator booted successfully"
            # Give it a moment to fully settle
            sleep 3
            return 0
        fi
        
        if [[ "$status" == "ERROR" ]] || [[ "$status" == "NOT_FOUND" ]]; then
            log_error "Error checking simulator status"
            return 1
        fi
        
        elapsed=$(($(date +%s) - start_time))
        log_debug "Waiting for boot... ($elapsed/$timeout)s"
        sleep 5
    done
    
    log_error "Timeout waiting for simulator to boot (${timeout}s exceeded)"
    return 1
}

# Shutdown iOS simulator
shutdown_simulator() {
    local simulator_id="$1"
    
    if [[ -z "$simulator_id" ]]; then
        log_error "Simulator ID required"
        return 1
    fi
    
    log_info "Shutting down simulator: $simulator_id"
    
    local status=$(get_simulator_status "$simulator_id")
    
    if [[ "$status" == "Shutdown" ]]; then
        log_info "Simulator is already shut down"
        return 0
    fi
    
    if [[ "$status" == "NOT_FOUND" ]]; then
        log_error "Simulator not found: $simulator_id"
        return 1
    fi
    
    if ! xcrun simctl shutdown "$simulator_id" 2>&1; then
        log_warn "Failed to gracefully shutdown simulator, attempting force shutdown..."
        killall "Simulator" 2>/dev/null || true
        sleep 2
    fi
    
    log_success "Simulator shut down"
    return 0
}

# Erase simulator (reset to clean state)
erase_simulator() {
    local simulator_id="$1"
    
    if [[ -z "$simulator_id" ]]; then
        log_error "Simulator ID required"
        return 1
    fi
    
    log_warn "Erasing simulator: $simulator_id"
    
    # Make sure simulator is shut down first
    shutdown_simulator "$simulator_id" || true
    sleep 1
    
    if ! xcrun simctl erase "$simulator_id" 2>&1; then
        log_error "Failed to erase simulator"
        return 1
    fi
    
    log_success "Simulator erased successfully"
    return 0
}

# Install app on simulator
install_app() {
    local simulator_id="$1"
    local app_path="$2"
    
    if [[ -z "$simulator_id" ]] || [[ -z "$app_path" ]]; then
        log_error "Simulator ID and app path required"
        return 1
    fi
    
    if [[ ! -d "$app_path" ]]; then
        log_error "App not found: $app_path"
        return 1
    fi
    
    log_info "Installing app on simulator: $app_path"
    
    if ! xcrun simctl install "$simulator_id" "$app_path" 2>&1; then
        log_error "Failed to install app"
        return 1
    fi
    
    log_success "App installed successfully"
    return 0
}

# Get app bundle ID from app
get_bundle_id() {
    local app_path="$1"
    
    if [[ ! -d "$app_path" ]]; then
        log_error "App not found: $app_path"
        return 1
    fi
    
    # Extract bundle ID from Info.plist
    local bundle_id=$(/usr/libexec/PlistBuddy -c "Print CFBundleIdentifier" "$app_path/Info.plist" 2>/dev/null)
    
    if [[ -z "$bundle_id" ]]; then
        log_error "Could not extract bundle ID from app"
        return 1
    fi
    
    echo "$bundle_id"
    return 0
}

# Launch app on simulator
launch_app() {
    local simulator_id="$1"
    local bundle_id="$2"
    
    if [[ -z "$simulator_id" ]] || [[ -z "$bundle_id" ]]; then
        log_error "Simulator ID and bundle ID required"
        return 1
    fi
    
    log_info "Launching app on simulator: $bundle_id"
    
    if ! xcrun simctl launch "$simulator_id" "$bundle_id" 2>&1; then
        log_error "Failed to launch app"
        return 1
    fi
    
    log_success "App launched successfully"
    return 0
}

# Get devices list in JSON format (for scripting)
get_devices_json() {
    xcrun simctl list devices --json 2>/dev/null
}

# Export functions for sourcing
export -f log_info log_success log_warn log_error log_debug
export -f check_xcode list_simulators find_latest_iphone_simulator
export -f get_simulator_id_by_name get_simulator_status
export -f boot_simulator shutdown_simulator erase_simulator
export -f install_app get_bundle_id launch_app get_devices_json
