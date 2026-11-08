// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'meal_template_dao.dart';

// ignore_for_file: type=lint
mixin _$MealTemplateDaoMixin on DatabaseAccessor<AppDatabase> {
  $MealTemplatesTable get mealTemplates => attachedDatabase.mealTemplates;
  MealTemplateDaoManager get managers => MealTemplateDaoManager(this);
}

class MealTemplateDaoManager {
  final _$MealTemplateDaoMixin _db;
  MealTemplateDaoManager(this._db);
  $$MealTemplatesTableTableManager get mealTemplates =>
      $$MealTemplatesTableTableManager(_db.attachedDatabase, _db.mealTemplates);
}
