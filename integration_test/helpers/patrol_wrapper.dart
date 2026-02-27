import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mocktail/mocktail.dart';

/// Wraps a standard [WidgetTester] in a [PatrolIntegrationTester] to provide
/// the $ finder and auto-waiting logic without needing Patrol's custom binding.
PatrolIntegrationTester wrapTester(WidgetTester tester) {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Use mocks for all non-mobile platforms (Desktop, Web) to avoid unnecessary 
  // Platform access and potential crashes in Patrol's native automators.
  if (kIsWeb || (defaultTargetPlatform != TargetPlatform.android && defaultTargetPlatform != TargetPlatform.iOS)) {
    return PatrolIntegrationTester(
      tester: tester,
      config: const PatrolTesterConfig(),
      nativeAutomator: _MockNativeAutomator(),
      nativeAutomator2: _MockNativeAutomator2(),
    );
  }

  return PatrolIntegrationTester(
    tester: tester,
    config: const PatrolTesterConfig(),
    nativeAutomator: NativeAutomator(config: const NativeAutomatorConfig()),
    nativeAutomator2: NativeAutomator2(config: const NativeAutomatorConfig()),
  );
}

class _MockNativeAutomator extends Mock implements NativeAutomator {}

class _MockNativeAutomator2 extends Mock implements NativeAutomator2 {}
