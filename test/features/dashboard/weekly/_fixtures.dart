/// Shared fixtures for the task-26 weekly summary dashboard tests.
///
/// A **fixed** Mon..Sun week built from the task-7 profile (male, 175cm, 70kg
/// with a pinned BMR override of **1979** kcal — the old sedentary baseline
/// 1978.5 rounded to whole kcal, now a user-set BMR; exercise excluded).
///
/// The week is pinned to 2026-01-05 (a Monday) 12:00 +08:00 so `rollupWeek`
/// produces a deterministic Monday..Sunday sequence:
///
/// | day | intake | Na mg | exercise | logged? | Na OK? |
/// |-----|--------|-------|----------|---------|--------|
/// | Mon |  2000  | 1600  |    -     |   yes   |  yes   |
/// | Tue |  1500  | 2400  |    -     |   yes   |  no    |
/// | Wed |  2200  | 1200  |   257    |   yes   |  yes   |
/// | Thu |  1800  | 2000  |    -     |   yes   |  yes   |
/// | Fri |  2500  | 2000  |    -     |   yes   |  yes   |
/// | Sat |    0   |   0   |   300    |   NO    |   -    |
/// | Sun |    0   |   0   |    -     |   no    |   -    |
///
/// Hand-computed cumulative metrics:
/// * logged days = **5** (Sat is exercise-only, so NOT a logged day);
/// * total intake = `2000+1500+2200+1800+2500` = **10000**;
/// * total burn = `5*1979 + 257` = **10152** (Wed's exercise is added
///   to that day's budget; Sat's 300 exercise is excluded because Sat is not a
///   logged day);
/// * difference = `10000 - 10152` = **-152** (缺口);
/// * salt adherence = **4 / 5** (Thu and Fri are exactly on the 2000 mg
///   boundary and count as adherent).
library;

import 'package:clock/clock.dart';

import 'package:caldoo/core/time/date_windows.dart';
import 'package:caldoo/domain/models/models.dart';

import '../../../data/repositories/fake_repositories.dart';

/// The task-7 profile: male 175cm 70kg, born 1995-10-22 (age 30 on
/// [weeklyNow]), with a pinned BMR of 1979 kcal (1978.5 rounded).
final UserProfile weeklyProfile = UserProfile(
  sex: Sex.male,
  birthDate: DateTime.utc(1995, 10, 22),
  heightCm: 175,
  weightKg: 70,
  bmrKcalOverride: 1979,
);

/// 2026-01-05 12:00 +08:00 (a Monday), used as the injected "now".
final DateTime weeklyNow = DateTime.utc(2026, 1, 5, 4);

/// A fixed +08:00 (Asia/Shanghai) offset for a deterministic week window.
const LocalOffset weeklyOffset = LocalOffset(480);

/// A clock pinned to [weeklyNow].
Clock weeklyClock() => Clock.fixed(weeklyNow);

/// Local noon of day [dayIndex] (0 = Monday of the fixture week), as a UTC
/// instant.
DateTime weeklyDayInstant(int dayIndex) =>
    DateTime.utc(2026, 1, 5 + dayIndex, 4);

/// The date-only day key of day [dayIndex] at the +08:00 fixture offset.
DateTime weeklyDayKey(int dayIndex) => DateTime.utc(2026, 1, 5 + dayIndex);

MealWithItems _meal({
  required String id,
  required int dayIndex,
  required int kcal,
  required double saltG,
}) => (
  meal: Meal(
    id: id,
    timestamp: weeklyDayInstant(dayIndex),
    mealType: MealType.lunch,
  ),
  items: <MealItem>[
    MealItem(
      id: '$id-item',
      name: '食物-$id',
      grams: 100,
      kcal: kcal,
      carbG: 0,
      proteinG: 0,
      fatG: 0,
      saltG: saltG,
      source: FoodSource.manual,
    ),
  ],
);

/// The five logged meals (Mon..Fri). Salt grams -> sodium mg: 4 g = 1600 mg,
/// 6 g = 2400 mg, 3 g = 1200 mg, 5 g = 2000 mg.
List<MealWithItems> weeklyMeals() => <MealWithItems>[
  _meal(id: 'mon', dayIndex: 0, kcal: 2000, saltG: 4),
  _meal(id: 'tue', dayIndex: 1, kcal: 1500, saltG: 6),
  _meal(id: 'wed', dayIndex: 2, kcal: 2200, saltG: 3),
  _meal(id: 'thu', dayIndex: 3, kcal: 1800, saltG: 5),
  _meal(id: 'fri', dayIndex: 4, kcal: 2500, saltG: 5),
];

/// Wed exercise (257 kcal) on a LOGGED day, plus Sat exercise-only (300 kcal)
/// on a day with no meal (which must therefore not count as logged).
List<DailyExercise> weeklyExercises() => <DailyExercise>[
  DailyExercise(dayKey: weeklyDayKey(2), kcal: 257),
  DailyExercise(dayKey: weeklyDayKey(5), kcal: 300),
];

/// Persists a profile + the given [mealGroups] + [exerciseEntries].
///
/// Pass `withProfile: false` for the incomplete-profile case.
Future<void> seedWeekly({
  required FakeMealRepository meals,
  required FakeExerciseRepository exercises,
  required FakeProfileRepository profile,
  List<MealWithItems> mealGroups = const <MealWithItems>[],
  List<DailyExercise> exerciseEntries = const <DailyExercise>[],
  bool withProfile = true,
}) async {
  if (withProfile) {
    await profile.saveProfile(weeklyProfile);
  }
  for (final MealWithItems group in mealGroups) {
    await meals.saveMealWithItems(group.meal, group.items);
  }
  for (final DailyExercise entry in exerciseEntries) {
    await exercises.setKcal(dayKey: entry.dayKey, kcal: entry.kcal);
  }
}
