import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:substitution/feed/pages/home.dart';
import 'package:substitution/shared/services/connectivity_service.dart';
import 'package:substitution/shared/services/substitution_service.dart';

class MockClient extends Mock implements Client {}

class MockConnectivityService extends Mock implements ConnectivityService {
  late Stream<bool> _connectivityStream;

  MockConnectivityService() {
    _connectivityStream = Stream.value(true);
  }

  @override
  Stream<bool> get onConnectivityChanged => _connectivityStream;

  @override
  Future<bool> get isOnline async => true;
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  testWidgets('HomePage (Feed) smoke test', (WidgetTester tester) async {
    final mockClient = MockClient();
    final mockConnectivityService = MockConnectivityService();

    // Mock getJoinedRooms to return empty list for simplicity
    when(() => mockClient.getJoinedRooms()).thenAnswer((_) async => []);
    when(() => mockClient.isLogged()).thenReturn(true);
    when(() => mockClient.userID).thenReturn('@user:matrix.org');

    final substitutionService = SubstitutionService(mockClient);

    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('en', 'US')],
        path: 'assets/translations',
        fallbackLocale: const Locale('en', 'US'),
        child: MultiProvider(
          providers: [
            Provider<Client>.value(value: mockClient),
            Provider<ConnectivityService>.value(value: mockConnectivityService),
            ChangeNotifierProvider<SubstitutionService>.value(
              value: substitutionService,
            ),
          ],
          child: MaterialApp(
            home: const HomePage(), // HomePage is the Feed
          ),
        ),
      ),
    );

    // Use multiple small pumps to allow async work to progress without triggering pumpAndSettle timeouts
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(HomePage), findsOneWidget);
    // Should show some empty state or the list view
    // Since we mocked getJoinedRooms -> empty, _fetchTimelines -> empty
    // It probably renders the RefreshIndicator and PagedListView
  });
}
