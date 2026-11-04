/// Regression tests for the 「两片 Emmental 奶酪片」 bug.
///
/// The analysis call never sees the saved-food library, so its grams is a
/// guess; the label link may either omit the serving count or pick the wrong
/// near-duplicate (the catalogue can hold both a `一片 25 g` and a
/// `一包 70 g` Emmental). These tests drive the real [MealReviewScreen] with
/// the user's two records and assert that the quantity written in the capture
/// text decides the grams:
///
/// * 两片 + 一片 25 g → 50 g, whichever candidate the model ranked first;
/// * a model answer that maps the two slices onto `一包 70 g` must never write
///   140 g — it is only offered as a candidate.
library;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'package:caldoo/ai/schemas/label_link.dart';
import 'package:caldoo/core/providers/app_providers.dart';
import 'package:caldoo/domain/models/models.dart';
import 'package:caldoo/features/meals/review/label_link_row.dart';
import 'package:caldoo/features/meals/review/label_linker.dart';
import 'package:caldoo/features/meals/review/meal_review_screen.dart';
import 'package:caldoo/features/meals/review/review_item_card.dart';

import '../../../data/repositories/fake_repositories.dart';
import '_fakes.dart';

const String userText = '两片emmental 奶酪片';

const Food colruyt = Food(
  id: 'food-colruyt',
  name: 'Emmental 奶酪片',
  brand: 'Colruyt',
  servings: <FoodServing>[FoodServing(label: '一片', amount: 25, unit: 'g')],
  source: FoodSource.label,
  kcal: 251,
  carbG: 8,
  proteinG: 19,
  fatG: 16,
  sodiumMg: 920,
);

const Food lidl = Food(
  id: 'food-lidl',
  name: 'Emmental奶酪',
  brand: 'Lidl',
  servings: <FoodServing>[FoodServing(label: '一包', amount: 70, unit: 'g')],
  source: FoodSource.label,
  kcal: 366,
  carbG: 0.5,
  proteinG: 27,
  fatG: 29,
  sodiumMg: 280,
);

MealItem cheeseItem() => const MealItem(
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

class FakeLinker {
  FakeLinker(this.build);

  final LabelLinkResult Function(List<Food> foods) build;

  Future<LabelLinkResult> call({
    required List<MealItem> items,
    required List<Food> foods,
    required String userText,
  }) async => build(foods);
}

int indexOf(List<Food> foods, String id) =>
    foods.indexWhere((Food f) => f.id == id);

Future<void> pumpReview(
  WidgetTester tester, {
  required FakeLinker linker,
  required List<Food> foods,
}) async {
  final FakeFoodRepository repo = FakeFoodRepository();
  for (final Food food in foods) {
    await repo.insertFood(food);
  }
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        mealRepositoryProvider.overrideWithValue(RecordingMealRepository()),
        foodRepositoryProvider.overrideWithValue(repo),
        reviewIdGeneratorProvider.overrideWithValue(() => 'blank'),
        connectivityProvider.overrideWith(
          (Ref ref) => Stream<List<ConnectivityResult>>.value(
            const <ConnectivityResult>[ConnectivityResult.wifi],
          ),
        ),
        labelLinkerProvider.overrideWithValue(linker.call),
      ],
      child: MaterialApp(
        home: MealReviewScreen(
          draft: AiMealDraft(items: <MealItem>[cheeseItem()]),
          meal: testMeal(),
          userText: userText,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

String field(WidgetTester tester, Key key) =>
    tester.widget<TextField>(find.byKey(key)).controller!.text;

void main() {
  testWidgets('两片 × 一片 25 g → 50 g (model count present)', (
    WidgetTester tester,
  ) async {
    await pumpReview(
      tester,
      foods: <Food>[colruyt, lidl],
      linker: FakeLinker(
        (List<Food> foods) => LabelLinkResult(
          matches: <LabelMatch>[
            LabelMatch(
              itemIndex: 0,
              foodIndex: indexOf(foods, colruyt.id),
              count: 2,
              servingLabel: '一片',
            ),
          ],
        ),
      ),
    );
    expect(field(tester, reviewGramsKey('item-cheese')), '50');
    expect(field(tester, reviewNameKey('item-cheese')), 'Emmental 奶酪片');
  });

  testWidgets('模型把两片套到一包 70 g：绝不写 140 g', (WidgetTester tester) async {
    await pumpReview(
      tester,
      foods: <Food>[colruyt, lidl],
      linker: FakeLinker(
        (List<Food> foods) => LabelLinkResult(
          matches: <LabelMatch>[
            LabelMatch(
              itemIndex: 0,
              foodIndex: indexOf(foods, lidl.id),
              count: 2,
              servingLabel: '一包',
            ),
          ],
        ),
      ),
    );
    expect(field(tester, reviewGramsKey('item-cheese')), '40');
    expect(field(tester, reviewNameKey('item-cheese')), 'Emmental 奶酪片');
    expect(
      find.byKey(labelLinkChipKey('item-cheese', lidl.id)),
      findsOneWidget,
    );
  });

  testWidgets('模型只给候选、不给 count：按原文 两片 补成 50 g', (WidgetTester tester) async {
    await pumpReview(
      tester,
      foods: <Food>[colruyt, lidl],
      linker: FakeLinker(
        (List<Food> foods) => LabelLinkResult(
          matches: <LabelMatch>[
            LabelMatch(itemIndex: 0, foodIndex: indexOf(foods, lidl.id)),
            LabelMatch(itemIndex: 0, foodIndex: indexOf(foods, colruyt.id)),
          ],
        ),
      ),
    );
    expect(field(tester, reviewGramsKey('item-cheese')), '50');
    expect(field(tester, reviewNameKey('item-cheese')), 'Emmental 奶酪片');
  });

  testWidgets('模型 top-1 是错误食物 + 错误份量：改选到 片 那份并算 50 g', (
    WidgetTester tester,
  ) async {
    await pumpReview(
      tester,
      foods: <Food>[colruyt, lidl],
      linker: FakeLinker(
        (List<Food> foods) => LabelLinkResult(
          matches: <LabelMatch>[
            LabelMatch(
              itemIndex: 0,
              foodIndex: indexOf(foods, lidl.id),
              count: 2,
              servingLabel: '一包',
            ),
            LabelMatch(itemIndex: 0, foodIndex: indexOf(foods, colruyt.id)),
          ],
        ),
      ),
    );
    expect(field(tester, reviewGramsKey('item-cheese')), '50');
    expect(field(tester, reviewNameKey('item-cheese')), 'Emmental 奶酪片');
  });

  testWidgets('serving_label 写成「一片 25 g」也按原文补成 50 g', (
    WidgetTester tester,
  ) async {
    await pumpReview(
      tester,
      foods: <Food>[colruyt, lidl],
      linker: FakeLinker(
        (List<Food> foods) => LabelLinkResult(
          matches: <LabelMatch>[
            LabelMatch(
              itemIndex: 0,
              foodIndex: indexOf(foods, colruyt.id),
              count: 2,
              servingLabel: '一片 25 g',
            ),
          ],
        ),
      ),
    );
    expect(field(tester, reviewGramsKey('item-cheese')), '50');
    expect(field(tester, reviewNameKey('item-cheese')), 'Emmental 奶酪片');
  });
}
