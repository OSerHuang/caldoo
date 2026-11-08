// The SAME contract suite runs twice: once against the Drift implementation
// (in-memory database) and once against the in-memory fake. A behavior only
// belongs to the repository contract when both implementations satisfy it.
import 'package:flutter_test/flutter_test.dart';
import 'package:caldoo/data/db/app_database.dart';
import 'package:caldoo/data/repositories/drift_meal_template_repository.dart';
import 'package:caldoo/domain/models/food.dart' show FoodSource;
import 'package:caldoo/domain/models/meal_item.dart';

import '../db/_test_db.dart';
import 'fake_repositories.dart';
import 'repository_suites.dart';

void main() {
  group('MealTemplateRepository: Drift implementation (in-memory DB)', () {
    late AppDatabase db;
    setUp(() => db = testDb());
    tearDown(() => db.close());

    runMealTemplateRepositorySuite(() => DriftMealTemplateRepository(db));
  });

  group('MealTemplateRepository: Fake implementation (in-memory map)', () {
    late FakeMealTemplateRepository fake;
    setUp(() => fake = FakeMealTemplateRepository());
    tearDown(() => fake.dispose());

    runMealTemplateRepositorySuite(() => fake);
  });

  group('MealTemplateRepository: Drift JSON items column', () {
    // The `items_json` column is the single wire shape between the database
    // and the domain model; prove the codec round-trips a real item list
    // (including a nullable foodId and confidence) through the repository.
    late AppDatabase db;
    setUp(() => db = testDb());
    tearDown(() => db.close());

    test(
      'item lines keep source, foodId and confidence across a save',
      () async {
        final repo = DriftMealTemplateRepository(db);
        await repo.saveTemplate(
          templateFixture(
            items: const <MealItem>[
              MealItem(
                id: 'i-ai',
                name: '米饭',
                grams: 150,
                kcal: 174,
                carbG: 38.9,
                proteinG: 4.2,
                fatG: 0.6,
                saltG: 0.01,
                source: FoodSource.ai,
                confidence: 0.82,
              ),
              MealItem(
                id: 'i-label',
                name: '全麦面包',
                foodId: 'f-bread',
                grams: 40,
                kcal: 98,
                carbG: 17.8,
                proteinG: 3.9,
                fatG: 1.2,
                saltG: 0.4,
                source: FoodSource.label,
              ),
            ],
          ),
        );

        final loaded = (await repo.getAllTemplates()).single;
        expect(loaded.items, hasLength(2));
        expect(loaded.items[0].source, FoodSource.ai);
        expect(loaded.items[0].confidence, 0.82);
        expect(loaded.items[0].foodId, isNull);
        expect(loaded.items[1].source, FoodSource.label);
        expect(loaded.items[1].foodId, 'f-bread');
      },
    );
  });
}
