import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mocktail/mocktail.dart';
import 'integration_test_helper.dart' show disableAnimations;

// On Web, PlatformAutomator cannot be instantiated (it uses dart:io internally),
// so we use a mock that satisfies the type system without calling any native code.

/// Web implementation of wrapTester
PatrolIntegrationTester wrapTester(WidgetTester tester) {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  disableAnimations(tester);

  return PatrolIntegrationTester(
    tester: tester,
    config: const PatrolTesterConfig(),
    platformAutomator: _MockPlatformAutomator(),
  );
}

class _MockPlatformAutomator extends Mock implements PlatformAutomator {}
