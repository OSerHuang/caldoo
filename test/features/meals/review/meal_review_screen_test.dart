/// Task 19: AI review/edit screen widget tests.
///
/// Covers the plan's acceptance criteria directly:
/// * editing an item's grams 100 -> 150 scales that item's kcal / macros / salt
///   by exactly 1.5 AND the live meal totals update;
/// * removing an item updates the totals;
/// * saving passes the EDITED values to the repository (a recording fake);
/// * a label-backed item recomputes from per-100 g at the new grams;
/// * kcal is never derived from the 4/4/9 macro factors;
/// * a 0-item / unnamed meal is rejected (no save call);
/// * the AI-correction panel re-estimates with the capture photos + note,
///   replaces the draft, warns before overwriting edits, and keeps the draft
///   on failure / offline.
library;

import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:caldoo/ai/ai_client.dart' show Network;
import 'package:caldoo/ai/schemas/meal_analysis.dart' show MealAnalysis;
import 'package:caldoo/core/providers/app_providers.dart'
    show connectivityProvider, foodRepositoryProvider, mealRepositoryProvider;
import 'package:caldoo/core/units/display_units.dart';
import 'package:caldoo/domain/models/models.dart';
import 'package:caldoo/features/meals/capture/image_codec.dart'
    show PreparedPhoto;
import 'package:caldoo/features/meals/review/meal_review_draft.dart';
import 'package:caldoo/features/meals/review/meal_review_screen.dart';
import 'package:caldoo/features/meals/review/meal_revision.dart';
import 'package:caldoo/features/meals/review/review_item_card.dart';
import 'package:caldoo/features/meals/saved_foods/food_suggestion_list.dart';
import 'package:caldoo/features/meals/saved_foods/label_suggestion_banner.dart';
import 'package:caldoo/features/meals/saved_foods/saved_food_detail_screen.dart';

import '../../../data/repositories/fake_repositories.dart';
import '_fakes.dart';

Future<RecordingMealRepository> _pumpReview(
  WidgetTester tester, {
  required List<MealItem> items,
  Meal? meal,
  bool editing = false,
  String? warning,
  List<Food> foods = const <Food>[],
  List<PreparedPhoto> photos = const <PreparedPhoto>[],
  String userText = '',
  MealReviser? reviser,
  List<ConnectivityResult> connectivity = const <ConnectivityResult>[
    ConnectivityResult.wifi,
  ],
  DisplayUnits? units,
}) async {
  final FakeFoodRepository foodRepo = FakeFoodRepository();
  for (final Food food in foods) {
    await foodRepo.insertFood(food);
  }
  final RecordingMealRepository mealRepo = RecordingMealRepository();
  int blank = 0;
  final Widget app = MaterialApp(
    home: MealReviewScreen(
      draft: AiMealDraft(items: items, warning: warning),
      meal: meal ?? testMeal(),
      editing: editing,
      photos: photos,
      userText: userText,
    ),
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        mealRepositoryProvider.overrideWithValue(mealRepo),
        foodRepositoryProvider.overrideWithValue(foodRepo),
        reviewIdGeneratorProvider.overrideWithValue(() => 'blank-${blank++}'),
        connectivityProvider.overrideWith(
          (ref) => Stream<List<ConnectivityResult>>.value(connectivity),
        ),
        if (reviser != null) mealReviserProvider.overrideWithValue(reviser),
      ],
      child: units == null ? app : DisplayScope(units: units, child: app),
    ),
  );
  await tester.pumpAndSettle();
  return mealRepo;
}

/// Reads a field's current controller text (the displayed value).
String _field(WidgetTester tester, Key key) =>
    tester.widget<TextField>(find.byKey(key)).controller!.text;

/// Reads a `Text` by key.
String _value(WidgetTester tester, Key key) =>
    tester.widget<Text>(find.byKey(key)).data!;

