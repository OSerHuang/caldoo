/// Task 26 (MANUAL-QA CHANNEL): the weekly summary dashboard widget test.
///
/// Drives the real providers against in-memory fakes and the fixed Mon..Sun
/// fixture. It asserts, on the RENDERED `fl_chart` `BarChart`:
/// * exactly 7 Mon..Sun groups, each with an intake bar and a burn bar, their
///   `toY` values being that day's intake and that day's budget (BMR +
///   exercise) — unlogged days plot nothing;
/// * the dashed target line's `y` = the BASE budget 1979 (= BMR, exercise
///   EXCLUDED), its dash array and its `基础代谢(不含运动)` label;
/// * the bar legend items (`摄入` / `消耗`);
/// and on the metric rows: the week's CUMULATIVE total intake, total burn and
/// difference (whole kcal, never averages), logged days, salt adherence. The
/// exact numbers are printed to stdout for the record.
library;

import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:caldoo/core/providers/app_providers.dart';
import 'package:caldoo/core/time/day_tick_provider.dart';
import 'package:caldoo/core/units/display_units.dart';
import 'package:caldoo/domain/models/day_rollup.dart';
import 'package:caldoo/features/dashboard/weekly/weekly_summary.dart';
import 'package:caldoo/features/dashboard/weekly/weekly_summary_providers.dart';
import 'package:caldoo/features/dashboard/weekly/weekly_summary_view.dart';

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
    tester.widget<BarChart>(find.byType(BarChart));

/// Seven Mon..Sun rollups carrying the given daily intakes (index 0 = Mon);
/// any non-zero intake counts as a logged day.
List<DayRollup> _week(List<int> intakes) => <DayRollup>[
  for (var i = 0; i < intakes.length; i++)
    DayRollup(
      date: weeklyDayInstant(i),
      intakeKcal: intakes[i],
      mealCount: intakes[i] > 0 ? 1 : 0,
    ),
];

/// The flattened text of a painted tooltip item (the item's own text plus its
/// styled spans), so tests can assert what the bubble actually reads.
String _tooltipText(BarTooltipItem item) => <String>[
  item.text,
  for (final TextSpan span in item.children ?? const <TextSpan>[])
    span.text ?? '',
].join();

