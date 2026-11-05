/// Riverpod wiring for the per-meal summary (task 22).
///
/// The running 今日累计 is derived from the [MealRepository]'s `watch` stream,
/// never from a cached read: [todayTotalsProvider] watches
/// [todayMealsProvider], which is a [StreamProvider] over
/// [MealRepository.watchMealsForDay]. Saving through [mealSaveControllerProvider]
/// makes the fake/Drift change stream emit and the totals recompute.
///
/// The clock and the local offset are injected (like task 9's rollups) so a
/// test pins a day deterministically; production reads the device time.
library;

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:caldoo/core/providers/app_providers.dart';
import 'package:caldoo/core/time/date_windows.dart';
import 'package:caldoo/core/time/day_tick_provider.dart';

import 'day_window.dart';
import 'meal_save_controller.dart';
import 'meal_totals.dart';

/// The time seam; production reads the ambient [clock], tests fix it.
final summaryClockProvider = Provider<Clock>((ref) => clock);

/// The device's current UTC offset as minutes east of Greenwich.
///
/// Re-read on every [dayTickProvider] signal, so a timezone change while the
/// process is alive re-derives the day windows instead of keeping the
/// launch-time offset. The app's day boundaries are deliberately fixed to the
/// local calendar date and are not configurable.
final localOffsetProvider = Provider<LocalOffset>((ref) {
  ref.watch(dayTickProvider);
  return LocalOffset(DateTime.now().timeZoneOffset.inMinutes);
});

/// `[start, end)` instants of the local day containing "now".
///
/// Re-derived on every [dayTickProvider] signal (app resume, the minute poll),
/// so the running 今日累计 follows the calendar across a warm start instead of
/// totting up the launch day forever. The window's key is a value-equal UTC
/// midnight, so a tick that does not cross a day boundary notifies nothing
/// downstream.
final todayWindowProvider = Provider<LocalDayWindow>((ref) {
  ref.watch(dayTickProvider);
  final LocalDayWindow window = localDayWindow(
    ref.watch(summaryClockProvider).now(),
    ref.watch(localOffsetProvider),
  );
  return window;
});

/// Today's meals **with their items**, live from the repository.
final todayMealsProvider = StreamProvider<List<MealWithItems>>((ref) {
  final LocalDayWindow window = ref.watch(todayWindowProvider);
  return ref
      .watch(mealRepositoryProvider)
      .watchMealsForDay(
        dayStartInclusive: window.start,
        dayEndExclusive: window.end,
      );
});

/// The running 今日累计 intake, recomputed on every repository emission.
///
/// An empty (or still-loading) stream yields [MealTotals.zero] rather than an
/// error, so the card always renders a number.
final todayTotalsProvider = Provider<MealTotals>((ref) {
  final List<MealWithItems> meals =
      ref.watch(todayMealsProvider).value ?? const <MealWithItems>[];
  return MealTotals.fromMeals(meals);
});

/// The meals **with their items** of the local day [dayKey], live from the
/// repository — the day-scoped twin of [todayMealsProvider], so a PAST day's
/// detail card can show that day's own running total.
final _dayMealsForDayProvider =
    StreamProvider.family<List<MealWithItems>, DateTime>((
      ref,
      DateTime dayKey,
    ) {
      final DateTime start = dayKey.subtract(
        ref.watch(localOffsetProvider).duration,
      );
      return ref
          .watch(mealRepositoryProvider)
          .watchMealsForDay(
            dayStartInclusive: start,
            dayEndExclusive: start.add(const Duration(days: 1)),
          );
    });

/// The running intake of the local day [dayKey] — the meal detail card's
/// 累计 line for a meal's OWN day (a past-day meal opened from history must
/// not show the wall-clock day's totals next to it).
///
/// Live like [todayTotalsProvider]; an empty (or still-loading) stream yields
/// [MealTotals.zero] rather than an error, so the card always renders a
/// number.
final dayTotalsForDayProvider = Provider.family<MealTotals, DateTime>((
  ref,
  DateTime dayKey,
) {
  final List<MealWithItems> meals =
      ref.watch(_dayMealsForDayProvider(dayKey)).value ??
      const <MealWithItems>[];
  return MealTotals.fromMeals(meals);
});

/// The validated save path used by the summary screen.
final mealSaveControllerProvider = Provider<MealSaveController>(
  (ref) => MealSaveController(ref.watch(mealRepositoryProvider)),
);
