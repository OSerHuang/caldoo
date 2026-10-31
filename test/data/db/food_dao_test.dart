// Drift exports its own SQL `isNull` helper, which clashes with the matcher.
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:caldoo/data/db/app_database.dart';
import 'package:caldoo/domain/models/food.dart';

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

  group('FoodDao', () {
    test('insert then read back every field', () async {
      await db.foodDao.insertFood(
        FoodsCompanion.insert(
          id: 'f-milk',
          name: '全脂牛奶',
          brand: const Value<String?>('光明'),
          barcode: const Value<String?>('6901234567890'),
          notes: const Value<String?>('一包 250 ml；别名：牛奶'),
          source: FoodSource.label,
          kcal: const Value<int?>(65),
          carbG: const Value<double?>(4.8),
          proteinG: const Value<double?>(3.3),
          fatG: const Value<double?>(3.6),
          sodiumMg: const Value<double?>(50),
        ),
      );

      final row = await db.foodDao.getFood('f-milk');

      expect(row, isNotNull);
      expect(row!.id, 'f-milk');
      expect(row.name, '全脂牛奶');
      expect(row.brand, '光明');
      expect(row.barcode, '6901234567890');
      expect(row.notes, '一包 250 ml；别名：牛奶');
      expect(row.source, FoodSource.label);
      expect(row.kcal, 65);
      expect(row.carbG, 4.8);
      expect(row.proteinG, 3.3);
      expect(row.fatG, 3.6);
      expect(row.sodiumMg, 50);
    });

    test('update rewrites the stored values in place', () async {
      await db.foodDao.insertFood(
        FoodsCompanion.insert(id: 'f1', name: '红烧肉', source: FoodSource.manual),
      );

      final updated = await db.foodDao.updateFood(
        FoodsCompanion.insert(
          id: 'f1',
          name: '自制红烧肉',
          brand: const Value<String?>('家'),
          notes: const Value<String?>('一包 500 g'),
          source: FoodSource.manual,
          kcal: const Value<int?>(472),
          proteinG: const Value<double?>(9.5),
        ),
      );

      final row = await db.foodDao.getFood('f1');
      expect(updated, isTrue);
      expect(row!.name, '自制红烧肉');
      expect(row.brand, '家');
      expect(row.notes, '一包 500 g');
      expect(row.kcal, 472);
      expect(row.proteinG, 9.5);
      // Absent nullable fields in the replacement are NULL, not stale values.
      expect(row.carbG, isNull);
      expect(row.fatG, isNull);
      expect(row.sodiumMg, isNull);
    });

    test('update returns false for a food that does not exist', () async {
      final updated = await db.foodDao.updateFood(
        FoodsCompanion.insert(id: 'nope', name: 'x', source: FoodSource.ai),
      );
      expect(updated, isFalse);
    });

    test('delete removes only the requested food', () async {
      await db.foodDao.insertFood(
        FoodsCompanion.insert(id: 'f1', name: '米饭', source: FoodSource.manual),
      );
      await db.foodDao.insertFood(
        FoodsCompanion.insert(id: 'f2', name: '鸡蛋', source: FoodSource.manual),
      );

      expect(await db.foodDao.deleteFood('f1'), 1);
      expect(await db.foodDao.getFood('f1'), isNull);
      expect(await db.foodDao.getFood('f2'), isNotNull);
      expect(await db.foodDao.deleteFood('f1'), 0);
    });

    test('blank nutrients round-trip as SQL NULL, never as 0', () async {
      // A GB 28050 label may omit values; insert them absent on purpose.
      await db.foodDao.insertFood(
        FoodsCompanion.insert(
          id: 'f-sparse',
          name: '自制汤',
          source: FoodSource.manual,
        ),
      );

      final row = await db.foodDao.getFood('f-sparse');
      expect(row!.kcal, isNull);
      expect(row.carbG, isNull);
      expect(row.proteinG, isNull);
      expect(row.fatG, isNull);
      expect(row.sodiumMg, isNull);
      expect(row.brand, isNull);
      expect(row.barcode, isNull);

      final raw = await db
          .customSelect(
            'SELECT kcal, carb_g, protein_g, fat_g, sodium_mg FROM foods '
            'WHERE id = ?',
            variables: const <Variable<Object>>[Variable<String>('f-sparse')],
          )
          .getSingle();

      expect(raw.data['kcal'], isNull);
      expect(raw.data['carb_g'], isNull);
      expect(raw.data['protein_g'], isNull);
      expect(raw.data['fat_g'], isNull);
      expect(raw.data['sodium_mg'], isNull);

      final count = await db
          .customSelect(
            'SELECT COUNT(*) AS n FROM foods WHERE kcal IS NULL '
            'AND carb_g IS NULL AND protein_g IS NULL AND fat_g IS NULL '
            'AND sodium_mg IS NULL',
          )
          .getSingle();
      expect(count.data['n'], 1);
    });

    test(
      'explicitly writing Value(null) stores NULL; absent leaves the value',
      () async {
        await db.foodDao.insertFood(
          FoodsCompanion.insert(
            id: 'f1',
            name: '酸奶',
            source: FoodSource.label,
            kcal: const Value<int?>(72),
            proteinG: const Value<double?>(2.5),
          ),
        );

        // A partial `write` with an absent column must not touch the stored value.
        await (db.update(db.foods)..where((t) => t.id.equals('f1'))).write(
          const FoodsCompanion(name: Value<String>('无糖酸奶')),
        );
        var row = await db.foodDao.getFood('f1');
        expect(row!.kcal, 72);
        expect(row.proteinG, 2.5);

        // Value(null) is an explicit "set this column to NULL".
        await (db.update(db.foods)..where((t) => t.id.equals('f1'))).write(
          const FoodsCompanion(kcal: Value<int?>(null)),
        );
        row = await db.foodDao.getFood('f1');
        expect(row!.kcal, isNull);
        expect(row.proteinG, 2.5);
      },
    );

    test('the source enum is persisted by name', () async {
      await db.foodDao.insertFood(
        FoodsCompanion.insert(id: 'f1', name: 'AI 估算', source: FoodSource.ai),
      );

      final raw = await db
          .customSelect(
            'SELECT source FROM foods WHERE id = ?',
            variables: const <Variable<Object>>[Variable<String>('f1')],
          )
          .getSingle();
      expect(raw.data['source'], 'ai');
    });

    test('watchAllFoods emits the catalogue on every change', () async {
      final stream = db.foodDao.watchAllFoods();

      final expectation = expectLater(
        stream,
        emitsInOrder(<Object?>[
          isEmpty,
          isA<List<FoodRow>>().having(
            (rows) => rows.map((row) => row.name).toList(),
            'names',
            <String>['egg', 'milk'],
          ),
          isA<List<FoodRow>>().having(
            (rows) => rows.map((row) => row.name).toList(),
            'names',
            <String>['milk'],
          ),
        ]),
      );

      // Let the initial (empty) event arrive before mutating.
      await pumpEventQueue();

      // One transaction, so the watcher sees one consistent emission.
      await db.transaction(() async {
        await db.foodDao.insertFood(
          FoodsCompanion.insert(
            id: 'f2',
            name: 'egg',
            source: FoodSource.manual,
          ),
        );
        await db.foodDao.insertFood(
          FoodsCompanion.insert(
            id: 'f1',
            name: 'milk',
            source: FoodSource.manual,
          ),
        );
      });
      await db.foodDao.deleteFood('f2');

      await expectation;
    });
  });
}
