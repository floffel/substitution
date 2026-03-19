/// Automated Play Store screenshot generation.
///
/// Captures 8 screenshots at 1080x1920 (phone portrait) resolution covering
/// all major app screens. Screenshots are saved via the integration test
/// binding's `takeScreenshot()` method.
///
/// Prerequisites:
///   - Matrix test server running with screenshot data:
///     docker compose -f docker-compose.yml -f docker-compose.screenshots.yml \
///       up -d postgres matrix-synapse redis
///     docker compose -f docker-compose.yml -f docker-compose.screenshots.yml \
///       run --rm matrix-init
///
/// Run (Linux desktop):
///   xvfb-run --auto-servernum --server-args="-screen 0 1080x1920x24" \
///     flutter test integration_test/screenshot_test.dart \
///       --dart-define=INTEGRATION_TEST=true \
///       --dart-define=MATRIX_SERVER=http://localhost:8008 \
///       -d linux
library;

import 'dart:io' as dart_io;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:introduction_screen/introduction_screen.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:substitution/main.dart' as app;
import 'package:substitution/post/widgets/post.dart';
import 'package:substitution/profile/pages/user_profile.dart';
import 'package:substitution/shared/pages/age_gate.dart';
import 'package:substitution/write/pages/roomselect.dart';

import 'helpers/integration_test_helper.dart'
    show skipIfNoMatrix, fastWait, settle, waitForMatrixClient;
import 'helpers/patrol_helper.dart' as patrol_helper;
import 'helpers/patrol_wrapper.dart';

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const _testMatrixServer = String.fromEnvironment(
  'MATRIX_SERVER',
  defaultValue: 'http://localhost:8008',
);
const _testUser = 'testuser1';
const _testPassword = 'testpass123';

/// Phone portrait resolution for Play Store screenshots.
const _phoneWidth = 1080.0;
const _phoneHeight = 1920.0;

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Takes a named screenshot, handling platform differences.
///
/// On non-web platforms that use a software surface (Linux desktop), the
/// Flutter surface must first be converted to an image. The resulting PNG
/// bytes are written to `android_playstore/Screenshots/englisch/<name>.png`
/// when running on a platform with dart:io (i.e. not web).
Future<void> takeNamedScreenshot(
  IntegrationTestWidgetsFlutterBinding binding,
  WidgetTester tester,
  String name,
) async {
  // Give animations / shimmer a moment to settle.
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(milliseconds: 500));

  // On desktop (Linux/macOS/Windows) the Flutter surface must be converted
  // to a raster image before takeScreenshot will produce usable bytes.
  if (!kIsWeb) {
    await binding.convertFlutterSurfaceToImage();
    await tester.pump();
  }

  final bytes = await binding.takeScreenshot(name);

  // Write the PNG to disk (only works with dart:io).
  if (!kIsWeb) {
    // Resolve project root relative to the test's working directory.
    // In CI the CWD is the project root; locally it may vary.
    final outDir = dart_io.Directory('android_playstore/Screenshots/englisch');
    if (!await outDir.exists()) {
      await outDir.create(recursive: true);
    }
    final file = dart_io.File('${outDir.path}/$name.png');
    await file.writeAsBytes(bytes);
    debugPrint('SCREENSHOT: Saved ${file.path} (${bytes.length} bytes)');
  }
}

/// Standard setUp: clean Matrix state, delete old DB, pre-confirm age gate.
Future<void> _setUp() async {
  try {
    app.globalMatrixClient?.abortSync();
    await app.globalMatrixClient?.dispose();
  } catch (e) {
    debugPrint('SCREENSHOT: Cleanup warning: $e');
  }
  app.globalMatrixClient = null;
  app.globalSubstitutionService = null;

  if (!kIsWeb) {
    try {
      final appDocDir = await getApplicationDocumentsDirectory();
      final mainDb = dart_io.File('${appDocDir.path}/matrix_database.db');
      if (await mainDb.exists()) {
        await mainDb.delete();
      }
    } catch (_) {}
  }

  await Future.delayed(const Duration(milliseconds: 500));
}

