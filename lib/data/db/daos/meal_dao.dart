import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/meal_items.dart';
import '../tables/meals.dart';

part 'meal_dao.g.dart';

/// A meal row paired with its item rows, ordered by item id.
///
/// This is the data-layer counterpart of `MealWithItems` in
/// `lib/core/time/date_windows.dart`; task 12 maps it to domain models.
typedef MealWithItemRows = ({MealRow meal, List<MealItemRow> items});

/// Reads and writes [Meals]/[MealItems], including reactive day/week windows.
///
/// Every range method takes an explicit half-open window
/// `[startInclusive, endExclusive)` of instants. This DAO contains **no**
/// calendar or timezone logic on purpose: `lib/core/time/date_windows.dart`
/// (task 9) owns day/week keys, and the caller converts those keys into the
/// bounds passed here.
@DriftAccessor(tables: [Meals, MealItems])
class MealDao extends DatabaseAccessor<AppDatabase> with _$MealDaoMixin {
  MealDao(super.attachedDatabase);

  // ---------------------------------------------------------------------
  // Meals
  // ---------------------------------------------------------------------

  /// Inserts a new meal; fails on a duplicate [Meals.id].
  Future<void> insertMeal(MealsCompanion meal) {
    return into(meals).insert(meal);
  }

  /// Replaces the stored meal identified by the companion's id.
  ///
  /// Returns false when no such row exists. Pass the complete record: drift's
  /// [UpdateStatement.replace] writes absent nullable fields as `NULL`.
  Future<bool> updateMeal(MealsCompanion meal) {
    return update(meals).replace(meal);
  }

  /// Deletes the meal; its items cascade away (foreign key, `ON DELETE
  /// CASCADE`). Returns the number of meals removed (0 or 1).
  Future<int> deleteMeal(String id) {
    return (delete(meals)..where((t) => t.id.equals(id))).go();
  }

