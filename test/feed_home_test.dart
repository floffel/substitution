import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:substitution/feed/pages/home.dart';
import 'package:go_router/go_router.dart';

class MockClient extends Mock implements Client {}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  testWidgets('HomePage (Feed) smoke test', (WidgetTester tester) async {
    final mockClient = MockClient();
    
    // Mock getJoinedRooms to return empty list for simplicity
    when(() => mockClient.getJoinedRooms()).thenAnswer((_) async => []);
    when(() => mockClient.isLogged()).thenReturn(true);
    when(() => mockClient.userID).thenReturn('@user:matrix.org');

    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('en', 'US')],
        path: 'assets/translations',
        fallbackLocale: const Locale('en', 'US'),
        child: MultiProvider(
          providers: [
            Provider<Client>.value(value: mockClient),
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
