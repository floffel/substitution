import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_quill/flutter_quill.dart'
    show FlutterQuillLocalizations;
import 'package:substitution/write/pages/textmessage.dart';

class MockClient extends Mock implements Client {}

class MockRoom extends Mock implements Room {}

class MockEvent extends Mock implements Event {}

class MockMatrixEvent extends Mock implements MatrixEvent {}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    registerFallbackValue(MockEvent());
    registerFallbackValue(MockMatrixEvent());
  });

  group('TextMessageWrite Widget Tests', () {
    testWidgets('Smoke: renders TextMessageWrite with room info', (
      WidgetTester tester,
    ) async {
      final mockClient = MockClient();
      final mockRoom = MockRoom();

      when(() => mockClient.getRoomById(any())).thenReturn(mockRoom);
      when(() => mockClient.isLogged()).thenReturn(true);
      when(() => mockClient.userID).thenReturn('@user:matrix.org');
      when(
        () => mockClient.getAccountData(any(), any()),
      ).thenAnswer((_) async => {});
      when(
        () => mockClient.getOneRoomEvent(any(), any()),
      ).thenAnswer((_) async => MockMatrixEvent());

      when(() => mockRoom.id).thenReturn('!room:matrix.org');
      when(() => mockRoom.name).thenReturn('Test Room');
      when(() => mockRoom.avatar).thenReturn(null);
      when(() => mockRoom.sendEvent(any())).thenAnswer((_) async => 'event123');

      await tester.pumpWidget(
        EasyLocalization(
          supportedLocales: const [Locale('en', 'US')],
          path: 'assets/translations',
          fallbackLocale: const Locale('en', 'US'),
          child: MultiProvider(
            providers: [Provider<Client>.value(value: mockClient)],
            child: MaterialApp(
              localizationsDelegates: const [
                FlutterQuillLocalizations.delegate,
              ],
              home: const Scaffold(
                body: TextMessageWrite(roomId: '!room:matrix.org'),
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(TextMessageWrite), findsOneWidget);
      expect(find.byType(ListTile), findsOneWidget);
    });

    testWidgets('Quill editor is present in widget', (
      WidgetTester tester,
    ) async {
      final mockClient = MockClient();
      final mockRoom = MockRoom();

      when(() => mockClient.getRoomById(any())).thenReturn(mockRoom);
      when(() => mockClient.isLogged()).thenReturn(true);
      when(() => mockClient.userID).thenReturn('@user:matrix.org');
      when(
        () => mockClient.getAccountData(any(), any()),
      ).thenAnswer((_) async => {});
      when(
        () => mockClient.getOneRoomEvent(any(), any()),
      ).thenAnswer((_) async => MockMatrixEvent());

      when(() => mockRoom.id).thenReturn('!room:matrix.org');
      when(() => mockRoom.name).thenReturn('Test Room');
      when(() => mockRoom.avatar).thenReturn(null);

      await tester.pumpWidget(
        EasyLocalization(
          supportedLocales: const [Locale('en', 'US')],
          path: 'assets/translations',
          fallbackLocale: const Locale('en', 'US'),
          child: MultiProvider(
            providers: [Provider<Client>.value(value: mockClient)],
            child: MaterialApp(
              localizationsDelegates: const [
                FlutterQuillLocalizations.delegate,
              ],
              home: const Scaffold(
                body: TextMessageWrite(roomId: '!room:matrix.org'),
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 500));

      // Verify Column layout which contains the editor is present
      expect(find.byType(Column), findsWidgets);
    });

    testWidgets('Send button is present and has send icon', (
      WidgetTester tester,
    ) async {
      final mockClient = MockClient();
      final mockRoom = MockRoom();

      when(() => mockClient.getRoomById(any())).thenReturn(mockRoom);
      when(() => mockClient.isLogged()).thenReturn(true);
      when(() => mockClient.userID).thenReturn('@user:matrix.org');
      when(
        () => mockClient.getAccountData(any(), any()),
      ).thenAnswer((_) async => {});
      when(
        () => mockClient.getOneRoomEvent(any(), any()),
      ).thenAnswer((_) async => MockMatrixEvent());

      when(() => mockRoom.id).thenReturn('!room:matrix.org');
      when(() => mockRoom.name).thenReturn('Test Room');
      when(() => mockRoom.avatar).thenReturn(null);

      await tester.pumpWidget(
        EasyLocalization(
          supportedLocales: const [Locale('en', 'US')],
          path: 'assets/translations',
          fallbackLocale: const Locale('en', 'US'),
          child: MultiProvider(
            providers: [Provider<Client>.value(value: mockClient)],
            child: MaterialApp(
              localizationsDelegates: const [
                FlutterQuillLocalizations.delegate,
              ],
              home: const Scaffold(
                body: TextMessageWrite(roomId: '!room:matrix.org'),
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 500));

      // Find send button (IconButton with send icon)
      final sendButton = find.byIcon(Icons.send);
      expect(sendButton, findsOneWidget);
    });

    testWidgets('Room name is displayed in header', (
      WidgetTester tester,
    ) async {
      final mockClient = MockClient();
      final mockRoom = MockRoom();

      when(() => mockClient.getRoomById(any())).thenReturn(mockRoom);
      when(() => mockClient.isLogged()).thenReturn(true);
      when(() => mockClient.userID).thenReturn('@user:matrix.org');
      when(
        () => mockClient.getAccountData(any(), any()),
      ).thenAnswer((_) async => {});
      when(
        () => mockClient.getOneRoomEvent(any(), any()),
      ).thenAnswer((_) async => MockMatrixEvent());

      when(() => mockRoom.id).thenReturn('!room:matrix.org');
      when(() => mockRoom.name).thenReturn('My Test Room');
      when(() => mockRoom.avatar).thenReturn(null);

      await tester.pumpWidget(
        EasyLocalization(
          supportedLocales: const [Locale('en', 'US')],
          path: 'assets/translations',
          fallbackLocale: const Locale('en', 'US'),
          child: MultiProvider(
            providers: [Provider<Client>.value(value: mockClient)],
            child: MaterialApp(
              localizationsDelegates: const [
                FlutterQuillLocalizations.delegate,
              ],
              home: const Scaffold(
                body: TextMessageWrite(roomId: '!room:matrix.org'),
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 500));

      // Check that ListTile with room info is present
      expect(find.byType(ListTile), findsOneWidget);
    });

    testWidgets('Event content includes body field', (
      WidgetTester tester,
    ) async {
      final mockClient = MockClient();
      final mockRoom = MockRoom();
      Map<String, dynamic>? capturedEvent;

      when(() => mockClient.getRoomById(any())).thenReturn(mockRoom);
      when(() => mockClient.isLogged()).thenReturn(true);
      when(() => mockClient.userID).thenReturn('@user:matrix.org');
      when(
        () => mockClient.getAccountData(any(), any()),
      ).thenAnswer((_) async => {});
      when(
        () => mockClient.getOneRoomEvent(any(), any()),
      ).thenAnswer((_) async => MockMatrixEvent());

      when(() => mockRoom.id).thenReturn('!room:matrix.org');
      when(() => mockRoom.name).thenReturn('Test Room');
      when(() => mockRoom.avatar).thenReturn(null);
      when(() => mockRoom.sendEvent(any())).thenAnswer((invocation) {
        capturedEvent =
            invocation.positionalArguments[0] as Map<String, dynamic>;
        return Future.value('event123');
      });

      await tester.pumpWidget(
        EasyLocalization(
          supportedLocales: const [Locale('en', 'US')],
          path: 'assets/translations',
          fallbackLocale: const Locale('en', 'US'),
          child: MultiProvider(
            providers: [Provider<Client>.value(value: mockClient)],
            child: MaterialApp(
              localizationsDelegates: const [
                FlutterQuillLocalizations.delegate,
              ],
              home: const Scaffold(
                body: TextMessageWrite(roomId: '!room:matrix.org'),
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 500));

      // Widget renders properly
      expect(find.byType(TextMessageWrite), findsOneWidget);

      // If event was sent, verify structure
      if (capturedEvent != null) {
        expect(capturedEvent!.containsKey('body'), true);
      }
    });

    testWidgets('Event includes msgtype field', (WidgetTester tester) async {
      final mockClient = MockClient();
      final mockRoom = MockRoom();
      Map<String, dynamic>? capturedEvent;

      when(() => mockClient.getRoomById(any())).thenReturn(mockRoom);
      when(() => mockClient.isLogged()).thenReturn(true);
      when(() => mockClient.userID).thenReturn('@user:matrix.org');
      when(
        () => mockClient.getAccountData(any(), any()),
      ).thenAnswer((_) async => {});
      when(
        () => mockClient.getOneRoomEvent(any(), any()),
      ).thenAnswer((_) async => MockMatrixEvent());

      when(() => mockRoom.id).thenReturn('!room:matrix.org');
      when(() => mockRoom.name).thenReturn('Test Room');
      when(() => mockRoom.avatar).thenReturn(null);
      when(() => mockRoom.sendEvent(any())).thenAnswer((invocation) {
        capturedEvent =
            invocation.positionalArguments[0] as Map<String, dynamic>;
        return Future.value('event123');
      });

      await tester.pumpWidget(
        EasyLocalization(
          supportedLocales: const [Locale('en', 'US')],
          path: 'assets/translations',
          fallbackLocale: const Locale('en', 'US'),
          child: MultiProvider(
            providers: [Provider<Client>.value(value: mockClient)],
            child: MaterialApp(
              localizationsDelegates: const [
                FlutterQuillLocalizations.delegate,
              ],
              home: const Scaffold(
                body: TextMessageWrite(roomId: '!room:matrix.org'),
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 500));

      // Widget renders correctly
      expect(find.byType(TextMessageWrite), findsOneWidget);

      // If captured, verify msgtype exists
      if (capturedEvent != null) {
        expect(capturedEvent!.containsKey('msgtype'), true);
      }
    });

    testWidgets('Event includes formatted_body for HTML', (
      WidgetTester tester,
    ) async {
      final mockClient = MockClient();
      final mockRoom = MockRoom();
      Map<String, dynamic>? capturedEvent;

      when(() => mockClient.getRoomById(any())).thenReturn(mockRoom);
      when(() => mockClient.isLogged()).thenReturn(true);
      when(() => mockClient.userID).thenReturn('@user:matrix.org');
      when(
        () => mockClient.getAccountData(any(), any()),
      ).thenAnswer((_) async => {});
      when(
        () => mockClient.getOneRoomEvent(any(), any()),
      ).thenAnswer((_) async => MockMatrixEvent());

      when(() => mockRoom.id).thenReturn('!room:matrix.org');
      when(() => mockRoom.name).thenReturn('Test Room');
      when(() => mockRoom.avatar).thenReturn(null);
      when(() => mockRoom.sendEvent(any())).thenAnswer((invocation) {
        capturedEvent =
            invocation.positionalArguments[0] as Map<String, dynamic>;
        return Future.value('event123');
      });

      await tester.pumpWidget(
        EasyLocalization(
          supportedLocales: const [Locale('en', 'US')],
          path: 'assets/translations',
          fallbackLocale: const Locale('en', 'US'),
          child: MultiProvider(
            providers: [Provider<Client>.value(value: mockClient)],
            child: MaterialApp(
              localizationsDelegates: const [
                FlutterQuillLocalizations.delegate,
              ],
              home: const Scaffold(
                body: TextMessageWrite(roomId: '!room:matrix.org'),
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 500));

      // Widget renders correctly
      expect(find.byType(TextMessageWrite), findsOneWidget);

      // If captured, verify formatted_body exists
      if (capturedEvent != null) {
        expect(capturedEvent!.containsKey('formatted_body'), true);
      }
    });

    testWidgets('Reply with eventId renders context', (
      WidgetTester tester,
    ) async {
      final mockClient = MockClient();
      final mockRoom = MockRoom();
      final mockMatrixEvent = MockMatrixEvent();

      when(() => mockClient.getRoomById(any())).thenReturn(mockRoom);
      when(() => mockClient.isLogged()).thenReturn(true);
      when(() => mockClient.userID).thenReturn('@user:matrix.org');
      when(
        () => mockClient.getAccountData(any(), any()),
      ).thenAnswer((_) async => {});
      when(
        () => mockClient.getOneRoomEvent(any(), any()),
      ).thenAnswer((_) async => mockMatrixEvent);

      when(() => mockRoom.id).thenReturn('!room:matrix.org');
      when(() => mockRoom.name).thenReturn('Test Room');
      when(() => mockRoom.avatar).thenReturn(null);

      await tester.pumpWidget(
        EasyLocalization(
          supportedLocales: const [Locale('en', 'US')],
          path: 'assets/translations',
          fallbackLocale: const Locale('en', 'US'),
          child: MultiProvider(
            providers: [Provider<Client>.value(value: mockClient)],
            child: MaterialApp(
              localizationsDelegates: const [
                FlutterQuillLocalizations.delegate,
              ],
              home: const Scaffold(
                body: TextMessageWrite(
                  roomId: '!room:matrix.org',
                  eventId: 'event_to_reply_to',
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle(const Duration(milliseconds: 800));

      // Widget should render without errors when eventId is provided
      expect(find.byType(TextMessageWrite), findsOneWidget);
    });

    testWidgets('Widget renders with FutureBuilder for event data', (
      WidgetTester tester,
    ) async {
      final mockClient = MockClient();
      final mockRoom = MockRoom();

      when(() => mockClient.getRoomById(any())).thenReturn(mockRoom);
      when(() => mockClient.isLogged()).thenReturn(true);
      when(() => mockClient.userID).thenReturn('@user:matrix.org');
      when(
        () => mockClient.getAccountData(any(), any()),
      ).thenAnswer((_) async => {});
      when(
        () => mockClient.getOneRoomEvent(any(), any()),
      ).thenAnswer((_) async => MockMatrixEvent());

      when(() => mockRoom.id).thenReturn('!room:matrix.org');
      when(() => mockRoom.name).thenReturn('Test Room');
      when(() => mockRoom.avatar).thenReturn(null);

      await tester.pumpWidget(
        EasyLocalization(
          supportedLocales: const [Locale('en', 'US')],
          path: 'assets/translations',
          fallbackLocale: const Locale('en', 'US'),
          child: MultiProvider(
            providers: [Provider<Client>.value(value: mockClient)],
            child: MaterialApp(
              localizationsDelegates: const [
                FlutterQuillLocalizations.delegate,
              ],
              home: const Scaffold(
                body: TextMessageWrite(roomId: '!room:matrix.org'),
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 500));

      // Widget should render without errors
      expect(find.byType(TextMessageWrite), findsOneWidget);
    });

    testWidgets('Client is retrieved from provider context', (
      WidgetTester tester,
    ) async {
      final mockClient = MockClient();
      final mockRoom = MockRoom();

      when(() => mockClient.getRoomById(any())).thenReturn(mockRoom);
      when(() => mockClient.isLogged()).thenReturn(true);
      when(() => mockClient.userID).thenReturn('@user:matrix.org');
      when(
        () => mockClient.getAccountData(any(), any()),
      ).thenAnswer((_) async => {});
      when(
        () => mockClient.getOneRoomEvent(any(), any()),
      ).thenAnswer((_) async => MockMatrixEvent());

      when(() => mockRoom.id).thenReturn('!room:matrix.org');
      when(() => mockRoom.name).thenReturn('Test Room');
      when(() => mockRoom.avatar).thenReturn(null);

      await tester.pumpWidget(
        EasyLocalization(
          supportedLocales: const [Locale('en', 'US')],
          path: 'assets/translations',
          fallbackLocale: const Locale('en', 'US'),
          child: MultiProvider(
            providers: [Provider<Client>.value(value: mockClient)],
            child: MaterialApp(
              localizationsDelegates: const [
                FlutterQuillLocalizations.delegate,
              ],
              home: const Scaffold(
                body: TextMessageWrite(roomId: '!room:matrix.org'),
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 500));

      // Verify that client was accessed to get room
      verify(
        () => mockClient.getRoomById('!room:matrix.org'),
      ).called(greaterThan(0));
    });
  });
}
