/// The shared repository contract suites (one per port).
///
/// Each `run*Suite` function registers one group's worth of tests for a single
/// repository port and takes a `create` factory, so the **same** suite runs
/// against the Drift implementation (in-memory database) and against the
/// in-memory fake. A behavior is part of the contract only if both pass it.
///
/// The tests assert domain values (full model equality plus per-field checks),
/// never `*Row` types, and cover: domain round-trips, blank/`null` handling,
/// half-open day/week windows, ordering, cascade-safe deletes and `watch`
/// re-emission.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:caldoo/core/time/date_windows.dart' show MealWithItems;
import 'package:caldoo/domain/models/models.dart';
import 'package:caldoo/domain/repositories/repositories.dart';

// ---------------------------------------------------------------------------
// Fixtures
//
// Timestamps are whole-second and locally flagged on purpose: the Drift schema
// stores `dateTime()` as unix *seconds* and reads back a local-flagged
// `DateTime`, and both implementations apply the same rule, so full model
// equality holds across the round-trip on any machine timezone.
// ---------------------------------------------------------------------------

/// Monday 2026-09-21 00:00 local — the start of the test week and the timezone
/// offset cancels out because the same local instant is used everywhere.
final DateTime monday = DateTime(2026, 9, 21);

/// Tuesday 2026-09-22 00:00 local — the exclusive end of the test day.
final DateTime tuesday = DateTime(2026, 9, 22);

/// Monday 2026-09-28 00:00 local — the exclusive end of the test week.
final DateTime nextMonday = DateTime(2026, 9, 28);

/// A fully-populated profile; every field differs from the model defaults.
///
/// The default [birthDate] is 32 on 2026-04-12 (its birthday), so the age
/// assertions exercise the derived-age boundary rather than a stored number.
UserProfile profileFixture({
  Sex sex = Sex.male,
  DateTime? birthDate,
  double heightCm = 178.5,
  double weightKg = 72.4,
  int? bmrKcalOverride = 2051,
}) => UserProfile(
  sex: sex,
  birthDate: birthDate ?? DateTime.utc(1994, 4, 12),
  heightCm: heightCm,
  weightKg: weightKg,
  bmrKcalOverride: bmrKcalOverride,
);

/// A saved food; nutrients default to label-style values, all overridable.
Food foodFixture({
  String id = 'f-milk',
  String name = '全脂牛奶',
  String? brand,
  String? barcode,
  FoodSource source = FoodSource.label,
  int? kcal = 65,
  double? carbG = 4.8,
  double? proteinG = 3.3,
  double? fatG = 3.6,
  double? sugarG,
  double? saturatedFatG,
  double? sodiumMg = 50,
  String? notes,
  List<String> aliases = const <String>[],
  List<FoodServing> servings = const <FoodServing>[],
  FoodStatus status = FoodStatus.active,
  MeasureBasis basis = MeasureBasis.per100g,
}) => Food(
  id: id,
  name: name,
  brand: brand,
  barcode: barcode,
  aliases: aliases,
  servings: servings,
  status: status,
  basis: basis,
  notes: notes,
  source: source,
  kcal: kcal,
  carbG: carbG,
  proteinG: proteinG,
  fatG: fatG,
  sugarG: sugarG,
  saturatedFatG: saturatedFatG,
  sodiumMg: sodiumMg,
);

/// A logged meal; the default timestamp keeps full model equality round-trips
/// exact (whole second).
Meal mealFixture({
  String id = 'm1',
  DateTime? timestamp,
  MealType mealType = MealType.lunch,
  String? note,
}) => Meal(
  id: id,
  timestamp: timestamp ?? DateTime(2026, 9, 21, 12),
  mealType: mealType,
  note: note,
);

/// One meal line; [grams]/[kcal]/macros default to a plausible 150 g 米饭.
MealItem itemFixture({
  String id = 'i1',
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
}) => MealItem(
  id: id,
  foodId: foodId,
  name: name,
  grams: grams,
  kcal: kcal,
  carbG: carbG,
  proteinG: proteinG,
  fatG: fatG,
  saltG: saltG,
  source: source,
  confidence: confidence,
);

