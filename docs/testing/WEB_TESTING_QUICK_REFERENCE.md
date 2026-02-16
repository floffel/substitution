# Quick Web Testing Reference Card

## Fast Cheat Sheet for Flutter Web Testing

### TL;DR - Just Run This

```bash
# 1. Install Chrome (first time only)
brew install google-chrome          # macOS
sudo apt-get install chromium-browser  # Ubuntu

# 2. Run web tests
./scripts/run-web-tests.sh

# 3. Check results
cat test-results/web-test-results.txt
```

**Expected time:** 10-15 minutes ⚡

---

## Common Commands

### Local Testing
```bash
# Basic
./scripts/run-web-tests.sh

# Verbose output
./scripts/run-web-tests.sh --verbose

# HTML renderer (fastest)
./scripts/run-web-tests.sh --renderer html

# CanvasKit renderer (better rendering)
./scripts/run-web-tests.sh --renderer canvaskit

# With Flutter directly
flutter test integration_test/ --device-id web -v

# Specific test file
flutter test integration_test/app_test.dart --device-id web -v
```

### Docker
```bash
# Start services
docker-compose up -d

# Run web tests
docker-compose run web-test

# Check services are running
docker-compose ps
```

### Troubleshooting
```bash
# Check Chrome is installed
which google-chrome
chrome --version

# Check Matrix server
curl http://localhost:8008/_matrix/client/versions

# View test results
cat test-results/web-test-results.txt
tail -100 test-results/web-test.log

# Increase timeout (minutes * 60)
WEB_TEST_TIMEOUT=$((15*60)) ./scripts/run-web-tests.sh
```

---

## Platform Comparison

```
Platform        | Time      | Setup  | Best For
────────────────────────────────────────────────────────
Web (HTML)      | 10-15m ⚡ | <1s    | Quick feedback, UI tests
iOS Simulator   | 25-35m 🍎 | 60s    | Full validation, native code
Android Emulator| 20-30m 🔧 | 120s   | Android-specific, native code
```

---

## When to Use Each

| Situation | Use |
|-----------|-----|
| Testing UI/navigation | Web ⚡ (10 min) |
| Before commit (no native code) | Web ⚡ (10 min) |
| Before commit (with native code) | Web + iOS 🍎 (35 min) |
| Pre-release | All three (45 min) |
| iOS-specific bug | iOS only 🍎 |
| Android-specific bug | Android only 🔧 |

---

## File Locations

```
scripts/run-web-tests.sh              # Main test script
docs/WEB_TESTING.md                   # Full documentation
docs/TESTING_PLATFORMS_COMPARISON.md  # Platform guide
docs/SETUP_WEB_TESTING_SUMMARY.md     # Setup summary
test-results/web-test-results.txt     # Test output
test-results/web-test.log             # Detailed logs
```

---

## Exit Codes

```
0 = All tests passed ✓
1 = Tests failed ✗
2 = Chrome not found
3 = Environment error
4 = Test timeout
5 = Setup failed
```

---

## Environment Variables

```bash
# Increase timeout (seconds)
WEB_TEST_TIMEOUT=1800

# Use custom Chrome
CHROME_EXECUTABLE=/path/to/chrome

# Custom Matrix server
MATRIX_SERVER=http://localhost:8008

# Verbose output
VERBOSE=true

# Use CanvasKit
WEB_RENDERER=canvaskit

# Example
WEB_TEST_TIMEOUT=1200 VERBOSE=true ./scripts/run-web-tests.sh
```

---

## Typical Workflow

```
1. Start Matrix server (first time)
   docker-compose up -d

2. Make code changes

3. Run web tests (2-3 min)
   ./scripts/run-web-tests.sh

4. If tests pass → continue
   If tests fail → fix and retry

5. Before committing:
   - If no native code: web tests ✓
   - If native code: add iOS tests

6. Pre-release: run all platforms
```

---

## CI/CD Quick Setup

GitHub Actions:
```yaml
- name: Run web tests
  run: ./scripts/run-web-tests.sh
  timeout-minutes: 20
```

GitLab CI:
```yaml
web-tests:
  script: ./scripts/run-web-tests.sh
  timeout: 20 minutes
```

---

## Pro Tips

1. **During development:** Web only (fast)
2. **Before commit:** Add iOS if needed (native code)
3. **Pre-release:** Run all three in parallel
4. **Failed test:** Check `test-results/web-test.log`
5. **Chrome not found:** Install via brew/apt
6. **Slow tests:** Use HTML renderer (faster)
7. **Rendering issues:** Try CanvasKit renderer
8. **Network errors:** Check Matrix server running

---

## Installation

### macOS
```bash
brew install google-chrome
# Or Chromium
brew install chromium
```

### Ubuntu
```bash
sudo apt-get update
sudo apt-get install chromium-browser
```

### Windows (WSL2)
```bash
sudo apt-get install chromium-browser
```

### Fedora
```bash
sudo dnf install chromium
```

---

## Quick Reference Links

- **Full Guide:** `docs/WEB_TESTING.md`
- **Platforms:** `docs/TESTING_PLATFORMS_COMPARISON.md`
- **Setup:** `docs/SETUP_WEB_TESTING_SUMMARY.md`
- **Script:** `scripts/run-web-tests.sh`

---

## Need Help?

```bash
# View script help
./scripts/run-web-tests.sh --help

# Check all logs
tail -200 test-results/web-test.log

# Run with verbose
./scripts/run-web-tests.sh --verbose

# Check documentation
cat docs/WEB_TESTING.md
```

---

## Key Numbers

- **Web test time:** 10-15 minutes
- **iOS test time:** 25-35 minutes  
- **Android test time:** 20-30 minutes
- **Speed improvement:** 2-3x faster than native platforms
- **CI/CD savings:** 45+ minutes when parallelized

---

Happy testing! 🚀
