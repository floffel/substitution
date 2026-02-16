# iOS Testing with Flutter on Apple Silicon macOS

## Overview

This document explains how to run Flutter integration tests on iOS using the native iOS Simulator on macOS. The iOS Simulator provides full compatibility with Apple Silicon Macs and offers a faster, more reliable testing environment compared to Android emulation.

## Why iOS Simulator Instead of Android Emulator?

| Aspect | iOS Simulator | Android Emulator |
|--------|---------------|------------------|
| **Apple Silicon Support** | ✓ Native support | ✗ Requires Rosetta 2 or containers |
| **Performance** | Fast, minimal overhead | Slower, requires virtualization |
| **Setup Complexity** | Simple (included with Xcode) | Complex (SDK, tools, AVD) |
| **Test Speed** | 5-15 seconds for typical tests | 20-60+ seconds per test |
| **Development Experience** | Excellent, tight Xcode integration | Good, but more debugging needed |

## Prerequisites

### System Requirements

- **macOS 11.0 or later** (ARM64 architecture)
- **Xcode 14.0 or later** (with iOS SDK)
- **Flutter 3.0 or later**
- **10GB free disk space** (for Xcode and simulators)
- **Command line tools installed**

### Installation Steps

#### 1. Install Xcode Command Line Tools

```bash
# Install command line tools
xcode-select --install

# Verify installation
xcode-select -p
# Expected output: /Applications/Xcode.app/Contents/Developer
```

#### 2. Verify iOS SDK Installation

```bash
# List installed iOS SDKs
xcrun simctl list runtimes

# Expected output similar to:
# iOS 17.2 (17.2) - com.apple.CoreSimulator.SimRuntime.iOS-17-2
```

#### 3. Verify Flutter Setup

```bash
# Check Flutter installation
flutter doctor

# Check iOS support
flutter doctor -v | grep -i ios

# Expected: iOS toolchain is correctly configured
```

#### 4. Create/List Available iOS Simulators

```bash
# List available simulators
xcrun simctl list devices

# You should see simulators like:
# iPhone 15 (XXXXX) (Shutdown)
# iPhone 14 (XXXXX) (Shutdown)
```

If no simulators exist, create one:

```bash
# Create an iPhone 15 simulator
xcrun simctl create "iPhone 15" \
  com.apple.CoreSimulator.SimDeviceType.iPhone-15 \
  com.apple.CoreSimulator.SimRuntime.iOS-17-2
```

## Running iOS Tests

### Quick Start

The simplest way to run tests:

```bash
# Run tests with default settings (latest iPhone simulator)
./scripts/run-ios-tests.sh

# The script will:
# 1. Find the latest iPhone simulator available
# 2. Boot it
# 3. Run all integration tests
# 4. Display results
# 5. Shut down the simulator
```

### Advanced Usage

#### Run on Specific Device

```bash
# Run on iPhone 14
./scripts/run-ios-tests.sh --device-name "iPhone 14"

# Run on specific simulator by UDID
./scripts/run-ios-tests.sh --simulator-id "XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX"
```

#### Keep Simulator Running

```bash
# Keep simulator running after tests (useful for debugging)
./scripts/run-ios-tests.sh --no-cleanup

# Later, shut down manually:
xcrun simctl shutdown "SIMULATOR_ID"
```

#### Custom Matrix Server

```bash
# Run tests against custom Matrix server
./scripts/run-ios-tests.sh --matrix-server "http://192.168.1.100:8008"
```

#### Enable Verbose Logging

```bash
# Show detailed debug output
./scripts/run-ios-tests.sh --verbose

# Or set environment variable
VERBOSE=true ./scripts/run-ios-tests.sh
```

#### Custom Timeouts

```bash
# Increase timeouts for slower machines
IOS_DEVICE_TIMEOUT=600 TEST_TIMEOUT=3600 ./scripts/run-ios-tests.sh

# Defaults:
# - IOS_DEVICE_TIMEOUT: 300 seconds (5 minutes for boot)
# - TEST_TIMEOUT: 1800 seconds (30 minutes for tests)
```

