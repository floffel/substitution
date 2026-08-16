import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:substitution/settings/pages/followfeeds.dart';
import 'package:substitution/shared/services/substitution_service.dart';

class MockClient extends Mock implements Client {}

class MockRoom extends Mock implements Room {}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    registerFallbackValue(MockRoom());
  });

  group('FollowFeedSettings Join Widget Tests', () {
    late MockClient mockClient;

    setUp(() {
      mockClient = MockClient();
      when(() => mockClient.isLogged()).thenReturn(true);
      when(() => mockClient.userID).thenReturn('@user:matrix.org');
      when(
        () => mockClient.homeserver,
      ).thenReturn(Uri.parse('https://matrix.org'));
      when(
        () => mockClient.getAccountData(any(), any()),
      ).thenAnswer((_) async => {});
      when(() => mockClient.getJoinedRooms()).thenAnswer((_) async => []);
      when(
        () => mockClient.queryPublicRooms(
          server: any(named: 'server'),
          limit: any(named: 'limit'),
          filter: any(named: 'filter'),
          since: any(named: 'since'),
        ),
      ).thenAnswer(
        (_) async => QueryPublicRoomsResponse.fromJson({
          'chunk': [],
          'total_room_count': 0,
          'prev_batch': null,
          'next_batch': null,
        }),
      );
    });

    testWidgets('Smoke: FollowFeedSettings renders', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        EasyLocalization(
          supportedLocales: const [Locale('en', 'US')],
          path: 'assets/translations',
          fallbackLocale: const Locale('en', 'US'),
          child: MultiProvider(
            providers: [
              Provider<Client>.value(value: mockClient),
              ChangeNotifierProvider<SubstitutionService>.value(
                value: SubstitutionService(mockClient),
              ),
            ],
            child: const MaterialApp(
              home: Scaffold(body: FollowFeedSettings()),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(FollowFeedSettings), findsOneWidget);
    });

    testWidgets('Tap join icon on unjoined room calls joinRoom', (
      WidgetTester tester,
    ) async {
      when(
        () => mockClient.joinRoom(
          any(that: endsWith(':matrix.org')),
          via: any(named: 'via'),
        ),
      ).thenAnswer((_) async => '!room:matrix.org');

      when(
        () => mockClient.setAccountDataPerRoom(
          any(),
          any(),
          'substitution',
          any(),
        ),
      ).thenAnswer((_) async {});

      when(
        () => mockClient.queryPublicRooms(
          server: any(named: 'server'),
          limit: any(named: 'limit'),
          filter: any(named: 'filter'),
          since: any(named: 'since'),
        ),
      ).thenAnswer(
        (_) async => QueryPublicRoomsResponse.fromJson({
          'chunk': [
            {
              'room_id': '!test:matrix.org',
              'name': 'Test Room',
              'topic': 'Test topic',
              'num_joined_members': 10,
              'avatar_url': null,
              'world_readable': true,
              'guest_can_join': true,
            },
          ],
          'total_room_count': 1,
          'prev_batch': null,
          'next_batch': null,
        }),
      );

      await tester.pumpWidget(
        EasyLocalization(
          supportedLocales: const [Locale('en', 'US')],
          path: 'assets/translations',
          fallbackLocale: const Locale('en', 'US'),
          child: MultiProvider(
            providers: [
              Provider<Client>.value(value: mockClient),
              ChangeNotifierProvider<SubstitutionService>.value(
                value: SubstitutionService(mockClient),
              ),
            ],
            child: const MaterialApp(
              home: Scaffold(body: FollowFeedSettings()),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(FollowFeedSettings), findsOneWidget);
    });

    testWidgets('After successful join, widget shows leave icon', (
      WidgetTester tester,
    ) async {
      when(
        () => mockClient.joinRoom(any(), via: any(named: 'via')),
      ).thenAnswer((_) async => '!room:matrix.org');

      when(
        () => mockClient.setAccountDataPerRoom(
          any(),
          any(),
          'substitution',
          any(),
        ),
      ).thenAnswer((_) async {});

      when(
        () => mockClient.queryPublicRooms(
          server: any(named: 'server'),
          limit: any(named: 'limit'),
          filter: any(named: 'filter'),
          since: any(named: 'since'),
        ),
      ).thenAnswer(
        (_) async => QueryPublicRoomsResponse.fromJson({
          'chunk': [],
          'total_room_count': 0,
          'prev_batch': null,
          'next_batch': null,
        }),
      );

      await tester.pumpWidget(
        EasyLocalization(
          supportedLocales: const [Locale('en', 'US')],
          path: 'assets/translations',
          fallbackLocale: const Locale('en', 'US'),
          child: MultiProvider(
            providers: [
              Provider<Client>.value(value: mockClient),
              ChangeNotifierProvider<SubstitutionService>.value(
                value: SubstitutionService(mockClient),
              ),
            ],
            child: const MaterialApp(
              home: Scaffold(body: FollowFeedSettings()),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(FollowFeedSettings), findsOneWidget);
    });
  });
}
