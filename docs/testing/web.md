# Flutter Web Testing Guide

## Overview

Web testing is a fast CI/CD alternative that allows you to run Flutter integration tests without setting up simulators or emulators. Tests run directly in a headless browser environment (Chrome/Chromium), making them ideal for:

- **Quick feedback loops** during development
- **Fast CI/CD pipelines** (10-15 minutes vs 25-35 min for iOS)
- **Cross-platform testing** on any machine with a browser
- **Parallel test execution** without resource contention

## Prerequisites

### Local Development

#### macOS
```bash
# Install Chrome (if not already installed)
brew install google-chrome

# Or use Chromium
brew install chromium

# Verify installation
google-chrome --version
```

#### Ubuntu/Debian
```bash
# Install Chromium
sudo apt-get update
sudo apt-get install chromium-browser

# Or install Google Chrome
wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | sudo apt-key add -
sudo sh -c 'echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" >> /etc/apt/sources.list.d/google-chrome.list'
sudo apt-get update
sudo apt-get install google-chrome-stable

# Verify installation
chromium-browser --version
# or
google-chrome --version
```

#### Fedora/RHEL
```bash
sudo dnf install chromium

# Verify installation
chromium --version
```

#### Windows (WSL2)
```bash
# In WSL2, install Chromium
sudo apt-get update
sudo apt-get install chromium-browser

# Or use Windows Chrome installation
# Chrome from Windows is accessible at:
# /mnt/c/Program Files/Google/Chrome/Application/chrome.exe
```

### Flutter Setup

Ensure Flutter is configured with web support:
```bash
flutter config --enable-web
flutter devices
```

You should see `web` listed in available devices.

### Matrix Test Server (Optional but Recommended)

For tests that interact with the Matrix chat backend:

```bash
# Start the test server and all dependencies
docker-compose up -d

# Verify server is running
curl http://localhost:8008/_matrix/client/versions
```

## Running Web Tests

### Quick Start (Local Machine)

```bash
# Run all web integration tests
./scripts/run-web-tests.sh

# Or use Flutter directly
flutter test integration_test/ --device-id web -v
```

### Using the Test Script with Options

```bash
# Run with HTML renderer (fastest)
./scripts/run-web-tests.sh --renderer html

# Run with CanvasKit renderer (better rendering fidelity)
./scripts/run-web-tests.sh --renderer canvaskit

# Specify custom Chrome path
./scripts/run-web-tests.sh --chrome-path /custom/path/to/chrome

# Verbose output for debugging
./scripts/run-web-tests.sh --verbose

# Custom Matrix server
./scripts/run-web-tests.sh --matrix-server http://matrix.example.com:8008

# Run with custom timeout (in seconds)
./scripts/run-web-tests.sh --help  # See all options
```

### Using Flutter Directly

```bash
# Run web tests with verbose output
flutter test integration_test/ --device-id web -v

# Use CanvasKit renderer for better rendering
flutter test integration_test/ --device-id web --web-renderer=canvaskit -v

# Run specific test file
flutter test integration_test/app_test.dart --device-id web -v

# Run with tags
flutter test integration_test/ --device-id web -v -t "quick"

# Run tests on custom port
flutter test integration_test/ --device-id web --web-port=8888 -v
```

### Docker/CI Pipeline

```bash
# Start services in background
docker-compose up -d matrix-synapse postgres redis matrix-init

# Run web tests in Docker
docker-compose run web-test

# Or run manually in container
docker-compose run --rm web bash -c "cd /project && ./scripts/run-web-tests.sh"
```

## Expected Runtime

### Execution Times

| Phase | Duration |
|-------|----------|
| **Setup** | 0-5s |
| **Dependency resolution** | 10-30s |
| **First build** | 30-60s |
| **Test execution** | 5-10 min |
| **Result parsing** | 5-10s |
| **Total (first run)** | **10-15 minutes** |
| **Total (cached)** | **8-12 minutes** |

### Comparison with Other Platforms

| Platform | Setup | Build | Test Exec | Total | Notes |
|----------|-------|-------|-----------|-------|-------|
| **Web (HTML)** | <1s | 30-60s | 5-10m | **10-15m** | ✓ Fastest, no simulator |
| **Web (CanvasKit)** | <1s | 45-90s | 5-10m | **12-18m** | Better rendering, slower |
| **iOS Simulator** | 60-120s | 30-60s | 15-20m | **25-35m** | Full features, slower |
| **Android Emulator** | 90-180s | 45-90s | 10-15m | **20-30m** | Requires /dev/kvm |

