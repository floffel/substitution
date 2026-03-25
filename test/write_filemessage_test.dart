import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:substitution/write/pages/filemessage.dart';

class MockClient extends Mock implements Client {}

class MockRoom extends Mock implements Room {}

class MockEvent extends Mock implements Event {}

class MockMatrixEvent extends Mock implements MatrixEvent {}

class MockMatrixFile extends Mock implements MatrixFile {}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    registerFallbackValue(MockEvent());
    registerFallbackValue(MockMatrixEvent());
    registerFallbackValue(MockMatrixFile());
  });

  group('FileMessageWrite Widget Tests', () {
    testWidgets('Smoke: renders FileMessageWrite with room info', (
      WidgetTester tester,
    ) async {
      final mockClient = MockClient();
      final mockRoom = MockRoom();

      when(() => mockClient.getRoomById(any())).thenReturn(mockRoom);
      when(() => mockClient.isLogged()).thenReturn(true);
      when(() => mockClient.userID).thenReturn('@user:matrix.org');
      when(
        () => mockClient.getOneRoomEvent(any(), any()),
      ).thenAnswer((_) async => MockMatrixEvent());

      when(() => mockRoom.id).thenReturn('!room:matrix.org');
      when(() => mockRoom.name).thenReturn('Test Room');
      when(() => mockRoom.avatar).thenReturn(null);
      when(
        () => mockRoom.sendFileEvent(any()),
      ).thenAnswer((_) async => 'event123');

      await tester.pumpWidget(
        EasyLocalization(
          supportedLocales: const [Locale('en', 'US')],
          path: 'assets/translations',
          fallbackLocale: const Locale('en', 'US'),
          child: MultiProvider(
            providers: [Provider<Client>.value(value: mockClient)],
            child: const MaterialApp(
              home: Scaffold(
                body: FileMessageWrite(roomId: '!room:matrix.org'),
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(FileMessageWrite), findsOneWidget);
      expect(find.byType(ListTile), findsOneWidget); // Room info
    });

    testWidgets('File picker button is present', (WidgetTester tester) async {
      final mockClient = MockClient();
      final mockRoom = MockRoom();

      when(() => mockClient.getRoomById(any())).thenReturn(mockRoom);
      when(() => mockClient.isLogged()).thenReturn(true);
      when(() => mockClient.userID).thenReturn('@user:matrix.org');
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
            child: const MaterialApp(
              home: Scaffold(
                body: FileMessageWrite(roomId: '!room:matrix.org'),
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 500));

      // File picker button with add_rounded icon should be present
      final pickButton = find.byIcon(Icons.add_rounded);
      expect(pickButton, findsWidgets);
    });
  });
}