/// A one-per-day exercise-burn value; [dayKey] is a date-only UTC key.
DailyExercise dailyExerciseFixture({DateTime? dayKey, int kcal = 321}) =>
    DailyExercise(dayKey: dayKey ?? DateTime.utc(2026, 9, 21), kcal: kcal);

// ---------------------------------------------------------------------------
// ProfileRepository
// ---------------------------------------------------------------------------

/// Registers the [ProfileRepository] contract tests.
void runProfileRepositorySuite(ProfileRepository Function() create) {
  late ProfileRepository profiles;
  setUp(() => profiles = create());

  test('loadProfile is null before anything is saved', () async {
    expect(await profiles.loadProfile(), isNull);
  });

  test('saveProfile then loadProfile round-trips every field', () async {
    final profile = profileFixture();

    await profiles.saveProfile(profile);
    final loaded = await profiles.loadProfile();

    expect(loaded, isNotNull);
    expect(loaded!.sex, Sex.male);
    expect(loaded.birthDate, DateTime.utc(1994, 4, 12));
    expect(loaded.heightCm, 178.5);
    expect(loaded.weightKg, 72.4);
    expect(loaded.bmrKcalOverride, 2051);
    expect(loaded, equals(profile));
    // Age is derived from the birthday on the caller's day, never stored.
    expect(loaded.ageOn(DateTime.utc(2026, 4, 12)), 32);
    expect(loaded.ageOn(DateTime.utc(2026, 4, 11)), 31);
  });

  test('a null bmrKcalOverride round-trips as "auto", never as 0', () async {
    final auto = profileFixture(bmrKcalOverride: null);

    await profiles.saveProfile(auto);
    final loaded = await profiles.loadProfile();

    expect(loaded, isNotNull);
    expect(loaded!.bmrKcalOverride, isNull);
    expect(loaded, equals(auto));
  });

  test('saving again updates the single stored profile in place', () async {
    await profiles.saveProfile(profileFixture());

    final updated = profileFixture(
      sex: Sex.female,
      birthDate: DateTime.utc(1985, 1, 15),
      heightCm: 165.2,
      weightKg: 58.7,
      bmrKcalOverride: 1980,
    );
    await profiles.saveProfile(updated);

    final loaded = await profiles.loadProfile();
    expect(loaded!.sex, Sex.female);
    expect(loaded.birthDate, DateTime.utc(1985, 1, 15));
    expect(loaded.heightCm, 165.2);
    expect(loaded.weightKg, 58.7);
    expect(loaded.bmrKcalOverride, 1980);
    expect(loaded, equals(updated));
    // The newly stored birthday (not the earlier one) drives the derived age.
    expect(loaded.ageOn(DateTime.utc(2026, 1, 15)), 41);
    expect(loaded.ageOn(DateTime.utc(2026, 1, 14)), 40);
  });

  test('clearProfile removes the stored profile', () async {
    await profiles.saveProfile(profileFixture());

    await profiles.clearProfile();

    expect(await profiles.loadProfile(), isNull);
  });

  test('watchProfile emits null, then the save, then the update', () async {
    final emissions = <UserProfile?>[];
    final subscription = profiles.watchProfile().listen(emissions.add);
    await pumpEventQueue();
    expect(emissions, <UserProfile?>[null]);

    final first = profileFixture();
    await profiles.saveProfile(first);
    await pumpEventQueue();
    expect(emissions.last, equals(first));
    expect(emissions.last!.weightKg, 72.4);

    final second = profileFixture(weightKg: 71.1);
    await profiles.saveProfile(second);
    await pumpEventQueue();
    expect(emissions.last, equals(second));
    expect(emissions.last!.weightKg, 71.1);

    await subscription.cancel();
  });
}

// ---------------------------------------------------------------------------
// FoodRepository
// ---------------------------------------------------------------------------

