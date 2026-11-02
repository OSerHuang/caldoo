import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:caldoo/data/db/app_database.dart';
import 'package:caldoo/domain/models/food.dart';
import 'package:caldoo/domain/models/meal.dart';
import 'package:caldoo/domain/models/user_profile.dart';
import 'package:caldoo/features/settings/ai_settings.dart';
import 'package:caldoo/features/settings/backup/auto_backup_providers.dart'
    show autoBackupStorageProvider;
import 'package:caldoo/features/settings/privacy/delete_all_data.dart';
import 'package:caldoo/features/settings/privacy/privacy_notice.dart';
import 'package:caldoo/features/settings/settings_providers.dart';

import '../../../data/db/_test_db.dart';
import '../backup/_auto_backup_fakes.dart';
import '../_fakes.dart';

/// Every table in the schema; the wipe must leave all of them empty.
const List<String> _allTables = <String>[
  'app_settings',
  'user_profile',
  'foods',
  'meals',
  'meal_items',
  'daily_exercises',
];

Future<int> _count(AppDatabase db, String table) async {
  final row = await db
      .customSelect('SELECT COUNT(*) AS c FROM $table')
      .getSingle();
  return row.read<int>('c');
}

/// Seeds one row in every table plus a stored key and the notice flag.
Future<void> _seed(AppDatabase db, InMemorySecureKeyStore keyStore) async {
  await db.appSettingsDao.setValue(PrivacyNoticeController.seenKey, 'true');
  await db.appSettingsDao.setValue(
    AiSettingsRepository.baseUrlPrefKey,
    'https://example.test',
  );
  await db.appSettingsDao.setValue(AiSettingsRepository.modelPrefKey, 'm');
  await db.userProfileDao.saveProfile(
    sex: Sex.male,
    birthDate: DateTime.utc(1995, 10, 22),
    heightCm: 175,
    weightKg: 70,
    bmrKcalOverride: 1979,
  );
  await db.foodDao.insertFood(
    FoodsCompanion.insert(id: 'f1', name: '米饭', source: FoodSource.label),
  );
  await db.mealDao.insertMeal(
    MealsCompanion.insert(
      id: 'm1',
      timestamp: DateTime(2026, 1, 1),
      mealType: MealType.lunch,
    ),
  );
  await db.mealDao.insertItem(
    MealItemsCompanion.insert(
      id: 'i1',
      mealId: 'm1',
      name: '米饭',
      grams: 100,
      kcal: 116,
      carbG: 25,
      proteinG: 2,
      fatG: 0,
      saltG: 0,
      source: FoodSource.label,
    ),
  );
  await db.exerciseDao.upsertKcal(dayKey: DateTime.utc(2026, 1, 1), kcal: 250);
  await keyStore.write(testApiKey);
}

Future<void> _pumpButton(
  WidgetTester tester, {
  required AppDatabase db,
  required InMemorySecureKeyStore keyStore,
  required InMemoryAutoBackupStorage backups,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        secureKeyStoreProvider.overrideWithValue(keyStore),
        autoBackupStorageProvider.overrideWithValue(backups),
      ],
      child: const MaterialApp(home: Scaffold(body: DeleteAllDataButton())),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  late AppDatabase db;
  late InMemorySecureKeyStore keyStore;

  setUp(() {
    db = testDb();
    keyStore = InMemorySecureKeyStore();
  });

  tearDown(() async {
    await db.close();
  });

  testWidgets(
    'cancelling the confirm dialog is a no-op; confirming wipes DB + key',
    (tester) async {
      await _seed(db, keyStore);
      await _pumpButton(
        tester,
        db: db,
        keyStore: keyStore,
        backups: InMemoryAutoBackupStorage(),
      );

      // --- Unconfirmed: cancel must change nothing. ---
      await tester.tap(find.byKey(const Key('privacy_delete_all_button')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('privacy_delete_confirm_dialog')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('privacy_delete_cancel')));
      await tester.pumpAndSettle();

      expect(await keyStore.read(), testApiKey);
      expect(
        await db.appSettingsDao.getValue(PrivacyNoticeController.seenKey),
        'true',
      );
      for (final String table in _allTables) {
        expect(
          await _count(db, table),
          greaterThan(0),
          reason: '$table must survive an unconfirmed wipe',
        );
      }

      // --- Confirmed: DB and secret store are both emptied. ---
      await tester.tap(find.byKey(const Key('privacy_delete_all_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('privacy_delete_confirm')));
      await tester.pumpAndSettle();

      // The notice flag is reset (so the notice reappears)...
      expect(
        await db.appSettingsDao.getValue(PrivacyNoticeController.seenKey),
        isNull,
      );
      // ...the key is gone...
      expect(await keyStore.read(), isNull);
      // ...and every table has 0 rows.
      for (final String table in _allTables) {
        expect(
          await _count(db, table),
          0,
          reason: '$table must be empty after the wipe',
        );
      }
    },
  );

  testWidgets(
    'confirming the wipe also deletes the automatic backup documents',
    (tester) async {
      await _seed(db, keyStore);
      final InMemoryAutoBackupStorage backups = InMemoryAutoBackupStorage();
      backups.seed(
        'data-2026-01-01T12-00.json',
        '{"version":2}',
        savedAt: DateTime(2026, 1, 1),
      );
      backups.seed(
        'data-2026-01-02T12-00.json',
        '{"version":2}',
        savedAt: DateTime(2026, 1, 2),
      );
      await _pumpButton(tester, db: db, keyStore: keyStore, backups: backups);

      // --- Unconfirmed: the backups must survive. ---
      await tester.tap(find.byKey(const Key('privacy_delete_all_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('privacy_delete_cancel')));
      await tester.pumpAndSettle();
      expect(backups.documents, hasLength(2));

      // --- Confirmed: the backup folder is emptied too. ---
      await tester.tap(find.byKey(const Key('privacy_delete_all_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('privacy_delete_confirm')));
      await tester.pumpAndSettle();

      expect(backups.documents, isEmpty);
    },
  );
}
