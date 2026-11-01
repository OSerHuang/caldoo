import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/weight_entries.dart';

part 'weight_dao.g.dart';

/// Reads and writes [WeightEntries]: one body-weight value per local day.
///
/// [dayKey] is a date-only key supplied by the caller; there is no calendar or
/// timezone logic here (see `lib/core/time/date_windows.dart`). Range reads are
/// half-open `[startInclusive, endExclusive)`.
@DriftAccessor(tables: [WeightEntries])
class WeightDao extends DatabaseAccessor<AppDatabase> with _$WeightDaoMixin {
  WeightDao(super.attachedDatabase);

  /// Inserts or replaces the weight for [dayKey] (re-recording overwrites).
  Future<void> upsertWeight({
    required DateTime dayKey,
    required double weightKg,
  }) {
    return into(weightEntries).insertOnConflictUpdate(
      WeightEntriesCompanion.insert(dayKey: dayKey, weightKg: weightKg),
    );
  }

  /// The row for [dayKey], or null when the day has no weight.
  Future<WeightEntryRow?> getDay(DateTime dayKey) {
    return (select(
      weightEntries,
    )..where((t) => t.dayKey.equals(dayKey))).getSingleOrNull();
  }

  /// Emits the row for [dayKey] on every change (null when absent).
  Stream<WeightEntryRow?> watchDay(DateTime dayKey) {
    final query = select(weightEntries)..where((t) => t.dayKey.equals(dayKey));
    return query.watchSingleOrNull();
  }

  /// Emits the rows in `[startInclusive, endExclusive)`, ordered by day.
  Stream<List<WeightEntryRow>> watchRange({
    required DateTime startInclusive,
    required DateTime endExclusive,
  }) {
    return _inRange(
      startInclusive: startInclusive,
      endExclusive: endExclusive,
    ).watch();
  }

  /// Emits every row, ordered by day (the weight-history page's full series).
  Stream<List<WeightEntryRow>> watchAll() {
    final SimpleSelectStatement<$WeightEntriesTable, WeightEntryRow> query =
        select(weightEntries)..orderBy([(t) => OrderingTerm.asc(t.dayKey)]);
    return query.watch();
  }

  /// Deletes the row for [dayKey]; returns the number of rows removed.
  Future<int> deleteDay(DateTime dayKey) {
    return (delete(weightEntries)..where((t) => t.dayKey.equals(dayKey))).go();
  }

  SimpleSelectStatement<$WeightEntriesTable, WeightEntryRow> _inRange({
    required DateTime startInclusive,
    required DateTime endExclusive,
  }) {
    return select(weightEntries)
      ..where(
        (t) =>
            t.dayKey.isBiggerOrEqualValue(startInclusive) &
            t.dayKey.isSmallerThanValue(endExclusive),
      )
      ..orderBy([(t) => OrderingTerm.asc(t.dayKey)]);
  }
}
