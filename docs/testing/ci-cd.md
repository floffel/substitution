# Integration Testing & CI/CD Pipeline

This document describes the comprehensive multi-platform integration testing pipeline for the Substitution app, which runs tests across Web, iOS, and Android platforms in parallel.

## Overview

The CI/CD pipeline is designed to ensure code quality and platform compatibility by running integration tests on multiple platforms simultaneously. The workflow is automated on every push to `main` or `develop` branches, and on all pull requests targeting these branches.

### Pipeline Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    GitHub Actions Workflow                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ Setup Job (Ubuntu) - Validates Flutter & dependencies   │  │
│  │ Time: ~3-5 minutes                                       │  │
│  └──────────────────────────────────────────────────────────┘  │
│                              │                                  │
│           ┌──────────────────┼──────────────────┐              │
│           ▼                  ▼                  ▼              │
│  ┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐  │
│  │  Web Tests      │ │  iOS Tests      │ │ Android Tests   │  │
│  │  (Ubuntu)       │ │  (macOS)        │ │ (Ubuntu+Docker) │  │
│  │  ~12-15 min     │ │  ~30-40 min     │ │ ~25-35 min      │  │
│  └─────────────────┘ └─────────────────┘ └─────────────────┘  │
│           │                  │                  │              │
│           └──────────────────┼──────────────────┘              │
│                              ▼                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ Test Results Aggregation (Ubuntu)                        │  │
│  │ Parse results from all platforms and generate report     │  │
│  │ Time: ~2-3 minutes                                       │  │
│  └──────────────────────────────────────────────────────────┘  │
│                              ▼                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ Final Status Check                                       │  │
│  │ Determine pass/fail and fail workflow if needed          │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Timing & Parallelization

### Total Execution Time

When all jobs run **in parallel** (as they do in this pipeline):

- **Critical Path:** iOS Tests (longest-running) + Final Aggregation = ~35-45 minutes
- **Total Wall-Clock Time:** ~40-50 minutes (including setup and aggregation)
- **Cost Optimization:** Running in parallel saves ~2-3 hours compared to sequential execution

### Job Timing Breakdown

| Job | Platform | Runner | Avg Time | Critical? |
|-----|----------|--------|----------|-----------|
| Setup & Validation | Cross-platform | Ubuntu | 3-5 min | Yes* |
| Web Tests | Web | Ubuntu | 12-15 min | No |
| iOS Tests | iOS | macOS | 30-40 min | **Yes** |
| Android Tests | Android | Ubuntu | 25-35 min | No |
| Result Aggregation | Results | Ubuntu | 2-3 min | Yes** |
| Final Status Check | Status | Ubuntu | 1 min | Yes** |

*Setup is required before other jobs  
**Depends on test jobs completing

### Parallelization Strategy

```
Time →
────────────────────────────────────────────────────────────
│Setup │ Web    │ iOS                  │ Results │ Final │
│(3m)  │ (15m)  │ (40m)                │ (3m)    │ (1m)  │
│      ├──────────────────────────────────────┤         │
│      │ Android (35m)                        │         │
```

**Key insight:** iOS tests run in parallel with Web and Android, so the total time is dominated by the iOS job rather than the sum of all jobs.

## Workflow Triggers

The integration tests automatically run on:

1. **Push events** to `main` or `develop` branches
2. **Pull requests** targeting `main` or `develop` branches
3. **Manual trigger** via GitHub Actions UI (workflow dispatch)

### Trigger Examples

```bash
# Automatic trigger - feature branch → PR
git checkout -b feature/my-feature
git commit -m "Add new feature"
git push origin feature/my-feature
# → Creates PR → Runs integration tests

# Manual trigger
# Go to Actions tab → Integration Tests (Multi-Platform) → Run workflow
```

## Platform-Specific Details

### Web Tests

**Location:** `.github/workflows/integration-tests.yml` - `web-tests` job

**What it does:**
- Enables Flutter web support
- Builds Flutter app for web (release mode)
- Runs integration tests against web server
- Captures JSON test results

**Test command:**
```bash
flutter test integration_test/ -d web-server --reporter=json
```

**Typical duration:** 12-15 minutes

**Artifacts generated:**
- `test_results/web/results.json` - Machine-readable test results
- `test_results/web/summary.txt` - Human-readable summary
- `build-web.log` - Build output logs

**Failure modes:**
- Build failures (compilation errors)
- Test timeouts
- Web server startup issues

