import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mocktail/mocktail.dart';
import 'integration_test_helper.dart' show disableAnimations;

// On Web, NativeAutomator cannot be instantiated (it uses dart:io internally),
// so we use mocks that satisfy the type system without calling any native code.

/// Web implementation of wrapTester
PatrolIntegrationTester wrapTester(WidgetTester tester) {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  disableAnimations(tester);

  return PatrolIntegrationTester(
    tester: tester,
    config: const PatrolTesterConfig(),
    nativeAutomator: _MockNativeAutomator(),
    nativeAutomator2: _MockNativeAutomator2(),
  );
}

class _MockNativeAutomator extends Mock implements NativeAutomator {}

class _MockNativeAutomator2 extends Mock implements NativeAutomator2 {}
