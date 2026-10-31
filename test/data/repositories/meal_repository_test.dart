// The SAME contract suite runs twice: once against the Drift implementation
// (in-memory database) and once against the in-memory fake. A behavior only
// belongs to the repository contract when both implementations satisfy it.
import 'package:flutter_test/flutter_test.dart';
import 'package:caldoo/data/db/app_database.dart';
import 'package:caldoo/data/repositories/drift_food_repository.dart';
import 'package:caldoo/data/repositories/drift_meal_repository.dart';
import 'package:caldoo/domain/models/models.dart';

import '../db/_test_db.dart';
import 'fake_repositories.dart';
import 'repository_suites.dart';

void main() {
  group('MealRepository: Drift implementation (in-memory DB)', () {
    late AppDatabase db;
    late DriftMealRepository meals;
    late DriftFoodRepository foods;
    setUp(() {
      db = testDb();
      meals = DriftMealRepository(db);
      foods = DriftFoodRepository(db);
    });
    tearDown(() => db.close());

    runMealRepositorySuite(createMeals: () => meals, createFoods: () => foods);

    test(
      '[drift-only] deleteMeal physically removes the item rows (FK cascade)',
      () async {
        await meals.saveMealWithItems(mealFixture(), <MealItem>[
          itemFixture(id: 'i1'),
          itemFixture(id: 'i2', name: '鸡蛋'),
        ]);

        await meals.deleteMeal('m1');

        // Raw table reads: the cascade is proven at the storage layer, not just
        // inferred from the repository's own queries.
        expect(await db.select(db.meals).get(), isEmpty);
        expect(await db.select(db.mealItems).get(), isEmpty);
      },
    );
  });

  group('MealRepository: Fake implementation (in-memory maps)', () {
    late FakeMealRepository meals;
    late FakeFoodRepository foods;
    setUp(() {
      meals = FakeMealRepository();
      foods = FakeFoodRepository();
    });
    tearDown(() async {
      await meals.dispose();
      await foods.dispose();
    });

    runMealRepositorySuite(createMeals: () => meals, createFoods: () => foods);
  });
}
