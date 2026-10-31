/// Riverpod wiring for the monthly summary dashboard.
///
/// The month is the new zoom level of the merged 概览 dashboard (a week and a
/// month share the period-neutral value layer), so this file mirrors
/// `weekly_summary_providers.dart` exactly:
///
/// * [monthlyMealsForMonthProvider] / [monthlyExercisesForMonthProvider] are
///   **family** [StreamProvider]s over `watchMealsInRange` / `watchRange` for
///   one explicit **fixed** local calendar month (the exercise range is
///   expressed in date-only day keys), so any historical month can be rendered
///   from its own live data;
/// * [monthlyRollupsForMonthProvider] folds them with the task-9 `rollupDay`
///   function, one call per day key of the month, producing 28..31
///   `DayRollup`s in calendar order (never a rolling 30-day window — February
///   is 28 or 29 days);
/// * [monthlySummaryForMonthProvider] turns that rollup list plus the profile
///   into a [PeriodSummaryState] via [buildPeriodSummary] — so the metric
///   definitions live in one pure function shared with the week.
///
/// ## Why families instead of a "selected month" override
///
/// The month view shows one page per month in a [PageView], and a page must
/// render its OWN month even while the neighbouring page is dragged in.
/// Riverpod 3 only re-mounts a provider in a nested `ProviderScope` when that
/// provider declares `$allTransitiveDependencies` (code-generated providers);
/// these hand-written top-level providers are mounted once at the root, so a
/// nested `ProviderScope` override of a seam such as a "selected month" would
/// NOT reach them. Keying the data by the month's first-day key in a family is
/// therefore the isolation mechanism: `monthlySummaryForMonthProvider(aMonthKey)`
/// is a distinct provider state per month.
///
/// The unkeyed [monthlySummaryProvider] is the *current month's* state and is a
/// thin projection over [monthlySummaryForMonthProvider] of
/// [monthlyCurrentMonthKeyProvider].
///
/// The clock and the local offset are injected seams ([monthlyClockProvider] /
/// [monthlyOffsetProvider]) so a widget test pins the month deterministically,
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
import 'package:caldoo/features/dashboard/period/period_summary.dart';

/// The time seam; production reads the ambient [clock], tests fix it.
final monthlyClockProvider = Provider<Clock>((ref) => clock);

/// The device's current UTC offset as minutes east of Greenwich.
///
/// Re-read on every [dayTickProvider] signal, so a timezone change while the
/// process is alive re-derives the month windows instead of keeping the
/// launch-time offset. The month boundary is the local calendar month and is
/// deliberately not configurable.
final monthlyOffsetProvider = Provider<LocalOffset>((ref) {
  ref.watch(dayTickProvider);
  return LocalOffset(DateTime.now().timeZoneOffset.inMinutes);
});

/// The half-open instant window `[start, end)` of the local calendar month
/// starting on the date-only [monthKey].
///
/// `start` is the month's first day 00:00 local, `end` is the first day of the
/// following month 00:00 local — the whole month, 28..31 full days, never a
/// rolling window. A mid-month [monthKey] is normalised through
/// [monthFirstDayKey], so every key of the month yields the same window.
({DateTime start, DateTime end}) monthWindowFor(
  DateTime monthKey,
  LocalOffset offset,
) {
  final DateTime firstDay = monthFirstDayKey(monthKey);
  final DateTime start = firstDay.subtract(offset.duration);
  return (
    start: start,
    end: monthKeyAfter(firstDay, 1).subtract(offset.duration),
  );
}

/// The date-only first-day key of the local calendar month containing "now".
///
/// Re-derived on every [dayTickProvider] signal (app resume, the minute poll),
/// so a warm start that slept across the month boundary follows the calendar
/// instead of freezing on the launch month. The key is a value-equal UTC
/// midnight, so a tick that does not cross a boundary notifies nothing
/// downstream.
final monthlyCurrentMonthKeyProvider = Provider<DateTime>((ref) {
  ref.watch(dayTickProvider);
  return monthKeyOf(
    ref.watch(monthlyClockProvider).now(),
    ref.watch(monthlyOffsetProvider),
  );
});

