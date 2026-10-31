import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:caldoo/core/providers/app_providers.dart';
import 'package:caldoo/core/units/display_units.dart';
import 'package:caldoo/domain/models/models.dart';
import 'package:caldoo/features/meals/saved_foods/label_suggestion_banner.dart';
import 'package:caldoo/features/meals/saved_foods/saved_food_meal_item_editor.dart';
import 'package:caldoo/features/meals/saved_foods/saved_food_picker.dart';

import '../../../data/repositories/fake_repositories.dart';
import '_fixtures.dart';

Future<void> _pumpEditor(
  WidgetTester tester, {
  required List<Food> foods,
  MealItem? aiItem,
  ValueChanged<MealItem>? onChanged,
  DisplayUnits? units,
}) async {
  final FakeFoodRepository repo = FakeFoodRepository();
  for (final Food food in foods) {
    await repo.insertFood(food);
  }
  final Widget app = MaterialApp(
    home: Scaffold(
      body: SavedFoodMealItemEditor(
        aiItem: aiItem ?? aiMilkItem(),
        onChanged: onChanged,
      ),
    ),
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [foodRepositoryProvider.overrideWithValue(repo)],
      child: units == null ? app : DisplayScope(units: units, child: app),
    ),
  );
  await tester.pumpAndSettle();
}

String _text(WidgetTester tester, Key key) =>
    tester.widget<Text>(find.byKey(key)).data!;

void main() {
  testWidgets(
    'picking a label food then editing grams rescales 1.5x then 2.0x',
    (WidgetTester tester) async {
      MealItem? captured;
      await _pumpEditor(
        tester,
        foods: <Food>[labelMilk],
        onChanged: (MealItem item) => captured = item,
      );

      await tester.tap(find.byKey(savedFoodPickButtonKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(savedFoodTileKey('food-label-milk')));
      await tester.pumpAndSettle();

      // Chosen at the AI item's grams (100 g): per100g * 1.0.
      expect(_text(tester, savedFoodKcalValueKey), '200');
      expect(captured?.foodId, 'food-label-milk');

      // 150 g -> per100g * 1.5, exactly.
      await tester.enterText(find.byKey(savedFoodGramsFieldKey), '150');
      await tester.pump();
      expect(_text(tester, savedFoodKcalValueKey), '300');
      expect(_text(tester, savedFoodCarbValueKey), '30');
      expect(_text(tester, savedFoodProteinValueKey), '15');
      expect(_text(tester, savedFoodFatValueKey), '7.5');
      expect(_text(tester, savedFoodSaltValueKey), '0.75');
      expect(captured?.grams, 150);

      // 200 g -> per100g * 2.0, exactly (recomputed, not frozen at the 1.5x).
      await tester.enterText(find.byKey(savedFoodGramsFieldKey), '200');
      await tester.pump();
      expect(_text(tester, savedFoodKcalValueKey), '400');
      expect(_text(tester, savedFoodCarbValueKey), '40');
      expect(_text(tester, savedFoodProteinValueKey), '20');
      expect(_text(tester, savedFoodFatValueKey), '10');
      expect(_text(tester, savedFoodSaltValueKey), '1');
      expect(captured?.grams, 200);
    },
  );

  testWidgets('a suggestion does not change values until it is tapped', (
    WidgetTester tester,
  ) async {
    MealItem? captured;
    await _pumpEditor(
      tester,
      foods: <Food>[labelMilk],
      onChanged: (MealItem item) => captured = item,
    );

    // The non-blocking suggestion is visible, naming the food and the reason.
    expect(find.byKey(LabelSuggestionBanner.containerKey), findsOneWidget);
    expect(find.text('库内已存该食物的标签：全脂牛奶（光明），采用?'), findsOneWidget);
    expect(find.text('名称一致'), findsOneWidget);
    // ... but nothing changed: the readouts are exactly the AI values.
    expect(_text(tester, savedFoodKcalValueKey), '120');
    expect(_text(tester, savedFoodProteinValueKey), '6');
    expect(_text(tester, savedFoodSaltValueKey), '0.3');
    expect(captured, isNull);

    // The explicit tap is the only thing that applies the label.
    await tester.tap(find.byKey(LabelSuggestionBanner.applyButtonKey));
    await tester.pumpAndSettle();

    expect(_text(tester, savedFoodKcalValueKey), '200'); // per100g * 1.0
    expect(_text(tester, savedFoodProteinValueKey), '10');
    expect(_text(tester, savedFoodSaltValueKey), '0.5'); // 200 mg / 400
    expect(captured?.foodId, 'food-label-milk');
    expect(find.byKey(LabelSuggestionBanner.containerKey), findsNothing);
  });

  testWidgets('no suggestion when nothing matches; AI values remain', (
    WidgetTester tester,
  ) async {
    await _pumpEditor(tester, foods: <Food>[aiVeg]);

    expect(find.byKey(LabelSuggestionBanner.containerKey), findsNothing);
    expect(_text(tester, savedFoodKcalValueKey), '120');
  });

  testWidgets('a kJ + sodium preference switches the readouts, not the input', (
    WidgetTester tester,
  ) async {
    MealItem? captured;
    await _pumpEditor(
      tester,
      foods: <Food>[labelMilk],
      onChanged: (MealItem item) => captured = item,
      units: const DisplayUnits(
        energy: EnergyDisplay.kj,
        salt: SaltDisplay.sodium,
      ),
    );

    // AI item: 120 kcal -> 502 kJ, 0.3 g salt -> 120 mg sodium.
    expect(_text(tester, savedFoodKcalValueKey), '502');
    expect(find.text('kJ'), findsOneWidget);
    expect(_text(tester, savedFoodSaltValueKey), '120');
    expect(find.text('钠'), findsOneWidget);
    expect(find.text('mg'), findsOneWidget);

    // The grams input stays canonical: same value, same unit, and it still
    // drives the (display-converted) readouts.
    final TextField grams = tester.widget<TextField>(
      find.byKey(savedFoodGramsFieldKey),
    );
    expect(grams.controller!.text, '100');
    expect(find.text('克数 (g)'), findsOneWidget);

    await tester.enterText(find.byKey(savedFoodGramsFieldKey), '150');
    await tester.pump();
    // 180 kcal -> 753.12 -> 753 kJ; 0.45 g salt -> 180 mg sodium.
    expect(_text(tester, savedFoodKcalValueKey), '753');
    expect(_text(tester, savedFoodSaltValueKey), '180');
    expect(captured?.grams, 150);
    // The stored item is canonical regardless of the display preference.
    expect(captured?.kcal, 180);
    expect(captured?.saltG, closeTo(0.45, 1e-9));
  });
}
