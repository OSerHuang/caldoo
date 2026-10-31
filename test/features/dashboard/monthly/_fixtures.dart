/// Shared fixtures for the monthly summary dashboard tests.
///
/// A **fixed** calendar month (2026-01, 31 days) built from the same task-7
/// profile the weekly fixtures use (male, 175cm, 70kg with a pinned BMR
/// override of **1979** kcal — the old sedentary baseline 1978.5 rounded to
/// whole kcal; exercise excluded).
///
/// "Now" is pinned to 2026-01-20 12:00 +08:00 so the month is mid-flight, like
/// a real user's month, and every rollup is deterministic on any machine
/// timezone.
///
/// | day | intake | Na mg | exercise | logged? | Na OK? |
/// |-----|--------|-------|----------|---------|--------|
/// |  1  |  2000  | 1600  |    -     |   yes   |  yes   |
/// |  2  |  1500  | 2400  |    -     |   yes   |  no    |
/// |  3  |  2200  | 1200  |   257    |   yes   |  yes   |
/// |  5  |  1800  | 2000  |    -     |   yes   |  yes   |
/// | 10  |    0   |   0   |   300    |   NO    |   -    |
/// | 20  |  2500  | 2000  |    -     |   yes   |  yes   |
///
/// Hand-computed cumulative metrics (identical to the weekly fixture, so the two
/// dashboards' shared metric rules can be compared number for number):
/// * logged days = **5** (day 10 is exercise-only, so NOT a logged day);
/// * total intake = `2000+1500+2200+1800+2500` = **10000**;
/// * total burn = `5*1979 + 257` = **10152** (day 3's exercise is added to that
///   day's budget; day 10's 300 exercise is excluded because day 10 is not a
///   logged day);
/// * difference = `10000 - 10152` = **-152** (缺口);
/// * salt adherence = **4 / 5** (day 5 and day 20 are exactly on the 2000 mg
///   boundary and count as adherent).
library;

import 'package:clock/clock.dart';

import 'package:caldoo/core/time/date_windows.dart';
import 'package:caldoo/domain/models/models.dart';

import '../../../data/repositories/fake_repositories.dart';

/// The task-7 profile: male 175cm 70kg, born 1995-10-22, with a pinned BMR of
/// 1979 kcal (1978.5 rounded).
final UserProfile monthlyProfile = UserProfile(
  sex: Sex.male,
  birthDate: DateTime.utc(1995, 10, 22),
  heightCm: 175,
  weightKg: 70,
  bmrKcalOverride: 1979,
);

/// 2026-01-20 12:00 +08:00, used as the injected "now".
final DateTime monthlyNow = DateTime.utc(2026, 1, 20, 4);

/// The date-only key of the fixture month's first day (2026-01-01).
final DateTime monthlyKey = DateTime.utc(2026, 1, 1);

/// A fixed +08:00 (Asia/Shanghai) offset for a deterministic month window.
const LocalOffset monthlyOffset = LocalOffset(480);

/// A clock pinned to [monthlyNow].
Clock monthlyClock() => Clock.fixed(monthlyNow);

/// Local noon of day [day] (1-based day of month) in the fixture month, as a
/// UTC instant.
DateTime monthlyDayInstant(int day) => DateTime.utc(2026, 1, day, 4);

/// The date-only day key of day [day] (1-based) at the +08:00 fixture offset.
DateTime monthlyDayKey(int day) => DateTime.utc(2026, 1, day);

MealWithItems _meal({
  required String id,
  required int day,
  required int kcal,
  required double saltG,
}) => (
  meal: Meal(
    id: id,
    timestamp: monthlyDayInstant(day),
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

/// The five logged meals (days 1, 2, 3, 5 and 20). Salt grams -> sodium mg:
/// 4 g = 1600 mg, 6 g = 2400 mg, 3 g = 1200 mg, 5 g = 2000 mg.
List<MealWithItems> monthlyMeals() => <MealWithItems>[
  _meal(id: 'd01', day: 1, kcal: 2000, saltG: 4),
  _meal(id: 'd02', day: 2, kcal: 1500, saltG: 6),
  _meal(id: 'd03', day: 3, kcal: 2200, saltG: 3),
  _meal(id: 'd05', day: 5, kcal: 1800, saltG: 5),
  _meal(id: 'd20', day: 20, kcal: 2500, saltG: 5),
];

/// Day 3 exercise (257 kcal) on a LOGGED day, plus day 10 exercise-only
/// (300 kcal) on a day with no meal (which must therefore not count as logged).
List<DailyExercise> monthlyExercises() => <DailyExercise>[
  DailyExercise(dayKey: monthlyDayKey(3), kcal: 257),
  DailyExercise(dayKey: monthlyDayKey(10), kcal: 300),
];

/// Four meals in the month BEFORE the fixture month (2025-12-28 .. 12-31), each
/// 1000 kcal and 6 g salt (2400 mg Na — over the 2000 mg ceiling, so 0
/// adherent): **4000** kcal over **4** logged days. Used by the month history
/// pager test, which needs a past month with different, distinguishable totals.
List<MealWithItems> previousMonthMeals() => <MealWithItems>[
  for (var i = 0; i < 4; i++)
    (
      meal: Meal(
        id: 'prev-m$i',
        timestamp: DateTime.utc(2025, 12, 28 + i, 4),
        mealType: MealType.lunch,
      ),
      items: <MealItem>[
        MealItem(
          id: 'prev-m$i-item',
          name: '食物-prev-$i',
          grams: 100,
          kcal: 1000,
          carbG: 0,
          proteinG: 0,
          fatG: 0,
          saltG: 6,
          source: FoodSource.manual,
        ),
      ],
    ),
];

/// Persists a profile + the given [mealGroups] + [exerciseEntries].
///
/// Pass `withProfile: false` for the incomplete-profile case.
Future<void> seedMonthly({
  required FakeMealRepository meals,
  required FakeExerciseRepository exercises,
  required FakeProfileRepository profile,
  List<MealWithItems> mealGroups = const <MealWithItems>[],
  List<DailyExercise> exerciseEntries = const <DailyExercise>[],
  bool withProfile = true,
}) async {
  if (withProfile) {
    await profile.saveProfile(monthlyProfile);
  }
  for (final MealWithItems group in mealGroups) {
    await meals.saveMealWithItems(group.meal, group.items);
  }
  for (final DailyExercise entry in exerciseEntries) {
    await exercises.setKcal(dayKey: entry.dayKey, kcal: entry.kcal);
  }
}
