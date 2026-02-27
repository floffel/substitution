import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:integration_test/integration_test.dart';

/// Wraps a standard [WidgetTester] in a [PatrolIntegrationTester] to provide
/// the $ finder and auto-waiting logic without needing Patrol's custom binding.
PatrolIntegrationTester wrapTester(WidgetTester tester) {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  return PatrolIntegrationTester(
    tester: tester,
    config: const PatrolTesterConfig(),
    nativeAutomator: NativeAutomator(config: const NativeAutomatorConfig()),
    nativeAutomator2: NativeAutomator2(config: const NativeAutomatorConfig()),
  );
}
