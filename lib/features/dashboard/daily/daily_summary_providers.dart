/// Riverpod wiring for the daily summary dashboard (task 24 + task 31 history).
///
/// Everything is derived from the repository `watch` streams and recomputed on
/// every emission — the dashboard never shows a stale cached total; the
/// *current-day* pointer itself ([dashboardTodayKeyProvider]) follows
/// [dayTickProvider], so a warm start across local midnight moves to the new
/// day instead of replaying the launch day:
///
/// * [dailyMealsForDayProvider] / [dailyExercisesForDayProvider] are
///   **family** [StreamProvider]s over `watchMealsForDay` / `watchRange` for one
///   explicit local day (the exercise range is expressed in date-only day
///   keys), so any historical day can be rendered from its own live data;
/// * [dailyRollupForDayProvider] folds them with the task-9 `rollupDay`
///   function;
/// * [dailySummaryForDayProvider] feeds that rollup into the task-7 engine
///   (`computeEnergyBudget`) as `intakeKcal` + `exerciseKcal`, so the budget is
///   computed in exactly one place and the exercise add-back is applied there.
///
/// ## Why families instead of a "selected day" override
///
/// The Today tab shows one page per day in a [PageView], and a page must render
/// its OWN day even while the neighbouring page is being dragged in. Riverpod
/// 3 only re-mounts a provider in a nested `ProviderScope` when that provider
/// declares `$allTransitiveDependencies` (code-generated providers); these
/// hand-written top-level providers are mounted once at the root, so a nested
/// `ProviderScope` override of a seam such as a "selected day" would NOT reach
/// them. Keying the data by the day in a family is therefore the isolation
/// mechanism: `dailyMealsForDayProvider(aDayKey)` is a distinct provider state
/// per day.
///
/// The unkeyed [dailySummaryProvider] is the *current day's* state — the same
/// value the bare [DailySummaryView] (and its tests/goldens) has always
/// rendered — and is a thin projection over [dailySummaryForDayProvider] of
/// [dashboardTodayKeyProvider].
///
/// The clock and the local offset are injected seams ([dashboardClockProvider] /
/// [dashboardOffsetProvider]) so a widget test pins the day deterministically,
/// including on a machine whose timezone is not Asia/Shanghai. Tests override
/// the three repository ports with the in-memory fakes, so no file database is
/// opened under `flutter test`.
library;

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:caldoo/core/math/energy_balance.dart';
import 'package:caldoo/core/providers/app_providers.dart';
import 'package:caldoo/core/time/date_windows.dart';
import 'package:caldoo/core/time/day_tick_provider.dart';
import 'package:caldoo/domain/models/daily_exercise.dart';
import 'package:caldoo/domain/models/day_rollup.dart';
import 'package:caldoo/domain/models/user_profile.dart';

import 'daily_summary.dart';

/// The time seam; production reads the ambient [clock], tests fix it.
final dashboardClockProvider = Provider<Clock>((ref) => clock);

/// The device's current UTC offset as minutes east of Greenwich.
///
/// Re-read on every [dayTickProvider] signal, so a timezone change while the
/// process is alive (e.g. travel) re-derives the day windows instead of
/// keeping the launch-time offset. The dashboard's day boundary is the local
/// calendar date and is deliberately not configurable.
final dashboardOffsetProvider = Provider<LocalOffset>((ref) {
  ref.watch(dayTickProvider);
  return LocalOffset(DateTime.now().timeZoneOffset.inMinutes);
});

/// The half-open instant window `[start, end)` of a local day plus its date
/// [key] (used by the rollup).
typedef DashboardDayWindow = ({DateTime start, DateTime end, DateTime key});

/// The instant window of the local day whose date-only key is [dayKey].
///
/// Local midnight is `key - offset` because `dayKeyOf` returns the date at UTC
/// midnight; the same conversion `localDayWindow` (task 22) uses.
DashboardDayWindow dashboardWindowForDay(DateTime dayKey, LocalOffset offset) {
  final DateTime start = dayKey.subtract(offset.duration);
  return (start: start, end: start.add(const Duration(days: 1)), key: dayKey);
}

/// The date-only key of the local day containing "now" (injected clock).
///
/// Re-derived on every [dayTickProvider] signal (app resume, the minute poll),
/// so a warm start that slept across local midnight follows the calendar
/// instead of freezing on the launch day. The key is a value-equal UTC
/// midnight, so a tick that does not cross a day boundary notifies nothing
/// downstream.
final dashboardTodayKeyProvider = Provider<DateTime>((ref) {
  ref.watch(dayTickProvider);
  return currentDayKey(
    clock: ref.watch(dashboardClockProvider),
    offset: ref.watch(dashboardOffsetProvider),
  );
});

