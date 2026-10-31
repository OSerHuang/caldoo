/// Label-priority item editor (task 20).
///
/// This is the non-UI core of the picker integration: it holds the **original
/// AI item** plus an optional chosen [Food] and the current grams, and derives
/// the effective [MealItem] on demand.
///
/// The one rule that matters: when a saved food is chosen, the item's nutrients
/// are **recomputed from the food's per-100 g values** every time [item] is
/// read — `resolveNutrients(aiItem, chosenFood, grams)` (task 10). Nothing is
/// snapshotted, so editing [grams] afterwards rescales from the per-100 g
/// source of truth and never freezes the previously displayed numbers. The item
/// also carries `foodId` + [grams], which is exactly what the review/save path
/// needs to recompute later.
///
/// An item with **no** chosen food is the plain AI item; editing its grams uses
/// the task-19 proportional rule (`newGrams / oldGrams`) because an AI response
/// only defines an implied per-gram basis. The label path never uses that rule.
library;

import 'package:caldoo/core/units/nutrition_units.dart';
import 'package:caldoo/domain/models/models.dart';
import 'package:caldoo/domain/services/label_priority.dart';

/// Mutable editor state for one meal item being reviewed.
///
/// Deliberately a plain object (not a Riverpod notifier): the widget owns one
/// instance and calls `setState` after a mutation, which keeps the arithmetic
/// trivially unit-testable and the widget free of provider boilerplate.
class MealItemEditor {
  MealItemEditor(this.aiItem) : _grams = aiItem.grams;

  /// The untouched AI estimate this item started from. Never mutated.
  final MealItem aiItem;

  Food? _chosenFood;
  double _grams;

  /// The saved food the user chose, or `null` while only the AI values apply.
  Food? get chosenFood => _chosenFood;

  /// Current consumed weight in grams.
  double get grams => _grams;

  /// Whether a saved food has been chosen (the label-priority path).
  bool get hasChosenFood => _chosenFood != null;

  /// The effective item for the current state.
  ///
  /// * chosen food -> nutrients recomputed from per-100 g at [_grams], with
  ///   `foodId` + [grams] set and `source` taken from the food;
  /// * no chosen food, grams unchanged -> the original [aiItem] verbatim;
  /// * no chosen food, grams edited -> proportional scaling (task-19 rule).
  MealItem get item {
    final Food? food = _chosenFood;
    if (food != null) {
      final ResolvedNutrients resolved = resolveNutrients(aiItem, food, _grams);
      return aiItem.copyWith(
        foodId: food.id,
        grams: _grams,
        kcal: resolved.kcal,
        carbG: resolved.carbG,
        proteinG: resolved.proteinG,
        fatG: resolved.fatG,
        saltG: resolved.saltG,
        source: food.source,
      );
    }
    if (_grams == aiItem.grams) {
      return aiItem;
    }
    final double base = aiItem.grams;
    if (base <= 0) {
      return aiItem.copyWith(grams: _grams);
    }
    final double factor = _grams / base;
    return aiItem.copyWith(
      grams: _grams,
      // Energy is integer-only: the proportional scale rounds once here.
      kcal: roundKcal(aiItem.kcal * factor),
      carbG: aiItem.carbG * factor,
      proteinG: aiItem.proteinG * factor,
      fatG: aiItem.fatG * factor,
      saltG: aiItem.saltG * factor,
    );
  }

  /// Chooses [food] (the explicit user tap) and switches to the per-100 g
  /// recompute path at the current grams.
  void chooseFood(Food food) {
    _chosenFood = food;
  }

  /// Drops the chosen food and returns to the AI estimate.
  void clearFood() {
    _chosenFood = null;
  }

  /// Sets the consumed weight. Negative, NaN and infinite values are rejected
  /// (the domain never lets a broken payload poison a day total); `0` is valid
  /// and yields zero label-scaled fields.
  void editGrams(double grams) {
    if (!grams.isFinite) {
      throw ArgumentError.value(
        grams,
        'grams',
        'must be a finite number (got NaN or infinity)',
      );
    }
    if (grams < 0) {
      throw ArgumentError.value(grams, 'grams', 'must not be negative');
    }
    _grams = grams;
  }
}
