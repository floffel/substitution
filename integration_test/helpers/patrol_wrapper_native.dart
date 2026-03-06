import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mocktail/mocktail.dart';
import 'integration_test_helper.dart' show disableAnimations;

/// Native implementation of wrapTester
PatrolIntegrationTester wrapTester(WidgetTester tester) {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  disableAnimations(tester);

  // Use a generous existsTimeout/visibleTimeout so Patrol finders don't fire
  // prematurely while waitForMatrixClient (up to 90s) is running.
  const config = PatrolTesterConfig(
    existsTimeout: Duration(minutes: 3),
    visibleTimeout: Duration(minutes: 3),
  );

  // Use mocks for all non-mobile platforms (Desktop) to avoid unnecessary
  // Platform access and potential crashes in Patrol's native automators.
  if (defaultTargetPlatform != TargetPlatform.android &&
      defaultTargetPlatform != TargetPlatform.iOS) {
    return PatrolIntegrationTester(
      tester: tester,
      config: config,
      nativeAutomator: _MockNativeAutomator(),
      nativeAutomator2: _MockNativeAutomator2(),
    );
  }

  // Increase NativeAutomatorConfig.findTimeout from the default 10s to 3
  // minutes.  This is the gRPC heartbeat timeout between the Dart test runner
  // and the Patrol native server on the device.  Without this, the native
  // automator declares the test dead after 10s whenever waitForMatrixClient
  // (which pumps for up to 90s) is in progress.
  // connectionTimeout must be strictly greater than findTimeout (asserted by
  // the Patrol constructor), so raise it to 5 minutes.
  const nativeConfig = NativeAutomatorConfig(
    connectionTimeout: Duration(minutes: 5),
    findTimeout: Duration(minutes: 3),
  );

  return PatrolIntegrationTester(
    tester: tester,
    config: config,
    nativeAutomator: NativeAutomator(config: nativeConfig),
    nativeAutomator2: NativeAutomator2(config: nativeConfig),
  );
}

class _MockNativeAutomator extends Mock implements NativeAutomator {}

class _MockNativeAutomator2 extends Mock implements NativeAutomator2 {}