## Known Limitations

### Web-Specific Rendering

1. **Platform Differences**
   - Some Material/Cupertino widgets render differently on web
   - SVG rendering may differ slightly from native platforms
   - No access to native platform channels (plug-in limitations)

2. **Media Handling**
   - Video player functionality may be limited
   - Audio format support depends on browser codecs
   - Image caching differs from native apps

3. **Performance**
   - Web tests run in a single-threaded environment
   - Some platform channels are not available
   - No access to device sensors/accelerometer

### Browser Limitations

1. **Security Constraints**
   - Cross-origin requests restricted (CORS)
   - Some APIs restricted in headless mode
   - File system access limited

2. **Headless Mode**
   - No visual rendering output (tests must be code-based)
   - Some JavaScript APIs unavailable
   - DOM testing may behave differently

### Unsupported Scenarios

The following should **NOT** be tested on web:

- ❌ iOS-specific features (Face ID, HomeKit, etc.)
- ❌ Android-specific features (fingerprint, NFC, etc.)
- ❌ Platform channel implementations
- ❌ Native module testing
- ❌ Complex gesture recognition (web has limited gesture support)
- ❌ Low-level graphics APIs

## Supported Scenarios

Web testing is **IDEAL** for:

- ✅ UI widget interactions
- ✅ Navigation flows
- ✅ Form validation
- ✅ API integration with Matrix server
- ✅ State management testing
- ✅ Accessibility testing
- ✅ Responsive design verification
- ✅ Cross-browser compatibility

## Interpreting Results

### Successful Test Output

```
00:00 +10: All tests passed! (45.2s)
```

### Failed Test Output

```
00:23 -1: Some tests failed
├─ app_test.dart: Login failed - timeout
├─ feed_test.dart: Image loading failed
└─ onboarding_test.dart: Navigation issue
```

### Key Indicators

1. **Passed Tests** (✓)
   - Widget renders correctly
   - User interactions work as expected
   - Navigation flows complete
   - API calls succeed

2. **Failed Tests** (✗)
   - Widget assertion failed
   - Element not found
   - Timeout waiting for element
   - Unexpected error in test code

3. **Skipped Tests** (⊘)
   - Test tagged with specific platform
   - Test requires unavailable feature
   - Test explicitly skipped

### Debugging Failed Tests

#### 1. Check Test Logs
```bash
# Run with verbose output
./scripts/run-web-tests.sh --verbose

# Or directly
flutter test integration_test/app_test.dart --device-id web -v
```

#### 2. Add Debug Output in Tests
```dart
testWidgets('My test', (tester) async {
  print('DEBUG: Starting test');
  
  await tester.pumpWidget(MyApp());
  print('DEBUG: App rendered');
  
  expect(find.byType(Button), findsOneWidget);
});
```

#### 3. Use Browser Developer Tools

While headless mode doesn't show the browser UI, you can run tests in headed mode:

```bash
# Run in regular (visible) browser
flutter run integration_test/app_test.dart --device-id web
```

Then use Chrome DevTools (F12) to:
- Inspect elements
- View console logs
- Check network requests
- Debug JavaScript

#### 4. Check Test Results Files

```bash
# View detailed test output
cat test-results/web-test-results.txt

# View full logs
cat test-results/web-test.log
```

### Common Issues and Solutions

| Issue | Cause | Solution |
|-------|-------|----------|
| Chrome not found | Browser not installed | Install Chrome: `brew install google-chrome` |
| Timeout waiting for element | Element doesn't exist or is slow | Increase timeout or check selector |
| Network errors | Matrix server not running | `docker-compose up matrix-synapse` |
| CORS errors | Cross-origin request blocked | Configure server CORS headers |
| Package errors | Outdated dependencies | Run `flutter pub get --upgrade` |
| Renderer not supported | Invalid renderer option | Use `html` or `canvaskit` only |

## Platform Testing Matrix

Use this matrix to decide which platform to test on:

### During Development
- **Primary**: Web (fastest feedback)
- **Secondary**: iOS Simulator (if native features needed)

### Before Commit
- **Required**: Web tests must pass
- **Optional**: iOS Simulator tests (if touching native code)

### Pre-Release (CI/CD)
- **Required**: Web tests (quick feedback)
- **Required**: iOS Simulator (release candidate)
- **Required**: Android Emulator (Linux CI/CD)

### Bug Verification
- **Web**: For UI/logic bugs
- **iOS/Android**: For platform-specific bugs

## Advanced Configuration

### Custom Web Renderer

By default, web tests use the HTML renderer (fastest):

