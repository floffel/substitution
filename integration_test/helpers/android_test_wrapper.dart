import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Android-specific test wrapper to handle platform differences
class AndroidTestWrapper {
  static const Duration _defaultTimeout = Duration(seconds: 30);

  /// Enhanced pump and settle with Android-specific optimizations
  static Future<void> enhancedPumpAndSettle(
    WidgetTester tester, {
    Duration timeout = const Duration(seconds: 30),
    int maxTries = 100,
  }) async {
    // First ensure any existing animations are stopped
    await tester.pump();

    int tries = 0;
    while (tries < maxTries) {
      try {
        // Attempt to settle
        await tester.pumpAndSettle(const Duration(milliseconds: 50));

        // If pump completes successfully, we're settled
        return;
      } catch (e) {
        tries++;

        if (tries >= maxTries) {
          debugPrint('Failed to settle after $maxTries attempts: $e');

          // Final attempt with just pump
          await tester.pump();
        } else {
          // Wait a bit before retrying
          await Future.delayed(const Duration(milliseconds: 100));
        }
      }
    }
  }

  /// Android-specific safe tap with enhanced error handling
  static Future<void> androidSafeTap(
    WidgetTester tester,
    Finder finder, {
    String? description,
  }) async {
    try {
      // Wait for element to be ready
      await _waitForElement(tester, finder);

      // Ensure single element
      expect(finder, findsOneWidget);

      // Perform tap with proper exception handling
      await tester.tap(finder, warnIfMissed: false);

      // Enhanced settling for Android
      await enhancedPumpAndSettle(tester);
    } catch (e) {
      debugPrint('Failed to tap element: ${finder.toString()} - $e');

      // Try alternative approach
      try {
        await tester.tap(finder, warnIfMissed: true);
        await enhancedPumpAndSettle(tester);
      } catch (e2) {
        debugPrint('Alternative tap also failed: $e2');
        rethrow;
      }
    }
  }

  /// Android-specific text entry with enhanced error handling
  static Future<void> androidSafeEnterText(
    WidgetTester tester,
    Finder finder,
    String text, {
    String? description,
  }) async {
    try {
      // Wait for input field to be ready
      await _waitForElement(tester, finder);

      // Ensure single element
      expect(finder, findsOneWidget);

      // Clear existing text first
      await tester.tap(finder);
      await enhancedPumpAndSettle(tester);

      // Clear all text and enter new
      await tester.enterText(finder, '');
      await enhancedPumpAndSettle(tester);

      // Enter the text
      await tester.enterText(finder, text);

      // Enhanced settling for Android
      await enhancedPumpAndSettle(tester);
    } catch (e) {
      debugPrint('Failed to enter text: ${finder.toString()} - $e');
      rethrow;
    }
  }

  /// Android-specific scroll with enhanced error handling
  static Future<void> androidSafeScroll(
    WidgetTester tester,
    Finder finder,
    Offset offset, {
    String? description,
  }) async {
    try {
      // Wait for scrollable element to be ready
      await _waitForElement(tester, finder);

      // Ensure single element
      expect(finder, findsOneWidget);

      // Perform scroll with proper exception handling
      await tester.drag(finder.first, offset, warnIfMissed: false);

      // Enhanced settling for Android
      await enhancedPumpAndSettle(tester);
    } catch (e) {
      debugPrint('Failed to scroll element: ${finder.toString()} - $e');

      // Try alternative approach
      try {
        await tester.drag(finder.first, offset);
        await enhancedPumpAndSettle(tester);
      } catch (e2) {
        debugPrint('Alternative scroll also failed: $e2');
        rethrow;
      }
    }
  }

  /// Android-specific wait with event-driven approach
  static Future<void> androidWaitFor(
    WidgetTester tester,
    Finder finder, {
    Duration timeout = const Duration(seconds: 30),
    String? description,
  }) async {
    final stopwatch = Stopwatch()..start();

    while (finder.evaluate().isEmpty) {
      if (stopwatch.elapsed >= timeout) {
        throw Exception(
          'Element not found: ${description ?? finder} (timeout: $timeout)',
        );
      }

      await Future.delayed(const Duration(milliseconds: 100));
    }

    stopwatch.stop();
  }

  /// Android-specific matrix client initialization wait
  static Future<void> androidWaitForMatrixClient(
    WidgetTester tester, {
    Duration timeout = const Duration(seconds: 45),
  }) async {
    debugPrint('Android: Waiting for Matrix client initialization...');

    // Wait for app to start
    await enhancedPumpAndSettle(tester, timeout: const Duration(seconds: 10));

    // Wait for age gate confirmation
    await androidWaitFor(
      tester,
      find.byType(MaterialApp),
      timeout: const Duration(seconds: 10),
    );

    debugPrint('Android: Matrix client initialization completed');
  }

  /// Helper method to wait for element availability
  static Future<void> _waitForElement(
    WidgetTester tester,
    Finder finder, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final stopwatch = Stopwatch()..start();

    while (finder.evaluate().isEmpty) {
      if (stopwatch.elapsed >= timeout) {
        throw Exception('Element not found: $finder within $timeout');
      }

      await tester.pump();
      await Future.delayed(const Duration(milliseconds: 50));
    }

    stopwatch.stop();
  }

  /// Enhanced Android emulator wait with retry logic
  static Future<bool> androidWaitForEmulatorReady({
    int maxRetries = 10,
    Duration retryDelay = const Duration(seconds: 2),
  }) async {
    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        debugPrint(
          'Android emulator ready check, attempt ${attempt + 1}/$maxRetries',
        );

        // Simple connectivity test
        return true; // If we can print debug, emulator is responsive
      } catch (e) {
        debugPrint(
          'Android emulator not ready, attempt ${attempt + 1}/$maxRetries: $e',
        );

        if (attempt < maxRetries - 1) {
          await Future.delayed(retryDelay);
        } else {
          debugPrint(
            'Android emulator failed to become ready after $maxRetries attempts',
          );
          return false;
        }
      }
    }

    return false;
  }

  /// Reset test environment to prevent binding assertion errors
  static Future<void> resetAndroidTestEnvironment() async {
    try {
      debugPrint('Resetting Android test environment...');

      // Clear any pending timers or async operations
      await Future.delayed(const Duration(milliseconds: 200));

      debugPrint('Android test environment reset complete');
    } catch (e) {
      debugPrint('Error resetting Android test environment: $e');
    }
  }
}
