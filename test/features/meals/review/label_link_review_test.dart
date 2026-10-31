/// Review-screen integration of the analyze-then-link call (P1).
///
/// The link call itself is faked (no socket): each test pins one contract of
/// `design/label-linking.md` §5 — auto-apply, undo, user-edit protection,
/// candidate chips, and the lexical-fallback boundary — plus the §17 rule that
/// a **photo** capture never matches the library at all.
library;

import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:caldoo/ai/ai_client.dart' show Network;
import 'package:caldoo/ai/schemas/label_link.dart';
import 'package:caldoo/core/providers/app_providers.dart'
    show connectivityProvider, foodRepositoryProvider, mealRepositoryProvider;
import 'package:caldoo/domain/models/models.dart';
import 'package:caldoo/features/meals/capture/image_codec.dart'
    show PreparedPhoto;
import 'package:caldoo/features/meals/review/label_link_row.dart';
import 'package:caldoo/features/meals/review/label_linker.dart';
import 'package:caldoo/features/meals/review/meal_review_screen.dart';
import 'package:caldoo/features/meals/review/meal_revision.dart'
    show MealReviser, mealReviserProvider;
import 'package:caldoo/features/meals/review/review_item_card.dart';
import 'package:caldoo/features/meals/saved_foods/label_suggestion_banner.dart';

import '../../../data/repositories/fake_repositories.dart';
import '_fakes.dart';

/// One recorded link call (inputs only; the answer is faked).
class LinkCall {
  const LinkCall({
    required this.items,
    required this.foods,
    required this.userText,
  });

  final List<MealItem> items;
  final List<Food> foods;
  final String userText;
}

/// A [LabelLinker] fake: records calls and replays a built answer, a failure or
/// a gated future.
class RecordingLabelLinker {
  RecordingLabelLinker({this.build, this.error, this.gate});

  /// Builds the answer from the foods the screen actually passed, so tests do
  /// not have to guess the catalogue order.
  final LabelLinkResult Function(List<Food> foods)? build;

  /// Per-call answer (by 0-based call index), taking precedence over [build].
  ///
  /// Used by the re-link tests: the first answer covers the whole draft, the
  /// second is the single-row re-link after a rename.
  LabelLinkResult Function(int callIndex, List<Food> foods)? buildForCall;

  /// When set, every call throws it (a typed [AiError] in practice).
  Object? error;

  /// When set, calls wait for this completer so a test can edit the row while
  /// the link is still in flight.
  Completer<LabelLinkResult>? gate;

  /// Every recorded call, in order.
  final List<LinkCall> calls = <LinkCall>[];

  Future<LabelLinkResult> call({
    required List<MealItem> items,
    required List<Food> foods,
    required String userText,
  }) async {
    calls.add(LinkCall(items: items, foods: foods, userText: userText));
    final int callIndex = calls.length - 1;
    final Completer<LabelLinkResult>? pending = gate;
    if (pending != null) {
      return pending.future;
    }
    final Object? failure = error;
    if (failure != null) {
      throw failure;
    }
    return buildForCall?.call(callIndex, foods) ??
        build?.call(foods) ??
        const LabelLinkResult(matches: <LabelMatch>[]);
  }
}

/// The label this suite auto-applies: a serving (一碗 200 g) and an alias, a
/// name distinct from the AI name, and plausible per-100 g numbers.
const Food _labelRice = Food(
  id: 'food-label-rice',
  name: '白米饭（一碗）',
  notes: '一碗 200 g；别名：米饭、白饭',
  source: FoodSource.label,
  kcal: 150,
  carbG: 30,
  proteinG: 3,
  fatG: 0.5,
  sodiumMg: 400,
);

/// A second candidate so the alternatives row is exercised.
const Food _labelBrownRice = Food(
  id: 'food-brown-rice',
  name: '糙米饭',
  notes: '一碗 180 g',
  source: FoodSource.label,
  kcal: 130,
  carbG: 28,
  proteinG: 3,
  fatG: 1,
  sodiumMg: 350,
);

