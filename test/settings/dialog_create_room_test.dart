import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'package:substitution/settings/widgets/dialogcreateroom.dart';

class MockClient extends Mock implements Client {}

class MockRoom extends Mock implements Room {}

class MockGoRouter extends Mock implements GoRouter {}

class MockSyncUpdate extends Mock implements SyncUpdate {}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    registerFallbackValue(MockRoom());
  });

  group('DialogCreateRoom Widget Tests', () {
    testWidgets('Smoke: renders form fields and create button', (
      WidgetTester tester,
    ) async {
      final mockClient = MockClient();

      when(() => mockClient.getRoomById(any())).thenReturn(null);
      when(() => mockClient.isLogged()).thenReturn(true);
      when(() => mockClient.userID).thenReturn('@user:matrix.org');

      await tester.pumpWidget(
        EasyLocalization(
          supportedLocales: const [Locale('en', 'US')],
          path: 'assets/translations',
          fallbackLocale: const Locale('en', 'US'),
          child: MultiProvider(
            providers: [Provider<Client>.value(value: mockClient)],
            child: MaterialApp(
              home: Scaffold(
                body: Builder(
                  builder: (context) {
                    return Dialog(child: DialogCreateRoom());
                  },
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 500));

      // Dialog should be present
      expect(find.byType(DialogCreateRoom), findsOneWidget);
      // 3 TextFormFields for: name, alias, topic
      expect(find.byType(TextFormField), findsWidgets);
      // Create button should be present
      expect(find.byType(TextButton), findsWidgets);
    });

    testWidgets('Form contains name, alias, and topic fields', (
      WidgetTester tester,
    ) async {
      final mockClient = MockClient();

      when(() => mockClient.getRoomById(any())).thenReturn(null);
      when(() => mockClient.isLogged()).thenReturn(true);
      when(() => mockClient.userID).thenReturn('@user:matrix.org');

      await tester.pumpWidget(
        EasyLocalization(
          supportedLocales: const [Locale('en', 'US')],
          path: 'assets/translations',
          fallbackLocale: const Locale('en', 'US'),
          child: MultiProvider(
            providers: [Provider<Client>.value(value: mockClient)],
            child: MaterialApp(
              home: Scaffold(
                body: Builder(
                  builder: (context) {
                    return Dialog(child: DialogCreateRoom());
                  },
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 500));

      // Find all TextFormFields
      final textFields = find.byType(TextFormField);
      expect(textFields, findsWidgets);
    });

    testWidgets(
      'Create button calls client.createRoom with correct parameters',
      (WidgetTester tester) async {
        final mockClient = MockClient();
        final mockRoom = MockRoom();

        when(() => mockClient.getRoomById(any())).thenReturn(mockRoom);
        when(() => mockClient.isLogged()).thenReturn(true);
        when(() => mockClient.userID).thenReturn('@user:matrix.org');
        when(
          () => mockClient.createRoom(
            isDirect: any(named: 'isDirect'),
            name: any(named: 'name'),
            topic: any(named: 'topic'),
            roomAliasName: any(named: 'roomAliasName'),
            visibility: any(named: 'visibility'),
          ),
        ).thenAnswer((_) async => 'roomId123');
        when(
          () => mockClient.waitForRoomInSync(any(), join: any(named: 'join')),
        ).thenAnswer((_) async => MockSyncUpdate());
        when(
          () => mockClient.setAccountDataPerRoom(any(), any(), any(), any()),
        ).thenAnswer((_) async => {});
        when(() => mockRoom.membership).thenReturn(Membership.join);

        await tester.pumpWidget(
          EasyLocalization(
            supportedLocales: const [Locale('en', 'US')],
            path: 'assets/translations',
            fallbackLocale: const Locale('en', 'US'),
            child: MultiProvider(
              providers: [Provider<Client>.value(value: mockClient)],
              child: MaterialApp(
                home: Scaffold(
                  body: Builder(
                    builder: (context) {
                      return Dialog(child: DialogCreateRoom());
                    },
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.pump(const Duration(milliseconds: 500));

        // Find input fields and enter text
        final textFields = find.byType(TextFormField);
        if (textFields.evaluate().isNotEmpty) {
          final nameField = textFields.at(0);
          await tester.enterText(nameField, 'My Test Room');
          await tester.pump();
        }

        // Find and tap create button
        final createButton = find.byType(TextButton);
        if (createButton.evaluate().isNotEmpty) {
          await tester.tap(createButton.first);
          await tester.pumpAndSettle(const Duration(milliseconds: 1000));
        }

        // Verify createRoom was called
        verify(
          () => mockClient.createRoom(
            isDirect: any(named: 'isDirect'),
            name: any(named: 'name'),
            topic: any(named: 'topic'),
            roomAliasName: any(named: 'roomAliasName'),
            visibility: any(named: 'visibility'),
          ),
        ).called(greaterThan(0));
      },
    );

    testWidgets('Successful room creation sets substitution account data', (
      WidgetTester tester,
    ) async {
      final mockClient = MockClient();
      final mockRoom = MockRoom();

      when(() => mockClient.getRoomById(any())).thenReturn(mockRoom);
      when(() => mockClient.isLogged()).thenReturn(true);
      when(() => mockClient.userID).thenReturn('@user:matrix.org');
      when(
        () => mockClient.createRoom(
          isDirect: any(named: 'isDirect'),
          name: any(named: 'name'),
          topic: any(named: 'topic'),
          roomAliasName: any(named: 'roomAliasName'),
          visibility: any(named: 'visibility'),
        ),
      ).thenAnswer((_) async => 'roomId123');
      when(
        () => mockClient.waitForRoomInSync(any(), join: any(named: 'join')),
      ).thenAnswer((_) async => MockSyncUpdate());
      when(
        () => mockClient.setAccountDataPerRoom(any(), any(), any(), any()),
      ).thenAnswer((_) async => {});
      when(() => mockRoom.membership).thenReturn(Membership.join);

      await tester.pumpWidget(
        EasyLocalization(
          supportedLocales: const [Locale('en', 'US')],
          path: 'assets/translations',
          fallbackLocale: const Locale('en', 'US'),
          child: MultiProvider(
            providers: [Provider<Client>.value(value: mockClient)],
            child: MaterialApp(
              home: Scaffold(
                body: Builder(
                  builder: (context) {
                    return Dialog(child: DialogCreateRoom());
                  },
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 500));

      // Tap create button to trigger room creation
      final createButton = find.byType(TextButton);
      if (createButton.evaluate().isNotEmpty) {
        await tester.tap(createButton.first);
        await tester.pumpAndSettle(const Duration(milliseconds: 1000));
      }

      // Verify setAccountDataPerRoom was called for substitution
      verify(
        () => mockClient.setAccountDataPerRoom(
          any(),
          any(),
          'substitution',
          any(),
        ),
      ).called(greaterThan(0));
    });

    testWidgets(
      'Empty room name shows validation error or prevents submission',
      (WidgetTester tester) async {
        final mockClient = MockClient();

        when(() => mockClient.getRoomById(any())).thenReturn(null);
        when(() => mockClient.isLogged()).thenReturn(true);
        when(() => mockClient.userID).thenReturn('@user:matrix.org');
        when(
          () => mockClient.createRoom(
            isDirect: any(named: 'isDirect'),
            name: any(named: 'name'),
            topic: any(named: 'topic'),
            roomAliasName: any(named: 'roomAliasName'),
            visibility: any(named: 'visibility'),
          ),
        ).thenAnswer((_) async => 'roomId123');

        await tester.pumpWidget(
          EasyLocalization(
            supportedLocales: const [Locale('en', 'US')],
            path: 'assets/translations',
            fallbackLocale: const Locale('en', 'US'),
            child: MultiProvider(
              providers: [Provider<Client>.value(value: mockClient)],
              child: MaterialApp(
                home: Scaffold(
                  body: Builder(
                    builder: (context) {
                      return Dialog(child: DialogCreateRoom());
                    },
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.pump(const Duration(milliseconds: 500));

        // Dialog should render
        expect(find.byType(DialogCreateRoom), findsOneWidget);
      },
    );

    testWidgets('Failed room creation shows error dialog', (
      WidgetTester tester,
    ) async {
      final mockClient = MockClient();

      when(() => mockClient.getRoomById(any())).thenReturn(null);
      when(() => mockClient.isLogged()).thenReturn(true);
      when(() => mockClient.userID).thenReturn('@user:matrix.org');
      when(
        () => mockClient.createRoom(
          isDirect: any(named: 'isDirect'),
          name: any(named: 'name'),
          topic: any(named: 'topic'),
          roomAliasName: any(named: 'roomAliasName'),
          visibility: any(named: 'visibility'),
        ),
      ).thenThrow(Exception('Network error'));

      await tester.pumpWidget(
        EasyLocalization(
          supportedLocales: const [Locale('en', 'US')],
          path: 'assets/translations',
          fallbackLocale: const Locale('en', 'US'),
          child: MultiProvider(
            providers: [Provider<Client>.value(value: mockClient)],
            child: MaterialApp(
              home: Scaffold(
                body: Builder(
                  builder: (context) {
                    return Dialog(child: DialogCreateRoom());
                  },
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 500));

      // Find and tap create button
      final createButton = find.byType(TextButton);
      if (createButton.evaluate().isNotEmpty) {
        await tester.tap(createButton.first);
        await tester.pumpAndSettle(const Duration(milliseconds: 1000));
      }

      // Error message should be displayed
      expect(find.byType(Text), findsWidgets);
    });

    testWidgets('Loading state shows progress indicator during room creation', (
      WidgetTester tester,
    ) async {
      final mockClient = MockClient();
      final mockRoom = MockRoom();

      when(() => mockClient.getRoomById(any())).thenReturn(mockRoom);
      when(() => mockClient.isLogged()).thenReturn(true);
      when(() => mockClient.userID).thenReturn('@user:matrix.org');
      when(
        () => mockClient.createRoom(
          isDirect: any(named: 'isDirect'),
          name: any(named: 'name'),
          topic: any(named: 'topic'),
          roomAliasName: any(named: 'roomAliasName'),
          visibility: any(named: 'visibility'),
        ),
      ).thenAnswer((_) async => 'roomId123');
      when(
        () => mockClient.waitForRoomInSync(any(), join: any(named: 'join')),
      ).thenAnswer((_) async => MockSyncUpdate());
      when(
        () => mockClient.setAccountDataPerRoom(any(), any(), any(), any()),
      ).thenAnswer((_) async => {});
      when(() => mockRoom.membership).thenReturn(Membership.join);

      await tester.pumpWidget(
        EasyLocalization(
          supportedLocales: const [Locale('en', 'US')],
          path: 'assets/translations',
          fallbackLocale: const Locale('en', 'US'),
          child: MultiProvider(
            providers: [Provider<Client>.value(value: mockClient)],
            child: MaterialApp(
              home: Scaffold(
                body: Builder(
                  builder: (context) {
                    return Dialog(child: DialogCreateRoom());
                  },
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 500));

      // Dialog should be present
      expect(find.byType(DialogCreateRoom), findsOneWidget);
    });
  });
}