```bash
# HTML renderer (default, fastest)
./scripts/run-web-tests.sh --renderer html

# CanvasKit renderer (better rendering, slower)
./scripts/run-web-tests.sh --renderer canvaskit
```

**Recommendations:**
- Use `html` for quick feedback during development
- Use `canvaskit` for final validation before release
- Both should pass in CI/CD pipeline

### Custom Test Port

If port 8080 is already in use:

```bash
flutter test integration_test/ --device-id web --web-port=8888 -v
```

### Environment Variables

Set these to customize test execution:

```bash
# Use different Matrix server
export MATRIX_SERVER=http://staging.matrix.example.com:8008
export MATRIX_TEST_USER=testuser1
export MATRIX_TEST_PASSWORD=testpass123

# Increase timeout (in seconds)
export WEB_TEST_TIMEOUT=1200

# Specify Chrome path
export CHROME_EXECUTABLE=/usr/bin/google-chrome

# Enable verbose logging
export VERBOSE=true

./scripts/run-web-tests.sh
```

### CI/CD Integration

#### GitHub Actions Example

```yaml
name: Web Tests

on: [push, pull_request]

jobs:
  web-tests:
    runs-on: ubuntu-latest
    
    services:
      postgres:
        image: postgres:16-alpine
        env:
          POSTGRES_PASSWORD: postgres
      
      matrix:
        image: matrixdotorg/synapse:latest
        options: >-
          --health-cmd "curl -f http://localhost:8008/_matrix/client/versions"
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
    
    steps:
      - uses: actions/checkout@v3
      
      - name: Set up Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: stable
          channel: stable
      
      - name: Install dependencies
        run: sudo apt-get install -y chromium-browser
      
      - name: Run web tests
        run: ./scripts/run-web-tests.sh
      
      - name: Upload results
        if: always()
        uses: actions/upload-artifact@v3
        with:
          name: test-results
          path: test-results/
```

#### GitLab CI Example

```yaml
web-tests:
  image: cirrusci/flutter:latest
  services:
    - postgres:16-alpine
    - matrixdotorg/synapse:latest
  before_script:
    - apt-get update
    - apt-get install -y chromium-browser
  script:
    - ./scripts/run-web-tests.sh
  artifacts:
    paths:
      - test-results/
    when: always
  timeout: 20 minutes
```

## Troubleshooting

### Script Errors

```bash
# Permission denied
chmod +x ./scripts/run-web-tests.sh

# Module not found errors
flutter pub get

# Environment variables not set
echo $MATRIX_SERVER
```

### Browser Issues

```bash
# Chrome crashes or fails to start
# Try with different renderer
./scripts/run-web-tests.sh --renderer canvaskit

# Use specific Chrome version
./scripts/run-web-tests.sh --chrome-path /usr/bin/google-chrome-stable

# Clean Flutter web cache
rm -rf build/web
flutter clean
flutter pub get
```

### Test Failures

```bash
# Run individual test for debugging
flutter test integration_test/app_test.dart --device-id web -v

# Run with verbose logging
VERBOSE=true ./scripts/run-web-tests.sh

# Check if Matrix server is running
curl http://localhost:8008/_matrix/client/versions
```

## Performance Tips

1. **Use HTML Renderer by Default**
   - Significantly faster than CanvasKit
   - Sufficient for most integration tests

2. **Parallel Test Execution**
   - Web tests don't require resources like simulators
   - Can run multiple test suites in parallel

3. **Cache Dependencies**
   - Use `flutter pub get` once
   - Subsequent runs reuse the cache

4. **Minimize Network Calls**
   - Mock expensive API calls
   - Use test fixtures instead of real data

5. **Split Large Test Suites**
   - Run different test files separately
   - Allows parallel execution in CI/CD

## Resources

- [Flutter Web Documentation](https://flutter.dev/web)
- [Flutter Integration Testing](https://flutter.dev/docs/testing/integration-tests)
- [WebDriver Protocol](https://www.w3.org/TR/webdriver/)
- [Chrome Command Line Flags](https://peter.sh/experiments/chromium-command-line-switches/)

## Next Steps

1. Run web tests locally to verify setup
2. Configure CI/CD pipeline to run web tests
3. Add platform-specific tests for iOS/Android as needed
4. Set up test coverage reporting
5. Integrate with your development workflow

## Support

For issues or questions:
- Check the [Troubleshooting](#troubleshooting) section
- Review test output in `test-results/` directory
- Run with `--verbose` flag for detailed logging
- Check Flutter documentation for web testing
