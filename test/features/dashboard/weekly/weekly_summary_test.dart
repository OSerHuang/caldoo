/// Task 26: pure tests for the weekly summary's metric definitions.
///
/// Locks the exact rules from the plan: a logged day needs `>= 1` MEAL
/// (exercise-only days do not count), the week shows CUMULATIVE totals (never
/// averages) over logged days only, the target line is the BMR (exercise
/// excluded, goal ignored), salt adherence is `adherent / logged` and goal
/// adherence judges each day against its OWN budget (goal + that day's
/// exercise add-back).
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:caldoo/core/time/date_windows.dart';
import 'package:caldoo/domain/models/daily_exercise.dart';
import 'package:caldoo/domain/models/day_rollup.dart';
import 'package:caldoo/domain/models/user_profile.dart';
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

  group('the chart base is the BMR, never the goal', () {
    test('no goal: BMR is 1979, not the 2236 exercise-inclusive budget', () {
      final WeeklySummary summary = _ready(_fixtureWeek());
      expect(summary.bmrKcal, 1979);
      expect(summary.bmrKcal, isNot(2236));
    });

    test(
      'a set goal does not move the burn, the line base or the difference',
      () {
        // The 1800 kcal goal deliberately differs from the 1979 BMR: if the
        // goal ever leaked into the burn (the goal-based-base regression) the
        // burn would read 5*1800 + 257 = 9257 and the difference +743.
        final WeeklySummaryState state = buildWeeklySummary(
          week: _fixtureWeek(),
          profile: weeklyProfile.copyWith(dailyKcalGoalOverride: 1800),
          today: weeklyNow,
        );
        final WeeklySummary summary = switch (state) {
          final WeeklySummaryReady ready => ready.summary,
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
        // The goal's own metric, judged against each day's budget (goal +
        // that day's exercise): Tue 1500 and Thu 1800 are <= 1800; Wed 2200
        // exceeds even its 1800 + 257 = 2057 budget, and Mon 2000 / Fri 2500
        // exceed the bare 1800.
        expect(summary.goalAdherentDays, 2);
      },
    );

    test('a day over the goal still counts when its exercise covers it', () {
      // The same week with Wed's burn raised from 257 to 500: Wed's budget
      // becomes 1800 + 500 = 2300, so its 2200 intake is within it — the tile
      // must follow the burn edit (the bare-goal rule would still say 2).
      final List<DayRollup> week = rollupWeek(
        clock: weeklyClock(),
        offset: weeklyOffset,
        meals: weeklyMeals(),
        exercises: <DailyExercise>[
          DailyExercise(dayKey: weeklyDayKey(2), kcal: 500),
          DailyExercise(dayKey: weeklyDayKey(5), kcal: 300),
        ],
      );
      final WeeklySummaryState state = buildWeeklySummary(
        week: week,
        profile: weeklyProfile.copyWith(dailyKcalGoalOverride: 1800),
        today: weeklyNow,
      );
      final WeeklySummary summary = switch (state) {
        final WeeklySummaryReady ready => ready.summary,
        _ => fail('expected ready, got ${state.runtimeType}'),
      };
      expect(summary.goalKcal, 1800);
      // Tue 1500, Wed 2200 (<= 2300) and Thu 1800 are adherent; Mon 2000 and
      // Fri 2500 are not — Sat's exercise-only 300 changes nothing (not a
      // logged day).
      expect(summary.goalAdherentDays, 3);
    });
  });

  group(
    'a preset goal follows the weight (BMR-relative, not a fixed number)',
    () {
      // Same person, no pinned BMR: the Mifflin-St Jeor estimate is re-derived
      // from the current weight on every build.
      final UserProfile derived = weeklyProfile.copyWith(
        clearBmrKcalOverride: true,
        dailyGoalPreset: DailyGoalPreset.slowCut,
      );

      WeeklySummary summaryOf(UserProfile profile) {
        final WeeklySummaryState state = buildWeeklySummary(
          week: _fixtureWeek(),
          profile: profile,
          today: weeklyNow,
        );
        return switch (state) {
          final WeeklySummaryReady ready => ready.summary,
          _ => fail('expected ready, got ${state.runtimeType}'),
        };
      }

      test('70 kg: BMR 1649 -> slowCut goal 1399', () {
        final WeeklySummary summary = summaryOf(derived);
        expect(summary.bmrKcal, 1649);
        expect(summary.goalKcal, 1399);
        // The burn is still the BMR + exercise, never the goal: 5*1649 + 257.
        expect(summary.totalBurnKcal, 8502);
      });

      test('65 kg: BMR 1599 -> the same preset now means 1349', () {
        final WeeklySummary summary = summaryOf(derived.copyWith(weightKg: 65));
        expect(summary.bmrKcal, 1599);
        expect(summary.goalKcal, 1349);
      });

      test('热量达标 is judged against the preset goal', () {
        // gain: 1649 + 250 = 1899 -> Tue 1500 and Thu 1800 are adherent;
        // Wed 2200 exceeds even its 1899 + 257 = 2156 day budget.
        final WeeklySummary summary = summaryOf(
          derived.copyWith(dailyGoalPreset: DailyGoalPreset.gain),
        );
        expect(summary.goalKcal, 1899);
        expect(summary.goalAdherentDays, 2);
      });
    },
  );

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
