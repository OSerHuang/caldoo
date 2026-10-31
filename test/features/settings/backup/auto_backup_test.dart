// Automatic off-app backup: capture, retention, throttle and restore.
//
// The platform store is faked: these tests pin the RULES (never rotate a real
// copy out for an empty database, keep the newest 10, stay cheap on lifecycle
// calls, restore additively), not the Android channel.
import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:caldoo/data/db/app_database.dart';
import 'package:caldoo/data/repositories/drift_meal_repository.dart';
import 'package:caldoo/data/repositories/drift_profile_repository.dart';
import 'package:caldoo/data/settings/app_settings_store.dart';
import 'package:caldoo/domain/models/models.dart';
import 'package:caldoo/features/settings/backup/auto_backup_data.dart';
import 'package:caldoo/features/settings/backup/auto_backup_service.dart';
import 'package:caldoo/features/settings/backup/backup_data.dart';
import 'package:caldoo/features/settings/backup/backup_service.dart';

import '../../../data/db/_test_db.dart';
import '_auto_backup_fakes.dart';

/// Seeds one meal plus its profile, so [BackupService.capture] is non-empty.
Future<void> seedOneDay(AppDatabase db) async {
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

void main() {
  group('fileNameFor', () {
    test('stamps the local wall clock with second resolution', () {
      expect(
        AutoBackupService.fileNameFor(DateTime(2026, 1, 2, 3, 4, 5)),
        'data-20260102-030405.json',
      );
      expect(
        AutoBackupService.fileNameFor(DateTime(2026, 11, 30, 23, 59, 59)),
        'data-20261130-235959.json',
      );
    });
  });

  group('AutoBackupService', () {
    late AppDatabase db;
    late InMemoryAutoBackupStorage storage;
    late AutoBackupService service;
    late DateTime now;

    setUp(() {
      db = testDb();
      now = DateTime(2026, 10, 30, 21, 15);
      storage = InMemoryAutoBackupStorage(now: () => now);
      service = AutoBackupService(
        backupService: BackupService(db, clock: Clock(() => now)),
        autoBackupStorage: storage,
        settingsStore: AppSettingsStore(db.appSettingsDao),
        clock: Clock(() => now),
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('runNow writes one data-*.json copy of the whole dataset', () async {
      await seedOneDay(db);

      final AutoBackupResult result = await service.runNow();

      expect(result.outcome, AutoBackupOutcome.saved);
      expect(result.fileName, 'data-20261030-211500.json');
      expect(storage.writeCount, 1);
      final String json = storage.documents[result.fileName]!.json;
      final Map<String, dynamic> decoded =
          jsonDecode(json) as Map<String, dynamic>;
      expect(decoded['schemaVersion'], backupSchemaVersion);
      expect((decoded['meals'] as List<Object?>).length, 1);
      expect(decoded['profile'], isNotNull);
    });

    test('an empty database never writes (and never rotates) a copy', () async {
      final AutoBackupResult result = await service.runNow();

      expect(result.outcome, AutoBackupOutcome.skippedEmpty);
      expect(storage.writeCount, 0);
      expect(storage.documents, isEmpty);
    });

    test('retention keeps the newest 10 and prunes the rest', () async {
      // Twelve older copies from previous launches: the fake's list is
      // newest-first, so the two oldest must be the ones removed.
      for (int i = 0; i < 12; i++) {
        final DateTime savedAt = now.subtract(Duration(days: 30 - i));
        storage.seed(
          'data-old-${i.toString().padLeft(2, '0')}.json',
          '{"schemaVersion":4}',
          savedAt: savedAt,
        );
      }
      await seedOneDay(db);

      final AutoBackupResult result = await service.runNow();

      expect(result.outcome, AutoBackupOutcome.saved);
      expect(
        storage.documents.length,
        AutoBackupService.keepCount,
        reason: 'at most keepCount documents are kept',
      );
      expect(
        storage.documents.containsKey('data-old-00.json'),
        isFalse,
        reason: 'the oldest copy is pruned',
      );
      expect(
        storage.documents.containsKey('data-old-01.json'),
        isFalse,
        reason: 'the second-oldest copy is pruned',
      );
      expect(
        storage.documents.containsKey('data-20261030-211500.json'),
        isTrue,
        reason: 'the copy that was just written survives pruning',
      );
    });

    test('a platform without a durable target reports unavailable', () async {
      storage.available = false;
      await seedOneDay(db);

      expect((await service.runNow()).outcome, AutoBackupOutcome.unavailable);
      expect(
        (await service.maybeRun())?.outcome,
        AutoBackupOutcome.unavailable,
      );
      expect(storage.writeCount, 0);
    });

    test('the switch is persisted and off means no capture', () async {
      await seedOneDay(db);
      await service.setEnabled(false);

      expect(await service.isEnabled(), isFalse);
      expect((await service.maybeRun())?.outcome, AutoBackupOutcome.disabled);
      expect(storage.writeCount, 0);

      await service.setEnabled(true);
      expect(await service.isEnabled(), isTrue);
    });

    test('maybeRun throttles to one capture per minInterval', () async {
      await seedOneDay(db);

      expect((await service.maybeRun())?.outcome, AutoBackupOutcome.saved);
      expect(storage.writeCount, 1);

      // Still inside the window: no second capture, no error.
      now = now.add(const Duration(minutes: 1));
      expect((await service.maybeRun())?.outcome, AutoBackupOutcome.throttled);
      expect(storage.writeCount, 1);

      // Window elapsed: a fresh copy is written.
      now = now.add(AutoBackupService.minInterval);
      expect((await service.maybeRun())?.outcome, AutoBackupOutcome.saved);
      expect(storage.writeCount, 2);
    });

    test('a manual backup always runs regardless of the throttle', () async {
      await seedOneDay(db);
      await service.maybeRun();

      now = now.add(const Duration(seconds: 10));
      expect((await service.runNow()).outcome, AutoBackupOutcome.saved);
      expect(storage.writeCount, 2);
    });

    test('restore is additive: a second restore imports nothing', () async {
      await seedOneDay(db);
      final AutoBackupResult result = await service.runNow();
      final AutoBackupEntry entry = (await storage.list()).single;

      final AppDatabase target = testDb();
      addTearDown(target.close);
      final AutoBackupService targetService = AutoBackupService(
        backupService: BackupService(target, clock: Clock(() => now)),
        autoBackupStorage: storage,
        settingsStore: AppSettingsStore(target.appSettingsDao),
        clock: Clock(() => now),
      );

      final ImportSummary first = await targetService.restore(entry);
      expect(first.totalImported, greaterThan(0));
      expect(await DriftProfileRepository(target).loadProfile(), isNotNull);

      final ImportSummary second = await targetService.restore(entry);
      expect(second.totalImported, 0);
      expect(second.totalSkipped, first.totalImported);
      expect(result.fileName, entry.fileName);
    });

    test('restore of a document that vanished fails explicitly', () async {
      final AutoBackupEntry missing = AutoBackupEntry(
        fileName: 'data-20200101-000000.json',
        sizeBytes: 10,
        savedAt: _aDate,
      );
      await expectLater(
        service.restore(missing),
        throwsA(isA<AutoBackupMissingException>()),
      );
    });

    test(
      'importPickedFile imports a chosen file and stays quiet on cancel',
      () async {
        await seedOneDay(db);
        final String json = await BackupService(db).exportToJson();

        expect(await service.importPickedFile(), isNull);

        final AppDatabase target = testDb();
        addTearDown(target.close);
        storage.pickedJson = json;
        final AutoBackupService targetService = AutoBackupService(
          backupService: BackupService(target),
          autoBackupStorage: storage,
          settingsStore: AppSettingsStore(target.appSettingsDao),
        );

        final ImportSummary? summary = await targetService.importPickedFile();
        expect(summary, isNotNull);
        expect(summary!.totalImported, greaterThan(0));
      },
    );
  });
}

final DateTime _aDate = DateTime(2020, 1, 1);
