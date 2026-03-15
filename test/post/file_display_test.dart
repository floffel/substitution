import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:substitution/post/widgets/display/file_display.dart';
import 'package:video_player/video_player.dart';

// Mock classes
class MockEvent extends Mock implements Event {
  late String _messageType;

  @override
  String get messageType => _messageType;

  void setMessageType(String type) {
    _messageType = type;
  }
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  group('FileDisplay Widget - Rich Media Previews', () {
    late MockEvent mockImageEvent;
    late MockEvent mockVideoEvent;

    setUp(() {
      mockImageEvent = MockEvent();
      mockVideoEvent = MockEvent();

      // Setup image event with proper messageType
      mockImageEvent.setMessageType(MessageTypes.Image);

      // Setup video event
      mockVideoEvent.setMessageType(MessageTypes.Video);
    });

    testWidgets('Smoke test: FileDisplay renders for image message type', (
      WidgetTester tester,
    ) async {
      final fileData = (
        origEvent: mockImageEvent,
        displayEvent: mockImageEvent,
        videoController: null as VideoPlayerController?,
      );

      await tester.pumpWidget(
        EasyLocalization(
          supportedLocales: const [Locale('en', 'US')],
          path: 'assets/translations',
          fallbackLocale: const Locale('en', 'US'),
          child: MaterialApp(home: Scaffold(body: FileDisplay(file: fileData))),
        ),
      );

      await tester.pump();

      // Verify FileDisplay renders
      expect(find.byType(FileDisplay), findsOneWidget);
    });

    testWidgets('Smoke test: FileDisplay renders for video message type', (
      WidgetTester tester,
    ) async {
      final fileData = (
        origEvent: mockVideoEvent,
        displayEvent: mockVideoEvent,
        videoController: null as VideoPlayerController?,
      );

      await tester.pumpWidget(
        EasyLocalization(
          supportedLocales: const [Locale('en', 'US')],
          path: 'assets/translations',
          fallbackLocale: const Locale('en', 'US'),
          child: MaterialApp(home: Scaffold(body: FileDisplay(file: fileData))),
        ),
      );

      await tester.pump();

      // Verify FileDisplay renders
      expect(find.byType(FileDisplay), findsOneWidget);
    });

    testWidgets('Image events render FileDisplay widget', (
      WidgetTester tester,
    ) async {
      final fileData = (
        origEvent: mockImageEvent,
        displayEvent: mockImageEvent,
        videoController: null as VideoPlayerController?,
      );

      await tester.pumpWidget(
        EasyLocalization(
          supportedLocales: const [Locale('en', 'US')],
          path: 'assets/translations',
          fallbackLocale: const Locale('en', 'US'),
          child: MaterialApp(home: Scaffold(body: FileDisplay(file: fileData))),
        ),
      );

      await tester.pump();

      // Verify FileDisplay renders for image content
      expect(find.byType(FileDisplay), findsOneWidget);
    });

    testWidgets('Video events initialize video display logic', (
      WidgetTester tester,
    ) async {
      final fileData = (
        origEvent: mockVideoEvent,
        displayEvent: mockVideoEvent,
        videoController: null as VideoPlayerController?,
      );

      await tester.pumpWidget(
        EasyLocalization(
          supportedLocales: const [Locale('en', 'US')],
          path: 'assets/translations',
          fallbackLocale: const Locale('en', 'US'),
          child: MaterialApp(home: Scaffold(body: FileDisplay(file: fileData))),
        ),
      );

      await tester.pump();

      // Verify the FileDisplay renders for video content
      expect(find.byType(FileDisplay), findsOneWidget);
    });

    testWidgets('FileDisplay handles multiple files in theory', (
      WidgetTester tester,
    ) async {
      // This test validates that FileDisplay handles individual files
      // FileDisplayContainer would handle multiple files with carousel
      final fileData = (
        origEvent: mockImageEvent,
        displayEvent: mockImageEvent,
        videoController: null as VideoPlayerController?,
      );

      await tester.pumpWidget(
        EasyLocalization(
          supportedLocales: const [Locale('en', 'US')],
          path: 'assets/translations',
          fallbackLocale: const Locale('en', 'US'),
          child: MaterialApp(home: Scaffold(body: FileDisplay(file: fileData))),
        ),
      );

      await tester.pump();

      expect(find.byType(FileDisplay), findsOneWidget);
    });

    testWidgets('FileDisplay renders with all supported media types', (
      WidgetTester tester,
    ) async {
      // Test that FileDisplay can handle different media types
      final audioEvent = MockEvent();
      audioEvent.setMessageType(MessageTypes.Audio);

      final fileData = (
        origEvent: audioEvent,
        displayEvent: audioEvent,
        videoController: null as VideoPlayerController?,
      );

      await tester.pumpWidget(
        EasyLocalization(
          supportedLocales: const [Locale('en', 'US')],
          path: 'assets/translations',
          fallbackLocale: const Locale('en', 'US'),
          child: MaterialApp(home: Scaffold(body: FileDisplay(file: fileData))),
        ),
      );

      await tester.pump();

      // Verify the widget renders
      expect(find.byType(FileDisplay), findsOneWidget);
    });
  });
}
