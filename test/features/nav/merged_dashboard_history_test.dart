/// The merged 概览 tab's week and month history (the former 汇总 tab).
///
/// Drives the **real app shell** ([HaohaochifanApp] + the production router)
/// over the in-memory repository fakes with every time seam pinned to the
/// fixture instant (2026-01-05 12:00 +08:00), then switches the merged
/// dashboard's 日/周/月 switcher to the week and month views and drives the real
/// [HistoryPeriodPager] each one mounts:
///
/// * the week view opens on `本周` with the fixture week's cumulative totals
///   (10000 / 10152 / -152, 5 logged days, salt 4 / 5) and the task-26 chart;
/// * swiping the finger right reveals the PREVIOUS week (its date-range header,
///   its own totals, bars and the same dashed base-budget line) plus the
///   `回到本周` action, which returns to the current week;
/// * swiping left at the current week cannot reach the future, and `›` is
///   absent on it because there is no future week;
/// * a historical week with no meals shows the past-week empty state, not
///   `本周暂无记录`;
/// * the month view opens on `本月` with the fixture month's totals
///   (10000 / 10152 / -152, 5 logged days, salt 4 / 5), the previous month
///   labelled `2025年12月` and its own totals (4000 / 7916 / -3916), and its
///   `回到本月` action;
/// * each view keeps its own browsed period while the user switches between
///   them (the three pagers live in an IndexedStack), and the quick-add actions
///   — which always record "now" — exist only on the day view.
library;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:caldoo/core/time/date_windows.dart';
import 'package:caldoo/domain/models/models.dart';
import 'package:caldoo/core/ui/history_period_pager.dart';
import 'package:caldoo/features/dashboard/monthly/monthly_summary_view.dart';
import 'package:caldoo/features/dashboard/weekly/weekly_summary_view.dart';
import 'package:caldoo/features/nav/today_screen.dart';

import '../dashboard/monthly/_fixtures.dart' as monthly;
import '../dashboard/weekly/_fixtures.dart' as weekly;
import '_harness.dart';

/// The week view's pager instance id ([HistoryPeriodPager.id]).
const String weekPager = 'week';

/// The month view's pager instance id ([HistoryPeriodPager.id]).
const String monthPager = 'month';

/// The previous fixture week's Mon..Sun range, as the pager labels it.
const String previousWeekLabel = '2025年12月29日 - 1月4日';

/// The previous fixture month, as the pager labels it.
const String previousMonthLabel = '2025年12月';

/// A meal in the week BEFORE the fixture week: [dayIndex] 0 = Mon 2025-12-29.
MealWithItems _previousWeekMeal({
  required String id,
  required int dayIndex,
  required int kcal,
}) => (
  meal: Meal(
    id: id,
    timestamp: weekly
        .weeklyDayInstant(dayIndex)
        .subtract(const Duration(days: 7)),
    mealType: MealType.lunch,
  ),
  items: <MealItem>[
    MealItem(
      id: '$id-item',
      name: '食物-$id',
      grams: 100,
      kcal: kcal,
      carbG: 0,
      proteinG: 0,
      fatG: 0,
      saltG: 6,
      source: FoodSource.manual,
    ),
  ],
);

/// Seven meals Mon..Sun of the previous week: `500 + 600 + … + 1100` = **5600**
/// kcal, each with 6 g salt (2400 mg Na — over the 2000 mg ceiling, so 0
/// adherent days).
List<MealWithItems> previousWeekMeals() => <MealWithItems>[
  for (var i = 0; i < 7; i++)
    _previousWeekMeal(id: 'prev-$i', dayIndex: i, kcal: 500 + 100 * i),
];

/// The rendered [Text.data] behind [key] (offstage views are skipped by the
/// finder, so this never reaches the hidden pagers).
String _text(WidgetTester tester, Key key) =>
    tester.widget<Text>(find.byKey(key)).data!;

String _label(WidgetTester tester, String id) =>
    _text(tester, historyPeriodLabelKey(id));

