// The Drift-backed weight repository against the in-memory test database:
// the save contract (history + profile sync in one transaction), the
// overwrite-per-day rule and the no-rewind delete semantics.
//
// dart format width=80
import 'package:flutter_test/flutter_test.dart';
import 'package:caldoo/data/db/app_database.dart';
import 'package:caldoo/data/repositories/drift_weight_repository.dart';
import 'package:caldoo/data/repositories/mappers.dart' show userProfileFromRow;
import 'package:caldoo/domain/models/user_profile.dart'
    show DailyGoalPreset, Sex;
import 'package:caldoo/domain/models/weight_entry.dart';

import '../db/_test_db.dart';

void main() {
  late AppDatabase db;
  late DriftWeightRepository repo;

  setUp(() {
    db = testDb();
    repo = DriftWeightRepository(db);
  });

  tearDown(() => db.close());

  final DateTime day1 = DateTime.utc(2026, 10, 20);
  final DateTime day2 = DateTime.utc(2026, 10, 25);

  Future<void> seedProfile({
    DailyGoalPreset? dailyGoalPreset,
    int? dailyKcalGoalOverride,
  }) {
    return db.userProfileDao.saveProfile(
      sex: Sex.male,
      birthDate: DateTime.utc(1996, 10, 22),
      heightCm: 175,
      weightKg: 70,
      dailyGoalPreset: dailyGoalPreset,
      dailyKcalGoalOverride: dailyKcalGoalOverride,
    );
  }

  test(
    'saveWeight writes the history row and syncs the profile weight',
    () async {
      await seedProfile();
      await repo.saveWeight(dayKey: day1, weightKg: 68.4);

      final row = await db.weightDao.getDay(day1);
      expect(row, isNotNull);
      expect(row!.weightKg, 68.4);

      final profile = userProfileFromRow(
        (await db.userProfileDao.getProfile())!,
      );
      expect(
        profile.weightKg,
        68.4,
        reason: 'BMR input follows the measurement',
      );
    },
  );

  test(
    'saveWeight preserves the profile goal (preset and legacy absolute)',
    () async {
      // A relative preset must survive the weight sync: it follows the BMR, so
      // dropping it would silently reset the user's goal.
      await seedProfile(dailyGoalPreset: DailyGoalPreset.slowCut);
      await repo.saveWeight(dayKey: day1, weightKg: 68.4);

      var profile = userProfileFromRow((await db.userProfileDao.getProfile())!);
      expect(profile.weightKg, 68.4);
      expect(
        profile.dailyGoalPreset,
        DailyGoalPreset.slowCut,
        reason: 'the relative goal is carried over, not dropped',
      );
      expect(profile.dailyKcalGoalOverride, isNull);

      // A legacy absolute goal keeps its fixed custom value on a weight change.
      await seedProfile(dailyKcalGoalOverride: 1399);
      await repo.saveWeight(dayKey: day2, weightKg: 67.9);

      profile = userProfileFromRow((await db.userProfileDao.getProfile())!);
      expect(profile.weightKg, 67.9);
      expect(
        profile.dailyKcalGoalOverride,
        1399,
        reason: 'the legacy absolute goal stays fixed',
      );
      expect(profile.dailyGoalPreset, isNull);
    },
  );

  test('saveWeight without a profile only writes the history row', () async {
    await repo.saveWeight(dayKey: day1, weightKg: 68.4);
    expect(await db.userProfileDao.getProfile(), isNull);
    expect(await db.weightDao.getDay(day1), isNotNull);
  });

  test('re-recording a day overwrites it (one row per day)', () async {
    await repo.saveWeight(dayKey: day1, weightKg: 68.4);
    await repo.saveWeight(dayKey: day1, weightKg: 68.0);

    final rows = await db.select(db.weightEntries).get();
    expect(rows, hasLength(1));
    expect(rows.single.weightKg, 68.0);
  });

  test('watchAll emits entries ordered by day, live', () async {
    await repo.saveWeight(dayKey: day2, weightKg: 68.0);
    await repo.saveWeight(dayKey: day1, weightKg: 68.9);

    final entries = await repo.watchAll().first;
    expect(entries.map((WeightEntry e) => e.dayKey), <DateTime>[day1, day2]);
    expect(entries.map((WeightEntry e) => e.weightKg), <double>[68.9, 68.0]);
  });

  test(
    'deleteDay removes the history row but does NOT rewind the profile',
    () async {
      await seedProfile();
      await repo.saveWeight(dayKey: day1, weightKg: 68.4);
      await repo.deleteDay(day1);

      expect(await db.weightDao.getDay(day1), isNull);
      final profile = userProfileFromRow(
        (await db.userProfileDao.getProfile())!,
      );
      expect(
        profile.weightKg,
        68.4,
        reason: 'deleting cleans the history, never the BMR input',
      );
    },
  );

  test('a non-finite or non-positive weight throws', () async {
    for (final double bad in <double>[0, -1, double.nan, double.infinity]) {
      expect(
        () => repo.saveWeight(dayKey: day1, weightKg: bad),
        throwsArgumentError,
        reason: 'weightKg=$bad',
      );
    }
  });
}