---

### iOS Tests

**Location:** `.github/workflows/integration-tests.yml` - `ios-tests` job

**What it does:**
- Creates/boots iOS simulator (iPhone 15, iOS 17)
- Builds Flutter app for iOS (debug mode)
- Runs integration tests on simulator
- Collects test logs and build output

**Test command:**
```bash
flutter test integration_test/ -d ios --reporter=json --verbose
```

**Typical duration:** 30-40 minutes

**Key features:**
- **Simulator setup:** Automatically creates and boots iPhone 15 simulator
- **Debug mode:** Uses debug build for faster iteration and debugging support
- **Verbose output:** Captures detailed test execution logs

**Artifacts generated:**
- `test_results/ios/test.log` - Detailed test execution log
- `test_results/ios/build.log` - iOS build output

**Failure modes:**
- Simulator boot failures (rare on fresh runners)
- iOS build compilation errors
- Simulator memory/resource constraints
- Test framework incompatibilities

**Environment requirements:**
- macOS runner (native Xcode required)
- ~8GB free disk space
- 10+ GB RAM

---

### Android Tests

**Location:** `.github/workflows/integration-tests.yml` - `android-tests` job

**What it does:**
- Sets up Java 11 (required for Android SDK)
- Installs Android SDK tools and system images
- Builds APK (debug)
- Launches Android emulator in Docker service
- Installs APK on emulator
- Runs integration tests against emulator

**Test command:**
```bash
flutter test integration_test/ -d emulator-5554 --reporter=json --verbose
```

**Typical duration:** 25-35 minutes

**Key features:**
- **Docker service:** Android emulator runs as GitHub Actions service
- **Emulator config:** Nexus 5X, Android 12 (API 31)
- **APK installation:** APK installed after build
- **Logging:** Captures logcat output for debugging

**Artifacts generated:**
- `test_results/android/test.log` - Test execution log
- `test_results/android/build.log` - Build output
- `test_results/android/device.log` - Logcat output from device

**Failure modes:**
- Java/Gradle build failures
- Android SDK tool installation timeouts
- Emulator boot failures
- ADB connection timeouts

**Environment requirements:**
- Linux runner (Docker support required)
- ~6GB free disk space
- Android SDK: API level 31, 33

---

## Test Results & Reporting

### Result Aggregation Process

The `test-results` job automatically:

1. **Downloads** all test artifacts from each platform
2. **Parses** test results (JSON and log files)
3. **Aggregates** pass/fail counts across platforms
4. **Generates** unified report with:
   - Status (✅ PASSED or ❌ FAILED)
   - Pass/fail counts by platform
   - Total counts across all platforms
   - Links to detailed artifacts
   - Execution metadata (commit, branch, timestamp)

### Test Report Format

```markdown
# Integration Test Results

**Workflow Run:** [1234567](https://github.com/.../actions/runs/1234567)
**Commit:** [`abc1234`](https://github.com/.../commit/abc1234)
**Branch:** `develop`
**Triggered by:** `username`

## `web` Platform
✅ Tests completed
- **Passed:** 42
- **Failed:** 0

## `ios` Platform
✅ Tests completed
- **Passed:** 38
- **Failed:** 0

## `android` Platform
✅ Tests completed
- **Passed:** 40
- **Failed:** 0

## Overall Summary

| Metric | Count |
|--------|-------|
| Total Passed | 120 |
| Total Failed | 0 |
| Total Skipped | 0 |

## Status: ✅ PASSED

---
Generated at: `2024-02-15T14:30:45Z`
```

### Where Results Are Posted

1. **GitHub Actions UI:**
   - Workflow run view in Actions tab
   - Step summary in job output
   - Artifacts available for download

2. **Pull Request (if applicable):**
   - Automatic comment with full report
   - Linked artifacts for detailed investigation

3. **Artifacts:**
   - All test logs and build output
   - Accessible for 30 days
   - Download from Actions tab

### Interpreting Results

#### ✅ All Tests Passed
- All platforms completed successfully
- No failures detected
- Safe to merge (assuming other checks also pass)

#### ❌ Some Tests Failed
- Platform(s) with failures clearly marked
- Check platform-specific logs for details
- **Next steps:**
  1. Review failing test logs
  2. Check if failures are environmental (timing, resources)
  3. Investigate code changes that triggered failure
  4. Fix and push new commit (tests re-run automatically)

