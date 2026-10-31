// The SAME contract suite runs twice: once against the Drift implementation
// (in-memory database) and once against the in-memory fake. A behavior only
// belongs to the repository contract when both implementations satisfy it.
import 'package:flutter_test/flutter_test.dart';
import 'package:caldoo/data/db/app_database.dart';
import 'package:caldoo/data/repositories/drift_food_repository.dart';
import 'package:caldoo/domain/models/food.dart';

import '../db/_test_db.dart';
import 'fake_repositories.dart';
import 'repository_suites.dart';

void main() {
  group('FoodRepository: Drift implementation (in-memory DB)', () {
    late AppDatabase db;
    setUp(() => db = testDb());
    tearDown(() => db.close());

    runFoodRepositorySuite(() => DriftFoodRepository(db));

    test('NULL structured columns read as defaults (legacy rows)', () async {
      // A row written before v7 has NULL aliases/servings/status/basis.
      await db
          .into(db.foods)
          .insert(
            FoodsCompanion.insert(
              id: 'legacy',
              name: '米饭',
              source: FoodSource.label,
            ),
          );

      final loaded = await DriftFoodRepository(db).getFood('legacy');

      expect(loaded, isNotNull);
      expect(loaded!.aliases, isEmpty);
      expect(loaded.servings, isEmpty);
      expect(loaded.status, FoodStatus.active);
      expect(loaded.basis, MeasureBasis.per100g);
    });
  });

  group('FoodRepository: Fake implementation (in-memory map)', () {
    late FakeFoodRepository fake;
    setUp(() => fake = FakeFoodRepository());
    tearDown(() => fake.dispose());

    runFoodRepositorySuite(() => fake);
  });
}
