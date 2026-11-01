/// Shared fixtures + a recording [MealRepository] for the task-19 review tests.
///
/// The recording fake captures the exact `(meal, items)` pair the review screen
/// hands to the repository, so a test can assert that the EDITED values — not
/// the raw AI snapshot — are what get persisted.
///
/// [RecordingMealReviser] does the same for the AI-correction panel: it records
/// every revision call's inputs and replays one canned [MealAnalysis] (or a
/// typed [AiError]), so the correction tests need no socket.
library;

import 'dart:async';

import 'package:caldoo/ai/ai_client.dart' show AiError;
import 'package:caldoo/ai/schemas/meal_analysis.dart';
import 'package:caldoo/core/time/date_windows.dart' show MealWithItems;
import 'package:caldoo/domain/models/models.dart';
import 'package:caldoo/domain/repositories/repositories.dart';
import 'package:caldoo/features/meals/capture/image_codec.dart'
    show PreparedPhoto;

/// One captured `saveMealWithItems` call.
class RecordedMealSave {
  const RecordedMealSave({required this.meal, required this.items});

  final Meal meal;
  final List<MealItem> items;
}

/// A [MealRepository] that records saves and updates instead of touching the
/// database.
class RecordingMealRepository implements MealRepository {
  /// Every captured save, in call order.
  final List<RecordedMealSave> saves = <RecordedMealSave>[];

  /// Every captured update (the edit-existing path), in call order.
  final List<RecordedMealSave> updates = <RecordedMealSave>[];

  @override
  Future<void> saveMealWithItems(Meal meal, List<MealItem> items) async {
    saves.add(RecordedMealSave(meal: meal, items: List<MealItem>.of(items)));
  }

  @override
  Future<void> updateMealWithItems(Meal meal, List<MealItem> items) async {
    updates.add(RecordedMealSave(meal: meal, items: List<MealItem>.of(items)));
  }

  @override
  Future<List<MealWithItems>> getMealsWithItemsForFood(String foodId) async =>
      const <MealWithItems>[];

  @override
  Future<void> deleteMeal(String id) async {}

  @override
  Future<List<Meal>> getMealsInRange({
    required DateTime startInclusive,
    required DateTime endExclusive,
  }) async => const <Meal>[];

  @override
  Future<List<MealWithItems>> getMealsWithItemsInRange({
    required DateTime startInclusive,
    required DateTime endExclusive,
  }) async => const <MealWithItems>[];

  @override
  Stream<List<MealWithItems>> watchMealsInRange({
    required DateTime startInclusive,
    required DateTime endExclusive,
  }) => const Stream<List<MealWithItems>>.empty();

  @override
  Stream<List<MealWithItems>> watchMealsForDay({
    required DateTime dayStartInclusive,
    required DateTime dayEndExclusive,
  }) => watchMealsInRange(
    startInclusive: dayStartInclusive,
    endExclusive: dayEndExclusive,
  );

  @override
  Stream<List<MealWithItems>> watchMealsForWeek({
    required DateTime weekStartInclusive,
    required DateTime weekEndExclusive,
  }) => watchMealsInRange(
    startInclusive: weekStartInclusive,
    endExclusive: weekEndExclusive,
  );

  @override
  Stream<MealWithItems?> watchMealWithItems(String id) =>
      const Stream<MealWithItems?>.empty();
}

/// The AI rice estimate: near-exactly-representable values so `*1.5` is exact.
MealItem riceItem({double grams = 100}) => MealItem(
  id: 'item-rice',
  name: '米饭',
  grams: grams,
  kcal: 120,
  carbG: 8,
  proteinG: 6,
  fatG: 5,
  saltG: 0.3,
  source: FoodSource.ai,
  confidence: 0.8,
);

/// A second AI estimate so totals visibly change when one row is edited.
MealItem eggItem({double grams = 50}) => MealItem(
  id: 'item-egg',
  name: '鸡蛋',
  grams: grams,
  kcal: 70,
  carbG: 1,
  proteinG: 7,
  fatG: 4,
  saltG: 0.2,
  source: FoodSource.ai,
);

/// A saved label food named 米饭 with per-100 g values that scale exactly.
const Food labelRice = Food(
  id: 'food-label-rice',
  name: '米饭',
  source: FoodSource.label,
  kcal: 150,
  carbG: 30,
  proteinG: 3,
  fatG: 0.5,
  sodiumMg: 400,
);

/// The meal record the review screen saves its items under.
Meal testMeal() => Meal(
  id: 'meal-1',
  timestamp: DateTime(2026, 1, 1, 12),
  mealType: MealType.lunch,
);

/// One recorded revision call (every input the review screen sent).
class RevisionCall {
  const RevisionCall({
    required this.photos,
    required this.userText,
    required this.correctionNote,
    required this.currentItems,
  });

  final List<PreparedPhoto> photos;
  final String userText;
  final String correctionNote;
  final List<MealItem> currentItems;
}

/// A [MealReviser] fake: records each call and returns [result], throws a typed
/// [error] (mirroring a failed AI request) or throws [thrown] (any other
/// failure the screen must survive without getting stuck).
class RecordingMealReviser {
  RecordingMealReviser({this.result, this.error, this.thrown, this.gate});

  /// The canned revised analysis returned by every call; unused when [error]
  /// or [thrown] is set.
  MealAnalysis? result;

  /// When set, every call throws this typed AI failure.
  AiError? error;

  /// When set, every call throws this non-AI failure.
  Object? thrown;

  /// When set, calls are recorded and then wait for this completer, so a test
  /// can observe the in-flight state (spinner, locked editors, double taps).
  Completer<MealAnalysis>? gate;

  /// Every recorded call, in order.
  final List<RevisionCall> calls = <RevisionCall>[];

  Future<MealAnalysis> call({
    required List<PreparedPhoto> photos,
    required String userText,
    required String correctionNote,
    required List<MealItem> currentItems,
  }) async {
    calls.add(
      RevisionCall(
        photos: photos,
        userText: userText,
        correctionNote: correctionNote,
        currentItems: currentItems,
      ),
    );
    final Completer<MealAnalysis>? pending = gate;
    if (pending != null) {
      return pending.future;
    }
    final Object? unexpected = thrown;
    if (unexpected != null) {
      throw unexpected;
    }
    final AiError? failure = error;
    if (failure != null) {
      throw failure;
    }
    final MealAnalysis? analysis = result;
    if (analysis == null) {
      throw StateError('RecordingMealReviser has no result configured');
    }
    return analysis;
  }
}

/// A revised analysis naming one item (200 g of rice) so a replacement is
/// unmistakable in the widgets.
MealAnalysis revisedRiceAnalysis() => const MealAnalysis(
  items: <MealAnalysisItem>[
    MealAnalysisItem(
      name: '米饭',
      grams: 200,
      kcal: 240,
      carbG: 16,
      proteinG: 12,
      fatG: 10,
      saltG: 0.6,
      confidence: 0.9,
    ),
  ],
);

/// A phone-free [PreparedPhoto] (the review screen only forwards it).
const PreparedPhoto testPhoto = PreparedPhoto(
  base64Data: 'AAAA',
  width: 1,
  height: 1,
);