#### ⚠️ Platform Build Failed
- App failed to build before tests even ran
- Check `build.log` for compilation errors
- Common causes:
  - Missing dependencies (run `flutter pub get`)
  - Dart/Flutter version incompatibility
  - Platform-specific code issues

## Caching Strategy

The pipeline implements comprehensive caching to speed up runs:

### Flutter SDK Cache
- **What:** Flutter binaries and tools
- **Where:** GitHub Actions built-in cache
- **Hit rate:** ~95% on subsequent runs
- **Time saved:** ~2-3 minutes per job

### Pub Dependencies Cache
- **What:** Dart packages from `pubspec.lock`
- **Where:** GitHub Actions built-in cache
- **Key:** Hash of `pubspec.lock` file
- **Hit rate:** ~90% (only changes on dependency updates)
- **Time saved:** ~1-2 minutes per job

### How to Invalidate Cache

If you're experiencing stale cache issues:

1. **Manual cache clear:** Use GitHub Actions UI
   - Settings → Actions → Clear all caches

2. **Automatic invalidation:** Cache is automatically invalidated when:
   - `pubspec.lock` changes
   - GitHub Actions updates runner images

## Skipping Tests (if needed)

While not recommended, you can skip the integration tests for specific commits using git commit messages:

### Skip All Tests
```bash
git commit -m "WIP: Update docs [skip ci]"
# Workflow will not trigger
```

### Run Only Specific Platforms

To run tests manually with custom parameters:

1. Go to Actions → Integration Tests (Multi-Platform)
2. Click "Run workflow"
3. Select branch and run

This allows you to:
- Manually trigger tests at specific commit
- Test a specific branch
- Manually test before merging

**Note:** Scheduled jobs for specific platforms are not yet configured. To implement this, add a `workflow_call` input to the workflow file.

## Adding More Platforms

To add testing for additional platforms (Windows, Linux Desktop, etc.):

### Step 1: Create New Job Template

```yaml
windows-tests:
  runs-on: windows-latest
  name: 'Windows Tests'
  needs: setup
  timeout-minutes: 40
  
  steps:
    - uses: actions/checkout@v4
    - name: 'Setup Flutter'
      uses: subosito/flutter-action@v2
      with:
        flutter-version: ${{ env.FLUTTER_VERSION }}
        channel: 'stable'
        cache: true
    
    - name: 'Install dependencies'
      run: flutter pub get
    
    - name: 'Enable Windows'
      run: flutter config --enable-windows-desktop
    
    - name: 'Build Windows app'
      run: flutter build windows
    
    - name: 'Run Windows tests'
      run: |
        mkdir -p test_results/windows
        flutter test integration_test/ -d windows --reporter=json 2>&1 | tee test_results/windows/test.log
    
    - name: 'Upload test results'
      if: always()
      uses: actions/upload-artifact@v4
      with:
        name: test-results-windows
        path: test_results/windows/
        retention-days: 30
```

### Step 2: Update Dependencies

Update the `needs` array in `test-results` job:

```yaml
test-results:
  needs: [setup, web-tests, ios-tests, android-tests, windows-tests]
```

And in `all-tests-passed`:

```yaml
all-tests-passed:
  needs: [web-tests, ios-tests, android-tests, windows-tests, test-results]
```

### Step 3: Update Result Parsing

Add parsing for new platform in `test-results` job:

```bash
parse_platform_results "windows"
```

### Best Practices for New Platforms

1. **Use same test suite:** Place all integration tests in `integration_test/`
2. **Follow naming:** `test-results-{platform-name}` for consistency
3. **Set appropriate timeouts:** Based on historical run times
4. **Consider runner costs:** Some runners are more expensive
5. **Use caching:** Enable Flutter cache for faster runs
6. **Document requirements:** Note any special setup needed

## Customization Guide

### Changing Flutter Version

Edit the `env` section at top of workflow:

```yaml
env:
  FLUTTER_VERSION: '3.19.0'  # Change this
```

### Adjusting Timeouts

Modify `timeout-minutes` for each job based on your needs:

```yaml
web-tests:
  timeout-minutes: 20  # Increase if builds are timing out
```

### Adding Email Notifications

Add step at end of `test-results` job:

```yaml
- name: 'Send test results email'
  if: always()
  uses: dawidd6/action-send-mail@v3
  with:
    server_address: smtp.gmail.com
    server_port: 465
    username: ${{ secrets.EMAIL_USERNAME }}
    password: ${{ secrets.EMAIL_PASSWORD }}
    subject: Integration Tests - ${{ job.status }}
    to: team@example.com
    body: Test results available at ${{ github.server_url }}/${{ github.repository }}/actions/runs/${{ github.run_id }}
```

