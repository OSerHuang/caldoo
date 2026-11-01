/// Batch re-resolve of logged meal items after their linked food was edited.
///
/// Editing a [Food] never rewrites history by itself — a logged [MealItem] is
/// a snapshot. This service is the explicit, user-confirmed exception: after
/// the user corrects a food's nutrient values (the 编辑数值 flow), every item
/// that points at that food via `foodId` can be recomputed from the food's
/// **current** per-100 g values at the item's own grams, exactly like the
/// per-row 「采用」 inside the review form ([resolveNutrients]).
///
/// Semantics:
/// * only items with `foodId == food.id` are touched; everything else —
///   including sibling items of the same meal — is returned untouched;
/// * a blank food field falls back to the item's stored value (the
///   `resolveNutrients` fallback: a blank label field is never turned into
///   `0`, and never erases what was recorded);
/// * energy is the single whole-kcal rounding boundary (`resolveNutrients`);
/// * salt is derived from the food's sodium (`sodiumMgToSaltG`);
/// * an item with `grams <= 0`, or one whose stored values are too malformed
///   for [resolveNutrients] to run, is skipped unchanged (defensive: a broken
///   record must not block the rest of the batch);
/// * a meal none of whose items actually changed is returned as the same
///   instance, so the caller can skip the rewrite entirely.
library;

import '../models/food.dart';
import '../models/meal_item.dart';
import '../../core/time/date_windows.dart' show MealWithItems;
import 'label_priority.dart' show resolveNutrients;

/// Recomputes the nutrient fields of every [meals] item linked to [food].
///
/// Returns the updated meal list in input order; meals without a changed item
/// keep their original instance. Nothing is persisted here — the caller writes
/// each changed meal back through `MealRepository.updateMealWithItems`.
List<MealWithItems> recomputeHistoryForFood(
  Food food,
  List<MealWithItems> meals,
) {
  return <MealWithItems>[
    for (final MealWithItems entry in meals) _recomputeMeal(food, entry),
  ];
}

MealWithItems _recomputeMeal(Food food, MealWithItems entry) {
  var changed = false;
  final List<MealItem> items = <MealItem>[];
  for (final MealItem item in entry.items) {
    var newItem = item;
    if (item.foodId == food.id && item.grams > 0) {
      try {
        final resolved = resolveNutrients(item, food, item.grams.toDouble());
        final candidate = item.copyWith(
          kcal: resolved.kcal,
          carbG: resolved.carbG,
          proteinG: resolved.proteinG,
          fatG: resolved.fatG,
          saltG: resolved.saltG,
        );
        // A food edited back to its recorded values (or a no-op edit) must
        // not mark the meal changed: the caller skips unchanged rewrites.
        if (candidate != item) {
          newItem = candidate;
          changed = true;
        }
      } on ArgumentError {
        // A malformed stored value with a blank food field cannot be
        // re-resolved; leave the item as recorded rather than blocking the
        // rest of the batch.
      }
    }
    items.add(newItem);
  }
  if (!changed) {
    return entry;
  }
  return (meal: entry.meal, items: items);
}
