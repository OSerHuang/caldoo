/// The 概览 tab's swipeable day history and flat day log (task 31).
///
/// Boots the real app shell over the in-memory repository fakes with the clock
/// pinned to 2026-01-05 12:00 +08:00, seeds one meal today and a DIFFERENT one
/// yesterday, and drives the real [HistoryPeriodPager] mounted by the 概览 tab:
///
/// * offset 0 is today: today's intake/macros/date, today's FOOD row and the
///   two quick-add actions are all on screen;
/// * swiping the finger right reveals yesterday's intake/macros/date and its
///   food row, together with the same quick-add actions — they record into
///   the browsed day, so backfilling yesterday is a first-class flow;
/// * the log is a flat list of the day's foods — no meal-type buckets
///   (早餐/午餐/晚餐/加餐) and no per-meal "N 项" summaries;
/// * the back-to-today action and the ‹ / › header buttons navigate between
///   days, and › is absent on today because there is no future page;
/// * swiping left at today cannot reach the future.
///
/// Assertions read the real rendered text via the public provider keys rather
/// than private widget types, so they pin the values the user sees.
library;

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:caldoo/core/ui/history_period_pager.dart';
import 'package:caldoo/domain/models/models.dart';
import 'package:caldoo/features/dashboard/daily/daily_summary_view.dart';
import 'package:caldoo/features/meals/capture/meal_capture_screen.dart';
import 'package:caldoo/features/meals/review/meal_review_screen.dart';
import 'package:caldoo/features/meals/summary/day_window.dart'
    show localDayWindow;
import 'package:caldoo/features/nav/today_screen.dart';

import '../../data/db/_test_db.dart';
import '../../data/repositories/fake_repositories.dart';
import '../dashboard/daily/_fixtures.dart'
    show dashboardClock, dashboardNow, dashboardOffset;
import '../meals/capture/_fakes.dart' show mealArguments, mealCompletion;
import '../settings/_fakes.dart';
import '_harness.dart';

/// Only the on-screen (hit-testable) instance of [key].
Finder visible(Key key) => find.byKey(key).hitTestable();

/// The rendered [Text.data] behind [key].
String _text(WidgetTester tester, Key key) =>
    tester.widget<Text>(find.byKey(key)).data!;

/// Whether the header currently shows the › (newer) button.
bool _newerShown(WidgetTester tester) =>
    find.byKey(historyNewerKey('today')).evaluate().isNotEmpty;

/// Whether the header's › (newer) button is enabled.
bool _newerEnabled(WidgetTester tester) =>
    tester.widget<IconButton>(find.byKey(historyNewerKey('today'))).onPressed !=
    null;

/// Seeds one meal on the pinned "now" (2026-01-05) and a DIFFERENT one the day
/// before (2026-01-04), with different kcal and macros so the two pages are
/// distinguishable at a glance.
Future<void> seedTwoDays(FakeMealRepository meals) async {
  await meals.saveMealWithItems(
    Meal(id: 'today-meal', timestamp: dashboardNow, mealType: MealType.lunch),
    <MealItem>[
      const MealItem(
        id: 'today-item',
        name: '牛肉面',
        grams: 300,
        kcal: 600,
        carbG: 60,
        proteinG: 30,
        fatG: 15,
        saltG: 2,
        source: FoodSource.manual,
      ),
    ],
  );
  await meals.saveMealWithItems(
    Meal(
      id: 'yesterday-meal',
      timestamp: dashboardNow.subtract(const Duration(days: 1)),
      mealType: MealType.dinner,
    ),
    <MealItem>[
      const MealItem(
        id: 'yesterday-item',
        name: '小米粥',
        grams: 200,
        kcal: 400,
        carbG: 20,
        proteinG: 10,
        fatG: 4,
        saltG: 1,
        source: FoodSource.manual,
      ),
    ],
  );
}

