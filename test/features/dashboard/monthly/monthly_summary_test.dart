/// Pure tests for the monthly summary's metric definitions.
///
/// Locks the exact rules the merged dashboard's month view shares with the
/// week view: a logged day needs `>= 1` MEAL (exercise-only days do not count),
/// the month shows CUMULATIVE totals (never averages) over logged days only,
/// the target line is the BMR (exercise excluded, goal ignored) and salt adherence is
/// `adherent / logged`.
///
/// The fixture is the fixed 2026-01 calendar month (31 days) mid-flight on
/// 2026-01-20, with the same hand-computed numbers as the weekly fixture — so
/// these assertions also prove the two zoom levels agree number for number.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:caldoo/core/time/date_windows.dart';
import 'package:caldoo/domain/models/daily_exercise.dart';
import 'package:caldoo/domain/models/day_rollup.dart';
import 'package:caldoo/features/dashboard/monthly/monthly_summary_providers.dart';
import 'package:caldoo/features/dashboard/period/period_summary.dart';

import '_fixtures.dart';

/// Rolls the fixture month up exactly the way the providers do.
List<DayRollup> _fixtureMonth() => <DayRollup>[
  for (final DateTime key in monthDayKeysFor(monthlyKey))
    rollupDay(
      date: key,
      meals: monthlyMeals(),
      exercises: monthlyExercises(),
      offset: monthlyOffset,
    ),
];

/// Unwraps the ready state, failing loudly otherwise.
PeriodSummary _ready(List<DayRollup> month) {
  final PeriodSummaryState state = buildPeriodSummary(
    days: month,
    profile: monthlyProfile,
    today: monthlyNow,
  );
  return switch (state) {
    final PeriodSummaryReady ready => ready.summary,
    _ => fail('expected PeriodSummaryReady, got ${state.runtimeType}'),
  };
}

