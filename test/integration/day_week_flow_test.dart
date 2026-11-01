/// Task 32: end-to-end integration test — one full day rolls into the week.
///
/// WIDGET-LEVEL: every step drives a **real production screen** over the real
/// provider graph (`_integration_env.dart`), and every number is asserted
/// against both the rendered widget and the **persisted drift rows**. No
/// device/emulator and no socket is used — `flutter test test/integration/`
/// runs this on the Dart VM.
///
/// Happy path:
///   1. photo meal  (recorded AI fixture, downscaled real photo)
///   2. label food  (recorded `label_photo_response.json` parse)
///   3. label meal  (logged from the saved label food through the review save
///      path — the same path that survives an AI failure)
///   4. manual exercise (跑步, 30 min @ 8 MET)
/// then asserts the per-meal summary, the daily summary (budget + deficit) and
/// the weekly chart, all equal to the hand-computed task-7 vector:
///   intake 1936, exercise 257, budget 2236, deficit 300 (the old fractional
///   task-7 vector 1935.75 / 257.25 / 2235.75 rounded to whole kcal).
library;

import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:caldoo/data/db/app_database.dart';
import 'package:caldoo/domain/models/models.dart';
import 'package:caldoo/l10n/app_format.dart' show AppFormat;
import 'package:caldoo/features/dashboard/daily/daily_summary_view.dart';
import 'package:caldoo/features/dashboard/weekly/weekly_summary_view.dart';
import 'package:caldoo/features/exercise/exercise_entry_screen.dart';
import 'package:caldoo/features/meals/capture/meal_capture_screen.dart';
import 'package:caldoo/features/meals/label/label_capture_screen.dart';
import 'package:caldoo/features/meals/review/meal_review_screen.dart';
import 'package:caldoo/features/meals/review/review_item_card.dart';
import 'package:caldoo/features/meals/saved_foods/saved_food_picker.dart';
import 'package:caldoo/features/meals/summary/meal_summary_card.dart';
import 'package:caldoo/features/nav/meal_detail_screen.dart';

import '_integration_env.dart';

// ---------------------------------------------------------------------------
// Reusable widget-flow steps (all real screens; no repository shortcuts).
// ---------------------------------------------------------------------------

/// Step 1: photo meal — pick a real photo, submit the mocked AI photo call,
/// save the pushed review screen.
Future<void> logPhotoMeal(WidgetTester tester, IntegrationEnv env) async {
  await env.pump(tester, const MealCaptureScreen());
  await tester.tap(find.byKey(const Key('capture_gallery_button')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('capture_submit_button')));
  await tester.pumpAndSettle();

  // The capture submit routed into the REAL review screen (my router override).
  expect(find.byType(MealReviewScreen), findsOneWidget);
  await tester.tap(find.byKey(reviewSaveButtonKey));
  await tester.pumpAndSettle();
}

/// Step 2: label food — pick the real label photo, parse the recorded fixture,
/// name and save the per-100 g `Food(source: label)`.
Future<void> saveLabelFood(WidgetTester tester, IntegrationEnv env) async {
  await env.pump(tester, const LabelCaptureScreen());
  await tester.tap(find.byKey(const Key('label_pick_button')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('label_parse_button')));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(labelNameFieldKey(0)), labelFoodName);
  await tester.pump();
  await tester.tap(find.byKey(const Key('label_save_button')));
  await tester.pumpAndSettle();
}

/// Step 3: label meal — log a meal from the saved label food. The draft is the
/// degraded shape (empty items + warning) so this is exactly the path that
/// stays usable when the AI parse fails.
Future<void> logLabelMeal(WidgetTester tester, IntegrationEnv env) async {
  await env.pump(
    tester,
    MealReviewScreen(
      draft: const AiMealDraft(items: <MealItem>[], warning: 'AI 结果解析失败'),
      meal: env.labelMeal(),
    ),
  );

  // Empty draft -> one blank row; choose the saved label food explicitly.
  await tester.tap(find.text('选择已存食物'));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(savedFoodTileKey(labelFoodId)));
  await tester.pumpAndSettle();

  await tester.enterText(find.byKey(reviewNameKey(blankItemId)), labelFoodName);
  await tester.enterText(find.byKey(reviewGramsKey(blankItemId)), '150');
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(reviewSaveButtonKey));
  await tester.pumpAndSettle();
}

/// Step 4: manual exercise — enter the task-7 vector's burn (257 kcal, the old
/// 257.25 rounded) for today. The burn field is digits-only, so the value is
/// typed as a whole number.
///
/// The screen opens on yesterday (exercise is normally backfilled the morning
/// after), so the flow first switches to 今天 through the real shortcut.
Future<void> logExercise(WidgetTester tester, IntegrationEnv env) async {
  await env.pump(tester, const ExerciseEntryScreen());
  await tester.tap(find.text('今天'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(exerciseKcalFieldKey), '257');
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(exerciseSaveButtonKey));
  await tester.pumpAndSettle();
}

