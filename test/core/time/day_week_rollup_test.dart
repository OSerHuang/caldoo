import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:caldoo/core/time/date_windows.dart';
import 'package:caldoo/domain/models/models.dart';

MealWithItems mealWithItems({
  required String id,
  required DateTime timestamp,
  required List<MealItem> items,
}) {
  return (
    meal: Meal(id: id, timestamp: timestamp, mealType: MealType.lunch),
    items: items,
  );
}

MealItem foodItem({
  required String id,
  int kcal = 0,
  double carbG = 0,
  double proteinG = 0,
  double fatG = 0,
  double saltG = 0,
}) {
  return MealItem(
    id: id,
    name: id,
    grams: 100,
    kcal: kcal,
    carbG: carbG,
    proteinG: proteinG,
    fatG: fatG,
    saltG: saltG,
    source: FoodSource.ai,
  );
}

DailyExercise exerciseOn({required DateTime dayKey, required int kcal}) {
  return DailyExercise(dayKey: dayKey, kcal: kcal);
}

void main() {
  const shanghai = LocalOffset(480);
  const utc = LocalOffset.utc;

  group('rollupDay', () {
    test(
      'sums only the meals and exercises inside the requested local day',
      () {
        final meals = <MealWithItems>[
          mealWithItems(
            id: 'late-night',
            timestamp: DateTime.utc(2026, 1, 5, 15, 30),
            items: <MealItem>[
              foodItem(
                id: 'noodles',
                kcal: 300,
                carbG: 40,
                proteinG: 20,
                fatG: 10,
                saltG: 1.0,
              ),
            ],
          ),
          mealWithItems(
            id: 'just-after-midnight',
            timestamp: DateTime.utc(2026, 1, 4, 16, 5),
            items: <MealItem>[
              foodItem(
                id: 'milk',
                kcal: 200,
                carbG: 20,
                proteinG: 10,
                fatG: 5,
                saltG: 0.5,
              ),
            ],
          ),
          mealWithItems(
            id: 'previous-day',
            timestamp: DateTime.utc(2026, 1, 4, 15, 59),
            items: <MealItem>[foodItem(id: 'ghost-a', kcal: 999)],
          ),
          mealWithItems(
            id: 'next-day',
            timestamp: DateTime.utc(2026, 1, 5, 16, 0),
            items: <MealItem>[foodItem(id: 'ghost-b', kcal: 888)],
          ),
        ];
        final exercises = <DailyExercise>[
          exerciseOn(dayKey: DateTime.utc(2026, 1, 5), kcal: 250),
          // A different day key: never counted for 2026-01-05.
          exerciseOn(dayKey: DateTime.utc(2026, 1, 6), kcal: 999),
        ];

        final rollup = rollupDay(
          date: DateTime.utc(2026, 1, 5),
          meals: meals,
          exercises: exercises,
          offset: shanghai,
        );

        expect(rollup.date, DateTime.utc(2026, 1, 5));
        expect(rollup.intakeKcal, 500);
        expect(rollup.carbG, 60);
        expect(rollup.proteinG, 30);
        expect(rollup.fatG, 15);
        expect(rollup.exerciseKcal, 250);
        expect(rollup.mealCount, 2);
      },
    );

    test('MealItem salt grams become canonical sodium mg at the boundary', () {
      final rollup = rollupDay(
        date: DateTime.utc(2026, 1, 5),
        meals: <MealWithItems>[
          mealWithItems(
            id: 'salty',
            timestamp: DateTime.utc(2026, 1, 5, 0, 0),
            items: <MealItem>[
              foodItem(id: 'a', saltG: 1.5),
              foodItem(id: 'b', saltG: 0.5),
            ],
          ),
        ],
        exercises: const <DailyExercise>[],
        offset: shanghai,
      );

      expect(rollup.sodiumMg, closeTo(800, 1e-9));
      expect(rollup.saltG, closeTo(2.0, 1e-9));
    });

    test('an empty day rolls up to an all-zero record', () {
      final rollup = rollupDay(
        date: DateTime.utc(2026, 1, 5),
        meals: const <MealWithItems>[],
        exercises: const <DailyExercise>[],
        offset: shanghai,
      );

      expect(rollup, DayRollup(date: DateTime.utc(2026, 1, 5)));
      expect(rollup.intakeKcal, 0);
      expect(rollup.carbG, 0);
      expect(rollup.proteinG, 0);
      expect(rollup.fatG, 0);
      expect(rollup.sodiumMg, 0);
      expect(rollup.exerciseKcal, 0);
      expect(rollup.mealCount, 0);
      expect(rollup.saltG, 0);
    });

    test('a day with only out-of-day entries still rolls up to zero', () {
      final rollup = rollupDay(
        date: DateTime.utc(2026, 1, 5),
        meals: <MealWithItems>[
          mealWithItems(
            id: 'sunday',
            timestamp: DateTime.utc(2026, 1, 4, 15, 59),
            items: <MealItem>[foodItem(id: 'a', kcal: 700)],
          ),
        ],
        exercises: <DailyExercise>[
          exerciseOn(dayKey: DateTime.utc(2026, 1, 4), kcal: 300),
        ],
        offset: shanghai,
      );

      expect(rollup, DayRollup(date: DateTime.utc(2026, 1, 5)));
    });

    test('the date argument is read as a calendar date, not an instant', () {
      final utcKey = rollupDay(
        date: DateTime.utc(2026, 1, 5),
        meals: const <MealWithItems>[],
        exercises: const <DailyExercise>[],
        offset: shanghai,
      );
      final localKey = rollupDay(
        date: DateTime(2026, 1, 5),
        meals: const <MealWithItems>[],
        exercises: const <DailyExercise>[],
        offset: shanghai,
      );

      expect(utcKey.date, DateTime.utc(2026, 1, 5));
      expect(localKey.date, DateTime.utc(2026, 1, 5));
      expect(localKey, utcKey);
    });
  });

  group('rollupWeek', () {
    test('a fixed Wednesday clock rolls the Monday..Sunday week', () {
      final mondayToSunday = List<DateTime>.generate(
        7,
        (i) => DateTime.utc(2026, 1, 5 + i, 0, 0),
      );
      final meals = <MealWithItems>[
        for (var i = 0; i < 7; i++)
          mealWithItems(
            id: 'meal-$i',
            timestamp: mondayToSunday[i].add(const Duration(hours: 8)),
            items: <MealItem>[
              foodItem(
                id: 'food-$i',
                kcal: 100 * (i + 1),
                saltG: 0.1 * (i + 1),
              ),
            ],
          ),
        mealWithItems(
          id: 'out-of-week',
          timestamp: DateTime.utc(2026, 1, 4, 15, 59),
          items: <MealItem>[foodItem(id: 'ghost', kcal: 1000)],
        ),
      ];
      final exercises = <DailyExercise>[
        exerciseOn(dayKey: DateTime.utc(2026, 1, 5), kcal: 150),
        exerciseOn(dayKey: DateTime.utc(2026, 1, 11), kcal: 50),
        // Out of the week: never counted.
        exerciseOn(dayKey: DateTime.utc(2026, 1, 4), kcal: 1000),
      ];
      final clock = Clock.fixed(DateTime.utc(2026, 1, 7, 4, 0));

      final week = rollupWeek(
        clock: clock,
        offset: shanghai,
        meals: meals,
        exercises: exercises,
      );

      expect(week, hasLength(7));
      expect(week.map((d) => d.date), orderedEquals(mondayToSunday));
      expect(
        week.map((d) => d.mealCount),
        orderedEquals(List<int>.filled(7, 1)),
      );
      expect(
        week.map((d) => d.intakeKcal),
        orderedEquals(<int>[100, 200, 300, 400, 500, 600, 700]),
      );
      expect(
        week.map((d) => d.exerciseKcal),
        orderedEquals(<int>[150, 0, 0, 0, 0, 0, 50]),
      );
      expect(week.fold<int>(0, (sum, d) => sum + d.intakeKcal), 2800);
      expect(week.fold<int>(0, (sum, d) => sum + d.exerciseKcal), 200);
      expect(
        week.fold<double>(0, (sum, d) => sum + d.sodiumMg),
        closeTo(0.1 * (1 + 2 + 3 + 4 + 5 + 6 + 7) * 400, 1e-9),
      );
    });

    test('Sunday 23:59 and Monday 00:01 meals split into two weeks', () {
      final lateSunday = DateTime.utc(2026, 1, 4, 15, 59);
      final earlyMonday = DateTime.utc(2026, 1, 4, 16, 1);
      final meals = <MealWithItems>[
        mealWithItems(
          id: 'sunday-dinner',
          timestamp: lateSunday,
          items: <MealItem>[foodItem(id: 'a', kcal: 700)],
        ),
        mealWithItems(
          id: 'monday-snack',
          timestamp: earlyMonday,
          items: <MealItem>[foodItem(id: 'b', kcal: 300)],
        ),
      ];

      final sundayWeek = rollupWeek(
        clock: Clock.fixed(lateSunday),
        offset: shanghai,
        meals: meals,
        exercises: const <DailyExercise>[],
      );
      final mondayWeek = rollupWeek(
        clock: Clock.fixed(earlyMonday),
        offset: shanghai,
        meals: meals,
        exercises: const <DailyExercise>[],
      );

      expect(sundayWeek.first.date, DateTime.utc(2025, 12, 29));
      expect(sundayWeek.last.date, DateTime.utc(2026, 1, 4));
      expect(sundayWeek.last.mealCount, 1);
      expect(sundayWeek.last.intakeKcal, 700);
      expect(sundayWeek.fold<int>(0, (sum, d) => sum + d.mealCount), 1);

      expect(mondayWeek.first.date, DateTime.utc(2026, 1, 5));
      expect(mondayWeek.last.date, DateTime.utc(2026, 1, 11));
      expect(mondayWeek.first.mealCount, 1);
      expect(mondayWeek.first.intakeKcal, 300);
      expect(mondayWeek.fold<int>(0, (sum, d) => sum + d.mealCount), 1);

      expect(sundayWeek.last.date, isNot(mondayWeek.first.date));
    });

    test(
      'the same instant lands in different weeks under different offsets',
      () {
        final instant = DateTime.utc(2026, 1, 4, 16, 30);
        final meals = <MealWithItems>[
          mealWithItems(
            id: 'one-meal',
            timestamp: instant,
            items: <MealItem>[foodItem(id: 'a', kcal: 420)],
          ),
        ];
        final clock = Clock.fixed(instant);

        final shanghaiWeek = rollupWeek(
          clock: clock,
          offset: shanghai,
          meals: meals,
          exercises: const <DailyExercise>[],
        );
        final utcWeek = rollupWeek(
          clock: clock,
          offset: utc,
          meals: meals,
          exercises: const <DailyExercise>[],
        );

        expect(shanghaiWeek.first.date, DateTime.utc(2026, 1, 5));
        expect(shanghaiWeek.first.intakeKcal, 420);
        expect(shanghaiWeek.fold<int>(0, (s, d) => s + d.intakeKcal), 420);

        expect(utcWeek.last.date, DateTime.utc(2026, 1, 4));
        expect(utcWeek.last.intakeKcal, 420);
        expect(utcWeek.fold<int>(0, (s, d) => s + d.intakeKcal), 420);
      },
    );
  });
}
