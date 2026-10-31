// Drift exports its own SQL `isNull` helper, which clashes with the matcher.
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

  group('AppSettingsDao', () {
    test('setValue inserts then rewrites in place', () async {
      await db.appSettingsDao.setValue('notice_seen', 'false');
      expect(await db.appSettingsDao.getValue('notice_seen'), 'false');

      await db.appSettingsDao.setValue('notice_seen', 'true');

      expect(await db.appSettingsDao.getValue('notice_seen'), 'true');
      expect(await db.appSettingsDao.getAll(), hasLength(1));
    });

    test('getValue returns null for a missing key', () async {
      expect(await db.appSettingsDao.getValue('nope'), isNull);
    });

    test('deleteValue removes only that key', () async {
      await db.appSettingsDao.setValue('a', '1');
      await db.appSettingsDao.setValue('b', '2');

      expect(await db.appSettingsDao.deleteValue('a'), 1);
      expect(await db.appSettingsDao.getValue('a'), isNull);
      expect(await db.appSettingsDao.getValue('b'), '2');
      expect(await db.appSettingsDao.deleteValue('a'), 0);
    });

    test('getAll returns every setting ordered by key', () async {
      await db.appSettingsDao.setValue('model', 'deepseek-chat');
      await db.appSettingsDao.setValue('baseUrl', 'https://api.deepseek.com');
      await db.appSettingsDao.setValue('notice_seen', 'true');

      final rows = await db.appSettingsDao.getAll();

      expect(rows.map((row) => row.key).toList(), <String>[
        'baseUrl',
        'model',
        'notice_seen',
      ]);
      expect(rows[1].value, 'deepseek-chat');
    });

    test('watchValue emits null, then every stored value', () async {
      final stream = db.appSettingsDao.watchValue('notice_seen');

      final expectation = expectLater(
        stream,
        emitsInOrder(<Object?>[isNull, 'false', 'true']),
      );

      // Let the initial (empty) event arrive before mutating.
      await pumpEventQueue();

      await db.appSettingsDao.setValue('notice_seen', 'false');
      await db.appSettingsDao.setValue('notice_seen', 'true');

      await expectation;
    });

    test('watchAll emits the full key/value set on every change', () async {
      final stream = db.appSettingsDao.watchAll();

      final expectation = expectLater(
        stream,
        emitsInOrder(<Object?>[
          isEmpty,
          isA<List<AppSetting>>().having(
            (rows) => rows.map((row) => row.key).toList(),
            'keys',
            <String>['baseUrl', 'model'],
          ),
          isA<List<AppSetting>>().having(
            (rows) => rows.map((row) => row.key).toList(),
            'keys',
            <String>['model'],
          ),
        ]),
      );

      // Let the initial (empty) event arrive before mutating.
      await pumpEventQueue();

      // One transaction, so the watcher sees one consistent emission.
      await db.transaction(() async {
        await db.appSettingsDao.setValue('model', 'deepseek-chat');
        await db.appSettingsDao.setValue('baseUrl', 'https://api.deepseek.com');
      });
      await db.appSettingsDao.deleteValue('baseUrl');

      await expectation;
    });

    test('clear wipes every setting', () async {
      await db.appSettingsDao.setValue('a', '1');
      await db.appSettingsDao.setValue('b', '2');

      expect(await db.appSettingsDao.clear(), 2);
      expect(await db.appSettingsDao.getAll(), isEmpty);
    });
  });
}
