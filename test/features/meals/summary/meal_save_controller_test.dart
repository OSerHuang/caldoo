/// Task 22: the validated save path + running 今日累计.
///
/// Covers the plan's acceptance criteria directly:
/// * saving 2 meals through [MealSaveController] makes the running 今日累计
///   (from the repository `watch` stream) equal the exact sum of both meals;
/// * each item's `source` survives persistence;
/// * a 0-item meal is rejected with [MealValidationException] and NOTHING is
///   written — the day total stays zero.
library;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:caldoo/core/time/date_windows.dart' show MealWithItems;
import 'package:caldoo/domain/models/models.dart';
import 'package:caldoo/features/meals/summary/meal_save_controller.dart';
import 'package:caldoo/features/meals/summary/meal_summary_providers.dart';
import 'package:caldoo/features/meals/summary/meal_totals.dart';

import '../../../data/repositories/fake_repositories.dart';
import '_fixtures.dart';

void main() {
  test('saving 2 meals makes the running 今日累计 equal the exact sum', () async {
    final FakeMealRepository repo = FakeMealRepository();
    addTearDown(repo.dispose);
    final ProviderContainer container = summaryContainer(repo);
    addTearDown(container.dispose);

    // A live listener keeps the StreamProvider unpaused (Riverpod 3 note).
    final List<MealTotals> emissions = <MealTotals>[];
    final ProviderSubscription<MealTotals> subscription = container.listen(
      todayTotalsProvider,
      (MealTotals? previous, MealTotals next) => emissions.add(next),
      fireImmediately: true,
    );
    addTearDown(subscription.close);
    await pumpEventQueue();

    final MealSaveController controller = container.read(
      mealSaveControllerProvider,
    );
    final Meal lunch = summaryMeal(id: 'meal-lunch', timestamp: fixedNow);
    final Meal breakfast = summaryMeal(
      id: 'meal-breakfast',
      timestamp: fixedNow.subtract(const Duration(hours: 2)),
      mealType: MealType.breakfast,
    );

    await controller.save(meal: lunch, items: <MealItem>[summaryRiceItem()]);
    await controller.save(meal: breakfast, items: <MealItem>[summaryEggItem()]);
    await pumpEventQueue();

    // 120 + 70 = 190 kcal; 8 + 1 = 9 carb; 6 + 7 = 13 protein; 5 + 4 = 9 fat;
    // sodium 120 + 80 = 200 mg -> salt 0.5 g. Exact, not approximate.
    final MealTotals running = emissions.last;
    expect(running.kcal, 190.0);
    expect(running.carbG, 9.0);
    expect(running.proteinG, 13.0);
    expect(running.fatG, 9.0);
    expect(running.sodiumMg, 200.0);
    expect(running.saltG, 0.5);

    // The running total is the SAME value the card watches.
    expect(container.read(todayTotalsProvider), running);

    // Per-item source is persisted verbatim through the repository.
    final window = fixedDayWindow();
    final List<MealWithItems> stored = await repo.getMealsWithItemsInRange(
      startInclusive: window.start,
      endExclusive: window.end,
    );
    expect(stored, hasLength(2));
    final Map<String, FoodSource> sourceById = <String, FoodSource>{
      for (final MealWithItems group in stored)
        for (final MealItem item in group.items) item.id: item.source,
    };
    expect(sourceById['item-rice'], FoodSource.ai);
    expect(sourceById['item-egg'], FoodSource.manual);

    // Manual-QA channel: the measured running total equals the hand sum.
    debugPrint(
      'TASK22_QA meals=2 day_total_kcal=${running.kcal} '
      'day_total_carb=${running.carbG} day_total_protein=${running.proteinG} '
      'day_total_fat=${running.fatG} day_total_salt=${running.saltG} '
      'sum=(120+70, 8+1, 6+7, 5+4, 0.3+0.2) sources=ai/manual -> PASS',
    );
  });

  test('a 0-item meal is rejected and nothing is written', () async {
    final FakeMealRepository repo = FakeMealRepository();
    addTearDown(repo.dispose);
    final ProviderContainer container = summaryContainer(repo);
    addTearDown(container.dispose);

    final MealSaveController controller = container.read(
      mealSaveControllerProvider,
    );
    final Meal empty = summaryMeal(id: 'meal-empty', timestamp: fixedNow);

    await expectLater(
      controller.save(meal: empty, items: const <MealItem>[]),
      throwsA(isA<MealValidationException>()),
    );

    final window = fixedDayWindow();
    final List<MealWithItems> stored = await repo.getMealsWithItemsInRange(
      startInclusive: window.start,
      endExclusive: window.end,
    );
    expect(stored, isEmpty);
    expect(container.read(todayTotalsProvider), MealTotals.zero);

    // Manual-QA channel: the 0-item rejection.
    debugPrint(
      'TASK22_QA empty_meal rejected=true stored_meals=${stored.length} '
      'day_total_kcal=${container.read(todayTotalsProvider).kcal} -> PASS',
    );
  });

  test('validateMealItems rejects an empty list and a blank name', () {
    expect(validateMealItems(const <MealItem>[]), '至少需要一个食物项');
    final MealItem blank = summaryRiceItem().copyWith(name: '   ');
    expect(validateMealItems(<MealItem>[blank]), '请填写食物名称');
    expect(validateMealItems(<MealItem>[summaryRiceItem()]), isNull);
  });
}
