import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:integration_test/integration_test.dart';
import 'integration_test_helper.dart' show disableAnimations;

// On Web, we don't import NativeAutomator at all to avoid Platform access.
// We use dynamic/Object to pass dummies to the constructor.

/// Web implementation of wrapTester
PatrolIntegrationTester wrapTester(WidgetTester tester) {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  disableAnimations(tester);

  return PatrolIntegrationTester(
    tester: tester,
    config: const PatrolTesterConfig(),
    // These are ignored on Web by Patrol as long as we don't call native methods.
    // We pass them as null or dummy if the constructor allowed, but it requires non-null.
    // We use a hack to provide something that looks like them but doesn't crash on init.
    nativeAutomator: _DummyWebAutomator() as dynamic,
    nativeAutomator2: _DummyWebAutomator() as dynamic,
  );
}

// Minimal class that doesn't extend anything from Patrol to avoid Platform issues.
class _DummyWebAutomator {
  // No-op
}
