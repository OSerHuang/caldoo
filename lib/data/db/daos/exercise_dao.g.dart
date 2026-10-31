// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'exercise_dao.dart';

// ignore_for_file: type=lint
mixin _$ExerciseDaoMixin on DatabaseAccessor<AppDatabase> {
  $DailyExercisesTable get dailyExercises => attachedDatabase.dailyExercises;
  ExerciseDaoManager get managers => ExerciseDaoManager(this);
}

class ExerciseDaoManager {
  final _$ExerciseDaoMixin _db;
  ExerciseDaoManager(this._db);
  $$DailyExercisesTableTableManager get dailyExercises =>
      $$DailyExercisesTableTableManager(
        _db.attachedDatabase,
        _db.dailyExercises,
      );
}