void main() {
  group('the month is 28..31 rollups in calendar order', () {
    test('the fixture month has 31 rollups, 1st..31st', () {
      final List<DayRollup> month = _fixtureMonth();

      expect(month, hasLength(31));
      expect(month.first.date, DateTime.utc(2026, 1, 1));
      expect(month.last.date, DateTime.utc(2026, 1, 31));
      for (var i = 1; i < month.length; i++) {
        expect(
          month[i].date.difference(month[i - 1].date),
          const Duration(days: 1),
        );
      }
    });
  });

  group('logged day = a day with >= 1 MEAL (exercise-only is NOT logged)', () {
    test('the fixture has 5 logged days; Jan 10 is exercise-only', () {
      final List<DayRollup> month = _fixtureMonth();

      // Jan 10 (index 9) has exercise but no meal -> not logged.
      expect(month[9].exerciseKcal, 300);
      expect(month[9].mealCount, 0);
      // Jan 31 (index 30) is completely empty.
      expect(month[30].mealCount, 0);
      expect(month[30].intakeKcal, 0);

      final PeriodSummary summary = _ready(month);
      expect(summary.loggedDays, 5);
      expect(summary.isLogged(9), isFalse);
      expect(summary.isLogged(0), isTrue);
    });
  });

  group('the month shows cumulative totals over LOGGED days only', () {
    test('total intake = 10000 (days 1, 2, 3, 5 and 20)', () {
      final PeriodSummary summary = _ready(_fixtureMonth());
      expect(summary.totalIntakeKcal, 10000);
      expect(summary.loggedDays, 5);
    });

    test('total burn = 5*1979 + 257 = 10152 (BMR + each day\'s exercise)', () {
      final PeriodSummary summary = _ready(_fixtureMonth());
      // BMR alone would be 9895; adding Jan 10's 300 (exercise-only, not a
      // logged day) would be 10195 — both are wrong for this month.
      expect(summary.totalBurnKcal, 10152);
      expect(summary.totalBurnKcal, isNot(9895));
      expect(summary.totalBurnKcal, isNot(10195));
    });

    test('difference = total intake - total burn = -152 (缺口)', () {
      final PeriodSummary summary = _ready(_fixtureMonth());
      expect(summary.totalBalanceKcal, -152);
      // If exercise were wrongly excluded from the per-day budget the
      // difference would instead be 10000 - 9895 = +105.
      expect(summary.totalBalanceKcal, isNot(105));
    });
  });

  group('the chart base is the BMR, never the goal', () {
    test('no goal: BMR is 1979, not the 2236 exercise-inclusive budget', () {
      final PeriodSummary summary = _ready(_fixtureMonth());
      expect(summary.bmrKcal, 1979);
      expect(summary.bmrKcal, isNot(2236));
    });

    test(
      'a set goal does not move the burn, the line base or the difference',
      () {
        // The 1800 kcal goal deliberately differs from the 1979 BMR: if the
        // goal ever leaked into the burn (the goal-based-base regression) the
        // burn would read 5*1800 + 257 = 9257 and the difference +743.
        final PeriodSummaryState state = buildPeriodSummary(
          days: _fixtureMonth(),
          profile: monthlyProfile.copyWith(dailyKcalGoalOverride: 1800),
          today: monthlyNow,
        );
        final PeriodSummary summary = switch (state) {
          final PeriodSummaryReady ready => ready.summary,
          _ => fail('expected ready, got ${state.runtimeType}'),
        };
        expect(summary.bmrKcal, 1979);
        expect(summary.bmrKcal, isNot(1800));
        expect(summary.goalKcal, 1800);
        // Burn stays BMR + exercise: 5*1979 + 257, NOT 5*1800 + 257.
        expect(summary.totalBurnKcal, 10152);
        expect(summary.totalBurnKcal, isNot(9257));
        // Difference stays intake - (BMR + exercise): -152, NOT +743.
        expect(summary.totalBalanceKcal, -152);
        expect(summary.totalBalanceKcal, isNot(743));
        // The goal's own metric: Jan 2 (1500) and Jan 5 (1800) are <= 1800;
        // Jan 1 (2000), Jan 3 (2200) and Jan 20 (2500) are not.
        expect(summary.goalAdherentDays, 2);
      },
    );
  });

  group('salt adherence = adherent logged days / logged days', () {
    test('4 of 5 logged days are <= 2000 mg -> 0.8', () {
      final PeriodSummary summary = _ready(_fixtureMonth());
      expect(summary.adherentDays, 4);
      expect(summary.loggedDays, 5);
      expect(summary.saltAdherence, 0.8);
    });

    test('the 2000 mg boundary is inclusive (days 5 and 20 count)', () {
      final List<DayRollup> month = _fixtureMonth();
      expect(month[4].sodiumMg, 2000.0); // Jan 5
      expect(month[19].sodiumMg, 2000.0); // Jan 20
      expect(_ready(month).adherentDays, 4);
    });
  });

  group('days after "today" in the viewed month', () {
    test('future days stay unlogged, keep their bars and add no totals', () {
      final List<DayRollup> month = _fixtureMonth();

      for (var i = 20; i < month.length; i++) {
        expect(month[i].mealCount, 0);
        expect(month[i].intakeKcal, 0);
      }

      final PeriodSummary summary = _ready(month);
      // The chart still plots the whole month, including the future days.
      expect(summary.days, hasLength(31));
      expect(summary.days.last.date, DateTime.utc(2026, 1, 31));
      // ...and they contribute nothing to the running totals.
      expect(summary.totalIntakeKcal, 10000);
      expect(summary.totalBurnKcal, 10152);
      expect(summary.totalBalanceKcal, -152);
    });
  });

  group('malformed input: an empty / short month is typed, never a crash', () {
    test('a month with no logged day -> PeriodSummaryEmpty', () {
      final PeriodSummaryState state = buildPeriodSummary(
        days: <DayRollup>[],
        profile: monthlyProfile,
        today: monthlyNow,
      );
      expect(state, isA<PeriodSummaryEmpty>());
    });

    test('a fully unlogged 31-day month -> PeriodSummaryEmpty', () {
      final List<DayRollup> empty = <DayRollup>[
        for (final DateTime key in monthDayKeysFor(monthlyKey))
          rollupDay(
            date: key,
            meals: const <MealWithItems>[],
            exercises: const <DailyExercise>[],
            offset: monthlyOffset,
          ),
      ];
      expect(
        buildPeriodSummary(
          days: empty,
          profile: monthlyProfile,
          today: monthlyNow,
        ),
        isA<PeriodSummaryEmpty>(),
      );
    });

    test(
      'logged month + no profile -> PeriodSummaryNoProfile (intake kept)',
      () {
        final PeriodSummaryState state = buildPeriodSummary(
          days: _fixtureMonth(),
          profile: null,
          today: monthlyNow,
        );
        final PeriodSummaryNoProfile noProfile = switch (state) {
          final PeriodSummaryNoProfile value => value,
          _ => fail(
            'expected PeriodSummaryNoProfile, got ${state.runtimeType}',
          ),
        };
        expect(noProfile.loggedDays, 5);
        expect(noProfile.adherentDays, 4);
        expect(noProfile.totalIntakeKcal, 10000);
        expect(noProfile.saltAdherence, 0.8);
        expect(noProfile.days, hasLength(31));
      },
    );
  });

  group('month window (the local calendar month, never a rolling 30 days)', () {
    test('a first-day key yields first-day 00:00 .. next first-day 00:00', () {
      final ({DateTime start, DateTime end}) window = monthWindowFor(
        monthlyKey,
        monthlyOffset,
      );
      // 2026-01-01 00:00 +08:00 == 2025-12-31 16:00 UTC.
      expect(window.start, DateTime.utc(2025, 12, 31, 16));
      expect(window.end, DateTime.utc(2026, 1, 31, 16));
      expect(window.end.difference(window.start), const Duration(days: 31));
    });

    test('a mid-month key means its month, not a window from that day', () {
      final ({DateTime start, DateTime end}) window = monthWindowFor(
        monthlyDayKey(20),
        monthlyOffset,
      );
      expect(window.start, DateTime.utc(2025, 12, 31, 16));
      expect(window.end, DateTime.utc(2026, 1, 31, 16));
      expect(monthFirstDayKey(monthlyDayKey(20)), monthlyKey);
    });

    test('February is 28 or 29 days, and the window follows', () {
      final DateTime february2026 = monthKeyAfter(monthlyKey, 1);
      final ({DateTime start, DateTime end}) short = monthWindowFor(
        february2026,
        monthlyOffset,
      );
      expect(short.end.difference(short.start), const Duration(days: 28));
      final ({DateTime start, DateTime end}) leap = monthWindowFor(
        DateTime.utc(2024, 2),
        monthlyOffset,
      );
      expect(leap.end.difference(leap.start), const Duration(days: 29));
    });
  });
}
