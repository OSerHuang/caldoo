/// Shared fixtures for the task-24 daily summary dashboard tests.
///
/// Built from the task-7 worked vector: male, 175cm, 70kg with a pinned
/// BMR override of **1979** kcal (the old sedentary baseline 1978.5 rounded to
/// whole kcal, now a user-set BMR), so the engine yields
/// `baseBudget 1979 + exercise 257 = 2236`.
///
/// Meal A + Meal B sum to **1936** kcal (intake < budget -> 缺口 300);
/// Meal A + Meal C sum to **2536** kcal (intake > budget -> 盈余 300).
/// Every energy value is a whole-kcal `int`; the old fractional literals were
/// rounded once, half away from zero (1000.5 -> 1001, 935.25 -> 935,
/// 1978.5 -> 1979, 257.25 -> 257).
library;

import 'package:clock/clock.dart';

import 'package:caldoo/core/time/date_windows.dart';
import 'package:caldoo/domain/models/models.dart';

import '../../../data/repositories/fake_repositories.dart';

/// The task-7 profile: male 175cm 70kg, born 1995-10-22 (age 30 on
/// [dashboardNow]), with a pinned BMR of 1979 kcal (1978.5 rounded).
final UserProfile dashboardProfile = UserProfile(
  sex: Sex.male,
  birthDate: DateTime.utc(1995, 10, 22),
  heightCm: 175,
  weightKg: 70,
  bmrKcalOverride: 1979,
);

/// 2026-01-05 12:00 +08:00, used as the injected "now".
final DateTime dashboardNow = DateTime.utc(2026, 1, 5, 4);

/// A fixed +08:00 (Asia/Shanghai) offset for a deterministic day window.
const LocalOffset dashboardOffset = LocalOffset(480);

/// A clock pinned to [dashboardNow].
Clock dashboardClock() => Clock.fixed(dashboardNow);

MealItem _item({
  required String id,
  required int kcal,
  required double carbG,
  required double proteinG,
  required double fatG,
  required double saltG,
}) => MealItem(
  id: id,
  name: '食物-$id',
  grams: 100,
  kcal: kcal,
  carbG: carbG,
  proteinG: proteinG,
  fatG: fatG,
  saltG: saltG,
  source: FoodSource.manual,
);

Meal _meal({required String id, MealType mealType = MealType.lunch}) =>
    Meal(id: id, timestamp: dashboardNow, mealType: mealType);

/// Meal A: 1001 kcal / carb 100 / protein 50 / fat 30 / salt 2.0 g.
MealWithItems dashboardMealA() => (
  meal: _meal(id: 'meal-a'),
  items: <MealItem>[
    _item(
      id: 'item-a',
      kcal: 1001,
      carbG: 100,
      proteinG: 50,
      fatG: 30,
      saltG: 2.0,
    ),
  ],
);

/// Meal B: 935 kcal / carb 80 / protein 40 / fat 25 / salt 1.5 g.
MealWithItems dashboardMealB() => (
  meal: _meal(id: 'meal-b', mealType: MealType.dinner),
  items: <MealItem>[
    _item(
      id: 'item-b',
      kcal: 935,
      carbG: 80,
      proteinG: 40,
      fatG: 25,
      saltG: 1.5,
    ),
  ],
);

/// Meal C: 1535 kcal / carb 120 / protein 60 / fat 35 / salt 2.5 g.
MealWithItems dashboardMealC() => (
  meal: _meal(id: 'meal-c', mealType: MealType.dinner),
  items: <MealItem>[
    _item(
      id: 'item-c',
      kcal: 1535,
      carbG: 120,
      proteinG: 60,
      fatG: 35,
      saltG: 2.5,
    ),
  ],
);

/// Task-7 deficit fixture: A + B = **1936** kcal.
List<MealWithItems> dashboardDeficitMeals() => <MealWithItems>[
  dashboardMealA(),
  dashboardMealB(),
];

/// Surplus fixture: A + C = **2536** kcal.
List<MealWithItems> dashboardSurplusMeals() => <MealWithItems>[
  dashboardMealA(),
  dashboardMealC(),
];

/// The date-only day key of [dashboardNow] at [dashboardOffset] (2026-01-05).
final DateTime dashboardDayKey = DateTime.utc(2026, 1, 5);

/// The task-7 exercise: **257** kcal on [dashboardDayKey] (257.25 rounded).
DailyExercise dashboardExercise({int kcal = 257}) =>
    DailyExercise(dayKey: dashboardDayKey, kcal: kcal);

/// Persists a profile + the given [mealGroups] + (optionally) the exercise.
///
/// Pass `withProfile: false` to leave the profile absent for the
/// incomplete-profile case.
Future<void> seedDashboard({
  required FakeMealRepository meals,
  required FakeExerciseRepository exercises,
  required FakeProfileRepository profile,
  List<MealWithItems> mealGroups = const <MealWithItems>[],
  bool withExercise = false,
  bool withProfile = true,
}) async {
  if (withProfile) {
    await profile.saveProfile(dashboardProfile);
  }
  for (final MealWithItems group in mealGroups) {
    await meals.saveMealWithItems(group.meal, group.items);
  }
  if (withExercise) {
    final DailyExercise exercise = dashboardExercise();
    await exercises.setKcal(dayKey: exercise.dayKey, kcal: exercise.kcal);
  }
}