/// The meals (with their items) of the local day [dayKey], live from the
/// [MealRepository].
final dailyMealsForDayProvider =
    StreamProvider.family<List<MealWithItems>, DateTime>((
      ref,
      DateTime dayKey,
    ) {
      final DashboardDayWindow window = dashboardWindowForDay(
        dayKey,
        ref.watch(dashboardOffsetProvider),
      );
      return ref
          .watch(mealRepositoryProvider)
          .watchMealsForDay(
            dayStartInclusive: window.start,
            dayEndExclusive: window.end,
          );
    });

/// The exercise-burn entries of the local day [dayKey], live from the
/// [DailyExerciseRepository].
///
/// The range is expressed in date-only day keys: `[dayKey, dayKey + 1d)`.
final dailyExercisesForDayProvider =
    StreamProvider.family<List<DailyExercise>, DateTime>((
      ref,
      DateTime dayKey,
    ) {
      return ref
          .watch(exerciseRepositoryProvider)
          .watchRange(
            startInclusive: dayKey,
            endExclusive: dayKey.add(const Duration(days: 1)),
          );
    });

/// The stored profile, live (`null` until one is saved).
final dailyProfileProvider = StreamProvider<UserProfile?>((ref) {
  return ref.watch(profileRepositoryProvider).watchProfile();
});

/// The rollup of the local day [dayKey], recomputed from the live streams.
///
/// While a stream is still loading its value is treated as empty so the rollup
/// is always a valid [DayRollup] (the UI shows the loading state via
/// [dailySummaryForDayProvider]).
final dailyRollupForDayProvider = Provider.family<DayRollup, DateTime>((
  ref,
  DateTime dayKey,
) {
  final List<MealWithItems> meals =
      ref.watch(dailyMealsForDayProvider(dayKey)).value ??
      const <MealWithItems>[];
  final List<DailyExercise> exercises =
      ref.watch(dailyExercisesForDayProvider(dayKey)).value ??
      const <DailyExercise>[];
  return rollupDay(
    date: dayKey,
    meals: meals,
    exercises: exercises,
    offset: ref.watch(dashboardOffsetProvider),
  );
});

/// The dashboard's composed state for the local day [dayKey]: rollup + engine
/// budget.
///
/// The budget/balance come ONLY from `computeEnergyBudget`, so the formula
/// lives in the task-7 engine and nowhere else. A `ProfileIncomplete` result
/// becomes [DailySummaryNoProfile] — the widget then hides the budget and the
/// signed balance instead of showing a deficit against a missing budget.
final dailySummaryForDayProvider = Provider.family<DailySummaryState, DateTime>(
  (ref, DateTime dayKey) {
    final AsyncValue<UserProfile?> profile = ref.watch(dailyProfileProvider);
    final AsyncValue<List<MealWithItems>> meals = ref.watch(
      dailyMealsForDayProvider(dayKey),
    );
    final AsyncValue<List<DailyExercise>> exercises = ref.watch(
      dailyExercisesForDayProvider(dayKey),
    );
    final bool stillLoading =
        (profile.isLoading && !profile.hasValue) ||
        (meals.isLoading && !meals.hasValue) ||
        (exercises.isLoading && !exercises.hasValue);
    if (stillLoading) {
      return const DailySummaryLoading();
    }

    final DayRollup rollup = ref.watch(dailyRollupForDayProvider(dayKey));
    final EnergyBudgetResult result = computeEnergyBudget(
      profile: profile.value,
      intakeKcal: rollup.intakeKcal,
      exerciseKcal: rollup.exerciseKcal,
      today: ref.watch(dashboardClockProvider).now(),
    );
    return switch (result) {
      ProfileIncomplete() => DailySummaryNoProfile(rollup),
      final EnergyBudget budget => DailySummaryReady(
        rollup: rollup,
        budget: budget,
      ),
    };
  },
);

/// The current day's composed dashboard state.
///
/// The bare [DailySummaryView] (and its existing widget tests/goldens) watches
/// this; the history pages watch [dailySummaryForDayProvider] with the day they
/// display instead.
final dailySummaryProvider = Provider<DailySummaryState>((ref) {
  return ref.watch(
    dailySummaryForDayProvider(ref.watch(dashboardTodayKeyProvider)),
  );
});
