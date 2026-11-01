import 'package:drift/drift.dart';

/// One recorded body-weight value per local calendar day (`weight_entries`).
///
/// [dayKey] is a date-only key (`DateTime.utc(y, m, d)`, the shape
/// `dayKeyOf()` returns) and the primary key, so a day holds at most one
/// entry: re-recording a day overwrites it. [weightKg] is kilograms, positive,
/// fractional to two decimals.
///
/// The weight log is a HISTORY record; the profile's current `weightKg` (the
/// BMR input) is kept in sync on save by the repository — see
/// `DriftWeightRepository.saveWeight`.
@DataClassName('WeightEntryRow')
class WeightEntries extends Table {
  /// Date-only local-day key; one row per day.
  DateTimeColumn get dayKey => dateTime()();

  /// Body weight in kilograms (positive; up to two decimals).
  RealColumn get weightKg => real()();

  @override
  Set<Column> get primaryKey => {dayKey};
}