/// Registers the [FoodRepository] contract tests.
void runFoodRepositorySuite(FoodRepository Function() create) {
  late FoodRepository foods;
  setUp(() => foods = create());

  test('insertFood then getFood round-trips every domain field', () async {
    final food = foodFixture(
      brand: '光明',
      barcode: '6901234567890',
      notes: '一包 250 ml；别名：牛奶',
    );

    await foods.insertFood(food);
    final loaded = await foods.getFood('f-milk');

    expect(loaded, isNotNull);
    expect(loaded!.id, 'f-milk');
    expect(loaded.name, '全脂牛奶');
    expect(loaded.brand, '光明');
    expect(loaded.barcode, '6901234567890');
    expect(loaded.notes, '一包 250 ml；别名：牛奶');
    expect(loaded.source, FoodSource.label);
    expect(loaded.kcal, 65);
    expect(loaded.carbG, 4.8);
    expect(loaded.proteinG, 3.3);
    expect(loaded.fatG, 3.6);
    expect(loaded.sodiumMg, 50);
    expect(loaded.saltG, 0.125);
    expect(loaded, equals(food));
  });

  test('round-trips the structured selection surface', () async {
    final structured = foodFixture(
      id: 'f-noodle',
      name: '辛拉面(农心)',
      notes: '标签 2026-09-17',
      aliases: const <String>['辛拉面', '泡面'],
      servings: const <FoodServing>[
        FoodServing(label: '一袋', amount: 120, unit: 'g'),
      ],
      status: FoodStatus.archived,
      basis: MeasureBasis.per100ml,
      sugarG: 12.5,
      saturatedFatG: 1.2,
    );

    await foods.insertFood(structured);
    final loaded = await foods.getFood('f-noodle');

    expect(loaded, isNotNull);
    expect(loaded!.aliases, <String>['辛拉面', '泡面']);
    expect(loaded.servings, structured.servings);
    expect(loaded.status, FoodStatus.archived);
    expect(loaded.basis, MeasureBasis.per100ml);
    expect(loaded.sugarG, 12.5);
    expect(loaded.saturatedFatG, 1.2);
    expect(loaded.isMatchable, isFalse);
    expect(loaded, equals(structured));
  });

  test('blank optional fields stay null, never 0 or empty string', () async {
    final sparse = foodFixture(
      id: 'f-sparse',
      name: '自制汤',
      source: FoodSource.manual,
      kcal: null,
      carbG: null,
      proteinG: null,
      fatG: null,
      sodiumMg: null,
    );

    await foods.insertFood(sparse);
    final loaded = await foods.getFood('f-sparse');

    expect(loaded!.brand, isNull);
    expect(loaded.barcode, isNull);
    expect(loaded.notes, isNull);
    expect(loaded.kcal, isNull);
    expect(loaded.carbG, isNull);
    expect(loaded.proteinG, isNull);
    expect(loaded.fatG, isNull);
    expect(loaded.sodiumMg, isNull);
    expect(loaded.saltG, isNull);
    expect(loaded.sugarG, isNull);
    expect(loaded.saturatedFatG, isNull);
    // The structured surface is empty/default for a food that never set it.
    expect(loaded.aliases, isEmpty);
    expect(loaded.servings, isEmpty);
    expect(loaded.status, FoodStatus.active);
    expect(loaded.basis, MeasureBasis.per100g);
    expect(loaded, equals(sparse));
  });

  test('getFood returns null for an unknown id', () async {
    expect(await foods.getFood('missing'), isNull);
  });

  test('getAllFoods returns the catalogue ordered by name', () async {
    await foods.insertFood(foodFixture(id: 'f3', name: '米饭'));
    await foods.insertFood(foodFixture(id: 'f1', name: 'apple'));
    await foods.insertFood(foodFixture(id: 'f2', name: 'banana'));

    final all = await foods.getAllFoods();

    expect(all.map((food) => food.id).toList(), <String>['f1', 'f2', 'f3']);
    expect(all.map((food) => food.name).toList(), <String>[
      'apple',
      'banana',
      '米饭',
    ]);
  });

  test('searchByNormalizedName matches the normalized key exactly', () async {
    await foods.insertFood(foodFixture(id: 'f-milk-1', name: '全脂 牛奶！'));
    await foods.insertFood(foodFixture(id: 'f-milk-2', name: '全脂牛奶'));
    await foods.insertFood(foodFixture(id: 'f-apple', name: 'Apple'));
    await foods.insertFood(foodFixture(id: 'f-soy', name: '豆浆'));

    final milk = await foods.searchByNormalizedName('  全脂牛奶 ');
    expect(milk.map((food) => food.id).toList(), <String>[
      'f-milk-1',
      'f-milk-2',
    ]);

    final apple = await foods.searchByNormalizedName(' APPLE  ');
    expect(apple.map((food) => food.id).toList(), <String>['f-apple']);

    // Exact normalized key only: no containment, no fuzzy matching.
    expect(await foods.searchByNormalizedName('牛奶'), isEmpty);
    expect(await foods.searchByNormalizedName('豆浆粉'), isEmpty);
    expect(await foods.searchByNormalizedName('   '), isEmpty);
  });

  test('upsertFood replaces the stored row in place, nulls included', () async {
    await foods.insertFood(foodFixture(brand: '光明', kcal: 65));

    final replacement = foodFixture(
      brand: null,
      barcode: '6900000000001',
      source: FoodSource.ai,
      kcal: null,
      sodiumMg: 12,
    );
    await foods.upsertFood(replacement);

    final loaded = await foods.getFood('f-milk');
    expect(loaded!.brand, isNull);
    expect(loaded.barcode, '6900000000001');
    expect(loaded.source, FoodSource.ai);
    expect(loaded.kcal, isNull);
    expect(loaded.sodiumMg, 12);
    expect(loaded, equals(replacement));
  });

  test('watchAllFoods emits the catalogue on insert and delete', () async {
    final emissions = <List<Food>>[];
    final subscription = foods.watchAllFoods().listen(emissions.add);
    await pumpEventQueue();
    expect(emissions, <Object>[isEmpty]);

    await foods.insertFood(foodFixture(id: 'f1', name: 'apple'));
    await pumpEventQueue();
    expect(emissions.last.map((food) => food.id).toList(), <String>['f1']);

    await foods.deleteFood('f1');
    await pumpEventQueue();
    expect(emissions.last, isEmpty);

    await subscription.cancel();
  });

  test('watchFood emits null, then the food, then the replacement', () async {
    final emissions = <Food?>[];
    final subscription = foods.watchFood('f1').listen(emissions.add);
    await pumpEventQueue();
    expect(emissions, <Food?>[null]);

    final food = foodFixture(id: 'f1', name: 'apple', kcal: 52);
    await foods.insertFood(food);
    await pumpEventQueue();
    expect(emissions.last, equals(food));
    expect(emissions.last!.kcal, 52);

    final replacement = foodFixture(id: 'f1', name: 'apple', kcal: 55);
    await foods.upsertFood(replacement);
    await pumpEventQueue();
    expect(emissions.last, equals(replacement));
    expect(emissions.last!.kcal, 55);

    await subscription.cancel();
  });

  test('deleteFood removes only the requested food', () async {
    await foods.insertFood(foodFixture(id: 'f1', name: 'apple'));
    await foods.insertFood(foodFixture(id: 'f2', name: 'banana'));

    await foods.deleteFood('f1');

    expect(await foods.getFood('f1'), isNull);
    expect(await foods.getFood('f2'), isNotNull);
    expect(
      (await foods.getAllFoods()).map((food) => food.id).toList(),
      <String>['f2'],
    );
  });
}

