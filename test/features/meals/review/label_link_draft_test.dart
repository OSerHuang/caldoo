/// ReviewItem auto-apply / undo contract for label linking (P1).
///
/// These are pure-Dart tests: the review screen's link call is covered by
/// `label_link_review_test.dart`, while this file pins the draft semantics —
/// what gets written, what is restored, and what must never be clobbered.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:caldoo/domain/models/models.dart';
import 'package:caldoo/features/meals/review/meal_review_draft.dart';

import '_fakes.dart';

const Food _labelRice = Food(
  id: 'food-label-rice',
  name: '米饭（标签）',
  source: FoodSource.label,
  kcal: 150,
  carbG: 30,
  proteinG: 3,
  fatG: 0.5,
  sodiumMg: 400,
);

void main() {
  group('applyLinkedFood', () {
    test('writes the label name, per-100 g nutrients and optional grams', () {
      final ReviewItem item = ReviewItem(base: riceItem());

      item.applyLinkedFood(_labelRice, name: _labelRice.name, grams: 150);

      expect(item.name, '米饭（标签）');
      expect(item.grams, 150);
      expect(item.hasChosenFood, isTrue);
      expect(item.chosenFood, same(_labelRice));
      expect(item.item.foodId, _labelRice.id);
      expect(item.item.source, FoodSource.label);
      // 150 kcal / 100 g x 150 g.
      expect(item.item.kcal, 225);
      expect(item.item.carbG, 45);
      // 400 mg sodium / 100 g -> 1.0 g salt / 100 g, at 150 g = 1.5 g.
      expect(item.item.saltG, closeTo(1.5, 1e-9));
      // An auto-apply is not a user edit and is undoable.
      expect(item.userEdited, isFalse);
      expect(item.autoAppliedLink, isTrue);
    });

    test('keeps the AI grams when no serving was resolved', () {
      final ReviewItem item = ReviewItem(base: riceItem());

      item.applyLinkedFood(_labelRice, name: _labelRice.name);

      expect(item.grams, 100);
      expect(item.item.kcal, 150);
      expect(item.autoAppliedLink, isTrue);
    });

    test('does not mark the row as user-edited', () {
      final ReviewItem item = ReviewItem(base: riceItem());

      item.applyLinkedFood(_labelRice, name: _labelRice.name);

      expect(item.userEdited, isFalse);
    });
  });

  group('undoLinkedFood', () {
    test('restores the AI name, grams and nutrients and rejects the link', () {
      final ReviewItem item = ReviewItem(base: riceItem());
      item.applyLinkedFood(_labelRice, name: _labelRice.name, grams: 200);

      item.undoLinkedFood();

      expect(item.name, '米饭');
      expect(item.grams, 100);
      expect(item.hasChosenFood, isFalse);
      expect(item.item.kcal, 120);
      expect(item.item.foodId, isNull);
      expect(item.autoAppliedLink, isFalse);
      expect(item.linkRejected, isTrue);
      // Undo is not a user edit either: a fresh analysis may link again.
      expect(item.userEdited, isFalse);
    });

    test('keeps a name the user typed after the auto-apply', () {
      final ReviewItem item = ReviewItem(base: riceItem());
      item.applyLinkedFood(_labelRice, name: _labelRice.name, grams: 200);

      item.editName('自己煮的米饭');
      item.undoLinkedFood();

      expect(item.name, '自己煮的米饭');
      expect(item.grams, 100);
    });

    test('keeps grams the user typed after the auto-apply', () {
      final ReviewItem item = ReviewItem(base: riceItem());
      item.applyLinkedFood(_labelRice, name: _labelRice.name, grams: 200);

      item.editGrams(180);
      item.undoLinkedFood();

      expect(item.grams, 180);
      expect(item.hasChosenFood, isFalse);
    });

    test('is a no-op on a row with no auto-applied link', () {
      final ReviewItem item = ReviewItem(base: riceItem());

      item.undoLinkedFood();

      expect(item.name, '米饭');
      expect(item.grams, 100);
      expect(item.hasChosenFood, isFalse);
      expect(item.userEdited, isFalse);
    });
  });

  group('manual choices', () {
    test('chooseFood drops the undo state (the user chose it)', () {
      final ReviewItem item = ReviewItem(base: riceItem());
      item.applyLinkedFood(_labelRice, name: _labelRice.name, grams: 200);

      item.chooseFood(_labelRice);

      expect(item.autoAppliedLink, isFalse);
      expect(item.hasChosenFood, isTrue);
    });

    test('adoptLinkedCandidate names the row and offers no undo', () {
      final ReviewItem item = ReviewItem(base: riceItem());

      item.adoptLinkedCandidate(_labelRice);

      expect(item.name, '米饭（标签）');
      expect(item.grams, 100);
      expect(item.hasChosenFood, isTrue);
      expect(item.autoAppliedLink, isFalse);
      expect(item.userEdited, isFalse);
    });

    test('clearFood drops the chosen food and the undo state', () {
      final ReviewItem item = ReviewItem(base: riceItem());
      item.applyLinkedFood(_labelRice, name: _labelRice.name, grams: 200);

      item.clearFood();

      // clearFood drops the label but keeps the grams the link wrote; the
      // proportional AI path then scales the estimate to those grams.
      expect(item.hasChosenFood, isFalse);
      expect(item.autoAppliedLink, isFalse);
      expect(item.grams, 200);
      expect(item.item.kcal, 240);
    });
  });

  group('userEdited', () {
    test('flips on a name, grams or nutrient edit', () {
      final ReviewItem byName = ReviewItem(base: riceItem());
      byName.editName('米饭');
      expect(byName.userEdited, isTrue);

      final ReviewItem byGrams = ReviewItem(base: riceItem());
      byGrams.editGrams(90);
      expect(byGrams.userEdited, isTrue);

      final ReviewItem byNutrient = ReviewItem(base: riceItem());
      byNutrient.editNutrient(ReviewNutrient.carbG, 40);
      expect(byNutrient.userEdited, isTrue);

      // Energy is edited through its own int-only entry point.
      final ReviewItem byKcal = ReviewItem(base: riceItem());
      byKcal.editKcal(130);
      expect(byKcal.userEdited, isTrue);
      expect(byKcal.item.kcal, 130);
    });
  });
}
