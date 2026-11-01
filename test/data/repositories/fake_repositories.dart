/// In-memory fake repository implementations.
///
/// These are the **second** implementation of every repository port, used to
/// prove that callers (and the shared contract suite) depend on the interface,
/// not on Drift. They deliberately mirror the Drift schema's observable
/// storage semantics:
/// * `DateTime` is kept at whole-second precision and read back as a
///   local-flagged instant (drift maps `dateTime()` to unix seconds);
/// * row identifiers are globally unique (`meals.id`, `meal_items.id`,
///   `foods.id`, `exercises.id` are primary keys);
/// * deleting a meal deletes its items (FK cascade), while deleting a food
///   leaves logged items untouched (no FK on `meal_items.food_id`);
/// * catalogue/list results keep the same ordering as the DAO queries
///   (foods by name, meals by timestamp, items by id).
///
/// Change notifications are emitted after a write, the way drift's query
/// streams re-emit after a statement. An idempotent no-op (deleting a missing
/// row) emits nothing.
library;

import 'dart:async';

import 'package:caldoo/core/time/date_windows.dart' show MealWithItems;
import 'package:caldoo/domain/models/models.dart';
import 'package:caldoo/domain/repositories/repositories.dart';
import 'package:caldoo/domain/services/label_priority.dart';

/// The whole-second, locally-flagged instant drift stores for a `dateTime()`.
///
/// Drift writes `millisecondsSinceEpoch ~/ 1000` and reads the value back with
/// `DateTime.fromMillisecondsSinceEpoch(seconds * 1000)`; the fakes apply the
/// same truncation so a sub-second fixture can never round-trip differently
/// between the two implementations.
DateTime storedInstant(DateTime instant) => DateTime.fromMillisecondsSinceEpoch(
  (instant.millisecondsSinceEpoch ~/ 1000) * 1000,
);

/// In-memory [ProfileRepository] over a single nullable field.
class FakeProfileRepository implements ProfileRepository {
  UserProfile? _profile;
  final StreamController<UserProfile?> _changes =
      StreamController<UserProfile?>.broadcast();

  @override
  Future<UserProfile?> loadProfile() async => _profile;

  @override
  Future<void> saveProfile(UserProfile profile) async {
    _profile = profile;
    _changes.add(profile);
  }

  @override
  Stream<UserProfile?> watchProfile() async* {
    yield _profile;
    yield* _changes.stream;
  }

  @override
  Future<void> clearProfile() async {
    if (_profile == null) {
      return;
    }
    _profile = null;
    _changes.add(null);
  }

  /// Closes the change stream; call from `tearDown`.
  Future<void> dispose() => _changes.close();
}

/// In-memory [FoodRepository] over a `id -> Food` map.
class FakeFoodRepository implements FoodRepository {
  final Map<String, Food> _foods = <String, Food>{};
  final StreamController<void> _changes = StreamController<void>.broadcast();

  @override
  Future<void> insertFood(Food food) async {
    if (_foods.containsKey(food.id)) {
      throw StateError('duplicate food id: ${food.id}');
    }
    _foods[food.id] = food;
    _changes.add(null);
  }

  @override
  Future<void> upsertFood(Food food) async {
    _foods[food.id] = food;
    _changes.add(null);
  }

  @override
  Future<Food?> getFood(String id) async => _foods[id];

  @override
  Future<List<Food>> getAllFoods() async => _byName();

  @override
  Stream<Food?> watchFood(String id) async* {
    yield _foods[id];
    yield* _changes.stream.map((_) => _foods[id]);
  }

  @override
  Stream<List<Food>> watchAllFoods() async* {
    yield _byName();
    yield* _changes.stream.map((_) => _byName());
  }

  @override
  Future<List<Food>> searchByNormalizedName(String rawName) async {
    final key = normalizeName(rawName);
    if (key.isEmpty) {
      return const <Food>[];
    }
    return <Food>[
      for (final food in _byName())
        if (normalizeName(food.name) == key) food,
    ];
  }

