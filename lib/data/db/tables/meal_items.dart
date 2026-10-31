import 'package:drift/drift.dart';

import '../../../domain/models/food.dart';
import 'meals.dart';

/// One food line inside a [Meals] row (`meal_items`), already scaled to the
/// consumed grams.
///
/// [mealId] is a hard foreign key with `ON DELETE CASCADE`: deleting a meal
/// removes its items, so no orphaned line can survive its parent. [foodId] is
/// deliberately **not** a foreign key — it is an optional back-link to a saved
/// food (kept so a grams edit can recompute from per-100 g values), and the
/// logged item is a historical record that must survive a food being deleted.
///
/// Canonical units: energy in **whole kcal** (integer-only), macros g.
/// [saltG] is the display unit carried on the item (sodium mg stays canonical
/// on [Foods]).
@DataClassName('MealItemRow')
class MealItems extends Table {
  /// UUID of the item.
  TextColumn get id => text()();

  /// Owning meal; deleted with its parent (cascade).
  TextColumn get mealId =>
      text().references(Meals, #id, onDelete: KeyAction.cascade)();

  /// Optional back-link to a saved [Foods] row; no FK on purpose (see above).
  TextColumn get foodId => text().nullable()();

  TextColumn get name => text()();

  /// Consumed weight in grams.
  RealColumn get grams => real()();

  /// Energy in **whole kcal** (canonical, integer-only).
  IntColumn get kcal => integer()();

  /// Carbohydrate in grams.
  RealColumn get carbG => real()();

  /// Protein in grams.
  RealColumn get proteinG => real()();

  /// Fat in grams.
  RealColumn get fatG => real()();

  /// Salt in grams — the display unit carried on the item.
  RealColumn get saltG => real()();

  /// Per-item provenance (`label` when a saved label food was applied).
  TextColumn get source => textEnum<FoodSource>()();

  /// AI self-reported confidence (0..1), when the provider returned one.
  RealColumn get confidence => real().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
