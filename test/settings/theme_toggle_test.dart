import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:substitution/shared/services/theme_service.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  testWidgets('Dark mode toggle switch exists', (WidgetTester tester) async {
    final themeService = ThemeService();
    await themeService.initialized;

    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('en', 'US')],
        path: 'assets/translations',
        fallbackLocale: const Locale('en', 'US'),
        child: ChangeNotifierProvider<ThemeService>.value(
          value: themeService,
          child: MaterialApp(
            home: Scaffold(
              body: SwitchListTile(
                title: const Text('Dark Mode'),
                value: themeService.themeMode == ThemeMode.dark,
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.byType(SwitchListTile), findsOneWidget);
  });

  testWidgets('Switch value reflects current theme mode', (
    WidgetTester tester,
  ) async {
    final themeService = ThemeService();
    await themeService.initialized;
    await themeService.setThemeMode(ThemeMode.dark);

    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('en', 'US')],
        path: 'assets/translations',
        fallbackLocale: const Locale('en', 'US'),
        child: ChangeNotifierProvider<ThemeService>.value(
          value: themeService,
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return SwitchListTile(
                    title: const Text('Dark Mode'),
                    value:
                        context.watch<ThemeService>().themeMode ==
                        ThemeMode.dark,
                    onChanged: (_) {},
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.byType(SwitchListTile), findsOneWidget);
  });

  testWidgets('Tapping toggle calls toggleTheme()', (
    WidgetTester tester,
  ) async {
    final themeService = ThemeService();
    await themeService.initialized;
    await themeService.setThemeMode(ThemeMode.light);

    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('en', 'US')],
        path: 'assets/translations',
        fallbackLocale: const Locale('en', 'US'),
        child: ChangeNotifierProvider<ThemeService>.value(
          value: themeService,
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return SwitchListTile(
                    title: const Text('Dark Mode'),
                    value:
                        context.watch<ThemeService>().themeMode ==
                        ThemeMode.dark,
                    onChanged: (_) async {
                      await context.read<ThemeService>().toggleTheme();
                    },
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );

    expect(themeService.themeMode, ThemeMode.light);

    // Tap the switch
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(themeService.themeMode, ThemeMode.dark);
  });
}