/// A flat saved food whose name matches the AI row exactly — the lexical
/// fallback path.
const Food _plainRice = Food(
  id: 'food-plain-rice',
  name: '米饭',
  source: FoodSource.label,
  kcal: 140,
  carbG: 30,
  proteinG: 3,
  fatG: 0.3,
  sodiumMg: 300,
);

Future<void> _pumpReview(
  WidgetTester tester, {
  required List<MealItem> items,
  List<Food> foods = const <Food>[],
  List<PreparedPhoto> photos = const <PreparedPhoto>[],
  String userText = '午饭',
  MealReviser? reviser,
  required RecordingLabelLinker linker,
}) async {
  final FakeFoodRepository foodRepo = FakeFoodRepository();
  for (final Food food in foods) {
    await foodRepo.insertFood(food);
  }
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        mealRepositoryProvider.overrideWithValue(RecordingMealRepository()),
        foodRepositoryProvider.overrideWithValue(foodRepo),
        reviewIdGeneratorProvider.overrideWithValue(() => 'blank'),
        connectivityProvider.overrideWith(
          (ref) => Stream<List<ConnectivityResult>>.value(
            const <ConnectivityResult>[ConnectivityResult.wifi],
          ),
        ),
        labelLinkerProvider.overrideWithValue(linker.call),
        if (reviser != null) mealReviserProvider.overrideWithValue(reviser),
      ],
      child: MaterialApp(
        home: MealReviewScreen(
          draft: AiMealDraft(items: items),
          meal: testMeal(),
          photos: photos,
          userText: userText,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Reads a field's current controller text (the displayed value).
String _field(WidgetTester tester, Key key) =>
    tester.widget<TextField>(find.byKey(key)).controller!.text;

/// Scrolls [key] into view (it may sit below the 600 px test viewport) and taps.
Future<void> _tapVisible(WidgetTester tester, Key key) async {
  final Finder finder = find.byKey(key);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('auto-applies the top candidate: name, grams and nutrients', (
    WidgetTester tester,
  ) async {
    final RecordingLabelLinker linker = RecordingLabelLinker(
      build: (List<Food> foods) => LabelLinkResult(
        matches: <LabelMatch>[
          LabelMatch(
            itemIndex: 0,
            foodIndex: foods.indexWhere((Food f) => f.id == _labelRice.id),
            count: 1,
            servingLabel: '一碗',
          ),
          LabelMatch(
            itemIndex: 0,
            foodIndex: foods.indexWhere((Food f) => f.id == _labelBrownRice.id),
          ),
        ],
      ),
    );
    await _pumpReview(
      tester,
      items: <MealItem>[riceItem()],
      foods: <Food>[_labelRice, _labelBrownRice],
      linker: linker,
    );

    // The link was fed the analysis snapshot, the catalogue and the text.
    expect(linker.calls, hasLength(1));
    expect(linker.calls.single.userText, '午饭');
    expect(linker.calls.single.items.single.name, '米饭');
    expect(linker.calls.single.foods, hasLength(2));

    // Name / grams (1 x 一碗 200 g) / nutrients (150 kcal per 100 g) all moved.
    expect(_field(tester, reviewNameKey('item-rice')), '白米饭（一碗）');
    expect(_field(tester, reviewGramsKey('item-rice')), '200');
    expect(_field(tester, reviewKcalKey('item-rice')), '300');
    expect(find.byKey(labelLinkAppliedKey('item-rice')), findsOneWidget);
    expect(find.byKey(labelLinkUndoKey('item-rice')), findsOneWidget);
    // The runner-up stays one tap away.
    expect(
      find.byKey(labelLinkChipKey('item-rice', _labelBrownRice.id)),
      findsOneWidget,
    );
  });

  testWidgets('undo restores the AI name, grams and nutrients', (
    WidgetTester tester,
  ) async {
    final RecordingLabelLinker linker = RecordingLabelLinker(
      build: (List<Food> foods) => LabelLinkResult(
        matches: <LabelMatch>[
          LabelMatch(
            itemIndex: 0,
            foodIndex: foods.indexWhere((Food f) => f.id == _labelRice.id),
            count: 1,
            servingLabel: '一碗',
          ),
        ],
      ),
    );
    await _pumpReview(
      tester,
      items: <MealItem>[riceItem()],
      foods: <Food>[_labelRice],
      linker: linker,
    );
    expect(_field(tester, reviewKcalKey('item-rice')), '300');

    await _tapVisible(tester, labelLinkUndoKey('item-rice'));

    expect(_field(tester, reviewNameKey('item-rice')), '米饭');
    expect(_field(tester, reviewGramsKey('item-rice')), '100');
    expect(_field(tester, reviewKcalKey('item-rice')), '120');
    expect(find.byKey(labelLinkAppliedKey('item-rice')), findsNothing);
    // The link is rejected: a late duplicate must not re-apply it.
    expect(find.byKey(labelLinkUndoKey('item-rice')), findsNothing);
  });

  testWidgets('a row the user edited keeps the AI values and only gets chips', (
    WidgetTester tester,
  ) async {
    final Completer<LabelLinkResult> gate = Completer<LabelLinkResult>();
    final RecordingLabelLinker linker = RecordingLabelLinker(gate: gate);
    await _pumpReview(
      tester,
      items: <MealItem>[riceItem()],
      foods: <Food>[_labelRice],
      linker: linker,
    );

    await tester.enterText(find.byKey(reviewNameKey('item-rice')), '我的米饭');
    await tester.pump();

    gate.complete(
      const LabelLinkResult(
        matches: <LabelMatch>[
          LabelMatch(itemIndex: 0, foodIndex: 0, count: 1, servingLabel: '一碗'),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(_field(tester, reviewNameKey('item-rice')), '我的米饭');
    expect(_field(tester, reviewGramsKey('item-rice')), '100');
    expect(_field(tester, reviewKcalKey('item-rice')), '120');
    expect(find.byKey(labelLinkAppliedKey('item-rice')), findsNothing);
    expect(
      find.byKey(labelLinkChipKey('item-rice', _labelRice.id)),
      findsOneWidget,
    );
  });

  testWidgets('tapping a candidate applies it as a manual choice (no undo)', (
    WidgetTester tester,
  ) async {
    final RecordingLabelLinker linker = RecordingLabelLinker(
      gate: Completer<LabelLinkResult>(),
    );
    await _pumpReview(
      tester,
      items: <MealItem>[riceItem()],
      foods: <Food>[_labelRice],
      linker: linker,
    );
    // Edit first so the link may only suggest (the text must actually change,
    // otherwise TextField never fires onChanged).
    await tester.enterText(find.byKey(reviewNameKey('item-rice')), '我的米饭');
    await tester.pump();
    linker.gate!.complete(
      const LabelLinkResult(
        matches: <LabelMatch>[LabelMatch(itemIndex: 0, foodIndex: 0)],
      ),
    );
    await tester.pumpAndSettle();

    await _tapVisible(tester, labelLinkChipKey('item-rice', _labelRice.id));

    expect(_field(tester, reviewNameKey('item-rice')), '白米饭（一碗）');
    expect(_field(tester, reviewKcalKey('item-rice')), '150');
    expect(find.byKey(labelLinkAppliedKey('item-rice')), findsOneWidget);
    expect(find.byKey(labelLinkUndoKey('item-rice')), findsNothing);
  });

  testWidgets('a failed link keeps the lexical fallback suggestions', (
    WidgetTester tester,
  ) async {
    final RecordingLabelLinker linker = RecordingLabelLinker(
      error: const Network(),
    );
    await _pumpReview(
      tester,
      items: <MealItem>[riceItem()],
      foods: <Food>[_plainRice],
      linker: linker,
    );

    expect(linker.calls, hasLength(1));
    expect(find.byKey(LabelSuggestionBanner.containerKey), findsOneWidget);
    expect(find.byKey(labelLinkAppliedKey('item-rice')), findsNothing);
  });

  testWidgets('a successful empty answer shows no suggestions at all', (
    WidgetTester tester,
  ) async {
    final RecordingLabelLinker linker = RecordingLabelLinker();
    await _pumpReview(
      tester,
      items: <MealItem>[riceItem()],
      foods: <Food>[_plainRice],
      linker: linker,
    );

    expect(linker.calls, hasLength(1));
    expect(find.byKey(LabelSuggestionBanner.containerKey), findsNothing);
    expect(find.byKey(labelLinkAppliedKey('item-rice')), findsNothing);
  });

  testWidgets('a review payload with no capture input skips the link call', (
    WidgetTester tester,
  ) async {
    final RecordingLabelLinker linker = RecordingLabelLinker();
    await _pumpReview(
      tester,
      items: <MealItem>[riceItem()],
      foods: <Food>[_plainRice],
      userText: '',
      linker: linker,
    );

    expect(linker.calls, isEmpty);
    // The pre-link lexical suggestion is still offered.
    expect(find.byKey(LabelSuggestionBanner.containerKey), findsOneWidget);
  });

  // ---------------------------------------------------------------------------
  // §17: a photo capture is prediction-only and never touches the library.
  // ---------------------------------------------------------------------------

  testWidgets('a photo capture never calls the link and offers no matching', (
    WidgetTester tester,
  ) async {
    final RecordingLabelLinker linker = RecordingLabelLinker();
    await _pumpReview(
      tester,
      items: <MealItem>[riceItem()],
      photos: <PreparedPhoto>[testPhoto],
      // A saved food whose name matches the row exactly: the lexical fallback
      // would have suggested it before this rule.
      foods: <Food>[_plainRice],
      userText: '',
      linker: linker,
    );

    expect(linker.calls, isEmpty);
    expect(find.byKey(LabelSuggestionBanner.containerKey), findsNothing);
    expect(find.byKey(labelLinkAppliedKey('item-rice')), findsNothing);
    // Prediction-only: the AI estimate is untouched ...
    expect(_field(tester, reviewNameKey('item-rice')), '米饭');
    expect(_field(tester, reviewKcalKey('item-rice')), '120');
    // ... while the manual label escape hatch stays available.
    expect(find.byIcon(Icons.bookmark_add_outlined), findsOneWidget);
  });

  testWidgets('a photo capture with typed text still never links', (
    WidgetTester tester,
  ) async {
    final RecordingLabelLinker linker = RecordingLabelLinker();
    await _pumpReview(
      tester,
      items: <MealItem>[riceItem()],
      photos: <PreparedPhoto>[testPhoto],
      foods: <Food>[_plainRice],
      userText: '一碗米饭',
      linker: linker,
    );

    expect(linker.calls, isEmpty);
    expect(find.byKey(LabelSuggestionBanner.containerKey), findsNothing);
    expect(find.byKey(labelLinkAppliedKey('item-rice')), findsNothing);
  });

  testWidgets('a photo capture does not re-link after a rename', (
    WidgetTester tester,
  ) async {
    final RecordingLabelLinker linker = RecordingLabelLinker();
    await _pumpReview(
      tester,
      items: <MealItem>[riceItem()],
      photos: <PreparedPhoto>[testPhoto],
      foods: <Food>[_labelRice],
      linker: linker,
    );

    await tester.enterText(find.byKey(reviewNameKey('item-rice')), '白米饭');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pumpAndSettle();

    expect(linker.calls, isEmpty);
    expect(
      find.byKey(labelLinkChipKey('item-rice', _labelRice.id)),
      findsNothing,
    );
    // Not just no chip: no lexical banner either — a photo capture shows no
    // matching surface at all.
    expect(find.byKey(LabelSuggestionBanner.containerKey), findsNothing);
  });

  testWidgets('a photo capture revision does not restart the link call', (
    WidgetTester tester,
  ) async {
    final RecordingLabelLinker linker = RecordingLabelLinker();
    final RecordingMealReviser reviser = RecordingMealReviser(
      result: revisedRiceAnalysis(),
    );
    await _pumpReview(
      tester,
      items: <MealItem>[riceItem()],
      photos: <PreparedPhoto>[testPhoto],
      foods: <Food>[_labelRice],
      reviser: reviser.call,
      linker: linker,
    );

    await tester.enterText(find.byKey(reviewCorrectionFieldKey), '米饭是两碗');
    await tester.pump();
    await _tapVisible(tester, reviewReviseButtonKey);

    expect(reviser.calls, hasLength(1));
    // The revision replaces the draft, but a photo capture still never matches.
    expect(linker.calls, isEmpty);
    expect(find.byKey(LabelSuggestionBanner.containerKey), findsNothing);
    expect(find.byKey(labelLinkAppliedKey('item-rice')), findsNothing);
  });

  testWidgets('a renamed row re-links after the debounce and refreshes chips', (
    WidgetTester tester,
  ) async {
    final RecordingLabelLinker linker = RecordingLabelLinker();
    linker.buildForCall = (int callIndex, List<Food> foods) {
      if (callIndex == 0) {
        return const LabelLinkResult(matches: <LabelMatch>[]);
      }
      return LabelLinkResult(
        matches: <LabelMatch>[
          LabelMatch(
            itemIndex: 0,
            foodIndex: foods.indexWhere((Food f) => f.id == _labelRice.id),
          ),
        ],
      );
    };
    await _pumpReview(
      tester,
      items: <MealItem>[riceItem()],
      foods: <Food>[_labelRice],
      linker: linker,
    );
    // Nothing matched the AI name, so no row block is shown.
    expect(linker.calls, hasLength(1));
    expect(
      find.byKey(labelLinkChipKey('item-rice', _labelRice.id)),
      findsNothing,
    );

    await tester.enterText(find.byKey(reviewNameKey('item-rice')), '白米饭');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 750));
    await tester.pumpAndSettle();

    expect(linker.calls, hasLength(2));
    expect(linker.calls.last.items.single.name, '白米饭');
    expect(linker.calls.last.foods, hasLength(1));
    expect(
      find.byKey(labelLinkChipKey('item-rice', _labelRice.id)),
      findsOneWidget,
    );
  });

  testWidgets('rapid renames debounce into a single re-link call', (
    WidgetTester tester,
  ) async {
    final RecordingLabelLinker linker = RecordingLabelLinker();
    await _pumpReview(
      tester,
      items: <MealItem>[riceItem()],
      foods: <Food>[_labelRice],
      linker: linker,
    );
    expect(linker.calls, hasLength(1));

    await tester.enterText(find.byKey(reviewNameKey('item-rice')), '白');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(find.byKey(reviewNameKey('item-rice')), '白米饭');
    await tester.pump(const Duration(milliseconds: 750));
    await tester.pumpAndSettle();

    expect(linker.calls, hasLength(2), reason: 'one debounced re-link');
    expect(linker.calls.last.items.single.name, '白米饭');
  });

  testWidgets('a row with an applied label never re-links after a rename', (
    WidgetTester tester,
  ) async {
    final RecordingLabelLinker linker = RecordingLabelLinker(
      build: (List<Food> foods) => LabelLinkResult(
        matches: <LabelMatch>[
          LabelMatch(
            itemIndex: 0,
            foodIndex: foods.indexWhere((Food f) => f.id == _labelRice.id),
          ),
        ],
      ),
    );
    await _pumpReview(
      tester,
      items: <MealItem>[riceItem()],
      foods: <Food>[_labelRice],
      linker: linker,
    );
    expect(find.byKey(labelLinkAppliedKey('item-rice')), findsOneWidget);

    await tester.enterText(find.byKey(reviewNameKey('item-rice')), '白米饭');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pumpAndSettle();

    expect(linker.calls, hasLength(1), reason: 'the user already has a label');
  });
}
