/// recomputeHistoryForFood: the batch re-resolve behind the food detail
/// page's 重算历史记录 offer.
///
/// The contract (see the service doc): only items linked via `foodId` are
/// touched, the per-field rule is exactly [resolveNutrients] (blank food
/// field -> the item's stored value; energy rounds once; salt derives from
/// sodium), unchanged meals come back as the same instance, and malformed
/// records are skipped rather than blocking the batch.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:caldoo/core/time/date_windows.dart' show MealWithItems;
import 'package:caldoo/domain/models/models.dart';
import 'package:caldoo/domain/services/food_history.dart';

Food _cheese() => const Food(
  id: 'food-cheese',
  name: '库洛米耶奶酪',
  source: FoodSource.label,
  kcal: 291,
  carbG: 1,
  proteinG: 20,
  fatG: 23,
  sodiumMg: 640,
);

MealItem _item({
  String id = 'item-1',
  String? foodId = 'food-cheese',
  String name = '库洛米耶奶酪',
  double grams = 50,
  int kcal = 145,
  double carbG = 10.25,
  double proteinG = 11.5,
  double fatG = 8,
  double saltG = 0,
}) {
  return MealItem(
    id: id,
    foodId: foodId,
    name: name,
    grams: grams,
    kcal: kcal,
    carbG: carbG,
    proteinG: proteinG,
    fatG: fatG,
    saltG: saltG,
    source: FoodSource.label,
  );
}

MealWithItems _meal(String id, List<MealItem> items, {DateTime? timestamp}) {
  return (
    meal: Meal(
      id: id,
      timestamp: timestamp ?? DateTime(2026, 11, 1, 12),
      mealType: MealType.lunch,
    ),
    items: items,
  );
}

void main() {
  test('scales every nutrient from per-100 g at the item grams', () {
    final meals = <MealWithItems>[
      _meal('m1', <MealItem>[_item()]),
    ];

    final updated = recomputeHistoryForFood(_cheese(), meals);

    final item = updated.single.items.single;
    // 50 g of the 291 kcal / 1 g / 20 g / 23 g / 640 mg food.
    expect(item.kcal, 146); // round(291 * 0.5)
    expect(item.carbG, 0.5);
    expect(item.proteinG, 10.0);
    expect(item.fatG, 11.5);
    expect(item.saltG, 0.8); // 640 mg * 0.5 / 400
  });

  test('energy rounds once at the whole-kcal boundary (70 g -> 204)', () {
    final meals = <MealWithItems>[
      _meal('m1', <MealItem>[_item(grams: 70, kcal: 202)]),
    ];

    final updated = recomputeHistoryForFood(_cheese(), meals);

    expect(updated.single.items.single.kcal, 204); // round(291 * 0.7)
  });

  test('a blank food field falls back to the item stored value', () {
    const Food partial = Food(
      id: 'food-cheese',
      name: '库洛米耶奶酪',
      source: FoodSource.label,
      kcal: 291,
      // carb / protein / fat / sodium blank on purpose.
    );
    final meals = <MealWithItems>[
      _meal('m1', <MealItem>[_item()]),
    ];

    final updated = recomputeHistoryForFood(partial, meals);

    final item = updated.single.items.single;
    expect(item.kcal, 146); // the label value wins where present
    expect(item.carbG, 10.25); // blank food field -> recorded value kept
    expect(item.proteinG, 11.5);
    expect(item.fatG, 8.0);
    expect(item.saltG, 0.0);
  });

  test('grams 0 and non-linked items are untouched; siblings stay as-is', () {
    final meals = <MealWithItems>[
      _meal('m1', <MealItem>[
        _item(id: 'zero', grams: 0, kcal: 99),
        _item(id: 'other', foodId: 'food-other', name: '别的', kcal: 77),
        _item(id: 'linked', grams: 30, kcal: 87),
      ]),
    ];

    final updated = recomputeHistoryForFood(_cheese(), meals);

    final items = updated.single.items;
    expect(items[0].kcal, 99); // grams 0 -> skipped
    expect(items[1].kcal, 77); // different food -> untouched
    expect(items[2].kcal, 87); // 30 g: round(291 * 0.3) — unchanged value
    // ...but its macros were recomputed: 30 g of 1 g carb = 0.3.
    expect(items[2].carbG, 0.3);
    expect(items[2].saltG, 0.48);
  });

  test(
    'a meal with no changes returns the SAME instance (skip the rewrite)',
    () {
      // The item already carries exactly what the food resolves to (the user
      // edited the food back to its recorded values): nothing may change, and
      // the caller must be able to skip the rewrite via instance identity.
      final meals = <MealWithItems>[
        _meal('m1', <MealItem>[
          _item(kcal: 146, carbG: 0.5, proteinG: 10, fatG: 11.5, saltG: 0.8),
        ]),
      ];

      final updated = recomputeHistoryForFood(_cheese(), meals);

      expect(identical(updated.single, meals.single), isTrue);
    },
  );

  test('an item too malformed to re-resolve is skipped, not fatal', () {
    // The food carries no fat; the item stores a broken (negative) fat value,
    // so resolveNutrients would have to "return" it and throws instead. The
    // whole item is skipped unchanged — a broken record must not block the
    // batch, and a partial rewrite could look stranger than the bug.
    const Food noFat = Food(
      id: 'food-cheese',
      name: '库洛米耶奶酪',
      source: FoodSource.label,
      kcal: 291,
      carbG: 1,
      proteinG: 20,
      sodiumMg: 640,
    );
    final MealItem broken = _item(grams: 50).copyWith(fatG: -5);
    final meals = <MealWithItems>[
      _meal('m1', <MealItem>[broken]),
    ];

    final updated = recomputeHistoryForFood(noFat, meals);

    final item = updated.single.items.single;
    expect(item.kcal, 145);
    expect(item.fatG, -5);
    expect(identical(updated.single.items.single, broken), isTrue);
  });

  test('input order preserved across several meals', () {
    final meals = <MealWithItems>[
      _meal('m2', <MealItem>[_item(id: 'b', grams: 70, kcal: 202)]),
      _meal('m1', <MealItem>[_item(id: 'a', grams: 30, kcal: 87)]),
    ];

    final updated = recomputeHistoryForFood(_cheese(), meals);

    expect(updated[0].meal.id, 'm2');
    expect(updated[0].items.single.kcal, 204);
    expect(updated[1].meal.id, 'm1');
    expect(updated[1].items.single.kcal, 87);
  });
}
