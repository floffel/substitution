import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'package:substitution/auth/auth_state.dart';

/// Mock classes extending Mock from mocktail
class MockClient extends Mock implements Client {}

class MockRoom extends Mock implements Room {}

class MockEvent extends Mock implements Event {}

class MockUser extends Mock implements User {}

class MockTimeline extends Mock implements Timeline {}

/// Global setup logic for all tests
void setUpTestInfrastructure() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    registerFallbackValue(MockEvent());
    registerFallbackValue(MockTimeline());
    // Register fallback values for common return types
    registerFallbackValue(<String, dynamic>{});
    registerFallbackValue(Uri.parse('https://example.com'));
  });
}

/// Pumps a widget wrapped in EasyLocalization + MultiProvider + MaterialApp with GoRouter
///
/// This helper eliminates boilerplate duplication across test files.
/// Always provides a GoRouter to support context.pop() and other navigation calls.
///
/// Parameters:
/// - [tester]: The WidgetTester instance
/// - [child]: The widget to test
/// - [mockClient]: Optional mock Client to provide via MultiProvider (default: creates one)
/// - [authState]: Optional pre-populated AuthState (default: creates an empty one)
Future<void> pumpApp(
  WidgetTester tester,
  Widget child, {
  Client? mockClient,
  AuthState? authState,
}) async {
  final client = mockClient ?? MockClient();
  final state = authState ?? AuthState();

  // Create a simple router with a single route for testing
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (context, state) => Scaffold(body: child)),
    ],
  );

  final app = EasyLocalization(
    supportedLocales: const [Locale('en', 'US')],
    path: 'assets/translations',
    fallbackLocale: const Locale('en', 'US'),
    child: MultiProvider(
      providers: [
        Provider<Client>.value(value: client),
        ChangeNotifierProvider<AuthState>.value(value: state),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        builder: (context, child) => child ?? const SizedBox.shrink(),
      ),
    ),
  );

  await tester.pumpWidget(app);
}

/// Factory helper to create a mock Room with common properties
MockRoom createMockRoom({
  required String name,
  required String id,
  Uri? avatar,
  int powerLevel = 50,
}) {
  final mockRoom = MockRoom();

  when(() => mockRoom.id).thenReturn(id);
  when(() => mockRoom.name).thenReturn(name);
  when(() => mockRoom.canonicalAlias).thenReturn('#$name:matrix.org');
  when(() => mockRoom.avatar).thenReturn(avatar);
  when(() => mockRoom.ownPowerLevel).thenReturn(powerLevel);

  return mockRoom;
}

/// Factory helper to create a mock Event with common properties
MockEvent createMockEvent({
  required String type,
  required String body,
  String? formattedText,
  required Room room,
  required User sender,
}) {
  final mockEvent = MockEvent();

  when(() => mockEvent.type).thenReturn(type);
  when(() => mockEvent.body).thenReturn(body);
  when(() => mockEvent.formattedText).thenReturn(formattedText ?? body);
  when(() => mockEvent.room).thenReturn(room);
  when(() => mockEvent.senderFromMemoryOrFallback).thenReturn(sender);
  when(() => mockEvent.messageType).thenReturn(MessageTypes.Text);
  when(() => mockEvent.eventId).thenReturn(r'$event123');
  when(() => mockEvent.roomId).thenReturn(room.id);
  when(() => mockEvent.originServerTs).thenReturn(DateTime.now());

  return mockEvent;
}

/// Factory helper to create a mock User with common properties
MockUser createMockUser({required String id, required String displayName}) {
  final mockUser = MockUser();

  when(() => mockUser.id).thenReturn(id);
  when(() => mockUser.displayName).thenReturn(displayName);
  when(() => mockUser.avatarUrl).thenReturn(null);

  return mockUser;
}
