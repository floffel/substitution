FROM ubuntu:22.04

ENV TZ=UTC
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# Install dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    clang \
    curl \
    git \
    ninja-build \
    pkg-config \
    unzip \
    xz-utils \
    zip \
    libglu1-mesa \
    libgtk-3-dev \
    python3 \
    llvm-14-tools \
    lld \
    binutils \
    xvfb \
    x11-utils \
    dbus \
    libsqlite3-0 \
    libsqlite3-dev \
    && rm -rf /var/lib/apt/lists/*

# Install Flutter
ENV FLUTTER_HOME=/opt/flutter
RUN git clone https://github.com/flutter/flutter.git -b stable $FLUTTER_HOME
ENV PATH=$FLUTTER_HOME/bin:$PATH

# Configure Flutter for testing
RUN flutter config --no-analytics && flutter precache

WORKDIR /project

