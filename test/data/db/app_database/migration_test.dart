// dart format width=80
// This file originated from `dart run drift_dev make-migrations` and has been
// adapted (task 33) to assert REAL data integrity for the v1 -> v2 migration:
// v1 seeded meal rows must survive the migration, and the newly added nullable
// `notes` column must read as NULL on preserved rows and be writable afterwards.
// Drift exports its own SQL `isNull`/`isNotNull` helpers, which clash with the
// matchers of the same name.
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:caldoo/data/db/app_database.dart';
import 'package:caldoo/data/repositories/mappers.dart' show foodFromRow;
import 'package:caldoo/domain/models/food.dart' show FoodStatus, MeasureBasis;
import 'package:caldoo/domain/models/user_profile.dart';

import 'generated/schema.dart';
import 'generated/schema_v1.dart' as v1;
import 'generated/schema_v2.dart' as v2;
import 'generated/schema_v3.dart' as v3;
import 'generated/schema_v4.dart' as v4;
import 'generated/schema_v5.dart' as v5;
import 'generated/schema_v6.dart' as v6;
import 'generated/schema_v7.dart' as v7;
import 'generated/schema_v8.dart' as v8;
import 'generated/schema_v9.dart' as v9;
import 'generated/schema_v10.dart' as v10;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  group('simple database migrations', () {
    // Verify every schema update with a data-less migration: this ensures the
    // written migrations actually produce the expected v2 schema.
    const versions = GeneratedHelper.versions;
    for (final (i, fromVersion) in versions.indexed) {
      group('from $fromVersion', () {
        for (final toVersion in versions.skip(i + 1)) {
          test('to $toVersion', () async {
            final schema = await verifier.schemaAt(fromVersion);
            final db = AppDatabase.forTesting(schema.newConnection());
            await verifier.migrateAndValidate(db, toVersion);
            await db.close();
          });
        }
      });
    }
  });

  group('v1 -> v2 data integrity', () {
    const mealId = 'meal-1';
    const noteMealId = 'meal-2';
    const itemId = 'item-1';

    // Drift stores DateTime as unix SECONDS (`millisecondsSinceEpoch ~/ 1000`),
    // which is why the versioned schema data classes carry a raw `int`.
    const lunchTs = 1735689600; // 2025-01-01T12:00:00Z
    const breakfastTs = 1735668000; // 2025-01-01T06:00:00Z

    final oldMealsData = <v1.MealsData>[
      const v1.MealsData(
        id: mealId,
        timestamp: lunchTs,
        mealType: 'lunch',
        note: '工作日午餐',
      ),
      // A row whose nullable `note` is NULL must migrate to `notes` = NULL too.
      const v1.MealsData(
        id: noteMealId,
        timestamp: breakfastTs,
        mealType: 'breakfast',
      ),
    ];

    final oldMealItemsData = <v1.MealItemsData>[
      const v1.MealItemsData(
        id: itemId,
        mealId: mealId,
        name: '米饭',
        grams: 200,
        kcal: 232,
        carbG: 51.6,
        proteinG: 4.2,
        fatG: 0.6,
        saltG: 0.01,
        source: 'ai',
        confidence: 0.8,
      ),
    ];

    final oldAppSettingsData = <v1.AppSettingsData>[
      const v1.AppSettingsData(key: 'notice_seen', value: 'true'),
    ];

    test(
      'preserves v1 meal/item/settings rows and adds a NULL notes column',
      () async {
        await verifier.testWithDataIntegrity(
          oldVersion: 1,
          newVersion: 2,
          createOld: v1.DatabaseAtV1.new,
          createNew: v2.DatabaseAtV2.new,
          openTestedDatabase: AppDatabase.forTesting,
          createItems: (batch, oldDb) {
            batch.insertAll(oldDb.appSettings, oldAppSettingsData);
            batch.insertAll(oldDb.meals, oldMealsData);
            batch.insertAll(oldDb.mealItems, oldMealItemsData);
          },
          validateItems: (newDb) async {
            final settings = await newDb.select(newDb.appSettings).get();
            expect(settings, hasLength(1));
            expect(settings.single.key, 'notice_seen');
            expect(settings.single.value, 'true');

            final meals = await newDb.select(newDb.meals).get();
            expect(meals, hasLength(2));

            final lunch = meals.singleWhere((row) => row.id == mealId);
            expect(lunch.timestamp, lunchTs);
            expect(lunch.mealType, 'lunch');
            expect(lunch.note, '工作日午餐');
            // The column introduced by v2 defaults to NULL for existing rows.
            expect(lunch.notes, isNull);

            final breakfast = meals.singleWhere((row) => row.id == noteMealId);
            expect(breakfast.timestamp, breakfastTs);
            expect(breakfast.mealType, 'breakfast');
            expect(breakfast.note, isNull);
            expect(breakfast.notes, isNull);

            final items = await newDb.select(newDb.mealItems).get();
            expect(items, hasLength(1));
            final item = items.single;
            expect(item.id, itemId);
            expect(item.mealId, mealId);
            expect(item.name, '米饭');
            expect(item.grams, 200);
            expect(item.kcal, 232);
            expect(item.carbG, 51.6);
            expect(item.proteinG, 4.2);
            expect(item.fatG, 0.6);
            expect(item.saltG, 0.01);
            expect(item.source, 'ai');
            expect(item.confidence, 0.8);
          },
        );
      },
    );

    test('the app database reads the migrated meal and `notes` is writable', () async {
      final schema = await verifier.schemaAt(1);

      // Seed the v1 database through the generated v1 schema class.
      final oldDb = v1.DatabaseAtV1(schema.newConnection());
      await oldDb.batch((batch) {
        batch.insertAll(oldDb.meals, oldMealsData);
        batch.insertAll(oldDb.mealItems, oldMealItemsData);
      });
      await oldDb.close();

      // Open the REAL app database against the v1 file and migrate all the way
      // to the current schema (the DAO below always speaks the current shape;
      // the intermediate steps have their own schema-shape coverage above).
      final db = AppDatabase.forTesting(schema.newConnection());
      await verifier.migrateAndValidate(db, 10);

      final meal = await db.mealDao.getMeal(mealId);
      expect(meal, isNotNull);
      expect(meal!.mealType.name, 'lunch');
      expect(meal.note, '工作日午餐');
      expect(meal.notes, isNull);
      // Drift reads unix seconds back as a local DateTime; assert the instant.
      expect(meal.timestamp.millisecondsSinceEpoch, lunchTs * 1000);

      final items = await db.mealDao.getItemsForMeal(mealId);
      expect(items, hasLength(1));
      expect(items.single.name, '米饭');
      expect(items.single.grams, 200);

      // The new nullable column is writable on a row that predates v2.
      await (db.update(db.meals)..where((t) => t.id.equals(mealId))).write(
        const MealsCompanion(notes: Value('迁移后写入')),
      );
      final updated = await db.mealDao.getMeal(mealId);
      expect(updated!.notes, '迁移后写入');
      expect(updated.note, '工作日午餐');

      await db.close();
      schema.close();
    });
  });

  group('v3 -> v4 data integrity', () {
    const foodId = 'food-1';

    final oldFoodsData = <v3.FoodsData>[
      const v3.FoodsData(
        id: foodId,
        name: '全麦面包',
        brand: '某品牌',
        barcode: '6900000000001',
        source: 'label',
        kcal: 250.5,
        carbG: 45.25,
        proteinG: 9.5,
        fatG: 3.75,
        sodiumMg: 320,
      ),
    ];

    test('preserves foods and adds a NULL notes column', () async {
      await verifier.testWithDataIntegrity(
        oldVersion: 3,
        newVersion: 4,
        createOld: v3.DatabaseAtV3.new,
        createNew: v4.DatabaseAtV4.new,
        openTestedDatabase: AppDatabase.forTesting,
        createItems: (batch, oldDb) {
          batch.insertAll(oldDb.foods, oldFoodsData);
        },
        validateItems: (newDb) async {
          final foods = await newDb.select(newDb.foods).get();
          expect(foods, hasLength(1));
          final food = foods.single;
          expect(food.id, foodId);
          expect(food.name, '全麦面包');
          expect(food.brand, '某品牌');
          expect(food.barcode, '6900000000001');
          expect(food.source, 'label');
          expect(food.kcal, 250.5);
          expect(food.carbG, 45.25);
          expect(food.proteinG, 9.5);
          expect(food.fatG, 3.75);
          expect(food.sodiumMg, 320);
          // The column introduced by v4 defaults to NULL for existing rows.
          expect(food.notes, isNull);
        },
      );
    });

    test(
      'the new notes column is writable on a row that predates v4',
      () async {
        final schema = await verifier.schemaAt(3);
        final oldDb = v3.DatabaseAtV3(schema.newConnection());
        await oldDb.batch((batch) {
          batch.insertAll(oldDb.foods, oldFoodsData);
        });
        await oldDb.close();

        final db = AppDatabase.forTesting(schema.newConnection());
        await verifier.migrateAndValidate(db, 10);

        final food = await db.foodDao.getFood(foodId);
        expect(food, isNotNull);
        expect(food!.notes, isNull);

        await (db.update(db.foods)..where((t) => t.id.equals(foodId))).write(
          const FoodsCompanion(notes: Value('一包 45 g；别名：小饼干')),
        );
        final updated = await db.foodDao.getFood(foodId);
        expect(updated!.notes, '一包 45 g；别名：小饼干');
        expect(updated.name, '全麦面包');

        await db.close();
        schema.close();
      },
    );
  });

  group('v2 -> v3 data integrity', () {
    const mealId = 'meal-1';
    const lunchTs = 1735689600; // 2025-01-01T12:00:00Z

    final oldMealsData = <v2.MealsData>[
      const v2.MealsData(
        id: mealId,
        timestamp: lunchTs,
        mealType: 'lunch',
        note: '工作日午餐',
      ),
    ];

    // A v2 session row; the migration deliberately discards these.
    final oldExercisesData = <v2.ExercisesData>[
      const v2.ExercisesData(
        id: 'e1',
        timestamp: lunchTs,
        type: '跑步',
        minutes: 30,
        met: 8,
        kcal: 250,
        overridden: 0,
      ),
    ];

    test('drops the old exercises table, adds an empty daily_exercises, keeps '
        'meals', () async {
      await verifier.testWithDataIntegrity(
        oldVersion: 2,
        newVersion: 3,
        createOld: v2.DatabaseAtV2.new,
        createNew: v3.DatabaseAtV3.new,
        openTestedDatabase: AppDatabase.forTesting,
        createItems: (batch, oldDb) {
          batch.insertAll(oldDb.meals, oldMealsData);
          batch.insertAll(oldDb.exercises, oldExercisesData);
        },
        validateItems: (newDb) async {
          // Meals survive untouched.
          final meals = await newDb.select(newDb.meals).get();
          expect(meals, hasLength(1));
          expect(meals.single.id, mealId);
          expect(meals.single.note, '工作日午餐');

          // The new table exists and is empty: no value migration.
          final daily = await newDb.select(newDb.dailyExercises).get();
          expect(daily, isEmpty);
        },
      );
    });
  });

  group('v4 -> v5 data integrity', () {
    // A v4 profile still carries the NEAT `activity_level` column, which the v5
    // schema replaces with the nullable `bmr_kcal_override`.
    const v4.UserProfileData profileData = v4.UserProfileData(
      id: 0,
      sex: 'female',
      age: 29,
      heightCm: 162.5,
      weightKg: 55.25,
      activityLevel: 'lightActive',
    );

    test(
      'preserves the anthropometrics, drops activity level, NULL override',
      () async {
        await verifier.testWithDataIntegrity(
          oldVersion: 4,
          newVersion: 5,
          createOld: v4.DatabaseAtV4.new,
          createNew: v5.DatabaseAtV5.new,
          openTestedDatabase: AppDatabase.forTesting,
          createItems: (batch, oldDb) {
            batch.insertAll(oldDb.userProfile, const <v4.UserProfileData>[
              profileData,
            ]);
          },
          validateItems: (newDb) async {
            final rows = await newDb.select(newDb.userProfile).get();
            expect(rows, hasLength(1));
            final row = rows.single;
            // Anthropometrics survive untouched...
            expect(row.id, 0);
            expect(row.sex, 'female');
            expect(row.age, 29);
            expect(row.heightCm, 162.5);
            expect(row.weightKg, 55.25);
            // ...the activity level is gone and the new column reads as NULL,
            // i.e. "derive the BMR with Mifflin-St Jeor".
            expect(row.bmrKcalOverride, isNull);
          },
        );
      },
    );

    test('the fully migrated profile accepts a manual BMR override', () async {
      final schema = await verifier.schemaAt(4);
      final oldDb = v4.DatabaseAtV4(schema.newConnection());
      await oldDb.batch((batch) {
        batch.insertAll(oldDb.userProfile, const <v4.UserProfileData>[
          profileData,
        ]);
      });
      await oldDb.close();

      // Migrate all the way to the current shape (v4 -> ... -> v10), because
      // the DAO below always speaks the current schema.
      final db = AppDatabase.forTesting(schema.newConnection());
      await verifier.migrateAndValidate(db, 10);

      final migrated = await db.userProfileDao.getProfile();
      expect(migrated, isNotNull);
      expect(migrated!.sex, Sex.female);
      expect(migrated.bmrKcalOverride, isNull);

      await db.userProfileDao.saveProfile(
        sex: Sex.female,
        birthDate: DateTime.utc(1997, 3, 14),
        heightCm: 162.5,
        weightKg: 55.25,
        bmrKcalOverride: 1350,
      );
      final updated = await db.userProfileDao.getProfile();
      expect(updated!.bmrKcalOverride, 1350);
      expect(updated.sex, Sex.female);
      expect(updated.weightKg, 55.25);
      expect(updated.birthDate.toUtc(), DateTime.utc(1997, 3, 14));

      await db.close();
      schema.close();
    });
  });

  group('v5 -> v6 data integrity', () {
    // A v5 profile stored `age`; v6 stores a date-only `birth_date` and derives
    // the age from it. The migration back-projects a birthday from the old age
    // as of migration day, so the user's current age is preserved.
    const v5.UserProfileData profileData = v5.UserProfileData(
      id: 0,
      sex: 'female',
      age: 29,
      heightCm: 162.5,
      weightKg: 55.25,
      bmrKcalOverride: 1310.5,
    );

    test(
      'preserves the anthropometrics and converts age to a birthday',
      () async {
        await verifier.testWithDataIntegrity(
          oldVersion: 5,
          newVersion: 6,
          createOld: v5.DatabaseAtV5.new,
          createNew: v6.DatabaseAtV6.new,
          openTestedDatabase: AppDatabase.forTesting,
          createItems: (batch, oldDb) {
            batch.insertAll(oldDb.userProfile, const <v5.UserProfileData>[
              profileData,
            ]);
          },
          validateItems: (newDb) async {
            final rows = await newDb.select(newDb.userProfile).get();
            expect(rows, hasLength(1));
            final row = rows.single;
            // Everything but the removed age column survives untouched.
            expect(row.id, 0);
            expect(row.sex, 'female');
            expect(row.heightCm, 162.5);
            expect(row.weightKg, 55.25);
            expect(row.bmrKcalOverride, 1310.5);
            // The birthday is migration-day minus 29 years (local date), stored
            // as the canonical UTC calendar date.
            final DateTime today = DateTime.now();
            final DateTime expected = DateTime.utc(
              today.year - 29,
              today.month,
              today.day,
            );
            // The generated schema exposes a dateTime as raw unix seconds.
            final DateTime birthday = DateTime.fromMillisecondsSinceEpoch(
              row.birthDate * 1000,
              isUtc: true,
            );
            expect(birthday, expected);
            // The age on migration day is unchanged (Feb-29 back-projection can
            // land one day late, which the calendar maths reflects honestly).
            final int age = ageOnBirthday(birthday, today);
            expect(age, anyOf(28, 29));
            expect(
              age,
              29,
              reason: 'age must be preserved for a normal (non-Feb-29) date',
              skip: today.month == 2 && today.day == 29,
            );
          },
        );
      },
    );

    test('the migrated profile can be saved with a real birthday', () async {
      final schema = await verifier.schemaAt(5);
      final oldDb = v5.DatabaseAtV5(schema.newConnection());
      await oldDb.batch((batch) {
        batch.insertAll(oldDb.userProfile, const <v5.UserProfileData>[
          profileData,
        ]);
      });
      await oldDb.close();

      final db = AppDatabase.forTesting(schema.newConnection());
      await verifier.migrateAndValidate(db, 10);

      final migrated = await db.userProfileDao.getProfile();
      expect(migrated, isNotNull);
      expect(migrated!.sex, Sex.female);
      // v10 rounds the legacy REAL override (1310.5 -> 1311).
      expect(migrated.bmrKcalOverride, 1311);

      await db.userProfileDao.saveProfile(
        sex: Sex.female,
        birthDate: DateTime.utc(1997, 3, 14),
        heightCm: 162.5,
        weightKg: 55.25,
        bmrKcalOverride: 1311,
      );
      final updated = await db.userProfileDao.getProfile();
      expect(updated!.birthDate.toUtc(), DateTime.utc(1997, 3, 14));
      expect(
        ageOnBirthday(updated.birthDate.toUtc(), DateTime(2026, 10, 22)),
        29,
      );

      await db.close();
      schema.close();
    });
  });

  group('v6 -> v7 data integrity', () {
    // v7 adds the structured selection surface to `foods` and back-fills the
    // old 「已停用」 notes marker into `status = archived`.
    const v6.FoodsData plain = v6.FoodsData(
      id: 'food-plain',
      name: '辛拉面(农心)',
      notes: '标签 2026-09-17',
      source: 'label',
      kcal: 422,
      carbG: 68,
      proteinG: 8.2,
      fatG: 13,
      sodiumMg: 1520,
    );
    const v6.FoodsData archived = v6.FoodsData(
      id: 'food-archived',
      name: 'AH熟火腿(脱脂)',
      notes: '已停用｜标签 2026-09-13',
      source: 'label',
      kcal: 112,
      sodiumMg: 652,
    );

    test(
      'preserves foods, defaults the new columns and archives 已停用',
      () async {
        await verifier.testWithDataIntegrity(
          oldVersion: 6,
          newVersion: 7,
          createOld: v6.DatabaseAtV6.new,
          createNew: v7.DatabaseAtV7.new,
          openTestedDatabase: AppDatabase.forTesting,
          createItems: (batch, oldDb) {
            batch.insertAll(oldDb.foods, const <v6.FoodsData>[plain, archived]);
          },
          validateItems: (newDb) async {
            final rows = await newDb.select(newDb.foods).get();
            expect(rows, hasLength(2));
            final byId = <String, v7.FoodsData>{
              for (final v7.FoodsData row in rows) row.id: row,
            };

            final v7.FoodsData kept = byId['food-plain']!;
            expect(kept.name, '辛拉面(农心)');
            expect(kept.notes, '标签 2026-09-17');
            expect(kept.kcal, 422);
            expect(kept.sodiumMg, 1520);
            expect(
              kept.aliases,
              isNull,
              reason: 'legacy aliases stay in notes',
            );
            expect(kept.servings, isNull);
            expect(kept.basis, isNull);
            expect(kept.status, isNull, reason: 'active is the NULL default');

            final v7.FoodsData stopped = byId['food-archived']!;
            expect(stopped.status, 'archived');
            expect(stopped.notes, '已停用｜标签 2026-09-13');
          },
        );
      },
    );

    test('the migrated rows map to active/archived domain foods', () async {
      final schema = await verifier.schemaAt(6);
      final oldDb = v6.DatabaseAtV6(schema.newConnection());
      await oldDb.batch((batch) {
        batch.insertAll(oldDb.foods, const <v6.FoodsData>[plain, archived]);
      });
      await oldDb.close();

      final db = AppDatabase.forTesting(schema.newConnection());
      await verifier.migrateAndValidate(db, 10);

      final kept = foodFromRow((await db.foodDao.getFood('food-plain'))!);
      expect(kept.status, FoodStatus.active);
      expect(kept.isMatchable, isTrue);
      expect(kept.basis, MeasureBasis.per100g);
      expect(kept.aliases, isEmpty);
      expect(kept.servings, isEmpty);
      expect(kept.kcal, 422);

      final stopped = foodFromRow((await db.foodDao.getFood('food-archived'))!);
      expect(stopped.status, FoodStatus.archived);
      expect(stopped.isMatchable, isFalse);

      await db.close();
    });
  });

  group('v7 -> v8 data integrity', () {
    // v8 adds the two optional GB 28050 declarations to `foods`. It is purely
    // additive: structured aliases/servings and every nutrient survive, and
    // the new columns read as NULL ("not declared", never 0).
    const v7.FoodsData food = v7.FoodsData(
      id: 'food-1',
      name: '全脂牛奶',
      brand: '光明',
      notes: '标签 2026-09-05',
      aliases: '["牛奶"]',
      servings: '[{"label":"一盒","amount":250,"unit":"ml"}]',
      status: 'archived',
      basis: 'per100ml',
      source: 'label',
      kcal: 65,
      carbG: 4.8,
      proteinG: 3.3,
      fatG: 3.6,
      sodiumMg: 50,
    );

    test('preserves the row and leaves the new columns NULL', () async {
      await verifier.testWithDataIntegrity(
        oldVersion: 7,
        newVersion: 8,
        createOld: v7.DatabaseAtV7.new,
        createNew: v8.DatabaseAtV8.new,
        openTestedDatabase: AppDatabase.forTesting,
        createItems: (batch, oldDb) {
          batch.insertAll(oldDb.foods, const <v7.FoodsData>[food]);
        },
        validateItems: (newDb) async {
          final rows = await newDb.select(newDb.foods).get();
          expect(rows, hasLength(1));
          final v8.FoodsData row = rows.single;
          expect(row.name, '全脂牛奶');
          expect(row.aliases, '["牛奶"]');
          expect(row.status, 'archived');
          expect(row.basis, 'per100ml');
          expect(row.kcal, 65);
          expect(row.fatG, 3.6);
          expect(row.sugarG, isNull);
          expect(row.saturatedFatG, isNull);
        },
      );
    });

    test('the migrated row maps with blank declarations as null', () async {
      final schema = await verifier.schemaAt(7);
      final oldDb = v7.DatabaseAtV7(schema.newConnection());
      await oldDb.batch((batch) {
        batch.insertAll(oldDb.foods, const <v7.FoodsData>[food]);
      });
      await oldDb.close();

      final db = AppDatabase.forTesting(schema.newConnection());
      await verifier.migrateAndValidate(db, 10);

      final mapped = foodFromRow((await db.foodDao.getFood('food-1'))!);
      expect(mapped.sugarG, isNull);
      expect(mapped.saturatedFatG, isNull);
      expect(mapped.status, FoodStatus.archived);
      expect(mapped.aliases, <String>['牛奶']);
      expect(mapped.servings.single.unit, 'ml');

      await db.close();
    });
  });

  group('v8 -> v9 data integrity', () {
    // v9 retires the free-text 补充说明: the prose is folded into the structured
    // aliases/servings (existing structured values win) and the text is dropped.
    const v8.FoodsData legacy = v8.FoodsData(
      id: 'food-legacy',
      name: 'AH Protein Kwark',
      notes: '标签 2026-09-14 | 一罐 450 g | 别名：ah kwark、夸克',
      source: 'label',
      kcal: 60,
      sodiumMg: 40,
    );
    const v8.FoodsData archived = v8.FoodsData(
      id: 'food-archived',
      name: 'AH熟火腿(脱脂)',
      notes: '已停用｜标签 2026-09-13｜一片 38 g',
      source: 'label',
      kcal: 112,
    );
    const v8.FoodsData structured = v8.FoodsData(
      id: 'food-structured',
      name: '燕麦奶',
      aliases: '["保留的别名"]',
      notes: '别名：不应覆盖',
      source: 'manual',
    );
    const v8.FoodsData plain = v8.FoodsData(
      id: 'food-plain',
      name: '白开水',
      source: 'manual',
    );

    test(
      'folds legacy prose into the structured fields and clears notes',
      () async {
        await verifier.testWithDataIntegrity(
          oldVersion: 8,
          newVersion: 9,
          createOld: v8.DatabaseAtV8.new,
          createNew: v9.DatabaseAtV9.new,
          openTestedDatabase: AppDatabase.forTesting,
          createItems: (batch, oldDb) {
            batch.insertAll(oldDb.foods, const <v8.FoodsData>[
              legacy,
              archived,
              structured,
              plain,
            ]);
          },
          validateItems: (newDb) async {
            final rows = await newDb.select(newDb.foods).get();
            final byId = <String, v9.FoodsData>{
              for (final v9.FoodsData row in rows) row.id: row,
            };

            final v9.FoodsData migrated = byId['food-legacy']!;
            expect(migrated.notes, isNull, reason: 'the prose is retired');
            expect(migrated.aliases, '["ah kwark","夸克"]');
            expect(migrated.servings, contains('"label":"一罐"'));
            expect(migrated.status, 'active');
            expect(migrated.kcal, 60, reason: 'nutrients are untouched');

            final v9.FoodsData stopped = byId['food-archived']!;
            expect(stopped.notes, isNull);
            expect(stopped.status, 'archived');
            expect(stopped.servings, contains('"label":"一片"'));

            final v9.FoodsData kept = byId['food-structured']!;
            expect(kept.notes, isNull);
            expect(
              kept.aliases,
              '["保留的别名"]',
              reason: 'existing structured values win',
            );

            final v9.FoodsData untouched = byId['food-plain']!;
            expect(untouched.notes, isNull);
            expect(untouched.aliases, isNull);
          },
        );
      },
    );

    test('the migrated row maps to a note-free domain food', () async {
      final schema = await verifier.schemaAt(8);
      final oldDb = v8.DatabaseAtV8(schema.newConnection());
      await oldDb.batch((batch) {
        batch.insertAll(oldDb.foods, const <v8.FoodsData>[legacy, archived]);
      });
      await oldDb.close();

      final db = AppDatabase.forTesting(schema.newConnection());
      await verifier.migrateAndValidate(db, 10);

      final migrated = foodFromRow((await db.foodDao.getFood('food-legacy'))!);
      expect(migrated.notes, isNull);
      expect(migrated.aliases, <String>['ah kwark', '夸克']);
      expect(migrated.servings.single.label, '一罐');
      expect(migrated.servings.single.amount, 450);

      final stopped = foodFromRow((await db.foodDao.getFood('food-archived'))!);
      expect(stopped.notes, isNull);
      expect(stopped.status, FoodStatus.archived);

      await db.close();
    });
  });

  group('v9 -> v10 integer-energy data integrity', () {
    // v10 narrows the four stored energy columns from REAL to INTEGER. Existing
    // fractional values (a kJ label conversion, an AI estimate, a typed BMR)
    // must be rounded to the nearest whole kcal, while a blank nutrient stays
    // NULL (never a fabricated 0).
    const String mealId = 'meal-v10';
    const int lunchTs = 1760000000; // 2025-10-09T08:53:20Z
    const int birthTs = 631152000; // 1990-01-01T00:00:00Z

    const v9.MealsData meal = v9.MealsData(
      id: mealId,
      timestamp: lunchTs,
      mealType: 'lunch',
    );
    const v9.MealItemsData item = v9.MealItemsData(
      id: 'item-v10',
      mealId: mealId,
      name: '米饭',
      grams: 200,
      kcal: 232.4,
      carbG: 51.6,
      proteinG: 4.2,
      fatG: 0.6,
      saltG: 0.01,
      source: 'ai',
    );
    const v9.FoodsData labelled = v9.FoodsData(
      id: 'food-v10',
      name: '酸奶',
      source: 'label',
      kcal: 60.5,
      carbG: 5.0,
      sodiumMg: 40.0,
    );
    const v9.FoodsData blank = v9.FoodsData(
      id: 'food-blank',
      name: '白开水',
      source: 'manual',
    );
    const v9.DailyExercisesData exercise = v9.DailyExercisesData(
      dayKey: 1760000000,
      kcal: 350.6,
    );
    const v9.UserProfileData profile = v9.UserProfileData(
      id: 0,
      sex: 'male',
      birthDate: birthTs,
      heightCm: 175,
      weightKg: 70,
      bmrKcalOverride: 1648.75,
    );

    test('rounds every stored REAL energy value, keeping NULLs NULL', () async {
      await verifier.testWithDataIntegrity(
        oldVersion: 9,
        newVersion: 10,
        createOld: v9.DatabaseAtV9.new,
        createNew: v10.DatabaseAtV10.new,
        openTestedDatabase: AppDatabase.forTesting,
        createItems: (batch, oldDb) {
          batch.insert(oldDb.meals, meal);
          batch.insert(oldDb.mealItems, item);
          batch.insertAll(oldDb.foods, const <v9.FoodsData>[labelled, blank]);
          batch.insert(oldDb.dailyExercises, exercise);
          batch.insert(oldDb.userProfile, profile);
        },
        validateItems: (newDb) async {
          final foods = await newDb.select(newDb.foods).get();
          final byId = <String, v10.FoodsData>{
            for (final v10.FoodsData row in foods) row.id: row,
          };
          expect(
            byId['food-v10']!.kcal,
            61,
            reason: '60.5 kcal rounds half away from zero',
          );
          expect(
            byId['food-blank']!.kcal,
            isNull,
            reason: 'a blank nutrient stays NULL, never 0',
          );

          final items = await newDb.select(newDb.mealItems).get();
          expect(items, hasLength(1));
          expect(items.single.kcal, 232, reason: '232.4 -> 232');

          final exercises = await newDb.select(newDb.dailyExercises).get();
          expect(exercises, hasLength(1));
          expect(exercises.single.kcal, 351, reason: '350.6 -> 351');

          final profiles = await newDb.select(newDb.userProfile).get();
          expect(profiles, hasLength(1));
          expect(
            profiles.single.bmrKcalOverride,
            1649,
            reason: '1648.75 -> 1649',
          );
        },
      );
    });
  });
}
