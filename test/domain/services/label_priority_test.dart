import 'package:flutter_test/flutter_test.dart';
import 'package:caldoo/core/units/nutrition_units.dart';
import 'package:caldoo/domain/models/models.dart';
import 'package:caldoo/domain/services/label_priority.dart';

/// The 牛奶 label food from the task acceptance vector: per-100 g
/// protein 3.3 g, sodium 50 mg.
const Food milkLabel = Food(
  id: 'food-milk',
  name: '全脂牛奶',
  brand: '光明',
  source: FoodSource.label,
  kcal: 65,
  carbG: 4.8,
  proteinG: 3.3,
  fatG: 3.6,
  sodiumMg: 50,
);

/// A saved food whose every nutrient field is blank (a valid `Food`).
const Food allBlankFood = Food(
  id: 'food-none',
  name: '清炒时蔬',
  source: FoodSource.ai,
);

MealItem aiMilk({
  String name = '全脂牛奶',
  double grams = 150,
  int kcal = 120,
  double carbG = 8,
  double proteinG = 6,
  double fatG = 5,
  double saltG = 0.3,
}) => MealItem(
  id: 'item-1',
  name: name,
  grams: grams,
  kcal: kcal,
  carbG: carbG,
  proteinG: proteinG,
  fatG: fatG,
  saltG: saltG,
  source: FoodSource.ai,
  confidence: 0.7,
);

