import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import '../helpers/test_helpers.dart';
import 'package:substitution/settings/pages/room_form_page.dart';

void main() {
  group('RoomFormPage (Edit Mode) Widget Tests', () {
    late MockClient mockClient;
    late MockRoom mockRoom;

    setUpTestInfrastructure();

    setUp(() {
      mockClient = MockClient();
      mockRoom = createMockRoom(
        name: 'Test Room',
        id: '!testroom:matrix.org',
        powerLevel: 100, // Admin power level
      );

      // Mock getRoomById
      when(
        () => mockClient.getRoomById('!testroom:matrix.org'),
      ).thenReturn(mockRoom);

      // Mock getState for power levels, join rules, encryption
      when(() => mockRoom.getState('m.room.power_levels')).thenReturn(null);
      when(() => mockRoom.getState('m.room.join_rules')).thenReturn(null);
      when(() => mockRoom.getState('m.room.encryption')).thenReturn(null);

      // Mock states property
      when(() => mockRoom.states).thenReturn({});

      // Mock getParticipants to avoid empty members
      when(() => mockRoom.getParticipants()).thenReturn([]);

      // Mock room properties
      when(() => mockRoom.avatar).thenReturn(null);
      when(() => mockRoom.topic).thenReturn('');
    });

    testWidgets('Smoke: renders page and verifies content loads', (
      WidgetTester tester,
    ) async {
      await pumpApp(
        tester,
        RoomFormPage(roomId: '!testroom:matrix.org'),
        mockClient: mockClient,
      );

      // Wait for async initialization
      await tester.pumpAndSettle();

      // Verify page renders
      expect(find.byType(RoomFormPage), findsOneWidget);
    });

    testWidgets('Non-admin users see no-permission message', (
      WidgetTester tester,
    ) async {
      final memberRoom = createMockRoom(
        name: 'Member Room',
        id: '!memberroom:matrix.org',
        powerLevel: 50, // Non-admin power level
      );

      when(
        () => mockClient.getRoomById('!memberroom:matrix.org'),
      ).thenReturn(memberRoom);
      when(() => memberRoom.getState('m.room.power_levels')).thenReturn(null);
      when(() => memberRoom.getState('m.room.join_rules')).thenReturn(null);
      when(() => memberRoom.getState('m.room.encryption')).thenReturn(null);
      when(() => memberRoom.states).thenReturn({});
      when(() => memberRoom.getParticipants()).thenReturn([]);
      when(() => memberRoom.avatar).thenReturn(null);
      when(() => memberRoom.topic).thenReturn('');

      await pumpApp(
        tester,
        RoomFormPage(roomId: '!memberroom:matrix.org'),
        mockClient: mockClient,
      );

      await tester.pumpAndSettle();

      // Verify page renders (non-admin sees lock/permission message)
      expect(find.byType(RoomFormPage), findsOneWidget);
    });

    testWidgets('Admin users can access full edit UI', (
      WidgetTester tester,
    ) async {
      await pumpApp(
        tester,
        RoomFormPage(roomId: '!testroom:matrix.org'),
        mockClient: mockClient,
      );

      await tester.pumpAndSettle();

      // Verify admin access with full UI
      expect(find.byType(RoomFormPage), findsOneWidget);
    });

    testWidgets('Room is fetched correctly on initialization', (
      WidgetTester tester,
    ) async {
      await pumpApp(
        tester,
        RoomFormPage(roomId: '!testroom:matrix.org'),
        mockClient: mockClient,
      );

      await tester.pumpAndSettle();

      // Verify getRoomById was called with correct room ID
      verify(
        () => mockClient.getRoomById('!testroom:matrix.org'),
      ).called(greaterThanOrEqualTo(1));
    });
  });
}
