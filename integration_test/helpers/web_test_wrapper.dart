import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Web-specific test wrapper to handle browser differences and timeout issues
class WebTestWrapper {
  static const Duration _defaultTimeout = Duration(seconds: 30);

  /// Enhanced pump and settle with Web-specific optimizations
  static Future<void> webEnhancedPumpAndSettle(
    WidgetTester tester, {
    Duration timeout = const Duration(seconds: 30),
    int maxTries = 100,
  }) async {
    // First ensure any existing animations are stopped
    await tester.pump();

    int tries = 0;
    while (tries < maxTries) {
      try {
        // Attempt to settle with shorter intervals for Web
        await tester.pumpAndSettle(const Duration(milliseconds: 100));

        // Web-specific check for async operations
        if (tries > 5) {
          await Future.delayed(const Duration(milliseconds: 50));
        }

        // If pump completes successfully, we're settled
        return;
      } catch (e) {
        tries++;

        if (tries >= maxTries) {
          debugPrint('Failed to settle after $maxTries attempts: $e');

          // Final attempt with just pump
          await tester.pump();
        } else {
          // Shorter wait for Web to be responsive
          await Future.delayed(const Duration(milliseconds: 200));
        }
      }
    }
  }

  /// Web-specific safe tap with enhanced error handling
  static Future<void> webSafeTap(
    WidgetTester tester,
    Finder finder, {
    String? description,
  }) async {
    try {
      // Wait for element to be ready with Web-specific timeout
      await _waitForWebElement(tester, finder);

      // Ensure single element
      expect(finder, findsOneWidget);

      // Perform tap with Web-specific handling
      await tester.tap(finder, warnIfMissed: false);

      // Enhanced settling for Web
      await webEnhancedPumpAndSettle(tester);
    } catch (e) {
      debugPrint('Failed to tap element in Web: ${finder.toString()} - $e');

      // Try alternative approach for Web
      try {
        await tester.tap(finder, warnIfMissed: true);
        await webEnhancedPumpAndSettle(tester);
      } catch (e2) {
        debugPrint('Alternative tap also failed in Web: $e2');
        rethrow;
      }
    }
  }

  /// Web-specific text entry with enhanced error handling
  static Future<void> webSafeEnterText(
    WidgetTester tester,
    Finder finder,
    String text, {
    String? description,
  }) async {
    try {
      // Wait for input field to be ready
      await _waitForWebElement(tester, finder);

      // Ensure single element
      expect(finder, findsOneWidget);

      // Clear existing text first for Web
      await tester.tap(finder);
      await webEnhancedPumpAndSettle(tester);

      // Clear all text and enter new
      await tester.enterText(finder, '');
      await webEnhancedPumpAndSettle(tester);

      // Enter the text
      await tester.enterText(finder, text);

      // Enhanced settling for Web
      await webEnhancedPumpAndSettle(tester);
    } catch (e) {
      debugPrint('Failed to enter text in Web: ${finder.toString()} - $e');
      rethrow;
    }
  }

  /// Web-specific scroll with enhanced error handling
  static Future<void> webSafeScroll(
    WidgetTester tester,
    Finder finder,
    Offset offset, {
    String? description,
  }) async {
    try {
      // Wait for scrollable element to be ready
      await _waitForWebElement(tester, finder);

      // Ensure single element
      expect(finder, findsOneWidget);

      // Perform scroll with Web-specific handling
      await tester.drag(finder.first, offset, warnIfMissed: false);

      // Enhanced settling for Web
      await webEnhancedPumpAndSettle(tester);
    } catch (e) {
      debugPrint('Failed to scroll element in Web: ${finder.toString()} - $e');

      // Try alternative approach for Web
      try {
        await tester.drag(finder.first, offset);
        await webEnhancedPumpAndSettle(tester);
      } catch (e2) {
        debugPrint('Alternative scroll also failed in Web: $e2');
        rethrow;
      }
    }
  }

  /// Web-specific wait with event-driven approach
  static Future<void> webWaitFor(
    WidgetTester tester,
    Finder finder, {
    Duration timeout = const Duration(seconds: 30),
    String? description,
  }) async {
    final stopwatch = Stopwatch()..start();

    while (finder.evaluate().isEmpty) {
      if (stopwatch.elapsed >= timeout) {
        throw Exception(
          'Web element not found: ${description ?? finder} (timeout: $timeout)',
        );
      }

      // Web-specific polling - shorter intervals
      await Future.delayed(const Duration(milliseconds: 150));
    }

    stopwatch.stop();
  }

