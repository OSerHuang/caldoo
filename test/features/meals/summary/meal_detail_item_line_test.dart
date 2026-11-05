/// Guards the meal-detail item line against the display-unit migration.
///
/// The `/meal/:id` screen already renders `S.mealDetailItemLineWith(grams,
/// DisplayUnits.of(context).energyText(item.kcal))`. With no [DisplayScope] the
/// line must keep the historical `150 g · 350 kcal`; a kJ scope converts only
/// the energy half.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:caldoo/core/providers/app_providers.dart';
import 'package:caldoo/core/units/display_units.dart';
import 'package:caldoo/domain/models/models.dart';
import 'package:caldoo/features/meals/summary/meal_summary_providers.dart';
import 'package:caldoo/features/nav/meal_detail_screen.dart';

import '../../../data/repositories/fake_repositories.dart';
import '_fixtures.dart';

/// A 150 g item at 350 kcal, matching the documented line example.
MealItem _item() => const MealItem(
  id: 'item-line',
  name: '测试食物',
  grams: 150,
  kcal: 350,
  carbG: 40,
  proteinG: 8,
  fatG: 6,
  saltG: 0.2,
  source: FoodSource.manual,
);

Future<void> _pumpMealDetail(WidgetTester tester, {DisplayUnits? units}) async {
  final FakeMealRepository repo = FakeMealRepository();
  addTearDown(repo.dispose);

  final Meal meal = summaryMeal(id: 'meal-line', timestamp: fixedNow);
  await repo.saveMealWithItems(meal, <MealItem>[_item()]);

  final Widget app = MaterialApp(home: MealDetailScreen(mealId: meal.id));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        mealRepositoryProvider.overrideWithValue(repo),
        summaryClockProvider.overrideWithValue(fixedShanghaiClock()),
        localOffsetProvider.overrideWithValue(shanghai),
      ],
      child: units == null ? app : DisplayScope(units: units, child: app),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the item line keeps the default 150 g · 350 kcal', (
    WidgetTester tester,
  ) async {
    await _pumpMealDetail(tester);

    expect(find.text('150 g · 350 kcal'), findsOneWidget);
    expect(find.text('150 g · 1464 kJ'), findsNothing);
  });

  testWidgets('fractional grams render like the review card, not rounded', (
    WidgetTester tester,
  ) async {
    // 74.5 g must stay 74.5 — the review card and the today screen show the
    // shared AppFormat.number, and rounding the detail page up to 75 made the
    // same meal read differently one screen later.
    final Meal meal = summaryMeal(id: 'meal-frac', timestamp: fixedNow);
    final FakeMealRepository repo = FakeMealRepository();
    addTearDown(repo.dispose);
    await repo.saveMealWithItems(meal, <MealItem>[
      const MealItem(
        id: 'item-frac',
        name: '测试食物',
        grams: 74.5,
        kcal: 174,
        carbG: 38.9,
        proteinG: 3.6,
        fatG: 0.3,
        saltG: 0.0005,
        source: FoodSource.ai,
      ),
    ]);
    final Widget app = MaterialApp(home: MealDetailScreen(mealId: meal.id));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mealRepositoryProvider.overrideWithValue(repo),
          summaryClockProvider.overrideWithValue(fixedShanghaiClock()),
          localOffsetProvider.overrideWithValue(shanghai),
        ],
        child: app,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('74.5 g · 174 kcal'), findsOneWidget);
    expect(find.text('75 g · 174 kcal'), findsNothing);
  });

  testWidgets('a kJ preference converts only the energy half of the line', (
    WidgetTester tester,
  ) async {
    await _pumpMealDetail(
      tester,
      units: const DisplayUnits(energy: EnergyDisplay.kj),
    );

    // 350 kcal -> 1464.4 -> 1464 kJ; the grams stay canonical.
    expect(find.text('150 g · 1464 kJ'), findsOneWidget);
    expect(find.text('150 g · 350 kcal'), findsNothing);
  });
}