void main() {
  late IntegrationEnv env;

  setUp(() async {
    env = IntegrationEnv();
    await env.seedProfile();
  });

  tearDown(() async {
    await env.dispose();
  });

  testWidgets('one full day (photo + label meal + exercise) -> weekly chart, exact task-7 '
      'numbers on the widgets AND the DB', (WidgetTester tester) async {
    // ---- Log the whole day through the real screens. ----
    await logPhotoMeal(tester, env);
    await saveLabelFood(tester, env);
    await logLabelMeal(tester, env);
    await logExercise(tester, env);

    // No-live-network: both AI calls (photo meal + label parse) were served
    // by the in-process mock adapter; there is no real Dio transport.
    expect(env.usesMockTransport, isTrue);
    expect(
      env.adapter.calls,
      2,
      reason: 'photo meal + label parse; the label meal never calls the AI',
    );

    // ---------------------------------------------------------------------
    // Persisted DB values (the same rows the UI streams from).
    // ---------------------------------------------------------------------
    final DateTime dayStart = DateTime(
      env.now.year,
      env.now.month,
      env.now.day,
    );
    final DateTime dayEnd = dayStart.add(const Duration(days: 1));

    final List<MealRow> meals = await env.db.mealDao.getMealsInRange(
      startInclusive: dayStart,
      endExclusive: dayEnd,
    );
    expect(meals.map((MealRow m) => m.id).toSet(), <String>{
      photoMealId,
      labelMealId,
    }, reason: 'both meals persisted for the local day');

    final List<MealItemRow> photoItems = await env.db.mealDao.getItemsForMeal(
      photoMealId,
    );
    expect(photoItems, hasLength(1));
    expect(photoItems.single.kcal, photoMealKcal);
    expect(photoItems.single.source, FoodSource.ai);

    final List<MealItemRow> labelItems = await env.db.mealDao.getItemsForMeal(
      labelMealId,
    );
    expect(labelItems, hasLength(1));
    expect(labelItems.single.kcal, labelMealKcal);
    expect(labelItems.single.grams, labelMealGrams);
    expect(labelItems.single.source, FoodSource.label);
    expect(labelItems.single.foodId, labelFoodId);

    // The persisted sum is EXACTLY the vector intake — no tolerance.
    final int persistedIntake = photoItems.single.kcal + labelItems.single.kcal;
    expect(persistedIntake, expectedIntakeKcal);

    final FoodRow? labelFood = await env.db.foodDao.getFood(labelFoodId);
    expect(labelFood, isNotNull);
    expect(labelFood!.source, FoodSource.label);
    expect(labelFood.kcal, labelFoodKcal);
    expect(labelFood.name, labelFoodName);

    final DailyExerciseRow? exercise = await env.db.exerciseDao.getDay(
      env.todayKey,
    );
    expect(exercise, isNotNull);
    expect(exercise!.dayKey.toUtc(), env.todayKey);
    expect(exercise.kcal, expectedExerciseKcal);

    // ---------------------------------------------------------------------
    // Per-meal summary (real `/meal/:id` screen) + live day running total.
    // ---------------------------------------------------------------------
    await env.pump(tester, const MealDetailScreen(mealId: photoMealId));
    expect(textOf(tester, mealSummaryKcalKey), AppFormat.number(photoMealKcal));
    expect(textOf(tester, dayTotalKcalKey), '1936');

    // ---------------------------------------------------------------------
    // Daily summary: intake / exercise / budget / signed deficit.
    // ---------------------------------------------------------------------
    await env.pump(
      tester,
      const Scaffold(body: SingleChildScrollView(child: DailySummaryView())),
    );
    expect(textOf(tester, dailyIntakeKcalKey), '1936');
    expect(textOf(tester, dailyExerciseKcalKey), '257');
    expect(textOf(tester, dailyBudgetKey), '2236');
    expect(textOf(tester, dailyBalanceLabelKey), '缺口(相对额度)');
    expect(textOf(tester, dailyBalanceValueKey), '300');

    // ---------------------------------------------------------------------
    // Weekly chart: 7 Mon..Sun groups (intake + burn per day), the
    // base-budget line, and the week's cumulative totals over logged days.
    // ---------------------------------------------------------------------
    await env.pump(
      tester,
      const Scaffold(body: SingleChildScrollView(child: WeeklySummaryView())),
    );
    final BarChart chart = tester.widget<BarChart>(find.byType(BarChart));
    final List<BarChartGroupData> groups = chart.data.barGroups;
    expect(groups, hasLength(7));
    final List<double> intakeBars = <double>[
      for (final BarChartGroupData g in groups) g.barRods.first.toY,
    ];
    expect(
      intakeBars.where((double v) => v > 0),
      hasLength(1),
      reason: 'exactly one logged day (the exercise-only case never counts)',
    );
    expect(intakeBars.reduce(math.max), expectedIntakeKcal);
    // The logged day's burn bar is its full budget (BMR + exercise); the
    // unlogged days carry no burn bar.
    final BarChartGroupData loggedGroup = groups.firstWhere(
      (BarChartGroupData g) => g.barRods.first.toY > 0,
    );
    expect(loggedGroup.barRods.last.toY, expectedBudgetKcal);
    expect(
      groups
          .where((BarChartGroupData g) => g.barRods.first.toY == 0)
          .every((BarChartGroupData g) => g.barRods.last.toY == 0),
      isTrue,
      reason: 'unlogged days must not plot a burn bar either',
    );
    final HorizontalLine line =
        chart.data.extraLinesData.horizontalLines.single;
    expect(line.y, expectedBaseBudgetKcal);
    expect(line.dashArray, weeklyTargetLineDashArray);
    expect(line.label.labelResolver(line), weeklyTargetLineLabel);
    // Cumulative totals for the week, whole kcal (never averages).
    expect(textOf(tester, weeklyTotalIntakeKey), '1936'); // 1935.75 rounded
    expect(textOf(tester, weeklyTotalBurnKey), '2236'); // 2235.75 rounded
    expect(textOf(tester, weeklyTotalBalanceKey), '-300');
    expect(textOf(tester, weeklyLoggedDaysKey), '1');

    // MANUAL-QA CHANNEL: the full day rolling into the week, exact numbers.
    debugPrint(
      'TASK32_QA photo=$photoMealKcal label=$labelMealKcal '
      'intake=$persistedIntake exercise=${exercise.kcal} '
      'baseBudget=$expectedBaseBudgetKcal budget=$expectedBudgetKcal '
      'deficit=$expectedDeficitKcal '
      'dayBar=${intakeBars.reduce(math.max)} weekBarCount=7 '
      'targetLine=${line.y} '
      'totalIntake=${textOf(tester, weeklyTotalIntakeKey)} '
      'totalBurn=${textOf(tester, weeklyTotalBurnKey)} '
      'difference=${textOf(tester, weeklyTotalBalanceKey)} '
      'loggedDays=${textOf(tester, weeklyLoggedDaysKey)} -> PASS',
    );
  });

  testWidgets(
    'failure: an AI parse failure leaves the label meal usable and the day '
    'total correct',
    (WidgetTester tester) async {
      // The photo AI call now degrades to a completion with no tool call.
      env.mealFails = true;
      await logPhotoMealExpectingFailure(tester, env);

      // No photo meal row was written.
      final List<MealItemRow> photoItems = await env.db.mealDao.getItemsForMeal(
        photoMealId,
      );
      expect(photoItems, isEmpty);

      // The label path (separate AI tool call, separate fixture) is unaffected.
      await saveLabelFood(tester, env);
      await logLabelMeal(tester, env);

      await env.pump(
        tester,
        const Scaffold(body: SingleChildScrollView(child: DailySummaryView())),
      );

      // Day total is exactly the label meal; budget is the exercise-free base.
      final String intake = textOf(tester, dailyIntakeKcalKey);
      final String budget = textOf(tester, dailyBudgetKey);
      expect(intake, AppFormat.number(labelMealKcal));
      expect(budget, AppFormat.number(expectedBaseBudgetKcal));

      // The label-only deficit is base budget - label intake (same formatter
      // the widget uses), so the shortfall is correct without a photo meal.
      final int labelOnlyDeficit = expectedBaseBudgetKcal - labelMealKcal;
      expect(textOf(tester, dailyBalanceLabelKey), '缺口(相对额度)');
      expect(
        textOf(tester, dailyBalanceValueKey),
        AppFormat.number(labelOnlyDeficit),
      );

      // The label meal WAS persisted and is usable.
      final List<MealItemRow> labelItems = await env.db.mealDao.getItemsForMeal(
        labelMealId,
      );
      expect(labelItems, hasLength(1));
      expect(labelItems.single.source, FoodSource.label);

      debugPrint(
        'TASK32_QA failure_path intake=$intake budget=$budget '
        'photoMeal=false labelMeal=${labelItems.single.kcal} -> PASS',
      );
    },
  );
}

/// Drives the capture submit that must degrade without routing to review.
Future<void> logPhotoMealExpectingFailure(
  WidgetTester tester,
  IntegrationEnv env,
) async {
  await env.pump(tester, const MealCaptureScreen());
  await tester.tap(find.byKey(const Key('capture_gallery_button')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('capture_submit_button')));
  await tester.pumpAndSettle();
  // An AI failure must NOT reach the review screen (no draft to review).
  expect(find.byType(MealReviewScreen), findsNothing);
}
