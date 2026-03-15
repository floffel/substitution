import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Event-driven test automation helpers to replace timeout-based testing
class TestAutomation {
  static const Duration _defaultTimeout = Duration(seconds: 30);
  static const Duration _pollingInterval = Duration(milliseconds: 100);

  /// Wait for a condition to become true using event-driven polling
  static Future<void> waitForCondition(
    bool Function() condition, {
    String? description,
    Duration timeout = _defaultTimeout,
  }) async {
    final stopwatch = Stopwatch()..start();

    while (!condition()) {
      if (stopwatch.elapsed >= timeout) {
        throw TimeoutException(
          'Condition ${description ?? "test condition"} not met within $timeout',
        );
      }

      await Future.delayed(_pollingInterval);
    }

    stopwatch.stop();
  }

  /// Wait for element to appear using event detection
  static Future<void> waitForElement(
    WidgetTester tester,
    Finder finder, {
    String? description,
    Duration timeout = _defaultTimeout,
  }) async {
    await waitForCondition(
      () => finder.evaluate().isNotEmpty,
      description: description ?? 'element $finder',
      timeout: timeout,
    );
  }

  /// Wait for element to disappear using event detection
  static Future<void> waitForElementToDisappear(
    WidgetTester tester,
    Finder finder, {
    String? description,
    Duration timeout = _defaultTimeout,
  }) async {
    await waitForCondition(
      () => finder.evaluate().isEmpty,
      description: description ?? 'element $finder to disappear',
      timeout: timeout,
    );
  }

  /// Wait for widget state change using event detection
  static Future<void> waitForStateChange<T>(
    WidgetTester tester,
    Finder finder,
    T Function(dynamic) getValue, {
    required T expectedValue,
    String? description,
    Duration timeout = _defaultTimeout,
  }) async {
    await waitForCondition(
      () => getValue(finder.evaluate().single.widget) == expectedValue,
      description: description ?? 'state change to $expectedValue',
      timeout: timeout,
    );
  }

  /// Safe tap with event verification
  static Future<void> safeTap(
    WidgetTester tester,
    Finder finder, {
    String? description,
  }) async {
    await waitForElement(tester, finder);

    // Ensure we have one and only one element
    final elements = finder.evaluate();
    if (elements.length != 1) {
      throw StateError(
        'Expected exactly one element for $finder, found ${elements.length}',
      );
    }

    final element = elements.single;

    // Verify the widget is visible and interactable
    expect(element, findsOneWidget);

    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  /// Safe scroll with event verification
  static Future<void> safeScroll(
    WidgetTester tester,
    Finder finder,
    Offset offset, {
    String? description,
  }) async {
    await waitForElement(tester, finder);

    final elements = finder.evaluate();
    expect(elements.length, 1);

    await tester.drag(finder.first, offset);
    await tester.pumpAndSettle();
  }

  /// Safe enter text with event verification
  static Future<void> safeEnterText(
    WidgetTester tester,
    Finder finder,
    String text, {
    String? description,
  }) async {
    await waitForElement(tester, finder);

    final elements = finder.evaluate();
    expect(elements.length, 1);

    await tester.enterText(finder.first, text);
    await tester.pumpAndSettle();
  }

  /// Enhanced pumping that waits for all animations and async operations
  static Future<void> safePumpAndSettle(
    WidgetTester tester, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    // First pump to complete any pending operations
    await tester.pump();

    // Wait for animations and async operations to settle
    await tester.pumpAndSettle(timeout);
  }

  /// Wait for Matrix client to be ready using event detection
  static Future<void> waitForMatrixClient(WidgetTester tester) async {
    await safePumpAndSettle(tester);

    // Wait for the app to be fully initialized
    await waitForCondition(() {
      try {
        final context = tester.element(find.byType(MaterialApp).first);
        return (context.widget as MaterialApp).home != null;
      } catch (e) {
        return false;
      }
    }, description: 'Matrix client initialization');
  }
}

class TimeoutException implements Exception {
  final String message;

  const TimeoutException(this.message);

  @override
  String toString() => 'TimeoutException: $message';
}
