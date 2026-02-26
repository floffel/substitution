import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:io' as dart_io show Socket;
import 'package:substitution/main.dart' as app;
import 'package:matrix/matrix.dart';

/// Returns the effective Matrix server URL for the current platform.
///
/// On Android emulators, `localhost` resolves to the emulator itself (not the
/// host machine). This helper translates `localhost` to `10.0.2.2` so that
/// Android tests can reach the host machine's Matrix server.
String effectiveMatrixServer(String server) {
  if (!kIsWeb &&
      defaultTargetPlatform == TargetPlatform.android &&
      server.contains('localhost')) {
    return server.replaceAll('localhost', '10.0.2.2');
  }
  return server;
}

/// Returns true if the Matrix test server at [matrixServer] is reachable.
///
/// Performs a TCP connection attempt with a short timeout.
/// On web (where dart:io is unavailable) always returns true, since web CI
/// runs on the same machine as the Matrix server.
Future<bool> isMatrixServerReachable({
  String matrixServer = 'http://localhost:8008',
}) async {
  if (kIsWeb) return true;
  try {
    final uri = Uri.parse(matrixServer);
    var host = uri.host.isEmpty ? 'localhost' : uri.host;
    final port = uri.port > 0 ? uri.port : 8008;

    // On Android emulators, localhost points to the emulator itself.
    // To reach the host machine, we must use 10.0.2.2.
    if (defaultTargetPlatform == TargetPlatform.android &&
        host == 'localhost') {
      host = '10.0.2.2';
    }

    final socket = await dart_io.Socket.connect(
      host,
      port,
      timeout: const Duration(seconds: 3),
    );
    await socket.close();
    return true;
  } catch (_) {
    return false;
  }
}

/// Skip the current test if Matrix server is not reachable.
///
/// Call this at the top of any test or setUp that requires a live Matrix server:
/// ```dart
/// setUp(() async {
///   if (!await skipIfNoMatrix(matrixServer: testMatrixServer)) return;
///   // ... rest of setUp
/// });
/// ```
/// Returns true if reachable (test continues), false if skipped (caller should return).
Future<bool> skipIfNoMatrix({
  String matrixServer = 'http://localhost:8008',
}) async {
  final reachable = await isMatrixServerReachable(matrixServer: matrixServer);
  if (!reachable) {
    markTestSkipped(
      'Skipping: Matrix server not reachable at $matrixServer '
      '(no Docker on this runner)',
    );
    return false;
  }
  return true;
}

/// Waits for [app.globalMatrixClient] to be initialized.
///
/// Tests that call [app.main()] should wait for the client to be ready
/// before attempting to use it.
Future<void> waitForMatrixClient(WidgetTester tester) async {
  debugPrint('Waiting for globalMatrixClient to be initialized...');
  for (int i = 0; i < 60; i++) {
    if (app.globalMatrixClient != null && find.byType(MaterialApp).evaluate().isNotEmpty) {
      debugPrint('globalMatrixClient initialized and UI mounted!');
      return;
    }
    await tester.pump(const Duration(milliseconds: 500));
  }
  throw Exception('Timeout waiting for globalMatrixClient initialization');
}

/// Helper to handle the Age Gate screen if it appears.
///
/// This checks for the existence of the age gate confirmation button.
/// If found, it taps the button and waits for the app to settle.
///
/// Usage in tests:
/// ```dart
/// app.main();
/// await handleAgeGate(tester);
/// ```
Future<void> handleAgeGate(WidgetTester tester) async {
  // Wait for the app to render the first frame(s)
  for (int i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 300));
    if (find.byKey(const Key('ageGateConfirmButton')).evaluate().isNotEmpty) {
      break;
    }
  }

  // Check if we are stuck on the Age Gate
  final ageGateButton = find.byKey(const Key('ageGateConfirmButton'));

  if (ageGateButton.evaluate().isNotEmpty) {
    debugPrint('Age Gate detected — tapping confirm...');
    await tester.tap(ageGateButton);
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
  } else {
    debugPrint('No Age Gate detected (or already passed).');
  }
}

