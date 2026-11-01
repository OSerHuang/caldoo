import 'package:drift/drift.dart';

import '../../../domain/models/user_profile.dart';

/// The single-row user profile (`user_profile`).
///
/// Holds exactly one row, enforced by the fixed primary key
/// (`UserProfileDao.singleRowId` = `0`) plus a `CHECK (id = 0)` constraint, so
/// a bug can never leave two competing profiles behind.
///
/// Enums are stored as their **name** (text), not their ordinal: reordering a
/// Dart enum must never silently re-interpret already-stored rows.
@DataClassName('UserProfileRow')
class UserProfiles extends Table {
  @override
  String get tableName => 'user_profile';

  /// Fixed primary key of the single profile row; always `0`.
  IntColumn get id => integer().withDefault(const Constant(0))();

  /// Biological sex (see [Sex]); stored as the enum name.
  TextColumn get sex => textEnum<Sex>()();

  /// Birthday as a canonical date-only value (UTC midnight, see
  /// [canonicalBirthDate]). The age is derived from it at use time, so it never
  /// goes stale and never needs a yearly edit.
  DateTimeColumn get birthDate => dateTime()();

  /// Height in centimetres.
  RealColumn get heightCm => real()();

  /// Weight in kilograms (editable; BMR recomputes on change).
  RealColumn get weightKg => real()();

  /// User-set basal metabolic rate override in **whole kcal/day**.
  ///
  /// `NULL` means "derive it": the profile has no activity-level column, so the
  /// engine falls back to the Mifflin-St Jeor estimate from the anthropometrics
  /// above. A user who knows their own BMR can pin it here and it wins. Energy
  /// is integer-only, so this is an INTEGER column.
  IntColumn get bmrKcalOverride => integer().nullable()();

  /// User-set daily energy goal in **whole kcal/day**, or `NULL` when no goal
  /// is set (the budget then stays "maintain": the resolved BMR).
  ///
  /// Same contract as [bmrKcalOverride]: an explicit number the user picked,
  /// stored as INTEGER; `NULL` reads as "no goal", never as 0.
  IntColumn get dailyKcalGoalOverride => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  /// Hard "single row" guarantee: only the fixed [id] `0` may be written.
  @override
  List<String> get customConstraints => const <String>['CHECK (id = 0)'];
}
