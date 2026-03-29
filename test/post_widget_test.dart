import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:substitution/post/widgets/post.dart';

class MockClient extends Mock implements Client {}

class MockEvent extends Mock implements Event {}

class MockRoom extends Mock implements Room {}

class MockUser extends Mock implements User {}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    registerFallbackValue(MockEvent());
  });

  testWidgets('PostWidget smoke test', (WidgetTester tester) async {
    final mockClient = MockClient();
    final mockEvent = MockEvent();
    final mockDisplayEvent = MockEvent();
    final mockRoom = MockRoom();
    final mockUser = MockUser();

    when(() => mockEvent.roomId).thenReturn('!room:matrix.org');
    when(() => mockEvent.eventId).thenReturn(r'$123');
    when(() => mockEvent.room).thenReturn(mockRoom);
    when(() => mockEvent.senderFromMemoryOrFallback).thenReturn(mockUser);

    when(() => mockDisplayEvent.room).thenReturn(mockRoom);
    when(() => mockDisplayEvent.messageType).thenReturn(MessageTypes.Text);
    when(() => mockDisplayEvent.type).thenReturn(EventTypes.Message);
    when(
      () => mockDisplayEvent.eventId,
    ).thenReturn(r'$123'); // same as event → not edited
    when(() => mockDisplayEvent.senderId).thenReturn('@user:matrix.org');
    when(() => mockDisplayEvent.content).thenReturn({
      'msgtype': MessageTypes.Text,
      'body': 'Hello',
      'formatted_body': '<b>Hello</b>',
    });
    when(() => mockDisplayEvent.formattedText).thenReturn('<b>Hello</b>');
    when(() => mockDisplayEvent.body).thenReturn('Hello');
    when(
      () => mockDisplayEvent.senderFromMemoryOrFallback,
    ).thenReturn(mockUser);
    when(() => mockDisplayEvent.originServerTs).thenReturn(DateTime.now());
    when(() => mockDisplayEvent.originalSource).thenReturn(null);

    when(() => mockRoom.ownPowerLevel).thenReturn(50);
    when(() => mockClient.userID).thenReturn('@me:matrix.org');

    when(() => mockUser.id).thenReturn('@user:matrix.org');
    when(() => mockUser.displayName).thenReturn('Test User');
    when(() => mockUser.avatarUrl).thenReturn(null);

    when(() => mockRoom.id).thenReturn('!room:matrix.org');
    when(() => mockRoom.name).thenReturn('Test Room');
    when(() => mockRoom.canonicalAlias).thenReturn('#test:matrix.org');
    when(() => mockRoom.avatar).thenReturn(null);

    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('en', 'US')],
        path: 'assets/translations',
        fallbackLocale: const Locale('en', 'US'),
        child: MultiProvider(
          providers: [Provider<Client>.value(value: mockClient)],
          child: MaterialApp(
            home: Scaffold(
              body: PostWidget(
                event: mockEvent,
                displayEvent: mockDisplayEvent,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(PostWidget), findsOneWidget);
    // Since translations might be missing in test, we check for either the text or the key
    expect(find.textContaining('Test Room'), findsOneWidget);
  });
}