### Custom Test Filters

To run specific test files only, modify the test command:

```bash
# Before (all tests)
flutter test integration_test/ -d web-server

# After (specific test file)
flutter test integration_test/app_test.dart -d web-server

# After (specific test pattern)
flutter test integration_test/ -k "login" -d web-server
```

## Troubleshooting

### Issue: iOS Tests Timeout

**Symptoms:** Job times out around 50 minutes

**Solutions:**
1. Increase `timeout-minutes` in `ios-tests` job to 60
2. Check if simulator is hanging: Review step output
3. Reduce scope: Run specific tests only
4. Check runner resources: May need to use larger runner

### Issue: Android Emulator Won't Boot

**Symptoms:** "Timeout waiting for adb"

**Solutions:**
1. Check Docker service health: `adb devices`
2. Clear device cache: Remove `--cache-size=2048m` from docker service
3. Use different emulator image:
   ```yaml
   services:
     android-emulator:
       image: thyrlian/android-sdk:latest
       env:
         SYSTEM_IMAGE: "system-images;android-33;google_apis;x86_64"
   ```

### Issue: Web Tests Flaky

**Symptoms:** Tests pass sometimes, fail other times

**Solutions:**
1. Add explicit waits in test code
2. Increase timeout in test:
   ```bash
   flutter test integration_test/ -d web-server --timeout=60000
   ```
3. Check for race conditions in test code
4. Use `tester.pumpAndSettle()` to wait for animations

### Issue: Cache Not Being Used

**Symptoms:** Dependency installation always slow

**Solutions:**
1. Verify `pubspec.lock` exists in repo
2. Clear cache manually and re-run
3. Check logs for "Cache hit" message
4. Ensure Flutter cache is enabled in all jobs

### Issue: Results Not Posted to PR

**Symptoms:** Test report doesn't appear as PR comment

**Solutions:**
1. Verify job has correct permissions:
   ```yaml
   permissions:
     pull-requests: write
   ```
2. Check if workflow is from PR fork (no write access)
3. Verify `issue_number` is available (only on PR events)

## Maintenance

### Weekly Tasks
- Monitor job execution times (should be consistent)
- Review failed tests and fix root causes
- Check for deprecated actions/tools

### Monthly Tasks
- Update Flutter version if new release available
- Review runner costs (platform usage)
- Audit and update Android/iOS SDK versions

### Quarterly Tasks
- Test on new Flutter stable release
- Review and update test coverage
- Performance optimization review

## Cost Optimization

### Current Costs
- **Setup job:** Ubuntu (free tier) - ~$0
- **Web tests:** Ubuntu (free tier) - ~$0
- **iOS tests:** macOS (paid) - ~$12/month (400 min/month)
- **Android tests:** Ubuntu (free tier) - ~$0
- **Result aggregation:** Ubuntu (free tier) - ~$0

**Monthly cost estimate:** ~$12-15 (macOS minutes)

### Cost Reduction Tips
1. Use Ubuntu runners when possible (free)
2. Optimize job timeouts (don't over-allocate)
3. Use caching aggressively (avoid reinstalls)
4. Consider scheduled tests (less frequent on non-main branches)

### Cost Increase Scenarios
- Adding Windows tests (paid runner)
- Increasing test frequency (more runs)
- Using larger runners for faster execution

## Security Considerations

### Secrets Management
- No secrets are currently used in this workflow
- If credentials needed (API keys, certificates):
  ```yaml
  - name: 'Use secret'
    run: echo ${{ secrets.MY_SECRET }}
  ```

### Artifact Security
- Artifacts stored for 30 days (configurable)
- Test logs may contain sensitive output
- Always review before sharing

### Workflow Permissions
- Current: Minimal permissions (read-only for most)
- PR comments: Requires `pull-requests: write` permission
- Add explicit permissions to workflow:
  ```yaml
  permissions:
    contents: read
    pull-requests: write
  ```

## References

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Flutter Testing Guide](https://flutter.dev/docs/testing)
- [Flutter Integration Testing](https://flutter.dev/docs/testing/integration-tests)
- [GitHub Actions Caching](https://docs.github.com/en/actions/using-workflows/caching-dependencies-and-artifacts)
