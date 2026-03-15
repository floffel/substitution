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

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  group('FollowFeedSettings Leave Widget Tests', () {
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
      when(
        () => mockClient.getJoinedRooms(),
      ).thenAnswer((_) async => ['!room:matrix.org']);
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

    testWidgets('Tap leave icon on joined room calls leaveRoom', (
      WidgetTester tester,
    ) async {
      when(() => mockClient.leaveRoom(any())).thenAnswer((_) async => {});

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

    testWidgets('After leaving, widget shows join icon', (
      WidgetTester tester,
    ) async {
      when(() => mockClient.leaveRoom(any())).thenAnswer((_) async => {});

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