/// Scrolls [key] into view (it may sit below the 600 px test viewport) and taps.
Future<void> _tapVisible(WidgetTester tester, Key key) async {
  final Finder finder = find.byKey(key);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'editing grams 100 -> 150 scales that item exactly 1.5x and updates totals',
    (WidgetTester tester) async {
      final MealItem rice = riceItem();
      final MealItem egg = eggItem();
      await _pumpReview(tester, items: <MealItem>[rice, egg]);

      // Baseline: the AI snapshot, untouched.
      expect(_field(tester, reviewKcalKey('item-rice')), '120');
      expect(_field(tester, reviewSaltKey('item-rice')), '0.3');
      expect(_value(tester, reviewTotalKcalKey), '190');
      expect(_value(tester, reviewTotalCarbKey), '9');
      expect(_value(tester, reviewTotalProteinKey), '13');
      expect(_value(tester, reviewTotalFatKey), '9');
      expect(_value(tester, reviewTotalSaltKey), '0.5');

      await tester.enterText(find.byKey(reviewGramsKey('item-rice')), '150');
      await tester.pump();

      // The edited item scales by exactly newGrams/oldGrams = 1.5.
      expect(_field(tester, reviewGramsKey('item-rice')), '150');
      expect(_field(tester, reviewKcalKey('item-rice')), '180');
      expect(_field(tester, reviewCarbKey('item-rice')), '12');
      expect(_field(tester, reviewProteinKey('item-rice')), '9');
      expect(_field(tester, reviewFatKey('item-rice')), '7.5');
      expect(_field(tester, reviewSaltKey('item-rice')), '0.45');

      // The other item is untouched, and the live totals reflect the scale.
      expect(_field(tester, reviewKcalKey('item-egg')), '70');
      expect(_field(tester, reviewGramsKey('item-egg')), '50');
      expect(_value(tester, reviewTotalKcalKey), '250');
      expect(_value(tester, reviewTotalProteinKey), '16');
      expect(_value(tester, reviewTotalSaltKey), '0.65');

      // Manual-QA channel: the measured 1.5x scale + totals in the output.
      debugPrint(
        'MEAL_REVIEW_QA grams=100->150 factor=1.5 '
        'item_kcal=${rice.kcal}->${rice.kcal * 1.5} '
        'item_protein=${rice.proteinG}->${rice.proteinG * 1.5} '
        'item_salt=${rice.saltG}->${rice.saltG * 1.5} '
        'total_kcal=190.0->${rice.kcal * 1.5 + egg.kcal} -> PASS',
      );
    },
  );

  testWidgets('a kJ + sodium preference switches only the read-only totals', (
    WidgetTester tester,
  ) async {
    await _pumpReview(
      tester,
      items: <MealItem>[riceItem(), eggItem()],
      units: const DisplayUnits(
        energy: EnergyDisplay.kj,
        salt: SaltDisplay.sodium,
      ),
    );

    // 190 kcal -> 794.96 -> 795 kJ; 0.5 g salt -> 200 mg sodium.
    expect(_value(tester, reviewTotalKcalKey), '795');
    expect(_value(tester, reviewTotalSaltKey), '200');
    expect(find.text('kJ'), findsOneWidget);
    expect(find.text('钠'), findsOneWidget);
    expect(find.text('mg'), findsOneWidget);
    expect(find.text('kcal'), findsNothing);

    // Data entry is deliberately canonical: whatever the display preference
    // says, the editable item fields keep kcal and salt grams.
    expect(_field(tester, reviewKcalKey('item-rice')), '120');
    expect(_field(tester, reviewSaltKey('item-rice')), '0.3');
    expect(find.text('热量 (kcal)'), findsNWidgets(2));
    expect(find.text('盐 (g)'), findsNWidgets(2));
  });

  testWidgets('removing an item updates the totals', (
    WidgetTester tester,
  ) async {
    await _pumpReview(tester, items: <MealItem>[riceItem(), eggItem()]);
    expect(_value(tester, reviewTotalKcalKey), '190');
    expect(_value(tester, reviewTotalProteinKey), '13');

    await _tapVisible(tester, reviewRemoveKey('item-egg'));

    expect(find.byKey(reviewKcalKey('item-egg')), findsNothing);
    expect(_value(tester, reviewTotalKcalKey), '120');
    expect(_value(tester, reviewTotalProteinKey), '6');
    expect(_value(tester, reviewTotalSaltKey), '0.3');
  });

  testWidgets('saving passes the EDITED values to the repository', (
    WidgetTester tester,
  ) async {
    final MealItem rice = riceItem();
    final RecordingMealRepository repo = await _pumpReview(
      tester,
      items: <MealItem>[rice],
    );

    await tester.enterText(find.byKey(reviewGramsKey('item-rice')), '150');
    await tester.pump();
    // A direct macro edit is also part of the edited payload.
    await tester.enterText(find.byKey(reviewProteinKey('item-rice')), '9.5');
    await tester.pump();

    await _tapVisible(tester, reviewSaveButtonKey);

    expect(repo.saves, hasLength(1));
    final RecordedMealSave saved = repo.saves.single;
    expect(saved.meal.id, 'meal-1');
    expect(saved.items, hasLength(1));
    final MealItem persisted = saved.items.single;
    expect(persisted.grams, 150);
    expect(persisted.kcal, rice.kcal * 1.5); // 180.0, scaled not snapshotted
    expect(persisted.saltG, rice.saltG * 1.5);
    expect(persisted.proteinG, 9.5); // the user's direct edit wins

    debugPrint(
      'MEAL_REVIEW_QA save_calls=${repo.saves.length} '
      'saved_grams=${persisted.grams} saved_kcal=${persisted.kcal} '
      'saved_protein=${persisted.proteinG} -> PASS',
    );
  });

  testWidgets('a label-backed item recomputes from per-100 g on grams edit', (
    WidgetTester tester,
  ) async {
    await _pumpReview(
      tester,
      items: <MealItem>[riceItem()],
      foods: <Food>[labelRice],
    );

    // The non-binding suggestion is offered; nothing changes until the tap.
    // The banner names the saved food and says why it was proposed.
    expect(find.byKey(LabelSuggestionBanner.containerKey), findsOneWidget);
    expect(find.text('库内已存该食物的标签：米饭，采用?'), findsOneWidget);
    expect(find.text('名称一致'), findsOneWidget);
    expect(_field(tester, reviewKcalKey('item-rice')), '120');
    await tester.tap(find.byKey(LabelSuggestionBanner.applyButtonKey));
    await tester.pumpAndSettle();

    // At the AI item's grams (100 g): per100g * 1.0.
    expect(_field(tester, reviewKcalKey('item-rice')), '150');

    // 150 g -> per100g * 1.5, exactly (recomputed, not frozen).
    await tester.enterText(find.byKey(reviewGramsKey('item-rice')), '150');
    await tester.pump();
    expect(_field(tester, reviewKcalKey('item-rice')), '225');
    expect(_field(tester, reviewProteinKey('item-rice')), '4.5');
    expect(_field(tester, reviewSaltKey('item-rice')), '1.5');
  });

  testWidgets('tapping the adopted saved food opens its per-100 g details', (
    WidgetTester tester,
  ) async {
    await _pumpReview(
      tester,
      items: <MealItem>[riceItem()],
      foods: <Food>[labelRice],
    );

    await tester.tap(find.byKey(LabelSuggestionBanner.applyButtonKey));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(reviewChosenFoodKey('item-rice')));
    await tester.pumpAndSettle();

    expect(find.byKey(savedFoodDetailScreenKey), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(savedFoodDetailNameKey)).data, '米饭');
    expect(find.text('基本信息'), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(savedFoodDetailBasisKey)).data,
      '每 100 g',
    );
    expect(
      tester.widget<Text>(find.byKey(savedFoodDetailValueKey('kcal'))).data,
      '150',
    );

    await tester.pageBack();
    await tester.pumpAndSettle();
    // The review row is still there and still backed by the label food.
    expect(find.byKey(reviewChosenFoodKey('item-rice')), findsOneWidget);
    expect(_field(tester, reviewKcalKey('item-rice')), '150');
  });

  testWidgets('a fuzzy name match offers the saved label without applying it', (
    WidgetTester tester,
  ) async {
    // The AI names the milk generically; the saved label is the real product.
    const MealItem genericMilk = MealItem(
      id: 'item-milk',
      name: '牛奶',
      grams: 100,
      kcal: 65,
      carbG: 4.8,
      proteinG: 3.3,
      fatG: 3.6,
      saltG: 0.05,
      source: FoodSource.ai,
    );
    const Food brandedMilk = Food(
      id: 'food-branded-milk',
      name: '全脂牛奶',
      brand: '光明',
      source: FoodSource.label,
      kcal: 68,
      carbG: 5,
      proteinG: 3.4,
      fatG: 3.8,
      sodiumMg: 52,
    );
    await _pumpReview(
      tester,
      items: <MealItem>[genericMilk],
      foods: <Food>[brandedMilk],
    );

    // Explicit name containment (牛奶 ⊂ 全脂牛奶) is enough to propose the
    // candidate, and the banner says why + which branded food it is.
    expect(find.byKey(LabelSuggestionBanner.containerKey), findsOneWidget);
    expect(find.text('库内相近：全脂牛奶（光明），采用?'), findsOneWidget);
    expect(find.text('名称相近'), findsOneWidget);
    // Non-binding: the AI values are still in effect.
    expect(_field(tester, reviewKcalKey('item-milk')), '65');

    await tester.tap(find.byKey(LabelSuggestionBanner.applyButtonKey));
    await tester.pumpAndSettle();

    // Now the label is authoritative: per100g * 1.0 at the AI grams.
    expect(_field(tester, reviewKcalKey('item-milk')), '68');
    expect(_field(tester, reviewProteinKey('item-milk')), '3.4');
    expect(find.byKey(reviewChosenFoodKey('item-milk')), findsOneWidget);
  });

  testWidgets('runner-up candidates are chips and each adopts its own label', (
    WidgetTester tester,
  ) async {
    const MealItem genericMilk = MealItem(
      id: 'item-milk',
      name: '牛奶',
      grams: 100,
      kcal: 65,
      carbG: 4.8,
      proteinG: 3.3,
      fatG: 3.6,
      saltG: 0.05,
      source: FoodSource.ai,
    );
    const Food unbranded = Food(
      id: 'food-whole-milk',
      name: '全脂牛奶',
      source: FoodSource.label,
      kcal: 68,
      carbG: 5,
      proteinG: 3.4,
      fatG: 3.8,
      sodiumMg: 52,
    );
    const Food mengniu = Food(
      id: 'food-mengniu',
      name: '纯牛奶',
      brand: '蒙牛',
      source: FoodSource.label,
      kcal: 62,
      carbG: 4.6,
      proteinG: 3.2,
      fatG: 3.5,
      sodiumMg: 60,
    );
    await _pumpReview(
      tester,
      items: <MealItem>[genericMilk],
      foods: <Food>[unbranded, mengniu],
    );

    // 纯牛奶 3 chars vs 牛奶 2 chars ranks above 全脂牛奶 4 chars: the shorter
    // containment is the stronger signal.
    expect(find.text('库内相近：纯牛奶（蒙牛），采用?'), findsOneWidget);
    expect(find.text('其他相近'), findsOneWidget);
    final Finder chip = find.byKey(foodSuggestionChipKey('food-whole-milk'));
    expect(chip, findsOneWidget);

    // Tapping a runner-up chip adopts THAT food, not the top banner's one.
    await tester.ensureVisible(chip);
    await tester.pumpAndSettle();
    await tester.tap(chip);
    await tester.pumpAndSettle();

    expect(find.byKey(reviewChosenFoodKey('item-milk')), findsOneWidget);
    expect(find.text('已采用：全脂牛奶'), findsOneWidget);
    expect(_field(tester, reviewKcalKey('item-milk')), '68');
  });

  testWidgets('kcal is never derived from the 4/4/9 macro factors', (
    WidgetTester tester,
  ) async {
    final MealItem rice = riceItem();
    final RecordingMealRepository repo = await _pumpReview(
      tester,
      items: <MealItem>[rice],
    );

    await _tapVisible(tester, reviewSaveButtonKey);

    final double fromMacros =
        4 * rice.carbG + 4 * rice.proteinG + 9 * rice.fatG; // 101.0
    final MealItem persisted = repo.saves.single.items.single;
    expect(persisted.kcal, rice.kcal); // 120.0, the AI value verbatim
    expect(persisted.kcal, isNot(fromMacros));
  });

  testWidgets('a 0-item meal is rejected and no save call is made', (
    WidgetTester tester,
  ) async {
    final RecordingMealRepository repo = await _pumpReview(
      tester,
      items: <MealItem>[],
      warning: 'AI 结果解析失败',
    );

    // The malformed draft still surfaces its banner + one editable blank row.
    expect(find.byKey(reviewWarningBannerKey), findsOneWidget);
    expect(find.byKey(reviewAddItemButtonKey), findsOneWidget);
    expect(find.byKey(reviewNameKey('blank-0')), findsOneWidget);

    // The blank row blocks saving.
    expect(
      tester.widget<FilledButton>(find.byKey(reviewSaveButtonKey)).onPressed,
      isNull,
    );
    await tester.tap(find.byKey(reviewSaveButtonKey), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(repo.saves, isEmpty);

    debugPrint(
      'MEAL_REVIEW_QA empty_meal_save_calls=${repo.saves.length} '
      'save_enabled=false -> PASS',
    );
  });

  test('a draft with no items is not saveable (pure state guard)', () {
    final MealReviewDraft draft = MealReviewDraft(items: const <MealItem>[]);
    expect(draft.isEmpty, isTrue);
    expect(draft.canSave, isFalse);
  });

  group('AI correction panel', () {
    testWidgets('is hidden when the review payload has no capture inputs', (
      WidgetTester tester,
    ) async {
      await _pumpReview(tester, items: <MealItem>[riceItem()]);
      expect(find.byKey(reviewRevisionCardKey), findsNothing);
    });

    testWidgets(
      'revision sends the photos, note and current items and replaces the '
      'draft',
      (WidgetTester tester) async {
        final RecordingMealReviser reviser = RecordingMealReviser(
          result: revisedRiceAnalysis(),
        );
        await _pumpReview(
          tester,
          items: <MealItem>[riceItem()],
          photos: <PreparedPhoto>[testPhoto],
          userText: '午饭',
          reviser: reviser.call,
        );

        expect(find.byKey(reviewRevisionCardKey), findsOneWidget);
        // A blank note cannot send a revision.
        expect(
          tester
              .widget<FilledButton>(find.byKey(reviewReviseButtonKey))
              .onPressed,
          isNull,
        );

        await tester.enterText(find.byKey(reviewCorrectionFieldKey), '米饭其实有两碗');
        await tester.pump();
        await _tapVisible(tester, reviewReviseButtonKey);

        expect(reviser.calls, hasLength(1));
        final RevisionCall call = reviser.calls.single;
        expect(call.photos, hasLength(1));
        expect(call.userText, '午饭');
        expect(call.correctionNote, '米饭其实有两碗');
        expect(call.currentItems.single.name, '米饭');
        expect(call.currentItems.single.grams, 100);

        // The whole draft was replaced: the old row is gone, the revised row
        // (fresh id from the id seam) shows the AI's new numbers.
        expect(find.byKey(reviewGramsKey('item-rice')), findsNothing);
        expect(_field(tester, reviewGramsKey('blank-0')), '200');
        expect(_field(tester, reviewKcalKey('blank-0')), '240');
        expect(_value(tester, reviewTotalKcalKey), '240');
        expect(_value(tester, reviewConfidenceKey('blank-0')), '置信 0.90');
        expect(find.text('AI 已按补充说明重新估算'), findsOneWidget);
      },
    );

    testWidgets('a failed revision keeps the draft and shows the error', (
      WidgetTester tester,
    ) async {
      final RecordingMealReviser reviser = RecordingMealReviser(
        error: const Network('down'),
      );
      await _pumpReview(
        tester,
        items: <MealItem>[riceItem()],
        photos: <PreparedPhoto>[testPhoto],
        reviser: reviser.call,
      );

      await tester.enterText(find.byKey(reviewCorrectionFieldKey), '米饭是两碗');
      await tester.pump();
      await _tapVisible(tester, reviewReviseButtonKey);

      expect(reviser.calls, hasLength(1));
      expect(find.byKey(reviewReviseErrorKey), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(reviewReviseErrorKey)).data,
        contains('网络不可用'),
      );
      // The AI-estimate draft is untouched and the retry is still available.
      expect(_field(tester, reviewGramsKey('item-rice')), '100');
      expect(
        tester
            .widget<FilledButton>(find.byKey(reviewReviseButtonKey))
            .onPressed,
        isNotNull,
      );
    });

    testWidgets('an edited draft asks before being overwritten', (
      WidgetTester tester,
    ) async {
      final RecordingMealReviser reviser = RecordingMealReviser(
        result: revisedRiceAnalysis(),
      );
      await _pumpReview(
        tester,
        items: <MealItem>[riceItem()],
        photos: <PreparedPhoto>[testPhoto],
        reviser: reviser.call,
      );

      // A manual edit makes the draft dirty.
      await tester.enterText(find.byKey(reviewGramsKey('item-rice')), '150');
      await tester.pump();
      await tester.enterText(find.byKey(reviewCorrectionFieldKey), '米饭是两碗');
      await tester.pump();

      await _tapVisible(tester, reviewReviseButtonKey);
      expect(find.byKey(reviewReviseDialogKey), findsOneWidget);
      expect(reviser.calls, isEmpty);

      // Cancel keeps everything, including the edit.
      await tester.tap(find.byKey(reviewReviseCancelKey));
      await tester.pumpAndSettle();
      expect(reviser.calls, isEmpty);
      expect(_field(tester, reviewGramsKey('item-rice')), '150');

      // Confirming sends the EDITED estimate as the revision baseline.
      await _tapVisible(tester, reviewReviseButtonKey);
      await tester.tap(find.byKey(reviewReviseConfirmKey));
      await tester.pumpAndSettle();
      expect(reviser.calls, hasLength(1));
      expect(reviser.calls.single.currentItems.single.grams, 150);
    });

    testWidgets('offline disables the revision button', (
      WidgetTester tester,
    ) async {
      await _pumpReview(
        tester,
        items: <MealItem>[riceItem()],
        photos: <PreparedPhoto>[testPhoto],
        connectivity: const <ConnectivityResult>[ConnectivityResult.none],
      );

      await tester.enterText(find.byKey(reviewCorrectionFieldKey), '米饭是两碗');
      await tester.pump();
      expect(find.byKey(reviewOfflineHintKey), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.byKey(reviewReviseButtonKey))
            .onPressed,
        isNull,
      );
    });

    testWidgets('a text-only payload can be revised without photos', (
      WidgetTester tester,
    ) async {
      final RecordingMealReviser reviser = RecordingMealReviser(
        result: revisedRiceAnalysis(),
      );
      await _pumpReview(
        tester,
        items: <MealItem>[riceItem()],
        userText: '两个鸡蛋一碗米饭',
        reviser: reviser.call,
      );

      // The panel is offered for a text-only meal and sends no image.
      expect(find.byKey(reviewRevisionCardKey), findsOneWidget);
      await tester.enterText(find.byKey(reviewCorrectionFieldKey), '米饭是两碗');
      await tester.pump();
      await _tapVisible(tester, reviewReviseButtonKey);

      expect(reviser.calls, hasLength(1));
      expect(reviser.calls.single.photos, isEmpty);
      expect(reviser.calls.single.userText, '两个鸡蛋一碗米饭');
      expect(reviser.calls.single.correctionNote, '米饭是两碗');
    });

    testWidgets('removing a row is also protected by the overwrite dialog', (
      WidgetTester tester,
    ) async {
      final RecordingMealReviser reviser = RecordingMealReviser(
        result: revisedRiceAnalysis(),
      );
      await _pumpReview(
        tester,
        items: <MealItem>[riceItem(), eggItem()],
        photos: <PreparedPhoto>[testPhoto],
        reviser: reviser.call,
      );

      await _tapVisible(tester, reviewRemoveKey('item-egg'));
      expect(find.byKey(reviewKcalKey('item-egg')), findsNothing);

      await tester.enterText(find.byKey(reviewCorrectionFieldKey), '重新估算');
      await tester.pump();
      await _tapVisible(tester, reviewReviseButtonKey);

      // A removal is a user edit: never overwritten silently.
      expect(find.byKey(reviewReviseDialogKey), findsOneWidget);
      expect(reviser.calls, isEmpty);
      await tester.tap(find.byKey(reviewReviseCancelKey));
      await tester.pumpAndSettle();
      expect(reviser.calls, isEmpty);
      expect(find.byKey(reviewKcalKey('item-egg')), findsNothing);
    });

    testWidgets('a non-AI revision failure never leaves the screen stuck', (
      WidgetTester tester,
    ) async {
      final RecordingMealReviser reviser = RecordingMealReviser(
        thrown: StateError('boom'),
      );
      await _pumpReview(
        tester,
        items: <MealItem>[riceItem()],
        photos: <PreparedPhoto>[testPhoto],
        reviser: reviser.call,
      );

      await tester.enterText(find.byKey(reviewCorrectionFieldKey), '米饭是两碗');
      await tester.pump();
      await _tapVisible(tester, reviewReviseButtonKey);

      // A generic, retryable message instead of a permanent spinner.
      expect(find.byKey(reviewReviseErrorKey), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(reviewReviseErrorKey)).data,
        '重新估算失败，请重试',
      );
      expect(
        tester
            .widget<FilledButton>(find.byKey(reviewReviseButtonKey))
            .onPressed,
        isNotNull,
      );
      // Saving stays available with the untouched draft.
      expect(
        tester.widget<FilledButton>(find.byKey(reviewSaveButtonKey)).onPressed,
        isNotNull,
      );
    });

    testWidgets('an in-flight revision locks the editors, keeps Save usable and cannot '
        'be sent twice', (WidgetTester tester) async {
      final Completer<MealAnalysis> gate = Completer<MealAnalysis>();
      final RecordingMealReviser reviser = RecordingMealReviser(gate: gate);
      await _pumpReview(
        tester,
        items: <MealItem>[riceItem()],
        photos: <PreparedPhoto>[testPhoto],
        reviser: reviser.call,
      );

      await tester.enterText(find.byKey(reviewCorrectionFieldKey), '米饭是两碗');
      await tester.pump();
      await tester.ensureVisible(find.byKey(reviewReviseButtonKey));
      await tester.pump();
      await tester.tap(find.byKey(reviewReviseButtonKey));
      await tester.pump();

      expect(reviser.calls, hasLength(1));
      // The note field is frozen and the button shows a spinner / is disabled.
      expect(
        tester.widget<TextField>(find.byKey(reviewCorrectionFieldKey)).enabled,
        isFalse,
      );
      expect(
        tester
            .widget<FilledButton>(find.byKey(reviewReviseButtonKey))
            .onPressed,
        isNull,
      );
      // A late tap cannot send a second request.
      await tester.tap(find.byKey(reviewReviseButtonKey), warnIfMissed: false);
      await tester.pump();
      expect(reviser.calls, hasLength(1));
      // Rows are absorbed, so no edit can be lost behind the swap.
      await tester.tap(
        find.byKey(reviewRemoveKey('item-rice')),
        warnIfMissed: false,
      );
      await tester.pump();
      expect(find.byKey(reviewKcalKey('item-rice')), findsOneWidget);
      // Saving never waits for the AI (draft G7).
      expect(
        tester.widget<FilledButton>(find.byKey(reviewSaveButtonKey)).onPressed,
        isNotNull,
      );

      gate.complete(revisedRiceAnalysis());
      await tester.pumpAndSettle();

      expect(find.byKey(reviewGramsKey('blank-0')), findsOneWidget);
      expect(find.byKey(reviewReviseErrorKey), findsNothing);
    });

    testWidgets('a revision finishing after unmount does not crash', (
      WidgetTester tester,
    ) async {
      final Completer<MealAnalysis> gate = Completer<MealAnalysis>();
      final RecordingMealReviser reviser = RecordingMealReviser(gate: gate);
      await _pumpReview(
        tester,
        items: <MealItem>[riceItem()],
        photos: <PreparedPhoto>[testPhoto],
        reviser: reviser.call,
      );

      await tester.enterText(find.byKey(reviewCorrectionFieldKey), '米饭是两碗');
      await tester.pump();
      await tester.ensureVisible(find.byKey(reviewReviseButtonKey));
      await tester.pump();
      await tester.tap(find.byKey(reviewReviseButtonKey));
      await tester.pump();
      expect(reviser.calls, hasLength(1));

      // Leave the screen while the call is still in flight.
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      gate.complete(revisedRiceAnalysis());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });

  group('edit mode (/meal/:id/edit — a saved meal reopened in this form)', () {
    testWidgets(
      'the banner names the stored values, no AI-correction panel renders and '
      'saving goes through updateMealWithItems',
      (WidgetTester tester) async {
        final RecordingMealRepository mealRepo = await _pumpReview(
          tester,
          items: <MealItem>[riceItem(grams: 200), eggItem()],
          editing: true,
        );

        // The edit banner replaces the AI-estimate banner.
        expect(find.text('AI 估算，可修改'), findsNothing);
        expect(find.text('已保存的记录，可直接修改'), findsOneWidget);
        // Without capture inputs the correction panel never renders.
        expect(find.byKey(reviewRevisionCardKey), findsNothing);
        // The stored rows are editable exactly like a fresh estimate.
        expect(_field(tester, reviewGramsKey('item-rice')), '200');

        await tester.enterText(find.byKey(reviewGramsKey('item-rice')), '300');
        await tester.pumpAndSettle();
        await _tapVisible(tester, reviewSaveButtonKey);

        // The edited record lands on the UPDATE path — never a second insert
        // of the same meal id.
        expect(mealRepo.saves, isEmpty);
        expect(mealRepo.updates, hasLength(1));
        expect(mealRepo.updates.single.meal.id, testMeal().id);
        final MealItem saved = mealRepo.updates.single.items.singleWhere(
          (MealItem item) => item.id == 'item-rice',
        );
        expect(saved.name, '米饭');
        expect(saved.grams, 300);
        // Proportional scaling from the stored values: 120 kcal * 1.5.
        expect(saved.kcal, 180);
      },
    );
  });
}
