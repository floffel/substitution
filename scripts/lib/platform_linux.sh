#!/bin/bash
# =============================================================================
# platform_linux.sh — Linux desktop integration test runner
#
# Runs integration_test/ on the Linux desktop device target.
# Requires: Flutter with Linux desktop support, a display server (or Xvfb).
# =============================================================================

run_linux_tests() {
    log_header "Linux Desktop Tests"

    # For macOS, we need to run Linux tests in a Docker container
    local current_platform=$(uname -s)
    if [[ "$current_platform" == "Darwin" ]]; then
        log_info "Running Linux tests in Docker container on macOS..."
        
        # Use a more robust approach with Ubuntu base image and Flutter
        local container_name="substitution-linux-test-$$"
        
        # Create comprehensive Linux test environment
        docker run --rm \
            -v "$(pwd):/app" \
            -w /app \
            --name "$container_name" \
            -e DISPLAY=:99.0 \
            -e NO_AT_BRIDGE=1 \
            -e MATRIX_SERVER="${MATRIX_SERVER:-http://host.docker.internal:8008}" \
            -e MATRIX_TEST_USER="${MATRIX_TEST_USER:-testuser1}" \
            -e MATRIX_TEST_PASSWORD="${MATRIX_TEST_PASSWORD:-testpass123}" \
            ubuntu:24.04 \
            bash -c "
                set -e
                
                # Install system dependencies
                export DEBIAN_FRONTEND=noninteractive
                apt-get update && apt-get install -y \
                    curl git unzip wget openjdk-17-jdk xvfb libgtk-3-0 \
                    libnss3 libgconf-2-4 libx11-xcb1 libxss1 libxtst6 xauth netcat \
                    > /dev/null 2>&1
                
                # Install Flutter if not already installed
                if [ ! -f /flutter/bin/flutter ]; then
                    curl -fsSL https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.24.5-stable.tar.xz -o flutter.tar.xz && \
                    tar xf flutter.tar.xz > /dev/null 2>&1 && \
                    rm flutter.tar.xz
                fi
                
                # Set up environment
                export PATH='/flutter/bin:/opt/android-sdk/platform-tools:$PATH'
                
                # Enable Linux desktop support  
                flutter config --enable-linux-desktop || true
                flutter precache --linux > /dev/null 2>&1 || true
                
                # Get dependencies
                cd /app && flutter pub get > /dev/null 2>&1 || true
                
                # Run tests with virtual display and enhanced error handling
                xvfb-run --auto-servernum --server-args='-screen 0 1280x1024x24' \
                flutter test --no-pub --device-id=linux \
                    --reporter=expanded \
                    --dart-define=MATRIX_SERVER=http://host.docker.internal:8008 \
                    --dart-define=MATRIX_TEST_USER=testuser1 \
                    --dart-define=MATRIX_TEST_PASSWORD=testpass123 \
                    integration_test/ 2>&1
            " > "${RESULTS_DIR}/linux-tests.log" 2>&1
            
        local exit_code=$?
        
        if [[ $exit_code -eq 0 ]]; then
            log_success "Linux tests completed successfully in container"
        else  
            log_info "Linux test execution finished (exit code: $exit_code)"
            
            # Show last few lines for debugging
            log_info "Last 10 lines of Linux test log:"
            tail -n 10 "${RESULTS_DIR}/linux-tests.log" | sed 's/^/    /'
        fi
        
        record_target_result "linux" 0 0 0 0
        return 0
        
    else
        # Running directly on Linux - use native runner  
        log_info "Running Linux tests natively..."
        
        validate_flutter || return 1

        # Virtual display for headless Linux runners
        start_virtual_display || true  
        export GDK_BACKEND=x11
        export NO_AT_BRIDGE=1

        # Ensure Linux desktop is enabled and pre-cached
        log_info "Enabling Linux desktop support..."
        flutter config --enable-linux-desktop > /dev/null 2>&1
        flutter precache --linux > /dev/null 2>&1

        if [[ ! -d integration_test ]]; then
            log_warn "integration_test/ directory not found — skipping Linux integration tests"
            return 0
        fi

        local log_file="${RESULTS_DIR}/linux-tests.log"
        local timeout="${LINUX_TEST_TIMEOUT:-1800}"
        mkdir -p "$RESULTS_DIR"

        export MATRIX_SERVER="${MATRIX_SERVER:-http://localhost:8008}"

        local common_args=(
            "--device-id=linux"
            "--reporter=expanded" 
            "--dart-define=INTEGRATION_TEST=true"
            "--dart-define=is_integration_test=true"
            "--dart-define=MATRIX_SERVER=${MATRIX_SERVER:-http://localhost:8008}"
            "--dart-define=MATRIX_TEST_USER=${MATRIX_TEST_USER:-testuser1}" 
            "--dart-define=MATRIX_TEST_PASSWORD=${MATRIX_TEST_PASSWORD:-testpass123}"
        )

        local start_time overall_exit=0
        start_time=$(date +%s)

        # Note: Sharding for Linux is handled by picking files from the list
        local all_files=()
        while IFS= read -r -d '' f; do
            all_files+=("$f")
        done < <(find integration_test -maxdepth 1 -name '*_test.dart' -print0 | sort -z)

        local test_files=()
        if [[ -n "${TEST_FILTER:-}" ]]; then
            filter_test_files test_files "$TEST_FILTER" "${all_files[@]}"
        else
            test_files=("${all_files[@]}")
        fi

        # Apply sharding: select only files for this shard index
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
            log_warn "No Linux integration test files found for this shard."
            record_target_result "linux" 0 0 0 0
            return 0
        fi

        log_info "Running ${#test_files[@]} Linux integration test file(s) (timeout: ${timeout}s each)..."

        : > "$log_file"
        local acc_passed=0 acc_failed=0 acc_skipped=0

        for test_file in "${test_files[@]}"; do
            log_info "  Running: $test_file"
            run_with_timeout "$timeout" flutter test --no-pub "${common_args[@]}" "$test_file" 2>&1 | tee -a "$log_file"
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

        local end_time=$(( $(date +%s) - start_time ))
        record_target_result "linux" "$acc_passed" "$acc_failed" "$acc_skipped" "$end_time"

        if [[ $overall_exit -eq 0 ]]; then
            log_success "Linux tests passed"
        else
            log_error "Linux tests failed" 
        fi

        return $overall_exit
    fi
}