/// Standard tearDown: dispose Matrix client.
Future<void> _tearDown() async {
  try {
    app.globalMatrixClient?.abortSync();
    await app.globalMatrixClient?.dispose();
  } catch (e) {
    debugPrint('SCREENSHOT: Tear-down warning: $e');
  }
  app.globalMatrixClient = null;
  app.globalSubstitutionService = null;

  if (!kIsWeb) {
    try {
      final appDocDir = await getApplicationDocumentsDirectory();
      final dbFile = dart_io.File('${appDocDir.path}/matrix_database.db');
      if (await dbFile.exists()) {
        await dbFile.delete();
      }
    } catch (_) {}
  }

  await Future.delayed(const Duration(milliseconds: 500));
}

/// Set the test view to phone portrait dimensions.
void _setPhoneViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(_phoneWidth, _phoneHeight);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() => tester.view.resetPhysicalSize());
  addTearDown(() => tester.view.resetDevicePixelRatio());
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // =======================================================================
  // Screenshot 1: Onboarding / Introduction
  // =======================================================================
  group('Screenshot: Onboarding', () {
    setUp(() async {
      if (!await skipIfNoMatrix(matrixServer: _testMatrixServer)) return;
      await _setUp();
      // Do NOT pre-confirm age gate — we want to see the intro screen.
      SharedPreferences.setMockInitialValues({'age_confirmed': true});
      AgeGatePage.confirmed = true;
    });

    tearDown(_tearDown);

    testWidgets('01_onboarding', (tester) async {
      _setPhoneViewport(tester);
      final $ = wrapTester(tester);

      app.main();
      await waitForMatrixClient($.tester);

      // Wait for intro screen to appear
      debugPrint('SCREENSHOT: Waiting for IntroductionScreen...');
      await fastWait(
        $.tester,
        () =>
            $(IntroductionScreen).exists ||
            $(Key('hostServerInput')).exists ||
            $(Key('ageGateConfirmButton')).exists,
        timeout: const Duration(seconds: 30),
      );

      // Handle age gate if it appears
      if ($(Key('ageGateConfirmButton')).exists) {
        await $(Key('ageGateConfirmButton')).tap();
        await fastWait(
          $.tester,
          () => $(IntroductionScreen).exists,
          timeout: const Duration(seconds: 15),
        );
      }

      // We should now be on the IntroductionScreen (first page = Welcome)
      if ($(IntroductionScreen).exists) {
        await settle($.tester, count: 3);
        await takeNamedScreenshot(binding, tester, '01_onboarding');
        debugPrint('SCREENSHOT: 01_onboarding captured');
      } else {
        debugPrint(
          'SCREENSHOT: WARNING — IntroductionScreen not found, skipping',
        );
      }
    }, timeout: const Timeout(Duration(minutes: 5)));
  });

  // =======================================================================
  // Screenshots 2–8: Post-login screens
  // =======================================================================
  group('Screenshot: App screens', () {
    setUp(() async {
      if (!await skipIfNoMatrix(matrixServer: _testMatrixServer)) return;
      await _setUp();
      SharedPreferences.setMockInitialValues({'age_confirmed': true});
      AgeGatePage.confirmed = true;
    });

    tearDown(_tearDown);

    testWidgets(
      'Capture all post-login screenshots',
      (tester) async {
        _setPhoneViewport(tester);
        final $ = wrapTester(tester);

        app.main();
        await waitForMatrixClient($.tester);

        // --- Login ---
        debugPrint('SCREENSHOT: Logging in...');
        if (!await patrol_helper.loginUser(
          $,
          matrixServer: _testMatrixServer,
          username: _testUser,
          password: _testPassword,
        )) {
          debugPrint('SCREENSHOT: Login failed — aborting');
          return;
        }

        // Wait for feed to load
        debugPrint('SCREENSHOT: Waiting for feed content...');
        await fastWait(
          $.tester,
          () => $(PostWidget).exists || $(Scrollable).exists,
          timeout: const Duration(seconds: 60),
        );
        // Extra pumps to let images/shimmer settle
        await settle(
          $.tester,
          count: 8,
          interval: const Duration(milliseconds: 500),
        );

        // ---- 02: Home Feed ----
        debugPrint('SCREENSHOT: Capturing 02_home_feed...');
        await takeNamedScreenshot(binding, tester, '02_home_feed');

        // ---- 03: Post Detail ----
        debugPrint('SCREENSHOT: Navigating to post detail...');
        if ($(PostWidget).exists) {
          await $(PostWidget).first.tap();
          await settle($.tester, count: 5);
          await takeNamedScreenshot(binding, tester, '03_post_detail');
          debugPrint('SCREENSHOT: 03_post_detail captured');

          // Go back to feed
          final backButton = $(find.byIcon(Icons.arrow_back));
          if (backButton.exists) {
            await backButton.tap();
            await settle($.tester, count: 3);
          } else {
            // Use system back / navigator pop
            final navigator = tester.state<NavigatorState>(
              find.byType(Navigator).last,
            );
            navigator.pop();
            await settle($.tester, count: 3);
          }
        } else {
          debugPrint(
            'SCREENSHOT: WARNING — No PostWidget found, skipping 03_post_detail',
          );
        }

        // ---- 04: Discover ----
        debugPrint('SCREENSHOT: Navigating to Discover tab...');
        final discoverNav = $(Key('navDiscover'));
        if (discoverNav.exists) {
          await discoverNav.tap();
          await settle(
            $.tester,
            count: 8,
            interval: const Duration(milliseconds: 500),
          );
          await takeNamedScreenshot(binding, tester, '04_discover');
          debugPrint('SCREENSHOT: 04_discover captured');
        } else {
          debugPrint('SCREENSHOT: WARNING — navDiscover not found');
        }

        // ---- 05: Messages ----
        debugPrint('SCREENSHOT: Navigating to Messages tab...');
        final messagesNav = $(Key('navMessages'));
        if (messagesNav.exists) {
          await messagesNav.tap();
          await settle($.tester, count: 5);
          await takeNamedScreenshot(binding, tester, '05_messages');
          debugPrint('SCREENSHOT: 05_messages captured');
        } else {
          debugPrint('SCREENSHOT: WARNING — navMessages not found');
        }

        // ---- 06: Write / Compose (Room Select) ----
        // Navigate back to Home tab first (FAB only visible on tab 0)
        debugPrint('SCREENSHOT: Navigating to Write...');
        final homeNav = $(Key('navHome'));
        if (homeNav.exists) {
          await homeNav.tap();
          await settle($.tester, count: 3);
        }
        final fab = $(Key('fabNewPost'));
        if (fab.exists) {
          await fab.tap();
          await fastWait(
            $.tester,
            () => $(RoomSelectPage).exists,
            timeout: const Duration(seconds: 15),
          );
          await settle($.tester, count: 3);
          await takeNamedScreenshot(binding, tester, '06_write');
          debugPrint('SCREENSHOT: 06_write captured');

          // Go back to feed
          final backButton = $(find.byIcon(Icons.arrow_back));
          if (backButton.exists) {
            await backButton.tap();
            await settle($.tester, count: 3);
          }
        } else {
          debugPrint('SCREENSHOT: WARNING — fabNewPost not found');
        }

        // ---- 07: User Profile ----
        debugPrint('SCREENSHOT: Navigating to user profile...');
        // Make sure we're on the home tab
        if (homeNav.exists) {
          await homeNav.tap();
          await settle($.tester, count: 3);
        }
        // Tap a CircleAvatar in the feed to navigate to a profile
        final avatar = $(CircleAvatar);
        if (avatar.exists) {
          await avatar.first.tap();
          await fastWait(
            $.tester,
            () => $(UserProfilePage).exists,
            timeout: const Duration(seconds: 30),
          );
          await settle($.tester, count: 5);
          await takeNamedScreenshot(binding, tester, '07_profile');
          debugPrint('SCREENSHOT: 07_profile captured');

          // Go back to feed
          final backButton = $(find.byIcon(Icons.arrow_back));
          if (backButton.exists) {
            await backButton.tap();
            await settle($.tester, count: 3);
          }
        } else {
          debugPrint(
            'SCREENSHOT: WARNING — No CircleAvatar found, skipping 07_profile',
          );
        }

        // ---- 08: Settings ----
        debugPrint('SCREENSHOT: Navigating to Settings tab...');
        final settingsNav = $(Key('navSettings'));
        if (settingsNav.exists) {
          await settingsNav.tap();
          await settle($.tester, count: 5);
          await takeNamedScreenshot(binding, tester, '08_settings');
          debugPrint('SCREENSHOT: 08_settings captured');
        } else {
          debugPrint('SCREENSHOT: WARNING — navSettings not found');
        }

        debugPrint('SCREENSHOT: All screenshots captured successfully!');
      },
      timeout: const Timeout(Duration(minutes: 15)),
    );
  });
}
