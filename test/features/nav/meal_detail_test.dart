/// Task 27 — the `/meal/:id` deep link and the capture→review route wiring.
///
/// MANUAL-QA CHANNEL: prints one `TASK27_MEAL_QA` line for the verified deep
/// link.
///
/// * deep-linking to `/meal/<id>` renders that meal's task-22 per-meal summary
///   for a seeded meal (本餐合计 + live 今日累计);
/// * an unknown id renders the explicit "未找到该餐" empty state;
/// * the Today list opens the same detail route;
/// * `/today/review` renders the task-19 review screen when handed a
///   [ReviewArgs] payload.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:caldoo/domain/models/models.dart';
import 'package:caldoo/features/meals/review/meal_review_screen.dart';
import 'package:caldoo/features/meals/review/review_item_card.dart';
import 'package:caldoo/features/meals/summary/meal_summary_card.dart';
import 'package:caldoo/features/nav/app_router.dart';
import 'package:caldoo/features/nav/meal_detail_screen.dart';
import 'package:caldoo/features/nav/review_args.dart';
import 'package:caldoo/features/nav/today_screen.dart';

import '_harness.dart';

String textOf(WidgetTester tester, Key key) =>
    tester.widget<Text>(find.byKey(key)).data!;

void main() {
  late NavTestEnv env;

  setUp(() => env = NavTestEnv());
  tearDown(() => env.dispose());

  testWidgets('deep-linking to /meal/<id> renders that meal detail', (
    WidgetTester tester,
  ) async {
    final seeded = navMeal(id: 'meal-deep', kcal: 750);
    await env.meals.saveMealWithItems(seeded.meal, seeded.items);
    await env.pump(tester);

    final GoRouter router = env.container.read(appRouterProvider);
    router.go('/meal/meal-deep');
    await tester.pumpAndSettle();

    expect(find.byKey(mealDetailScreenKey).hitTestable(), findsOneWidget);
    expect(textOf(tester, mealSummaryKcalKey), '750');
    // The per-meal card's live day running total sees the same seeded meal.
    expect(textOf(tester, dayTotalKcalKey), '750');
    // The item list sits below the fold on the 800x600 test viewport.
    final Finder item = find.byKey(
      const Key('meal_detail_item_meal-deep-item'),
    );
    await tester.ensureVisible(item);
    await tester.pumpAndSettle();
    expect(item.hitTestable(), findsOneWidget);
    debugPrint(
      'TASK27_MEAL_QA deep_link=/meal/meal-deep '
      'meal_kcal=${textOf(tester, mealSummaryKcalKey)} '
      'day_total=${textOf(tester, dayTotalKcalKey)} -> PASS',
    );
  });

  testWidgets('an unknown meal id renders the empty state', (
    WidgetTester tester,
  ) async {
    await env.pump(tester);

    final GoRouter router = env.container.read(appRouterProvider);
    router.go('/meal/does-not-exist');
    await tester.pumpAndSettle();

    expect(find.byKey(mealDetailScreenKey).hitTestable(), findsOneWidget);
    expect(find.byKey(mealDetailMissingKey).hitTestable(), findsOneWidget);
  });

  testWidgets('the Today list opens a meal detail route', (
    WidgetTester tester,
  ) async {
    final seeded = navMeal(id: 'meal-today', kcal: 420);
    await env.meals.saveMealWithItems(seeded.meal, seeded.items);
    await env.pump(tester);

    // The food row starts below the fold on the 800x600 test viewport; the
    // outer ListView builds lazily, so drag until the finder resolves first.
    // The vertical list now lives inside the horizontal history pager, so the
    // default "first Scrollable" (the pager) must be skipped explicitly.
    final Finder tile = find.byKey(todayFoodRowKey('meal-today-item'));
    await tester.scrollUntilVisible(
      tile,
      120,
      scrollable: find
          .byWidgetPredicate(
            (Widget widget) =>
                widget is Scrollable &&
                widget.axisDirection == AxisDirection.down,
          )
          .first,
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(tile);
    await tester.pumpAndSettle();
    await tester.tap(tile);
    await tester.pumpAndSettle();

    expect(find.byKey(mealDetailScreenKey).hitTestable(), findsOneWidget);
    expect(textOf(tester, mealSummaryKcalKey), '420');
  });

  testWidgets('/today/review renders the real review screen for a draft', (
    WidgetTester tester,
  ) async {
    await env.pump(tester);

    final GoRouter router = env.container.read(appRouterProvider);
    // `push` resolves only when the route is popped, so do not await it here.
    unawaited(
      router.push(
        '/today/review',
        extra: ReviewArgs(
          draft: const AiMealDraft(
            items: <MealItem>[
              MealItem(
                id: 'draft-item',
                name: '鸡蛋',
                grams: 50,
                kcal: 70,
                carbG: 1,
                proteinG: 7,
                fatG: 4,
                saltG: 0.2,
                source: FoodSource.ai,
              ),
            ],
          ),
          meal: Meal(
            id: 'meal-review',
            timestamp: DateTime(2026, 1, 5, 12),
            mealType: MealType.lunch,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(MealReviewScreen).hitTestable(), findsOneWidget);
    expect(find.byKey(reviewAiBannerKey).hitTestable(), findsOneWidget);
  });

  testWidgets('the detail page deletes the meal behind a confirm dialog', (
    WidgetTester tester,
  ) async {
    final seeded = navMeal(id: 'meal-del', kcal: 300);
    await env.meals.saveMealWithItems(seeded.meal, seeded.items);
    await env.pump(tester);

    final GoRouter router = env.container.read(appRouterProvider);
    router.go('/meal/meal-del');
    await tester.pumpAndSettle();

    // Cancelling the dialog keeps the meal.
    await tester.tap(find.byKey(mealDetailDeleteKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(mealDetailDeleteCancelKey));
    await tester.pumpAndSettle();
    expect(
      await env.meals.getMealsInRange(
        startInclusive: DateTime(2000),
        endExclusive: DateTime(2100),
      ),
      hasLength(1),
    );

    // Confirming removes it and lands on 概览 (the totals are watch streams,
    // so they follow by themselves).
    await tester.tap(find.byKey(mealDetailDeleteKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(mealDetailDeleteConfirmKey));
    await tester.pumpAndSettle();

    expect(find.byKey(mealDetailScreenKey), findsNothing);
    expect(find.byKey(todayScreenKey), findsOneWidget);
    expect(
      await env.meals.getMealsInRange(
        startInclusive: DateTime(2000),
        endExclusive: DateTime(2100),
      ),
      isEmpty,
    );
  });

  testWidgets('the detail page opens the editor and saves edits back', (
    WidgetTester tester,
  ) async {
    final seeded = navMeal(id: 'meal-edit', kcal: 300); // 150 g of 米饭
    await env.meals.saveMealWithItems(seeded.meal, seeded.items);
    await env.pump(tester);

    final GoRouter router = env.container.read(appRouterProvider);
    router.go('/meal/meal-edit');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(mealDetailEditKey));
    await tester.pumpAndSettle();

    // The editor shows the stored values under the edit banner — not the AI
    // estimate banner.
    expect(find.text('AI 估算，可修改'), findsNothing);
    expect(find.text('已保存的记录，可直接修改'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(reviewGramsKey('meal-edit-item')))
          .controller!
          .text,
      '150',
    );

    // 150 g -> 300 g doubles the item (300 kcal -> 600).
    await tester.enterText(find.byKey(reviewGramsKey('meal-edit-item')), '300');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(reviewSaveButtonKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(reviewSaveButtonKey));
    await tester.pumpAndSettle();

    // Popping the editor lands back on the live detail, which re-emitted the
    // updated record through the watch stream.
    expect(find.byKey(mealDetailScreenKey).hitTestable(), findsOneWidget);
    expect(textOf(tester, mealSummaryKcalKey), '600');
    final group = await env.meals.getMealsWithItemsInRange(
      startInclusive: DateTime(2000),
      endExclusive: DateTime(2100),
    );
    expect(group.single.items.single.grams, 300);
    expect(group.single.items.single.kcal, 600);
  });
}
