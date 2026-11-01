// Task 28: versioned JSON export/import.
//
// The round-trip is exercised WITHOUT the share sheet: the pure codec
// (`backup_codec.dart`) and the Drift service (`backup_service.dart`) are the
// only pieces under test, exactly as the deliverable requires.
import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:caldoo/core/time/date_windows.dart' show MealWithItems;
import 'package:caldoo/data/db/app_database.dart';
import 'package:caldoo/data/repositories/drift_exercise_repository.dart';
import 'package:caldoo/data/repositories/drift_food_repository.dart';
import 'package:caldoo/data/repositories/drift_meal_repository.dart';
import 'package:caldoo/data/repositories/drift_profile_repository.dart';
import 'package:caldoo/domain/models/models.dart';
import 'package:caldoo/features/settings/ai_settings.dart';
import 'package:caldoo/features/settings/backup/backup_codec.dart';
import 'package:caldoo/features/settings/backup/backup_data.dart';
import 'package:caldoo/features/settings/backup/backup_service.dart';

import '../../../data/db/_test_db.dart';
import '../_fakes.dart';

/// A pinned "today" for the codec's legacy age -> birthday conversion, so the
/// round-trip never depends on the wall clock.
final DateTime pinnedNow = DateTime.utc(2026, 1, 5);

/// Seeds a rich, fully-populated dataset into [db]. Counts are asserted by the
/// round-trip test below: 1 profile, 2 foods, 2 meals, 3 items, 2 exercises and
/// 2 persisted settings (`notice_seen` is excluded).
Future<void> seedEverything(AppDatabase db) async {
  await DriftProfileRepository(db).saveProfile(
    UserProfile(
      sex: Sex.female,
      birthDate: DateTime.utc(1997, 3, 14),
      heightCm: 162.5,
      weightKg: 55.25,
      bmrKcalOverride: 1311,
      dailyKcalGoalOverride: 1200,
    ),
  );

  final foods = DriftFoodRepository(db);
  await foods.insertFood(
    const Food(
      id: 'f1',
      name: '全麦面包',
      brand: '某品牌',
      barcode: '6900000000001',
      aliases: <String>['小饼干', '苏打饼'],
      servings: <FoodServing>[FoodServing(label: '一包', amount: 45, unit: 'g')],
      status: FoodStatus.archived,
      basis: MeasureBasis.per100ml,
      source: FoodSource.label,
      kcal: 251,
      carbG: 45.25,
      proteinG: 9.5,
      fatG: 3.75,
      sugarG: 12.5,
      saturatedFatG: 1.2,
      sodiumMg: 320.0,
    ),
  );
  // The other end of the "blank stays blank" contract: every nullable stays
  // null and must survive the round-trip as null, never as 0/''.
  await foods.insertFood(
    const Food(id: 'f2', name: '白开水', source: FoodSource.manual),
  );

  final meals = DriftMealRepository(db);
  await meals.saveMealWithItems(
    Meal(
      id: 'm1',
      timestamp: DateTime(2026, 3, 4, 8, 15),
      mealType: MealType.breakfast,
      note: '早餐备注',
    ),
    const <MealItem>[
      MealItem(
        id: 'i1',
        foodId: 'f1',
        name: '全麦面包',
        grams: 80,
        kcal: 200,
        carbG: 36.2,
        proteinG: 7.6,
        fatG: 3,
        saltG: 0.8,
        source: FoodSource.label,
        confidence: 0.93,
      ),
      MealItem(
        id: 'i2',
        name: '鸡蛋',
        grams: 55,
        kcal: 78,
        carbG: 0.6,
        proteinG: 6.4,
        fatG: 5.3,
        saltG: 0.2,
        source: FoodSource.manual,
      ),
    ],
  );
  await meals.saveMealWithItems(
    Meal(
      id: 'm2',
      timestamp: DateTime(2026, 3, 4, 12, 30),
      mealType: MealType.lunch,
    ),
    const <MealItem>[
      MealItem(
        id: 'i3',
        foodId: 'f2',
        name: '米饭',
        grams: 150,
        kcal: 174,
        carbG: 38.4,
        proteinG: 3.9,
        fatG: 0.45,
        saltG: 0.01,
        source: FoodSource.ai,
        confidence: 0.4,
      ),
    ],
  );

  final exercises = DriftExerciseRepository(db);
  await exercises.setKcal(dayKey: DateTime.utc(2026, 3, 4), kcal: 220);
  await exercises.setKcal(dayKey: DateTime.utc(2026, 3, 5), kcal: 300);

  // The history rows are written through the DAO (not the repository): the
  // seed stays orthogonal to the profile-sync side of saveWeight, so the
  // round-trip asserts the storage format, not the sync behaviour.
  await db.weightDao.upsertWeight(
    dayKey: DateTime.utc(2026, 3, 4),
    weightKg: 55.1,
  );
  await db.weightDao.upsertWeight(
    dayKey: DateTime.utc(2026, 3, 10),
    weightKg: 54.7,
  );

  await db.appSettingsDao.setValue(
    AiSettingsRepository.baseUrlPrefKey,
    'https://api.example.test',
  );
  await db.appSettingsDao.setValue(
    AiSettingsRepository.modelPrefKey,
    'example-model',
  );
  // Transient UI state: must NEVER appear in an export.
  await db.appSettingsDao.setValue('notice_seen', 'true');
}