IconButton _newerButton(WidgetTester tester, String id) =>
    tester.widget<IconButton>(find.byKey(historyNewerKey(id)));

IconButton _olderButton(WidgetTester tester, String id) =>
    tester.widget<IconButton>(find.byKey(historyOlderKey(id)));

void main() {
  late NavTestEnv env;

  setUp(() => env = NavTestEnv());
  tearDown(() => env.dispose());

  /// Switches the merged dashboard to the week view.
  Future<void> openWeek(WidgetTester tester) async {
    await tester.tap(find.byKey(todayViewWeekKey));
    await tester.pumpAndSettle();
  }

  /// Switches the merged dashboard to the month view.
  Future<void> openMonth(WidgetTester tester) async {
    await tester.tap(find.byKey(todayViewMonthKey));
    await tester.pumpAndSettle();
  }

  /// Swipes one page older (finger to the right) on [id]'s pager and settles.
  Future<void> swipeOlder(WidgetTester tester, String id) async {
    await tester.drag(find.byKey(historyPagerKey(id)), const Offset(600, 0));
    await tester.pumpAndSettle();
  }

  /// Seeds the fixture week plus the DIFFERENT previous week, so a past-week
  /// page's numbers can never be the current week's by accident.
  Future<void> seedTwoWeeks() async {
    await weekly.seedWeekly(
      meals: env.meals,
      exercises: env.exercises,
      profile: env.profile,
      mealGroups: <MealWithItems>[
        ...weekly.weeklyMeals(),
        ...previousWeekMeals(),
      ],
      exerciseEntries: weekly.weeklyExercises(),
    );
  }

  /// Seeds the fixture month plus the DIFFERENT previous month.
  Future<void> seedTwoMonths() async {
    await monthly.seedMonthly(
      meals: env.meals,
      exercises: env.exercises,
      profile: env.profile,
      mealGroups: <MealWithItems>[
        ...monthly.monthlyMeals(),
        ...monthly.previousMonthMeals(),
      ],
      exerciseEntries: monthly.monthlyExercises(),
    );
  }

  testWidgets('week view: 本周 header and the fixture cumulative totals', (
    WidgetTester tester,
  ) async {
    await seedTwoWeeks();
    await env.pump(tester);
    await openWeek(tester);

    expect(find.byKey(historyPagerKey(weekPager)), findsOneWidget);
    expect(_label(tester, weekPager), '本周');
    expect(find.text('本周汇总'), findsOneWidget);

    expect(_text(tester, weeklyTotalIntakeKey), '10000');
    expect(_text(tester, weeklyTotalBurnKey), '10152');
    expect(_text(tester, weeklyTotalBalanceKey), '-152');
    expect(_text(tester, weeklyLoggedDaysKey), '5');
    expect(_text(tester, weeklySaltAdherenceKey), '4 / 5');
    expect(find.byKey(weeklyEmptyStateKey), findsNothing);

    // At the current week: no back-to-now action and no future page, so the
    // › button is not mounted at all.
    expect(find.byKey(historyBackToNowKey(weekPager)), findsNothing);
    expect(find.byKey(historyNewerKey(weekPager)), findsNothing);
    expect(_olderButton(tester, weekPager).onPressed, isNotNull);

    // Quick-add actions record "now", so they exist only on the day view.
    expect(find.byKey(todayQuickAddMealKey), findsNothing);
    expect(find.byKey(todayQuickAddExerciseKey), findsNothing);

    debugPrint(
      'MERGED_DASH_QA view=周 header=${_label(tester, weekPager)} '
      'intake=${_text(tester, weeklyTotalIntakeKey)} -> PASS',
    );
  });

  testWidgets(
    'week view: swiping right reveals the previous week with its own data',
    (WidgetTester tester) async {
      await seedTwoWeeks();
      await env.pump(tester);
      await openWeek(tester);

      await swipeOlder(tester, weekPager);

      // The header now labels the past Mon..Sun range, with the back action.
      expect(_label(tester, weekPager), previousWeekLabel);
      expect(find.byKey(historyBackToNowKey(weekPager)), findsOneWidget);
      expect(find.widgetWithText(TextButton, '回到本周'), findsOneWidget);

      // Past-week wording, not the current-week title.
      expect(find.text('周汇总'), findsOneWidget);
      expect(find.text('本周汇总'), findsNothing);

      // The previous week's own cumulative totals.
      expect(_text(tester, weeklyTotalIntakeKey), '5600');
      expect(_text(tester, weeklyTotalBurnKey), '13853'); // 7 * 1979
      expect(_text(tester, weeklyTotalBalanceKey), '-8253'); // 5600 - 13853
      expect(_text(tester, weeklyLoggedDaysKey), '7');
      expect(_text(tester, weeklySaltAdherenceKey), '0 / 7');

      // The chart is the previous week's, and the dashed base-budget line (BMR,
      // exercise excluded) still renders for a historical week.
      final BarChart chart = tester.widget<BarChart>(
        find.byKey(weeklyChartKey),
      );
      expect(
        <double>[
          for (final BarChartGroupData group in chart.data.barGroups)
            group.barRods.first.toY,
        ],
        <double>[500, 600, 700, 800, 900, 1000, 1100],
      );
      final HorizontalLine line =
          chart.data.extraLinesData.horizontalLines.single;
      expect(line.y, 1979);
      expect(line.dashArray, <int>[6, 4]);
      expect(line.label.labelResolver(line), '基础代谢(不含运动)');

      expect(find.byKey(historyNewerKey(weekPager)), findsOneWidget);
      expect(_newerButton(tester, weekPager).onPressed, isNotNull);
      expect(_olderButton(tester, weekPager).onPressed, isNotNull);

      debugPrint(
        'MERGED_DASH_QA view=周 previousWeek label=$previousWeekLabel '
        'intake=${_text(tester, weeklyTotalIntakeKey)} -> PASS',
      );
    },
  );

  testWidgets('week view: 回到本周 returns to the current week and its totals', (
    WidgetTester tester,
  ) async {
    await seedTwoWeeks();
    await env.pump(tester);
    await openWeek(tester);

    await swipeOlder(tester, weekPager);
    expect(_text(tester, weeklyTotalIntakeKey), '5600');

    await tester.tap(find.byKey(historyBackToNowKey(weekPager)));
    await tester.pumpAndSettle();

    expect(_label(tester, weekPager), '本周');
    expect(find.text('本周汇总'), findsOneWidget);
    expect(_text(tester, weeklyTotalIntakeKey), '10000');
    expect(_text(tester, weeklyTotalBalanceKey), '-152');
    expect(find.byKey(historyBackToNowKey(weekPager)), findsNothing);
    expect(find.byKey(historyNewerKey(weekPager)), findsNothing);
  });

  testWidgets('week view: swiping left at the current week cannot reach now', (
    WidgetTester tester,
  ) async {
    await seedTwoWeeks();
    await env.pump(tester);
    await openWeek(tester);

    await tester.drag(
      find.byKey(historyPagerKey(weekPager)),
      const Offset(-600, 0),
    );
    await tester.pumpAndSettle();

    expect(_label(tester, weekPager), '本周');
    expect(_text(tester, weeklyTotalIntakeKey), '10000');
    expect(find.byKey(historyBackToNowKey(weekPager)), findsNothing);
    expect(find.byKey(historyNewerKey(weekPager)), findsNothing);
  });

  testWidgets('week view: the ‹ / › header buttons step back and forward', (
    WidgetTester tester,
  ) async {
    await seedTwoWeeks();
    await env.pump(tester);
    await openWeek(tester);

    expect(_label(tester, weekPager), '本周');
    expect(find.byKey(historyNewerKey(weekPager)), findsNothing);
    expect(_olderButton(tester, weekPager).onPressed, isNotNull);

    await tester.tap(find.byKey(historyOlderKey(weekPager)));
    await tester.pumpAndSettle();
    expect(_label(tester, weekPager), previousWeekLabel);
    expect(_text(tester, weeklyTotalIntakeKey), '5600');
    expect(_newerButton(tester, weekPager).onPressed, isNotNull);

    await tester.tap(find.byKey(historyNewerKey(weekPager)));
    await tester.pumpAndSettle();
    expect(_label(tester, weekPager), '本周');
    expect(_text(tester, weeklyTotalIntakeKey), '10000');
    expect(find.byKey(historyNewerKey(weekPager)), findsNothing);
  });

  testWidgets('week view: a historical week with no meals shows the past empty '
      'state', (WidgetTester tester) async {
    // Only the current week has data; the previous week is empty.
    await weekly.seedWeekly(
      meals: env.meals,
      exercises: env.exercises,
      profile: env.profile,
      mealGroups: weekly.weeklyMeals(),
      exerciseEntries: weekly.weeklyExercises(),
    );
    await env.pump(tester);
    await openWeek(tester);

    await swipeOlder(tester, weekPager);

    expect(_label(tester, weekPager), previousWeekLabel);
    expect(find.byKey(weeklyEmptyStateKey), findsOneWidget);
    expect(_text(tester, weeklyEmptyStateKey), '这一周暂无记录');
    expect(find.text('本周暂无记录'), findsNothing);
    expect(find.byKey(weeklyChartKey), findsNothing);
    expect(find.byKey(weeklyTotalIntakeKey), findsNothing);
  });

  testWidgets('month view: 本月 header and the fixture cumulative totals', (
    WidgetTester tester,
  ) async {
    await seedTwoMonths();
    await env.pump(tester);
    await openMonth(tester);

    expect(find.byKey(historyPagerKey(monthPager)), findsOneWidget);
    expect(_label(tester, monthPager), '本月');
    expect(find.text('本月汇总'), findsOneWidget);

    expect(_text(tester, monthlyTotalIntakeKey), '10000');
    expect(_text(tester, monthlyTotalBurnKey), '10152');
    expect(_text(tester, monthlyTotalBalanceKey), '-152');
    expect(_text(tester, monthlyLoggedDaysKey), '5');
    expect(_text(tester, monthlySaltAdherenceKey), '4 / 5');
    expect(find.byKey(monthlyEmptyStateKey), findsNothing);

    // At the current month: no back-to-now action and no future page, so the
    // › button is not mounted at all.
    expect(find.byKey(historyBackToNowKey(monthPager)), findsNothing);
    expect(find.byKey(historyNewerKey(monthPager)), findsNothing);
    expect(_olderButton(tester, monthPager).onPressed, isNotNull);

    // Quick-add actions record "now", so they exist only on the day view.
    expect(find.byKey(todayQuickAddMealKey), findsNothing);

    debugPrint(
      'MERGED_DASH_QA view=月 header=${_label(tester, monthPager)} '
      'intake=${_text(tester, monthlyTotalIntakeKey)} -> PASS',
    );
  });

  testWidgets('month view: swiping right reveals the previous month', (
    WidgetTester tester,
  ) async {
    await seedTwoMonths();
    await env.pump(tester);
    await openMonth(tester);

    await swipeOlder(tester, monthPager);

    // The header names the past calendar month, with the back action.
    expect(_label(tester, monthPager), previousMonthLabel);
    expect(find.byKey(historyBackToNowKey(monthPager)), findsOneWidget);
    expect(find.byKey(historyNewerKey(monthPager)), findsOneWidget);
    expect(find.widgetWithText(TextButton, '回到本月'), findsOneWidget);

    // Past-month wording, not the current-month title.
    expect(find.text('月汇总'), findsOneWidget);
    expect(find.text('本月汇总'), findsNothing);

    // The previous month's own cumulative totals: 4 meals x 1000 kcal = 4000,
    // burn 4 * 1979 = 7916 (the fixture's exercise belongs to the current
    // month), difference 4000 - 7916 = -3916, salt 0 adherent of 4.
    expect(_text(tester, monthlyTotalIntakeKey), '4000');
    expect(_text(tester, monthlyTotalBurnKey), '7916');
    expect(_text(tester, monthlyTotalBalanceKey), '-3916');
    expect(_text(tester, monthlyLoggedDaysKey), '4');
    expect(_text(tester, monthlySaltAdherenceKey), '0 / 4');

    // The chart is the previous month's: 31 daily intake bars, the dashed
    // base-budget line still at the profile's BMR.
    final BarChart chart = tester.widget<BarChart>(find.byKey(monthlyChartKey));
    expect(chart.data.barGroups.length, 31);
    expect(
      chart.data.barGroups.first.barRods.length,
      1,
      reason: 'the month chart draws intake bars only',
    );
    expect(chart.data.extraLinesData.horizontalLines.single.y, 1979);

    // The back action returns to the current month.
    await tester.tap(find.byKey(historyBackToNowKey(monthPager)));
    await tester.pumpAndSettle();
    expect(_label(tester, monthPager), '本月');
    expect(_text(tester, monthlyTotalIntakeKey), '10000');

    debugPrint(
      'MERGED_DASH_QA view=月 previousMonth label=$previousMonthLabel '
      'intake=4000 -> PASS',
    );
  });

  testWidgets('month view: a historical month with no meals shows the past '
      'empty state', (WidgetTester tester) async {
    await monthly.seedMonthly(
      meals: env.meals,
      exercises: env.exercises,
      profile: env.profile,
      mealGroups: monthly.monthlyMeals(),
      exerciseEntries: monthly.monthlyExercises(),
    );
    await env.pump(tester);
    await openMonth(tester);

    await swipeOlder(tester, monthPager);

    expect(_label(tester, monthPager), previousMonthLabel);
    expect(find.byKey(monthlyEmptyStateKey), findsOneWidget);
    expect(_text(tester, monthlyEmptyStateKey), '这一月暂无记录');
    expect(find.text('本月暂无记录'), findsNothing);
    expect(find.byKey(monthlyChartKey), findsNothing);
    expect(find.byKey(monthlyTotalIntakeKey), findsNothing);
  });

  testWidgets('each view keeps its own browsed period across switcher changes', (
    WidgetTester tester,
  ) async {
    // Only the week fixtures are seeded: this test is about the pagers' state,
    // and the month fixtures would land inside the week windows (a month and a
    // week overlap), which would make the week totals ambiguous.
    await seedTwoWeeks();
    await env.pump(tester);

    // Browse one DAY into the past, then one week, then one month.
    await tester.tap(find.byKey(historyOlderKey('today')));
    await tester.pumpAndSettle();
    expect(_label(tester, 'today'), isNot('今天'));

    await openWeek(tester);
    await swipeOlder(tester, weekPager);
    expect(_label(tester, weekPager), previousWeekLabel);
    await openMonth(tester);
    await swipeOlder(tester, monthPager);
    expect(_label(tester, monthPager), previousMonthLabel);

    // Switching back to 周 restores the week the user was reading, not 本周.
    await tester.tap(find.byKey(todayViewWeekKey));
    await tester.pumpAndSettle();
    expect(_label(tester, weekPager), previousWeekLabel);
    expect(_text(tester, weeklyTotalIntakeKey), '5600');
    // The month view was left on the previous month, too.
    await tester.tap(find.byKey(todayViewMonthKey));
    await tester.pumpAndSettle();
    expect(_label(tester, monthPager), previousMonthLabel);

    // And 日 is still the day the user had stepped back to, not 今天.
    await tester.tap(find.byKey(todayViewDayKey));
    await tester.pumpAndSettle();
    final String stepBackLabel = _label(tester, 'today');
    expect(stepBackLabel, isNot('今天'));
    expect(stepBackLabel, contains('周'));
  });
}
