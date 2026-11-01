/// Task 26: pure tests for the weekly summary's metric definitions.
///
/// Locks the exact rules from the plan: a logged day needs `>= 1` MEAL
/// (exercise-only days do not count), the week shows CUMULATIVE totals (never
/// averages) over logged days only, the target line is the BASE budget
/// (exercise excluded) and salt adherence is `adherent / logged`.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:caldoo/core/time/date_windows.dart';
import 'package:caldoo/domain/models/daily_exercise.dart';
import 'package:caldoo/domain/models/day_rollup.dart';
import 'package:caldoo/domain/models/weight_entry.dart';
import 'package:caldoo/features/dashboard/weekly/weekly_summary.dart';

import '_fixtures.dart';

/// Rolls the fixture week up exactly the way the providers do.
List<DayRollup> _fixtureWeek() => rollupWeek(
  clock: weeklyClock(),
  offset: weeklyOffset,
  meals: weeklyMeals(),
  exercises: weeklyExercises(),
);

/// Unwraps the ready state, failing loudly otherwise.
WeeklySummary _ready(List<DayRollup> week) {
  final WeeklySummaryState state = buildWeeklySummary(
    week: week,
    profile: weeklyProfile,
    today: weeklyNow,
  );
  return switch (state) {
    final WeeklySummaryReady ready => ready.summary,
    _ => fail('expected WeeklySummaryReady, got ${state.runtimeType}'),
  };
}

