// Drift exports its own SQL `isNull` helper, which clashes with the matcher.
import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:caldoo/data/db/app_database.dart';

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

  group('AppDatabase', () {
    test('is schema version 12', () {
      expect(db.schemaVersion, 12);
    });

    test('app_settings insert then read back the exact value', () async {
      await db
          .into(db.appSettings)
          .insert(
            AppSettingsCompanion.insert(key: 'notice_seen', value: 'true'),
          );

      final row = await (db.select(
        db.appSettings,
      )..where((t) => t.key.equals('notice_seen'))).getSingle();

      expect(row.key, 'notice_seen');
      expect(row.value, 'true');
    });

    test('app_settings update rewrites the value in place', () async {
      await db
          .into(db.appSettings)
          .insert(
            AppSettingsCompanion.insert(key: 'notice_seen', value: 'false'),
          );

      await (db.update(db.appSettings)
            ..where((t) => t.key.equals('notice_seen')))
          .write(const AppSettingsCompanion(value: Value('true')));

      final rows = await db.select(db.appSettings).get();
      expect(rows, hasLength(1));
      expect(rows.single.key, 'notice_seen');
      expect(rows.single.value, 'true');
    });

    test('app_settings delete removes the row', () async {
      await db
          .into(db.appSettings)
          .insert(
            AppSettingsCompanion.insert(key: 'notice_seen', value: 'true'),
          );

      await (db.delete(
        db.appSettings,
      )..where((t) => t.key.equals('notice_seen'))).go();

      expect(await db.select(db.appSettings).get(), isEmpty);
    });

    test('watch emits the initial state, then every change', () async {
      final query = db.select(db.appSettings)
        ..where((t) => t.key.equals('notice_seen'));

      final expectation = expectLater(
        query.watchSingleOrNull(),
        emitsInOrder(<Object?>[
          isNull,
          isA<AppSetting>()
              .having((row) => row.key, 'key', 'notice_seen')
              .having((row) => row.value, 'value', 'true'),
          isA<AppSetting>().having((row) => row.value, 'value', 'false'),
        ]),
      );

      // Let the initial (empty) event arrive before mutating.
      await pumpEventQueue();

      await db
          .into(db.appSettings)
          .insert(
            AppSettingsCompanion.insert(key: 'notice_seen', value: 'true'),
          );
      await (db.update(db.appSettings)
            ..where((t) => t.key.equals('notice_seen')))
          .write(const AppSettingsCompanion(value: Value('false')));

      await expectation;
    });

    test('close ends query streams cleanly', () async {
      final stream = db.select(db.appSettings).watch();

      final done = expectLater(stream, emitsDone);
      await db.close();
      closedByTest = true;
      await done;
    });
  });
}
