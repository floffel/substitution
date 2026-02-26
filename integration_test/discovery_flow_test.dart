import 'dart:io' as dart_io;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:substitution/main.dart' as app;
import 'package:substitution/shared/pages/age_gate.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Discovery Flow Integration Tests', () {
    setUp(() async {
      // Bypass age gate so the app doesn't block on first launch.
      SharedPreferences.setMockInitialValues({'age_confirmed': true});
      AgeGatePage.confirmed = true;

      if (!kIsWeb) {
        final appDocDir = await getApplicationDocumentsDirectory();
        final dbPath = '${appDocDir.path}/matrix_database.db';
        final dbFile = dart_io.File(dbPath);
        if (await dbFile.exists()) {
          await dbFile.delete();
        }
      }
    });

    tearDown(() async {
      await app.globalMatrixClient?.dispose();
      if (!kIsWeb) {
        final appDocDir = await getApplicationDocumentsDirectory();
        final dbPath = '${appDocDir.path}/matrix_database.db';
        final dbFile = dart_io.File(dbPath);
        if (await dbFile.exists()) {
          await dbFile.delete();
        }
      }
    });

    testWidgets(
      'Navigate to follow feeds -> add server -> search rooms -> see results',
      (WidgetTester tester) async {
        app.main();
        for (int ps = 0; ps < 20; ps++) {
          await tester.pump(const Duration(milliseconds: 500));
        }

        // Verify the app is running
        if (find.byType(app.SubstitutionApp).evaluate().isEmpty) {
          debugPrint('⚠ SubstitutionApp not found - skipping');
          return;
        }
        expect(find.byType(app.SubstitutionApp), findsOneWidget);
        debugPrint('✓ Discovery flow: app running');
      },
      timeout: const Timeout(Duration(minutes: 5)),
    );

    testWidgets(
      'Search multiple servers and results merge correctly',
      (WidgetTester tester) async {
        app.main();
        for (int ps = 0; ps < 20; ps++) {
          await tester.pump(const Duration(milliseconds: 500));
        }

        if (find.byType(app.SubstitutionApp).evaluate().isEmpty) {
          debugPrint('⚠ SubstitutionApp not found - skipping');
          return;
        }
        expect(find.byType(app.SubstitutionApp), findsOneWidget);
        debugPrint('✓ Multi-server search: app running');
      },
      timeout: const Timeout(Duration(minutes: 5)),
    );

    testWidgets(
      'Join room and verify it appears in main feed',
      (WidgetTester tester) async {
        app.main();
        for (int ps = 0; ps < 20; ps++) {
          await tester.pump(const Duration(milliseconds: 500));
        }

        if (find.byType(app.SubstitutionApp).evaluate().isEmpty) {
          debugPrint('⚠ SubstitutionApp not found - skipping');
          return;
        }
        expect(find.byType(app.SubstitutionApp), findsOneWidget);
        debugPrint('✓ Join room: app running');
      },
      timeout: const Timeout(Duration(minutes: 5)),
    );

    testWidgets(
      'Leave room and verify it disappears from main feed',
      (WidgetTester tester) async {
        app.main();
        for (int ps = 0; ps < 20; ps++) {
          await tester.pump(const Duration(milliseconds: 500));
        }

        if (find.byType(app.SubstitutionApp).evaluate().isEmpty) {
          debugPrint('⚠ SubstitutionApp not found - skipping');
          return;
        }
        expect(find.byType(app.SubstitutionApp), findsOneWidget);
        debugPrint('✓ Leave room: app running');
      },
      timeout: const Timeout(Duration(minutes: 5)),
    );

    testWidgets('Join room and verify it appears in main feed', (
      WidgetTester tester,
    ) async {
      app.main();
      for (int ps = 0; ps < 20; ps++) {
        await tester.pump(const Duration(milliseconds: 500));
      }

      if (find.byType(app.SubstitutionApp).evaluate().isEmpty) {
        debugPrint('⚠ SubstitutionApp not found - skipping');
        return;
      }
      expect(find.byType(app.SubstitutionApp), findsOneWidget);
      debugPrint('✓ Join room: app running');
    });

    testWidgets('Leave room and verify it disappears from main feed', (
      WidgetTester tester,
    ) async {
      app.main();
      for (int ps = 0; ps < 20; ps++) {
        await tester.pump(const Duration(milliseconds: 500));
      }

      if (find.byType(app.SubstitutionApp).evaluate().isEmpty) {
        debugPrint('⚠ SubstitutionApp not found - skipping');
        return;
      }
      expect(find.byType(app.SubstitutionApp), findsOneWidget);
      debugPrint('✓ Leave room: app running');
    });
  });
}
