import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';
import 'package:substitution/post/interfaces/event_view.dart';

import '../helpers/test_helpers.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(RelationshipTypes.thread);
  });

  group('EventView', () {
    late MockEvent event;
    late MockEvent displayEvent;
    late EventView view;

    setUp(() {
      event = MockEvent();
      displayEvent = MockEvent();
      view = EventView(event: event, displayEvent: displayEvent);
    });

    // Build a stub User for `senderFromMemoryOrFallback`.
    // Note: the user is constructed in a helper *outside* a `when()` so
    // we can stub its methods without nesting (mocktail disallows
    // `when()` inside another stub).
    User buildUser({String? displayName, String? avatarUrl}) {
      final user = MockUser();
      when(() => user.displayName).thenReturn(displayName);
      when(
        () => user.avatarUrl,
      ).thenReturn(avatarUrl == null ? null : Uri.parse(avatarUrl));
      return user;
    }

    // Build a stub Event with the comment relation metadata.
    MockEvent buildComment({
      required String eventId,
      required int ts,
      required String pointsAt,
    }) {
      final m = MockEvent();
      when(() => m.eventId).thenReturn(eventId);
      when(
        () => m.originServerTs,
      ).thenReturn(DateTime.fromMillisecondsSinceEpoch(ts));
      when(() => m.content).thenReturn({
        'm.relates_to': {
          'm.in_reply_to': {'event_id': pointsAt},
        },
      });
      return m;
    }

    group('avatar helpers', () {
      test('avatarURL() returns the sender avatar mxc:// URI', () {
        final user = buildUser(avatarUrl: 'mxc://matrix.org/avatar123');
        when(() => displayEvent.senderFromMemoryOrFallback).thenReturn(user);

        expect(view.avatarURL(), Uri.parse('mxc://matrix.org/avatar123'));
      });

      test('avatarURL() returns null when the sender has no avatar', () {
        final user = buildUser(avatarUrl: null);
        when(() => displayEvent.senderFromMemoryOrFallback).thenReturn(user);

        expect(view.avatarURL(), isNull);
      });

      test('hasAvatarURL() is true when avatarURL() is non-null', () {
        final user = buildUser(avatarUrl: 'mxc://x/y');
        when(() => displayEvent.senderFromMemoryOrFallback).thenReturn(user);

        expect(view.hasAvatarURL(), isTrue);
      });

      test('hasAvatarURL() is false when avatarURL() is null', () {
        final user = buildUser(avatarUrl: null);
        when(() => displayEvent.senderFromMemoryOrFallback).thenReturn(user);

        expect(view.hasAvatarURL(), isFalse);
      });
    });

    group('username', () {
      test('returns the sender display name when set', () {
        final user = buildUser(displayName: 'Alice');
        when(() => displayEvent.senderFromMemoryOrFallback).thenReturn(user);

        expect(view.username(), 'Alice');
      });

      test('returns "unknown" when display name is null', () {
        final user = buildUser(displayName: null);
        when(() => displayEvent.senderFromMemoryOrFallback).thenReturn(user);

        expect(view.username(), 'unknown');
      });
    });

    group('postEvent', () {
      test('defaults to the original event', () {
        expect(view.postEvent, same(event));
      });
    });

    group('comments', () {
      test(
        'returns deduplicated + sorted comments from aggregatedEvents',
        () async {
          // Two aggregated events that point back at our eventId, plus a
          // duplicate (same eventId) and one that points elsewhere.
          final tsOld = DateTime(2026, 1, 1).millisecondsSinceEpoch;
          final tsNew = DateTime(2026, 6, 1).millisecondsSinceEpoch;

          final e1 = buildComment(eventId: 'c1', ts: tsOld, pointsAt: 'post-1');
          final e2 = buildComment(eventId: 'c2', ts: tsNew, pointsAt: 'post-1');
          final e3 = buildComment(
            eventId: 'c2', // duplicate
            ts: tsNew,
            pointsAt: 'post-1',
          );
          final e4 = buildComment(eventId: 'c4', ts: tsNew, pointsAt: 'other');

          final timeline = MockTimeline();
          when(() => event.eventId).thenReturn('post-1');
          when(
            () => event.aggregatedEvents(timeline, any()),
          ).thenReturn({e1, e2, e3, e4});
          when(() => e1.getDisplayEvent(timeline)).thenReturn(e1);
          when(() => e2.getDisplayEvent(timeline)).thenReturn(e2);
          when(() => e3.getDisplayEvent(timeline)).thenReturn(e3);
          when(() => e4.getDisplayEvent(timeline)).thenReturn(e4);

          // We pass the timeline eagerly so the helper does not need to
          // hit the network.
          final viewWithTimeline = EventView(
            event: event,
            displayEvent: event,
            timeline: timeline,
          );

          final comments = await viewWithTimeline.comments;

          // Should keep only events whose m.relates_to.m.in_reply_to.event_id
          // matches our post-1, deduped by eventId, sorted newest first.
          expect(comments, hasLength(2));
          expect(comments[0].origEvent.eventId, 'c2');
          expect(comments[1].origEvent.eventId, 'c1');
        },
      );

      test('returns an empty list when no aggregated events exist', () async {
        final timeline = MockTimeline();
        when(() => event.eventId).thenReturn('post-1');
        when(
          () => event.aggregatedEvents(timeline, any()),
        ).thenReturn(<Event>{});

        final viewWithTimeline = EventView(
          event: event,
          displayEvent: event,
          timeline: timeline,
        );

        expect(await viewWithTimeline.comments, isEmpty);
      });
    });
  });
}
