/// The monthly summary dashboard widget test.
///
/// Drives the real providers against in-memory fakes and the fixed 2026-01
/// fixture. It mirrors the task-26 weekly view test for the new month card and
/// asserts, on the RENDERED `fl_chart` `BarChart`:
/// * exactly 31 calendar-day groups, each with **one intake bar** (the burn
///   rods are deliberately not plotted on a month — see the view's doc — so the
///   burn series stays in the tooltip and the totals);
/// * the dashed target line's `y` = the BMR 1979 (= the resolved BMR, exercise
///   EXCLUDED), its dash array and its `基础代谢(不含运动)` label;
/// * the bottom axis labels every fifth day (`1 6 11 16 21 26 31`), so 31 day
///   numbers do not collide at phone width;
/// * the legend (`摄入` + the target line, and no `消耗` item);
/// and on the metric rows: the month's CUMULATIVE total intake, total burn and
/// difference (whole kcal, never averages), logged days and salt adherence. The
/// exact numbers are printed to stdout for the record.
///
/// A second widget test browsed to the previous month proves the card is
/// month-agnostic: its title drops to `月汇总` and every number comes from the
/// browsed month's own keyed provider, not from the current month.
library;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:caldoo/core/providers/app_providers.dart';
import 'package:caldoo/core/time/date_windows.dart'
    show MealWithItems, monthDayKeysFor;
import 'package:caldoo/core/units/display_units.dart';
import 'package:caldoo/domain/models/models.dart';
import 'package:caldoo/features/dashboard/monthly/monthly_summary_providers.dart';
import 'package:caldoo/features/dashboard/monthly/monthly_summary_view.dart';
import 'package:caldoo/features/dashboard/period/period_chart.dart';
import 'package:caldoo/features/dashboard/period/period_summary.dart';

import '../../../data/repositories/fake_repositories.dart';
import '_fixtures.dart';

/// The display preference pair the kJ / sodium cases install.
const DisplayUnits metricUnits = DisplayUnits(
  energy: EnergyDisplay.kj,
  salt: SaltDisplay.sodium,
);

String _text(WidgetTester tester, Key key) =>
    tester.widget<Text>(find.byKey(key)).data!;

BarChart _chart(WidgetTester tester) =>
    tester.widget<BarChart>(find.byKey(monthlyChartKey));

/// The flattened text of a painted tooltip item (the item's own text plus its
/// styled spans), so tests can assert what the bubble actually reads.
String _tooltipText(BarTooltipItem item) => <String>[
  item.text,
  for (final TextSpan span in item.children ?? const <TextSpan>[])
    span.text ?? '',
].join();

/// The 2026-01 fixture's intake per 1-based day of month.
const Map<int, int> _fixtureIntakes = <int, int>{
  1: 2000,
  2: 1500,
  3: 2200,
  5: 1800,
  20: 2500,
};