/// Every JSON object key anywhere in [node], for the secret-field scan.
Set<String> allKeys(Object? node) {
  final Set<String> keys = <String>{};
  if (node is Map<String, dynamic>) {
    for (final MapEntry<String, dynamic> entry in node.entries) {
      keys.add(entry.key);
      keys.addAll(allKeys(entry.value));
    }
  } else if (node is List<Object?>) {
    for (final Object? item in node) {
      keys.addAll(allKeys(item));
    }
  }
  return keys;
}

void main() {
  group('backup round-trip (seed -> export -> import into a fresh DB)', () {
    late AppDatabase source;
    late AppDatabase target;

    setUp(() {
      source = testDb();
      target = testDb();
    });
    tearDown(() async {
      await source.close();
      await target.close();
    });

    test('every record and field survives, with nothing skipped', () async {
      await seedEverything(source);
      final sourceService = BackupService(source);
      final targetService = BackupService(target);

      final String payload = await sourceService.exportToJson();
      final ImportSummary summary = await targetService.importFromJson(payload);

      // The export is stamped with the current (weight-history) version.
      expect(backupSchemaVersion, 5);
      expect(supportedBackupSchemaVersions, <int>{2, 3, 4, 5});
      final Map<String, dynamic> exported =
          jsonDecode(payload) as Map<String, dynamic>;
      expect(exported['schemaVersion'], 5);

      // v5 carries the explicit daily goal next to the BMR override.
      final Map<String, dynamic> exportedProfile =
          exported['profile'] as Map<String, dynamic>;
      expect(exportedProfile['bmrKcalOverride'], 1311);
      expect(exportedProfile['bmrKcalOverride'], isA<int>());
      expect(exportedProfile['dailyKcalGoalOverride'], 1200);
      expect(exportedProfile['dailyKcalGoalOverride'], isA<int>());
      final Map<String, dynamic> exportedFood =
          (exported['foods'] as List<Object?>).first as Map<String, dynamic>;
      expect(exportedFood['kcal'], 251);
      expect(exportedFood['kcal'], isA<int>());
      final Map<String, dynamic> exportedMeal =
          (exported['meals'] as List<Object?>).first as Map<String, dynamic>;
      final Map<String, dynamic> exportedItem =
          (exportedMeal['items'] as List<Object?>).first
              as Map<String, dynamic>;
      expect(exportedItem['kcal'], isA<int>());
      expect(
        exported['dailyExercises'],
        everyElement(
          predicate<Object?>(
            (Object? e) => (e! as Map<String, dynamic>)['kcal'] is int,
          ),
        ),
      );
      expect(
        (exported['profile'] as Map<String, dynamic>).containsKey('birthDate'),
        isTrue,
      );
      expect(
        (exported['profile'] as Map<String, dynamic>).containsKey('age'),
        isFalse,
      );

      // Deep equality on the whole snapshot: profile, foods, meals+items,
      // exercises and settings, every field included.
      final BackupData expected = await sourceService.capture();
      final BackupData actual = await targetService.capture();
      expect(actual, expected);

      expect(summary.totalSkipped, 0);
      expect(summary.profileImported, 1);
      expect(summary.foodsImported, 2);
      expect(summary.mealsImported, 2);
      expect(summary.mealItemsImported, 3);
      expect(summary.dailyExercisesImported, 2);
      expect(summary.weightEntriesImported, 2);
      expect(summary.settingsImported, 2);
      expect(summary.totalImported, 14);

      // Spot-check the nullable fields explicitly, so a broken `==` cannot
      // hide a silently-coerced null (the blank-stays-blank contract).
      final Food? structuredFood = await DriftFoodRepository(target)
          .getFood('f1');
      expect(structuredFood, isNotNull);
      expect(structuredFood!.aliases, <String>['小饼干', '苏打饼']);
      expect(structuredFood.servings.single.label, '一包');
      expect(structuredFood.servings.single.amount, 45);
      expect(structuredFood.status, FoodStatus.archived);
      expect(structuredFood.basis, MeasureBasis.per100ml);
      expect(structuredFood.sugarG, 12.5);
      expect(structuredFood.saturatedFatG, 1.2);

      final Food? blankFood = await DriftFoodRepository(target).getFood('f2');
      expect(blankFood, isNotNull);
      expect(blankFood!.brand, isNull);
      expect(blankFood.barcode, isNull);
      expect(blankFood.notes, isNull);
      expect(blankFood.kcal, isNull);
      expect(blankFood.sodiumMg, isNull);

      final List<MealWithItems> meals = actual.meals;
      final MealWithItems breakfast = meals.firstWhere(
        (group) => group.meal.id == 'm1',
      );
      expect(breakfast.meal.note, '早餐备注');
      expect(breakfast.items.firstWhere((i) => i.id == 'i2').foodId, isNull);
      expect(
        breakfast.items.firstWhere((i) => i.id == 'i2').confidence,
        isNull,
      );
      expect(breakfast.items.firstWhere((i) => i.id == 'i1').confidence, 0.93);

      expect(actual.profile, isNotNull);
      expect(actual.profile!.heightCm, 162.5);
      // The birthday (not an age) crosses the JSON round-trip verbatim.
      expect(actual.profile!.birthDate, DateTime.utc(1997, 3, 14));
      // The BMR override crosses the JSON round-trip verbatim (not re-derived).
      expect(actual.profile!.bmrKcalOverride, 1311);
      // The daily goal crosses verbatim too: an explicit number, never derived.
      expect(actual.profile!.dailyKcalGoalOverride, 1200);
      expect(
        actual.dailyExercises.map((e) => e.kcal).toList(),
        unorderedEquals(<int>[220, 300]),
      );
      expect(
        actual.dailyExercises.firstWhere((e) => e.kcal == 220).dayKey,
        DateTime.utc(2026, 3, 4),
      );
      // The weight history survives row-for-row, keys included.
      expect(
        actual.weightEntries.map((e) => e.weightKg).toList(),
        unorderedEquals(<double>[55.1, 54.7]),
      );
      expect(
        actual.weightEntries.firstWhere((e) => e.weightKg == 54.7).dayKey,
        DateTime.utc(2026, 3, 10),
      );
    });

    test('the export excludes the transient notice_seen flag', () async {
      await seedEverything(source);
      final String payload = await BackupService(source).exportToJson();

      expect(payload, isNot(contains('notice_seen')));
      final BackupData data = decodeBackup(payload, now: pinnedNow);
      expect(
        data.settings.keys,
        unorderedEquals(<String>['ai_base_url', 'ai_model']),
      );
      expect(data.settings.containsKey('notice_seen'), isFalse);

      // And importing it can never resurrect the flag into the target DB.
      await BackupService(target).importFromJson(payload);
      expect(await target.appSettingsDao.getValue('notice_seen'), isNull);
      expect(
        await target.appSettingsDao.getValue(
          AiSettingsRepository.baseUrlPrefKey,
        ),
        'https://api.example.test',
      );
    });
  });

  group('legacy schemaVersion 2 profile (stored age) import', () {
    late AppDatabase db;

    setUp(() => db = testDb());
    tearDown(() async => db.close());

    /// A version-2 backup whose profile still stores `age`, not `birthDate`.
    String legacyPayload({int age = 29}) => jsonEncode(<String, Object?>{
      'schemaVersion': 2,
      'profile': <String, Object?>{
        'sex': 'female',
        'age': age,
        'heightCm': 162.5,
        'weightKg': 55.25,
        'bmrKcalOverride': 1310.5,
      },
      'foods': <Object?>[],
      'meals': <Object?>[],
      'dailyExercises': <Object?>[],
      'settings': <String, String>{},
    });

    test(
      'the stored age becomes a birthday that keeps that age on the pinned now',
      () async {
        final ImportSummary summary = await BackupService(
          db,
          clock: Clock.fixed(pinnedNow),
        ).importFromJson(legacyPayload());

        expect(summary.profileImported, 1);
        final UserProfile? stored = await DriftProfileRepository(db)
            .loadProfile();
        expect(stored, isNotNull);
        // 2026-01-05 minus 29 whole years: the derived age is still exactly 29.
        expect(stored!.birthDate, DateTime.utc(1997, 1, 5));
        expect(stored.ageOn(pinnedNow), 29);
        expect(stored.sex, Sex.female);
        expect(stored.heightCm, 162.5);
        expect(stored.weightKg, 55.25);
        // Fractional legacy energy is rounded once at the JSON boundary.
        expect(stored.bmrKcalOverride, 1311);
      },
    );

    test('the pure codec accepts v2 and applies the same conversion', () {
      final BackupData data = decodeBackup(
        legacyPayload(age: 41),
        now: pinnedNow,
      );

      expect(data.profile, isNotNull);
      expect(data.profile!.birthDate, DateTime.utc(1985, 1, 5));
      expect(data.profile!.ageOn(pinnedNow), 41);
    });

    test('a v2 age that is not a positive number is a format error', () {
      final String payload = jsonEncode(<String, Object?>{
        'schemaVersion': 2,
        'profile': <String, Object?>{'sex': 'female', 'age': 0},
      });

      expect(
        () => decodeBackup(payload, now: pinnedNow),
        throwsA(isA<BackupFormatException>()),
      );
    });
  });

  group('import conflict policy (existing row wins)', () {
    late AppDatabase source;
    late AppDatabase target;

    setUp(() {
      source = testDb();
      target = testDb();
    });
    tearDown(() async {
      await source.close();
      await target.close();
    });

    test('a colliding id is skipped, counted, and left untouched', () async {
      // Source: food f1 "INCOMING", meal m1 with items i1/i2, exercise e1.
      await DriftFoodRepository(source).insertFood(
        const Food(id: 'f1', name: 'INCOMING', source: FoodSource.manual),
      );
      await DriftMealRepository(source).saveMealWithItems(
        Meal(
          id: 'm1',
          timestamp: DateTime(2026, 3, 4, 8),
          mealType: MealType.breakfast,
        ),
        const <MealItem>[
          MealItem(
            id: 'i1',
            name: 'x1',
            grams: 1,
            kcal: 1,
            carbG: 1,
            proteinG: 1,
            fatG: 1,
            saltG: 1,
            source: FoodSource.manual,
          ),
          MealItem(
            id: 'i2',
            name: 'x2',
            grams: 1,
            kcal: 1,
            carbG: 1,
            proteinG: 1,
            fatG: 1,
            saltG: 1,
            source: FoodSource.manual,
          ),
        ],
      );
      await DriftExerciseRepository(source)
          .setKcal(dayKey: DateTime.utc(2026, 3, 4), kcal: 100);

      // Target already owns all three ids with different content.
      await DriftFoodRepository(target).insertFood(
        const Food(id: 'f1', name: 'EXISTING', source: FoodSource.label),
      );
      await DriftMealRepository(target).saveMealWithItems(
        Meal(
          id: 'm1',
          timestamp: DateTime(2026, 1, 1, 7),
          mealType: MealType.dinner,
          note: 'KEEP ME',
        ),
        const <MealItem>[
          MealItem(
            id: 'i9',
            name: 'existing item',
            grams: 2,
            kcal: 2,
            carbG: 2,
            proteinG: 2,
            fatG: 2,
            saltG: 2,
            source: FoodSource.label,
          ),
        ],
      );
      await DriftExerciseRepository(target)
          .setKcal(dayKey: DateTime.utc(2026, 3, 4), kcal: 999);

      final ImportSummary summary = await BackupService(target)
          .importFromJson(await BackupService(source).exportToJson());

      expect(summary.foodsSkipped, 1);
      expect(summary.mealsSkipped, 1);
      expect(summary.mealItemsSkipped, 2, reason: 'children follow the meal');
      expect(summary.dailyExercisesSkipped, 1);
      expect(summary.foodsImported, 0);
      expect(summary.mealsImported, 0);
      expect(summary.dailyExercisesImported, 0);

      // The existing rows won, verbatim.
      expect(
        (await DriftFoodRepository(target).getFood('f1'))!.name,
        'EXISTING',
      );
      final BackupData captured = await BackupService(target).capture();
      final Meal kept = captured.meals.single.meal;
      expect(kept.mealType, MealType.dinner);
      expect(kept.note, 'KEEP ME');
      expect(captured.dailyExercises.single.kcal, 999);

      // No orphaned items: only the pre-existing i9 remains.
      final Set<String> itemIds = <String>{
        for (final MealItemRow row
            in await target.select(target.mealItems).get())
          row.id,
      };
      expect(itemIds, <String>{'i9'});
    });

    test('a new meal skips only the child id that collides', () async {
      // Source meal m_new carries one colliding item (i_shared) and one fresh.
      await DriftMealRepository(source).saveMealWithItems(
        Meal(
          id: 'm_new',
          timestamp: DateTime(2026, 4, 1, 9),
          mealType: MealType.snack,
        ),
        const <MealItem>[
          MealItem(
            id: 'i_shared',
            name: 'shared',
            grams: 1,
            kcal: 1,
            carbG: 1,
            proteinG: 1,
            fatG: 1,
            saltG: 1,
            source: FoodSource.manual,
          ),
          MealItem(
            id: 'i_fresh',
            name: 'fresh',
            grams: 1,
            kcal: 1,
            carbG: 1,
            proteinG: 1,
            fatG: 1,
            saltG: 1,
            source: FoodSource.manual,
          ),
        ],
      );

      // Target owns i_shared under a different meal.
      await DriftMealRepository(target).saveMealWithItems(
        Meal(
          id: 'm_old',
          timestamp: DateTime(2026, 1, 2, 9),
          mealType: MealType.lunch,
        ),
        const <MealItem>[
          MealItem(
            id: 'i_shared',
            name: 'existing shared',
            grams: 5,
            kcal: 5,
            carbG: 5,
            proteinG: 5,
            fatG: 5,
            saltG: 5,
            source: FoodSource.label,
          ),
        ],
      );

      final ImportSummary summary = await BackupService(target)
          .importFromJson(await BackupService(source).exportToJson());

      expect(summary.mealsImported, 1);
      expect(summary.mealItemsImported, 1);
      expect(summary.mealItemsSkipped, 1);

      final BackupData captured = await BackupService(target).capture();
      final MealWithItems fresh = captured.meals.firstWhere(
        (group) => group.meal.id == 'm_new',
      );
      expect(fresh.items.map((i) => i.id), <String>['i_fresh']);
      // The existing item still belongs to its original meal, unmodified.
      final MealWithItems old = captured.meals.firstWhere(
        (group) => group.meal.id == 'm_old',
      );
      expect(old.items.single.id, 'i_shared');
      expect(old.items.single.name, 'existing shared');
    });
  });

  group('rejected payloads leave the database unchanged', () {
    late AppDatabase db;
    late BackupService service;

    setUp(() async {
      db = testDb();
      service = BackupService(db);
      await seedEverything(db);
    });
    tearDown(() async {
      await db.close();
    });

    test('a wrong schemaVersion throws a typed error', () async {
      final BackupData before = await service.capture();
      // A FUTURE version (never the current one) must be rejected wholesale.
      const int wrongVersion = backupSchemaVersion + 1;
      final String payload = jsonEncode(<String, Object?>{
        'schemaVersion': wrongVersion,
        'profile': null,
        'foods': <Object?>[],
        'meals': <Object?>[],
        'dailyExercises': <Object?>[],
        'weightEntries': <Object?>[],
        'settings': <String, String>{},
      });

      await expectLater(
        service.importFromJson(payload),
        throwsA(
          isA<BackupSchemaVersionException>()
              .having((e) => e.found, 'found', wrongVersion)
              .having((e) => e.expected, 'expected', backupSchemaVersion),
        ),
      );
      expect(await service.capture(), before);
    });

    test('a missing schemaVersion throws a typed format error', () async {
      final BackupData before = await service.capture();
      await expectLater(
        service.importFromJson('{"foods":[]}'),
        throwsA(isA<BackupFormatException>()),
      );
      expect(await service.capture(), before);
    });

    test('malformed JSON throws a typed error and writes nothing', () async {
      final BackupData before = await service.capture();

      await expectLater(
        service.importFromJson('{"schemaVersion": 2, '),
        throwsA(isA<BackupFormatException>()),
      );
      // Valid JSON, wrong shapes: still a format error, still no writes.
      await expectLater(
        service.importFromJson('{"schemaVersion":2,"foods":"nope"}'),
        throwsA(isA<BackupFormatException>()),
      );
      await expectLater(
        service.importFromJson('{"schemaVersion":2,"settings":{"a":1}}'),
        throwsA(isA<BackupFormatException>()),
      );

      expect(await service.capture(), before);
    });

    test('every failure is a BackupException (typed, not generic)', () async {
      await expectLater(
        service.importFromJson('{'),
        throwsA(isA<BackupException>()),
      );
      await expectLater(
        service.importFromJson('{"schemaVersion":0}'),
        throwsA(isA<BackupException>()),
      );
    });
  });

  group('secret hygiene', () {
    test(
      'the export carries no key field and never the stored secret',
      () async {
        final AppDatabase db = testDb();
        addTearDown(db.close);

        // A key IS stored (in secure storage) before the export runs.
        final InMemorySecureKeyStore keyStore = InMemorySecureKeyStore();
        final AiSettingsRepository aiRepo = AiSettingsRepository(
          dao: db.appSettingsDao,
          keyStore: keyStore,
        );
        await aiRepo.saveApiKey(testApiKey);
        await aiRepo.saveConfig(
          const AiSettings(
            baseUrl: 'https://api.example.test',
            model: 'example-model',
          ),
        );

        final String payload = await BackupService(db).exportToJson();

        // 1. The secret value is nowhere in the payload.
        expect(payload, isNot(contains(testApiKey)));
        expect(payload, isNot(contains(FlutterSecureKeyStore.keyName)));

        // 2. No field name anywhere resembles a credential.
        final Map<String, dynamic> root =
            jsonDecode(payload) as Map<String, dynamic>;
        for (final String key in allKeys(root)) {
          final String lower = key.toLowerCase();
          expect(lower, isNot(contains('key')), reason: 'field "$key"');
          expect(lower, isNot(contains('token')), reason: 'field "$key"');
          expect(lower, isNot(contains('secret')), reason: 'field "$key"');
          expect(lower, isNot(contains('password')), reason: 'field "$key"');
        }

        // Sanity: the non-secret settings still exported.
        final BackupData data = decodeBackup(payload, now: pinnedNow);
        expect(data.settings['ai_base_url'], 'https://api.example.test');
        expect(data.settings['ai_model'], 'example-model');
      },
    );
  });

  group('legacy 补充说明 import', () {
    test('folds notes into the structured fields and drops the text', () {
      final String payload = jsonEncode(<String, Object?>{
        'schemaVersion': 3,
        'profile': null,
        'foods': <Object?>[
          <String, Object?>{
            'id': 'f-legacy',
            'name': 'AH Protein Kwark',
            'source': 'label',
            'notes': '标签 2026-09-14 | 一罐 450 g | 别名：ah kwark、夸克',
            'kcal': 60,
          },
        ],
        'meals': <Object?>[],
        'dailyExercises': <Object?>[],
        'settings': <String, String>{},
      });

      final BackupData data = decodeBackup(payload, now: pinnedNow);
      final Food food = data.foods.single;
      // A backup written before v9 still carries the retired blob; import folds
      // it into the structured fields instead of resurrecting the text.
      expect(food.notes, isNull);
      expect(food.aliases, <String>['ah kwark', '夸克']);
      expect(food.servings.single.label, '一罐');
      expect(food.servings.single.amount, 450);
    });
  });

  group('legacy schemaVersion 3 fractional energy import', () {
    late AppDatabase db;

    setUp(() => db = testDb());
    tearDown(() async => db.close());

    /// A v3 backup written before energy became integer-only: every kcal field
    /// may still carry a fraction, and it must round rather than be rejected.
    String legacyFractionalPayload() => jsonEncode(<String, Object?>{
      'schemaVersion': 3,
      'profile': <String, Object?>{
        'sex': 'male',
        'birthDate': DateTime.utc(1995, 10, 22).toIso8601String(),
        'heightCm': 175,
        'weightKg': 70,
        'bmrKcalOverride': 1648.75,
      },
      'foods': <Object?>[
        <String, Object?>{
          'id': 'f-v3',
          'name': '旧标签食品',
          'source': 'label',
          'kcal': 232.4,
        },
      ],
      'meals': <Object?>[
        <String, Object?>{
          'meal': <String, Object?>{
            'id': 'm-v3',
            'timestamp': DateTime.utc(2026, 1, 5, 4).toIso8601String(),
            'mealType': 'lunch',
          },
          'items': <Object?>[
            <String, Object?>{
              'id': 'i-v3',
              'name': '旧记录',
              'grams': 100,
              'kcal': 232.4,
              'carbG': 1,
              'proteinG': 1,
              'fatG': 1,
              'saltG': 1,
              'source': 'manual',
            },
          ],
        },
      ],
      'dailyExercises': <Object?>[
        <String, Object?>{
          'dayKey': DateTime.utc(2026, 1, 5).toIso8601String(),
          'kcal': 257.25,
        },
      ],
      'settings': <String, String>{},
    });

    test(
      'the pure codec rounds each fractional energy value to whole kcal',
      () {
        final BackupData data = decodeBackup(
          legacyFractionalPayload(),
          now: pinnedNow,
        );

        expect(data.profile!.bmrKcalOverride, 1649); // 1648.75 -> 1649
        expect(data.foods.single.kcal, 232); // 232.4 -> 232
        expect(data.meals.single.items.single.kcal, 232);
        expect(data.dailyExercises.single.kcal, 257); // 257.25 -> 257
      },
    );

    test(
      'the service imports a v3 file and persists the rounded ints',
      () async {
        final ImportSummary summary = await BackupService(
          db,
          clock: Clock.fixed(pinnedNow),
        ).importFromJson(legacyFractionalPayload());

        expect(summary.profileImported, 1);
        expect(summary.foodsImported, 1);
        expect(summary.mealsImported, 1);
        expect(summary.mealItemsImported, 1);
        expect(summary.dailyExercisesImported, 1);

        final UserProfile? profile = await DriftProfileRepository(db)
            .loadProfile();
        expect(profile, isNotNull);
        expect(profile!.bmrKcalOverride, 1649);
        final Food? food = await DriftFoodRepository(db).getFood('f-v3');
        expect(food, isNotNull);
        expect(food!.kcal, 232);

        final BackupData stored = await BackupService(
          db,
          clock: Clock.fixed(pinnedNow),
        ).capture();
        expect(stored.meals.single.items.single.kcal, 232);
        expect(stored.dailyExercises.single.kcal, 257);
      },
    );
  });
}
