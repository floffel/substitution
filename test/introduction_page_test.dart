import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:substitution/auth/pages/introduction_page.dart'; // Import IntroductionPage

class MockClient extends Mock implements Client {}

void main() {
  setUpAll(() async {
    // Setup shared preferences for EasyLocalization
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  testWidgets('IntroductionPage smoke test', (WidgetTester tester) async {
    final mockClient = MockClient();

    // Stub necessary client methods/getters
    when(() => mockClient.isLogged()).thenReturn(false);
    // Stub homeserver getter if accessed
    when(() => mockClient.homeserver).thenReturn(null);
    when(() => mockClient.userID).thenReturn(null);

    // Create the widget under test wrapped in required providers and localization
    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('en', 'US')],
        path:
            'assets/translations', // This path must match pubspec.yaml assets entry
        fallbackLocale: const Locale('en', 'US'),
        child: MultiProvider(
          providers: [Provider<Client>.value(value: mockClient)],
          child: Builder(
            builder: (context) {
              return const MaterialApp(home: IntroductionPage());
            },
          ),
        ),
      ),
    );

    // Verify that the widget renders
    // Since EasyLocalization might not load assets in test environment easily without more setup,
    // we expect the keys to be displayed if translations are missing.
    // Or, if assets are loaded correctly, the text might be different.
    // Let's check for a key or partial text.
    // "intro.welcome.title" is the first page title key.

    // Wait for async operations (like localization loading)
    await tester.pumpAndSettle();

    // Check if the first page is displayed
    // The key "intro.welcome.title" should be present as text if translations fail,
    // or the translated text if they succeed.
    // A safe bet is finding the image or a widget type.

    expect(find.byType(IntroductionPage), findsOneWidget);

    // Check for the logo image
    expect(
      find.byType(Image),
      findsOneWidget,
    ); // Assuming at least one image (logo)

    // Check for "Next" button text (key: "intro.buttons.next")
    // If translation fails, it shows the key. If it works, it shows "Next" (likely).
    // Let's find by type Text and inspect content if needed, or just ensure no crash.
  });
}
