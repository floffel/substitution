#!/bin/bash
# =============================================================================
# common.sh — Shared utilities: logging, colors, timeout, OS detection
# =============================================================================

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

# Logging functions
log_info()    { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[OK]${NC} $*"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }
log_debug()   { [[ "${VERBOSE:-false}" == "true" ]] && echo -e "${BLUE}[DEBUG]${NC} $*"; return 0; }

log_header() {
    echo ""
    echo -e "${BOLD}━━━ $* ━━━${NC}"
    echo ""
}

# Detect host OS: darwin, linux, or windows (WSL)
detect_os() {
    case "$(uname -s)" in
        Darwin) echo "darwin" ;;
        Linux)
            if grep -qEi "(microsoft|wsl)" /proc/version 2>/dev/null; then
                echo "windows"
            else
                echo "linux"
            fi
            ;;
        MINGW*|MSYS*|CYGWIN*) echo "windows" ;;
        *) echo "unknown" ;;
    esac
}

# Run a command with a timeout (seconds). Returns 124 on timeout.
# Tries: timeout (Linux), gtimeout (macOS/brew), python3, perl fallbacks.
run_with_timeout() {
    local seconds="$1"; shift

    if command -v timeout &>/dev/null; then
        timeout "$seconds" "$@"; return $?
    fi
    if command -v gtimeout &>/dev/null; then
        gtimeout "$seconds" "$@"; return $?
    fi
    if command -v python3 &>/dev/null; then
        python3 - "$seconds" "$@" <<'PY'
import subprocess, sys
try:
    r = subprocess.run(sys.argv[2:], timeout=int(sys.argv[1]))
    sys.exit(r.returncode)
except subprocess.TimeoutExpired:
    sys.exit(124)
PY
        return $?
    fi
    if command -v perl &>/dev/null; then
        perl -e 'alarm shift; exec @ARGV' "$seconds" "$@"; return $?
    fi

    log_warn "No timeout utility found; running without timeout"
    "$@"
}

# Validate that flutter CLI is available
validate_flutter() {
    if ! command -v flutter &>/dev/null; then
        log_error "flutter not found in PATH"
        return 1
    fi
    log_debug "Flutter found: $(command -v flutter)"
    return 0
}

# Fetch flutter dependencies
fetch_dependencies() {
    log_info "Fetching Flutter dependencies..."
    if ! flutter pub get 2>&1 | tail -5; then
        log_error "flutter pub get failed"
        return 1
    fi
    log_success "Dependencies fetched"
}

# Start Xvfb virtual display (Linux only, for headless GUI tests)
start_virtual_display() {
    if [[ -n "$DISPLAY" ]]; then
        log_debug "DISPLAY already set: $DISPLAY"
        return 0
    fi
    if [[ "$(detect_os)" == "darwin" ]]; then
        log_debug "macOS: Xvfb not needed"
        return 0
    fi
    if ! command -v Xvfb &>/dev/null; then
        log_warn "Xvfb not found and DISPLAY is not set"
        return 1
    fi
    log_info "Starting Xvfb virtual display..."
    Xvfb :99 -screen 0 1280x720x24 -ac -retro &>/dev/null &
    XVFB_PID=$!
    export DISPLAY=:99
    sleep 2
    log_debug "Xvfb started (PID $XVFB_PID)"
}

# Kill Xvfb if we started it
stop_virtual_display() {
    if [[ -n "${XVFB_PID:-}" ]]; then
        kill "$XVFB_PID" 2>/dev/null || true
        unset XVFB_PID
    fi
}

# Generate Flutter shard arguments if SHARD_INDEX and TOTAL_SHARDS are set
get_shard_args() {
    if [[ -n "${SHARD_INDEX:-}" ]] && [[ -n "${TOTAL_SHARDS:-}" ]]; then
        echo "--shard=$SHARD_INDEX" "--total-shards=$TOTAL_SHARDS"
    fi
}
