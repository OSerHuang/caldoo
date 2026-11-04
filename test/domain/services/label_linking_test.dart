/// Unit tests for the pure label-linking layer.
///
/// Three seams are covered here, all without any AI payload or Flutter widget:
///
/// * `renderLabelIndex` — the `#n｜…` prompt block: 0-based numbering, omitted
///   empty segments, single-line fields and whole-line truncation;
/// * `normalizeLabelMatches` — model output hardening: bounds, de-duplication,
///   per-item cap, count/serving sanity;
/// * `decideLabelApply` — the auto-apply gate: untouched rows only, the
///   plausibility ratio, and `count × serving` grams.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:caldoo/ai/schemas/label_link.dart';
import 'package:caldoo/domain/models/models.dart';
import 'package:caldoo/domain/services/label_linking.dart';

/// Saved food builder; id defaults to the name, which is unique in these tests.
Food food(
  String name, {
  String? id,
  String? brand,
  String? notes,
  List<String> aliases = const <String>[],
  List<FoodServing> servings = const <FoodServing>[],
  FoodStatus status = FoodStatus.active,
  int? kcal,
  FoodSource source = FoodSource.label,
}) {
  return Food(
    id: id ?? name,
    name: name,
    brand: brand,
    notes: notes,
    aliases: aliases,
    servings: servings,
    status: status,
    source: source,
    kcal: kcal,
  );
}

/// Meal item builder in the app's canonical units.
MealItem aiItem({
  String id = 'item-0',
  String name = '辛拉面',
  double grams = 100,
  int kcal = 120,
}) {
  return MealItem(
    id: id,
    name: name,
    grams: grams,
    kcal: kcal,
    carbG: 0,
    proteinG: 0,
    fatG: 0,
    saltG: 0,
    source: FoodSource.ai,
  );
}

/// One raw candidate row.
LabelMatch match(
  int itemIndex,
  int foodIndex, {
  double? count,
  String? servingLabel,
}) {
  return LabelMatch(
    itemIndex: itemIndex,
    foodIndex: foodIndex,
    count: count,
    servingLabel: servingLabel,
  );
}