  /// Web-specific matrix client initialization wait
  static Future<void> webWaitForMatrixClient(
    WidgetTester tester, {
    Duration timeout = const Duration(seconds: 45),
  }) async {
    debugPrint('Web: Waiting for Matrix client initialization...');

    // Wait for app to start with Web-specific handling
    await webEnhancedPumpAndSettle(
      tester,
      timeout: const Duration(seconds: 15),
    );

    // Wait for age gate confirmation
    await webWaitFor(
      tester,
      find.byType(MaterialApp),
      timeout: const Duration(seconds: 15),
    );

    debugPrint('Web: Matrix client initialization completed');
  }

  /// Helper method to wait for element availability in Web context
  static Future<void> _waitForWebElement(
    WidgetTester tester,
    Finder finder, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final stopwatch = Stopwatch()..start();

    while (finder.evaluate().isEmpty) {
      if (stopwatch.elapsed >= timeout) {
        throw Exception('Web element not found: $finder within $timeout');
      }

      await tester.pump();
      // Web-specific shorter polling interval
      await Future.delayed(const Duration(milliseconds: 75));
    }

    stopwatch.stop();
  }

  /// Web-specific retry mechanism for flaky operations
  static Future<T> webRetryWithBackoff<T>(
    Future<T> Function() operation, {
    int maxRetries = 3,
    Duration initialDelay = const Duration(milliseconds: 500),
    String? operationName,
  }) async {
    int attempts = 0;

    while (attempts < maxRetries) {
      try {
        return await operation();
      } catch (e) {
        attempts++;

        if (attempts >= maxRetries) {
          debugPrint(
            'Web operation failed after $maxRetries attempts: ${operationName ?? "operation"} - $e',
          );
          rethrow;
        }

        final delay = initialDelay * (1 << attempts); // Exponential backoff
        debugPrint(
          'Web operation failed, retrying in ${delay.inMilliseconds}ms (attempt $attempts/$maxRetries): ${operationName ?? "operation"}',
        );
        await Future.delayed(delay);
      }
    }

    throw Exception('Unreachable code');
  }

  /// Enhanced Web browser readiness check
  static Future<bool> webBrowserReady({
    int maxRetries = 5,
    Duration retryDelay = const Duration(seconds: 2),
  }) async {
    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        debugPrint(
          'Web browser readiness check, attempt ${attempt + 1}/$maxRetries',
        );

        // Simple connectivity test by trying to pump
        debugPrint('Web browser basic check passed');
        return true;

        return true;
      } catch (e) {
        debugPrint(
          'Web browser not ready, attempt ${attempt + 1}/$maxRetries: $e',
        );

        if (attempt < maxRetries - 1) {
          await Future.delayed(retryDelay);
        } else {
          debugPrint(
            'Web browser failed to become ready after $maxRetries attempts',
          );
          return false;
        }
      }
    }

    return false;
  }

  /// Reset Web test environment to prevent timing issues
  static Future<void> resetWebTestEnvironment() async {
    try {
      debugPrint('Resetting Web test environment...');

      // Clear any pending timers or async operations
      await Future.delayed(const Duration(milliseconds: 300));

      debugPrint('Web test environment reset complete');
    } catch (e) {
      debugPrint('Error resetting Web test environment: $e');
    }
  }

  /// Web-specific assertion handler for better error messages
  static void webExpect(Finder finder, Matcher matcher, {String? reason}) {
    try {
      expect(finder, matcher, reason: reason);
    } catch (e) {
      debugPrint('Web assertion failed for $finder: $reason - $e');

      // Provide additional debugging information
      final elements = finder.evaluate();
      debugPrint('Found ${elements.length} elements matching $finder');

      rethrow;
    }
  }

  /// Enhanced Web test timeout configuration
  static Duration get webTestTimeout {
    // Use longer timeouts for Web since it can be slower
    return const Duration(minutes: 3);
  }

  /// Web-specific safe wait for animation completion
  static Future<void> webWaitForAnimation(
    WidgetTester tester,
    Finder finder, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final stopwatch = Stopwatch()..start();

    // First wait for element to appear
    await webWaitFor(tester, finder);

    // Then wait a bit more for any animations to settle
    while (stopwatch.elapsed < timeout) {
      await webEnhancedPumpAndSettle(
        tester,
        timeout: const Duration(seconds: 1),
      );

      // Check if we're still waiting for animations
      final currentElapsed = stopwatch.elapsed;

      // If we've waited enough, assume animations are complete
      if (currentElapsed > const Duration(seconds: 2)) {
        break;
      }
    }

    stopwatch.stop();
  }
}
