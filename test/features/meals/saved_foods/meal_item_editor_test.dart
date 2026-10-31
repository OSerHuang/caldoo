import 'package:flutter_test/flutter_test.dart';

import 'package:caldoo/domain/models/models.dart';
import 'package:caldoo/features/meals/saved_foods/meal_item_editor.dart';

import '_fixtures.dart';

void main() {
  group('MealItemEditor', () {
    test('chooseFood stores foodId + grams and recomputes from per-100g', () {
      final MealItemEditor editor = MealItemEditor(aiMilkItem());
      editor.chooseFood(labelMilk);
      editor.editGrams(150);

      final MealItem item = editor.item;
      expect(item.foodId, 'food-label-milk');
      expect(item.grams, 150);
      expect(item.source, FoodSource.label);
      expect(item.kcal, 200 * 150 / 100); // 300.0
      expect(item.carbG, 20 * 150 / 100); // 30.0
      expect(item.proteinG, 10 * 150 / 100); // 15.0
      expect(item.fatG, 5 * 150 / 100); // 7.5
      expect(item.saltG, 200 * 150 / 100 / 400); // 0.75
    });

    test('editing grams after choosing recomputes instead of freezing', () {
      final MealItemEditor editor = MealItemEditor(aiMilkItem());
      editor.chooseFood(labelMilk);

      editor.editGrams(100);
      expect(editor.item.kcal, 200.0);

      editor.editGrams(200);
      expect(editor.item.kcal, 400.0); // recomputed, NOT frozen at 200
      expect(editor.item.grams, 200);
    });

    test('a blank label field falls back to the AI value verbatim', () {
      final MealItemEditor editor = MealItemEditor(aiMilkItem());
      editor.chooseFood(blankProteinMilk);
      editor.editGrams(150);

      expect(editor.item.kcal, 300.0); // label field -> scaled
      expect(editor.item.proteinG, 6.0); // AI fallback -> verbatim, not scaled
    });

    test('without a chosen food the AI values are untouched', () {
      final MealItemEditor editor = MealItemEditor(aiMilkItem());
      expect(editor.item.kcal, 120.0);
      expect(editor.item.foodId, isNull);
      expect(editor.hasChosenFood, isFalse);
    });

    test('grams 0 zeroes the label-scaled fields', () {
      final MealItemEditor editor = MealItemEditor(aiMilkItem());
      editor.chooseFood(labelMilk);
      editor.editGrams(0);
      expect(editor.item.kcal, 0.0);
      expect(editor.item.saltG, 0.0);
    });

    test('malformed grams are rejected', () {
      final MealItemEditor editor = MealItemEditor(aiMilkItem());
      expect(() => editor.editGrams(-1), throwsArgumentError);
      expect(() => editor.editGrams(double.nan), throwsArgumentError);
      expect(() => editor.editGrams(double.infinity), throwsArgumentError);
    });
  });
}
