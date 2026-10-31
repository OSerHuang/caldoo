import 'package:flutter_test/flutter_test.dart';
import 'package:caldoo/data/db/app_database.dart';

import '_test_db.dart';

/// Monday 2026-09-21 — the date-only day key used throughout.
final DateTime monday = DateTime.utc(2026, 9, 21);

/// The next day.
final DateTime tuesday = DateTime.utc(2026, 9, 22);

/// The following Monday.
final DateTime nextMonday = DateTime.utc(2026, 9, 28);

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

  group('ExerciseDao', () {
    test('upsert then read back the value', () async {
      await db.exerciseDao.upsertKcal(dayKey: monday, kcal: 257);

      final row = await db.exerciseDao.getDay(monday);

      expect(row, isNotNull);
      expect(row!.kcal, 257);
      // The date-only key round-trips (drift reads back a local instant at the
      // same moment; the instant is what matters).
      expect(row.dayKey.toUtc(), monday);
    });

    test('upsert replaces the value for the same day', () async {
      await db.exerciseDao.upsertKcal(dayKey: monday, kcal: 100);
      await db.exerciseDao.upsertKcal(dayKey: monday, kcal: 261);

      final rows = await db.select(db.dailyExercises).get();
      expect(rows, hasLength(1));
      expect(rows.single.kcal, 261);
    });

    test('getDay returns null for an unknown day', () async {
      expect(await db.exerciseDao.getDay(monday), isNull);
    });

    test('deleteDay removes the value', () async {
      await db.exerciseDao.upsertKcal(dayKey: monday, kcal: 300);

      expect(await db.exerciseDao.deleteDay(monday), 1);
      expect(await db.exerciseDao.getDay(monday), isNull);
      expect(await db.exerciseDao.deleteDay(monday), 0);
    });

    test('watchRange honours the half-open day-key bounds', () async {
      await db.exerciseDao.upsertKcal(
        dayKey: monday.subtract(const Duration(days: 1)),
        kcal: 50,
      );
      await db.exerciseDao.upsertKcal(dayKey: monday, kcal: 100);
      await db.exerciseDao.upsertKcal(dayKey: nextMonday, kcal: 900);

      final rows = await db.exerciseDao
          .watchRange(startInclusive: monday, endExclusive: nextMonday)
          .first;

      expect(rows.map((row) => row.kcal).toList(), <int>[100]);
    });

    test('watchDay emits on insert and on update', () async {
      final stream = db.exerciseDao.watchDay(monday);

      final expectation = expectLater(
        stream,
        emitsInOrder(<Object?>[
          isNull,
          isA<DailyExerciseRow>().having((row) => row.kcal, 'kcal', 257),
          isA<DailyExerciseRow>().having((row) => row.kcal, 'kcal', 260),
        ]),
      );

      // Let the initial (empty) event arrive before mutating.
      await pumpEventQueue();

      await db.exerciseDao.upsertKcal(dayKey: monday, kcal: 257);
      await db.exerciseDao.upsertKcal(dayKey: monday, kcal: 260);

      await expectation;
    });

    test('watchRange reports the window ordered by day', () async {
      final stream = db.exerciseDao.watchRange(
        startInclusive: monday,
        endExclusive: nextMonday,
      );
      final emissions = <List<DailyExerciseRow>>[];
      final subscription = stream.listen(emissions.add);

      await pumpEventQueue();
      expect(emissions, <Object>[isEmpty]);

      // One transaction so the watcher sees one consistent emission.
      await db.transaction(() async {
        await db.exerciseDao.upsertKcal(dayKey: tuesday, kcal: 200);
        await db.exerciseDao.upsertKcal(dayKey: monday, kcal: 100);
      });
      await pumpEventQueue();

      expect(emissions.last.map((row) => row.kcal).toList(), <int>[100, 200]);

      await subscription.cancel();
    });
  });
}