void main() {
  group('normalizeName', () {
    test('trims, lowercases, strips punctuation and collapses whitespace', () {
      expect(normalizeName(' 全脂 牛奶！'), '全脂牛奶');
      expect(normalizeName(' 全脂 牛奶！'), normalizeName('全脂牛奶'));
      expect(normalizeName('  MILK   Powder!! '), 'milk powder');
      expect(normalizeName('Milk-Powder'), 'milk powder');
      expect(normalizeName('全脂\u3000牛奶'), '全脂牛奶');
    });

    test('is idempotent and maps a blank-ish name to the empty key', () {
      const messy = '  全脂 牛奶！ ';
      expect(normalizeName(normalizeName(messy)), normalizeName(messy));
      expect(normalizeName('  ！？ '), '');
    });

    test('keeps different foods apart (no fuzzy collapsing)', () {
      expect(normalizeName('全脂牛奶'), isNot(normalizeName('脱脂牛奶')));
    });
  });

  group('parseFoodAliases', () {
    test('reads aliases after multiple zh-CN markers and separators', () {
      expect(parseFoodAliases('一包 45 g；别名：小饼干、牛奶；又名：纯牛奶 / 鲜奶'), <String>[
        '小饼干',
        '牛奶',
        '纯牛奶',
        '鲜奶',
      ]);
      expect(parseFoodAliases('别名: milk powder | whole milk'), <String>[
        'milk powder',
        'whole milk',
      ]);
      expect(parseFoodAliases('俗称：小饼干，又名：牛奶；别称：鲜奶'), <String>[
        '小饼干',
        '牛奶',
        '鲜奶',
      ]);
    });

    test('understands AKA case-insensitively', () {
      expect(parseFoodAliases('AKA: 小饼干、牛奶'), <String>['小饼干', '牛奶']);
      expect(parseFoodAliases('aka 小饼干'), <String>['小饼干']);
    });

    test('returns empty with no marker or null/blank notes', () {
      expect(parseFoodAliases('一包 45 g'), isEmpty);
      expect(parseFoodAliases(null), isEmpty);
      expect(parseFoodAliases('   '), isEmpty);
    });

    test('drops blank and duplicate aliases', () {
      expect(parseFoodAliases('别名： 、 小饼干 、、 小饼干 '), <String>['小饼干']);
    });
  });

  group('parseFoodServings', () {
    test('reads a package size written as its own notes segment', () {
      expect(parseFoodServings('一包 45 g；别名：小饼干'), <FoodServing>[
        const FoodServing(label: '一包', amount: 45, unit: 'g'),
      ]);
      expect(
        parseFoodServings('标签 2026-09-14｜一罐 450 g（整罐≈450g=270kcal）｜别名：kwark'),
        <FoodServing>[const FoodServing(label: '一罐', amount: 450, unit: 'g')],
      );
      expect(parseFoodServings('鸭腿；一袋 110 g'), <FoodServing>[
        const FoodServing(label: '一袋', amount: 110, unit: 'g'),
      ]);
    });

    test('reads several servings from one notes field', () {
      expect(parseFoodServings('一包 100 g，一块 30 g'), <FoodServing>[
        const FoodServing(label: '一包', amount: 100, unit: 'g'),
        const FoodServing(label: '一块', amount: 30, unit: 'g'),
      ]);
    });

    test('keeps a per-unit label with a slash or parenthetical', () {
      expect(parseFoodServings('一份/一袋(面饼) 80 g'), <FoodServing>[
        const FoodServing(label: '一份/一袋', amount: 80, unit: 'g'),
      ]);
      expect(parseFoodServings('一个(M) 58 g（53-63g）'), <FoodServing>[
        const FoodServing(label: '一个', amount: 58, unit: 'g'),
      ]);
    });

    test('normalises 克 and 毫升 while keeping volume distinct', () {
      expect(parseFoodServings('一袋 500 克'), <FoodServing>[
        const FoodServing(label: '一袋', amount: 500, unit: 'g'),
      ]);
      expect(parseFoodServings('一包 250 ml'), <FoodServing>[
        const FoodServing(label: '一包', amount: 250, unit: 'ml'),
      ]);
      expect(parseFoodServings('一包 250 毫升').single.isVolume, isTrue);
    });

    test('strips nested parentheticals without losing the amount', () {
      expect(
        parseFoodServings('一袋 500 g（净重500g（不含冰衣）；虾85%+水+盐）'),
        <FoodServing>[const FoodServing(label: '一袋', amount: 500, unit: 'g')],
      );
    });

    test('ignores prose, per-100 g values, dates and null/blank notes', () {
      expect(parseFoodServings('每100g：60kcal、脂肪0.2'), isEmpty);
      expect(parseFoodServings('面饼80g 295kcal；一袋120g=511kcal'), isEmpty);
      expect(parseFoodServings('标签 2026-09-07'), isEmpty);
      expect(parseFoodServings('3块=50g'), isEmpty);
      expect(parseFoodServings('别名：kwark、夸克'), isEmpty);
      expect(parseFoodServings(null), isEmpty);
      expect(parseFoodServings('   '), isEmpty);
    });

    test('caps at three servings and drops duplicates', () {
      expect(
        parseFoodServings('一包 100 g；一包 100 g；一块 30 g；一根 45 g；一瓶 350 g'),
        <FoodServing>[
          const FoodServing(label: '一包', amount: 100, unit: 'g'),
          const FoodServing(label: '一块', amount: 30, unit: 'g'),
          const FoodServing(label: '一根', amount: 45, unit: 'g'),
        ],
      );
    });
  });

  group('foodAliases / foodServings', () {
    test('structured aliases win over aliases recorded in notes', () {
      const Food structured = Food(
        id: 'food-structured',
        name: '苏打饼干',
        aliases: <String>['小饼干'],
        notes: '别名：牛奶',
        source: FoodSource.manual,
      );

      expect(foodAliases(structured), <String>['小饼干']);
    });

    test('falls back to parsing notes for legacy alias-only rows', () {
      const Food legacy = Food(
        id: 'food-legacy',
        name: '苏打饼干',
        notes: '一包 45 g；别名：小饼干、牛奶',
        source: FoodSource.manual,
      );

      expect(foodAliases(legacy), <String>['小饼干', '牛奶']);
      expect(
        foodAliases(
          const Food(id: 'food-none', name: '米饭', source: FoodSource.manual),
        ),
        isEmpty,
      );
    });

    test('structured servings win over servings recorded in notes', () {
      const Food structured = Food(
        id: 'food-structured-serving',
        name: '辛拉面',
        servings: <FoodServing>[
          FoodServing(label: '一袋', amount: 120, unit: 'g'),
        ],
        notes: '一包 45 g',
        source: FoodSource.label,
      );
      const Food legacy = Food(
        id: 'food-legacy-serving',
        name: '辛拉面',
        notes: '一包 45 g',
        source: FoodSource.label,
      );

      expect(foodServings(structured), <FoodServing>[
        const FoodServing(label: '一袋', amount: 120, unit: 'g'),
      ]);
      expect(foodServings(legacy), <FoodServing>[
        const FoodServing(label: '一包', amount: 45, unit: 'g'),
      ]);
    });
  });

  group('suggestSavedFood', () {
    test('ranks exact normalized-name matches with label source first', () {
      const aiFood = Food(
        id: 'food-ai',
        name: '全脂牛奶',
        source: FoodSource.ai,
        kcal: 70,
        carbG: 5,
        proteinG: 3,
        fatG: 3,
        sodiumMg: 60,
      );
      const manualFood = Food(
        id: 'food-manual',
        name: '全脂 牛奶',
        source: FoodSource.manual,
        kcal: 68,
        carbG: 5,
        proteinG: 3.1,
        fatG: 3.2,
        sodiumMg: 55,
      );

      // milkLabel is deliberately LAST in the input list: ranking must not be
      // input order.
      final suggestions = suggestSavedFood(aiMilk(name: ' 全脂 牛奶！ '), <Food>[
        aiFood,
        manualFood,
        milkLabel,
      ]);

      expect(
        suggestions.map((FoodSuggestion s) => s.food.id).toList(),
        <String>['food-milk', 'food-manual', 'food-ai'],
      );
      expect(suggestions[0].score, 1.0);
      expect(suggestions[1].score, closeTo(0.98, 1e-9));
      expect(suggestions[2].score, closeTo(0.95, 1e-9));
      for (final suggestion in suggestions) {
        expect(suggestion.reason, FoodMatchReason.exactName);
        expect(suggestion.matchedAlias, isNull);
      }
    });

    test('returns nothing when no saved food matches the normalized key', () {
      final suggestions = suggestSavedFood(aiMilk(name: '清炒时蔬'), <Food>[
        milkLabel,
      ]);
      expect(suggestions, isEmpty);
    });

    test('matches by containment in either direction (barcode never used)', () {
      const contains = Food(
        id: 'food-contains',
        name: '光明全脂牛奶',
        source: FoodSource.label,
        kcal: 65,
        proteinG: 3.3,
      );
      const barcodeOnly = Food(
        id: 'food-barcode',
        name: '纯牛奶',
        barcode: '6901234567890',
        source: FoodSource.label,
        kcal: 65,
        proteinG: 3.0,
      );
      final suggestions = suggestSavedFood(aiMilk(name: '全脂牛奶'), <Food>[
        barcodeOnly,
        contains,
      ]);

      expect(suggestions, hasLength(1));
      expect(suggestions.single.food.id, 'food-contains');
      expect(suggestions.single.reason, FoodMatchReason.partialName);
      expect(suggestions.single.score, closeTo(0.72 + 0.22 * 4 / 6, 1e-9));
    });

    test('matches an exact alias parsed from notes (legacy rows)', () {
      const snack = Food(
        id: 'food-snack',
        name: '某饼干',
        notes: '一包 45 g；别名：小饼干、牛奶',
        source: FoodSource.label,
        kcal: 480,
        proteinG: 6,
      );
      final suggestions = suggestSavedFood(
        aiMilk(name: '牛奶', grams: 45, kcal: 216),
        <Food>[snack],
      );

      expect(suggestions, hasLength(1));
      expect(suggestions.single.reason, FoodMatchReason.alias);
      expect(suggestions.single.matchedAlias, '牛奶');
      expect(suggestions.single.score, closeTo(0.97, 1e-9));
    });

    test('matches an exact structured alias and reports the raw alias', () {
      const snack = Food(
        id: 'food-snack',
        name: '苏打饼干',
        aliases: <String>['小饼干', '苏打'],
        source: FoodSource.label,
        kcal: 480,
      );
      final suggestions = suggestSavedFood(
        aiMilk(name: '小饼干', grams: 45, kcal: 216),
        <Food>[snack],
      );

      expect(suggestions, hasLength(1));
      expect(suggestions.single.reason, FoodMatchReason.alias);
      expect(suggestions.single.matchedAlias, '小饼干');
      expect(suggestions.single.score, closeTo(0.97, 1e-9));
    });

    test('structured aliases replace notes aliases (notes are legacy only)', () {
      const structured = Food(
        id: 'food-structured',
        name: '苏打饼干',
        aliases: <String>['小饼干'],
        notes: '别名：牛奶',
        source: FoodSource.label,
        kcal: 480,
      );

      expect(
        suggestSavedFood(aiMilk(name: '小饼干'), <Food>[structured]),
        hasLength(1),
      );
      // The notes marker is ignored once structured aliases exist, exactly like
      // foodServings ignores notes once structured servings exist.
      expect(suggestSavedFood(aiMilk(name: '牛奶'), <Food>[structured]), isEmpty);
    });

    test(
      'never suggests an archived food, not even by exact name or alias',
      () {
        const archived = Food(
          id: 'food-archived',
          name: '全脂牛奶',
          status: FoodStatus.archived,
          source: FoodSource.label,
          kcal: 65,
        );
        const archivedAlias = Food(
          id: 'food-archived-alias',
          name: '苏打饼干',
          aliases: <String>['小饼干'],
          status: FoodStatus.archived,
          source: FoodSource.label,
          kcal: 480,
        );

        expect(
          suggestSavedFood(aiMilk(name: '全脂牛奶'), <Food>[archived]),
          isEmpty,
        );
        expect(
          suggestSavedFood(aiMilk(name: '小饼干'), <Food>[archivedAlias]),
          isEmpty,
        );
        // An active food next to them is still suggested normally.
        final mixed = suggestSavedFood(aiMilk(name: '全脂牛奶'), <Food>[
          archived,
          milkLabel,
        ]);
        expect(mixed.map((FoodSuggestion s) => s.food.id).toList(), <String>[
          'food-milk',
        ]);
      },
    );

    test('brand text disambiguates same-name saved foods', () {
      const mengniu = Food(
        id: 'food-mengniu',
        name: '纯牛奶',
        brand: '蒙牛',
        source: FoodSource.label,
      );
      const yili = Food(
        id: 'food-yili',
        name: '纯牛奶',
        brand: '伊利',
        source: FoodSource.label,
      );
      final suggestions = suggestSavedFood(aiMilk(name: '蒙牛纯牛奶'), <Food>[
        yili,
        mengniu,
      ]);

      expect(
        suggestions.map((FoodSuggestion s) => s.food.id).toList(),
        <String>['food-mengniu', 'food-yili'],
      );
      expect(
        suggestions.first.score,
        closeTo(0.72 + 0.22 * 3 / 5 + 0.05, 1e-9),
      );
      expect(suggestions.last.score, closeTo(0.72 + 0.22 * 3 / 5, 1e-9));
      for (final suggestion in suggestions) {
        expect(suggestion.reason, FoodMatchReason.partialName);
      }
    });

    test('falls back to bigram similarity for reordered ASCII keys', () {
      const powderMilk = Food(
        id: 'food-powder',
        name: 'Powder Milk',
        source: FoodSource.label,
      );
      final suggestions = suggestSavedFood(aiMilk(name: 'milk powder'), <Food>[
        powderMilk,
      ]);

      expect(suggestions, hasLength(1));
      expect(suggestions.single.reason, FoodMatchReason.similarName);
      expect(suggestions.single.score, closeTo(0.63, 1e-9));
    });

    test('implausible per-100 g kcal ranks below a plausible candidate', () {
      const plausible = Food(
        id: 'food-plausible',
        name: '全脂牛奶',
        brand: '蒙牛',
        source: FoodSource.label,
        kcal: 150,
      );
      const wild = Food(
        id: 'food-wild',
        name: '全脂牛奶',
        brand: '蒙牛',
        source: FoodSource.label,
        kcal: 1500,
      );
      // AI implies 300 kcal / 200 g = 150 kcal per 100 g; `wild` is ~10x that.
      final suggestions = suggestSavedFood(
        aiMilk(name: '蒙牛全脂牛奶', grams: 200, kcal: 300),
        <Food>[wild, plausible],
      );

      expect(
        suggestions.map((FoodSuggestion s) => s.food.id).toList(),
        <String>['food-plausible', 'food-wild'],
      );
      const double identity = 0.72 + 0.22 * 4 / 6 + 0.05;
      expect(suggestions.first.score, closeTo(identity, 1e-9));
      expect(suggestions.last.score, closeTo(identity * 0.55, 1e-9));
    });

    test(
      'an exact name is never demoted or filtered by a wild kcal estimate',
      () {
        const exact = Food(
          id: 'food-exact',
          name: '全脂牛奶',
          source: FoodSource.label,
          kcal: 65,
        );
        // AI implies 150 kcal per 100 g while the label says 65: an exact name
        // must still score 1.0 and stay on the list.
        final suggestions = suggestSavedFood(
          aiMilk(name: '全脂牛奶', grams: 200, kcal: 300),
          <Food>[exact],
        );

        expect(suggestions, hasLength(1));
        expect(suggestions.single.reason, FoodMatchReason.exactName);
        expect(suggestions.single.score, 1.0);
      },
    );

    test('respects the limit and orders score ties deterministically', () {
      const names = <String>['脱脂牛奶', '高钙牛奶', '全脂牛奶', '有机牛奶', '早餐牛奶'];
      final foods = <Food>[
        for (var i = 0; i < names.length; i++)
          Food(id: 'food-$i', name: names[i], source: FoodSource.label),
      ];

      final first = suggestSavedFood(aiMilk(name: '牛奶'), foods);
      final second = suggestSavedFood(aiMilk(name: '牛奶'), foods);

      expect(first, hasLength(3));
      // Equal scores break by normalized name ascending (code-unit order).
      expect(first.map((FoodSuggestion s) => s.food.name).toList(), <String>[
        '全脂牛奶',
        '早餐牛奶',
        '有机牛奶',
      ]);
      expect(first, second);
    });

    test('is non-binding: never mutates the AI item and stores no link', () {
      final item = aiMilk();
      final before = item.toJson();

      final suggestions = suggestSavedFood(item, <Food>[milkLabel]);

      expect(suggestions, hasLength(1));
      expect(item.toJson(), before);
      expect(item.source, FoodSource.ai);
      expect(item.foodId, isNull);
    });
  });

  group('rankCatalogueForQuery', () {
    test('returns empty for a blank query', () {
      const foods = <Food>[
        Food(id: 'f-milk', name: '牛奶', source: FoodSource.label),
      ];
      expect(rankCatalogueForQuery('   ', foods), isEmpty);
      expect(rankCatalogueForQuery('！？', foods), isEmpty);
    });

    test('returns the whole small catalogue ordered by source priority', () {
      const foods = <Food>[
        Food(id: 'f-apple', name: '苹果', source: FoodSource.ai),
        Food(id: 'f-egg', name: '鸡蛋', source: FoodSource.manual),
        Food(id: 'f-bread', name: '面包', source: FoodSource.label),
      ];
      final ranked = rankCatalogueForQuery('牛奶', foods, limit: 20);

      expect(ranked.map((Food f) => f.id).toList(), <String>[
        'f-bread',
        'f-egg',
        'f-apple',
      ]);
      expect(() => ranked.add(allBlankFood), throwsUnsupportedError);
    });

    test('ranks the most relevant saved food first for a query', () {
      const foods = <Food>[
        Food(id: 'f-apple', name: '苹果', source: FoodSource.label),
        Food(id: 'f-whole-milk', name: '全脂牛奶', source: FoodSource.label),
        Food(id: 'f-egg', name: '鸡蛋', source: FoodSource.label),
        Food(id: 'f-bread', name: '面包', source: FoodSource.label),
        Food(id: 'f-milk', name: '牛奶', source: FoodSource.label),
      ];
      final ranked = rankCatalogueForQuery('牛奶', foods, limit: 2);

      expect(ranked.map((Food f) => f.name).toList(), <String>['牛奶', '全脂牛奶']);
      expect(rankCatalogueForQuery('牛奶', foods, limit: 2), ranked);
    });

    test('uses aliases and the one-character CJK fallback for recall', () {
      const foods = <Food>[
        Food(
          id: 'f-snack',
          name: '某饼干',
          notes: '别名：牛奶',
          source: FoodSource.label,
        ),
        Food(id: 'f-egg', name: '鸡蛋', source: FoodSource.label),
        Food(id: 'f-apple', name: '苹果', source: FoodSource.label),
      ];
      final ranked = rankCatalogueForQuery('牛奶', foods, limit: 1);
      expect(ranked.single.id, 'f-snack');

      final short = rankCatalogueForQuery('奶', foods, limit: 1);
      expect(short.single.id, 'f-snack');
    });

    test('recalls a structured alias, ignoring notes once aliases exist', () {
      const foods = <Food>[
        Food(
          id: 'f-structured',
          name: '苏打饼干',
          aliases: <String>['牛奶'],
          notes: '别名：薄脆',
          source: FoodSource.label,
        ),
        Food(id: 'f-egg', name: '鸡蛋', source: FoodSource.label),
        Food(id: 'f-apple', name: '苹果', source: FoodSource.label),
      ];
      final ranked = rankCatalogueForQuery('牛奶', foods, limit: 1);
      expect(ranked.single.id, 'f-structured');
      // The notes alias was superseded by the structured list.
      expect(rankCatalogueForQuery('薄脆', foods, limit: 1), isEmpty);
    });

    test(
      'never recalls an archived food, even in the small-catalogue path',
      () {
        const foods = <Food>[
          Food(
            id: 'f-archived',
            name: '牛奶',
            status: FoodStatus.archived,
            source: FoodSource.label,
          ),
          Food(
            id: 'f-archived-alias',
            name: '苏打饼干',
            aliases: <String>['小饼干'],
            status: FoodStatus.archived,
            source: FoodSource.label,
          ),
          Food(id: 'f-milk', name: '全脂牛奶', source: FoodSource.label),
        ];

        // `foods.length <= limit`: archived rows are still skipped before the
        // whole-catalogue shortcut returns.
        final small = rankCatalogueForQuery('牛奶', foods, limit: 20);
        expect(small.map((Food f) => f.id).toList(), <String>['f-milk']);

        // Scored path (active catalogue larger than the limit) skips them too:
        // the only alias match is archived, so nothing is recalled.
        const withMore = <Food>[
          ...foods,
          Food(id: 'f-egg', name: '鸡蛋', source: FoodSource.label),
          Food(id: 'f-apple', name: '苹果', source: FoodSource.label),
        ];
        expect(rankCatalogueForQuery('小饼干', withMore, limit: 1), isEmpty);
        expect(
          rankCatalogueForQuery('牛奶', withMore, limit: 1).map((Food f) => f.id),
          <String>['f-milk'],
        );
      },
    );

    test('clamps limit to at least 1', () {
      const foods = <Food>[
        Food(id: 'f-milk', name: '牛奶', source: FoodSource.label),
        Food(id: 'f-egg', name: '鸡蛋', source: FoodSource.label),
      ];
      final ranked = rankCatalogueForQuery('牛奶', foods, limit: 0);
      expect(ranked.single.id, 'f-milk');
    });
  });

  group('resolveNutrients', () {
    test('150 g of the 牛奶 label scales per-100 g EXACTLY', () {
      final item = aiMilk();
      final resolved = resolveNutrients(item, milkLabel, 150);

      // The contract expression is `labelPer100g * grams / 100`; with that
      // order these are exact doubles (labelPer100g * (grams / 100) is not).
      expect(resolved.kcal, 98); // roundKcal(65 * 150 / 100)
      expect(resolved.carbG, 7.2); // 4.8 * 150 / 100
      expect(resolved.proteinG, 4.95); // 3.3 * 150 / 100
      expect(resolved.fatG, 5.4); // 3.6 * 150 / 100
      expect(resolved.saltG, 0.1875); // sodiumMgToSaltG(50 * 150 / 100)

      // The sodium mg -> salt g bridge is explicit.
      expect(resolved.saltG, sodiumMgToSaltG(75));

      // Label values beat the deliberately different AI values.
      expect(resolved.proteinG, isNot(item.proteinG));
      expect(resolved.saltG, isNot(item.saltG));

      for (final NutrientField field in NutrientField.values) {
        expect(
          resolved.provenanceOf(field),
          NutrientProvenance.label,
          reason: 'expected $field to be badged label',
        );
      }
    });

    test('a blank label field falls back to the AI value, never 0', () {
      const blankProtein = Food(
        id: 'food-blank',
        name: '全脂牛奶',
        source: FoodSource.label,
        kcal: 65,
        carbG: 4.8,
        proteinG: null,
        fatG: 3.6,
        sodiumMg: null,
      );
      final item = aiMilk(proteinG: 6, saltG: 0.3);
      final resolved = resolveNutrients(item, blankProtein, 150);

      expect(resolved.proteinG, 6.0);
      expect(resolved.proteinG, item.proteinG);
      expect(resolved.proteinG, isNot(0));
      expect(
        resolved.provenanceOf(NutrientField.proteinG),
        NutrientProvenance.ai,
      );

      expect(resolved.saltG, 0.3);
      expect(resolved.saltG, item.saltG);
      expect(resolved.saltG, isNot(0));
      expect(resolved.provenanceOf(NutrientField.saltG), NutrientProvenance.ai);

      // Fields the label DID provide still come from the label.
      expect(resolved.kcal, 98);
      expect(resolved.carbG, 7.2);
      expect(resolved.fatG, 5.4);
      expect(
        resolved.provenanceOf(NutrientField.kcal),
        NutrientProvenance.label,
      );
      expect(
        resolved.provenanceOf(NutrientField.carbG),
        NutrientProvenance.label,
      );
      expect(
        resolved.provenanceOf(NutrientField.fatG),
        NutrientProvenance.label,
      );
    });

    test('an unmatched item keeps every AI value with provenance ai', () {
      final item = aiMilk(
        name: '清炒时蔬',
        kcal: 180,
        carbG: 12,
        proteinG: 4,
        fatG: 11,
        saltG: 1.25,
      );

      // No saved food matches -> no suggestion at all.
      expect(suggestSavedFood(item, <Food>[milkLabel]), isEmpty);

      final resolved = resolveNutrients(item, allBlankFood, 150);
      expect(resolved.kcal, 180);
      expect(resolved.carbG, 12.0);
      expect(resolved.proteinG, 4.0);
      expect(resolved.fatG, 11.0);
      expect(resolved.saltG, 1.25);
      expect(resolved.provenance, hasLength(NutrientField.values.length));
      for (final NutrientField field in NutrientField.values) {
        expect(
          resolved.provenanceOf(field),
          NutrientProvenance.ai,
          reason: 'expected $field to be badged ai',
        );
      }
    });

    test('is a pure function: no input is mutated, no snapshot is taken', () {
      final item = aiMilk();
      final beforeItem = item.toJson();
      final beforeFood = milkLabel.toJson();

      resolveNutrients(item, milkLabel, 150);

      expect(item.toJson(), beforeItem);
      expect(item.foodId, isNull); // the CALLER stores foodId + grams
      expect(item.grams, 150);
      expect(milkLabel.toJson(), beforeFood);
    });

    test('0 g scales label fields to 0 but never zeroes a blank field', () {
      const blankProtein = Food(
        id: 'food-blank',
        name: '全脂牛奶',
        source: FoodSource.label,
        kcal: 65,
        carbG: 4.8,
        proteinG: null,
        fatG: 3.6,
        sodiumMg: null,
      );
      final resolved = resolveNutrients(
        aiMilk(proteinG: 6, saltG: 0.3),
        blankProtein,
        0,
      );

      expect(resolved.kcal, 0);
      expect(
        resolved.provenanceOf(NutrientField.kcal),
        NutrientProvenance.label,
      );
      expect(resolved.proteinG, 6.0);
      expect(
        resolved.provenanceOf(NutrientField.proteinG),
        NutrientProvenance.ai,
      );
    });

    test('rejects malformed grams (negative / NaN / infinite)', () {
      expect(
        () => resolveNutrients(aiMilk(), milkLabel, -1),
        throwsArgumentError,
      );
      expect(
        () => resolveNutrients(aiMilk(), milkLabel, double.nan),
        throwsArgumentError,
      );
      expect(
        () => resolveNutrients(aiMilk(), milkLabel, double.infinity),
        throwsArgumentError,
      );
    });

    test(
      'a non-finite/negative label value is blank -> AI fallback, not 0',
      () {
        const malformed = Food(
          id: 'food-nan',
          name: '全脂牛奶',
          source: FoodSource.label,
          proteinG: double.nan,
          sodiumMg: -5,
        );
        final resolved = resolveNutrients(
          aiMilk(proteinG: 6, saltG: 0.3),
          malformed,
          150,
        );

        expect(resolved.proteinG, 6.0);
        expect(
          resolved.provenanceOf(NutrientField.proteinG),
          NutrientProvenance.ai,
        );
        expect(resolved.saltG, 0.3);
        expect(
          resolved.provenanceOf(NutrientField.saltG),
          NutrientProvenance.ai,
        );
      },
    );

    test(
      'a malformed AI fallback value is rejected (never poisons a total)',
      () {
        expect(
          () =>
              resolveNutrients(aiMilk(proteinG: double.nan), allBlankFood, 150),
          throwsArgumentError,
        );
        expect(
          () => resolveNutrients(aiMilk(kcal: -1), allBlankFood, 150),
          throwsArgumentError,
        );
      },
    );
  });
}
