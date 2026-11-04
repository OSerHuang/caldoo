/// Riverpod wiring for the profile & settings feature (task 23).
///
/// Widgets never touch Drift or a repository implementation directly: they
/// watch [storedProfileProvider] / [profileBudgetProvider], which project the
/// `ProfileRepository` port from `core/providers/app_providers.dart`. Tests
/// override that port with the in-memory fake, so no database is opened under
/// `flutter test`.
///
/// The daily budget is computed ONLY by the energy engine
/// (`computeEnergyBudget`): the exercise-free baseline is the user's daily goal
/// when one is set, otherwise the resolved basal metabolic rate — the
/// profile's [UserProfile.bmrKcalOverride] when set, otherwise the
/// Mifflin-St Jeor estimate from sex/birthday/height/weight (the age is derived
/// on the injected clock's today). The goal is either a [DailyGoalPreset] (BMR
/// + delta, re-derived on every read, so it follows the body weight) or a fixed
/// [UserProfile.dailyKcalGoalOverride] (the number the user typed). There is no
/// activity multiplier and no hidden factor.
library;

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:caldoo/core/math/energy_balance.dart';
import 'package:caldoo/core/providers/app_providers.dart';
import 'package:caldoo/core/time/day_tick_provider.dart';
import 'package:caldoo/core/time/date_windows.dart';
import 'package:caldoo/domain/models/daily_exercise.dart';
import 'package:caldoo/domain/models/user_profile.dart';

/// The time seam for the profile feature; production reads the ambient
/// [clock], tests fix it so the derived age (and therefore the BMR estimate)
/// is deterministic.
final profileClockProvider = Provider<Clock>((ref) => clock);

/// The stored profile, live (`null` until one is saved).
///
/// An absent profile is a first-class state (the screen shows the
/// "完善资料" prompt) — never an error and never a crash.
final storedProfileProvider = StreamProvider<UserProfile?>((ref) {
  return ref.watch(profileRepositoryProvider).watchProfile();
});

/// The exercise-free daily budget from the energy engine.
///
/// `computeEnergyBudget` is the ONLY place the budget is computed. The baseline
/// it consumes is the stored daily goal when one is set, else
/// [resolveBmrKcal]: the profile's own BMR override, or the Mifflin-St Jeor
/// estimate when no override is stored. A [DailyGoalPreset] is re-derived from
/// the current BMR (so a weight change moves the budget), while a fixed
/// [UserProfile.dailyKcalGoalOverride] is used verbatim.
///
/// Returns:
/// * `null` while the profile stream is still loading — the UI shows a
///   spinner, never a guessed number;
/// * [ProfileIncomplete] when no profile is stored — the screen hides the
///   budget and shows "完善资料以计算每日额度";
/// * an [EnergyBudget] once a complete profile exists.
final profileBudgetProvider = Provider<EnergyBudgetResult?>((ref) {
  final AsyncValue<UserProfile?> profile = ref.watch(storedProfileProvider);
  if (profile.isLoading && !profile.hasValue) {
    return null;
  }
  return computeEnergyBudget(
    profile: profile.value,
    intakeKcal: 0,
    today: ref.watch(profileClockProvider).now(),
  );
});

/// Today's logged exercise burn, for the goal sheet's preview equation.
///
/// A live read over the exercise port for today's date-only key (the ambient
/// local offset, like every day window), re-derived on [dayTickProvider] so a
/// sheet open across midnight reports the new day. The one-shot `Future` read
/// it replaces completed once per process — Riverpod keeps a manual provider's
/// value forever — so after the first open the preview never moved again: a
/// burn logged later the same day, and yesterday's burn after rollover, both
/// stuck on screen despite the "reopening re-reads" promise.
final goalSheetExerciseKcalProvider = StreamProvider<int>((ref) {
  final Clock clock = ref.watch(profileClockProvider);
  ref.watch(dayTickProvider);
  final DateTime now = clock.now();
  final LocalOffset offset = LocalOffset(now.timeZoneOffset.inMinutes);
  final DateTime dayKey = currentDayKey(clock: clock, offset: offset);
  return ref
      .watch(exerciseRepositoryProvider)
      .watchRange(
        startInclusive: dayKey,
        endExclusive: dayKey.add(const Duration(days: 1)),
      )
      .map(
        (List<DailyExercise> rows) =>
            rows.fold<int>(0, (int sum, DailyExercise e) => sum + e.kcal),
      );
});
