import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:substitution/shared/services/theme_service.dart';

void main() {
  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ThemeService', () {
    test('Default theme mode is ThemeMode.system', () async {
      final service = ThemeService();
      await service.initialized;
      expect(service.themeMode, ThemeMode.system);
    });

    test('toggleTheme() switches between light and dark', () async {
      final service = ThemeService();
      await service.initialized;

      await service.setThemeMode(ThemeMode.light);
      expect(service.themeMode, ThemeMode.light);

      await service.toggleTheme(isDark: false);
      expect(service.themeMode, ThemeMode.dark);

      await service.toggleTheme(isDark: true);
      expect(service.themeMode, ThemeMode.light);
    });

    test('setThemeMode() persists to SharedPreferences', () async {
      final service = ThemeService();
      await service.initialized;

      await service.setThemeMode(ThemeMode.dark);

      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString('theme_mode');
      expect(stored, 'dark');
    });

    test('Loading from SharedPreferences restores saved theme', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('theme_mode', 'dark');

      final service = ThemeService();
      await service.initialized;
      expect(service.themeMode, ThemeMode.dark);
    });

    test('notifyListeners() is called on change', () async {
      final service = ThemeService();
      await service.initialized;

      var notificationCount = 0;
      service.addListener(() {
        notificationCount++;
      });

      await service.setThemeMode(ThemeMode.dark);
      expect(notificationCount, greaterThan(0));
    });
  });
}
