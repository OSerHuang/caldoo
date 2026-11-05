/// Riverpod wiring for the weekly summary dashboard (task 26 + task 31
/// history).
///
/// Everything is derived from the repository `watch` streams and recomputed on
/// every emission:
///
/// * [weeklyMealsForWeekProvider] / [weeklyExercisesForWeekProvider] are
///   **family** [StreamProvider]s over `watchMealsForWeek` / `watchRange` for
///   one explicit **fixed** Mon..Sun local week (the exercise range is
///   expressed in date-only day keys), so any historical week can be rendered
///   from its own live data;
/// * [weeklyRollupsForWeekProvider] folds them with the task-9 `rollupDay`
///   function, one call per day key, producing exactly seven `DayRollup`s
///   Monday..Sunday (never a rolling 7-day window);
/// * [weeklySummaryForWeekProvider] turns that rollup list plus the profile
///   into a [WeeklySummaryState] via [buildWeeklySummary] — so the metric
///   definitions live in one pure function.
///
/// ## Why families instead of a "selected week" override
///
/// The 概览 tab's week view shows one page per week in a [PageView], and a page
/// must render its OWN week even while the neighbouring page is dragged in.
/// Riverpod 3 only re-mounts a provider in a nested `ProviderScope` when that
/// provider declares `$allTransitiveDependencies` (code-generated providers);
/// these hand-written top-level providers are mounted once at the root, so a
/// nested `ProviderScope` override of a seam such as a "selected week" would
/// NOT reach them. Keying the data by the week's Monday key in a family is
/// therefore the isolation mechanism: `weeklySummaryForWeekProvider(aMondayKey)`
/// is a distinct provider state per week.
///
/// The unkeyed [weeklySummaryProvider] is the *current week's* state — the same
/// value the bare [WeeklySummaryView] (and its existing tests/goldens) has
/// always rendered — and is a thin projection over
/// [weeklySummaryForWeekProvider] of [weeklyCurrentMondayKeyProvider].
///
/// The clock and the local offset are injected seams ([weeklyClockProvider] /
/// [weeklyOffsetProvider]) so a widget test pins the week deterministically,
/// including on a machine whose timezone is not Asia/Shanghai. Tests override
/// the three repository ports with the in-memory fakes, so no file database is
/// opened under `flutter test`.
library;

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:caldoo/core/providers/app_providers.dart';
import 'package:caldoo/core/time/date_windows.dart';
import 'package:caldoo/core/time/day_tick_provider.dart';
import 'package:caldoo/domain/models/daily_exercise.dart';
import 'package:caldoo/domain/models/day_rollup.dart';
import 'package:caldoo/domain/models/user_profile.dart';
import 'package:caldoo/domain/models/weight_entry.dart';

import 'weekly_summary.dart';

/// The time seam; production reads the ambient [clock], tests fix it.
final weeklyClockProvider = Provider<Clock>((ref) => clock);

/// The device's current UTC offset as minutes east of Greenwich.
///
/// Re-read on every [dayTickProvider] signal, so a timezone change while the
/// process is alive re-derives the week windows instead of keeping the
/// launch-time offset. The week boundary is the local calendar week and is
/// deliberately not configurable.
final weeklyOffsetProvider = Provider<LocalOffset>((ref) {
  ref.watch(dayTickProvider);
  return LocalOffset(DateTime.now().timeZoneOffset.inMinutes);
});

/// The seven date keys Monday..Sunday of the local week starting on the
/// date-only [mondayKey].
List<DateTime> weekDayKeysForMonday(DateTime mondayKey) =>
    List<DateTime>.generate(
      7,
      (int i) => mondayKey.add(Duration(days: i)),
      growable: false,
    );

/// The half-open instant window `[start, end)` of the local week starting on
/// the date-only [mondayKey].
///
/// `start` is Monday 00:00 local, `end` is the following Monday 00:00 local —
/// seven full days, never a rolling window.
({DateTime start, DateTime end}) weekWindowForMonday(
  DateTime mondayKey,
  LocalOffset offset,
) {
  final DateTime start = mondayKey.subtract(offset.duration);
  return (start: start, end: start.add(const Duration(days: 7)));
}

/// The date-only Monday key of the local week containing "now".
///
/// Re-derived on every [dayTickProvider] signal (app resume, the minute poll),
/// so a warm start that slept across the week boundary follows the calendar
/// instead of freezing on the launch week. The key is a value-equal UTC
/// midnight, so a tick that does not cross a boundary notifies nothing
/// downstream.
final weeklyCurrentMondayKeyProvider = Provider<DateTime>((ref) {
  ref.watch(dayTickProvider);
  return mondayKeyOf(
    ref.watch(weeklyClockProvider).now(),
    ref.watch(weeklyOffsetProvider),
  );
});