void main() {
  late NavTestEnv env;

  setUp(() => env = NavTestEnv());
  tearDown(() => env.dispose());

  /// Uses a real phone-sized surface (390x844 logical) rather than the 800x600
  /// test default: the daily hero card plus the quick-add row only fit above
  /// the fold on a phone-sized screen, and an off-screen sliver child is
  /// skipped by key finders.
  void usePhoneSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(390 * 2, 844 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
  }

  /// Seeds the two days and boots the app on the 概览 tab.
  Future<void> pumpSeeded(WidgetTester tester) async {
    usePhoneSurface(tester);
    await seedTwoDays(env.meals);
    await env.pump(tester);
  }

  testWidgets('the initial page shows today: totals, food row, quick-add', (
    WidgetTester tester,
  ) async {
    await pumpSeeded(tester);

    expect(visible(todayScreenKey), findsOneWidget);

    // Header: "今天", no back-to-now action, no › (no future page).
    expect(_text(tester, historyPeriodLabelKey('today')), '今天');
    expect(find.byKey(historyBackToNowKey('today')), findsNothing);
    expect(_newerShown(tester), isFalse);

    // Today's real numbers, rendered from the day providers.
    expect(_text(tester, dailyIntakeKcalKey), '600');
    expect(_text(tester, dailyCarbKey), '60');
    expect(_text(tester, dailyProteinKey), '30');
    expect(_text(tester, dailyFatKey), '15');
    expect(_text(tester, dailySaltKey), '2 / 5');
    expect(find.text('今日汇总'), findsOneWidget);
    expect(find.text('1月5日'), findsOneWidget);

    // Today's food row, and only today's.
    expect(find.byKey(todayFoodRowKey('today-item')), findsOneWidget);
    expect(find.byKey(todayFoodRowKey('yesterday-item')), findsNothing);
    expect(find.text('今日记录'), findsOneWidget);

    // The quick-add actions are offered today only.
    expect(visible(todayQuickAddMealKey), findsOneWidget);
    expect(visible(todayQuickAddExerciseKey), findsOneWidget);
  });

  testWidgets('swiping right shows yesterday: totals, food, quick-add', (
    WidgetTester tester,
  ) async {
    await pumpSeeded(tester);

    await tester.drag(
      find.byKey(historyPagerKey('today')),
      const Offset(600, 0),
    );
    await tester.pumpAndSettle();

    // Header now labels yesterday and offers back-to-today.
    expect(_text(tester, historyPeriodLabelKey('today')), '1月4日 周日');
    expect(find.byKey(historyBackToNowKey('today')), findsOneWidget);
    expect(_newerShown(tester), isTrue);
    expect(_newerEnabled(tester), isTrue);

    // Yesterday's real numbers, NOT today's.
    expect(_text(tester, dailyIntakeKcalKey), '400');
    expect(_text(tester, dailyCarbKey), '20');
    expect(_text(tester, dailyProteinKey), '10');
    expect(_text(tester, dailyFatKey), '4');
    expect(_text(tester, dailySaltKey), '1 / 5');
    expect(find.text('当日汇总'), findsOneWidget);
    expect(find.text('1月4日'), findsOneWidget);
    expect(find.text('当日记录'), findsOneWidget);

    // Yesterday's food row is rendered; today's is not.
    expect(find.byKey(todayFoodRowKey('yesterday-item')), findsOneWidget);
    expect(find.byKey(todayFoodRowKey('today-item')), findsNothing);

    // Quick-add records into the browsed day, so a past page offers it too.
    expect(visible(todayQuickAddMealKey), findsOneWidget);
    expect(visible(todayQuickAddExerciseKey), findsOneWidget);
  });

  testWidgets('back-to-today returns to today\'s numbers', (
    WidgetTester tester,
  ) async {
    await pumpSeeded(tester);

    await tester.drag(
      find.byKey(historyPagerKey('today')),
      const Offset(600, 0),
    );
    await tester.pumpAndSettle();
    expect(_text(tester, dailyIntakeKcalKey), '400');
    expect(_text(tester, historyPeriodLabelKey('today')), '1月4日 周日');

    await tester.tap(find.byKey(historyBackToNowKey('today')));
    await tester.pumpAndSettle();

    expect(_text(tester, historyPeriodLabelKey('today')), '今天');
    expect(_text(tester, dailyIntakeKcalKey), '600');
    expect(find.byKey(historyBackToNowKey('today')), findsNothing);
    expect(_newerShown(tester), isFalse);
    expect(find.byKey(todayFoodRowKey('today-item')), findsOneWidget);
    expect(visible(todayQuickAddMealKey), findsOneWidget);
  });

  testWidgets('swiping left at today cannot reach the future', (
    WidgetTester tester,
  ) async {
    await pumpSeeded(tester);

    await tester.drag(
      find.byKey(historyPagerKey('today')),
      const Offset(-600, 0),
    );
    await tester.pumpAndSettle();

    // Still today: the pager is past-only.
    expect(_text(tester, historyPeriodLabelKey('today')), '今天');
    expect(_text(tester, dailyIntakeKcalKey), '600');
    expect(find.byKey(historyBackToNowKey('today')), findsNothing);
    expect(find.byKey(todayFoodRowKey('today-item')), findsOneWidget);
    expect(_newerShown(tester), isFalse);
  });

  testWidgets('the ‹ / › header buttons step back and forward one day', (
    WidgetTester tester,
  ) async {
    await pumpSeeded(tester);

    // › is absent on today; ‹ is enabled.
    expect(find.byKey(historyNewerKey('today')), findsNothing);
    expect(
      tester.widget<IconButton>(find.byKey(historyOlderKey('today'))).onPressed,
      isNotNull,
    );

    // ‹ goes one day back, where › (newer) reappears.
    await tester.tap(find.byKey(historyOlderKey('today')));
    await tester.pumpAndSettle();
    expect(_text(tester, historyPeriodLabelKey('today')), '1月4日 周日');
    expect(_text(tester, dailyIntakeKcalKey), '400');
    expect(_newerShown(tester), isTrue);

    // › comes back to today, where it disappears again.
    await tester.tap(find.byKey(historyNewerKey('today')));
    await tester.pumpAndSettle();
    expect(_text(tester, historyPeriodLabelKey('today')), '今天');
    expect(_text(tester, dailyIntakeKcalKey), '600');
    expect(find.byKey(historyNewerKey('today')), findsNothing);
  });

  testWidgets('the log lists each food directly, without meal-type buckets', (
    WidgetTester tester,
  ) async {
    usePhoneSurface(tester);
    await env.meals.saveMealWithItems(
      Meal(
        id: 'multi-meal',
        timestamp: dashboardNow,
        mealType: MealType.dinner,
      ),
      <MealItem>[
        const MealItem(
          id: 'multi-noodle',
          name: '牛肉面',
          grams: 300,
          kcal: 600,
          carbG: 60,
          proteinG: 30,
          fatG: 15,
          saltG: 2,
          source: FoodSource.manual,
        ),
        const MealItem(
          id: 'multi-egg',
          name: '卤蛋',
          grams: 50,
          kcal: 80,
          carbG: 1,
          proteinG: 7,
          fatG: 5,
          saltG: 0.5,
          source: FoodSource.manual,
        ),
      ],
    );
    await env.pump(tester);

    // One row per FOOD, carrying the food's own name/weight/kcal.
    expect(find.byKey(todayFoodRowKey('multi-noodle')), findsOneWidget);
    expect(find.byKey(todayFoodRowKey('multi-egg')), findsOneWidget);
    expect(find.text('牛肉面'), findsOneWidget);
    expect(find.text('卤蛋'), findsOneWidget);
    expect(find.text('300 g'), findsOneWidget);
    expect(find.text('50 g'), findsOneWidget);

    // No meal-type buckets and no per-meal "N 项" summary line.
    for (final String mealType in <String>['早餐', '午餐', '晚餐', '加餐']) {
      expect(
        find.text(mealType),
        findsNothing,
        reason: 'the day log is a flat food list, not meal-type buckets',
      );
    }
    expect(find.text('2 项'), findsNothing);
  });

  testWidgets('a past day with no meal shows the historical empty state', (
    WidgetTester tester,
  ) async {
    await pumpSeeded(tester);

    // Two pages back (2026-01-03) has no seeded meal.
    await tester.tap(find.byKey(historyOlderKey('today')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(historyOlderKey('today')));
    await tester.pumpAndSettle();

    expect(_text(tester, historyPeriodLabelKey('today')), '1月3日 周六');
    expect(_text(tester, dailyIntakeKcalKey), '0');
    expect(find.byKey(todayMealsEmptyKey), findsOneWidget);
    expect(find.text('这一天没有记录'), findsOneWidget);
    expect(find.byKey(todayFoodRowKey('yesterday-item')), findsNothing);
  });

  testWidgets(
    'quick-add on yesterday\'s page backfills the meal into yesterday',
    (WidgetTester tester) async {
      usePhoneSurface(tester);
      await seedTwoDays(env.meals);
      // The real capture flow needs the AI seams: a served analysis for the
      // submitted text, like the review-wiring tests.
      final mock = mockDio((options) => mealCompletion(mealArguments));
      final InMemorySecureKeyStore keyStore = InMemorySecureKeyStore();
      await keyStore.write(testApiKey);
      await env.pump(
        tester,
        dio: mock.dio,
        keyStore: keyStore,
        database: testDb(),
      );

      // Onto yesterday's page, then through the real capture route: the
      // quick-add pushes the browsed day as the route's extra.
      await tester.drag(
        find.byKey(historyPagerKey('today')),
        const Offset(600, 0),
      );
      await tester.pumpAndSettle();
      await scrollTodayUntilVisible(tester, find.byKey(todayQuickAddMealKey));
      await tester.tap(find.byKey(todayQuickAddMealKey));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('capture_text_field')),
        '昨天的午饭',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('capture_submit_button')));
      await tester.pumpAndSettle();

      expect(find.byType(MealReviewScreen), findsOneWidget);
      // The capture instant (12:00) guesses 午餐; a backfilling user corrects
      // it through the type selector before saving.
      expect(find.byKey(reviewMealTypeSelectorKey), findsOneWidget);
      await tester.tap(find.text('晚餐'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(reviewSaveButtonKey));
      await tester.pump();
      await tester.tap(find.byKey(reviewSaveButtonKey));
      await tester.pumpAndSettle();

      // The save pops back to the capture screen; leave the flow entirely.
      expect(find.byType(MealCaptureScreen), findsOneWidget);
      await systemBack(tester);
      await tester.pumpAndSettle();

      // Still on yesterday's page, now including the backfilled meal:
      // 400 (小米粥) + 174 (米饭). The meal recorded "now"-of-yesterday, so it
      // lands in yesterday's window, never today's.
      expect(_text(tester, historyPeriodLabelKey('today')), '1月4日 周日');
      await scrollTodayUp(tester);
      expect(_text(tester, dailyIntakeKcalKey), '574');
      await scrollTodayUntilVisible(tester, find.text('米饭'));
      expect(find.text('米饭'), findsOneWidget);
    },
  );

  testWidgets('改为今天 on the capture screen re-targets the backfill into today', (
    WidgetTester tester,
  ) async {
    // The re-targeted meal records "now" through the capture route's
    // package:clock seam, which the harness's Riverpod clock providers do
    // NOT pin — wrap the whole flow in withClock so "now" is the harness's
    // 2026-01-05 12:00 +08:00 everywhere in this test.
    await withClock(dashboardClock(), () async {
      usePhoneSurface(tester);
      await seedTwoDays(env.meals);
      final mock = mockDio((options) => mealCompletion(mealArguments));
      final InMemorySecureKeyStore keyStore = InMemorySecureKeyStore();
      await keyStore.write(testApiKey);
      await env.pump(
        tester,
        dio: mock.dio,
        keyStore: keyStore,
        database: testDb(),
      );

      // The exact inverse of the backfill test above: capture opened on
      // yesterday's page, but the meal must land in TODAY's window.
      final today = localDayWindow(dashboardNow, dashboardOffset);
      final int todayBefore = (await env.meals.getMealsInRange(
        startInclusive: today.start,
        endExclusive: today.end,
      )).length;
      final yesterday = localDayWindow(
        dashboardNow.subtract(const Duration(days: 1)),
        dashboardOffset,
      );
      final int yesterdayBefore = (await env.meals.getMealsInRange(
        startInclusive: yesterday.start,
        endExclusive: yesterday.end,
      )).length;

      await tester.drag(
        find.byKey(historyPagerKey('today')),
        const Offset(600, 0),
      );
      await tester.pumpAndSettle();
      await scrollTodayUntilVisible(tester, find.byKey(todayQuickAddMealKey));
      await tester.tap(find.byKey(todayQuickAddMealKey));
      await tester.pumpAndSettle();

      // The capture screen announces the backfill target (1月4日 周日) —
      // the exact mistake this screen is now designed to surface…
      expect(find.textContaining('1月4日'), findsOneWidget);
      // …and one tap re-targets the meal into today.
      await tester.tap(find.byKey(captureChangeToTodayKey));
      await tester.pumpAndSettle();
      expect(find.textContaining('1月4日'), findsNothing);

      await tester.enterText(
        find.byKey(const Key('capture_text_field')),
        '其实是今天吃的',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('capture_submit_button')));
      await tester.pumpAndSettle();

      expect(find.byType(MealReviewScreen), findsOneWidget);
      await tester.ensureVisible(find.byKey(reviewSaveButtonKey));
      await tester.pump();
      await tester.tap(find.byKey(reviewSaveButtonKey));
      await tester.pumpAndSettle();

      // The meal recorded "now" of the pinned clock (today, 12:00 +08:00):
      // it lands in today's window, and yesterday's log stays untouched.
      final List<Meal> todayAfter = await env.meals.getMealsInRange(
        startInclusive: today.start,
        endExclusive: today.end,
      );
      expect(todayAfter, hasLength(todayBefore + 1));
      final List<Meal> yesterdayAfter = await env.meals.getMealsInRange(
        startInclusive: yesterday.start,
        endExclusive: yesterday.end,
      );
      expect(yesterdayAfter, hasLength(yesterdayBefore));
    });
  });
}

/// Scrolls the 今日 day view back towards the top (the totals card), the
/// opposite of [scrollTodayUntilVisible].
Future<void> scrollTodayUp(WidgetTester tester) async {
  await tester.drag(
    find
        .byWidgetPredicate(
          (Widget widget) =>
              widget is Scrollable &&
              widget.axisDirection == AxisDirection.down,
        )
        .first,
    const Offset(0, 600),
  );
  await tester.pumpAndSettle();
}
