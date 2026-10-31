// The backup screen's automatic-backup block: status, manual backup, restore
// from a listed copy and the "import from file" picker.
//
// The platform store is faked (`_auto_backup_fakes.dart`); the database is the
// usual in-memory harness, so a restore really writes rows and the additive
// policy is observable.
import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:caldoo/data/db/app_database.dart';
import 'package:caldoo/data/repositories/drift_meal_repository.dart';
import 'package:caldoo/data/repositories/drift_profile_repository.dart';
import 'package:caldoo/data/settings/app_settings_store.dart';
import 'package:caldoo/domain/models/models.dart';
import 'package:caldoo/features/settings/backup/auto_backup_data.dart';
import 'package:caldoo/features/settings/backup/auto_backup_providers.dart';
import 'package:caldoo/features/settings/backup/auto_backup_service.dart';
import 'package:caldoo/features/settings/backup/backup_service.dart';
import 'package:caldoo/features/settings/backup/backup_screen.dart';
import 'package:caldoo/features/settings/settings_providers.dart';

import '../../../data/db/_test_db.dart';
import '_auto_backup_fakes.dart';

Future<void> _seedOneMeal(AppDatabase db) async {
  await DriftProfileRepository(db).saveProfile(
    UserProfile(
      sex: Sex.female,
      birthDate: DateTime.utc(1997, 3, 14),
      heightCm: 162.5,
      weightKg: 55.25,
    ),
  );
  await DriftMealRepository(db).saveMealWithItems(
    Meal(
      id: 'm1',
      timestamp: DateTime(2026, 10, 30, 8, 15),
      mealType: MealType.breakfast,
    ),
    const <MealItem>[
      MealItem(
        id: 'i1',
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
}

Future<void> _pumpScreen(
  WidgetTester tester, {
  required AppDatabase db,
  required InMemoryAutoBackupStorage storage,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        autoBackupStorageProvider.overrideWithValue(storage),
      ],
      child: const MaterialApp(home: BackupScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  late AppDatabase db;
  late InMemoryAutoBackupStorage storage;

  setUp(() {
    db = testDb();
    storage = InMemoryAutoBackupStorage(
      now: () => DateTime(2026, 10, 30, 21, 30),
    );
  });

  tearDown(() async {
    await db.close();
  });

  testWidgets('an unsupported platform disables the switch and says so', (
    tester,
  ) async {
    storage.available = false;
    await _pumpScreen(tester, db: db, storage: storage);

    expect(find.text('当前设备不支持自动备份'), findsOneWidget);
    final Switch toggle = tester.widget<Switch>(
      find.descendant(
        of: find.byKey(autoBackupToggleKey),
        matching: find.byType(Switch),
      ),
    );
    expect(toggle.onChanged, isNull);
    expect(find.byKey(autoBackupNowKey), findsNothing);
  });

  testWidgets('a listed copy can be restored through the confirm dialog', (
    tester,
  ) async {
    await _seedOneMeal(db);
    // Produce a real document in the fake folder through the same service the
    // screen uses, so the restore imports genuine JSON.
    final AutoBackupService service = AutoBackupService(
      backupService: BackupService(db),
      autoBackupStorage: storage,
      settingsStore: AppSettingsStore(db.appSettingsDao),
      clock: Clock(() => DateTime(2026, 10, 30, 21, 30)),
    );
    final AutoBackupResult result = await service.runNow();
    expect(result.didSave, isTrue);

    await _pumpScreen(tester, db: db, storage: storage);

    // Status: one copy, timestamped from the fake's fixed clock.
    expect(find.textContaining('共 1 份'), findsOneWidget);

    // The local database is wiped to model the disaster this feature guards
    // against, then the listed copy restores it.
    await db.delete(db.mealItems).go();
    await db.delete(db.meals).go();
    await db.delete(db.userProfiles).go();

    final Finder entryFinder = find.byKey(
      autoBackupEntryKey('data-20261030-213000.json'),
    );
    await tester.scrollUntilVisible(entryFinder, 200);
    await tester.tap(entryFinder);
    await tester.pumpAndSettle();
    expect(find.byKey(autoBackupRestoreDialogKey), findsOneWidget);
    await tester.tap(find.byKey(autoBackupRestoreConfirmKey));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.byKey(backupResultKey), 200);
    expect(find.textContaining('导入完成'), findsOneWidget);
    expect(await DriftProfileRepository(db).loadProfile(), isNotNull);
  });

  testWidgets('the manual backup button writes a copy and reports it', (
    tester,
  ) async {
    await _seedOneMeal(db);
    await _pumpScreen(tester, db: db, storage: storage);

    await tester.tap(find.byKey(autoBackupNowKey));
    await tester.pumpAndSettle();

    expect(storage.writeCount, 1);
    await tester.scrollUntilVisible(find.byKey(backupResultKey), 200);
    expect(find.textContaining('已保存自动备份'), findsOneWidget);
  });

  testWidgets('cancelling the file picker reports "未选择文件"', (tester) async {
    storage.pickedJson = null;
    await _pumpScreen(tester, db: db, storage: storage);

    await tester.tap(find.byKey(backupImportFileKey));
    await tester.pumpAndSettle();

    expect(find.text('未选择文件'), findsOneWidget);
  });

  testWidgets('the switch persists its value to app_settings', (tester) async {
    await _pumpScreen(tester, db: db, storage: storage);

    await tester.tap(find.byKey(autoBackupToggleKey));
    await tester.pumpAndSettle();

    expect(
      await db.appSettingsDao.getValue(AutoBackupService.enabledSettingKey),
      'false',
    );
  });
}