// ---------------------------------------------------------------------------
// MealRepository
// ---------------------------------------------------------------------------

/// Registers the [MealRepository] contract tests.
///
/// [createFoods] is needed for the cross-port test proving that deleting a
/// saved food leaves already-logged meal items intact.
void runMealRepositorySuite({
  required MealRepository Function() createMeals,
  required FoodRepository Function() createFoods,
}) {
  late MealRepository meals;
  late FoodRepository foods;
  setUp(() {
    meals = createMeals();
    foods = createFoods();
  });

  test(
    'saveMealWithItems then getMealsInRange round-trips every meal field',
    () async {
      final meal = mealFixture(note: '工作日午餐');

      await meals.saveMealWithItems(meal, <MealItem>[itemFixture(id: 'i1')]);
      final loaded = await meals.getMealsInRange(
        startInclusive: monday,
        endExclusive: tuesday,
      );

      expect(loaded, hasLength(1));
      expect(loaded.single.id, 'm1');
      expect(loaded.single.mealType, MealType.lunch);
      expect(loaded.single.note, '工作日午餐');
      expect(loaded.single.timestamp.isAtSameMomentAs(meal.timestamp), isTrue);
      expect(loaded.single, equals(meal));
    },
  );

  test(
    'getMealsWithItemsInRange pairs every meal with its items in schema order',
    () async {
      final firstItem = itemFixture(id: 'i-l1');
      final secondItem = itemFixture(
        id: 'i-l2',
        name: '西红柿炒蛋',
        grams: 200,
        kcal: 120,
        carbG: 6,
        proteinG: 9,
        fatG: 7,
        saltG: 0.9,
        confidence: 0.7,
      );
      await meals.saveMealWithItems(
        mealFixture(id: 'm-lunch', timestamp: DateTime(2026, 9, 21, 12)),
        // Deliberately out of id order: the contract orders items by id.
        <MealItem>[secondItem, firstItem],
      );
      await meals.saveMealWithItems(
        mealFixture(
          id: 'm-breakfast',
          timestamp: DateTime(2026, 9, 21, 8),
          mealType: MealType.breakfast,
        ),
        <MealItem>[itemFixture(id: 'i-b1', name: '豆浆', grams: 250, kcal: 80)],
      );

      final groups = await meals.getMealsWithItemsInRange(
        startInclusive: monday,
        endExclusive: tuesday,
      );

      expect(groups.map((group) => group.meal.id).toList(), <String>[
        'm-breakfast',
        'm-lunch',
      ]);
      expect(groups.first.items.map((item) => item.id).toList(), <String>[
        'i-b1',
      ]);
      expect(groups.last.items, equals(<MealItem>[firstItem, secondItem]));
      expect(groups.last.items.first.grams, 150);
      expect(groups.last.items.last.confidence, 0.7);
    },
  );

  test('getMealsInRange honours the half-open window', () async {
    await meals.saveMealWithItems(
      mealFixture(id: 'm-before', timestamp: DateTime(2026, 9, 20, 23, 59)),
      <MealItem>[itemFixture(id: 'i-before')],
    );
    await meals.saveMealWithItems(
      mealFixture(id: 'm-start', timestamp: DateTime(2026, 9, 21)),
      <MealItem>[itemFixture(id: 'i-start')],
    );
    await meals.saveMealWithItems(
      mealFixture(id: 'm-mid', timestamp: DateTime(2026, 9, 21, 18, 30)),
      <MealItem>[itemFixture(id: 'i-mid')],
    );
    await meals.saveMealWithItems(
      mealFixture(id: 'm-end', timestamp: DateTime(2026, 9, 22)),
      <MealItem>[itemFixture(id: 'i-end')],
    );

    final loaded = await meals.getMealsInRange(
      startInclusive: monday,
      endExclusive: tuesday,
    );

    expect(loaded.map((meal) => meal.id).toList(), <String>[
      'm-start',
      'm-mid',
    ]);
  });

  test(
    'blank note, food link and confidence stay null through the round-trip',
    () async {
      final meal = mealFixture();
      final item = itemFixture(id: 'i1');
      await meals.saveMealWithItems(meal, <MealItem>[item]);

      final loaded = (await meals.getMealsWithItemsInRange(
        startInclusive: monday,
        endExclusive: tuesday,
      )).single;

      expect(loaded.meal.note, isNull);
      expect(loaded.items.single.foodId, isNull);
      expect(loaded.items.single.confidence, isNull);
      expect(loaded.meal, equals(meal));
      expect(loaded.items.single, equals(item));

      // A present confidence value round-trips exactly (not just "non-null").
      await meals.saveMealWithItems(
        mealFixture(id: 'm2', timestamp: DateTime(2026, 9, 21, 13)),
        <MealItem>[itemFixture(id: 'i2', confidence: 0.83)],
      );
      final second = (await meals.getMealsWithItemsInRange(
        startInclusive: monday,
        endExclusive: tuesday,
      )).firstWhere((group) => group.meal.id == 'm2');
      expect(second.items.single.confidence, 0.83);
    },
  );

  test('deleteMeal deletes the meal and cascades to its items', () async {
    await meals.saveMealWithItems(mealFixture(id: 'm-a'), <MealItem>[
      itemFixture(id: 'i-shared'),
    ]);
    await meals.saveMealWithItems(
      mealFixture(id: 'm-b', timestamp: DateTime(2026, 9, 21, 13)),
      <MealItem>[itemFixture(id: 'i-keep')],
    );

    await meals.deleteMeal('m-a');

    final groups = await meals.getMealsWithItemsInRange(
      startInclusive: monday,
      endExclusive: tuesday,
    );
    expect(groups.map((group) => group.meal.id).toList(), <String>['m-b']);
    expect(groups.single.items.single.id, 'i-keep');

    // The deleted meal's item row is gone, not orphaned: reusing its id under
    // a new meal hits the global `meal_items.id` primary key if it survived.
    await meals.saveMealWithItems(
      mealFixture(id: 'm-c', timestamp: DateTime(2026, 9, 21, 14)),
      <MealItem>[itemFixture(id: 'i-shared')],
    );
    final after = await meals.getMealsWithItemsInRange(
      startInclusive: monday,
      endExclusive: tuesday,
    );
    expect(after.map((group) => group.meal.id).toList(), <String>[
      'm-b',
      'm-c',
    ]);
  });

  test(
    'deleting a saved food leaves already-logged meal items intact',
    () async {
      await foods.insertFood(foodFixture(id: 'f-milk', name: '全脂牛奶'));
      final item = itemFixture(
        id: 'i1',
        foodId: 'f-milk',
        source: FoodSource.label,
      );
      await meals.saveMealWithItems(mealFixture(), <MealItem>[item]);

      await foods.deleteFood('f-milk');

      final loaded = (await meals.getMealsWithItemsInRange(
        startInclusive: monday,
        endExclusive: tuesday,
      )).single;
      expect(loaded.items.single, equals(item));
      expect(loaded.items.single.foodId, 'f-milk');
      expect(await foods.getFood('f-milk'), isNull);
    },
  );

  test(
    'watchMealsForDay emits the day window with its items after a save',
    () async {
      final emissions = <List<MealWithItems>>[];
      final subscription = meals
          .watchMealsForDay(dayStartInclusive: monday, dayEndExclusive: tuesday)
          .listen(emissions.add);
      await pumpEventQueue();
      expect(emissions, <Object>[isEmpty]);

      final firstItem = itemFixture(id: 'i1');
      final secondItem = itemFixture(
        id: 'i2',
        name: '西红柿炒蛋',
        grams: 200,
        kcal: 120,
        carbG: 6,
        proteinG: 9,
        fatG: 7,
        saltG: 0.9,
        confidence: 0.7,
      );
      // Saved out of id order; the contract still reports them ordered by id.
      await meals.saveMealWithItems(mealFixture(note: '工作日午餐'), <MealItem>[
        secondItem,
        firstItem,
      ]);
      await pumpEventQueue();

      expect(emissions.last, hasLength(1));
      expect(emissions.last.single.meal.id, 'm1');
      expect(emissions.last.single.meal.mealType, MealType.lunch);
      expect(emissions.last.single.meal.note, '工作日午餐');
      expect(
        emissions.last.single.items,
        equals(<MealItem>[firstItem, secondItem]),
      );
      expect(emissions.last.single.items.first.kcal, 174);
      expect(emissions.last.single.items.last.name, '西红柿炒蛋');
      expect(emissions.last.single.items.last.confidence, 0.7);

      await subscription.cancel();
    },
  );

  test('watchMealsForDay only reports meals inside the supplied day', () async {
    await meals.saveMealWithItems(
      mealFixture(id: 'm-today', timestamp: DateTime(2026, 9, 21, 12)),
      <MealItem>[itemFixture(id: 'i-today')],
    );
    await meals.saveMealWithItems(
      mealFixture(id: 'm-tomorrow', timestamp: DateTime(2026, 9, 22)),
      <MealItem>[itemFixture(id: 'i-tomorrow')],
    );

    final today = await meals
        .watchMealsForDay(dayStartInclusive: monday, dayEndExclusive: tuesday)
        .first;

    expect(today, hasLength(1));
    expect(today.single.meal.id, 'm-today');
    expect(today.single.items.single.id, 'i-today');
  });

  test('watchMealsForWeek reports the whole Monday..Sunday window', () async {
    await meals.saveMealWithItems(
      mealFixture(
        id: 'm-mon',
        timestamp: monday.add(const Duration(minutes: 5)),
      ),
      <MealItem>[itemFixture(id: 'i-mon')],
    );
    await meals.saveMealWithItems(
      mealFixture(
        id: 'm-sun',
        timestamp: nextMonday.subtract(const Duration(minutes: 1)),
      ),
      <MealItem>[itemFixture(id: 'i-sun')],
    );
    await meals.saveMealWithItems(
      mealFixture(id: 'm-next-mon', timestamp: nextMonday),
      <MealItem>[itemFixture(id: 'i-next-mon')],
    );

    final week = await meals
        .watchMealsForWeek(
          weekStartInclusive: monday,
          weekEndExclusive: nextMonday,
        )
        .first;

    expect(week.map((group) => group.meal.id).toList(), <String>[
      'm-mon',
      'm-sun',
    ]);
  });

  test(
    'watchMealsInRange reports a whole month window with its items',
    () async {
      // A local September 2026 window: 30 calendar days, so this exercises the
      // generic range the monthly dashboard cannot express as a fixed day/week.
      final monthStart = DateTime(2026, 9, 1);
      final nextMonth = DateTime(2026, 10, 1);

      await meals.saveMealWithItems(
        mealFixture(id: 'm-aug', timestamp: DateTime(2026, 8, 31, 23, 59)),
        <MealItem>[itemFixture(id: 'i-aug')],
      );
      await meals.saveMealWithItems(
        mealFixture(id: 'm-first', timestamp: monthStart),
        <MealItem>[itemFixture(id: 'i-first')],
      );
      await meals.saveMealWithItems(
        mealFixture(id: 'm-mid', timestamp: DateTime(2026, 9, 15, 12, 30)),
        <MealItem>[
          itemFixture(id: 'i-mid-1'),
          itemFixture(id: 'i-mid-2', name: '鸡蛋'),
        ],
      );
      await meals.saveMealWithItems(
        mealFixture(id: 'm-last', timestamp: DateTime(2026, 9, 30, 23, 59)),
        <MealItem>[itemFixture(id: 'i-last')],
      );
      await meals.saveMealWithItems(
        mealFixture(id: 'm-oct', timestamp: nextMonth),
        <MealItem>[itemFixture(id: 'i-oct')],
      );

      final month = await meals
          .watchMealsInRange(
            startInclusive: monthStart,
            endExclusive: nextMonth,
          )
          .first;

      // Half-open on both ends, and the whole month is one contiguous window.
      expect(month.map((group) => group.meal.id).toList(), <String>[
        'm-first',
        'm-mid',
        'm-last',
      ]);
      expect(month.map((group) => group.items.length).toList(), <int>[1, 2, 1]);
      expect(month[1].items.map((item) => item.id).toList(), <String>[
        'i-mid-1',
        'i-mid-2',
      ]);
    },
  );
}

