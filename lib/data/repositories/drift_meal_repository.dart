/// Drift-backed [MealRepository].
library;

import 'package:drift/drift.dart' show Value;

import '../../core/time/date_windows.dart' show MealWithItems;
import '../../domain/models/meal.dart';
import '../../domain/models/meal_item.dart';
import '../../domain/repositories/meal_repository.dart';
import '../db/app_database.dart';
import '../db/daos/meal_dao.dart' show MealWithItemRows;
import 'mappers.dart';

/// Stores meals and their items via `MealDao`, returning domain models only.
class DriftMealRepository implements MealRepository {
  /// Creates the repository over [db].
  DriftMealRepository(this._db);

  final AppDatabase _db;

  @override
  Future<void> saveMealWithItems(Meal meal, List<MealItem> items) {
    return _db.mealDao.saveMealWithItems(
      meal: _mealCompanion(meal),
      items: <MealItemsCompanion>[
        for (final item in items) _itemCompanion(meal.id, item),
      ],
    );
  }

  @override
  Future<void> updateMealWithItems(Meal meal, List<MealItem> items) {
    return _db.mealDao.replaceMealWithItems(
      meal: _mealCompanion(meal),
      items: <MealItemsCompanion>[
        for (final item in items) _itemCompanion(meal.id, item),
      ],
    );
  }

  /// The full editable record of [meal]; the one place that maps the domain
  /// [Meal] into the companion both the insert and the update paths write.
  MealsCompanion _mealCompanion(Meal meal) {
    return MealsCompanion.insert(
      id: meal.id,
      timestamp: meal.timestamp,
      mealType: meal.mealType,
      note: Value<String?>(meal.note),
    );
  }

  @override
  Future<void> deleteMeal(String id) async {
    // Items cascade away with the meal (FK ON DELETE CASCADE).
    await _db.mealDao.deleteMeal(id);
  }

  @override
  Future<List<Meal>> getMealsInRange({
    required DateTime startInclusive,
    required DateTime endExclusive,
  }) async {
    final rows = await _db.mealDao.getMealsInRange(
      startInclusive: startInclusive,
      endExclusive: endExclusive,
    );
    return <Meal>[for (final row in rows) mealFromRow(row)];
  }

  @override
  Future<List<MealWithItems>> getMealsWithItemsInRange({
    required DateTime startInclusive,
    required DateTime endExclusive,
  }) async {
    final groups = await _db.mealDao.getMealsWithItemsInRange(
      startInclusive: startInclusive,
      endExclusive: endExclusive,
    );
    return <MealWithItems>[
      for (final group in groups) mealWithItemsFromRows(group),
    ];
  }

  @override
  Stream<List<MealWithItems>> watchMealsInRange({
    required DateTime startInclusive,
    required DateTime endExclusive,
  }) {
    return _db.mealDao
        .watchMealsInRange(
          startInclusive: startInclusive,
          endExclusive: endExclusive,
        )
        .map(_groupsToDomain);
  }

  @override
  Stream<List<MealWithItems>> watchMealsForDay({
    required DateTime dayStartInclusive,
    required DateTime dayEndExclusive,
  }) {
    return watchMealsInRange(
      startInclusive: dayStartInclusive,
      endExclusive: dayEndExclusive,
    );
  }

  @override
  Stream<List<MealWithItems>> watchMealsForWeek({
    required DateTime weekStartInclusive,
    required DateTime weekEndExclusive,
  }) {
    return watchMealsInRange(
      startInclusive: weekStartInclusive,
      endExclusive: weekEndExclusive,
    );
  }

  @override
  Stream<MealWithItems?> watchMealWithItems(String id) {
    return _db.mealDao.watchMealWithItems(id).map((
      List<MealWithItemRows> groups,
    ) {
      if (groups.isEmpty) {
        return null;
      }
      return mealWithItemsFromRows(groups.single);
    });
  }

  /// The owning meal id comes from the [Meal] argument: a domain [MealItem]
  /// carries no `mealId`, the repository is what knows the parent.
  MealItemsCompanion _itemCompanion(String mealId, MealItem item) {
    return MealItemsCompanion.insert(
      id: item.id,
      mealId: mealId,
      foodId: Value<String?>(item.foodId),
      name: item.name,
      grams: item.grams,
      kcal: item.kcal,
      carbG: item.carbG,
      proteinG: item.proteinG,
      fatG: item.fatG,
      saltG: item.saltG,
      source: item.source,
      confidence: Value<double?>(item.confidence),
    );
  }

  static List<MealWithItems> _groupsToDomain(List<MealWithItemRows> groups) {
    return <MealWithItems>[
      for (final group in groups) mealWithItemsFromRows(group),
    ];
  }
}
