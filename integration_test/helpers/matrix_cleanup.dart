import 'dart:io' as dart_io;
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:substitution/main.dart' as app;

/// Enhanced Matrix client cleanup utility for reliable e2e testing
class MatrixCleanup {
  /// Comprehensive disposal of Matrix client with proper error handling and async cleanup
  static Future<void> disposeMatrixClient() async {
    try {
      final client = app.globalMatrixClient;

      if (client != null) {
        debugPrint('MatrixCleanup: Starting comprehensive disposal...');

        // Step 1: Abort any ongoing sync operations
        try {
          client.abortSync();
          await Future.delayed(const Duration(milliseconds: 100));
        } catch (e) {
          debugPrint(
            'MatrixCleanup: Warning during sync abort, continuing: $e',
          );
        }

        // Step 2: Close database connections properly
        try {
          await client.dispose();
          debugPrint('MatrixCleanup: Matrix client disposed successfully');

          // Extended wait for database closure to complete in CI environments
          await Future.delayed(const Duration(milliseconds: 500));
        } catch (e) {
          debugPrint(
            'MatrixCleanup: Error during client disposal, continuing anyway: $e',
          );
        }
      }

      // Step 3: Clear global references
      app.globalMatrixClient = null;
      app.globalSubstitutionService = null;

      debugPrint('MatrixCleanup: Complete disposal finished');
    } catch (e) {
      debugPrint('MatrixCleanup: Error during cleanup process: $e');

      // Ensure we always clear globals even if disposal fails
      app.globalMatrixClient = null;
      app.globalSubstitutionService = null;
    }
  }

  /// Wait for Matrix client to be fully initialized
  static Future<void> waitForMatrixClientReady() async {
    int attempts = 0;

    while (attempts < 10) {
      try {
        // Check if Matrix client is available
        final client = app.globalMatrixClient;

        if (client != null) {
          debugPrint('MatrixCleanup: Matrix client is ready');
          return;
        }

        // Wait before checking again
        await Future.delayed(const Duration(milliseconds: 500));
      } catch (e) {
        debugPrint(
          'MatrixCleanup: Error checking Matrix client readiness, retrying...',
        );
      }

      attempts++;
    }

    debugPrint(
      'MatrixCleanup: Matrix client did not become ready within timeout',
    );
  }

  /// Reset test environment with proper async cleanup
  static Future<void> resetTestEnvironment() async {
    debugPrint('MatrixCleanup: Resetting test environment...');

    // Step 1: Dispose any existing Matrix client
    await disposeMatrixClient();

    // Step 2: Clear database files to ensure clean state
    try {
      final appDocDir = await getApplicationDocumentsDirectory();

      // Clear various database files that might retain locks
      final dbFiles = [
        'matrix_database.db',
        'matrix_database.db-shm', // Shared memory file
        'matrix_database.db-wal', // Write-ahead log
      ];

      for (final dbFile in dbFiles) {
        final fullPath = '${appDocDir.path}/$dbFile';
        try {
          final file = dart_io.File(fullPath);
          if (await file.exists()) {
            await file.delete();
            debugPrint('MatrixCleanup: Deleted $dbFile');
          }
        } catch (e) {
          debugPrint(
            'MatrixCleanup: Error during file cleanup for $dbFile, continuing...',
          );
        }
      }

      debugPrint('MatrixCleanup: Database cleanup completed');
    } catch (e) {
      debugPrint(
        'MatrixCleanup: Error during app directory cleanup, continuing...',
      );
    }

    // Step 3: Extended wait for OS to release file locks (important for CI)
    await Future.delayed(const Duration(milliseconds: 1000));

    debugPrint('MatrixCleanup: Test environment reset complete');
  }

  /// Enhanced wait for animation and async operations to settle
  static Future<void> enhancedSettle() async {
    debugPrint('MatrixCleanup: Starting enhanced settle...');

    // Multiple attempts to settle with increasing delays
    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        debugPrint('MatrixCleanup: Settle attempt $attempt/3');

        // Progressive delays for different types of operations
        final delay = Duration(milliseconds: 100 * attempt);
        await Future.delayed(delay);
      } catch (e) {
        debugPrint(
          'MatrixCleanup: Error during settle attempt $attempt, continuing...',
        );
      }
    }

    debugPrint('MatrixCleanup: Enhanced settle completed');
  }

  /// Create a test wrapper with automatic Matrix client management
  static WidgetTesterCallback createMatrixAwareTest(
    String name,
    Future<void> Function(WidgetTester) body, {
    Duration timeout = const Duration(minutes: 10), // Increased for CI
  }) {
    return (WidgetTester tester) async {
      try {
        debugPrint('MatrixCleanup: Starting Matrix-aware test: $name');

        // Reset environment before each test
        await resetTestEnvironment();

        debugPrint('MatrixCleanup: Environment ready for $name');

        // Run the actual test
        await body(tester);
      } catch (e, stack) {
        debugPrint('MatrixCleanup: Test $name failed: $e');
        debugPrint(stack.toString());

        // Ensure cleanup even on failure
        await disposeMatrixClient();
        rethrow;
      } finally {
        // Always cleanup after test
        await disposeMatrixClient();
        debugPrint('MatrixCleanup: Completed Matrix-aware test: $name');
      }
    };
  }

  /// Wait for specific conditions with proper error handling
  static Future<bool> waitForConditionWithTimeout(
    bool Function() condition, {
    Duration timeout = const Duration(seconds: 30),
    String? description,
  }) async {
    final stopwatch = Stopwatch()..start();

    while (!condition()) {
      if (stopwatch.elapsed >= timeout) {
        throw Exception(
          'Condition ${description ?? "test condition"} not met within $timeout',
        );
      }

      // Check with progressive delays to handle async operations
      final delay =
          stopwatch.elapsed < const Duration(seconds: 5)
              ? const Duration(milliseconds: 100)
              : stopwatch.elapsed < const Duration(seconds: 15)
              ? const Duration(milliseconds: 200)
              : const Duration(milliseconds: 500);

      await Future.delayed(delay);
    }

    stopwatch.stop();
    debugPrint(
      'MatrixCleanup: Condition ${description ?? "met"} after ${stopwatch.elapsedMilliseconds}ms',
    );
    return true;
  }
}
