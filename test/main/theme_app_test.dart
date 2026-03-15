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

  testWidgets('App starts with system theme by default', (
    WidgetTester tester,
  ) async {
    final themeService = ThemeService();
    await themeService.initialized;

    expect(themeService.themeMode, ThemeMode.system);
  });

  testWidgets('darkTheme is defined and different from theme', (
    WidgetTester tester,
  ) async {
    final darkTheme = ThemeData(
      colorSchemeSeed: Colors.green,
      useMaterial3: true,
      brightness: Brightness.dark,
    );

    final lightTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
    );

    expect(darkTheme.brightness, Brightness.dark);
    expect(lightTheme.brightness, Brightness.light);
  });

  testWidgets('Changing ThemeService updates MaterialApp reactively', (
    WidgetTester tester,
  ) async {
    final themeService = ThemeService();
    await themeService.initialized;

    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('en', 'US')],
        path: 'assets/translations',
        fallbackLocale: const Locale('en', 'US'),
        child: ChangeNotifierProvider<ThemeService>.value(
          value: themeService,
          child: Builder(
            builder: (context) {
              final theme = context.watch<ThemeService>().themeMode;
              return MaterialApp(
                themeMode: theme,
                theme: ThemeData(
                  useMaterial3: true,
                  brightness: Brightness.light,
                ),
                darkTheme: ThemeData(
                  colorSchemeSeed: Colors.green,
                  useMaterial3: true,
                  brightness: Brightness.dark,
                ),
                home: Scaffold(body: Center(child: Text('Theme: $theme'))),
              );
            },
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await themeService.setThemeMode(ThemeMode.dark);
    await tester.pumpAndSettle();

    expect(themeService.themeMode, ThemeMode.dark);
  });
}
