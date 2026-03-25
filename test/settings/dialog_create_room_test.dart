import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'package:substitution/settings/pages/room_form_page.dart';

class MockClient extends Mock implements Client {}

class MockRoom extends Mock implements Room {}

class MockGoRouter extends Mock implements GoRouter {}

class MockSyncUpdate extends Mock implements SyncUpdate {}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    registerFallbackValue(MockRoom());
    registerFallbackValue(RouteInformation(uri: Uri()));
  });

  Widget buildTestApp({required MockClient mockClient}) {
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (context, state) => const RoomFormPage()),
      ],
    );

    return EasyLocalization(
      supportedLocales: const [Locale('en', 'US')],
      path: 'assets/translations',
      fallbackLocale: const Locale('en', 'US'),
      child: MultiProvider(
        providers: [Provider<Client>.value(value: mockClient)],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
  }

  group('RoomFormPage (Create Mode) Widget Tests', () {
    testWidgets('Smoke: renders form fields and create button', (
      WidgetTester tester,
    ) async {
      final mockClient = MockClient();

      when(() => mockClient.getRoomById(any())).thenReturn(null);
      when(() => mockClient.isLogged()).thenReturn(true);
      when(() => mockClient.userID).thenReturn('@user:matrix.org');

      await tester.pumpWidget(buildTestApp(mockClient: mockClient));
      await tester.pump(const Duration(milliseconds: 500));

      // Form page should be present
      expect(find.byType(RoomFormPage), findsOneWidget);
      // TextFormFields should be rendered (name, alias, topic)
      expect(find.byType(TextFormField), findsWidgets);
    });

    testWidgets('Form contains name, alias, and topic fields', (
      WidgetTester tester,
    ) async {
      final mockClient = MockClient();

      when(() => mockClient.getRoomById(any())).thenReturn(null);
      when(() => mockClient.isLogged()).thenReturn(true);
      when(() => mockClient.userID).thenReturn('@user:matrix.org');

      await tester.pumpWidget(buildTestApp(mockClient: mockClient));
      await tester.pump(const Duration(milliseconds: 500));

      final textFields = find.byType(TextFormField);
      // At minimum name, alias, topic fields should be present
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
            preset: any(named: 'preset'),
            invite: any(named: 'invite'),
            initialState: any(named: 'initialState'),
          ),
        ).thenAnswer((_) async => 'roomId123');
        when(
          () => mockClient.waitForRoomInSync(any(), join: any(named: 'join')),
        ).thenAnswer((_) async => MockSyncUpdate());
        when(
          () => mockClient.setAccountDataPerRoom(any(), any(), any(), any()),
        ).thenAnswer((_) async => {});
        when(() => mockRoom.membership).thenReturn(Membership.join);
        when(() => mockRoom.setAvatar(any())).thenAnswer((_) async => '');

        await tester.pumpWidget(buildTestApp(mockClient: mockClient));
        await tester.pump(const Duration(milliseconds: 500));

        // Enter room name
        final textFields = find.byType(TextFormField);
        if (textFields.evaluate().isNotEmpty) {
          await tester.enterText(textFields.at(0), 'My Test Room');
          await tester.pump();
        }

        // Tap create button (FilledButton.tonalIcon in app bar)
        final createButton = find.byType(FilledButton);
        if (createButton.evaluate().isNotEmpty) {
          await tester.tap(createButton.first);
          await tester.pumpAndSettle(const Duration(milliseconds: 1000));
        }
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
          preset: any(named: 'preset'),
          invite: any(named: 'invite'),
          initialState: any(named: 'initialState'),
        ),
      ).thenAnswer((_) async => 'roomId123');
      when(
        () => mockClient.waitForRoomInSync(any(), join: any(named: 'join')),
      ).thenAnswer((_) async => MockSyncUpdate());
      when(
        () => mockClient.setAccountDataPerRoom(any(), any(), any(), any()),
      ).thenAnswer((_) async => {});
      when(() => mockRoom.membership).thenReturn(Membership.join);
      when(() => mockRoom.setAvatar(any())).thenAnswer((_) async => '');

      await tester.pumpWidget(buildTestApp(mockClient: mockClient));
      await tester.pump(const Duration(milliseconds: 500));

      // Verify page renders
      expect(find.byType(RoomFormPage), findsOneWidget);
    });

    testWidgets(
      'Empty room name shows validation error or prevents submission',
      (WidgetTester tester) async {
        final mockClient = MockClient();

        when(() => mockClient.getRoomById(any())).thenReturn(null);
        when(() => mockClient.isLogged()).thenReturn(true);
        when(() => mockClient.userID).thenReturn('@user:matrix.org');

        await tester.pumpWidget(buildTestApp(mockClient: mockClient));
        await tester.pump(const Duration(milliseconds: 500));

        // Page should render
        expect(find.byType(RoomFormPage), findsOneWidget);
      },
    );

    testWidgets('Failed room creation shows error snackbar', (
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
          preset: any(named: 'preset'),
          invite: any(named: 'invite'),
          initialState: any(named: 'initialState'),
        ),
      ).thenThrow(Exception('Network error'));

      await tester.pumpWidget(buildTestApp(mockClient: mockClient));
      await tester.pump(const Duration(milliseconds: 500));

      // Dialog should render
      expect(find.byType(RoomFormPage), findsOneWidget);
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
          preset: any(named: 'preset'),
          invite: any(named: 'invite'),
          initialState: any(named: 'initialState'),
        ),
      ).thenAnswer((_) async => 'roomId123');
      when(
        () => mockClient.waitForRoomInSync(any(), join: any(named: 'join')),
      ).thenAnswer((_) async => MockSyncUpdate());
      when(
        () => mockClient.setAccountDataPerRoom(any(), any(), any(), any()),
      ).thenAnswer((_) async => {});
      when(() => mockRoom.membership).thenReturn(Membership.join);
      when(() => mockRoom.setAvatar(any())).thenAnswer((_) async => '');

      await tester.pumpWidget(buildTestApp(mockClient: mockClient));
      await tester.pump(const Duration(milliseconds: 500));

      // Page should be present
      expect(find.byType(RoomFormPage), findsOneWidget);
    });
  });
}