  @override
  Future<void> deleteFood(String id) async {
    if (_foods.remove(id) != null) {
      _changes.add(null);
    }
  }

  /// Closes the change stream; call from `tearDown`.
  Future<void> dispose() => _changes.close();

  List<Food> _byName() {
    final list = _foods.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return list;
  }
}

/// In-memory [MealRepository] over meal/item maps, cascade-aware.
class FakeMealRepository implements MealRepository {
  final Map<String, Meal> _meals = <String, Meal>{};
  final Map<String, List<MealItem>> _itemsByMeal = <String, List<MealItem>>{};

  /// Item id -> owning meal id; mirrors the `meal_items.id` primary key so a
  /// duplicate id across meals fails exactly like the database would.
  final Map<String, String> _itemOwner = <String, String>{};
  final StreamController<void> _changes = StreamController<void>.broadcast();

  @override
  Future<void> saveMealWithItems(Meal meal, List<MealItem> items) async {
    if (_meals.containsKey(meal.id)) {
      throw StateError('duplicate meal id: ${meal.id}');
    }
    for (final item in items) {
      if (_itemOwner.containsKey(item.id)) {
        throw StateError('duplicate meal item id: ${item.id}');
      }
    }

    _meals[meal.id] = meal.copyWith(timestamp: storedInstant(meal.timestamp));
    _itemsByMeal[meal.id] = List<MealItem>.of(items);
    for (final item in items) {
      _itemOwner[item.id] = meal.id;
    }
    _changes.add(null);
  }

  @override
  Future<void> updateMealWithItems(Meal meal, List<MealItem> items) async {
    if (!_meals.containsKey(meal.id)) {
      throw StateError('no meal to update: ${meal.id}');
    }
    final Set<String> seen = <String>{};
    for (final item in items) {
      if (!seen.add(item.id)) {
        throw StateError('duplicate meal item id: ${item.id}');
      }
      final String? owner = _itemOwner[item.id];
      if (owner != null && owner != meal.id) {
        throw StateError('meal item id owned by another meal: ${item.id}');
      }
    }

    _meals[meal.id] = meal.copyWith(timestamp: storedInstant(meal.timestamp));
    // Swap the item list wholesale, exactly like the DAO transaction: rows the
    // editor dropped disappear, and a re-inserted original id re-owns cleanly.
    for (final item in _itemsByMeal[meal.id] ?? const <MealItem>[]) {
      _itemOwner.remove(item.id);
    }
    _itemsByMeal[meal.id] = List<MealItem>.of(items);
    for (final item in items) {
      _itemOwner[item.id] = meal.id;
    }
    _changes.add(null);
  }

  @override
  Future<List<MealWithItems>> getMealsWithItemsForFood(String foodId) async {
    final meals = <MealWithItems>[
      for (final MapEntry<String, List<MealItem>> entry in _itemsByMeal.entries)
        if (entry.value.any((MealItem item) => item.foodId == foodId))
          (meal: _meals[entry.key]!, items: List<MealItem>.of(entry.value)),
    ];
    meals.sort((a, b) => a.meal.timestamp.compareTo(b.meal.timestamp));
    return meals;
  }

  @override
  Future<void> deleteMeal(String id) async {
    final items = _itemsByMeal.remove(id);
    if (items == null && !_meals.containsKey(id)) {
      return;
    }
    _meals.remove(id);
    for (final item in items ?? const <MealItem>[]) {
      _itemOwner.remove(item.id);
    }
    _changes.add(null);
  }

  @override
  Future<List<Meal>> getMealsInRange({
    required DateTime startInclusive,
    required DateTime endExclusive,
  }) async => _mealsInRange(startInclusive, endExclusive);

  @override
  Future<List<MealWithItems>> getMealsWithItemsInRange({
    required DateTime startInclusive,
    required DateTime endExclusive,
  }) async => _groupsInRange(startInclusive, endExclusive);