### Full Example

```bash
# Comprehensive test run with custom settings
IOS_DEVICE_TIMEOUT=600 \
TEST_TIMEOUT=3600 \
MATRIX_SERVER=http://localhost:8008 \
VERBOSE=true \
./scripts/run-ios-tests.sh \
  --device-name "iPhone 15" \
  --no-cleanup

# Output will show:
# ✓ Environment validation
# ✓ Simulator found and booted
# ✓ Matrix server connectivity confirmed
# ✓ Integration tests running
# ✓ Test results summary
```

## Matrix Test Server Integration

The iOS tests integrate with the same Matrix test server used by Android tests.

### Prerequisites

Ensure the Matrix test server is running:

```bash
# Terminal 1: Start Matrix server and test infrastructure
docker-compose up

# Wait for these services to be healthy:
# - postgres (database)
# - matrix-synapse (Matrix server at http://localhost:8008)
# - matrix-init (test data initialization)
# - redis (caching)
```

### Test Server Configuration

The test server provides:

- **Server URL**: http://localhost:8008
- **Test User 1**: `testuser1` / `testpass123`
- **Test User 2**: `testuser2` / `testpass123`
- **Test Rooms**: Pre-created and initialized
- **Test Data**: Users, devices, and relationships ready for tests

### Verifying Server Connectivity

```bash
# Check Matrix server is running
curl http://localhost:8008/_matrix/client/versions

# Expected response:
# {"versions":["r0.5.0","r0.6.0","v1.1"],...}

# Check test data was initialized
curl -X POST http://localhost:8008/_matrix/client/r0/login \
  -d '{"type":"m.login.password","user":"testuser1","password":"testpass123"}'
```

### Environment Variables

The test runner automatically sets these for iOS tests:

```bash
MATRIX_SERVER=http://localhost:8008
MATRIX_TEST_USER=testuser1
MATRIX_TEST_PASSWORD=testpass123
```

These are available to your Flutter tests as environment variables.

## Expected Execution Time

### Typical Timeline

| Phase | Duration | Notes |
|-------|----------|-------|
| **Simulator Boot** | 15-30s | Initial startup varies by machine |
| **Flutter Pub Get** | 30-60s | Dependency resolution |
| **Test Initialization** | 10-20s | App startup, test framework setup |
| **Test Execution** | 15-25 min | ~22 integration test files |
| **Cleanup** | 5-10s | Simulator shutdown |
| **Total** | **20-30 minutes** | Most time is test execution |

### Performance Tips

1. **Reuse running simulator**: Use `--no-cleanup` and run tests multiple times
2. **Use faster hardware**: Apple Silicon M1/M2/M3 provides best performance
3. **Run specific tests**: `flutter test integration_test/auth_test.dart --device-id=...`
4. **Parallel execution**: Run tests on multiple simulators in separate terminals

## Interpreting Test Results

### Success Output

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[SUCCESS] Test Results Summary:
Total Tests:    22
Passed:         22 ✓
Failed:         0 ✗
Duration:       23m 45s
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### Failure Output

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
[ERROR] Test Results Summary:
Total Tests:    22
Passed:         20 ✓
Failed:         2 ✗
Duration:       18m 30s
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### Result Files

After test execution, results are saved to `test-results/`:

```
test-results/
├── ios-test-results.txt         # Full test output
├── ios-device-info.txt          # Device configuration
├── device.log                   # Simulator logs
└── test-results.json            # Structured results (if generated)
```

## Common Issues and Troubleshooting

### Issue: "Xcode command line tools not found"

**Symptoms**: `xcrun: error: unable to find utility`

**Solution**:
```bash
# Install command line tools
xcode-select --install

# Or update Xcode path
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
```

### Issue: "No iPhone simulators available"

