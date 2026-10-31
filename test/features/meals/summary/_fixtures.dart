/// Shared fixtures for the task-22 per-meal summary tests.
///
/// All values are exactly representable in binary floating point so the
/// "running 今日累计 equals the exact sum" assertions are exact:
/// `120 + 70 = 190`, sodium `120 + 80 = 200 mg`, salt `0.3 + 0.2 = 0.5 g`.
library;

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:caldoo/core/providers/app_providers.dart';
import 'package:caldoo/core/time/date_windows.dart';
import 'package:caldoo/core/time/day_tick_provider.dart';
import 'package:caldoo/domain/models/models.dart';
import 'package:caldoo/features/meals/summary/day_window.dart';
import 'package:caldoo/features/meals/summary/meal_summary_providers.dart';

import '../../../data/repositories/fake_repositories.dart';

/// A fixed +08:00 (Asia/Shanghai) offset for deterministic day windows.
const LocalOffset shanghai = LocalOffset(480);

/// 2026-01-05 12:00 +08:00, used as the injected "now".
final DateTime fixedNow = DateTime.utc(2026, 1, 5, 4);

/// A clock pinned to [fixedNow].
Clock fixedShanghaiClock() => Clock.fixed(fixedNow);

/// The AI rice estimate: kcal 120 / carb 8 / protein 6 / fat 5 / salt 0.3 g.
MealItem summaryRiceItem() => const MealItem(
  id: 'item-rice',
  name: '米饭',
  grams: 100,
  kcal: 120,
  carbG: 8,
  proteinG: 6,
  fatG: 5,
  saltG: 0.3,
  source: FoodSource.ai,
  confidence: 0.8,
);

/// A manually-entered egg line: kcal 70 / carb 1 / protein 7 / fat 4 / salt 0.2 g.
MealItem summaryEggItem() => const MealItem(
  id: 'item-egg',
  name: '鸡蛋',
  grams: 50,
  kcal: 70,
  carbG: 1,
  proteinG: 7,
  fatG: 4,
  saltG: 0.2,
  source: FoodSource.manual,
);

/// A meal record with a caller-supplied [id] / [timestamp] / [mealType].
Meal summaryMeal({
  required String id,
  DateTime? timestamp,
  MealType mealType = MealType.lunch,
}) => Meal(id: id, timestamp: timestamp ?? fixedNow, mealType: mealType);

/// A [ProviderContainer] with the meal repo + clock + offset pinned.
ProviderContainer summaryContainer(FakeMealRepository repo) {
  return ProviderContainer(
    overrides: [
      mealRepositoryProvider.overrideWithValue(repo),
      summaryClockProvider.overrideWithValue(fixedShanghaiClock()),
      localOffsetProvider.overrideWithValue(shanghai),
      // 今日累计's window follows the day-tick signal; these tests pin the day
      // instead, so the tick stays quiet (the real one needs a WidgetsBinding
      // and a Timer, neither of which belongs in a plain container test).
      dayTickProvider.overrideWith((ref) => const Stream<int>.empty()),
    ],
  );
}

/// The instant window of the fixed local day, for reading back stored meals.
LocalDayWindow fixedDayWindow() => localDayWindow(fixedNow, shanghai);
