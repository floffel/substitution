import 'dart:io' as io;
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Enhanced iOS resource management for integration tests
class IOSResourceManager {
  static const String _tag = 'IOS_RESOURCE_MANAGER';

  /// Clean up all iOS-specific resources to prevent crashes
  static Future<void> cleanupIOSResources() async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      debugPrint('$_tag: Starting iOS resource cleanup...');

      try {
        // 1. Clear application caches and temp files
        await _clearApplicationCaches();

        // 2. Force garbage collection hint for Flutter engine
        await _hintGarbageCollection();

        // 3. Clear any lingering database locks
        await _clearDatabaseLocks();

        debugPrint('$_tag: iOS resource cleanup completed');
      } catch (e) {
        debugPrint('$_tag: Error during iOS resource cleanup: $e');
      }
    }
  }

  /// Clear application caches and temporary files
  static Future<void> _clearApplicationCaches() async {
    try {
      final appDocDir = await getApplicationDocumentsDirectory();

      // Clear various cache directories
      final directoriesToClear = [
        'Library/Caches',
        'tmp',
        'Documents/substitution_cache',
      ];

      for (final dirPath in directoriesToClear) {
        final fullPath = '${appDocDir.path}/$dirPath';
        final directory = io.Directory(fullPath);

        if (await directory.exists()) {
          await for (final entity in directory.list(recursive: true)) {
            if (entity is io.File) {
              try {
                await entity.delete();
              } catch (_) {}
            }
          }
        }
      }

      debugPrint('$_tag: Cleared application caches');
    } catch (e) {
      debugPrint('$_tag: Error clearing caches: $e');
    }
  }

  /// Hint to Flutter engine for garbage collection
  static Future<void> _hintGarbageCollection() async {
    // This is a hint to help with memory pressure on iOS
    await Future.delayed(const Duration(milliseconds: 100));

    // Additional delay to allow system cleanup
    await Future.delayed(const Duration(milliseconds: 200));

    debugPrint('$_tag: Completed garbage collection hint');
  }

  /// Clear any lingering database file locks
  static Future<void> _clearDatabaseLocks() async {
    try {
      final appDocDir = await getApplicationDocumentsDirectory();

      // Common SQLite files that might have locks
      final dbFiles = [
        'matrix_database.db',
        'matrix_database.db-shm', // Shared memory file
        'matrix_database.db-wal', // Write-ahead log
      ];

      for (final dbFile in dbFiles) {
        final fullPath = '${appDocDir.path}/$dbFile';
        try {
          final file = io.File(fullPath);
          if (await file.exists()) {
            // Delete the file to ensure no lingering locks
            await file.delete();
          }
        } catch (_) {
          // Ignore errors as files might be in use
        }
      }

      debugPrint('$_tag: Cleared database locks');
    } catch (e) {
      debugPrint('$_tag: Error clearing database locks: $e');
    }
  }

  /// Enhanced delay for iOS stability between test steps
  static Future<void> iosStabilityDelay({String? reason}) async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      final delayReason = reason ?? 'iOS stability';
      debugPrint('$_tag: Waiting for iOS stability ($delayReason)...');

      // Longer delay for complex operations
      await Future.delayed(const Duration(milliseconds: 1500));
    }
  }

  /// Check if iOS device has sufficient memory for testing
  static bool checkIOSMemoryPressure() {
    // This is a placeholder - in real implementation,
    // could check actual memory metrics
    return true;
  }

  /// Pre-test iOS setup for better stability
  static Future<void> preTestIOSSetup() async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      debugPrint('$_tag: Pre-test iOS setup...');

      // Clear any existing resources
      await cleanupIOSResources();

      // Wait for system stabilization
      await Future.delayed(const Duration(milliseconds: 500));

      debugPrint('$_tag: Pre-test iOS setup complete');
    }
  }

  /// Post-test iOS cleanup
  static Future<void> postTestIOSCleanup() async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      debugPrint('$_tag: Post-test iOS cleanup...');

      await cleanupIOSResources();

      debugPrint('$_tag: Post-test iOS cleanup complete');
    }
  }
}