void main() {
  late FakeMealRepository mealRepo;
  late FakeExerciseRepository exerciseRepo;
  late FakeProfileRepository profileRepo;
  late FakeWeightRepository weightRepo;

  setUp(() {
    mealRepo = FakeMealRepository();
    exerciseRepo = FakeExerciseRepository();
    profileRepo = FakeProfileRepository();
    weightRepo = FakeWeightRepository();
  });

  tearDown(() async {
    await mealRepo.dispose();
    await exerciseRepo.dispose();
    await profileRepo.dispose();
    await weightRepo.dispose();
  });

  /// Pumps the monthly dashboard over the fakes and returns the live container.
  ///
  /// [monthKey] / [isCurrentMonth] select the browsed month exactly like the
  /// merged 概览 screen's month pager does; [units] installs the display
  /// preference above the app (the default is the historical kcal + salt).
  Future<ProviderContainer> pumpMonthly(
    WidgetTester tester, {
    DateTime? monthKey,
    bool isCurrentMonth = true,
    DisplayUnits units = DisplayUnits.defaults,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mealRepositoryProvider.overrideWithValue(mealRepo),
          exerciseRepositoryProvider.overrideWithValue(exerciseRepo),
          profileRepositoryProvider.overrideWithValue(profileRepo),
          // The weight stream feeds the 体重变化 tile; the fake keeps the real
          // file database out of the widget tests.
          weightRepositoryProvider.overrideWithValue(weightRepo),
          monthlyClockProvider.overrideWithValue(monthlyClock()),
          monthlyOffsetProvider.overrideWithValue(monthlyOffset),
        ],
        child: DisplayScope(
          units: units,
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: MonthlySummaryView(
                  monthKey: monthKey,
                  isCurrentMonth: isCurrentMonth,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(
      tester.element(find.byType(MonthlySummaryView)),
    );
  }

  /// Seeds the fixture month (or both fixture and previous month when
  /// [includePreviousMonth] is set) and pumps the current month's card.
  Future<ProviderContainer> pumpSeededFixture(
    WidgetTester tester, {
    bool withProfile = true,
    DisplayUnits units = DisplayUnits.defaults,
  }) async {
    await seedMonthly(
      meals: mealRepo,
      exercises: exerciseRepo,
      profile: profileRepo,
      mealGroups: monthlyMeals(),
      exerciseEntries: monthlyExercises(),
      withProfile: withProfile,
    );
    return pumpMonthly(tester, units: units);
  }

  testWidgets(
    'fixed month: one intake bar per day, dashed 1979 base line, totals',
    (WidgetTester tester) async {
      await pumpSeededFixture(tester);

      // --- 31 day groups, ONE rod per group (no burn rods on the month). ---
      final BarChart chart = _chart(tester);
      final List<BarChartGroupData> groups = chart.data.barGroups;
      expect(groups.length, 31);
      expect(
        groups.every((BarChartGroupData g) => g.barRods.length == 1),
        isTrue,
        reason: 'the month plots intake only; burn stays in tooltip + totals',
      );
      expect(
        <double>[for (final BarChartGroupData g in groups) g.barRods.first.toY],
        <double>[
          for (var day = 1; day <= 31; day++)
            (_fixtureIntakes[day] ?? 0).toDouble(),
        ],
        reason: 'first rod = each calendar day\'s intake, in day order',
      );
      expect(
        groups.first.barRods.first.width,
        monthlyRodWidth,
        reason: 'narrower than the week card\'s 14 px so 31 rods never touch',
      );

      // --- Evenly spaced integer y-axis: maxY rounded up to a nice step. ---
      // max(2500 intake, 1979 base) = 2500 -> 2500 * 1.2 = 3000.
      expect(chart.data.maxY, 3000);
      expect(chart.data.minY, 0);
      expect(chart.data.titlesData.leftTitles.sideTitles.interval, 1000);

      // --- The bottom axis labels every fifth day only. ---
      expect(
        chart.data.titlesData.bottomTitles.sideTitles.interval,
        monthlyLabelEvery,
      );
      for (final String label in <String>[
        '1',
        '6',
        '11',
        '16',
        '21',
        '26',
        '31',
      ]) {
        expect(
          find.text(label),
          findsOneWidget,
          reason: 'day $label must be labelled on the month x axis',
        );
      }
      // A day between two labels is not rendered: 31 numbers would collide.
      expect(find.text('2'), findsNothing);
      expect(find.text('27'), findsNothing);

      // --- Dashed target line at the BMR (exercise excluded, goal ignored). ---
      final HorizontalLine line =
          chart.data.extraLinesData.horizontalLines.single;
      expect(line.y, 1979, reason: 'base = BMR override 1979');
      expect(line.y, isNot(closeTo(2236, 1e-9)));
      expect(line.dashArray, <int>[6, 4]);
      expect(line.label.show, isTrue);
      expect(line.label.labelResolver(line), '基础代谢(不含运动)');
      expect(find.byKey(monthlyTargetLegendKey), findsOneWidget);

      // --- Legend: 摄入 + 虚线 target, and deliberately no 消耗 item. ---
      expect(_text(tester, monthlyIntakeLegendKey), '摄入');
      expect(_text(tester, monthlyTargetLegendKey), '虚线：基础代谢(不含运动)');
      expect(find.text('消耗'), findsNothing);

      // --- Cumulative totals over LOGGED days only, whole kcal. ---
      expect(_text(tester, monthlyTotalIntakeKey), '10000');
      expect(_text(tester, monthlyTotalBurnKey), '10152'); // 5*1979 + 257
      expect(_text(tester, monthlyTotalBalanceKey), '-152'); // 10000 - 10152
      expect(_text(tester, monthlyLoggedDaysKey), '5'); // day 10 excluded
      expect(_text(tester, monthlySaltAdherenceKey), '4 / 5'); // 0.8
      expect(find.byKey(monthlyProfilePromptKey), findsNothing);

      // --- Card title: the current month. ---
      expect(find.text('本月汇总'), findsOneWidget);

      debugPrint(
        'MONTH_QA intakeBars=${<double>[for (final BarChartGroupData g in groups) g.barRods.first.toY]} targetLineY=${line.y} dash=${line.dashArray} '
        'label=${line.label.labelResolver(line)} '
        'totalIntake=${_text(tester, monthlyTotalIntakeKey)} '
        'totalBurn=${_text(tester, monthlyTotalBurnKey)} '
        'difference=${_text(tester, monthlyTotalBalanceKey)} '
        'loggedDays=${_text(tester, monthlyLoggedDaysKey)} '
        'saltAdherence=${_text(tester, monthlySaltAdherenceKey)} -> PASS',
      );
    },
  );

  testWidgets('the top y-axis label does not overlap the 「本月汇总」 title', (
    WidgetTester tester,
  ) async {
    await pumpSeededFixture(tester);

    final Finder title = find.text('本月汇总');
    final Finder topLabel = find.text('3000');
    expect(title, findsOneWidget);
    expect(topLabel, findsOneWidget);

    final Rect titleRect = tester.getRect(title);
    final Rect labelRect = tester.getRect(topLabel);
    expect(
      labelRect.top,
      greaterThanOrEqualTo(titleRect.bottom),
      reason: 'the top y-axis label must sit below the title, not on top of it',
    );

    // The chart itself keeps the week card's height so the two views match.
    expect(tester.getSize(find.byKey(monthlyChartKey)).height, 220);

    debugPrint(
      'MONTH_QA titleBottom=${titleRect.bottom} '
      'topLabelTop=${labelRect.top} -> PASS',
    );
  });

  testWidgets('empty month renders the empty state, not a crash', (
    WidgetTester tester,
  ) async {
    // A profile exists, but no meal and no exercise is logged this month.
    await seedMonthly(
      meals: mealRepo,
      exercises: exerciseRepo,
      profile: profileRepo,
    );

    await pumpMonthly(tester);

    expect(find.byKey(monthlyEmptyStateKey), findsOneWidget);
    expect(find.text('本月暂无记录'), findsOneWidget);
    expect(find.byType(BarChart), findsNothing);
    expect(find.byKey(monthlyTotalIntakeKey), findsNothing);

    debugPrint('MONTH_QA empty-month -> empty state (no chart) -> PASS');
  });

  testWidgets('a past empty month says 这一月暂无记录', (WidgetTester tester) async {
    await seedMonthly(
      meals: mealRepo,
      exercises: exerciseRepo,
      profile: profileRepo,
    );

    await pumpMonthly(
      tester,
      monthKey: DateTime.utc(2025, 12, 1),
      isCurrentMonth: false,
    );

    await tester.pumpAndSettle();

    expect(find.byKey(monthlyEmptyStateKey), findsOneWidget);
    expect(find.text('这一月暂无记录'), findsOneWidget);

    debugPrint('MONTH_QA past-empty-month -> 这一月暂无记录 -> PASS');
  });

  testWidgets(
    'logged month without a profile: intake bars stay, budget hidden',
    (WidgetTester tester) async {
      final ProviderContainer container = await pumpSeededFixture(
        tester,
        withProfile: false,
      );

      // Intake bars only: no burn rods, no target line, no target legend.
      final BarChart chart = _chart(tester);
      expect(chart.data.barGroups.length, 31);
      expect(
        chart.data.barGroups.every(
          (BarChartGroupData g) => g.barRods.length == 1,
        ),
        isTrue,
      );
      expect(chart.data.extraLinesData.horizontalLines, isEmpty);
      expect(find.byKey(monthlyTargetLegendKey), findsNothing);

      // Total burn and the difference need a budget -> the em dash, no values.
      expect(find.byKey(monthlyTotalBurnKey), findsNothing);
      expect(find.byKey(monthlyTotalBalanceKey), findsNothing);
      expect(find.text('—'), findsNWidgets(2));
      expect(find.byKey(monthlyProfilePromptKey), findsOneWidget);

      // Profile-independent metrics stay.
      expect(_text(tester, monthlyTotalIntakeKey), '10000');
      expect(_text(tester, monthlySaltAdherenceKey), '4 / 5');
      expect(
        container.read(monthlySummaryProvider),
        isA<PeriodSummaryNoProfile>(),
      );

      debugPrint('MONTH_QA no-profile -> intake only + 完善资料 -> PASS');
    },
  );

  testWidgets(
    'kJ + sodium preference: rods, axis, target line and totals switch units',
    (WidgetTester tester) async {
      await pumpSeededFixture(tester, units: metricUnits);

      // --- One intake rod per day, converted to kJ: day 1 2000 -> 8368,
      // day 2 1500 -> 6276, day 3 2200 -> 9205, day 5 1800 -> 7531,
      // day 20 2500 -> 10460, every other day 0. ---
      final BarChart chart = _chart(tester);
      expect(
        <double>[
          for (final BarChartGroupData g in chart.data.barGroups)
            g.barRods.first.toY,
        ],
        <double>[
          for (var day = 1; day <= 31; day++)
            switch (_fixtureIntakes[day] ?? 0) {
              2000 => 8368,
              1500 => 6276,
              2200 => 9205,
              1800 => 7531,
              2500 => 10460,
              _ => 0,
            },
        ],
      );

      // --- The axis is built from the converted values: 10460 kJ -> maxY
      // 15000 at a 5000 step with integer kJ tick labels. ---
      expect(chart.data.maxY, 15000);
      expect(chart.data.minY, 0);
      expect(chart.data.titlesData.leftTitles.sideTitles.interval, 5000);
      expect(find.text('15000'), findsOneWidget);

      // --- The dashed target line moves with the axis (base BMR 1979). ---
      final HorizontalLine line =
          chart.data.extraLinesData.horizontalLines.single;
      expect(line.y, 8280);
      expect(line.label.labelResolver(line), '基础代谢(不含运动)');

      // --- Totals switch value AND unit; the salt label follows sodium. ---
      expect(_text(tester, monthlyTotalIntakeKey), '41840');
      expect(_text(tester, monthlyTotalBurnKey), '42476');
      expect(_text(tester, monthlyTotalBalanceKey), '-636');
      expect(find.text('kJ'), findsNWidgets(3));
      expect(find.text('kcal'), findsNothing);
      expect(_text(tester, monthlyLoggedDaysKey), '5');
      expect(_text(tester, monthlySaltAdherenceKey), '4 / 5');
      expect(find.text('钠达标'), findsOneWidget);
      expect(find.text('盐达标'), findsNothing);

      debugPrint(
        'MONTH_UNITS_QA intakeBars=${<double>[for (final BarChartGroupData g in chart.data.barGroups) g.barRods.first.toY]} '
        'targetLineY=${line.y} maxY=${chart.data.maxY} '
        'totalIntake=${_text(tester, monthlyTotalIntakeKey)} '
        'totalBurn=${_text(tester, monthlyTotalBurnKey)} '
        'saltAdherenceLabel=钠达标 -> PASS',
      );
    },
  );

  testWidgets('loaded chart without a profile in kJ mode', (
    WidgetTester tester,
  ) async {
    await pumpSeededFixture(tester, withProfile: false, units: metricUnits);

    // The profile-dependent placeholder units follow the preference too.
    expect(find.text('—'), findsNWidgets(2));
    expect(
      find.text('kJ'),
      findsNWidgets(3),
      reason: 'intake + 2 placeholders',
    );
    expect(find.text('kcal'), findsNothing);
    expect(_text(tester, monthlyTotalIntakeKey), '41840');
    expect(find.byKey(monthlyTotalBurnKey), findsNothing);
    expect(find.byKey(monthlyTotalBalanceKey), findsNothing);
    expect(find.byKey(monthlyProfilePromptKey), findsOneWidget);
    expect(find.text('钠达标'), findsOneWidget);
  });

  testWidgets('loading renders a spinner, not a guessed number', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          monthlySummaryProvider.overrideWithValue(
            const PeriodSummaryLoading(),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: MonthlySummaryView())),
      ),
    );
    // A single frame: pumpAndSettle would never finish on an indeterminate
    // spinner.
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byKey(monthlyEmptyStateKey), findsNothing);
    expect(find.byType(BarChart), findsNothing);

    debugPrint('MONTH_QA loading -> spinner -> PASS');
  });

  testWidgets(
    'browsing a past month: 月汇总 wording and that month\'s own numbers',
    (WidgetTester tester) async {
      // Both the fixture month and the month before it have data, with
      // distinguishable totals (2025-12: 4 x 1000 kcal, 4 logged days).
      await seedMonthly(
        meals: mealRepo,
        exercises: exerciseRepo,
        profile: profileRepo,
        mealGroups: <MealWithItems>[...monthlyMeals(), ...previousMonthMeals()],
        exerciseEntries: monthlyExercises(),
      );

      await pumpMonthly(
        tester,
        monthKey: DateTime.utc(2025, 12, 1),
        isCurrentMonth: false,
      );

      // Title drops to the past-month wording.
      expect(find.text('月汇总'), findsOneWidget);
      expect(find.text('本月汇总'), findsNothing);

      // The browsed month's own data: 2025-12 has 31 days too.
      final BarChart chart = _chart(tester);
      expect(chart.data.barGroups.length, 31);
      expect(
        <double>[
          for (final BarChartGroupData g in chart.data.barGroups)
            g.barRods.first.toY,
        ],
        <double>[for (var day = 1; day <= 31; day++) day >= 28 ? 1000.0 : 0.0],
        reason: '2025-12-28..31 are the previous-month fixture meals',
      );

      // Cumulative totals of the BROWSED month, not of the current one.
      expect(_text(tester, monthlyTotalIntakeKey), '4000');
      expect(_text(tester, monthlyTotalBurnKey), '7916'); // 4 logged * 1979
      expect(_text(tester, monthlyTotalBalanceKey), '-3916');
      expect(_text(tester, monthlyLoggedDaysKey), '4');
      expect(_text(tester, monthlySaltAdherenceKey), '0 / 4'); // all over Na

      debugPrint(
        'MONTH_QA pastMonth=2025-12 intake=${_text(tester, monthlyTotalIntakeKey)} '
        'burn=${_text(tester, monthlyTotalBurnKey)} '
        'difference=${_text(tester, monthlyTotalBalanceKey)} '
        'loggedDays=${_text(tester, monthlyLoggedDaysKey)} '
        'saltAdherence=${_text(tester, monthlySaltAdherenceKey)} -> PASS',
      );
    },
  );

  group('month chart construction and tooltip content', () {
    DayRollup dayFor(int day) => DayRollup(
      date: monthlyDayKey(day),
      intakeKcal: _fixtureIntakes[day] ?? 0,
      exerciseKcal: day == 3
          ? 257
          : day == 10
          ? 300
          : 0,
      mealCount: (_fixtureIntakes[day] ?? 0) > 0 ? 1 : 0,
    );

    List<DayRollup> month() => <DayRollup>[
      for (var day = 1; day <= 31; day++) dayFor(day),
    ];

    test('31 groups, one rod each, 6 px wide, maxY 3000 at a 1000 step', () {
      final BarChartData data = monthlyChartData(days: month(), bmrKcal: 1979);
      expect(data.barGroups.length, 31);
      expect(
        data.barGroups.every((BarChartGroupData g) => g.barRods.length == 1),
        isTrue,
      );
      expect(data.barGroups.first.barRods.first.width, 6);
      expect(data.maxY, 3000);
      expect(data.minY, 0);
      expect(data.titlesData.leftTitles.sideTitles.interval, 1000);
      expect(data.titlesData.bottomTitles.sideTitles.interval, 5);
      expect(data.extraLinesData.horizontalLines.single.y, 1979);
      debugPrint(
        'MONTH_QA construction maxY=${data.maxY} '
        'interval=${data.titlesData.leftTitles.sideTitles.interval} '
        'groups=${data.barGroups.length} -> PASS',
      );
    });

    test('leap-year February is 29 groups and never hard-codes 31', () {
      // 2028 is a leap year: monthDayKeysFor must hand the chart 29 days (the
      // old hard-coded-31 risk), and a non-leap February 28.
      final List<DayRollup> february2028 = <DayRollup>[
        for (final DateTime key in monthDayKeysFor(DateTime.utc(2028, 2)))
          DayRollup(date: key, intakeKcal: 100, mealCount: 1),
      ];
      expect(february2028, hasLength(29));
      final BarChartData leap = monthlyChartData(
        days: february2028,
        bmrKcal: 1979,
      );
      expect(leap.barGroups.length, 29);

      final List<DayRollup> february2026 = <DayRollup>[
        for (final DateTime key in monthDayKeysFor(DateTime.utc(2026, 2)))
          DayRollup(date: key, intakeKcal: 100, mealCount: 1),
      ];
      expect(february2026, hasLength(28));
      expect(
        monthlyChartData(days: february2026, bmrKcal: 1979).barGroups.length,
        28,
      );
    });

    test('the month hit band stays narrower than the gap between rods', () {
      // 31 rods sit ~9 px apart on a phone. fl_chart's hit test takes the FIRST
      // group whose expanded band contains the press, so a horizontal band of 6
      // (the week card's value) would attribute the left half of every bar to
      // the previous day. The month card must keep it at 1.
      final BarChartData data = monthlyChartData(days: month(), bmrKcal: 1979);
      // [EdgeInsets.horizontal] is left + right, so 1 px a side is 2 px total.
      final EdgeInsets band = data.barTouchData.touchExtraThreshold;
      expect(band.left, 1);
      expect(band.right, 1);
      expect(band.top, 16);
      expect(band.bottom, 16);
      expect(
        band.horizontal,
        lessThan(monthlyRodWidth + 3),
        reason: 'the total band must stay narrower than a 9 px slot',
      );

      // And the rod narrows below the tuned 6 px when 31 slots get tight.
      expect(monthlyRodWidthFor(plotWidth: 278, count: 31), monthlyRodWidth);
      expect(monthlyRodWidthFor(plotWidth: 208, count: 31), lessThan(5));
      expect(monthlyRodWidthFor(plotWidth: 100, count: 31), greaterThan(0));
    });

    test('x labels are the day-of-month numbers', () {
      expect(monthlyDayLabels(month()), <String>[
        for (var day = 1; day <= 31; day++) '$day',
      ]);
    });

    test('the tooltip title is the calendar date, not a weekday', () {
      expect(monthlyTooltipTitle(dayFor(5)), '1月5日');
      expect(monthlyTooltipTitle(dayFor(20)), '1月20日');
    });

    test(
      'tooltip rows: date + intake + burn + signed difference, whole kcal',
      () {
        final BarChartData data = monthlyChartData(
          days: month(),
          bmrKcal: 1979,
          tooltipTheme: PeriodTooltipTheme.light,
        );
        final BarTouchTooltipData touch = data.barTouchData.touchTooltipData;
        expect(touch.fitInsideHorizontally, isTrue);
        expect(touch.fitInsideVertically, isTrue);
        expect(touch.tooltipMargin, 6);

        // Day 20: 2500 intake, 1979 budget, +521 surplus.
        final BarChartGroupData group = data.barGroups[19];
        final BarTooltipItem item = touch.getTooltipItem(
          group,
          19,
          group.barRods.first,
          0,
        )!;
        final String text = _tooltipText(item);
        expect(text, contains('1月20日'));
        expect(text, contains('摄入 2500 kcal'));
        expect(text, contains('消耗 1979 kcal'));
        expect(text, contains('差值 521 kcal'));
        // fl_chart's default item would have painted the raw double.
        expect(text, isNot(contains('2500.0')));

        // Day 3 carries its 257 exercise: burn 2236, difference -36.
        final BarChartGroupData day3 = data.barGroups[2];
        final String day3Text = _tooltipText(
          touch.getTooltipItem(day3, 2, day3.barRods.first, 0)!,
        );
        expect(day3Text, contains('1月3日'));
        expect(day3Text, contains('消耗 2236 kcal'));
        expect(day3Text, contains('差值 -36 kcal'));

        debugPrint(
          'MONTH_QA tooltip text=${text.replaceAll('\n', ' | ')} -> PASS',
        );
      },
    );

    test('an unlogged day reports 未记录 instead of zero rows', () {
      final BarChartData data = monthlyChartData(days: month(), bmrKcal: 1979);
      final BarChartGroupData group = data.barGroups[6]; // day 7, unlogged
      final String text = _tooltipText(
        data.barTouchData.touchTooltipData.getTooltipItem(
          group,
          6,
          group.barRods.first,
          0,
        )!,
      );
      expect(text, contains('1月7日'));
      expect(text, contains('未记录'));
      expect(text, isNot(contains('摄入')));
    });

    test('without a profile the tooltip only reports intake', () {
      final BarChartData data = monthlyChartData(days: month(), bmrKcal: null);
      expect(data.extraLinesData.horizontalLines, isEmpty);
      final BarChartGroupData group = data.barGroups[0]; // day 1
      final String text = _tooltipText(
        data.barTouchData.touchTooltipData.getTooltipItem(
          group,
          0,
          group.barRods.first,
          0,
        )!,
      );
      expect(text, contains('摄入 2000 kcal'));
      expect(text, isNot(contains('消耗')));
      expect(text, isNot(contains('差值')));
    });

    test('the rendered chart uses the legible light tooltip bubble', () {
      final BarChartData data = monthlyChartData(
        days: month(),
        bmrKcal: 1979,
        tooltipTheme: PeriodTooltipTheme.light,
      );
      expect(
        data.barTouchData.touchTooltipData.getTooltipColor(data.barGroups[0]),
        PeriodTooltipTheme.light.background,
      );
    });

    test('the kJ preference converts the rods, axis top and target line', () {
      const DisplayUnits kj = DisplayUnits(energy: EnergyDisplay.kj);
      final BarChartData data = monthlyChartData(
        days: month(),
        bmrKcal: 1979,
        units: kj,
      );
      expect(
        <double>[
          for (final BarChartGroupData g in data.barGroups) g.barRods.first.toY,
        ],
        <double>[
          for (var day = 1; day <= 31; day++)
            switch (_fixtureIntakes[day] ?? 0) {
              2000 => 8368,
              1500 => 6276,
              2200 => 9205,
              1800 => 7531,
              2500 => 10460,
              _ => 0,
            },
        ],
      );
      // max(10460, 8280) * 1.2 = 12552 -> whole 5000 steps -> 15000.
      expect(data.maxY, 15000);
      expect(data.titlesData.leftTitles.sideTitles.interval, 5000);
      expect(data.extraLinesData.horizontalLines.single.y, 8280);
      // The burn series stays off the plot in kJ too.
      expect(
        data.barGroups.every((BarChartGroupData g) => g.barRods.length == 1),
        isTrue,
      );
      debugPrint(
        'MONTH_UNITS maxY=${data.maxY} '
        'targetY=${data.extraLinesData.horizontalLines.single.y} -> PASS',
      );
    });

    test('the tooltip renders kJ while its model rows keep kcal', () {
      const DisplayUnits kj = DisplayUnits(energy: EnergyDisplay.kj);
      final BarChartData data = monthlyChartData(
        days: month(),
        bmrKcal: 1979,
        units: kj,
        tooltipTheme: PeriodTooltipTheme.light,
      );
      final BarTouchTooltipData touch = data.barTouchData.touchTooltipData;

      // Day 20: 2500 intake, 1979 budget, +521 surplus.
      final BarChartGroupData group = data.barGroups[19];
      final String text = _tooltipText(
        touch.getTooltipItem(group, 19, group.barRods.first, 0)!,
      );
      expect(text, contains('1月20日'));
      expect(text, contains('摄入 10460 kJ'));
      expect(text, contains('消耗 8280 kJ'));
      expect(text, contains('差值 2180 kJ'));
      expect(text, isNot(contains('kcal')));

      // Day 3 carries its 257 exercise: burn 2236 -> 9355, diff -36 -> -151.
      final BarChartGroupData day3 = data.barGroups[2];
      final String day3Text = _tooltipText(
        touch.getTooltipItem(day3, 2, day3.barRods.first, 0)!,
      );
      expect(day3Text, contains('消耗 9355 kJ'));
      expect(day3Text, contains('差值 -151 kJ'));

      // The tooltip model keeps the canonical kcal ints.
      final PeriodDayTooltip model = periodDayTooltip(
        day: dayFor(20),
        bmrKcal: 1979,
        title: monthlyTooltipTitle(dayFor(20)),
        units: kj,
      );
      expect(
        <int>[for (final PeriodTooltipRow row in model.rows) row.kcal],
        <int>[2500, 1979, 521],
      );
      debugPrint('MONTH_UNITS tooltip=${text.replaceAll('\n', ' | ')} -> PASS');
    });
  });
}
