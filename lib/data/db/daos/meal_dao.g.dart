// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'meal_dao.dart';

// ignore_for_file: type=lint
mixin _$MealDaoMixin on DatabaseAccessor<AppDatabase> {
  $MealsTable get meals => attachedDatabase.meals;
  $MealItemsTable get mealItems => attachedDatabase.mealItems;
  MealDaoManager get managers => MealDaoManager(this);
}

class MealDaoManager {
  final _$MealDaoMixin _db;
  MealDaoManager(this._db);
  $$MealsTableTableManager get meals =>
      $$MealsTableTableManager(_db.attachedDatabase, _db.meals);
  $$MealItemsTableTableManager get mealItems =>
      $$MealItemsTableTableManager(_db.attachedDatabase, _db.mealItems);
}
