import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:substitution/settings/pages/followfeeds.dart';

class MockClient extends Mock implements Client {}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  testWidgets('FollowFeedSettings smoke test', (WidgetTester tester) async {
    final mockClient = MockClient();
    
    when(() => mockClient.isLogged()).thenReturn(true);
    when(() => mockClient.userID).thenReturn('@user:matrix.org');
    when(() => mockClient.homeserver).thenReturn(Uri.parse('https://matrix.org'));
    
    // Mock getAccountData
    when(() => mockClient.getAccountData(any(), any())).thenAnswer((_) async => {});

    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('en', 'US')],
        path: 'assets/translations',
        fallbackLocale: const Locale('en', 'US'),
        child: MultiProvider(
          providers: [
            Provider<Client>.value(value: mockClient),
          ],
          child: const MaterialApp(
            home: Scaffold(body: FollowFeedSettings()),
          ),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(FollowFeedSettings), findsOneWidget);
    // Should find the "Add Server" chip/button
    expect(find.byIcon(Icons.add), findsOneWidget);
  });
}
