// Task 33 DB benchmark: seed a realistic 90-day dataset and confirm the queries
// that back the daily/weekly rollups return well under the stated threshold.
//
// Threshold (default, per the task): 200 ms on the reference machine. The
// measured value is printed as `BENCHMARK_90D_QUERY_MS=<value>` so it can be
// recorded verbatim in the task evidence.
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:caldoo/data/db/app_database.dart';
import 'package:caldoo/domain/models/food.dart';
import 'package:caldoo/domain/models/meal.dart';

import '_test_db.dart';

/// Hard pass/fail bound for the benchmark (milliseconds).
const double benchmarkThresholdMs = 200;

/// Size of the seeded window.
const int benchmarkDays = 90;
const int mealsPerDay = 4;
const int itemsPerMeal = 3;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;

  setUp(() {
    db = testDb();
  });

  tearDown(() async {
    await db.close();
  });

  test('90-day rollup queries return under ${benchmarkThresholdMs.toInt()} ms', () async {
    final base = DateTime.utc(2026, 6, 1); // arbitrary anchor (Monday).
    final meals = <MealsCompanion>[];
    final items = <MealItemsCompanion>[];

    for (var day = 0; day < benchmarkDays; day++) {
      final dayStart = base.add(Duration(days: day));
      for (var m = 0; m < mealsPerDay; m++) {
        final mealId = 'meal-$day-$m';
        meals.add(
          MealsCompanion.insert(
            id: mealId,
            timestamp: dayStart.add(Duration(hours: 7 + m * 4)),
            mealType: MealType.values[m % MealType.values.length],
            note: Value<String?>('day $day meal $m'),
          ),
        );
        for (var i = 0; i < itemsPerMeal; i++) {
          items.add(
            MealItemsCompanion.insert(
              id: 'item-$day-$m-$i',
              mealId: mealId,
              name: '食物$i',
              grams: 100 + i * 25,
              kcal: 150 + i * 40,
              carbG: 20 + i * 5,
              proteinG: 5 + i * 2,
              fatG: 3 + i * 1.5,
              saltG: 0.2 + i * 0.1,
              source: FoodSource.ai,
              confidence: const Value<double?>(0.8),
            ),
          );
        }
      }
    }

    // Insert parents before children in one batch (order is preserved, which
    // matters because foreign keys are ON).
    await db.batch((batch) {
      batch.insertAll(db.meals, meals);
      batch.insertAll(db.mealItems, items);
    });

    // Guard against a false pass: the dataset must actually exist.
    expect(
      (await db.select(db.meals).get()).length,
      benchmarkDays * mealsPerDay,
    );
    expect(
      (await db.select(db.mealItems).get()).length,
      benchmarkDays * mealsPerDay * itemsPerMeal,
    );

    final rangeStart = base;
    final rangeEnd = base.add(const Duration(days: benchmarkDays));

    // Warm-up (first run pays one-off preparation costs).
    await db.mealDao.getMealsWithItemsInRange(
      startInclusive: rangeStart,
      endExclusive: rangeEnd,
    );

    // Measured query: meals LEFT JOIN items over the full 90-day window, which
    // is exactly what the weekly rollup aggregates.
    final stopwatch = Stopwatch()..start();
    final rows = await db.mealDao.getMealsWithItemsInRange(
      startInclusive: rangeStart,
      endExclusive: rangeEnd,
    );
    stopwatch.stop();

    expect(rows, hasLength(benchmarkDays * mealsPerDay));

    // Single-day watcher (the per-meal / daily-summary path).
    final singleDayWatch = Stopwatch()..start();
    final dayMeals = await db.mealDao
        .watchMealsForDay(
          dayStartInclusive: base.add(const Duration(days: 45)),
          dayEndExclusive: base.add(const Duration(days: 46)),
        )
        .first;
    singleDayWatch.stop();
    expect(dayMeals, hasLength(mealsPerDay));

    final measuredMs = stopwatch.elapsedMicroseconds / 1000;
    final dayMs = singleDayWatch.elapsedMicroseconds / 1000;

    // ignore: avoid_print
    print(
      'BENCHMARK_90D: rows=${rows.length} items=${items.length} '
      'rangeQueryMs=${measuredMs.toStringAsFixed(3)} '
      'singleDayWatchMs=${dayMs.toStringAsFixed(3)} '
      'thresholdMs=${benchmarkThresholdMs.toInt()}',
    );
    // ignore: avoid_print
    print('BENCHMARK_90D_QUERY_MS=${measuredMs.toStringAsFixed(3)}');

    expect(
      measuredMs,
      lessThan(benchmarkThresholdMs),
      reason:
          '90-day range query took ${measuredMs.toStringAsFixed(3)} ms '
          '(threshold ${benchmarkThresholdMs.toInt()} ms)',
    );
  });
}
