import 'package:flutter_test/flutter_test.dart';
import 'package:substitution/shared/utils/relative_time.dart';

void main() {
  // The function calls DateTime.now() internally, so we must construct
  // input dates relative to the real "now" to avoid flaky tests.

  group('relativeTime', () {
    test('returns "just now" for a future date (clock skew safety)', () {
      // A date slightly in the future should never produce a negative
      // or "in 5m" string — this protects against local clock drift.
      final future = DateTime.now().add(const Duration(minutes: 5));
      expect(relativeTime(future), 'just now');
    });

    test('returns "just now" within the same second', () {
      expect(relativeTime(DateTime.now()), 'just now');
    });

    test('returns "just now" for differences under 60 seconds', () {
      final thirtySecondsAgo = DateTime.now().subtract(
        const Duration(seconds: 30),
      );
      expect(relativeTime(thirtySecondsAgo), 'just now');
    });

    test('returns "1m ago" for a 1-minute-old date', () {
      final oneMinuteAgo = DateTime.now().subtract(const Duration(minutes: 1));
      expect(relativeTime(oneMinuteAgo), '1m ago');
    });

    test('returns "5m ago" for a 5-minute-old date', () {
      final fiveMinutesAgo = DateTime.now().subtract(
        const Duration(minutes: 5),
      );
      expect(relativeTime(fiveMinutesAgo), '5m ago');
    });

    test('returns "59m ago" just before the hour boundary', () {
      final fiftyNineMinutesAgo = DateTime.now().subtract(
        const Duration(minutes: 59),
      );
      expect(relativeTime(fiftyNineMinutesAgo), '59m ago');
    });

    test('returns "1h ago" at the hour boundary', () {
      final oneHourAgo = DateTime.now().subtract(const Duration(hours: 1));
      expect(relativeTime(oneHourAgo), '1h ago');
    });

    test('returns "5h ago" for a 5-hour-old date', () {
      final fiveHoursAgo = DateTime.now().subtract(const Duration(hours: 5));
      expect(relativeTime(fiveHoursAgo), '5h ago');
    });

    test('returns "1d ago" at the day boundary', () {
      final oneDayAgo = DateTime.now().subtract(const Duration(days: 1));
      expect(relativeTime(oneDayAgo), '1d ago');
    });

    test('returns "6d ago" just before the week boundary', () {
      final sixDaysAgo = DateTime.now().subtract(const Duration(days: 6));
      expect(relativeTime(sixDaysAgo), '6d ago');
    });

    test('returns "1w ago" at the week boundary', () {
      final oneWeekAgo = DateTime.now().subtract(const Duration(days: 7));
      expect(relativeTime(oneWeekAgo), '1w ago');
    });

    test('returns "2w ago" for two weeks', () {
      final twoWeeksAgo = DateTime.now().subtract(const Duration(days: 14));
      expect(relativeTime(twoWeeksAgo), '2w ago');
    });

    test('returns "4w ago" for 29 days (still in the weeks bucket)', () {
      // 29 days < 30, so still weeks.
      final twentyNineDaysAgo = DateTime.now().subtract(
        const Duration(days: 29),
      );
      expect(relativeTime(twentyNineDaysAgo), '4w ago');
    });

    test('returns "1mo ago" at the month boundary', () {
      final oneMonthAgo = DateTime.now().subtract(const Duration(days: 30));
      expect(relativeTime(oneMonthAgo), '1mo ago');
    });

    test('returns "6mo ago" for ~180 days', () {
      final sixMonthsAgo = DateTime.now().subtract(const Duration(days: 180));
      expect(relativeTime(sixMonthsAgo), '6mo ago');
    });

    test('returns "12mo ago" for 364 days (documents off-by-one risk)', () {
      // The function uses integer division: inDays ~/ 30.
      // 364 / 30 = 12 (truncated). This documents the "off-by-one" risk:
      // a year minus 1 day is rendered as 12mo, not 11mo.
      final threeSixtyFourDaysAgo = DateTime.now().subtract(
        const Duration(days: 364),
      );
      expect(relativeTime(threeSixtyFourDaysAgo), '12mo ago');
    });

    test('returns "1y ago" at the year boundary', () {
      final oneYearAgo = DateTime.now().subtract(const Duration(days: 365));
      expect(relativeTime(oneYearAgo), '1y ago');
    });

    test('returns "2y ago" for two years', () {
      final twoYearsAgo = DateTime.now().subtract(const Duration(days: 730));
      expect(relativeTime(twoYearsAgo), '2y ago');
    });

    test('handles a very old date (5 years)', () {
      final fiveYearsAgo = DateTime.now().subtract(
        const Duration(days: 365 * 5),
      );
      expect(relativeTime(fiveYearsAgo), '5y ago');
    });
  });
}
