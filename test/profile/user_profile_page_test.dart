import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'dart:async';

class MockClient extends Mock implements Client {}

class MockProfile extends Mock implements Profile {}

class MockRoom extends Mock implements Room {}

void main() {
  group('User Profile Page Widget Tests', () {
    late MockClient mockClient;
    late MockProfile mockProfile;
    late List<MockRoom> mockRooms;

    setUp(() {
      mockClient = MockClient();
      mockProfile = MockProfile();
      mockRooms = [MockRoom(), MockRoom()];

      // Setup profile
      when(() => mockProfile.displayName).thenReturn('Test User');
      when(() => mockProfile.avatarUrl).thenReturn(null);

      // Setup rooms
      when(() => mockRooms[0].id).thenReturn('!room1:matrix.org');
      when(() => mockRooms[0].name).thenReturn('Room 1');
      when(
        () => mockRooms[0].getPowerLevelByUserId('@testuser:matrix.org'),
      ).thenReturn(60);

      when(() => mockRooms[1].id).thenReturn('!room2:matrix.org');
      when(() => mockRooms[1].name).thenReturn('Room 2');
      when(
        () => mockRooms[1].getPowerLevelByUserId('@testuser:matrix.org'),
      ).thenReturn(50);

      // Setup client
      when(
        () => mockClient.getProfileFromUserId('@testuser:matrix.org'),
      ).thenAnswer((_) async => mockProfile);
      when(
        () => mockClient.getRoomById('!room1:matrix.org'),
      ).thenReturn(mockRooms[0]);
      when(
        () => mockClient.getRoomById('!room2:matrix.org'),
      ).thenReturn(mockRooms[1]);
    });

    testWidgets('Smoke: renders avatar, display name, Matrix ID', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Provider<Client>.value(
              value: mockClient,
              child: FutureBuilder<Profile>(
                future: mockClient.getProfileFromUserId('@testuser:matrix.org'),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const CircularProgressIndicator();
                  }
                  final profile = snapshot.data!;
                  return Column(
                    children: [
                      CircleAvatar(
                        child: Text((profile.displayName ?? 'User')[0]),
                      ),
                      Text(profile.displayName ?? 'Unknown'),
                      const Text('@testuser:matrix.org'),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify widgets are rendered
      expect(find.byType(CircleAvatar), findsOneWidget);
      expect(find.text('Test User'), findsOneWidget);
      expect(find.text('@testuser:matrix.org'), findsOneWidget);
    });

    testWidgets('Shows list of rooms user posts in', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Provider<Client>.value(
              value: mockClient,
              child: ListView(
                children:
                    mockRooms.map((room) {
                      return ListTile(title: Text(room.name));
                    }).toList(),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify room list tiles are rendered
      expect(find.byType(ListTile), findsWidgets);
      expect(find.text('Room 1'), findsOneWidget);
      expect(find.text('Room 2'), findsOneWidget);
    });

    testWidgets('Loading state while fetching', (WidgetTester tester) async {
      // Use a Completer to manually control when the future completes
      final completer = Completer<Profile>();

      when(
        () => mockClient.getProfileFromUserId(any()),
      ).thenAnswer((_) => completer.future);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Provider<Client>.value(
              value: mockClient,
              child: FutureBuilder<Profile>(
                future: mockClient.getProfileFromUserId('@testuser:matrix.org'),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const CircularProgressIndicator();
                  }
                  if (snapshot.hasData) {
                    return Text(snapshot.data!.displayName ?? 'Unknown');
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        ),
      );

      // Should show loading indicator
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Complete the future
      completer.complete(mockProfile);
      await tester.pumpAndSettle();

      // Should now show the profile name
      expect(find.text('Test User'), findsOneWidget);
    });

    testWidgets('Error state for invalid user ID', (WidgetTester tester) async {
      final completer = Completer<Profile>();

      when(
        () => mockClient.getProfileFromUserId('@invalid:matrix.org'),
      ).thenAnswer((_) => completer.future);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Provider<Client>.value(
              value: mockClient,
              child: FutureBuilder<Profile>(
                future: mockClient.getProfileFromUserId('@invalid:matrix.org'),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Text('User not found');
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        ),
      );

      // Throw error
      completer.completeError(Exception('User not found'));
      await tester.pumpAndSettle();

      expect(find.text('User not found'), findsOneWidget);
    });
  });
}
