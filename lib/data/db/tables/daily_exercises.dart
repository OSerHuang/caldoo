import 'package:drift/drift.dart';

/// One editable exercise-burn value per local calendar day (`daily_exercises`).
///
/// [dayKey] is a date-only key (`DateTime.utc(y, m, d)`, the shape
/// `dayKeyOf()` returns) and the primary key, so a day has at most one burn.
/// [kcal] is added back to that day's budget by the energy engine.
@DataClassName('DailyExerciseRow')
class DailyExercises extends Table {
  /// Date-only local-day key; one row per day.
  DateTimeColumn get dayKey => dateTime()();

  /// Burn in **whole kcal** for that day (integer-only).
  IntColumn get kcal => integer()();

  @override
  Set<Column> get primaryKey => {dayKey};
}