void main() {
  group('renderLabelIndex', () {
    test('numbers the lines by list index and renders every segment', () {
      final String index = renderLabelIndex(<Food>[
        food('辛拉面(农心)', brand: '农心', notes: '一包 120 g；别名：泡面、辛拉面'),
        food('鸡蛋', notes: '一个 58 g'),
      ]);

      expect(
        index,
        '#0｜辛拉面(农心)｜品牌：农心｜别名：泡面、辛拉面｜份量：一包 120 g\n'
        '#1｜鸡蛋｜份量：一个 58 g',
      );
      expect(index.split('\n'), hasLength(2));
    });

    test('omits the brand / alias / serving segments a food does not have', () {
      expect(renderLabelIndex(<Food>[food('米饭')]), '#0｜米饭');
      expect(
        renderLabelIndex(<Food>[food('米饭', brand: '金龙鱼')]),
        '#0｜米饭｜品牌：金龙鱼',
      );
      expect(
        renderLabelIndex(<Food>[food('乐事薯片', notes: '别名：薯片、土豆片')]),
        '#0｜乐事薯片｜别名：薯片、土豆片',
      );
      // A notes field with neither an alias marker nor a serving shape is
      // ignored entirely instead of leaking prose into the prompt.
      expect(
        renderLabelIndex(<Food>[food('米饭', notes: '每100g：116kcal')]),
        '#0｜米饭',
      );
    });

    test('joins several recorded servings with the ideographic comma', () {
      expect(
        renderLabelIndex(<Food>[food('饼干', notes: '一包 100 g，一块 30 g')]),
        '#0｜饼干｜份量：一包 100 g、一块 30 g',
      );
    });

    test('keeps a volume serving in ml and renders fractional amounts', () {
      expect(
        renderLabelIndex(<Food>[food('豆浆', notes: '一包 250 ml')]),
        '#0｜豆浆｜份量：一包 250 ml',
      );
      expect(
        renderLabelIndex(<Food>[food('奶酪三角', notes: '一块 16.67 g')]),
        '#0｜奶酪三角｜份量：一块 16.67 g',
      );
    });

    test('folds newlines and whitespace runs in every field onto one line', () {
      final String index = renderLabelIndex(<Food>[
        food('光明\n全脂  牛奶', brand: ' 光 明 ', notes: '一包 250 ml；别名：牛  奶、 纯 牛奶'),
      ]);

      expect(index, '#0｜光明 全脂 牛奶｜品牌：光 明｜别名：牛 奶、纯 牛奶｜份量：一包 250 ml');
      // One food is exactly one prompt line: a newline in a user-supplied
      // name must not be able to inject another line.
      expect(index, isNot(contains('\n')));
    });

    test('skips a nameless food but keeps the true list indices', () {
      final String index = renderLabelIndex(<Food>[food('   '), food('米饭')]);
      expect(index, '#1｜米饭');
    });

    test('renders structured aliases and servings', () {
      final String index = renderLabelIndex(<Food>[
        food(
          '辛拉面(农心)',
          brand: '农心',
          aliases: <String>['泡面', '辛拉面'],
          servings: const <FoodServing>[
            FoodServing(label: '一包', amount: 120, unit: 'g'),
          ],
        ),
        food(
          '鸡蛋',
          servings: const <FoodServing>[
            FoodServing(label: '一个', amount: 58, unit: 'g'),
          ],
        ),
      ]);

      expect(
        index,
        '#0｜辛拉面(农心)｜品牌：农心｜别名：泡面、辛拉面｜份量：一包 120 g\n'
        '#1｜鸡蛋｜份量：一个 58 g',
      );
    });

    test('prefers structured aliases/servings over legacy notes', () {
      final String index = renderLabelIndex(<Food>[
        food(
          '乐事薯片',
          aliases: <String>['薯片'],
          notes: '别名：土豆片；一包 45 g',
          servings: const <FoodServing>[
            FoodServing(label: '一袋', amount: 50, unit: 'g'),
          ],
        ),
      ]);

      expect(index, '#0｜乐事薯片｜别名：薯片｜份量：一袋 50 g');
    });

    test('skips archived foods but keeps the true list indices', () {
      final String index = renderLabelIndex(<Food>[
        food(
          '旧牛奶',
          status: FoodStatus.archived,
          aliases: <String>['牛奶'],
          servings: const <FoodServing>[
            FoodServing(label: '一包', amount: 250, unit: 'ml'),
          ],
        ),
        food('米饭'),
        food('旧饼干', status: FoodStatus.archived),
      ]);

      // An archived food is retired from matching: no line at all, and the
      // rendered #n is still the true subscript in the list.
      expect(index, '#1｜米饭');
    });

    test('truncates whole lines and never exceeds maxChars', () {
      final List<Food> foods = <Food>[food('光明 全脂牛奶'), food('伊利 低脂牛奶')];
      final String both = renderLabelIndex(foods);
      final List<String> lines = both.split('\n');
      final String firstLine = lines.first;
      final String secondLine = lines.last;

      // Exactly one line fits.
      expect(renderLabelIndex(foods, maxChars: firstLine.length), firstLine);
      // One character short: nothing fits, and no half line is emitted.
      expect(renderLabelIndex(foods, maxChars: firstLine.length - 1), '');
      // Both lines with the separating newline.
      expect(
        renderLabelIndex(
          foods,
          maxChars: firstLine.length + 1 + secondLine.length,
        ),
        both,
      );
      expect(renderLabelIndex(foods, maxChars: 3), '');
    });

    test('a dropped long line does not stop a later shorter one', () {
      final String index = renderLabelIndex(<Food>[
        food('一个非常非常非常非常非常长的标签名字'),
        food('米'),
      ], maxChars: '#1｜米'.length);
      expect(index, '#1｜米');
    });

    test('returns an empty string for an empty library or budget', () {
      expect(renderLabelIndex(const <Food>[]), '');
      expect(renderLabelIndex(<Food>[food('米饭')], maxChars: 0), '');
      expect(renderLabelIndex(<Food>[food('米饭')], maxChars: -10), '');
    });

    test('is deterministic', () {
      final List<Food> foods = <Food>[
        food('光明 全脂牛奶', brand: '光明', notes: '一包 250 ml；别名：牛奶'),
        food('米饭', kcal: 116),
      ];
      expect(renderLabelIndex(foods), renderLabelIndex(foods));
    });
  });

  group('normalizeLabelMatches', () {
    final Food ramen = food('辛拉面', notes: '一包 120 g');
    final Food egg = food('鸡蛋', notes: '一个 58 g');
    final Food rice = food('米饭');
    final Food milk = food('牛奶', notes: '一包 250 ml');
    final List<Food> foods = <Food>[ramen, egg, rice, milk];

    test('drops indices outside the item list or the food list', () {
      final List<LabelMatch> result = normalizeLabelMatches(
        matches: <LabelMatch>[
          match(-1, 0),
          match(0, -1),
          match(2, 0),
          match(0, 4),
          match(1, 3),
        ],
        itemCount: 2,
        foods: foods,
      );
      expect(result, <LabelMatch>[match(1, 3)]);
    });

    test('de-duplicates the same (item, food) pair, keeping the first row', () {
      final List<LabelMatch> result = normalizeLabelMatches(
        matches: <LabelMatch>[
          match(0, 0, count: 1, servingLabel: '一包'),
          match(0, 0, count: 2, servingLabel: '一包'),
        ],
        itemCount: 1,
        foods: foods,
      );
      expect(result, <LabelMatch>[match(0, 0, count: 1, servingLabel: '一包')]);
    });

    test('keeps at most three candidates per item, in model order', () {
      final List<LabelMatch> result = normalizeLabelMatches(
        matches: <LabelMatch>[
          match(0, 3),
          match(0, 1),
          match(0, 0),
          match(0, 2),
        ],
        itemCount: 1,
        foods: foods,
      );
      expect(result, <LabelMatch>[match(0, 3), match(0, 1), match(0, 0)]);
      expect(labelLinkMaxCandidatesPerItem, 3);
    });

    test('interleaves items without letting one item eat another cap', () {
      final List<LabelMatch> result = normalizeLabelMatches(
        matches: <LabelMatch>[
          match(0, 0),
          match(1, 1),
          match(0, 1),
          match(1, 2),
        ],
        itemCount: 2,
        foods: foods,
      );
      expect(result, hasLength(4));
      expect(
        result.map((LabelMatch m) => (m.itemIndex, m.foodIndex)),
        <(int, int)>[(0, 0), (1, 1), (0, 1), (1, 2)],
      );
    });

    test('honours a custom maxPerItem', () {
      final List<LabelMatch> result = normalizeLabelMatches(
        matches: <LabelMatch>[match(0, 0), match(0, 1)],
        itemCount: 1,
        foods: foods,
        maxPerItem: 1,
      );
      expect(result, <LabelMatch>[match(0, 0)]);
    });

    test('clears a non-positive or non-finite count and its serving', () {
      final List<LabelMatch> result = normalizeLabelMatches(
        matches: <LabelMatch>[
          match(0, 0, count: 0, servingLabel: '一包'),
          match(0, 1, count: -3, servingLabel: '一个'),
          match(0, 2, count: double.infinity, servingLabel: '一包'),
          match(1, 3, count: double.nan, servingLabel: '一包'),
        ],
        itemCount: 2,
        foods: foods,
      );
      expect(result, hasLength(4));
      for (final LabelMatch cleaned in result) {
        expect(cleaned.count, isNull);
        expect(cleaned.servingLabel, isNull);
      }
    });

    test('keeps a valid count and a serving the food really records', () {
      const LabelMatch raw = LabelMatch(
        itemIndex: 0,
        foodIndex: 0,
        count: 2,
        servingLabel: '一包',
      );
      final List<LabelMatch> result = normalizeLabelMatches(
        matches: <LabelMatch>[raw],
        itemCount: 1,
        foods: foods,
      );
      expect(result.single, raw);
      expect(result.single.count, 2);
      expect(result.single.servingLabel, '一包');
    });

    test('clears a serving label the food does not record but keeps count', () {
      final List<LabelMatch> result = normalizeLabelMatches(
        matches: <LabelMatch>[match(0, 0, count: 2, servingLabel: '一袋')],
        itemCount: 1,
        foods: foods,
      );
      expect(result.single.count, 2);
      expect(result.single.servingLabel, isNull);
    });

    test('matches the serving label after whitespace folding', () {
      // The recorded label itself carries an inner space; the model may return
      // extra whitespace around/inside it.
      final Food spaced = food('一块豆腐', notes: '一 块 200 g');
      final List<LabelMatch> result = normalizeLabelMatches(
        matches: <LabelMatch>[match(0, 0, count: 2, servingLabel: ' 一  块 ')],
        itemCount: 1,
        foods: <Food>[spaced],
      );
      expect(result.single.servingLabel, '一 块');
      expect(result.single.count, 2);
    });

    test('validates servings against a structured serving list', () {
      final Food boxed = food(
        '辛拉面',
        servings: const <FoodServing>[
          FoodServing(label: '一袋', amount: 120, unit: 'g'),
        ],
      );
      final List<LabelMatch> kept = normalizeLabelMatches(
        matches: <LabelMatch>[match(0, 0, count: 2, servingLabel: '一袋')],
        itemCount: 1,
        foods: <Food>[boxed],
      );
      expect(kept.single.servingLabel, '一袋');
      expect(kept.single.count, 2);

      // A structured list supersedes the legacy notes serving: the old label
      // is no longer recognised.
      final Food superseded = food(
        '辛拉面',
        notes: '一包 45 g',
        servings: const <FoodServing>[
          FoodServing(label: '一袋', amount: 120, unit: 'g'),
        ],
      );
      final List<LabelMatch> cleared = normalizeLabelMatches(
        matches: <LabelMatch>[match(0, 0, count: 2, servingLabel: '一包')],
        itemCount: 1,
        foods: <Food>[superseded],
      );
      expect(cleared.single.count, 2);
      expect(cleared.single.servingLabel, isNull);
    });

    test('clears a blank serving label', () {
      final List<LabelMatch> result = normalizeLabelMatches(
        matches: <LabelMatch>[match(0, 0, servingLabel: ' \n ')],
        itemCount: 1,
        foods: foods,
      );
      expect(result.single.servingLabel, isNull);
    });

    test('keeps a count with no serving (grams stay undecided)', () {
      final List<LabelMatch> result = normalizeLabelMatches(
        matches: <LabelMatch>[match(0, 0, count: 1.5)],
        itemCount: 1,
        foods: foods,
      );
      expect(result.single.count, 1.5);
      expect(result.single.servingLabel, isNull);
    });

    test('returns nothing for empty or impossible inputs', () {
      expect(
        normalizeLabelMatches(
          matches: <LabelMatch>[],
          itemCount: 1,
          foods: foods,
        ),
        isEmpty,
      );
      expect(
        normalizeLabelMatches(
          matches: <LabelMatch>[match(0, 0)],
          itemCount: 0,
          foods: foods,
        ),
        isEmpty,
      );
      expect(
        normalizeLabelMatches(
          matches: <LabelMatch>[match(0, 0)],
          itemCount: 1,
          foods: const <Food>[],
        ),
        isEmpty,
      );
      expect(
        normalizeLabelMatches(
          matches: <LabelMatch>[match(0, 0)],
          itemCount: 1,
          foods: foods,
          maxPerItem: 0,
        ),
        isEmpty,
      );
    });

    test('returns an unmodifiable list', () {
      final List<LabelMatch> result = normalizeLabelMatches(
        matches: <LabelMatch>[match(0, 0)],
        itemCount: 1,
        foods: foods,
      );
      expect(() => result.add(match(0, 1)), throwsUnsupportedError);
    });
  });

  group('decideLabelApply', () {
    /// A label whose per-100 g energy is [kcal]; may carry a serving and status.
    Food labelFood({
      int? kcal = 120,
      String? notes,
      List<FoodServing> servings = const <FoodServing>[],
      FoodStatus status = FoodStatus.active,
    }) {
      return Food(
        id: 'food-label',
        name: '辛拉面',
        notes: notes,
        servings: servings,
        status: status,
        source: FoodSource.label,
        kcal: kcal,
      );
    }

    test('auto-applies a plausible match without touching grams', () {
      final LabelApplyDecision decision = decideLabelApply(
        item: aiItem(grams: 100, kcal: 120),
        food: labelFood(kcal: 120),
        match: match(0, 0),
        userEdited: false,
        hasChosenFood: false,
        linkRejected: false,
      );
      expect(decision.action, LabelApplyAction.autoApply);
      expect(decision.reason, LabelApplyReason.ok);
      expect(decision.grams, isNull);
      expect(decision.isAutoApply, isTrue);
    });

    test('derives grams from count × the recorded serving', () {
      final LabelApplyDecision decision = decideLabelApply(
        item: aiItem(),
        food: labelFood(notes: '一包 120 g'),
        match: match(0, 0, count: 2, servingLabel: '一包'),
        userEdited: false,
        hasChosenFood: false,
        linkRejected: false,
      );
      expect(decision.isAutoApply, isTrue);
      expect(decision.grams, 240);
    });

    test('derives grams from a structured serving', () {
      final LabelApplyDecision decision = decideLabelApply(
        item: aiItem(),
        food: labelFood(
          servings: const <FoodServing>[
            FoodServing(label: '一袋', amount: 120, unit: 'g'),
          ],
        ),
        match: match(0, 0, count: 2, servingLabel: '一袋'),
        userEdited: false,
        hasChosenFood: false,
        linkRejected: false,
      );
      expect(decision.isAutoApply, isTrue);
      expect(decision.grams, 240);
    });

    test('a structured serving supersedes the legacy notes serving', () {
      final Food food = labelFood(
        notes: '一包 45 g',
        servings: const <FoodServing>[
          FoodServing(label: '一袋', amount: 120, unit: 'g'),
        ],
      );

      final LabelApplyDecision legacy = decideLabelApply(
        item: aiItem(),
        food: food,
        match: match(0, 0, count: 2, servingLabel: '一包'),
        userEdited: false,
        hasChosenFood: false,
        linkRejected: false,
      );
      expect(legacy.isAutoApply, isTrue);
      expect(legacy.grams, isNull);

      final LabelApplyDecision structured = decideLabelApply(
        item: aiItem(),
        food: food,
        match: match(0, 0, count: 2, servingLabel: '一袋'),
        userEdited: false,
        hasChosenFood: false,
        linkRejected: false,
      );
      expect(structured.grams, 240);
    });

    test('supports a fractional count (half a box)', () {
      final LabelApplyDecision decision = decideLabelApply(
        item: aiItem(),
        food: labelFood(notes: '一盒 200 g'),
        match: match(0, 0, count: 0.5, servingLabel: '一盒'),
        userEdited: false,
        hasChosenFood: false,
        linkRejected: false,
      );
      expect(decision.grams, 100);
    });

    test('treats an ml serving as 1 ml ≈ 1 g', () {
      final LabelApplyDecision decision = decideLabelApply(
        item: aiItem(),
        food: labelFood(notes: '一包 250 ml'),
        match: match(0, 0, count: 2, servingLabel: '一包'),
        userEdited: false,
        hasChosenFood: false,
        linkRejected: false,
      );
      expect(decision.grams, 500);
    });

    test('keeps grams null when only a count came back', () {
      final LabelApplyDecision decision = decideLabelApply(
        item: aiItem(),
        food: labelFood(notes: '一包 120 g'),
        match: match(0, 0, count: 2),
        userEdited: false,
        hasChosenFood: false,
        linkRejected: false,
      );
      expect(decision.isAutoApply, isTrue);
      expect(decision.grams, isNull);
    });

    test('keeps grams null when the serving label is not recorded', () {
      final LabelApplyDecision decision = decideLabelApply(
        item: aiItem(),
        food: labelFood(notes: '一包 120 g'),
        match: match(0, 0, count: 2, servingLabel: '一袋'),
        userEdited: false,
        hasChosenFood: false,
        linkRejected: false,
      );
      expect(decision.isAutoApply, isTrue);
      expect(decision.grams, isNull);
    });

    test('folds whitespace in the serving label before comparing', () {
      // The recorded label carries an inner space; the model's copy of it may
      // add extra spaces around or inside it.
      final LabelApplyDecision decision = decideLabelApply(
        item: aiItem(),
        food: labelFood(notes: '一 包 120 g'),
        match: match(0, 0, count: 2, servingLabel: ' 一  包 '),
        userEdited: false,
        hasChosenFood: false,
        linkRejected: false,
      );
      expect(decision.grams, 240);
    });

    test('never auto-applies a row that already has a chosen food', () {
      final LabelApplyDecision decision = decideLabelApply(
        item: aiItem(),
        food: labelFood(notes: '一包 120 g'),
        match: match(0, 0, count: 1, servingLabel: '一包'),
        userEdited: false,
        hasChosenFood: true,
        linkRejected: false,
      );
      expect(decision.action, LabelApplyAction.suggestOnly);
      expect(decision.reason, LabelApplyReason.alreadyChosen);
      expect(decision.grams, isNull);
      expect(decision.isAutoApply, isFalse);
    });

    test('never auto-applies a user-edited row', () {
      final LabelApplyDecision decision = decideLabelApply(
        item: aiItem(),
        food: labelFood(notes: '一包 120 g'),
        match: match(0, 0, count: 1, servingLabel: '一包'),
        userEdited: true,
        hasChosenFood: false,
        linkRejected: false,
      );
      expect(decision.reason, LabelApplyReason.userEdited);
      expect(decision.grams, isNull);
    });

    test('never auto-applies a rejected row again', () {
      final LabelApplyDecision decision = decideLabelApply(
        item: aiItem(),
        food: labelFood(notes: '一包 120 g'),
        match: match(0, 0, count: 1, servingLabel: '一包'),
        userEdited: false,
        hasChosenFood: false,
        linkRejected: true,
      );
      expect(decision.reason, LabelApplyReason.linkRejected);
    });

    test('never auto-applies an archived food: it is only suggested', () {
      final LabelApplyDecision decision = decideLabelApply(
        item: aiItem(),
        food: labelFood(notes: '一包 120 g', status: FoodStatus.archived),
        match: match(0, 0, count: 1, servingLabel: '一包'),
        userEdited: false,
        hasChosenFood: false,
        linkRejected: false,
      );
      expect(decision.action, LabelApplyAction.suggestOnly);
      expect(decision.reason, LabelApplyReason.archived);
      expect(decision.grams, isNull);
      expect(decision.isAutoApply, isFalse);
    });

    test(
      'archived is a property of the candidate, so it wins over row state',
      () {
        expect(
          decideLabelApply(
            item: aiItem(),
            food: labelFood(status: FoodStatus.archived),
            match: match(0, 0),
            userEdited: true,
            hasChosenFood: true,
            linkRejected: true,
          ).reason,
          LabelApplyReason.archived,
        );
      },
    );
    test('reports the row-state reason by precedence', () {
      expect(
        decideLabelApply(
          item: aiItem(),
          food: labelFood(),
          match: match(0, 0),
          userEdited: true,
          hasChosenFood: true,
          linkRejected: true,
        ).reason,
        LabelApplyReason.alreadyChosen,
      );
      expect(
        decideLabelApply(
          item: aiItem(),
          food: labelFood(),
          match: match(0, 0),
          userEdited: true,
          hasChosenFood: false,
          linkRejected: true,
        ).reason,
        LabelApplyReason.userEdited,
      );
    });

    test('rejects a label whose energy is far below the AI estimate', () {
      // AI says 120 kcal / 100 g; a 30 kcal / 100 g label is 0.25× → wrong food.
      final LabelApplyDecision decision = decideLabelApply(
        item: aiItem(grams: 100, kcal: 120),
        food: labelFood(kcal: 30, notes: '一包 120 g'),
        match: match(0, 0, count: 1, servingLabel: '一包'),
        userEdited: false,
        hasChosenFood: false,
        linkRejected: false,
      );
      expect(decision.action, LabelApplyAction.suggestOnly);
      expect(decision.reason, LabelApplyReason.implausibleNutrients);
      expect(decision.grams, isNull);
    });

    test('rejects a label whose energy is far above the AI estimate', () {
      // 480 vs 120 kcal / 100 g is 4× → wrong food.
      final LabelApplyDecision decision = decideLabelApply(
        item: aiItem(grams: 100, kcal: 120),
        food: labelFood(kcal: 480),
        match: match(0, 0),
        userEdited: false,
        hasChosenFood: false,
        linkRejected: false,
      );
      expect(decision.reason, LabelApplyReason.implausibleNutrients);
    });

    test('accepts the inclusive 0.3×–3.3× plausibility band', () {
      expect(
        decideLabelApply(
          item: aiItem(grams: 100, kcal: 120),
          food: labelFood(kcal: 36),
          match: match(0, 0),
          userEdited: false,
          hasChosenFood: false,
          linkRejected: false,
        ).isAutoApply,
        isTrue,
        reason: '0.3× is inside the band',
      );
      expect(
        decideLabelApply(
          item: aiItem(grams: 100, kcal: 120),
          food: labelFood(kcal: 396),
          match: match(0, 0),
          userEdited: false,
          hasChosenFood: false,
          linkRejected: false,
        ).isAutoApply,
        isTrue,
        reason: '3.3× is inside the band',
      );
    });

    test('skips the plausibility gate when the AI numbers are unusable', () {
      for (final MealItem item in <MealItem>[
        aiItem(grams: 0, kcal: 120),
        aiItem(grams: 100, kcal: 0),
      ]) {
        expect(
          decideLabelApply(
            item: item,
            food: labelFood(kcal: 1000),
            match: match(0, 0),
            userEdited: false,
            hasChosenFood: false,
            linkRejected: false,
          ).isAutoApply,
          isTrue,
        );
      }
    });

    test('skips the plausibility gate when the label has no usable kcal', () {
      for (final Food food in <Food>[
        labelFood(kcal: null),
        labelFood(kcal: 0),
      ]) {
        expect(
          decideLabelApply(
            item: aiItem(),
            food: food,
            match: match(0, 0),
            userEdited: false,
            hasChosenFood: false,
            linkRejected: false,
          ).isAutoApply,
          isTrue,
        );
      }
    });

    test('value equality covers action, reason and grams', () {
      const LabelApplyDecision a = LabelApplyDecision(
        action: LabelApplyAction.autoApply,
        reason: LabelApplyReason.ok,
        grams: 240,
      );
      const LabelApplyDecision b = LabelApplyDecision(
        action: LabelApplyAction.autoApply,
        reason: LabelApplyReason.ok,
        grams: 240,
      );
      const LabelApplyDecision c = LabelApplyDecision(
        action: LabelApplyAction.autoApply,
        reason: LabelApplyReason.ok,
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
    });
  });

  group('parseLocalQuantity', () {
    test('parses the single Chinese/Arabic portion the user wrote', () {
      expect(
        parseLocalQuantity('两片emmental 奶酪片'),
        const LocalQuantity(count: 2, unit: '片'),
      );
      expect(
        parseLocalQuantity('2片奶酪'),
        const LocalQuantity(count: 2, unit: '片'),
      );
      expect(
        parseLocalQuantity('半盒牛奶'),
        const LocalQuantity(count: 0.5, unit: '盒'),
      );
      expect(
        parseLocalQuantity('十二片饼干'),
        const LocalQuantity(count: 12, unit: '片'),
      );
      expect(
        parseLocalQuantity('两份米饭'),
        const LocalQuantity(count: 2, unit: '份'),
      );
    });

    test('refuses ambiguous or non-portion texts', () {
      expect(parseLocalQuantity('两个鸡蛋一碗米饭'), isNull);
      expect(parseLocalQuantity('午饭'), isNull);
      expect(parseLocalQuantity('约150克'), isNull);
      expect(parseLocalQuantity(''), isNull);
    });

    test('looks the serving up by the user unit, not by amount', () {
      final Food cheese = food(
        'Emmental 奶酪片',
        servings: <FoodServing>[
          const FoodServing(label: '一片', amount: 25, unit: 'g'),
          const FoodServing(label: '一包', amount: 70, unit: 'g'),
        ],
      );
      expect(servingForUnit(cheese, '片')?.label, '一片');
      expect(servingForUnit(cheese, '碗'), isNull);
      expect(
        servingGramsForQuantity(
          cheese,
          const LocalQuantity(count: 2, unit: '片'),
        ),
        50,
      );
      expect(
        servingGramsForQuantity(
          cheese,
          const LocalQuantity(count: 1, unit: '碗'),
        ),
        isNull,
      );
    });
  });

  group('group servings (「三块 21 g」)', () {
    // A serving label with its own numeral is a GROUP: 「三块 21 g」 means
    // three pieces weigh 21 g, so the user's count multiplies the PER-UNIT
    // grams — the old `count × amount` read wrote 3× too much, auto-applied.
    final Food haw = food(
      '山楂糕',
      servings: <FoodServing>[
        const FoodServing(label: '三块', amount: 21, unit: 'g'),
      ],
    );
    final Food arabic = food(
      '果丹皮',
      servings: <FoodServing>[
        const FoodServing(label: '3块', amount: 60, unit: 'g'),
      ],
    );
    final Food halfBox = food(
      '牛奶',
      servings: <FoodServing>[
        const FoodServing(label: '半盒', amount: 50, unit: 'g'),
      ],
    );

    test('两块 × 三块 21 g → 14 g, not 42 g', () {
      expect(
        servingGramsForQuantity(haw, const LocalQuantity(count: 2, unit: '块')),
        14,
      );
    });

    test('Arabic group label: 两块 × 3块 60 g → 40 g, not 120 g', () {
      expect(
        servingGramsForQuantity(
          arabic,
          const LocalQuantity(count: 2, unit: '块'),
        ),
        40,
      );
    });

    test('一盒 × 半盒 50 g → 100 g', () {
      expect(
        servingGramsForQuantity(
          halfBox,
          const LocalQuantity(count: 1, unit: '盒'),
        ),
        100,
      );
    });

    test('bare-unit and 一-labels keep the old per-one semantics', () {
      final Food cheese = food(
        '奶酪',
        servings: <FoodServing>[
          const FoodServing(label: '一片', amount: 25, unit: 'g'),
          const FoodServing(label: '片', amount: 30, unit: 'g'),
        ],
      );
      expect(
        servingGramsForQuantity(
          cheese,
          const LocalQuantity(count: 2, unit: '片'),
        ),
        50,
      );
    });

    test(
      'model count × group label: 3 × 三块 21 g → 21 g (decideLabelApply)',
      () {
        final LabelApplyDecision decision = decideLabelApply(
          item: const MealItem(
            id: 'item-haw',
            name: '山楂糕',
            grams: 40,
            kcal: 100,
            carbG: 2,
            proteinG: 8,
            fatG: 8,
            saltG: 0.5,
            source: FoodSource.ai,
          ),
          food: haw,
          match: const LabelMatch(
            itemIndex: 0,
            foodIndex: 0,
            count: 3,
            servingLabel: '三块',
          ),
          userEdited: false,
          hasChosenFood: false,
          linkRejected: false,
          localQuantity: null,
        );
        expect(decision.action, LabelApplyAction.autoApply);
        expect(decision.grams, 21);
      },
    );
  });

  group('decideLabelApply · local quantity', () {
    Food cheese() => const Food(
      id: 'food-cheese',
      name: 'Emmental 奶酪片',
      servings: <FoodServing>[FoodServing(label: '一片', amount: 25, unit: 'g')],
      source: FoodSource.label,
      kcal: 251,
    );
    MealItem twoSlices() => const MealItem(
      id: 'item-cheese',
      name: 'Emmental 奶酪片',
      grams: 40,
      kcal: 100,
      carbG: 2,
      proteinG: 8,
      fatG: 8,
      saltG: 0.5,
      source: FoodSource.ai,
    );

    test('derives grams from the user unit when the model gave no count', () {
      final LabelApplyDecision decision = decideLabelApply(
        item: twoSlices(),
        food: cheese(),
        match: const LabelMatch(itemIndex: 0, foodIndex: 0),
        userEdited: false,
        hasChosenFood: false,
        linkRejected: false,
        localQuantity: const LocalQuantity(count: 2, unit: '片'),
      );
      expect(decision.action, LabelApplyAction.autoApply);
      expect(decision.reason, LabelApplyReason.ok);
      expect(decision.grams, 50);
    });

    test('rejects a serving whose unit contradicts the user text', () {
      final LabelApplyDecision decision = decideLabelApply(
        item: twoSlices(),
        food: cheese(),
        match: const LabelMatch(
          itemIndex: 0,
          foodIndex: 0,
          count: 2,
          servingLabel: '一包',
        ),
        userEdited: false,
        hasChosenFood: false,
        linkRejected: false,
        localQuantity: const LocalQuantity(count: 2, unit: '片'),
      );
      expect(decision.action, LabelApplyAction.suggestOnly);
      expect(decision.reason, LabelApplyReason.servingUnitMismatch);
      expect(decision.grams, isNull);
    });

    test('keeps the model path unchanged without a local quantity', () {
      final LabelApplyDecision decision = decideLabelApply(
        item: twoSlices(),
        food: cheese(),
        match: const LabelMatch(
          itemIndex: 0,
          foodIndex: 0,
          count: 2,
          servingLabel: '一片',
        ),
        userEdited: false,
        hasChosenFood: false,
        linkRejected: false,
      );
      expect(decision.action, LabelApplyAction.autoApply);
      expect(decision.grams, 50);
    });
  });

  group('serving_label echoed with its amount (live model behaviour)', () {
    Food cheese() => const Food(
      id: 'food-cheese',
      name: 'Emmental 奶酪片',
      servings: <FoodServing>[FoodServing(label: '一片', amount: 25, unit: 'g')],
      source: FoodSource.label,
      kcal: 251,
    );
    MealItem twoSlices() => const MealItem(
      id: 'item-cheese',
      name: 'Emmental 奶酪片',
      grams: 40,
      kcal: 100,
      carbG: 2,
      proteinG: 8,
      fatG: 8,
      saltG: 0.5,
      source: FoodSource.ai,
    );

    test('strips the echoed amount and keeps the count usable', () {
      final List<LabelMatch> normalized = normalizeLabelMatches(
        matches: <LabelMatch>[
          const LabelMatch(
            itemIndex: 0,
            foodIndex: 0,
            count: 2,
            servingLabel: '一片 25 g',
          ),
        ],
        itemCount: 1,
        foods: <Food>[cheese()],
      );
      expect(normalized.single.count, 2);
      expect(normalized.single.servingLabel, '一片');
    });

    test('and the decision then writes 2 × 25 g', () {
      final LabelApplyDecision decision = decideLabelApply(
        item: twoSlices(),
        food: cheese(),
        match: const LabelMatch(
          itemIndex: 0,
          foodIndex: 0,
          count: 2,
          servingLabel: '一片',
        ),
        userEdited: false,
        hasChosenFood: false,
        linkRejected: false,
      );
      expect(decision.grams, 50);
    });
  });
}
