import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/daily_exercises.dart';

part 'exercise_dao.g.dart';

/// Reads and writes [DailyExercises]: one burn value per local calendar day.
///
/// [dayKey] is a date-only key supplied by the caller; there is no calendar or
/// timezone logic here (see `lib/core/time/date_windows.dart`). Range reads are
/// half-open `[startInclusive, endExclusive)`.
@DriftAccessor(tables: [DailyExercises])
class ExerciseDao extends DatabaseAccessor<AppDatabase>
    with _$ExerciseDaoMixin {
  ExerciseDao(super.attachedDatabase);

  /// Inserts or replaces the whole-kcal burn for [dayKey].
  Future<void> upsertKcal({required DateTime dayKey, required int kcal}) {
    return into(dailyExercises).insertOnConflictUpdate(
      DailyExercisesCompanion.insert(dayKey: dayKey, kcal: kcal),
    );
  }

  /// The row for [dayKey], or null when the day has no burn.
  Future<DailyExerciseRow?> getDay(DateTime dayKey) {
    return (select(
      dailyExercises,
    )..where((t) => t.dayKey.equals(dayKey))).getSingleOrNull();
  }

  /// Emits the row for [dayKey] on every change (null when absent).
  Stream<DailyExerciseRow?> watchDay(DateTime dayKey) {
    final query = select(dailyExercises)..where((t) => t.dayKey.equals(dayKey));
    return query.watchSingleOrNull();
  }

  /// Emits the rows in `[startInclusive, endExclusive)`, ordered by day.
  Stream<List<DailyExerciseRow>> watchRange({
    required DateTime startInclusive,
    required DateTime endExclusive,
  }) {
    return _inRange(
      startInclusive: startInclusive,
      endExclusive: endExclusive,
    ).watch();
  }

  /// Deletes the row for [dayKey]; returns the number of rows removed.
  Future<int> deleteDay(DateTime dayKey) {
    return (delete(dailyExercises)..where((t) => t.dayKey.equals(dayKey))).go();
  }

  SimpleSelectStatement<$DailyExercisesTable, DailyExerciseRow> _inRange({
    required DateTime startInclusive,
    required DateTime endExclusive,
  }) {
    return select(dailyExercises)
      ..where(
        (t) =>
            t.dayKey.isBiggerOrEqualValue(startInclusive) &
            t.dayKey.isSmallerThanValue(endExclusive),
      )
      ..orderBy([(t) => OrderingTerm.asc(t.dayKey)]);
  }
}
