// Drift exports its own SQL `isNull` helper, which clashes with the matcher.
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:caldoo/data/db/app_database.dart';
import 'package:caldoo/data/db/daos/user_profile_dao.dart';
import 'package:caldoo/domain/models/user_profile.dart';

import '_test_db.dart';

void main() {
  late AppDatabase db;
  var closedByTest = false;

  setUp(() {
    db = testDb();
    closedByTest = false;
  });

  tearDown(() async {
    if (!closedByTest) {
      await db.close();
    }
  });

  Future<void> save({
    Sex sex = Sex.male,
    DateTime? birthDate,
    double heightCm = 178,
    double weightKg = 72.5,
    int? bmrKcalOverride,
    int? dailyKcalGoalOverride,
    DailyGoalPreset? dailyGoalPreset,
  }) {
    return db.userProfileDao.saveProfile(
      sex: sex,
      birthDate: birthDate ?? DateTime.utc(1994, 5, 20),
      heightCm: heightCm,
      weightKg: weightKg,
      bmrKcalOverride: bmrKcalOverride,
      dailyKcalGoalOverride: dailyKcalGoalOverride,
      dailyGoalPreset: dailyGoalPreset,
    );
  }

  group('UserProfileDao', () {
    test('insert then read back every profile field', () async {
      final DateTime birthday = DateTime.utc(1985, 3, 14);
      await save(
        sex: Sex.female,
        birthDate: birthday,
        heightCm: 165.5,
        weightKg: 58.2,
        bmrKcalOverride: 1831,
      );

      final row = await db.userProfileDao.getProfile();

      expect(row, isNotNull);
      expect(row!.id, UserProfileDao.singleRowId);
      expect(row.sex, Sex.female);
      // Drift hands a `dateTime()` back as a local-flagged instant, so the
      // birthday is compared in its canonical date-only shape.
      final DateTime storedBirthday = canonicalBirthDate(row.birthDate.toUtc());
      expect(storedBirthday, birthday);
      expect(ageOnBirthday(storedBirthday, DateTime.utc(2026, 3, 14)), 41);
      expect(ageOnBirthday(storedBirthday, DateTime.utc(2026, 3, 13)), 40);
      expect(row.heightCm, 165.5);
      expect(row.weightKg, 58.2);
      expect(row.bmrKcalOverride, 1831);
    });

    test('saving again updates the single row in place', () async {
      await save(weightKg: 72.5);
      await save(
        sex: Sex.female,
        weightKg: 60,
        birthDate: DateTime.utc(1980, 12, 1),
      );

      final rows = await db.select(db.userProfiles).get();

      expect(rows, hasLength(1));
      expect(rows.single.sex, Sex.female);
      expect(
        canonicalBirthDate(rows.single.birthDate.toUtc()),
        DateTime.utc(1980, 12, 1),
      );
      expect(rows.single.weightKg, 60);
    });

    test('sex persists by name; the BMR override is stored verbatim', () async {
      await save(sex: Sex.female, bmrKcalOverride: 1726);

      final raw = await db
          .customSelect(
            'SELECT sex, birth_date, bmr_kcal_override FROM user_profile',
          )
          .getSingle();

      expect(raw.data['sex'], 'female');
      expect(raw.data['birth_date'], isNotNull);
      expect(raw.data['bmr_kcal_override'], 1726);
    });

    test('a null BMR override is stored as NULL ("auto" BMR)', () async {
      await save();

      final raw = await db
          .customSelect('SELECT bmr_kcal_override FROM user_profile')
          .getSingle();

      expect(raw.data['bmr_kcal_override'], isNull);
      expect((await db.userProfileDao.getProfile())!.bmrKcalOverride, isNull);
    });

    test('the goal preset persists by enum name, not ordinal', () async {
      await save(dailyGoalPreset: DailyGoalPreset.fastCut);

      final raw = await db
          .customSelect('SELECT daily_goal_preset FROM user_profile')
          .getSingle();

      expect(raw.data['daily_goal_preset'], 'fastCut');
      expect(
        (await db.userProfileDao.getProfile())!.dailyGoalPreset,
        DailyGoalPreset.fastCut,
      );
    });

    test('a null goal preset is stored as NULL next to a fixed goal', () async {
      await save(dailyKcalGoalOverride: 1399);

      final raw = await db
          .customSelect(
            'SELECT daily_kcal_goal_override, daily_goal_preset '
            'FROM user_profile',
          )
          .getSingle();

      expect(raw.data['daily_kcal_goal_override'], 1399);
      expect(raw.data['daily_goal_preset'], isNull);
      expect((await db.userProfileDao.getProfile())!.dailyGoalPreset, isNull);
    });

    test('the CHECK constraint rejects a second profile row', () async {
      await save();

      await expectLater(
        db
            .into(db.userProfiles)
            .insert(
              UserProfilesCompanion.insert(
                id: const Value<int>(1),
                sex: Sex.male,
                birthDate: DateTime.utc(2000, 1, 1),
                heightCm: 180,
                weightKg: 70,
              ),
            ),
        throwsA(
          isA<Exception>().having(
            (error) => error.toString(),
            'message',
            contains('CHECK constraint failed'),
          ),
        ),
      );
    });

    test('clearProfile deletes the row', () async {
      await save();

      expect(await db.userProfileDao.clearProfile(), 1);
      expect(await db.userProfileDao.getProfile(), isNull);
      expect(await db.userProfileDao.clearProfile(), 0);
    });

    test('watchProfile emits null, then the save, then the update', () async {
      final stream = db.userProfileDao.watchProfile();

      final expectation = expectLater(
        stream,
        emitsInOrder(<Object?>[
          isNull,
          isA<UserProfileRow>()
              .having((row) => row.sex, 'sex', Sex.male)
              .having((row) => row.weightKg, 'weightKg', 72.5),
          isA<UserProfileRow>()
              .having((row) => row.sex, 'sex', Sex.female)
              .having((row) => row.weightKg, 'weightKg', 60),
        ]),
      );

      // Let the initial (empty) event arrive before mutating.
      await pumpEventQueue();

      await save();
      await save(sex: Sex.female, weightKg: 60);

      await expectation;
    });
  });
}