// ---------------------------------------------------------------------------
// DailyExerciseRepository
// ---------------------------------------------------------------------------

/// Date-only UTC day keys for the exercise suite (the exercise table matches on
/// the day key directly, so these are UTC rather than the local meal instants).
final DateTime exerciseMonday = DateTime.utc(2026, 9, 21);
final DateTime exerciseTuesday = DateTime.utc(2026, 9, 22);
final DateTime exerciseNextMonday = DateTime.utc(2026, 9, 28);

/// Registers the [DailyExerciseRepository] contract tests.
void runExerciseRepositorySuite(DailyExerciseRepository Function() create) {
  late DailyExerciseRepository exercises;
  setUp(() => exercises = create());

  test('setKcal then getDay round-trips the value', () async {
    await exercises.setKcal(dayKey: exerciseMonday, kcal: 321);

    final day = await exercises.getDay(exerciseMonday);

    expect(day, isNotNull);
    expect(day!.dayKey, exerciseMonday);
    expect(day.kcal, 321);
    expect(day, equals(dailyExerciseFixture()));
  });

  test('getDay returns null for a day with no value', () async {
    expect(await exercises.getDay(exerciseMonday), isNull);
  });

  test('setKcal upserts in place: one value per day', () async {
    await exercises.setKcal(dayKey: exerciseMonday, kcal: 100);
    await exercises.setKcal(dayKey: exerciseMonday, kcal: 250);

    final day = await exercises.getDay(exerciseMonday);
    expect(day!.kcal, 250);

    final range = await exercises
        .watchRange(
          startInclusive: exerciseMonday,
          endExclusive: exerciseTuesday,
        )
        .first;
    expect(range, hasLength(1));
  });

  test('a non-positive kcal clears the day', () async {
    await exercises.setKcal(dayKey: exerciseMonday, kcal: 300);

    await exercises.setKcal(dayKey: exerciseMonday, kcal: 0);

    expect(await exercises.getDay(exerciseMonday), isNull);
  });

  test('watchRange honours the half-open day-key window', () async {
    await exercises.setKcal(
      dayKey: exerciseMonday.subtract(const Duration(days: 1)),
      kcal: 50,
    );
    await exercises.setKcal(dayKey: exerciseMonday, kcal: 100);
    await exercises.setKcal(dayKey: exerciseNextMonday, kcal: 900);

    final range = await exercises
        .watchRange(
          startInclusive: exerciseMonday,
          endExclusive: exerciseNextMonday,
        )
        .first;

    expect(range.map((entry) => entry.kcal).toList(), <int>[100]);
  });

  test('watchRange reports the window ordered by day', () async {
    await exercises.setKcal(dayKey: exerciseTuesday, kcal: 200);
    await exercises.setKcal(dayKey: exerciseMonday, kcal: 100);

    final range = await exercises
        .watchRange(
          startInclusive: exerciseMonday,
          endExclusive: exerciseNextMonday,
        )
        .first;

    expect(range.map((entry) => entry.dayKey).toList(), <DateTime>[
      exerciseMonday,
      exerciseTuesday,
    ]);
  });

  test('watchDay emits null, then the value, then the update', () async {
    final emissions = <DailyExercise?>[];
    final subscription = exercises
        .watchDay(exerciseMonday)
        .listen(emissions.add);
    await pumpEventQueue();
    expect(emissions, <DailyExercise?>[null]);

    await exercises.setKcal(dayKey: exerciseMonday, kcal: 321);
    await pumpEventQueue();
    expect(emissions.last, equals(dailyExerciseFixture()));

    await exercises.setKcal(dayKey: exerciseMonday, kcal: 500);
    await pumpEventQueue();
    expect(emissions.last!.kcal, 500);

    await subscription.cancel();
  });

  test('clearing a day re-emits null on the day stream', () async {
    await exercises.setKcal(dayKey: exerciseMonday, kcal: 300);
    final emissions = <DailyExercise?>[];
    final subscription = exercises
        .watchDay(exerciseMonday)
        .listen(emissions.add);
    await pumpEventQueue();
    expect(emissions.last, isNotNull);

    await exercises.setKcal(dayKey: exerciseMonday, kcal: 0);
    await pumpEventQueue();
    expect(emissions.last, isNull);

    await subscription.cancel();
  });
}