  @override
  Stream<List<MealWithItems>> watchMealsInRange({
    required DateTime startInclusive,
    required DateTime endExclusive,
  }) async* {
    yield _groupsInRange(startInclusive, endExclusive);
    yield* _changes.stream.map(
      (_) => _groupsInRange(startInclusive, endExclusive),
    );
  }

  @override
  Stream<List<MealWithItems>> watchMealsForDay({
    required DateTime dayStartInclusive,
    required DateTime dayEndExclusive,
  }) => watchMealsInRange(
    startInclusive: dayStartInclusive,
    endExclusive: dayEndExclusive,
  );

  @override
  Stream<List<MealWithItems>> watchMealsForWeek({
    required DateTime weekStartInclusive,
    required DateTime weekEndExclusive,
  }) => watchMealsInRange(
    startInclusive: weekStartInclusive,
    endExclusive: weekEndExclusive,
  );

  @override
  Stream<MealWithItems?> watchMealWithItems(String id) async* {
    yield _groupOf(id);
    yield* _changes.stream.map((_) => _groupOf(id));
  }

  MealWithItems? _groupOf(String id) {
    final meal = _meals[id];
    if (meal == null) {
      return null;
    }
    return (meal: meal, items: _itemsOf(id));
  }

  /// Closes the change stream; call from `tearDown`.
  Future<void> dispose() => _changes.close();

  List<Meal> _mealsInRange(DateTime startInclusive, DateTime endExclusive) {
    final start = storedInstant(startInclusive);
    final end = storedInstant(endExclusive);
    final list = <Meal>[
      for (final meal in _meals.values)
        if (!meal.timestamp.isBefore(start) && meal.timestamp.isBefore(end))
          meal,
    ]..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return list;
  }

  List<MealWithItems> _groupsInRange(
    DateTime startInclusive,
    DateTime endExclusive,
  ) {
    return <MealWithItems>[
      for (final meal in _mealsInRange(startInclusive, endExclusive))
        (meal: meal, items: _itemsOf(meal.id)),
    ];
  }

  List<MealItem> _itemsOf(String mealId) {
    final items = List<MealItem>.of(_itemsByMeal[mealId] ?? const <MealItem>[])
      ..sort((a, b) => a.id.compareTo(b.id));
    return items;
  }
}

/// In-memory [DailyExerciseRepository] over a `dayKey -> DailyExercise` map.
class FakeExerciseRepository implements DailyExerciseRepository {
  final Map<DateTime, DailyExercise> _byDay = <DateTime, DailyExercise>{};
  final StreamController<void> _changes = StreamController<void>.broadcast();

  @override
  Future<void> setKcal({required DateTime dayKey, required int kcal}) async {
    if (kcal <= 0) {
      if (_byDay.remove(dayKey) != null) {
        _changes.add(null);
      }
      return;
    }
    _byDay[dayKey] = DailyExercise(dayKey: dayKey, kcal: kcal);
    _changes.add(null);
  }

  @override
  Future<DailyExercise?> getDay(DateTime dayKey) async => _byDay[dayKey];

  @override
  Stream<DailyExercise?> watchDay(DateTime dayKey) async* {
    yield _byDay[dayKey];
    yield* _changes.stream.map((_) => _byDay[dayKey]);
  }

  @override
  Stream<List<DailyExercise>> watchRange({
    required DateTime startInclusive,
    required DateTime endExclusive,
  }) async* {
    yield _inRange(startInclusive, endExclusive);
    yield* _changes.stream.map((_) => _inRange(startInclusive, endExclusive));
  }

  /// Closes the change stream; call from `tearDown`.
  Future<void> dispose() => _changes.close();

  List<DailyExercise> _inRange(DateTime startInclusive, DateTime endExclusive) {
    final list = <DailyExercise>[
      for (final entry in _byDay.values)
        if (!entry.dayKey.isBefore(startInclusive) &&
            entry.dayKey.isBefore(endExclusive))
          entry,
    ]..sort((a, b) => a.dayKey.compareTo(b.dayKey));
    return list;
  }
}