/// WCAG 2.1 relative-luminance contrast ratio between two opaque colours.
double _contrastRatio(Color a, Color b) {
  final double la = a.computeLuminance();
  final double lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  late FakeMealRepository mealRepo;
  late FakeExerciseRepository exerciseRepo;
  late FakeProfileRepository profileRepo;

  setUp(() {
    mealRepo = FakeMealRepository();
    exerciseRepo = FakeExerciseRepository();
    profileRepo = FakeProfileRepository();
  });

  tearDown(() async {
    await mealRepo.dispose();
    await exerciseRepo.dispose();
    await profileRepo.dispose();
  });

  /// Pumps the weekly dashboard over the fakes and returns the live container.
  ///
  /// [units] installs the display preference above the app; the default
  /// (kcal + salt) is what the historical assertions run under.
  Future<ProviderContainer> pumpWeekly(
    WidgetTester tester, {
    DisplayUnits units = DisplayUnits.defaults,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mealRepositoryProvider.overrideWithValue(mealRepo),
          exerciseRepositoryProvider.overrideWithValue(exerciseRepo),
          profileRepositoryProvider.overrideWithValue(profileRepo),
          weeklyClockProvider.overrideWithValue(weeklyClock()),
          weeklyOffsetProvider.overrideWithValue(weeklyOffset),
          // The current-week pointer follows the day-tick signal; these tests
          // pin the week instead, so the tick stays quiet (and its production
          // Timer out of the fake-async zone).
          dayTickProvider.overrideWith((ref) => const Stream<int>.empty()),
        ],
        child: DisplayScope(
          units: units,
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(child: WeeklySummaryView()),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(
      tester.element(find.byType(WeeklySummaryView)),
    );
  }

  testWidgets(
    'fixed week: intake + burn bars, dashed 1979 base line, cumulative totals',
    (WidgetTester tester) async {
      await seedWeekly(
        meals: mealRepo,
        exercises: exerciseRepo,
        profile: profileRepo,
        mealGroups: weeklyMeals(),
        exerciseEntries: weeklyExercises(),
      );

      await pumpWeekly(tester);

      // --- 7 groups, each with an intake bar and a burn bar. ---
      final BarChart chart = _chart(tester);
      final List<BarChartGroupData> groups = chart.data.barGroups;
      expect(groups.length, 7);
      expect(
        <double>[for (final BarChartGroupData g in groups) g.barRods.first.toY],
        <double>[2000, 1500, 2200, 1800, 2500, 0, 0],
        reason:
            'first rod = Mon..Sun daily intake; Sat/Sun have no logged meal',
      );
      expect(
        <double>[for (final BarChartGroupData g in groups) g.barRods.last.toY],
        <double>[
          1979,
          1979,
          2236, // Wed carries its 257 exercise on top of the BMR
          1979,
          1979,
          0, // Sat is exercise-only -> not a logged day, so no burn bar
          0,
        ],
        reason: 'second rod = each logged day\'s budget (BMR + exercise)',
      );

      // --- Evenly spaced integer y-axis: maxY rounded up to a nice interval,
      // so no fractional tick sits on top of the tick below it. ---
      expect(chart.data.maxY, 3000);
      expect(chart.data.minY, 0);
      expect(chart.data.titlesData.leftTitles.sideTitles.interval, 1000);

      // --- Dashed target line at the BASE budget (exercise excluded). ---
      final HorizontalLine line =
          chart.data.extraLinesData.horizontalLines.single;
      expect(line.y, 1979, reason: 'base = BMR override 1979');
      expect(
        line.y,
        isNot(closeTo(2236, 1e-9)),
        reason: 'must exclude Wed exercise (1979 + 257 = 2236)',
      );
      expect(line.dashArray, <int>[6, 4]);
      expect(line.color, weeklyTargetLineColor);
      expect(line.label.show, isTrue);
      expect(line.label.labelResolver(line), '基础代谢(不含运动)');

      // --- Legend: 摄入 / 消耗 / 虚线 target. ---
      expect(_text(tester, weeklyIntakeLegendKey), '摄入');
      expect(_text(tester, weeklyBurnLegendKey), '消耗');
      expect(_text(tester, weeklyTargetLegendKey), '虚线：基础代谢(不含运动)');

      // --- Cumulative totals over LOGGED days only, whole kcal. ---
      expect(_text(tester, weeklyTotalIntakeKey), '10000');
      expect(_text(tester, weeklyTotalBurnKey), '10152'); // 5*1979 + 257
      expect(_text(tester, weeklyTotalBalanceKey), '-152'); // 10000 - 10152
      expect(_text(tester, weeklyLoggedDaysKey), '5'); // Sat excluded
      expect(_text(tester, weeklySaltAdherenceKey), '4 / 5'); // 0.8
      expect(find.byKey(weeklyProfilePromptKey), findsNothing);

      debugPrint(
        'TASK26_QA intakeBars=${<double>[for (final BarChartGroupData g in groups) g.barRods.first.toY]} burnBars=${<double>[for (final BarChartGroupData g in groups) g.barRods.last.toY]} targetLineY=${line.y} dash=${line.dashArray} '
        'label=${line.label.labelResolver(line)} '
        'totalIntake=${_text(tester, weeklyTotalIntakeKey)} '
        'totalBurn=${_text(tester, weeklyTotalBurnKey)} '
        'difference=${_text(tester, weeklyTotalBalanceKey)} '
        'loggedDays=${_text(tester, weeklyLoggedDaysKey)} '
        'saltAdherence=${_text(tester, weeklySaltAdherenceKey)} -> PASS',
      );
    },
  );

  testWidgets('the top y-axis label does not overlap the 「本周汇总」 title', (
    WidgetTester tester,
  ) async {
    await seedWeekly(
      meals: mealRepo,
      exercises: exerciseRepo,
      profile: profileRepo,
      mealGroups: weeklyMeals(),
      exerciseEntries: weeklyExercises(),
    );

    await pumpWeekly(tester);

    // maxY = max(2500 intake, 2236 burn, 1979 base) * 1.2 = 3000,
    // rounded up to a whole 1000 step -> the topmost left y-axis label is
    // '3000' (the one that used to be painted over the card title).
    final Finder title = find.text('本周汇总');
    final Finder topLabel = find.text('3000');
    expect(title, findsOneWidget);
    expect(topLabel, findsOneWidget);

    final BarChart chart = _chart(tester);
    expect(chart.data.maxY, 3000);
    expect(chart.data.titlesData.leftTitles.sideTitles.interval, 1000);

    final Rect titleRect = tester.getRect(title);
    final Rect labelRect = tester.getRect(topLabel);
    expect(
      labelRect.top,
      greaterThanOrEqualTo(titleRect.bottom),
      reason: 'the top y-axis label must sit below the title, not on top of it',
    );

    // The fix must not drop the chart content: still 7 groups, two rods each.
    expect(_chart(tester).data.barGroups.length, 7);
    expect(_chart(tester).data.barGroups.first.barRods.length, 2);

    debugPrint(
      'TASK26_QA titleBottom=${titleRect.bottom} '
      'topLabelTop=${labelRect.top} -> PASS',
    );
  });

  testWidgets('empty week renders the empty state, not a crash', (
    WidgetTester tester,
  ) async {
    // A profile exists, but no meal and no exercise is logged this week.
    await seedWeekly(
      meals: mealRepo,
      exercises: exerciseRepo,
      profile: profileRepo,
    );

    await pumpWeekly(tester);

    expect(find.byKey(weeklyEmptyStateKey), findsOneWidget);
    expect(find.byType(BarChart), findsNothing);
    expect(find.byKey(weeklyTotalIntakeKey), findsNothing);

    debugPrint('TASK26_QA empty-week -> empty state (no chart) -> PASS');
  });

  testWidgets(
    'logged week without a profile: intake bars stay, burn + difference hidden',
    (WidgetTester tester) async {
      await seedWeekly(
        meals: mealRepo,
        exercises: exerciseRepo,
        profile: profileRepo,
        mealGroups: weeklyMeals(),
        exerciseEntries: weeklyExercises(),
        withProfile: false,
      );

      final ProviderContainer container = await pumpWeekly(tester);

      // Intake bars only; no burn bars, no target line, no burn legend.
      expect(_chart(tester).data.barGroups.length, 7);
      expect(_chart(tester).data.barGroups.first.barRods.length, 1);
      expect(_chart(tester).data.extraLinesData.horizontalLines, isEmpty);
      expect(find.byKey(weeklyBurnLegendKey), findsNothing);
      expect(find.byKey(weeklyTargetLegendKey), findsNothing);

      // Total burn and the difference need a budget -> the em dash, no values.
      expect(find.byKey(weeklyTotalBurnKey), findsNothing);
      expect(find.byKey(weeklyTotalBalanceKey), findsNothing);
      expect(find.text('—'), findsNWidgets(2));
      expect(find.byKey(weeklyProfilePromptKey), findsOneWidget);

      // Profile-independent metrics stay.
      expect(_text(tester, weeklyTotalIntakeKey), '10000');
      expect(_text(tester, weeklySaltAdherenceKey), '4 / 5');
      expect(
        container.read(weeklySummaryProvider),
        isA<WeeklySummaryNoProfile>(),
      );
    },
  );

  testWidgets(
    'kJ + sodium preference: bars, axis, target line and totals switch units',
    (WidgetTester tester) async {
      await seedWeekly(
        meals: mealRepo,
        exercises: exerciseRepo,
        profile: profileRepo,
        mealGroups: weeklyMeals(),
        exerciseEntries: weeklyExercises(),
      );

      await pumpWeekly(tester, units: metricUnits);

      // --- The rods are converted to kJ, per day, before plotting. ---
      final BarChart chart = _chart(tester);
      final List<BarChartGroupData> groups = chart.data.barGroups;
      expect(
        <double>[for (final BarChartGroupData g in groups) g.barRods.first.toY],
        <double>[8368, 6276, 9205, 7531, 10460, 0, 0],
        reason: '2000/1500/2200/1800/2500 kcal * 4.184, rounded',
      );
      expect(
        <double>[for (final BarChartGroupData g in groups) g.barRods.last.toY],
        <double>[8280, 8280, 9355, 8280, 8280, 0, 0],
        reason: 'BMR 1979 -> 8280 kJ; Wed 2236 -> 9355 kJ',
      );

      // --- The axis is built from the converted values: max 10460 kJ ->
      // 15000 at a 5000 step, with integer kJ tick labels. ---
      expect(chart.data.maxY, 15000);
      expect(chart.data.minY, 0);
      expect(chart.data.titlesData.leftTitles.sideTitles.interval, 5000);
      expect(find.text('15000'), findsOneWidget);

      // --- The dashed target line moves with the axis (base BMR 1979). ---
      final HorizontalLine line =
          chart.data.extraLinesData.horizontalLines.single;
      expect(line.y, 8280);
      expect(line.label.labelResolver(line), '基础代谢(不含运动)');

      // --- Totals switch value AND unit: 10000 -> 41840 kJ, 10152 -> 42476,
      // -152 -> -636. The three energy tiles carry the only kJ units. ---
      expect(_text(tester, weeklyTotalIntakeKey), '41840');
      expect(_text(tester, weeklyTotalBurnKey), '42476');
      expect(_text(tester, weeklyTotalBalanceKey), '-636');
      expect(find.text('kJ'), findsNWidgets(3));
      expect(find.text('kcal'), findsNothing);

      // --- Non-energy metrics stay unchanged; the salt label follows sodium. ---
      expect(_text(tester, weeklyLoggedDaysKey), '5');
      expect(_text(tester, weeklySaltAdherenceKey), '4 / 5');
      expect(find.text('钠达标'), findsOneWidget);
      expect(find.text('盐达标'), findsNothing);

      debugPrint(
        'WEEKLY_UNITS_QA intakeBars=${<double>[for (final BarChartGroupData g in groups) g.barRods.first.toY]} '
        'burnBars=${<double>[for (final BarChartGroupData g in groups) g.barRods.last.toY]} '
        'targetLineY=${line.y} maxY=${chart.data.maxY} '
        'totalIntake=${_text(tester, weeklyTotalIntakeKey)} '
        'saltAdherenceLabel=${find.text('钠达标')} -> PASS',
      );
    },
  );

  testWidgets(
    'kJ preference without a profile: the — placeholders keep the kJ unit',
    (WidgetTester tester) async {
      await seedWeekly(
        meals: mealRepo,
        exercises: exerciseRepo,
        profile: profileRepo,
        mealGroups: weeklyMeals(),
        exerciseEntries: weeklyExercises(),
        withProfile: false,
      );

      await pumpWeekly(tester, units: metricUnits);

      // The two budget-dependent tiles are still placeholders, but their unit
      // is the display preference's, not a hard-coded kcal.
      expect(find.text('—'), findsNWidgets(2));
      expect(
        find.text('kJ'),
        findsNWidgets(3),
        reason: 'intake + 2 placeholders',
      );
      expect(find.text('kcal'), findsNothing);
      expect(_text(tester, weeklyTotalIntakeKey), '41840');
      expect(find.byKey(weeklyTotalBurnKey), findsNothing);
      expect(find.byKey(weeklyTotalBalanceKey), findsNothing);
      expect(find.byKey(weeklyProfilePromptKey), findsOneWidget);
      expect(find.text('钠达标'), findsOneWidget);
    },
  );

  group('burn bar rule: base + exercise on logged days only', () {
    test('a logged day with exercise -> 1979 + 257', () {
      final DayRollup day = DayRollup(
        date: weeklyDayInstant(2),
        intakeKcal: 2200,
        exerciseKcal: 257,
        mealCount: 1,
      );
      expect(weeklyBurnFor(day, 1979), 2236);
    });

    test('an exercise-only day is unlogged -> no burn bar', () {
      final DayRollup day = DayRollup(
        date: weeklyDayInstant(5),
        exerciseKcal: 300,
      );
      expect(weeklyBurnFor(day, 1979), 0);
    });

    test('no profile -> no burn bar', () {
      final DayRollup day = DayRollup(
        date: weeklyDayInstant(0),
        intakeKcal: 2000,
        mealCount: 1,
      );
      expect(weeklyBurnFor(day, null), 0);
    });
  });

  group('y-axis scale: rounded maxY + explicit nice interval (D3 residual)', () {
    test('fixture week -> maxY 3000, interval 1000', () {
      final BarChartData data = weeklyChartData(
        days: _week(<int>[2000, 1500, 2200, 1800, 2500, 0, 0]),
        baseBudgetKcal: 1979,
      );
      expect(data.maxY, 3000);
      expect(data.minY, 0);
      expect(data.titlesData.leftTitles.sideTitles.interval, 1000);
      // The bar content is untouched: intake first, burn second.
      expect(data.barGroups.first.barRods.first.toY, 2000);
      expect(data.barGroups.first.barRods.last.toY, 1979);
      debugPrint(
        'D3_RESIDUAL fixture maxY=${data.maxY} '
        'interval=${data.titlesData.leftTitles.sideTitles.interval} -> PASS',
      );
    });

    test('device case (max intake 4234, base 1979) -> maxY 6000, step 2000', () {
      final BarChartData data = weeklyChartData(
        days: _week(<int>[4234, 0, 0, 0, 0, 0, 0]),
        baseBudgetKcal: 1979,
      );
      // 4234 * 1.2 = 5080.8 rounds UP to the next whole 2000 multiple.
      expect(data.maxY, 6000);
      expect(data.titlesData.leftTitles.sideTitles.interval, 2000);
      // A whole-multiple top means no fractional 5080.8 label can collide with
      // the 5000 tick.
      expect(data.maxY % 2000, 0);
      // The target line and the intake bar are untouched.
      expect(data.extraLinesData.horizontalLines.single.y, 1979);
      expect(data.barGroups.first.barRods.first.toY, 4234);
      debugPrint(
        'D3_RESIDUAL device maxY=${data.maxY} '
        'interval=${data.titlesData.leftTitles.sideTitles.interval} -> PASS',
      );
    });

    test(
      'unlogged profile-independent top -> 100 with a whole-multiple maxY',
      () {
        final double interval = weeklyChartInterval(0);
        final BarChartData data = weeklyChartData(
          days: _week(<int>[0, 0, 0, 0, 0, 0, 0]),
          baseBudgetKcal: null,
        );
        expect(data.maxY, 100);
        expect(data.maxY % interval, 0);
        // Without a profile there is no burn series: one intake rod per day.
        expect(data.barGroups.first.barRods.length, 1);
      },
    );
  });

  group('long-press tooltip: readable per-day bubble', () {
    DayRollup dayFor(int index) => DayRollup(
      date: weeklyDayKey(index),
      intakeKcal: <int>[2000, 1500, 2200, 1800, 2500, 0, 0][index],
      exerciseKcal: index == 2
          ? 257
          : index == 5
          ? 300
          : 0,
      mealCount: index <= 4 ? 1 : 0,
    );

    List<DayRollup> week() => <DayRollup>[
      for (var i = 0; i < 7; i++) dayFor(i),
    ];

    test(
      'content: weekday + intake + burn + signed difference, whole kcal',
      () {
        final WeeklyDayTooltip tooltip = weeklyDayTooltip(
          day: dayFor(4),
          baseBudgetKcal: 1979,
        );
        expect(tooltip.title, '周五');
        expect(tooltip.logged, isTrue);
        expect(
          <(WeeklyTooltipKind, String, int)>[
            for (final WeeklyTooltipRow row in tooltip.rows)
              (row.kind, row.label, row.kcal),
          ],
          <(WeeklyTooltipKind, String, int)>[
            (WeeklyTooltipKind.intake, '摄入', 2500),
            (WeeklyTooltipKind.burn, '消耗', 1979),
            (WeeklyTooltipKind.difference, '差值', 521),
          ],
        );
      },
    );

    test("burn row carries that day's exercise; the difference is signed", () {
      final WeeklyDayTooltip tooltip = weeklyDayTooltip(
        day: dayFor(2),
        baseBudgetKcal: 1979,
      );
      expect(tooltip.rows[1].kcal, 2236, reason: '1979 BMR + 257 exercise');
      expect(tooltip.rows[2].kcal, -36, reason: '2200 intake - 2236 burn');
    });

    test('an unlogged day reports 未记录 instead of zero rows', () {
      final WeeklyDayTooltip tooltip = weeklyDayTooltip(
        day: dayFor(5),
        baseBudgetKcal: 1979,
      );
      expect(tooltip.title, '周六');
      expect(tooltip.logged, isFalse);
      expect(tooltip.rows, isEmpty);
    });

    test('without a profile only the intake row is reported', () {
      final WeeklyDayTooltip tooltip = weeklyDayTooltip(
        day: dayFor(0),
        baseBudgetKcal: null,
      );
      expect(tooltip.rows.single.kind, WeeklyTooltipKind.intake);
      expect(tooltip.rows.single.kcal, 2000);
    });

    test('the chart hands fl_chart a legible, fitted bubble for each day', () {
      final BarChartData data = weeklyChartData(
        days: week(),
        baseBudgetKcal: 1979,
        tooltipTheme: WeeklyTooltipTheme.light,
      );
      final BarTouchTooltipData touch = data.barTouchData.touchTooltipData;
      expect(
        touch.fitInsideHorizontally,
        isTrue,
        reason: 'never clipped at the edges',
      );
      expect(
        touch.fitInsideVertically,
        isTrue,
        reason: 'never clipped above a tall bar',
      );
      expect(touch.tooltipMargin, 6);
      expect(
        touch.getTooltipColor(data.barGroups[4]),
        WeeklyTooltipTheme.light.background,
      );

      final BarTooltipItem item = touch.getTooltipItem(
        data.barGroups[4],
        4,
        data.barGroups[4].barRods.first,
        0,
      )!;
      final String text = _tooltipText(item);
      expect(text, contains('周五'));
      expect(text, contains('摄入 2500 kcal'));
      expect(text, contains('消耗 1979 kcal'));
      expect(text, contains('差值 521 kcal'));
      // The old defect: fl_chart's default item dumped the raw double.
      expect(text, isNot(contains('2500.0')));
      debugPrint('WEEKLY_TOOLTIP text=${text.replaceAll('\n', ' | ')} -> PASS');
    });

    testWidgets('the rendered chart uses the legible light bubble', (
      WidgetTester tester,
    ) async {
      await seedWeekly(
        meals: mealRepo,
        exercises: exerciseRepo,
        profile: profileRepo,
        mealGroups: weeklyMeals(),
        exerciseEntries: weeklyExercises(),
      );
      await pumpWeekly(tester);
      final BarChartData data = _chart(tester).data;
      final BarTouchTooltipData touch = data.barTouchData.touchTooltipData;
      expect(
        touch.getTooltipColor(data.barGroups.first),
        WeeklyTooltipTheme.light.background,
      );
      final BarTooltipItem item = touch.getTooltipItem(
        data.barGroups[4],
        4,
        data.barGroups[4].barRods.first,
        0,
      )!;
      expect(_tooltipText(item), contains('周五'));
    });

    test('both palettes keep every tooltip text tone above 4.5:1 contrast', () {
      for (final WeeklyTooltipTheme theme in <WeeklyTooltipTheme>[
        WeeklyTooltipTheme.light,
        WeeklyTooltipTheme.dark,
      ]) {
        expect(
          theme.background.a,
          1.0,
          reason: 'fill must be opaque over bars',
        );
        final Map<String, Color> tones = <String, Color>{
          'text': theme.text,
          'muted': theme.muted,
          'deficit': theme.deficit,
          'surplus': theme.surplus,
          'balanced': theme.balanced,
        };
        final List<String> ratios = <String>[];
        for (final MapEntry<String, Color> entry in tones.entries) {
          final double ratio = _contrastRatio(entry.value, theme.background);
          expect(
            ratio,
            greaterThanOrEqualTo(4.5),
            reason: '${entry.key} on the bubble fill',
          );
          ratios.add('${entry.key}=${ratio.toStringAsFixed(2)}');
        }
        debugPrint(
          'WEEKLY_TOOLTIP contrast ${theme == WeeklyTooltipTheme.light ? 'light' : 'dark'} '
          '${ratios.join(' ')} -> PASS',
        );
      }
    });
  });

  group('display units: the kJ preference on the chart', () {
    const DisplayUnits kj = DisplayUnits(energy: EnergyDisplay.kj);

    DayRollup dayFor(int index) => DayRollup(
      date: weeklyDayInstant(index),
      intakeKcal: <int>[2000, 1500, 2200, 1800, 2500, 0, 0][index],
      exerciseKcal: index == 2
          ? 257
          : index == 5
          ? 300
          : 0,
      mealCount: index <= 4 ? 1 : 0,
    );

    List<DayRollup> week() => <DayRollup>[
      for (var i = 0; i < 7; i++) dayFor(i),
    ];

    test('rods, y-axis top and target line are converted to kJ', () {
      final BarChartData data = weeklyChartData(
        days: week(),
        baseBudgetKcal: 1979,
        units: kj,
      );
      expect(
        <double>[
          for (final BarChartGroupData g in data.barGroups) g.barRods.first.toY,
        ],
        <double>[8368, 6276, 9205, 7531, 10460, 0, 0],
      );
      expect(
        <double>[
          for (final BarChartGroupData g in data.barGroups) g.barRods.last.toY,
        ],
        <double>[8280, 8280, 9355, 8280, 8280, 0, 0],
      );
      // max(10460, 9355, 8280) * 1.2 = 12552 -> whole 5000 steps -> 15000.
      expect(data.maxY, 15000);
      expect(data.titlesData.leftTitles.sideTitles.interval, 5000);
      expect(data.extraLinesData.horizontalLines.single.y, 8280);
      // Axis tick labels are already the converted integers.
      expect(data.barGroups.first.barRods.first.toY.round(), 8368);
      debugPrint(
        'WEEKLY_UNITS maxY=${data.maxY} '
        'interval=${data.titlesData.leftTitles.sideTitles.interval} '
        'targetY=${data.extraLinesData.horizontalLines.single.y} -> PASS',
      );
    });

    test('the tooltip renders kJ while its model rows keep kcal', () {
      final BarChartData data = weeklyChartData(
        days: week(),
        baseBudgetKcal: 1979,
        units: kj,
        tooltipTheme: WeeklyTooltipTheme.light,
      );
      final BarTouchTooltipData touch = data.barTouchData.touchTooltipData;
      final BarChartGroupData group = data.barGroups[4]; // Friday
      final String text = _tooltipText(
        touch.getTooltipItem(group, 4, group.barRods.first, 0)!,
      );
      expect(text, contains('周五'));
      expect(text, contains('摄入 10460 kJ'));
      expect(text, contains('消耗 8280 kJ'));
      expect(text, contains('差值 2180 kJ'));
      expect(text, isNot(contains('kcal')));

      // The model keeps the stored kcal ints; only the rendering converts.
      final WeeklyDayTooltip model = weeklyDayTooltip(
        day: dayFor(4),
        baseBudgetKcal: 1979,
        units: kj,
      );
      expect(
        <int>[for (final WeeklyTooltipRow row in model.rows) row.kcal],
        <int>[2500, 1979, 521],
      );
      expect(model.units, kj);
      // And the default tooltip model still documents the historical unit.
      expect(
        weeklyDayTooltip(day: dayFor(4), baseBudgetKcal: 1979).units,
        DisplayUnits.defaults,
      );
      debugPrint(
        'WEEKLY_UNITS tooltip=${text.replaceAll('\n', ' | ')} -> PASS',
      );
    });
  });
}
