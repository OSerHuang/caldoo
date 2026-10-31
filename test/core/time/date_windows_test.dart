import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:caldoo/core/time/date_windows.dart';

void main() {
  const shanghai = LocalOffset(480);
  const utc = LocalOffset.utc;

  group('dayKeyOf (local calendar date)', () {
    test('23:30 Asia/Shanghai lands on that same calendar day', () {
      final instant = DateTime.utc(2026, 1, 5, 15, 30);
      expect(dayKeyOf(instant, shanghai), DateTime.utc(2026, 1, 5));
    });

    test(
      'the same instant falls on different days under different offsets',
      () {
        final instant = DateTime.utc(2026, 1, 4, 16, 30);
        expect(dayKeyOf(instant, shanghai), DateTime.utc(2026, 1, 5));
        expect(
          dayKeyOf(instant, const LocalOffset(-480)),
          DateTime.utc(2026, 1, 4),
        );
      },
    );

    test('23:59 and 00:00 local split days while UTC calls it one day', () {
      final before = DateTime.utc(2026, 1, 4, 15, 59);
      final after = DateTime.utc(2026, 1, 4, 16, 0);
      expect(dayKeyOf(before, shanghai), DateTime.utc(2026, 1, 4));
      expect(dayKeyOf(after, shanghai), DateTime.utc(2026, 1, 5));
      expect(dayKeyOf(before, utc), dayKeyOf(after, utc));
    });

    test('a local-flagged DateTime resolves through its instant', () {
      final local = DateTime.utc(2026, 1, 5, 15, 30).toLocal();
      expect(dayKeyOf(local, shanghai), DateTime.utc(2026, 1, 5));
    });
  });

  group('week window (Monday 00:00 -> Sunday 24:00 local)', () {
    test('a Monday 00:05 local meal starts the new week', () {
      final instant = DateTime.utc(2026, 1, 4, 16, 5);
      expect(mondayKeyOf(instant, shanghai), DateTime.utc(2026, 1, 5));
      final keys = weekDayKeysOf(instant, shanghai);
      expect(keys.first, DateTime.utc(2026, 1, 5));
      expect(keys.last, DateTime.utc(2026, 1, 11));
    });

    test('Sunday 23:59 and Monday 00:01 local split into two weeks', () {
      final sunday = DateTime.utc(2026, 1, 4, 15, 59);
      final monday = DateTime.utc(2026, 1, 4, 16, 1);
      expect(dayKeyOf(sunday, shanghai), DateTime.utc(2026, 1, 4));
      expect(dayKeyOf(monday, shanghai), DateTime.utc(2026, 1, 5));
      expect(mondayKeyOf(sunday, shanghai), DateTime.utc(2025, 12, 29));
      expect(mondayKeyOf(monday, shanghai), DateTime.utc(2026, 1, 5));
      expect(
        mondayKeyOf(sunday, shanghai),
        isNot(mondayKeyOf(monday, shanghai)),
      );
    });

    test('the seven keys run Monday..Sunday, contiguous and ordered', () {
      final keys = weekDayKeysOf(DateTime.utc(2026, 1, 7, 4), shanghai);
      expect(keys, hasLength(7));
      expect(
        keys.map((d) => d.weekday),
        orderedEquals(<int>[1, 2, 3, 4, 5, 6, 7]),
      );
      for (var i = 1; i < keys.length; i++) {
        expect(keys[i].difference(keys[i - 1]), const Duration(days: 1));
      }
    });
  });

  group('month keys (local calendar month)', () {
    test('a mid-month instant maps to the first day of its local month', () {
      expect(
        monthKeyOf(DateTime.utc(2026, 1, 20, 4), shanghai),
        DateTime.utc(2026, 1, 1),
      );
    });

    test('23:59 on the last day and 00:00 on the first split months', () {
      final lastOfMonth = DateTime.utc(2026, 1, 31, 15, 59); // 23:59 +08:00
      final firstOfNext = DateTime.utc(2026, 1, 31, 16, 0); // 02-01 00:00 +08

      expect(monthKeyOf(lastOfMonth, shanghai), DateTime.utc(2026, 1, 1));
      expect(monthKeyOf(firstOfNext, shanghai), DateTime.utc(2026, 2, 1));
      expect(
        monthKeyOf(lastOfMonth, shanghai),
        isNot(monthKeyOf(firstOfNext, shanghai)),
      );
    });

    test('the same instant falls in different months under other offsets', () {
      final instant = DateTime.utc(2026, 1, 31, 16, 30);

      expect(monthKeyOf(instant, shanghai), DateTime.utc(2026, 2, 1));
      expect(
        monthKeyOf(instant, const LocalOffset(-480)),
        DateTime.utc(2026, 1, 1),
      );
    });

    test('the day keys of a 31-day month run 1st..31st, contiguous', () {
      final keys = monthDayKeysFor(DateTime.utc(2026, 1, 1));

      expect(keys, hasLength(31));
      expect(keys.first, DateTime.utc(2026, 1, 1));
      expect(keys.last, DateTime.utc(2026, 1, 31));
      for (var i = 1; i < keys.length; i++) {
        expect(keys[i].difference(keys[i - 1]), const Duration(days: 1));
      }
      expect(keys.every((date) => date.isUtc), isTrue);
    });

    test('February has 28 days, or 29 in a leap year', () {
      expect(monthDayKeysFor(DateTime.utc(2026, 2, 1)), hasLength(28));
      expect(monthDayKeysFor(DateTime.utc(2024, 2, 1)), hasLength(29));
      expect(
        monthDayKeysFor(DateTime.utc(2024, 2, 1)).last,
        DateTime.utc(2024, 2, 29),
      );
    });

    test('a mid-month key still yields that whole month from the 1st', () {
      expect(
        monthDayKeysFor(DateTime.utc(2026, 4, 17)),
        monthDayKeysFor(DateTime.utc(2026, 4, 1)),
      );
      expect(monthDayKeysFor(DateTime.utc(2026, 4, 17)), hasLength(30));
    });

    test('monthKeyAfter steps forward and back across year boundaries', () {
      expect(
        monthKeyAfter(DateTime.utc(2026, 1, 1), 1),
        DateTime.utc(2026, 2, 1),
      );
      expect(
        monthKeyAfter(DateTime.utc(2025, 12, 1), 1),
        DateTime.utc(2026, 1, 1),
      );
      expect(
        monthKeyAfter(DateTime.utc(2026, 1, 1), -1),
        DateTime.utc(2025, 12, 1),
      );
      expect(
        monthKeyAfter(DateTime.utc(2026, 3, 1), 12),
        DateTime.utc(2027, 3, 1),
      );
      expect(
        monthKeyAfter(DateTime.utc(2026, 1, 1), 0),
        DateTime.utc(2026, 1, 1),
      );
    });

    test('monthKeyAfter ignores the day component of its key', () {
      expect(
        monthKeyAfter(DateTime.utc(2026, 1, 20), 1),
        DateTime.utc(2026, 2, 1),
      );
    });

    test('daysInMonth matches the calendar, leap years included', () {
      expect(daysInMonth(DateTime.utc(2026, 1, 1)), 31);
      expect(daysInMonth(DateTime.utc(2026, 2, 1)), 28);
      expect(daysInMonth(DateTime.utc(2024, 2, 1)), 29);
      expect(daysInMonth(DateTime.utc(2026, 4, 1)), 30);
      expect(daysInMonth(DateTime.utc(2026, 12, 1)), 31);
    });
  });

  group('day key <-> local calendar date', () {
    test('a date-only key becomes the same local calendar date', () {
      final local = localDateOfKey(DateTime.utc(2026, 9, 21));
      expect(local.isUtc, isFalse);
      expect(local, DateTime(2026, 9, 21));
      expect(local.hour, 0);
    });

    test('a local calendar date becomes the matching UTC-flagged key', () {
      final key = dayKeyFromLocalDate(DateTime(2026, 9, 21, 23, 59, 30));
      expect(key.isUtc, isTrue);
      expect(key, DateTime.utc(2026, 9, 21));
    });

    test('the two helpers round-trip a date picker result', () {
      final key = DateTime.utc(2026, 2, 28);
      expect(dayKeyFromLocalDate(localDateOfKey(key)), key);
      final picked = DateTime(2026, 3, 1);
      expect(localDateOfKey(dayKeyFromLocalDate(picked)), picked);
    });
  });

  group('clock seam', () {
    test('a fixed clock pins "today" and the current week', () {
      final clock = Clock.fixed(DateTime.utc(2026, 1, 7, 4));
      expect(
        currentDayKey(clock: clock, offset: shanghai),
        DateTime.utc(2026, 1, 7),
      );
      expect(currentWeekDayKeys(clock: clock, offset: shanghai), <DateTime>[
        DateTime.utc(2026, 1, 5),
        DateTime.utc(2026, 1, 6),
        DateTime.utc(2026, 1, 7),
        DateTime.utc(2026, 1, 8),
        DateTime.utc(2026, 1, 9),
        DateTime.utc(2026, 1, 10),
        DateTime.utc(2026, 1, 11),
      ]);
    });

    test('two different fixed clocks yield different current weeks', () {
      final beforeMidnight = Clock.fixed(DateTime.utc(2026, 1, 4, 15, 59));
      final afterMidnight = Clock.fixed(DateTime.utc(2026, 1, 4, 16, 1));
      expect(
        currentWeekDayKeys(clock: beforeMidnight, offset: shanghai).first,
        DateTime.utc(2025, 12, 29),
      );
      expect(
        currentWeekDayKeys(clock: afterMidnight, offset: shanghai).first,
        DateTime.utc(2026, 1, 5),
      );
    });
  });

  group('LocalOffset guards', () {
    test('rejects offsets outside UTC-12:00..UTC+14:00', () {
      expect(() => LocalOffset(900), throwsA(isA<AssertionError>()));
      expect(() => LocalOffset(-900), throwsA(isA<AssertionError>()));
    });

    test('accepts the full legal range and exposes its Duration', () {
      expect(const LocalOffset(-720).duration, const Duration(hours: -12));
      expect(const LocalOffset(840).duration, const Duration(hours: 14));
      expect(const LocalOffset(480).minutesEast, 480);
      expect(const LocalOffset(480), const LocalOffset(480));
      expect(const LocalOffset(480).hashCode, const LocalOffset(480).hashCode);
    });
  });
}
