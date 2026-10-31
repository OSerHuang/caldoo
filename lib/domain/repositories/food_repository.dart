/// Repository port for the saved-food catalogue (the phase-2 sync seam).
///
/// Pure Dart: imports [Food] and nothing from `drift`; every method returns
/// domain models, never `FoodRow`. The Drift implementation lives in
/// `lib/data/repositories/`.
library;

import '../models/food.dart';

/// Persistence port for saved foods with per-100 g nutrient values.
abstract interface class FoodRepository {
  /// Inserts a new food; fails on a duplicate [Food.id].
  Future<void> insertFood(Food food);

  /// Inserts the food, or replaces the stored row with the same id.
  ///
  /// The whole record is written: a field that is `null` on [food] becomes
  /// `NULL`, it never keeps a stale stored value.
  Future<void> upsertFood(Food food);

  /// The food with [id], or `null` when it does not exist.
  Future<Food?> getFood(String id);

  /// Every saved food, ordered by name.
  Future<List<Food>> getAllFoods();

  /// Emits the food with [id] on every change (`null` when absent).
  Stream<Food?> watchFood(String id);

  /// Emits the full catalogue on every change, ordered by name.
  Stream<List<Food>> watchAllFoods();

  /// Saved foods whose **normalized name key** equals the key of [rawName].
  ///
  /// Matching uses `normalizeName` from `lib/domain/services/label_priority.dart`
  /// (exact normalized equality — no edit distance, containment or
  /// brand/barcode matching). Returns an empty list when the key of [rawName]
  /// is empty. Results keep the catalogue's name order.
  Future<List<Food>> searchByNormalizedName(String rawName);

  /// Deletes the food; logged meal items that reference it are unaffected
  /// (`meal_items.food_id` is deliberately not a foreign key — an item is a
  /// historical record that must survive the food).
  Future<void> deleteFood(String id);
}
