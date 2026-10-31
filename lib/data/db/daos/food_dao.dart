import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/foods.dart';

part 'food_dao.g.dart';

/// Reads and writes the saved-food catalogue (`foods`).
///
/// Writes take a [FoodsCompanion] so the typed API keeps compile-time required
/// fields (id/name/source) while nullable nutrients stay absent as SQL `NULL`.
@DriftAccessor(tables: [Foods])
class FoodDao extends DatabaseAccessor<AppDatabase> with _$FoodDaoMixin {
  FoodDao(super.attachedDatabase);

  /// Inserts a new food; fails on a duplicate [Foods.id].
  Future<void> insertFood(FoodsCompanion food) {
    return into(foods).insert(food);
  }

  /// Inserts the food, or rewrites the row with the same id.
  Future<void> upsertFood(FoodsCompanion food) {
    return into(foods).insertOnConflictUpdate(food);
  }

  /// Replaces the stored food identified by the companion's id.
  ///
  /// Returns false when no such row exists. Absent nullable fields are written
  /// as `NULL` — drift's [UpdateStatement.replace] is a full-row replace, so
  /// pass the complete record.
  Future<bool> updateFood(FoodsCompanion food) {
    return update(foods).replace(food);
  }

  /// Deletes the food; returns the number of rows removed.
  Future<int> deleteFood(String id) {
    return (delete(foods)..where((t) => t.id.equals(id))).go();
  }

  /// The food with [id], or null when it does not exist.
  Future<FoodRow?> getFood(String id) {
    return (select(foods)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  /// Emits the food with [id] on every change (null when absent).
  Stream<FoodRow?> watchFood(String id) {
    final query = select(foods)..where((t) => t.id.equals(id));
    return query.watchSingleOrNull();
  }

  /// Every saved food, ordered by name.
  Future<List<FoodRow>> getAllFoods() {
    return (select(foods)..orderBy([(t) => OrderingTerm.asc(t.name)])).get();
  }

  /// Emits the full catalogue on every change, ordered by name.
  Stream<List<FoodRow>> watchAllFoods() {
    final query = select(foods)..orderBy([(t) => OrderingTerm.asc(t.name)]);
    return query.watch();
  }
}
