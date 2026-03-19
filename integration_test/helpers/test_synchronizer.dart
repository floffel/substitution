import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Test synchronization helper to prevent Flutter binding assertion errors
class TestSynchronizer {
  static const Duration _defaultSettleDelay = Duration(milliseconds: 200);

  /// Enhanced pump and settle with proper synchronization to prevent binding errors
  static Future<void> synchronizedPumpAndSettle(
    WidgetTester tester, {
    Duration settleTimeout = const Duration(seconds: 30),
    int maxPumpAttempts = 10,
  }) async {
    // Initial pump to clear any pending operations
    await tester.pump();
    await Future.delayed(_defaultSettleDelay);

    // Use bounded pumps instead of pumpAndSettle, which can hang indefinitely
    // when background activity (Matrix sync, paging fetches) keeps the
    // Flutter scheduler busy. Pump for settleTimeout duration total,
    // checking after each 100ms interval.
    final deadline = DateTime.now().add(settleTimeout);
    while (DateTime.now().isBefore(deadline)) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    // Final small delay to ensure everything is stable
    await Future.delayed(_defaultSettleDelay);
  }

  /// Safe test interaction with automatic synchronization
  static Future<void> safeTestInteraction(
    WidgetTester tester,
    Function(WidgetTester) interaction, {
    String? description,
  }) async {
    try {
      // Ensure we're in a stable state before interaction
      await synchronizedPumpAndSettle(tester);

      // Perform the interaction
      if (interaction is Future Function(WidgetTester)) {
        await interaction(tester);
      } else {
        interaction(tester);
      }

      // Ensure everything settles after the interaction
      await synchronizedPumpAndSettle(tester);
    } catch (e) {
      debugPrint('Safe test interaction failed for $description: $e');

      // Try to recover with a simple pump
      try {
        await tester.pump();
      } catch (pumpError) {
        debugPrint('Recovery pump failed: $pumpError');
      }

      rethrow;
    }
  }

  /// Enhanced wait for condition with synchronization
  static Future<void> synchronizedWaitFor(
    WidgetTester tester,
    bool Function() condition, {
    Duration timeout = const Duration(seconds: 30),
    String? description,
  }) async {
    final stopwatch = Stopwatch()..start();

    while (!condition()) {
      if (stopwatch.elapsed >= timeout) {
        throw Exception(
          'Synchronized wait timed out: ${description ?? "condition"}',
        );
      }

      // Small pump to help the system progress
      await tester.pump(const Duration(milliseconds: 50));

      // Wait a bit before checking again
      await Future.delayed(const Duration(milliseconds: 100));
    }

    stopwatch.stop();

    // Final synchronization after condition is met
    await synchronizedPumpAndSettle(tester);
  }

  /// Test cleanup to prevent binding conflicts between tests
  static Future<void> testCleanup(WidgetTester tester) async {
    try {
      debugPrint('TestSynchronizer: Performing test cleanup...');

      // Final pump to ensure no pending operations
      await tester.pump();

      // Wait for any animations or async operations to complete
      await Future.delayed(const Duration(milliseconds: 300));

      // Additional pump to clear any lingering state
      await tester.pump();

      debugPrint('TestSynchronizer: Test cleanup completed');
    } catch (e) {
      debugPrint('Test synchronization error during cleanup: $e');

      // Try simple pump as fallback
      try {
        await tester.pump();
      } catch (_) {
        debugPrint('Fallback cleanup pump failed, continuing...');
      }
    }
  }

  /// Enhanced tap with automatic synchronization
  static Future<void> synchronizedTap(
    WidgetTester tester,
    Finder finder, {
    String? description,
  }) async {
    return safeTestInteraction(
      tester,
      (WidgetTester t) => t.tap(finder),
      description: description,
    );
  }

  /// Enhanced enter text with automatic synchronization
  static Future<void> synchronizedEnterText(
    WidgetTester tester,
    Finder finder,
    String text, {
    String? description,
  }) async {
    return safeTestInteraction(
      tester,
      (WidgetTester t) => t.enterText(finder, text),
      description: description,
    );
  }

  /// Enhanced scroll with automatic synchronization
  static Future<void> synchronizedScroll(
    WidgetTester tester,
    Finder finder,
    Offset offset, {
    String? description,
  }) async {
    return safeTestInteraction(
      tester,
      (WidgetTester t) => t.drag(finder.first, offset),
      description: description,
    );
  }

  /// Wait for widget to be present with synchronization
  static Future<void> synchronizedWaitForWidget(
    WidgetTester tester,
    Finder finder, {
    Duration timeout = const Duration(seconds: 30),
    String? description,
  }) async {
    await synchronizedWaitFor(
      tester,
      () => finder.evaluate().isNotEmpty,
      timeout: timeout,
      description: description ?? 'widget $finder',
    );
  }

  /// Create a test widget wrapper with automatic synchronization
  static WidgetTesterCallback createSynchronizedTest(
    String name,
    WidgetTesterCallback body, {
    Duration timeout = const Duration(
      minutes: 10,
    ), // Increased for CI reliability
  }) {
    return (WidgetTester tester) async {
      try {
        // Initial state setup
        debugPrint('TestSynchronizer: Starting synchronized test $name');

        // Run the actual test body with synchronization
        await safeTestInteraction(tester, (t) async {
          // Run the test body and ensure it returns properly
          await body(t);
        }, description: name);
      } catch (e, stack) {
        debugPrint('TestSynchronizer: Test failed $name - $e');
        debugPrint(stack.toString());

        // Ensure we clean up even on failure
        await testCleanup(tester);

        rethrow;
      } finally {
        // Always cleanup at the end
        await testCleanup(tester);
        debugPrint('TestSynchronizer: Completed synchronized test $name');
      }
    };
  }

  /// Enhanced matrix client wait with synchronization
  static Future<void> synchronizedWaitForMatrixClient(
    WidgetTester tester, {
    Duration timeout = const Duration(seconds: 60),
  }) async {
    debugPrint('TestSynchronizer: Waiting for Matrix client...');

    // Wait for app initialization with proper synchronization
    await synchronizedPumpAndSettle(
      tester,
      settleTimeout: const Duration(seconds: 15),
    );

    // Additional wait for Matrix client specific initialization
    await synchronizedWaitFor(
      tester,
      () {
        try {
          final contexts = find.byType(MaterialApp).evaluate();
          return contexts.isNotEmpty;
        } catch (_) {
          return false;
        }
      },
      timeout: const Duration(seconds: 20),
      description: 'Matrix client initialization',
    );

    debugPrint('TestSynchronizer: Matrix client ready');
  }
}