**Symptoms**: `ERROR: No iPhone simulators available`

**Solutions**:
```bash
# List available runtimes
xcrun simctl list runtimes

# Create a simulator if none exist
xcrun simctl create "iPhone 15" \
  com.apple.CoreSimulator.SimDeviceType.iPhone-15 \
  com.apple.CoreSimulator.SimRuntime.iOS-17-2

# Verify creation
xcrun simctl list devices | grep -i iphone
```

### Issue: "Simulator fails to boot"

**Symptoms**: Simulator starts but tests don't run; timeout errors

**Causes and Solutions**:
```bash
# 1. Too many simulators running
killall "Simulator"
sleep 2

# 2. Simulator cache corrupted
xcrun simctl erase "SIMULATOR_ID"

# 3. Insufficient resources
# - Close other applications
# - Restart your Mac
# - Check available disk space: `df -h`

# 4. Increase timeout
IOS_DEVICE_TIMEOUT=600 TEST_TIMEOUT=3600 ./scripts/run-ios-tests.sh
```

### Issue: "Matrix server not accessible"

**Symptoms**: Tests fail with connection errors to http://localhost:8008

**Solutions**:
```bash
# 1. Verify server is running
docker-compose ps

# 2. Start server if needed
docker-compose up

# 3. Wait for server to be healthy
docker-compose ps
# All services should show "healthy" or "running"

# 4. Check server connectivity
curl http://localhost:8008/_matrix/client/versions

# 5. Check network
# - Ensure iOS simulator can reach localhost
# - In iOS simulator: Settings > Wi-Fi should show network connection
```

### Issue: "Test timeout"

**Symptoms**: `The following assertion failed: <test-name> ... timed out after 1800 seconds`

**Solutions**:
```bash
# Increase test timeout
TEST_TIMEOUT=3600 ./scripts/run-ios-tests.sh

# Or run specific test file in isolation
flutter test integration_test/auth_test.dart \
  --device-id=SIMULATOR_ID \
  --verbose

# Check for performance issues
# - Run on different simulator if available
# - Check system resources: `top -l 1 | head -20`
# - Reduce background processes
```

### Issue: "Tests pass locally but fail in CI"

**Possible Causes**:
- Different macOS version (iOS SDK version mismatch)
- Different Xcode version
- Test flakiness (network, timing)
- Matrix server not fully initialized

**Solutions**:
```bash
# Run with verbose logging in CI
VERBOSE=true ./scripts/run-ios-tests.sh

# Add longer wait times for CI environment
IOS_DEVICE_TIMEOUT=600 TEST_TIMEOUT=3600 ./scripts/run-ios-tests.sh

# Ensure Matrix server is fully healthy before tests
docker-compose up --wait
```

## Integration with CI/CD

### GitHub Actions Example

```yaml
name: iOS Integration Tests
on: [push, pull_request]

jobs:
  ios-tests:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Set up Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: 'latest'
      
      - name: Start Matrix Test Server
        run: |
          docker-compose up -d
          docker-compose exec -T matrix-synapse \
            sh -c 'while ! curl -f http://localhost:8008/_matrix/client/versions; do sleep 1; done'
      
      - name: Run iOS Integration Tests
        run: ./scripts/run-ios-tests.sh
        env:
          IOS_DEVICE_TIMEOUT: 600
          TEST_TIMEOUT: 3600
      
      - name: Upload Test Results
        if: always()
        uses: actions/upload-artifact@v3
        with:
          name: ios-test-results
          path: test-results/
```

### Local CI Simulation

To test your CI configuration locally:

```bash
# Simulate CI environment
docker-compose down
docker-compose up -d
sleep 30  # Wait for server initialization
./scripts/run-ios-tests.sh --verbose
```

## Development Workflow

### Running Tests During Development