/// Waits for at least [count] rooms to be joined and visible in the UI.
///
/// Throws an [Exception] if the condition is not met within the timeout.
Future<void> waitForJoinedRooms(
  WidgetTester tester,
  int count, {
  Duration timeout = const Duration(seconds: 120),
}) async {
  debugPrint('Waiting for at least $count joined rooms to be visible...');
  final stopWatch = Stopwatch()..start();

  while (stopWatch.elapsed < timeout) {
    await tester.pump(const Duration(milliseconds: 500));
    final roomItems = find.byType(ListTile);
    final currentCount = roomItems.evaluate().length;

    if (currentCount >= count) {
      debugPrint('✓ Found $currentCount rooms (target: $count)');
      // Log room names for debugging
      for (final element in roomItems.evaluate()) {
        final listTile = element.widget as ListTile;
        if (listTile.title is Text) {
          debugPrint('  - Room: ${(listTile.title as Text).data}');
        }
      }
      return;
    }

    // Also check if we are on the right page
    if (find.byType(CircularProgressIndicator).evaluate().isNotEmpty) {
      debugPrint('...still loading (CircularProgressIndicator visible)...');
    } else {
      debugPrint('...still waiting ($currentCount/$count rooms found)...');
    }
  }

  final finalCount = find.byType(ListTile).evaluate().length;
  throw Exception(
    'Timeout waiting for $count rooms. Only $finalCount found after ${timeout.inSeconds}s',
  );
}

/// Wait for the Matrix client to reach a specific [SyncStatus] using its internal stream.
/// This is 100% event-driven and avoids any manual polling or "luck-based" sleeps.
Future<void> waitForSyncStatus(
  SyncStatus targetStatus, {
  Duration timeout = const Duration(seconds: 120),
}) async {
  final client = app.globalMatrixClient;
  if (client == null) throw Exception('globalMatrixClient is null');

  debugPrint('Event-Driven: Waiting for Matrix sync status: $targetStatus');
  
  await client.onSyncStatus.stream
      .firstWhere((status) => status.status == targetStatus)
      .timeout(timeout);
      
  debugPrint('✓ Event received: Matrix reached status $targetStatus');
}

/// Waits for the Matrix client to be fully synced (initial sync complete).
Future<void> waitForSync(
  WidgetTester tester, {
  Duration timeout = const Duration(seconds: 120),
}) async {
  if (app.globalMatrixClient?.prevBatch != null) return;
  await waitForSyncStatus(SyncStatus.finished, timeout: timeout);
  // After the data event, one pump is enough to render the resulting state
  await tester.pump();
}

/// A more robust version of pumpAndSettle that doesn't hang on background activity.
Future<void> settle(WidgetTester tester, {int count = 5, Duration interval = const Duration(milliseconds: 500)}) async {
  for (int i = 0; i < count; i++) {
    await tester.pump(interval);
  }
}

/// A high-performance, event-driven waiter.
/// Pumps frames as fast as possible until [condition] returns true.
/// This is the most deterministic way to wait for state changes, as it resumes
/// the test the exact frame after the condition is met, without manual sleeps.
Future<void> fastWait(
  WidgetTester tester,
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    if (condition()) return;
    // Pump with a small duration to allow microtasks and timers to run
    await tester.pump(const Duration(milliseconds: 100));
  }
  
  // Timeout reached, dump tree for debugging
  debugPrint('TIMEOUT in fastWait! Current widget tree:');
  try {
    debugPrint(tester.allWidgets.map((w) => w.runtimeType.toString()).join(', '));
  } catch (e) {
    debugPrint('Could not dump widgets: $e');
  }
  
  throw Exception('Timeout waiting for condition');
}

/// Pumps the app until the given finder finds at least one widget.
Future<void> waitUntilVisible(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  debugPrint('Fast-Wait: Waiting for $finder...');
  await fastWait(tester, () => finder.evaluate().isNotEmpty, timeout: timeout);
}

/// Pumps the app until the given finder finds no widgets.
Future<void> waitUntilNotVisible(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  debugPrint('Waiting for $finder to disappear...');
  await fastWait(tester, () => finder.evaluate().isEmpty, timeout: timeout);
}
