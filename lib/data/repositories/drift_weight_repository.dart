/// Drift-backed [WeightRepository].
library;

import '../../domain/models/weight_entry.dart';
import '../../domain/repositories/weight_repository.dart';
import '../db/app_database.dart';
import 'mappers.dart';

/// Stores the one-per-day body weight via `WeightDao`, returning domain models
/// only.
///
/// [saveWeight] owns the profile sync: the weight history and the profile's
/// `weightKg` (the BMR input) are written in ONE transaction, so the derived
/// basal metabolism can never lag behind the latest measurement.
class DriftWeightRepository implements WeightRepository {
  /// Creates the repository over [db].
  DriftWeightRepository(this._db);

  final AppDatabase _db;

  @override
  Future<WeightEntry?> getDay(DateTime dayKey) async {
    final WeightEntryRow? row = await _db.weightDao.getDay(dayKey);
    return row == null ? null : weightEntryFromRow(row);
  }

  @override
  Stream<WeightEntry?> watchDay(DateTime dayKey) {
    return _db.weightDao
        .watchDay(dayKey)
        .map((row) => row == null ? null : weightEntryFromRow(row));
  }

  @override
  Stream<List<WeightEntry>> watchRange({
    required DateTime startInclusive,
    required DateTime endExclusive,
  }) {
    return _db.weightDao
        .watchRange(startInclusive: startInclusive, endExclusive: endExclusive)
        .map(_rowsToDomain);
  }

  @override
  Stream<List<WeightEntry>> watchAll() {
    return _db.weightDao.watchAll().map(_rowsToDomain);
  }

  @override
  Future<void> saveWeight({
    required DateTime dayKey,
    required double weightKg,
  }) async {
    if (!weightKg.isFinite || weightKg <= 0) {
      throw ArgumentError.value(
        weightKg,
        'weightKg',
        'must be finite and positive',
      );
    }
    await _db.transaction(() async {
      await _db.weightDao.upsertWeight(dayKey: dayKey, weightKg: weightKg);
      final UserProfileRow? profile = await _db.userProfileDao.getProfile();
      if (profile != null && profile.weightKg != weightKg) {
        // Rewrite the single row verbatim except the weight: the DAO's
        // saveProfile is the one upsert path, so no field can be dropped — in
        // particular the relative goal preset (which follows the weight) is
        // carried over unchanged, as is the legacy absolute goal.
        await _db.userProfileDao.saveProfile(
          sex: profile.sex,
          birthDate: profile.birthDate,
          heightCm: profile.heightCm,
          weightKg: weightKg,
          bmrKcalOverride: profile.bmrKcalOverride,
          dailyKcalGoalOverride: profile.dailyKcalGoalOverride,
          dailyGoalPreset: profile.dailyGoalPreset,
        );
      }
    });
  }

  @override
  Future<int> deleteDay(DateTime dayKey) {
    // Deliberately no profile rewind: deleting cleans the history, never the
    // BMR input (see the port contract).
    return _db.weightDao.deleteDay(dayKey);
  }

  static List<WeightEntry> _rowsToDomain(List<WeightEntryRow> rows) {
    return <WeightEntry>[for (final row in rows) weightEntryFromRow(row)];
  }
}