/// The meals (with their items) of the local month starting on the date-only
/// [monthKey], live from the [MealRepository].
final monthlyMealsForMonthProvider =
    StreamProvider.family<List<MealWithItems>, DateTime>((
      ref,
      DateTime monthKey,
    ) {
      final ({DateTime start, DateTime end}) window = monthWindowFor(
        monthKey,
        ref.watch(monthlyOffsetProvider),
      );
      return ref
          .watch(mealRepositoryProvider)
          .watchMealsInRange(
            startInclusive: window.start,
            endExclusive: window.end,
          );
    });

/// The exercise-burn entries of the local month starting on the date-only
/// [monthKey], live from the [DailyExerciseRepository].
///
/// The range is expressed in date-only day keys: the month's first-day key
/// through the following month's first-day key.
final monthlyExercisesForMonthProvider =
    StreamProvider.family<List<DailyExercise>, DateTime>((
      ref,
      DateTime monthKey,
    ) {
      final DateTime firstDay = monthFirstDayKey(monthKey);
      return ref
          .watch(exerciseRepositoryProvider)
          .watchRange(
            startInclusive: firstDay,
            endExclusive: monthKeyAfter(firstDay, 1),
          );
    });

/// The stored profile, live (`null` until one is saved).
final monthlyProfileProvider = StreamProvider<UserProfile?>((ref) {
  return ref.watch(profileRepositoryProvider).watchProfile();
});

/// The 28..31 rollups of the local month starting on the date-only [monthKey],
/// in calendar order, recomputed from the live streams.
///
/// While a stream is still loading its value is treated as empty so the rollup
/// list is always valid (the UI shows the loading state via
/// [monthlySummaryForMonthProvider]).
final monthlyRollupsForMonthProvider =
    Provider.family<List<DayRollup>, DateTime>((ref, DateTime monthKey) {
      final LocalOffset offset = ref.watch(monthlyOffsetProvider);
      final List<MealWithItems> meals =
          ref.watch(monthlyMealsForMonthProvider(monthKey)).value ??
          const <MealWithItems>[];
      final List<DailyExercise> exercises =
          ref.watch(monthlyExercisesForMonthProvider(monthKey)).value ??
          const <DailyExercise>[];
      return <DayRollup>[
        for (final DateTime key in monthDayKeysFor(monthKey))
          rollupDay(
            date: key,
            meals: meals,
            exercises: exercises,
            offset: offset,
          ),
      ];
    });

/// The monthly dashboard's composed state for the local month starting on the
/// date-only [monthKey]: rollups + profile.
final monthlySummaryForMonthProvider =
    Provider.family<PeriodSummaryState, DateTime>((ref, DateTime monthKey) {
      final AsyncValue<UserProfile?> profile = ref.watch(
        monthlyProfileProvider,
      );
      final AsyncValue<List<MealWithItems>> meals = ref.watch(
        monthlyMealsForMonthProvider(monthKey),
      );
      final AsyncValue<List<DailyExercise>> exercises = ref.watch(
        monthlyExercisesForMonthProvider(monthKey),
      );
      final bool stillLoading =
          (profile.isLoading && !profile.hasValue) ||
          (meals.isLoading && !meals.hasValue) ||
          (exercises.isLoading && !exercises.hasValue);
      if (stillLoading) {
        return const PeriodSummaryLoading();
      }
      return buildPeriodSummary(
        days: ref.watch(monthlyRollupsForMonthProvider(monthKey)),
        profile: profile.value,
        today: ref.watch(monthlyClockProvider).now(),
      );
    });

/// The current month's composed dashboard state.
final monthlySummaryProvider = Provider<PeriodSummaryState>((ref) {
  return ref.watch(
    monthlySummaryForMonthProvider(ref.watch(monthlyCurrentMonthKeyProvider)),
  );
});