  /// The meal with [id], or null when it does not exist.
  Future<MealRow?> getMeal(String id) {
    return (select(meals)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  /// Emits the meal with [id] on every change (null when absent).
  Stream<MealRow?> watchMeal(String id) {
    final query = select(meals)..where((t) => t.id.equals(id));
    return query.watchSingleOrNull();
  }

  /// Meals in `[startInclusive, endExclusive)`, ordered by timestamp.
  Future<List<MealRow>> getMealsInRange({
    required DateTime startInclusive,
    required DateTime endExclusive,
  }) {
    return _mealsInRange(
      startInclusive: startInclusive,
      endExclusive: endExclusive,
    ).get();
  }

  // ---------------------------------------------------------------------
  // Items
  // ---------------------------------------------------------------------

  /// Inserts a new item; fails on a duplicate [MealItems.id] or when
  /// [MealItems.mealId] has no parent meal (foreign key).
  Future<void> insertItem(MealItemsCompanion item) {
    return into(mealItems).insert(item);
  }

  /// Inserts all [items] in a single batch.
  Future<void> insertItems(Iterable<MealItemsCompanion> items) {
    return batch((b) => b.insertAll(mealItems, items));
  }

  /// Replaces the stored item identified by the companion's id.
  ///
  /// Returns false when no such row exists; absent nullable fields become
  /// `NULL` (full-row replace).
  Future<bool> updateItem(MealItemsCompanion item) {
    return update(mealItems).replace(item);
  }

  /// Deletes one item; returns the number of rows removed.
  Future<int> deleteItem(String id) {
    return (delete(mealItems)..where((t) => t.id.equals(id))).go();
  }

  /// The items of [mealId], ordered by item id.
  Future<List<MealItemRow>> getItemsForMeal(String mealId) {
    return (select(mealItems)
          ..where((t) => t.mealId.equals(mealId))
          ..orderBy([(t) => OrderingTerm.asc(t.id)]))
        .get();
  }

  /// Emits the items of [mealId] on every change, ordered by item id.
  Stream<List<MealItemRow>> watchItemsForMeal(String mealId) {
    final query = select(mealItems)
      ..where((t) => t.mealId.equals(mealId))
      ..orderBy([(t) => OrderingTerm.asc(t.id)]);
    return query.watch();
  }

  /// Distinct ids of the meals that contain an item linked to [foodId]
  /// (`meal_items.food_id` is a back-link, not a foreign key). A meal that
  /// links the food on several items must come back once — the recompute flow
  /// reports the count to the user and rewrites each listed meal.
  Future<List<String>> getMealIdsForFood(String foodId) async {
    final query = selectOnly(mealItems, distinct: true)
      ..addColumns([mealItems.mealId])
      ..where(mealItems.foodId.equals(foodId));
    final rows = await query.get();
    return <String>[for (final row in rows) row.read(mealItems.mealId)!];
  }

  /// Writes [meal] and its [items] in one transaction, so a `watch` stream
  /// never observes a half-saved meal (task 22's save path).
  Future<void> saveMealWithItems({
    required MealsCompanion meal,
    required List<MealItemsCompanion> items,
  }) {
    return transaction(() async {
      await into(meals).insert(meal);
      await batch((b) => b.insertAll(mealItems, items));
    });
  }

  /// Updates the meal row by the companion's id and swaps its items for
  /// [items], atomically.
  ///
  /// The edit flow's "complete record" write: the row's editable columns are
  /// written, then the stored item list is deleted and reinserted, so a row
  /// the editor removed cannot survive (item ids may be the original ones or
  /// fresh ones — everything is deleted first, so either lands cleanly).
  /// Only the columns present in the companion are written, a column absent
  /// from it (the schema-v2 `notes`) is left untouched. Throws [StateError]
  /// when no meal with that id exists, so a stale editor surfaces an error
  /// instead of silently doing nothing.
  Future<void> replaceMealWithItems({
    required MealsCompanion meal,
    required List<MealItemsCompanion> items,
  }) {
    return transaction(() async {
      final String id = meal.id.value;
      final int updated = await (update(
        meals,
      )..where((t) => t.id.equals(id))).write(meal);
      if (updated == 0) {
        throw StateError('no meal to update: $id');
      }
      await (delete(mealItems)..where((t) => t.mealId.equals(id))).go();
      await batch((b) => b.insertAll(mealItems, items));
    });
  }

  // ---------------------------------------------------------------------
  // Reactive instant windows (bounds supplied by the caller)
  // ---------------------------------------------------------------------

  /// Meals **with their items** in the arbitrary window
  /// `[startInclusive, endExclusive)`, ordered by meal timestamp.
  ///
  /// The generic window query. Day and week windows are just ranges as well, so
  /// [watchMealsForDay] / [watchMealsForWeek] delegate here and there is exactly
  /// one query definition to keep correct.
  Stream<List<MealWithItemRows>> watchMealsInRange({
    required DateTime startInclusive,
    required DateTime endExclusive,
  }) {
    return _mealsWithItemsInRange(
      startInclusive: startInclusive,
      endExclusive: endExclusive,
    ).watch().map(_groupJoinedRows);
  }

  /// Meals **with their items** in the day window
  /// `[dayStartInclusive, dayEndExclusive)`, ordered by meal timestamp.
  Stream<List<MealWithItemRows>> watchMealsForDay({
    required DateTime dayStartInclusive,
    required DateTime dayEndExclusive,
  }) {
    return watchMealsInRange(
      startInclusive: dayStartInclusive,
      endExclusive: dayEndExclusive,
    );
  }

  /// Meals **with their items** in the week window
  /// `[weekStartInclusive, weekEndExclusive)`, ordered by meal timestamp.
  Stream<List<MealWithItemRows>> watchMealsForWeek({
    required DateTime weekStartInclusive,
    required DateTime weekEndExclusive,
  }) {
    return watchMealsInRange(
      startInclusive: weekStartInclusive,
      endExclusive: weekEndExclusive,
    );
  }

  /// Emits the single meal [id] **with its items** on every change.
  ///
  /// Emits an empty list when the meal does not exist; the repository maps that
  /// to `null`. Items are ordered by id, matching the window queries.
  Stream<List<MealWithItemRows>> watchMealWithItems(String id) {
    final query = select(meals)
        .join([leftOuterJoin(mealItems, mealItems.mealId.equalsExp(meals.id))]);
    return (query
          ..where(meals.id.equals(id))
          ..orderBy([OrderingTerm.asc(mealItems.id)]))
        .watch()
        .map(_groupJoinedRows);
  }

  /// One-shot variant of `watchMealsInRange` (and of the day/week wrappers).
  Future<List<MealWithItemRows>> getMealsWithItemsInRange({
    required DateTime startInclusive,
    required DateTime endExclusive,
  }) async {
    final rows = await _mealsWithItemsInRange(
      startInclusive: startInclusive,
      endExclusive: endExclusive,
    ).get();
    return _groupJoinedRows(rows);
  }

  JoinedSelectStatement<HasResultSet, dynamic> _mealsWithItemsInRange({
    required DateTime startInclusive,
    required DateTime endExclusive,
  }) {
    final query = select(meals)
        .join([leftOuterJoin(mealItems, mealItems.mealId.equalsExp(meals.id))]);
    return query
      ..where(
        meals.timestamp.isBiggerOrEqualValue(startInclusive) &
            meals.timestamp.isSmallerThanValue(endExclusive),
      )
      ..orderBy([
        OrderingTerm.asc(meals.timestamp),
        OrderingTerm.asc(mealItems.id),
      ]);
  }

  SimpleSelectStatement<$MealsTable, MealRow> _mealsInRange({
    required DateTime startInclusive,
    required DateTime endExclusive,
  }) {
    return select(meals)
      ..where(
        (t) =>
            t.timestamp.isBiggerOrEqualValue(startInclusive) &
            t.timestamp.isSmallerThanValue(endExclusive),
      )
      ..orderBy([(t) => OrderingTerm.asc(t.timestamp)]);
  }

  /// Collapses the `meals LEFT JOIN meal_items` rows into meal+items groups,
  /// preserving the query's meal order.
  List<MealWithItemRows> _groupJoinedRows(List<TypedResult> rows) {
    final mealsById = <String, MealRow>{};
    final itemsByMeal = <String, List<MealItemRow>>{};

    for (final row in rows) {
      final meal = row.readTable(meals);
      mealsById.putIfAbsent(meal.id, () {
        itemsByMeal[meal.id] = <MealItemRow>[];
        return meal;
      });
      final item = row.readTableOrNull(mealItems);
      if (item != null) {
        itemsByMeal[meal.id]!.add(item);
      }
    }

    return [
      for (final entry in mealsById.entries)
        (meal: entry.value, items: itemsByMeal[entry.key]!),
    ];
  }
}