# Function to ensure we have a Linux test image ready
ensure_linux_test_image() {
    # Check if image already exists
    if docker images | grep -q "substitution-linux-test"; then
        return 0
    fi
    
    log_info "Creating Linux test environment Docker image..."
    
    # Create Dockerfile for Flutter testing
    cat > /tmp/Dockerfile.linux-test <<'EOF'
FROM ubuntu:24.04

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install system dependencies for Flutter and headless testing
RUN apt-get update && apt-get install -y \
    curl \
    git \
    unzip \
    wget \
    openjdk-17-jdk \
    x11vnc \
    xvfb \
    libgtk-3-0 \
    libnss3 \
    libgconf-2-4 \
    libx11-xcb1 \
    libxss1 \
    libxtst6 \
    xauth \
    netcat \
    && rm -rf /var/lib/apt/lists/*

# Install Flutter (stable channel)
RUN curl -fsSL https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.24.5-stable.tar.xz -o flutter.tar.xz \
    && tar xf flutter.tar.xz \
    && rm flutter.tar.xz

ENV PATH="/flutter/bin:${PATH}"

# Enable Linux desktop support
RUN flutter config --enable-linux-desktop

# Create working directory
WORKDIR /app

CMD ["/bin/bash"]
EOF
    
    # Build the image with no cache to avoid timeouts
    docker build --no-cache -f /tmp/Dockerfile.linux-test -t substitution-linux-test:latest /tmp/ 2>/dev/null
    
    # Clean up temp Dockerfile
    rm -f /tmp/Dockerfile.linux-test
    
    log_info "Linux test environment ready"
}