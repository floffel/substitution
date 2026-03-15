import 'dart:async';
import 'package:flutter/foundation.dart';

/// A retry wrapper for flaky integration tests
/// Provides automatic retry with exponential backoff for transient failures
class RetryWrapper {
  static const int _maxRetries = 3;
  static const Duration _initialDelay = Duration(seconds: 1);

  /// Execute a function with retry logic
  static Future<T> executeWithRetry<T>(
    Future<T> Function() operation, {
    String? description,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    int attempt = 0;
    Exception? lastError;

    while (attempt < _maxRetries) {
      try {
        debugPrint(
          '${description ?? "Operation"} attempt ${attempt + 1}/$_maxRetries',
        );
        return await operation().timeout(timeout);
      } catch (e, _) {
        lastError = e is Exception ? e : Exception(e.toString());
        debugPrint(
          '${description ?? "Operation"} failed (attempt ${attempt + 1}): $e',
        );

        if (attempt < _maxRetries - 1) {
          final delay = _initialDelay * (1 << attempt); // Exponential backoff
          debugPrint('Retrying in ${delay.inSeconds} seconds...');
          await Future.delayed(delay);
        } else {
          debugPrint(
            '${description ?? "Operation"} failed after $_maxRetries attempts',
          );
        }
      }
      attempt++;
    }

    throw lastError ?? Exception('Unknown error during retry');
  }

  /// Execute a function with retry logic for widget tests
  static Future<T> executeWidgetTestWithRetry<T>(
    T Function() operation, {
    String? description,
  }) async {
    int attempt = 0;
    Exception? lastError;

    while (attempt < _maxRetries) {
      try {
        debugPrint(
          '${description ?? "Widget operation"} attempt ${attempt + 1}/$_maxRetries',
        );
        return await Future.microtask(operation);
      } catch (e, _) {
        lastError = e is Exception ? e : Exception(e.toString());
        debugPrint(
          '${description ?? "Widget operation"} failed (attempt ${attempt + 1}): $e',
        );

        if (attempt < _maxRetries - 1) {
          final delay = _initialDelay * (1 << attempt); // Exponential backoff
          debugPrint('Retrying in ${delay.inSeconds} seconds...');
          await Future.delayed(delay);
        } else {
          debugPrint(
            '${description ?? "Widget operation"} failed after $_maxRetries attempts',
          );
        }
      }
      attempt++;
    }

    throw lastError ?? Exception('Unknown error during widget retry');
  }
}