```bash
# Terminal 1: Keep simulator running
./scripts/run-ios-tests.sh --no-cleanup

# Terminal 2: Run specific test multiple times as you develop
cd /path/to/project
for i in {1..5}; do
  flutter test integration_test/feature_test.dart \
    --device-id=SIMULATOR_ID \
    --verbose
done
```

### Debugging Failed Tests

```bash
# 1. Keep simulator running
./scripts/run-ios-tests.sh --no-cleanup

# 2. In another terminal, run test with verbose output
flutter test integration_test/failing_test.dart \
  --device-id=SIMULATOR_ID \
  --verbose

# 3. View simulator logs in real-time
xcrun simctl spawn <simulator-id> log stream --level debug

# 4. Get full system log after test
xcrun simctl get_app_container <simulator-id> com.example.app documents
```

### Inspecting Device Logs

```bash
# Get simulator device logs
xcrun simctl spawn SIMULATOR_ID log show --predicate 'eventMessage contains "ERROR"'

# Or use convenience function from utils
source ./scripts/ios-simulator-utils.sh
list_simulators  # See which simulators are available
```

## Advanced Topics

### Custom Simulator Configuration

```bash
# Create simulator with specific iOS version
xcrun simctl create "iPhone 15 iOS 17" \
  com.apple.CoreSimulator.SimDeviceType.iPhone-15 \
  com.apple.CoreSimulator.SimRuntime.iOS-17-2

# Add to PATH for easier access
export CUSTOM_SIM_ID=$(xcrun simctl list devices --json | \
  python3 -c "import json, sys; d=json.load(sys.stdin); \
  print([s['udid'] for r in d['devices'].values() \
  for s in r if 'iPhone 15 iOS 17' in s['name']][0])")

./scripts/run-ios-tests.sh --simulator-id "$CUSTOM_SIM_ID"
```

### Running Tests in Parallel

```bash
# Create multiple simulators
for i in {1..3}; do
  xcrun simctl create "iPhone 15 Parallel $i" \
    com.apple.CoreSimulator.SimDeviceType.iPhone-15 \
    com.apple.CoreSimulator.SimRuntime.iOS-17-2
done

# Run tests in parallel (in separate terminals)
./scripts/run-ios-tests.sh --device-name "iPhone 15 Parallel 1"
./scripts/run-ios-tests.sh --device-name "iPhone 15 Parallel 2"
./scripts/run-ios-tests.sh --device-name "iPhone 15 Parallel 3"
```

### Performance Profiling

```bash
# Run tests with performance measurement
time ./scripts/run-ios-tests.sh

# Analyze Flutter test performance
flutter test integration_test/ --device-id=SIMULATOR_ID \
  --enable-impeller \
  --trace-startup \
  --verbose
```

## Related Documentation

- [Flutter Integration Testing Guide](https://docs.flutter.dev/testing/integration-tests)
- [Xcode Simulator Documentation](https://help.apple.com/xcode/mac/current/#/dev2433c7d1d)
- [Matrix Synapse Testing Guide](https://matrix-org.github.io/synapse/latest/development/test_coverage.html)

## Support and Feedback

For issues or questions:

1. Check the [Troubleshooting](#common-issues-and-troubleshooting) section
2. Review test output in `test-results/ios-test-results.txt`
3. Enable verbose logging: `VERBOSE=true ./scripts/run-ios-tests.sh`
4. Report issues at: https://github.com/anomalyco/opencode/issues

## Quick Reference

| Command | Purpose |
|---------|---------|
| `./scripts/run-ios-tests.sh` | Run all iOS tests |
| `./scripts/run-ios-tests.sh --device-name "iPhone 14"` | Run on specific device |
| `./scripts/run-ios-tests.sh --no-cleanup` | Keep simulator running |
| `xcrun simctl list devices` | List available simulators |
| `xcrun simctl boot SIMULATOR_ID` | Boot simulator manually |
| `xcrun simctl shutdown SIMULATOR_ID` | Shutdown simulator manually |
| `xcrun simctl erase SIMULATOR_ID` | Reset simulator state |
