// Drift exports its own SQL `isNull` helper, which clashes with the matcher.
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart' show SqliteException;
import 'package:flutter_test/flutter_test.dart';
import 'package:caldoo/data/db/app_database.dart';
import 'package:caldoo/data/db/daos/meal_dao.dart';
import 'package:caldoo/domain/models/food.dart';
import 'package:caldoo/domain/models/meal.dart';

import '_test_db.dart';

/// Monday 2026-09-21 00:00 UTC — the start of the test week.
final DateTime monday = DateTime.utc(2026, 9, 21);

/// The following Monday, i.e. the exclusive end of the test week.
final DateTime nextMonday = DateTime.utc(2026, 9, 28);

MealsCompanion mealCompanion({
  String id = 'm1',
  DateTime? timestamp,
  MealType mealType = MealType.lunch,
  String? note,
}) {
  return MealsCompanion.insert(
    id: id,
    timestamp: timestamp ?? DateTime.utc(2026, 9, 21, 12),
    mealType: mealType,
    note: Value<String?>(note),
  );
}

MealItemsCompanion itemCompanion({
  required String id,
  String mealId = 'm1',
  String? foodId,
  String name = '米饭',
  double grams = 150,
  int kcal = 174,
  double carbG = 38.9,
  double proteinG = 3.6,
  double fatG = 0.3,
  double saltG = 0.0005,
  FoodSource source = FoodSource.ai,
  double? confidence,
}) {
  return MealItemsCompanion.insert(
    id: id,
    mealId: mealId,
    foodId: Value<String?>(foodId),
    name: name,
    grams: grams,
    kcal: kcal,
    carbG: carbG,
    proteinG: proteinG,
    fatG: fatG,
    saltG: saltG,
    source: source,
    confidence: Value<double?>(confidence),
  );
}

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

  Future<void> saveTwoItemLunch() {
    return db.mealDao.saveMealWithItems(
      meal: mealCompanion(note: '工作日午餐'),
      items: <MealItemsCompanion>[
        itemCompanion(id: 'i1'),
        itemCompanion(
          id: 'i2',
          name: '西红柿炒蛋',
          grams: 200,
          kcal: 120,
          carbG: 6,
          proteinG: 9,
          fatG: 7,
          saltG: 0.9,
        ),
      ],
    );
  }

  group('MealDao meals CRUD', () {
    test('insert then read back every meal field', () async {
      await db.mealDao.insertMeal(mealCompanion(note: '有点咸'));

      final row = await db.mealDao.getMeal('m1');

      expect(row, isNotNull);
      expect(row!.id, 'm1');
      expect(
        row.timestamp.isAtSameMomentAs(DateTime.utc(2026, 9, 21, 12)),
        isTrue,
      );
      expect(row.mealType, MealType.lunch);
      expect(row.note, '有点咸');
    });

    test('update rewrites the stored meal in place', () async {
      await db.mealDao.insertMeal(mealCompanion());

      final updated = await db.mealDao.updateMeal(
        mealCompanion(
          timestamp: DateTime.utc(2026, 9, 21, 19, 30),
          mealType: MealType.dinner,
          note: '改了时间',
        ),
      );

      final row = await db.mealDao.getMeal('m1');
      expect(updated, isTrue);
      expect(
        row!.timestamp.isAtSameMomentAs(DateTime.utc(2026, 9, 21, 19, 30)),
        isTrue,
      );
      expect(row.mealType, MealType.dinner);
      expect(row.note, '改了时间');
    });

    test('update returns false for a meal that does not exist', () async {
      expect(await db.mealDao.updateMeal(mealCompanion(id: 'nope')), isFalse);
    });

    test('delete removes the meal', () async {
      await db.mealDao.insertMeal(mealCompanion());

      expect(await db.mealDao.deleteMeal('m1'), 1);
      expect(await db.mealDao.getMeal('m1'), isNull);
      expect(await db.mealDao.deleteMeal('m1'), 0);
    });

    test('getMealsInRange honours the supplied bounds', () async {
      await db.mealDao.insertMeal(
        mealCompanion(
          id: 'm-before',
          timestamp: monday.subtract(const Duration(minutes: 1)),
        ),
      );
      await db.mealDao.insertMeal(
        mealCompanion(
          id: 'm-monday',
          timestamp: monday.add(const Duration(minutes: 5)),
        ),
      );
      await db.mealDao.insertMeal(
        mealCompanion(
          id: 'm-sunday',
          timestamp: nextMonday.subtract(const Duration(minutes: 1)),
        ),
      );
      await db.mealDao.insertMeal(
        mealCompanion(id: 'm-next-monday', timestamp: nextMonday),
      );

      final rows = await db.mealDao.getMealsInRange(
        startInclusive: monday,
        endExclusive: nextMonday,
      );

      expect(rows.map((row) => row.id).toList(), <String>[
        'm-monday',
        'm-sunday',
      ]);
    });
  });

  group('MealDao replaceMealWithItems (the edit path)', () {
    test('rewrites the row and swaps the item list wholesale', () async {
      await saveTwoItemLunch();

      await db.mealDao.replaceMealWithItems(
        meal: mealCompanion(
          timestamp: DateTime.utc(2026, 9, 21, 19, 30),
          note: '改过了',
        ),
        items: <MealItemsCompanion>[
          itemCompanion(id: 'i1', grams: 300, kcal: 348),
          itemCompanion(id: 'i3', name: '鸡蛋', kcal: 70),
        ],
      );

      final row = await db.mealDao.getMeal('m1');
      expect(row!.note, '改过了');
      expect(
        row.timestamp.isAtSameMomentAs(DateTime.utc(2026, 9, 21, 19, 30)),
        isTrue,
      );
      final groups = await db.mealDao.getMealsWithItemsInRange(
        startInclusive: monday,
        endExclusive: nextMonday,
      );
      final items = groups.single.items;
      // The dropped 西红柿炒蛋 row is gone; the kept id carries its new values
      // and the added row is in.
      expect(items, hasLength(2));
      expect(items.map((r) => r.id), <String>['i1', 'i3']);
      expect(items.first.grams, 300);
      expect(items.first.kcal, 348);
    });

    test('throws for a meal that does not exist and writes nothing', () async {
      await saveTwoItemLunch();

      await expectLater(
        db.mealDao.replaceMealWithItems(
          meal: mealCompanion(id: 'nope'),
          items: <MealItemsCompanion>[itemCompanion(id: 'i9')],
        ),
        throwsStateError,
      );

      // The failed transaction left the stored meal untouched.
      final groups = await db.mealDao.getMealsWithItemsInRange(
        startInclusive: monday,
        endExclusive: nextMonday,
      );
      expect(groups.single.items, hasLength(2));
    });

    test('the day stream re-emits after the replace', () async {
      await saveTwoItemLunch();

      final stream = db.mealDao.watchMealsForDay(
        dayStartInclusive: monday,
        dayEndExclusive: monday.add(const Duration(days: 1)),
      );
      final emissions = <List<MealWithItemRows>>[];
      final subscription = stream.listen(emissions.add);
      await pumpEventQueue();
      expect(emissions.last.single.items, hasLength(2));

      await db.mealDao.replaceMealWithItems(
        meal: mealCompanion(),
        items: <MealItemsCompanion>[itemCompanion(id: 'i1')],
      );
      await pumpEventQueue();

      expect(emissions.last.single.items, hasLength(1));

      await subscription.cancel();
    });
  });

  group('MealDao items CRUD', () {
    setUp(() async {
      await db.mealDao.insertMeal(mealCompanion());
    });

    test('insertItems batch then read back ordered', () async {
      await db.mealDao.insertItems(<MealItemsCompanion>[
        itemCompanion(id: 'i2', name: '西红柿炒蛋', confidence: 0.8),
        itemCompanion(id: 'i1'),
      ]);

      final rows = await db.mealDao.getItemsForMeal('m1');

      expect(rows.map((row) => row.id).toList(), <String>['i1', 'i2']);
      expect(rows.first.name, '米饭');
      expect(rows.last.confidence, 0.8);
      expect(rows.last.foodId, isNull);
    });

    test('update rewrites the stored item in place', () async {
      await db.mealDao.insertItem(itemCompanion(id: 'i1'));

      final updated = await db.mealDao.updateItem(
        itemCompanion(
          id: 'i1',
          foodId: 'f-milk',
          grams: 200,
          kcal: 130,
          carbG: 9.6,
          proteinG: 6.6,
          fatG: 7.2,
          saltG: 0.1,
          source: FoodSource.label,
          confidence: 1,
        ),
      );

      final row = (await db.mealDao.getItemsForMeal('m1')).single;
      expect(updated, isTrue);
      expect(row.foodId, 'f-milk');
      expect(row.grams, 200);
      expect(row.kcal, 130);
      expect(row.saltG, 0.1);
      expect(row.source, FoodSource.label);
      expect(row.confidence, 1);
    });

    test('deleteItem removes only that item', () async {
      await db.mealDao.insertItems(<MealItemsCompanion>[
        itemCompanion(id: 'i1'),
        itemCompanion(id: 'i2', name: '鸡蛋'),
      ]);

      expect(await db.mealDao.deleteItem('i1'), 1);
      expect(await db.mealDao.getItemsForMeal('m1'), hasLength(1));
      expect((await db.mealDao.getItemsForMeal('m1')).single.id, 'i2');
    });
  });

  group('MealDao referential integrity', () {
    test('deleting a meal cascades to its items', () async {
      await saveTwoItemLunch();
      expect(await db.mealDao.getItemsForMeal('m1'), hasLength(2));

      final deleted = await db.mealDao.deleteMeal('m1');

      expect(deleted, 1);
      expect(await db.mealDao.getMeal('m1'), isNull);
      expect(await db.mealDao.getItemsForMeal('m1'), isEmpty);
      expect(await db.select(db.mealItems).get(), isEmpty);
    });

    test(
      'an item without a parent meal is rejected by the foreign key',
      () async {
        await expectLater(
          db.mealDao.insertItem(
            itemCompanion(id: 'i-orphan', mealId: 'missing'),
          ),
          throwsA(isA<SqliteException>()),
        );
        expect(await db.select(db.mealItems).get(), isEmpty);
      },
    );
  });

  group('MealDao reactive day/week windows', () {
    test(
      'watchMealsForDay emits the meal with its 2 items after a change',
      () async {
        final stream = db.mealDao.watchMealsForDay(
          dayStartInclusive: monday,
          dayEndExclusive: monday.add(const Duration(days: 1)),
        );

        final expectation = expectLater(
          stream,
          emitsInOrder(<Object?>[
            isEmpty,
            isA<List<MealWithItemRows>>()
                .having((rows) => rows, 'rows', hasLength(1))
                .having((rows) => rows.single.meal.id, 'meal id', 'm1')
                .having(
                  (rows) => rows.single.meal.mealType,
                  'meal type',
                  MealType.lunch,
                )
                .having((rows) => rows.single.items, 'items', hasLength(2))
                .having(
                  (rows) => rows.single.items.map((item) => item.name).toList(),
                  'item names',
                  containsAll(<String>['米饭', '西红柿炒蛋']),
                ),
          ]),
        );

        // Let the initial (empty) event arrive before mutating.
        await pumpEventQueue();

        await saveTwoItemLunch();

        await expectation;
      },
    );

    test(
      'watchMealsForDay only reports meals inside the supplied day bounds',
      () async {
        final stream = db.mealDao.watchMealsForDay(
          dayStartInclusive: monday,
          dayEndExclusive: monday.add(const Duration(days: 1)),
        );
        final emissions = <List<MealWithItemRows>>[];
        final subscription = stream.listen(emissions.add);

        await pumpEventQueue();
        expect(emissions, <Object>[isEmpty]);

        // One transaction so the watcher sees one consistent emission.
        await db.transaction(() async {
          await db.mealDao.saveMealWithItems(
            meal: mealCompanion(
              id: 'm-monday',
              timestamp: monday.add(const Duration(hours: 12)),
            ),
            items: <MealItemsCompanion>[
              itemCompanion(id: 'i1', mealId: 'm-monday'),
            ],
          );
          await db.mealDao.saveMealWithItems(
            meal: mealCompanion(
              id: 'm-tuesday',
              timestamp: monday.add(const Duration(days: 1, hours: 12)),
            ),
            items: <MealItemsCompanion>[
              itemCompanion(id: 'i2', mealId: 'm-tuesday'),
            ],
          );
        });
        await pumpEventQueue();

        expect(emissions.last.map((row) => row.meal.id).toList(), <String>[
          'm-monday',
        ]);
        expect(emissions.last.single.items.single.id, 'i1');

        await subscription.cancel();
      },
    );

    test('watchMealsForWeek reports the whole Monday..Sunday window', () async {
      final stream = db.mealDao.watchMealsForWeek(
        weekStartInclusive: monday,
        weekEndExclusive: nextMonday,
      );
      final emissions = <List<MealWithItemRows>>[];
      final subscription = stream.listen(emissions.add);

      await pumpEventQueue();
      expect(emissions, <Object>[isEmpty]);

      await db.transaction(() async {
        await db.mealDao.saveMealWithItems(
          meal: mealCompanion(
            id: 'm-mon',
            timestamp: monday.add(const Duration(minutes: 5)),
          ),
          items: <MealItemsCompanion>[itemCompanion(id: 'i1', mealId: 'm-mon')],
        );
        await db.mealDao.saveMealWithItems(
          meal: mealCompanion(
            id: 'm-sun',
            timestamp: nextMonday.subtract(const Duration(minutes: 1)),
          ),
          items: <MealItemsCompanion>[itemCompanion(id: 'i2', mealId: 'm-sun')],
        );
        // Outside the week window: must never appear.
        await db.mealDao.saveMealWithItems(
          meal: mealCompanion(id: 'm-next-mon', timestamp: nextMonday),
          items: <MealItemsCompanion>[
            itemCompanion(id: 'i3', mealId: 'm-next-mon'),
          ],
        );
      });
      await pumpEventQueue();

      expect(emissions.last.map((row) => row.meal.id).toList(), <String>[
        'm-mon',
        'm-sun',
      ]);

      await subscription.cancel();
    });

    test('the day stream re-emits when an item of the meal changes', () async {
      await saveTwoItemLunch();

      final stream = db.mealDao.watchMealsForDay(
        dayStartInclusive: monday,
        dayEndExclusive: monday.add(const Duration(days: 1)),
      );
      final emissions = <List<MealWithItemRows>>[];
      final subscription = stream.listen(emissions.add);

      await pumpEventQueue();
      expect(emissions.last.single.items, hasLength(2));

      await db.mealDao.insertItem(
        itemCompanion(id: 'i3', name: '紫菜蛋花汤', kcal: 60),
      );
      await pumpEventQueue();

      expect(emissions.last.single.items, hasLength(3));

      await subscription.cancel();
    });

    test('getMealsWithItemsInRange pairs every meal with its items', () async {
      await saveTwoItemLunch();
      await db.mealDao.saveMealWithItems(
        meal: mealCompanion(
          id: 'm2',
          timestamp: DateTime.utc(2026, 9, 22, 8),
          mealType: MealType.breakfast,
        ),
        items: <MealItemsCompanion>[
          itemCompanion(id: 'i3', mealId: 'm2', name: '豆浆'),
        ],
      );

      final rows = await db.mealDao.getMealsWithItemsInRange(
        startInclusive: monday,
        endExclusive: nextMonday,
      );

      expect(rows, hasLength(2));
      expect(rows.first.meal.id, 'm1');
      expect(rows.first.items, hasLength(2));
      expect(rows.last.meal.id, 'm2');
      expect(rows.last.items.single.name, '豆浆');
    });
  });

  group('MealDao NULL handling', () {
    test(
      'a blank confidence and food link round-trip as SQL NULL, not 0',
      () async {
        await saveTwoItemLunch();

        final row = (await db.mealDao.getItemsForMeal('m1')).first;
        expect(row.confidence, isNull);
        expect(row.foodId, isNull);

        final raw = await db
            .customSelect(
              'SELECT confidence, food_id FROM meal_items WHERE id = ?',
              variables: const <Variable<Object>>[Variable<String>('i1')],
            )
            .getSingle();
        expect(raw.data['confidence'], isNull);
        expect(raw.data['food_id'], isNull);

        final count = await db
            .customSelect(
              'SELECT COUNT(*) AS n FROM meal_items '
              'WHERE confidence IS NULL AND food_id IS NULL',
            )
            .getSingle();
        // Both items of the saved lunch round-trip with NULLs, not zeros.
        expect(count.data['n'], 2);
      },
    );

    test('a blank meal note round-trips as SQL NULL', () async {
      await db.mealDao.insertMeal(mealCompanion());

      final raw = await db
          .customSelect(
            'SELECT note FROM meals WHERE id = ?',
            variables: const <Variable<Object>>[Variable<String>('m1')],
          )
          .getSingle();
      expect(raw.data['note'], isNull);
      expect((await db.mealDao.getMeal('m1'))!.note, isNull);
    });
  });

  group('MealDao getMealIdsForFood', () {
    test('a meal linking the food on several items comes back once', () async {
      // The natural double-link: rice logged as two lines of one meal.
      await db.mealDao.saveMealWithItems(
        meal: mealCompanion(id: 'm1'),
        items: <MealItemsCompanion>[
          itemCompanion(id: 'i1', foodId: 'food-x'),
          itemCompanion(id: 'i2', foodId: 'food-x'),
        ],
      );
      await db.mealDao.saveMealWithItems(
        meal: mealCompanion(id: 'm2'),
        items: <MealItemsCompanion>[
          itemCompanion(id: 'i3', mealId: 'm2', foodId: 'food-x'),
        ],
      );

      final ids = await db.mealDao.getMealIdsForFood('food-x');

      // One id per MEAL, not per linking item — the recompute flow reports
      // this count to the user and rewrites each listed meal.
      expect(ids, hasLength(2));
      expect(ids.toSet(), <String>{'m1', 'm2'});
    });
  });
}
