import 'package:flutter_test/flutter_test.dart';

import 'package:caldoo/domain/models/models.dart';
import 'package:caldoo/features/meals/saved_foods/saved_food_search.dart';

import '_fixtures.dart';

void main() {
  group('searchSavedFoods', () {
    test('a blank or punctuation-only query returns the whole catalogue', () {
      final List<String> ids = searchSavedFoods(<Food>[
        labelMilk,
        aiVeg,
      ], '   ').map((f) => f.id).toList();
      expect(ids, <String>['food-label-milk', 'food-ai-veg']);
      expect(searchSavedFoods(<Food>[labelMilk, aiVeg], '！？'), hasLength(2));
    });

    test('matches a normalized substring of the name (CJK spaces ignored)', () {
      expect(
        searchSavedFoods(<Food>[labelMilk, aiVeg], '牛奶').map((f) => f.id),
        <String>['food-label-milk'],
      );
      expect(
        searchSavedFoods(<Food>[labelMilk, aiVeg], '全脂 牛奶').map((f) => f.id),
        <String>['food-label-milk'],
      );
    });

    test('matches an alias/package note recorded in notes', () {
      final List<Food> catalogue = <Food>[labelMilk, aiVeg, aliasedFood];
      expect(searchSavedFoods(catalogue, '小饼干').map((f) => f.id), <String>[
        'food-alias',
      ]);
      expect(searchSavedFoods(catalogue, '45 g').map((f) => f.id), <String>[
        'food-alias',
      ]);
    });

    test('matches a structured alias', () {
      const Food structuredAlias = Food(
        id: 'food-structured-alias',
        name: '苏打饼干',
        aliases: <String>['薄 脆', '苏打饼'],
        source: FoodSource.manual,
      );
      final List<Food> catalogue = <Food>[
        labelMilk,
        aiVeg,
        aliasedFood,
        structuredAlias,
      ];

      // The structured alias is normalized like every other field (the CJK
      // inner space is dropped on both sides before the substring test).
      expect(searchSavedFoods(catalogue, '薄脆').map((f) => f.id), <String>[
        'food-structured-alias',
      ]);
      // The legacy notes alias still matches (this food has no structured one).
      expect(searchSavedFoods(catalogue, '小饼干').map((f) => f.id), <String>[
        'food-alias',
      ]);
    });

    test('matches the brand too', () {
      expect(
        searchSavedFoods(<Food>[labelMilk, aiVeg], '光明').map((f) => f.id),
        <String>['food-label-milk'],
      );
    });

    test('a non-match is an empty list, never an error', () {
      expect(searchSavedFoods(<Food>[labelMilk, aiVeg], '汉堡'), isEmpty);
    });
  });
}
