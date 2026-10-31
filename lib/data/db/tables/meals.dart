import 'package:drift/drift.dart';

import '../../../domain/models/meal.dart';

/// Logged meals: the grouping record that owns its meal items (`meals`).
///
/// [timestamp] is the instant the meal is attributed to; the DAO never resolves
/// it to a calendar day itself. Day/week windows arrive as explicit bounds
/// (see `lib/core/time/date_windows.dart`, which owns the timezone logic).
@DataClassName('MealRow')
class Meals extends Table {
  /// UUID of the meal.
  TextColumn get id => text()();

  /// The instant the meal is attributed to.
  DateTimeColumn get timestamp => dateTime()();

  /// Breakfast / lunch / dinner / snack; stored as the enum name.
  TextColumn get mealType => textEnum<MealType>()();

  /// Optional free-text note.
  TextColumn get note => text().nullable()();

  /// Optional free-text notes (added in schema v2 by task 33).
  ///
  /// This column is the schema change that introduces the genuine v1 -> v2
  /// migration: it is **nullable**, so the migration is a pure additive
  /// `ALTER TABLE meals ADD COLUMN notes TEXT` that cannot fail on existing
  /// rows and preserves every v1 meal. `note` above is the original v1 column
  /// and is left untouched, so the v1 snapshot in `drift_schemas/` stays
  /// authoritative for `migrateAndValidate`.
  TextColumn get notes => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