/// The meals (with their items) of the local week starting on the date-only
/// [mondayKey], live from the [MealRepository].
final weeklyMealsForWeekProvider =
    StreamProvider.family<List<MealWithItems>, DateTime>((
      ref,
      DateTime mondayKey,
    ) {
      final ({DateTime start, DateTime end}) window = weekWindowForMonday(
        mondayKey,
        ref.watch(weeklyOffsetProvider),
      );
      return ref
          .watch(mealRepositoryProvider)
          .watchMealsForWeek(
            weekStartInclusive: window.start,
            weekEndExclusive: window.end,
          );
    });

/// The exercise-burn entries of the local week starting on the date-only
/// [mondayKey], live from the [DailyExerciseRepository].
///
/// The range is expressed in date-only day keys: the Monday key through the
/// following Monday key.
final weeklyExercisesForWeekProvider =
    StreamProvider.family<List<DailyExercise>, DateTime>((
      ref,
      DateTime mondayKey,
    ) {
      return ref
          .watch(exerciseRepositoryProvider)
          .watchRange(
            startInclusive: mondayKey,
            endExclusive: mondayKey.add(const Duration(days: 7)),
          );
    });

/// The stored profile, live (`null` until one is saved).
final weeklyProfileProvider = StreamProvider<UserProfile?>((ref) {
  return ref.watch(profileRepositoryProvider).watchProfile();
});

/// The body-weight entries of the local week starting on the date-only
/// [mondayKey], live from the [WeightRepository].
///
/// The range is expressed in date-only day keys (Monday through the following
/// Monday), exactly like the exercises; the period's weight-change tile is
/// derived from these by [buildPeriodSummary].
final weeklyWeightsForWeekProvider =
    StreamProvider.family<List<WeightEntry>, DateTime>((
      ref,
      DateTime mondayKey,
    ) {
      return ref
          .watch(weightRepositoryProvider)
          .watchRange(
            startInclusive: mondayKey,
            endExclusive: mondayKey.add(const Duration(days: 7)),
          );
    });

/// The seven rollups Monday..Sunday of the local week starting on the date-only
/// [mondayKey], recomputed from the live streams.
///
/// While a stream is still loading its value is treated as empty so the rollup
/// list is always valid (the UI shows the loading state via
/// [weeklySummaryForWeekProvider]).
final weeklyRollupsForWeekProvider = Provider.family<List<DayRollup>, DateTime>(
  (ref, DateTime mondayKey) {
    final LocalOffset offset = ref.watch(weeklyOffsetProvider);
    final List<MealWithItems> meals =
        ref.watch(weeklyMealsForWeekProvider(mondayKey)).value ??
        const <MealWithItems>[];
    final List<DailyExercise> exercises =
        ref.watch(weeklyExercisesForWeekProvider(mondayKey)).value ??
        const <DailyExercise>[];
    return <DayRollup>[
      for (final DateTime key in weekDayKeysForMonday(mondayKey))
        rollupDay(
          date: key,
          meals: meals,
          exercises: exercises,
          offset: offset,
        ),
    ];
  },
);

/// The weekly dashboard's composed state for the local week starting on the
/// date-only [mondayKey]: rollups + profile.
final weeklySummaryForWeekProvider =
    Provider.family<WeeklySummaryState, DateTime>((ref, DateTime mondayKey) {
      final AsyncValue<UserProfile?> profile = ref.watch(weeklyProfileProvider);
      final AsyncValue<List<MealWithItems>> meals = ref.watch(
        weeklyMealsForWeekProvider(mondayKey),
      );
      final AsyncValue<List<DailyExercise>> exercises = ref.watch(
        weeklyExercisesForWeekProvider(mondayKey),
      );
      final bool stillLoading =
          (profile.isLoading && !profile.hasValue) ||
          (meals.isLoading && !meals.hasValue) ||
          (exercises.isLoading && !exercises.hasValue);
      // An ERRORED stream must not fall through to a zero week (its `.value`
      // is null, so the totals would claim 摄入 0) — stay on the loading state
      // like the daily card does.
      final bool unavailable =
          stillLoading ||
          profile.hasError ||
          meals.hasError ||
          exercises.hasError;
      if (unavailable) {
        return const WeeklySummaryLoading();
      }
      // The weight stream deliberately does NOT gate the loading state: while
      // it loads the summary renders with no weight tile, never a spinner.
      return buildWeeklySummary(
        week: ref.watch(weeklyRollupsForWeekProvider(mondayKey)),
        profile: profile.value,
        today: ref.watch(weeklyClockProvider).now(),
        weightEntries:
            ref.watch(weeklyWeightsForWeekProvider(mondayKey)).value ??
            const <WeightEntry>[],
      );
    });

/// The current week's composed dashboard state.
///
/// The bare [WeeklySummaryView] (and its existing widget tests/goldens) watches
/// this; the history pages watch [weeklySummaryForWeekProvider] with the week
/// they display instead.
final weeklySummaryProvider = Provider<WeeklySummaryState>((ref) {
  return ref.watch(
    weeklySummaryForWeekProvider(ref.watch(weeklyCurrentMondayKeyProvider)),
  );
});
