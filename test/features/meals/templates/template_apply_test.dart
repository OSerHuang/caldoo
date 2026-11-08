/// Pure-Dart tests for the template -> review mapping (`template_apply.dart`).
///
/// The rules under test: fresh item ids on every fill, and every nutrient /
/// provenance field (grams, macros, `source`, `foodId`, `confidence`) carried
/// through verbatim — a label-backed line must still be label-backed after a
/// template fill, or the review screen's grams semantics would change.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:caldoo/domain/models/models.dart';
import 'package:caldoo/features/meals/templates/template_apply.dart';

MealTemplate _template() => MealTemplate(
  id: 't1',
  name: '早餐标配',
  createdAt: DateTime(2026, 3, 4, 8),
  mealType: MealType.breakfast,
  items: const <MealItem>[
    MealItem(
      id: 'src-ai',
      name: '米饭',
      grams: 150,
      kcal: 174,
      carbG: 38.9,
      proteinG: 4.2,
      fatG: 0.6,
      saltG: 0.01,
      source: FoodSource.ai,
      confidence: 0.8,
    ),
    MealItem(
      id: 'src-label',
      foodId: 'f-bread',
      name: '全麦面包',
      grams: 80,
      kcal: 200,
      carbG: 36.2,
      proteinG: 7.6,
      fatG: 3,
      saltG: 0.8,
      source: FoodSource.label,
    ),
  ],
);

void main() {
  group('draftFromTemplate', () {
    test('re-issues fresh ids but keeps every value and provenance field', () {
      final AiMealDraft draft = draftFromTemplate(_template());

      expect(draft.items, hasLength(2));

      final MealItem ai = draft.items[0];
      expect(ai.id, isNot('src-ai'), reason: 'ids are always fresh');
      expect(ai.name, '米饭');
      expect(ai.grams, 150);
      expect(ai.kcal, 174);
      expect(ai.carbG, 38.9);
      expect(ai.proteinG, 4.2);
      expect(ai.fatG, 0.6);
      expect(ai.saltG, 0.01);
      expect(ai.source, FoodSource.ai);
      expect(ai.confidence, 0.8);
      expect(ai.foodId, isNull);

      final MealItem label = draft.items[1];
      expect(label.id, isNot('src-label'));
      expect(label.id, isNot(ai.id), reason: 'ids are unique within the fill');
      expect(label.name, '全麦面包');
      expect(label.grams, 80);
      expect(label.kcal, 200);
      expect(label.foodId, 'f-bread', reason: 'the label back-link survives');
      expect(label.source, FoodSource.label);
    });

    test('a supplied id generator drives the ids deterministically', () {
      var counter = 0;
      final AiMealDraft draft = draftFromTemplate(
        _template(),
        idGenerator: () => 'fresh-${counter++}',
      );

      expect(draft.items.map((MealItem item) => item.id), <String>[
        'fresh-0',
        'fresh-1',
      ]);
    });

    test('two fills never share ids', () {
      final AiMealDraft first = draftFromTemplate(_template());
      final AiMealDraft second = draftFromTemplate(_template());

      final Set<String> ids = <String>{
        for (final MealItem item in first.items) item.id,
        for (final MealItem item in second.items) item.id,
      };
      expect(ids, hasLength(4));
    });
  });

  group('MealTemplate.totalKcal', () {
    test('sums the whole-kcal energy over the item lines', () {
      expect(_template().totalKcal, 374);
    });

    test('an empty item list totals zero', () {
      expect(
        MealTemplate(
          id: 't-empty',
          name: '空',
          createdAt: DateTime(2026, 3, 4, 8),
          mealType: MealType.snack,
          items: const <MealItem>[],
        ).totalKcal,
        0,
      );
    });
  });
}
