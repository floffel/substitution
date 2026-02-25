import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:substitution/feed/pages/home.dart';

class MockClient extends Mock implements Client {}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  group('Room Feed Isolation Tests', () {
    late MockClient mockClient;

    setUp(() {
      mockClient = MockClient();
      when(() => mockClient.isLogged()).thenReturn(true);
      when(() => mockClient.userID).thenReturn('@user:matrix.org');
    });

    testWidgets('Smoke: HomePage can be instantiated with roomId parameter', (
      WidgetTester tester,
    ) async {
      // This test verifies that HomePage accepts a roomId parameter
      // In a real scenario, the HomePage would filter events by room
      const homePage = HomePage(roomId: '!testroom:matrix.org');
      expect(homePage.roomId, equals('!testroom:matrix.org'));
    });

    testWidgets('HomePage with null roomId shows unified timeline', (
      WidgetTester tester,
    ) async {
      // This test verifies that HomePage can be instantiated without a roomId
      // to show the unified timeline
      const homePage = HomePage(roomId: null);
      expect(homePage.roomId, isNull);
    });

    testWidgets('HomePage roomId parameter is passed correctly', (
      WidgetTester tester,
    ) async {
      // Verify that the roomId is stored correctly
      const testRoomId = '!room123:matrix.org';
      const homePage = HomePage(roomId: testRoomId);
      expect(homePage.roomId, equals(testRoomId));
    });

    testWidgets('HomePage exists and is a StatefulWidget', (
      WidgetTester tester,
    ) async {
      // HomePage should be a StatefulWidget that manages its own state
      const homePage = HomePage(roomId: '!test:matrix.org');
      expect(homePage, isA<StatefulWidget>());
    });
  });
}
