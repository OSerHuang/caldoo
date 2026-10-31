/// Drift-backed [DailyExerciseRepository].
library;

import '../../domain/models/daily_exercise.dart';
import '../../domain/repositories/daily_exercise_repository.dart';
import '../db/app_database.dart';
import 'mappers.dart';

/// Stores the one-per-day exercise burn via `ExerciseDao`, returning domain
/// models only.
class DriftExerciseRepository implements DailyExerciseRepository {
  /// Creates the repository over [db].
  DriftExerciseRepository(this._db);

  final AppDatabase _db;

  @override
  Future<DailyExercise?> getDay(DateTime dayKey) async {
    final DailyExerciseRow? row = await _db.exerciseDao.getDay(dayKey);
    return row == null ? null : dailyExerciseFromRow(row);
  }

  @override
  Stream<DailyExercise?> watchDay(DateTime dayKey) {
    return _db.exerciseDao
        .watchDay(dayKey)
        .map((row) => row == null ? null : dailyExerciseFromRow(row));
  }

  @override
  Stream<List<DailyExercise>> watchRange({
    required DateTime startInclusive,
    required DateTime endExclusive,
  }) {
    return _db.exerciseDao
        .watchRange(startInclusive: startInclusive, endExclusive: endExclusive)
        .map(_rowsToDomain);
  }

  @override
  Future<void> setKcal({required DateTime dayKey, required int kcal}) async {
    if (kcal <= 0) {
      await _db.exerciseDao.deleteDay(dayKey);
      return;
    }
    await _db.exerciseDao.upsertKcal(dayKey: dayKey, kcal: kcal);
  }

  static List<DailyExercise> _rowsToDomain(List<DailyExerciseRow> rows) {
    return <DailyExercise>[for (final row in rows) dailyExerciseFromRow(row)];
  }
}
