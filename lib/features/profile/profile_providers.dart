/// Riverpod wiring for the profile & settings feature (task 23).
///
/// Widgets never touch Drift or a repository implementation directly: they
/// watch [storedProfileProvider] / [profileBudgetProvider], which project the
/// `ProfileRepository` port from `core/providers/app_providers.dart`. Tests
/// override that port with the in-memory fake, so no database is opened under
/// `flutter test`.
///
/// The daily budget is computed ONLY by the energy engine
/// (`computeEnergyBudget`): the exercise-free baseline is the resolved basal
/// metabolic rate — the user's [UserProfile.bmrKcalOverride] when set, otherwise
/// the Mifflin-St Jeor estimate from sex/birthday/height/weight (the age is
/// derived on the injected clock's today). There is no
/// activity multiplier.
library;

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:caldoo/core/math/energy_balance.dart';
import 'package:caldoo/core/providers/app_providers.dart';
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
/// it consumes is [resolveBmrKcal]: the profile's own BMR override, or the
/// Mifflin-St Jeor estimate when no override is stored.
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
