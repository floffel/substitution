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

    # First try the built-in timeout commands
    if command -v timeout &>/dev/null; then
        timeout "$seconds" "$@"; return $?
    fi
    if command -v gtimeout &>/dev/null; then
        gtimeout "$seconds" "$@"; return $?
    fi

    # Enhanced Python timeout with better error handling
    if command -v python3 &>/dev/null; then
        local temp_script="/tmp/flutter_test_timeout_$$.py"
        
        # Create robust Python timeout script
        cat > "$temp_script" <<'PYTHON_TIMEOUT_SCRIPT'
#!/usr/bin/env python3
import subprocess, sys, json, os, signal

def timeout_handler(signum, frame):
    print("Process timed out", file=sys.stderr)
    sys.exit(124)

# Set up signal handler for timeout
signal.signal(signal.SIGALRM, timeout_handler)

try:
    # Parse command arguments more carefully
    if len(sys.argv) < 2:
        print("Usage: timeout.py seconds [command...]", file=sys.stderr)
        sys.exit(1)
    
    timeout_seconds = int(sys.argv[1])
    
    # Handle the command arguments which might be JSON-encoded
    if len(sys.argv) == 3:
        # Try to parse as JSON first
        try:
            cmd_args = json.loads(sys.argv[2])
            if not isinstance(cmd_args, list):
                raise ValueError("Command args must be a list")
        except (json.JSONDecodeError, ValueError):
            # Fall back to treating as direct arguments
            cmd_args = sys.argv[2:]
    else:
        # Direct command line arguments starting from index 2
        cmd_args = sys.argv[2:]
    
    # Set the alarm for timeout
    signal.alarm(timeout_seconds)
    
    # Run the command
    result = subprocess.run(cmd_args, timeout=timeout_seconds)
    
    # Cancel alarm if command completed successfully
    signal.alarm(0)
    
    sys.exit(result.returncode)

except subprocess.TimeoutExpired:
    print(f"Command timed out after {timeout_seconds} seconds", file=sys.stderr)
    sys.exit(124)

except Exception as e:
    print(f"Error running command: {e}", file=sys.stderr)
    sys.exit(1)

PYTHON_TIMEOUT_SCRIPT

        # Use JSON encoding for command arguments to handle complex quoting
        if [[ $# -gt 0 ]]; then
            # Encode all arguments as a JSON array
            local json_args=$(printf '%s\n' "$@" | python3 -c "
import sys, json
args = []
for line in sys.stdin:
    if line.strip():  # Skip empty lines
        args.append(line.rstrip('\n'))
print(json.dumps(args))
" 2>/dev/null)

            if [[ -n "$json_args" ]]; then
                python3 "$temp_script" "$seconds" "$json_args"
            else
                # Fallback to direct execution if JSON encoding fails
                python3 "$temp_script" "$seconds"
            fi
        else
            # Just the timeout, no command
            python3 "$temp_script" "$seconds"
        fi
        
        local exit_code=$?
        rm -f "$temp_script"
        return $exit_code
    fi

    # Perl fallback with better error handling
    if command -v perl &>/dev/null; then
        # Run in subshell to prevent hanging
        ( 
            perl -e '
                use POSIX ":sys_wait_h";
                my $timeout = shift @ARGV;
                local %ENV;
                
                # Set up timeout using alarm
                eval {
                    alarm($timeout);
                    
                    my $cmd = join(" ", @ARGV);
                    system($cmd);
                    
                    alarm(0);  # Cancel timeout
                };
                
                if ($@) {
                    warn "Timeout occurred: $@";
                    exit(124);
                }
                
                # Check if the process exited with error
                my $status = $? >> 8;
                exit($status);
            ' "$seconds" "$@"
        )
        
        return $?
    fi

    log_warn "No timeout utility found; running without timeout"
    
    # Fallback: run command and hope it completes
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
        echo "--shard-index=$SHARD_INDEX" "--total-shards=$TOTAL_SHARDS"
    fi
}

# Filter an array of test file paths by TEST_FILTER (glob matched against basename).
# Usage:
#   filter_test_files filtered_array "${test_files[@]}"
#   then use "${filtered_array[@]}"
#
# Because bash 3.2 (macOS default) does not support namerefs (local -n),
# this function prints the matched paths separated by newlines and must be
# called with a process substitution or read loop.  The caller-friendly
# wrapper below handles the boilerplate.
#
# Preferred call pattern (works on bash 3.2+):
#   local test_files=()
#   filter_test_files test_files "${all_files[@]}"
# where test_files is set as a global from within this function via eval.
filter_test_files() {
    local _varname="$1"; shift
    local _filter="$1"; shift
    local _matched=()
    for f in "$@"; do
        local base
        base=$(basename "$f")
        # Match if: 
        # 1. No filter
        # 2. Filter matches basename exactly (or glob)
        # 3. Filter matches the full path as a substring
        if [[ -z "$_filter" ]] || [[ "$base" == $_filter ]] || [[ "$f" == *"$_filter"* ]]; then
            _matched+=("$f")
        fi
    done
    if [[ -n "$_filter" ]]; then
        if [[ ${#_matched[@]} -eq 0 ]]; then
            log_warn "Filter '$_filter' matched no files"
        else
            log_info "Filter '$_filter' selected ${#_matched[@]} file(s): ${_matched[*]}"
        fi
    fi
    # Assign to the caller's variable using eval (bash 3.2 compatible)
    # We build a quoted list so paths with spaces are handled correctly.
    local _q=""
    for f in "${_matched[@]}"; do
        _q+=" $(printf '%q' "$f")"
    done
    eval "${_varname}=(${_q})"
}
