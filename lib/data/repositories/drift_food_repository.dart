/// Drift-backed [FoodRepository].
library;

import 'package:drift/drift.dart' show Value;

import '../../domain/models/food.dart';
import '../../domain/repositories/food_repository.dart';
import '../../domain/services/label_priority.dart';
import '../db/app_database.dart';
import 'food_supplement_codec.dart';
import 'mappers.dart';

/// Stores saved foods via `FoodDao`, returning domain [Food]s only.
class DriftFoodRepository implements FoodRepository {
  /// Creates the repository over [db].
  DriftFoodRepository(this._db);

  final AppDatabase _db;

  @override
  Future<void> insertFood(Food food) =>
      _db.foodDao.insertFood(_companion(food));

  @override
  Future<void> upsertFood(Food food) async {
    // `update(replace)` returns false when the row is absent; otherwise it is
    // a full-row replace, so nulls in `food` overwrite stale stored values.
    final replaced = await _db.foodDao.updateFood(_companion(food));
    if (!replaced) {
      await _db.foodDao.insertFood(_companion(food));
    }
  }

  @override
  Future<Food?> getFood(String id) async {
    final row = await _db.foodDao.getFood(id);
    return row == null ? null : foodFromRow(row);
  }

  @override
  Future<List<Food>> getAllFoods() async {
    final rows = await _db.foodDao.getAllFoods();
    return <Food>[for (final row in rows) foodFromRow(row)];
  }

  @override
  Stream<Food?> watchFood(String id) {
    return _db.foodDao
        .watchFood(id)
        .map((row) => row == null ? null : foodFromRow(row));
  }

  @override
  Stream<List<Food>> watchAllFoods() {
    return _db.foodDao.watchAllFoods().map(
      (rows) => <Food>[for (final row in rows) foodFromRow(row)],
    );
  }

  @override
  Future<List<Food>> searchByNormalizedName(String rawName) async {
    // `normalizeName` is a pure-Dart contract owned by label_priority (regex
    // based); SQL cannot reproduce it, so the catalogue is filtered in Dart.
    final key = normalizeName(rawName);
    if (key.isEmpty) {
      return const <Food>[];
    }
    final rows = await _db.foodDao.getAllFoods();
    return <Food>[
      for (final row in rows)
        if (normalizeName(row.name) == key) foodFromRow(row),
    ];
  }

  @override
  Future<void> deleteFood(String id) async {
    await _db.foodDao.deleteFood(id);
  }

  /// Builds the full-row companion; nullable fields are written explicitly so
  /// a `null` becomes SQL `NULL` instead of being left untouched.
  FoodsCompanion _companion(Food food) => FoodsCompanion.insert(
    id: food.id,
    name: food.name,
    brand: Value<String?>(food.brand),
    barcode: Value<String?>(food.barcode),
    aliases: Value<String?>(encodeAliases(food.aliases)),
    servings: Value<String?>(encodeServings(food.servings)),
    status: Value<FoodStatus>(food.status),
    basis: Value<MeasureBasis>(food.basis),
    notes: Value<String?>(food.notes),
    source: food.source,
    kcal: Value<int?>(food.kcal),
    carbG: Value<double?>(food.carbG),
    proteinG: Value<double?>(food.proteinG),
    fatG: Value<double?>(food.fatG),
    sugarG: Value<double?>(food.sugarG),
    saturatedFatG: Value<double?>(food.saturatedFatG),
    sodiumMg: Value<double?>(food.sodiumMg),
  );
}