void main() {
  group('logged day = a day with >= 1 MEAL (exercise-only is NOT logged)', () {
    test('the fixture has 5 logged days; Sat (exercise-only) is excluded', () {
      final List<DayRollup> week = _fixtureWeek();
      expect(week.length, 7);

      // Sat (index 5) has exercise but no meal -> not logged.
      expect(week[5].exerciseKcal, 300);
      expect(week[5].mealCount, 0);
      // Sun (index 6) is completely empty.
      expect(week[6].mealCount, 0);
      expect(week[6].intakeKcal, 0);

      expect(_ready(week).loggedDays, 5);
    });
  });

  group('the week shows cumulative totals over LOGGED days only', () {
    test('total intake = 10000 (the Monday..Friday sum)', () {
      final WeeklySummary summary = _ready(_fixtureWeek());
      expect(summary.totalIntakeKcal, 10000);
      expect(summary.loggedDays, 5);
    });

    test('total burn = 5*1979 + 257 = 10152 (BMR + each day\'s exercise)', () {
      final WeeklySummary summary = _ready(_fixtureWeek());
      // BMR alone would be 9895; adding Sat's 300 (exercise-only, not a
      // logged day) would be 10195 — both are wrong for this week.
      expect(summary.totalBurnKcal, 10152);
      expect(summary.totalBurnKcal, isNot(9895));
      expect(summary.totalBurnKcal, isNot(10195));
    });

    test('difference = total intake - total burn = -152 (缺口)', () {
      final WeeklySummary summary = _ready(_fixtureWeek());
      expect(summary.totalBalanceKcal, -152);
      // If exercise were wrongly excluded from the per-day budget the
      // difference would instead be 10000 - 9895 = +105.
      expect(summary.totalBalanceKcal, isNot(105));
    });
  });

  group('target line = BASE budget (= BMR, exercise EXCLUDED)', () {
    test('base budget is 1979, not the 2236 exercise-inclusive budget', () {
      final WeeklySummary summary = _ready(_fixtureWeek());
      expect(summary.baseBudgetKcal, 1979);
      expect(summary.baseBudgetKcal, isNot(2236));
    });
  });

  group('salt adherence = adherent logged days / logged days', () {
    test('4 of 5 logged days are <= 2000 mg -> 0.8', () {
      final WeeklySummary summary = _ready(_fixtureWeek());
      expect(summary.adherentDays, 4);
      expect(summary.loggedDays, 5);
      expect(summary.saltAdherence, 0.8);
    });

    test('the 2000 mg boundary is inclusive (Thu + Fri count as adherent)', () {
      final List<DayRollup> week = _fixtureWeek();
      expect(week[3].sodiumMg, 2000.0); // Thu
      expect(week[4].sodiumMg, 2000.0); // Fri
      expect(_ready(week).adherentDays, 4);
    });
  });

  group('malformed input: an empty / short week is typed, never a crash', () {
    test('a week with no logged day -> WeeklySummaryEmpty', () {
      final WeeklySummaryState state = buildWeeklySummary(
        week: <DayRollup>[],
        profile: weeklyProfile,
        today: weeklyNow,
      );
      expect(state, isA<WeeklySummaryEmpty>());
    });

    test('a fully unlogged 7-day week -> WeeklySummaryEmpty', () {
      final List<DayRollup> empty = rollupWeek(
        clock: weeklyClock(),
        offset: weeklyOffset,
        meals: const <MealWithItems>[],
        exercises: const <DailyExercise>[],
      );
      expect(
        buildWeeklySummary(
          week: empty,
          profile: weeklyProfile,
          today: weeklyNow,
        ),
        isA<WeeklySummaryEmpty>(),
      );
    });

    test(
      'logged week + no profile -> WeeklySummaryNoProfile (intake kept)',
      () {
        final WeeklySummaryState state = buildWeeklySummary(
          week: _fixtureWeek(),
          profile: null,
          today: weeklyNow,
        );
        final WeeklySummaryNoProfile noProfile = switch (state) {
          final WeeklySummaryNoProfile value => value,
          _ => fail(
            'expected WeeklySummaryNoProfile, got ${state.runtimeType}',
          ),
        };
        expect(noProfile.loggedDays, 5);
        expect(noProfile.adherentDays, 4);
        expect(noProfile.totalIntakeKcal, 10000.0);
        expect(noProfile.saltAdherence, 0.8);
      },
    );
  });

  test('the target-line label is distinct from the daily 今日额度(含运动)', () {
    expect(weeklyTargetLineLabel, '基础代谢(不含运动)');
    expect(weeklyTargetLineLabel, isNot(contains('今日额度')));
    expect(weeklyTargetLineDashArray, <int>[6, 4]);
  });

  group('weight change = last in-week entry minus first (>= 2 entries)', () {
    /// Runs the builder with in-week weight rows (Jan 5..11 = the fixture week).
    WeeklySummaryState buildWithWeights(List<WeightEntry> entries) =>
        buildWeeklySummary(
          week: _fixtureWeek(),
          profile: weeklyProfile,
          today: weeklyNow,
          weightEntries: entries,
        );

    test('three entries -> last minus first, signed', () {
      final WeeklySummaryState state = buildWithWeights(<WeightEntry>[
        WeightEntry(dayKey: weeklyDayKey(0), weightKg: 69.0),
        WeightEntry(dayKey: weeklyDayKey(4), weightKg: 68.7),
        WeightEntry(dayKey: weeklyDayKey(6), weightKg: 68.4),
      ]);
      final WeeklySummary summary = switch (state) {
        final WeeklySummaryReady ready => ready.summary,
        _ => fail('expected ready, got ${state.runtimeType}'),
      };
      expect(summary.weightDeltaKg, closeTo(-0.6, 1e-9));
    });

    test('a single entry has no direction -> null (no tile)', () {
      final WeeklySummaryState state = buildWithWeights(<WeightEntry>[
        WeightEntry(dayKey: weeklyDayKey(2), weightKg: 68.4),
      ]);
      expect((state as WeeklySummaryReady).summary.weightDeltaKg, isNull);
    });

    test('no entries -> null', () {
      final WeeklySummary summary = _ready(_fixtureWeek());
      expect(summary.weightDeltaKg, isNull);
    });

    test('the delta is profile-independent: NoProfile carries it too', () {
      final WeeklySummaryState state = buildWeeklySummary(
        week: _fixtureWeek(),
        profile: null,
        today: weeklyNow,
        weightEntries: <WeightEntry>[
          WeightEntry(dayKey: weeklyDayKey(0), weightKg: 69.0),
          WeightEntry(dayKey: weeklyDayKey(6), weightKg: 69.6),
        ],
      );
      expect(
        (state as WeeklySummaryNoProfile).weightDeltaKg,
        closeTo(0.6, 1e-9),
      );
    });
  });
}
