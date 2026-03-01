#!/bin/bash
# =============================================================================
# containerized_linux_runner.sh — Run Linux tests in Docker on macOS/Windows
#
# This allows running Flutter Linux desktop integration tests from any host OS
# by executing them inside a Docker container that matches the CI environment.
# =============================================================================

run_containerized_linux_tests() {
    local project_root="$1"
    
    # Create Docker image if it doesn't exist
    create_linux_test_image
    
    # Run tests in container matching GitHub CI environment
    docker run --rm \
        -v "${project_root}:/app" \
        -w /app \
        -e MATRIX_SERVER="${MATRIX_SERVER:-http://host.docker.internal:8008}" \
        -e MATRIX_TEST_USER="${MATRIX_TEST_USER:-testuser1}" \
        -e MATRIX_TEST_PASSWORD="${MATRIX_TEST_PASSWORD:-testpass123}" \
        substitution-linux-test:latest \
        xvfb-run --auto-servernum --server-args="-screen 0 1280x1024x24" \
        ./scripts/test.sh linux --no-docker "$@"
}

create_linux_test_image() {
    # Check if image already exists
    if docker images | grep -q "substitution-linux-test"; then
        return 0
    fi
    
    log_info "Creating Linux test environment Docker image..."
    
    # Create Dockerfile for Flutter + Android testing
    cat > /tmp/Dockerfile.linux-test <<'EOF'
FROM ubuntu:24.04

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install system dependencies for Flutter and Android SDK
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

# Set up xvfb for headless testing
RUN mkdir -p /tmp/.X11-unix && chmod 1777 /tmp/.X11-unix

# Install Flutter (stable channel)
RUN curl -fsSL https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.24.5-stable.tar.xz -o flutter.tar.xz \
    && tar xf flutter.tar.xz \
    && rm flutter.tar.xz

ENV PATH="/flutter/bin:${PATH}"

# Enable Linux desktop support
RUN flutter config --enable-linux-desktop

# Set Android SDK environment variables
ENV ANDROID_SDK_ROOT="/opt/android-sdk"
ENV ANDROID_HOME="/opt/android-sdk"

# Install Android SDK command-line tools
RUN mkdir -p /opt/android-sdk/cmdline-tools \
    && cd /opt/android-sdk/cmdline-tools \
    && wget -q https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip \
    && unzip -q commandlinetools-linux-11076708_latest.zip \
    && rm commandlinetools-linux-11076708_latest.zip \
    && mkdir latest \
    && mv cmdline-tools/* latest/ 2>/dev/null || true \
    && rm -rf cmdline-tools

ENV PATH="${PATH}:/opt/android-sdk/platform-tools:/opt/android-sdk/cmdline-tools/latest/bin"

# Install Android SDK platforms and build tools
RUN yes | sdkmanager --licenses || true
RUN sdkmanager "platform-tools" \
    "build-tools;36.0.0" \
    "platforms;android-36"

# Install Docker CLI and docker-compose
RUN curl -fsSL https://get.docker.com/builds/Linux/x86_64/docker-27.3.1.tgz -o docker.tgz \
    && tar xzf docker.tgz \
    && mv docker/* /usr/local/bin/ \
    && rm docker.tgz

# Create working directory
WORKDIR /app

# Set permissions for Docker socket access
RUN groupadd -f docker && usermod -aG docker \$USER || true

CMD ["/bin/bash"]
EOF
    
    # Build the image
    docker build -f /tmp/Dockerfile.linux-test -t substitution-linux-test:latest /tmp/ 2>/dev/null
    
    # Clean up temp Dockerfile
    rm -f /tmp/Dockerfile.linux-test
    
    log_info "Linux test environment ready"
}

# Check if we're already in a container
is_running_in_container() {
    [[ -f /.dockerenv ]]
}

# Main entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if is_running_in_container; then
        log_info "Already running in container, executing Linux tests directly"
        # We're inside the container already - just run the tests
        cd /app || exit 1
        
        # Set up xvfb for headless operation
        export DISPLAY=:99.0
        export NO_AT_BRIDGE=1
        
        # Run the actual test script
        ./scripts/test.sh linux --no-docker "$@"
    else
        # We're on the host OS - use Docker to run tests
        project_root=$(pwd)
        log_info "Running Linux tests in Docker container..."
        run_containerized_linux_tests "$project_root" "$@"
    fi
fi