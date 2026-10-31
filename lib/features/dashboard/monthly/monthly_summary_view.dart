/// The monthly summary dashboard: the 月 view of the merged 概览 screen.
///
/// The month is the same cumulative dashboard as the week card at a coarser
/// zoom: it renders the calendar month's day-by-day intake as a
/// `fl_chart` `BarChart`, the profile's exercise-free **BMR as a dashed target
/// line**, and the month's running totals (total intake, total burn, the signed
/// difference, logged days and salt adherence — cumulative so far, never
/// averages). The chart machinery, the tooltip bubble and the totals grid are
/// shared with the week card through `features/dashboard/period/`.
///
/// The card is read-only, so every energy number follows the app's display-unit
/// preference (kcal by default, kJ when chosen); the totals grid also switches
/// its salt-adherence label to 钠达标 for the sodium basis.
///
/// ## Why the month card drops the burn rods
///
/// The week card plots two rods per day — intake and burn — because seven slots
/// leave room for them. A month has up to 31 slots on the same phone width, so
/// two six-pixel rods per day would visually merge into a single hatched block
/// and answer neither question (what did I eat? what was my budget?). The month
/// card therefore plots **one intake rod per day** and keeps the burn series in
/// the long-press tooltip and in the totals, where it stays readable as an
/// exact number. The legend mirrors the plot: 摄入 and the 虚线 target only.
///
/// The remaining parameters are chosen for 28..31 slots:
/// * rods are [monthlyRodWidth] px wide (the week's 14 px would touch);
/// * the bottom axis labels every [monthlyLabelEvery]th day, so the month reads
///   `1 6 11 16 21 26` (plus `31`, or `28`/`29`/`30`, when the month is that
///   long) instead of 31 colliding day numbers;
/// * the tooltip's title is the calendar date ([AppFormat.shortDate], `1月5日`)
///   rather than a weekday, because a month repeats every weekday four or five
///   times — the date is what identifies the day here.
///
/// ## States and wording
///
/// Loading renders a spinner rather than a guessed number; an all-unlogged
/// month renders [monthlyEmptyStateKey] instead of an all-zero chart; a missing
/// profile keeps the intake bars and the profile-independent metrics but hides
/// the target line and the difference behind a "完善资料" prompt.
///
/// The view is month-agnostic: it renders the current month by default and,
/// when [MonthlySummaryView.monthKey] is supplied, the calendar month starting
/// on that date-only first-day key through the month-keyed `family` providers.
/// [isCurrentMonth] only changes the user-facing wording (the card title and the
/// empty state), so a historical page never claims to be "本月".
library;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:caldoo/core/theme/app_dimensions.dart';
import 'package:caldoo/core/theme/app_semantic_colors.dart';
import 'package:caldoo/core/ui/app_card.dart';
import 'package:caldoo/core/units/display_units.dart';
import 'package:caldoo/domain/models/day_rollup.dart';
import 'package:caldoo/l10n/app_format.dart';
import 'package:caldoo/l10n/app_strings.dart';

import '../period/period_chart.dart';
import '../period/period_summary.dart';
import '../period/period_totals.dart';
import 'monthly_summary_providers.dart';

/// Key of the empty state (a month with no logged day).
const Key monthlyEmptyStateKey = Key('monthly_empty_state');

/// Key of the cumulative total-intake value.
const Key monthlyTotalIntakeKey = Key('monthly_total_intake');

/// Key of the cumulative total-burn value (BMR + exercise).
const Key monthlyTotalBurnKey = Key('monthly_total_burn');

/// Key of the cumulative difference value (total intake - total burn).
const Key monthlyTotalBalanceKey = Key('monthly_total_balance');

/// Key of the logged-days value.
const Key monthlyLoggedDaysKey = Key('monthly_logged_days');

/// Key of the salt-adherence value (`adherent / logged`).
const Key monthlySaltAdherenceKey = Key('monthly_salt_adherence');

/// Key of the "完善资料" prompt shown when the profile is incomplete.
const Key monthlyProfilePromptKey = Key('monthly_profile_prompt');

/// Key of the chart's intake-bar legend item.
const Key monthlyIntakeLegendKey = Key('monthly_intake_legend');

/// Key of the chart's target-line legend.
const Key monthlyTargetLegendKey = Key('monthly_target_legend');

/// Key of the bar chart itself.
const Key monthlyChartKey = Key('monthly_chart');

/// The widest an intake rod may become in the month chart, in logical pixels.
///
/// Narrower than the week card's 14 px because a month packs up to 31 slots in
/// the same plot width; at 14 px the rods would touch and merge into a block.
/// The card scales the rod down on narrow screens ([monthlyRodWidthFor]): a
/// fixed width would leave 0.7 px gaps between the 31 rods on a 320 dp phone,
/// which reads as one solid block.
const double monthlyRodWidth = 6;

/// The rod width to use for [count] days in a plot [plotWidth] px wide.
///
/// Leaves a 2 px gap between neighbouring rods and never exceeds
/// [monthlyRodWidth], so a 390 dp phone keeps the tuned 6 px while a 320 dp
/// phone shrinks to ~4.6 px instead of merging the rods.
double monthlyRodWidthFor({required double plotWidth, required int count}) {
  if (count <= 0) {
    return monthlyRodWidth;
  }
  final double slot = plotWidth / count;
  return (slot - 2).clamp(3.0, monthlyRodWidth);
}

/// Show one bottom-axis label every this many days (`1 6 11 16 21 26 31`).
///
/// A label under every one of up to 31 day numbers would collide at phone
/// width; every fifth day still lets the user locate any day at a glance.
const int monthlyLabelEvery = 5;

/// The task-26 metric keys, handed to the shared [PeriodTotals] grid.
const PeriodTotalsKeys _monthlyTotalsKeys = PeriodTotalsKeys(
  totalIntake: monthlyTotalIntakeKey,
  totalBurn: monthlyTotalBurnKey,
  totalBalance: monthlyTotalBalanceKey,
  loggedDays: monthlyLoggedDaysKey,
  saltAdherence: monthlySaltAdherenceKey,
  profilePrompt: monthlyProfilePromptKey,
);

/// The monthly summary dashboard card.
class MonthlySummaryView extends ConsumerWidget {
  /// Creates the monthly summary view.
  ///
  /// [monthKey] is the date-only first-day key of the month to render (a
  /// mid-month date means that month); when it is `null` the view renders the
  /// **current** month. The history pager passes the browsed month's key,
  /// which selects that month's `family` provider state.
  ///
  /// [isCurrentMonth] defaults to `true` so the current-month wording
  /// (`本月汇总` / `本月暂无记录`) is used; a historical page passes `false` for
  /// the past-month wording (`月汇总` / `这一月暂无记录`).
  const MonthlySummaryView({
    this.monthKey,
    this.isCurrentMonth = true,
    super.key,
  });

  /// The date-only first-day key of the month to render, or `null` for this
  /// month.
  final DateTime? monthKey;

  /// Whether this card renders the current month (the default) or a past one.
  final bool isCurrentMonth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final DateTime? monthKey = this.monthKey;
    final PeriodSummaryState state = monthKey == null
        ? ref.watch(monthlySummaryProvider)
        : ref.watch(monthlySummaryForMonthProvider(monthKey));
    return switch (state) {
      PeriodSummaryLoading() => const AppCard(
        child: SizedBox(
          height: 200,
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      PeriodSummaryEmpty() => AppCard(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Text(
              isCurrentMonth
                  ? S.of(context).monthlyEmpty
                  : S.of(context).historyMonthlyEmpty,
              key: monthlyEmptyStateKey,
            ),
          ),
        ),
      ),
      PeriodSummaryNoProfile(
        :final List<DayRollup> days,
        :final int loggedDays,
        :final int adherentDays,
        :final int totalIntakeKcal,
      ) =>
        _MonthlyCard(
          days: days,
          baseBudgetKcal: null,
          loggedDays: loggedDays,
          adherentDays: adherentDays,
          totalIntakeKcal: totalIntakeKcal,
          isCurrentMonth: isCurrentMonth,
        ),
      PeriodSummaryReady(:final PeriodSummary summary) => _MonthlyCard(
        days: summary.days,
        baseBudgetKcal: summary.baseBudgetKcal,
        loggedDays: summary.loggedDays,
        adherentDays: summary.adherentDays,
        totalIntakeKcal: summary.totalIntakeKcal,
        totalBurnKcal: summary.totalBurnKcal,
        totalBalanceKcal: summary.totalBalanceKcal,
        isCurrentMonth: isCurrentMonth,
      ),
    };
  }
}

/// The card body for a known month of [days] and an optional base budget.
class _MonthlyCard extends StatelessWidget {
  const _MonthlyCard({
    required this.days,
    required this.baseBudgetKcal,
    required this.loggedDays,
    required this.adherentDays,
    required this.totalIntakeKcal,
    required this.isCurrentMonth,
    this.totalBurnKcal,
    this.totalBalanceKcal,
  });

  /// The month's rollups, in calendar order (28..31 entries).
  final List<DayRollup> days;

  /// The exercise-free base budget, or `null` when the profile is incomplete.
  final int? baseBudgetKcal;

  /// How many days of the month logged at least one meal.
  final int loggedDays;

  /// How many logged days stayed at or under the WHO sodium ceiling.
  final int adherentDays;

  /// The month's cumulative intake over its logged days, in whole kcal.
  final int totalIntakeKcal;

  /// Whether this card is the current month (title `本月汇总`) or a past one
  /// (title `月汇总`).
  final bool isCurrentMonth;

  /// The month's cumulative burn (BMR + exercise), or `null` without a profile.
  final int? totalBurnKcal;

  /// The signed `total intake - total burn`, or `null` without a profile.
  final int? totalBalanceKcal;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppSemantics semantics = AppSemantics.of(context);
    final ColorScheme colors = theme.colorScheme;
    final int? baseBudgetKcal = this.baseBudgetKcal;
    // The card is read-only: the display preference reaches the chart (rods,
    // axis, target line, tooltip) and the totals grid, which reads the scope
    // itself.
    final DisplayUnits units = DisplayUnits.of(context);

    return AppCard(
      padding: const EdgeInsets.all(AppDim.heroPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            isCurrentMonth
                ? S.of(context).monthlyTitle
                : S.of(context).historyMonthlyTitle,
            style: theme.textTheme.titleMedium,
          ),
          // Same headroom as the week card: the topmost y-axis label must never
          // sit against the title before the fit-inside offset is measured.
          const SizedBox(height: 16),
          SizedBox(
            height: 220,
            // The rod width has to follow the available width: 31 slots on a
            // narrow phone leave no room for the tuned 6 px rods.
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) =>
                  BarChart(
                    monthlyChartData(
                      days: days,
                      baseBudgetKcal: baseBudgetKcal,
                      barColor: colors.primary,
                      targetColor: semantics.chartTarget,
                      axisLabelColor: colors.onSurfaceVariant,
                      tooltipTheme: PeriodTooltipTheme.of(context),
                      rodWidth: monthlyRodWidthFor(
                        // The plot loses the left y-axis gutter (40 px).
                        plotWidth: constraints.maxWidth - 40,
                        count: days.length,
                      ),
                      units: units,
                    ),
                    key: monthlyChartKey,
                  ),
            ),
          ),
          const SizedBox(height: 10),
          // The legend mirrors the plot: intake plus the dashed target line.
          // There is deliberately no 消耗 item — the month card draws no burn
          // rods (see the library doc), and a legend entry for a series that is
          // not plotted would only mislead. Burn is still reported exactly in
          // the tooltip and the 总消耗 tile below.
          Wrap(
            spacing: 14,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              PeriodLegendDot(
                color: colors.primary,
                label: S.of(context).legendIntake,
                textKey: monthlyIntakeLegendKey,
              ),
              if (baseBudgetKcal != null)
                PeriodLegendDash(
                  color: semantics.chartTarget,
                  label: S.of(context).targetLegend(periodTargetLineLabel),
                  textKey: monthlyTargetLegendKey,
                ),
            ],
          ),
          const SizedBox(height: 18),
          PeriodTotals(
            totalIntakeKcal: totalIntakeKcal,
            totalBurnKcal: totalBurnKcal,
            totalBalanceKcal: totalBalanceKcal,
            loggedDays: loggedDays,
            adherentDays: adherentDays,
            keys: _monthlyTotalsKeys,
          ),
        ],
      ),
    );
  }
}

/// The bottom-axis labels of a month chart: the day-of-month of each rollup,
/// in calendar order (`1` .. `31`).
List<String> monthlyDayLabels(List<DayRollup> days) => <String>[
  for (final DayRollup day in days) '${day.date.day}',
];

/// The long-press tooltip's first line for [day]: the calendar date (`1月5日`).
///
/// A month repeats each weekday four or five times, so the date — not the
/// weekday — is what identifies the touched day here.
String monthlyTooltipTitle(DayRollup day) => AppFormat.shortDate(day.date);

/// Builds the month card's `fl_chart` data: one intake bar per day of the
/// month, the dashed BMR target line and the date-titled tooltip.
///
/// Exposed (not private) so the widget test can assert the exact bar values,
/// the target-line `y` and the axis step without duplicating the chart
/// construction. The colour params default to the light-palette constants; the
/// view passes brightness-aware colours. [tooltipTheme] defaults to the light
/// tooltip palette for the same context-free reason.
///
/// Burn bars are off ([periodChartData]'s `showBurnBars: false`): the burn
/// series stays in the tooltip and the totals, where 28..31 values remain
/// readable as numbers (see the library doc for the full rationale).
///
/// [units] is the read-only display preference: the rods, the y-axis and the
/// target line are converted to kJ when it asks for it, while the tooltip rows
/// keep their kcal values and convert only when formatted.
BarChartData monthlyChartData({
  required List<DayRollup> days,
  required int? baseBudgetKcal,
  Color? barColor,
  Color? targetColor,
  Color? axisLabelColor,
  PeriodTooltipTheme? tooltipTheme,
  double rodWidth = monthlyRodWidth,
  DisplayUnits units = DisplayUnits.defaults,
}) => periodChartData(
  days: days,
  xLabels: monthlyDayLabels(days),
  baseBudgetKcal: baseBudgetKcal,
  showBurnBars: false,
  rodWidth: rodWidth,
  labelEvery: monthlyLabelEvery,
  // One pixel of hit-band padding: the rods sit ~9 px apart, so anything wider
  // would make fl_chart's first-match hit test report the previous day.
  touchExtraHorizontal: 1,
  tooltipTitle: monthlyTooltipTitle,
  barColor: barColor,
  targetColor: targetColor,
  axisLabelColor: axisLabelColor,
  tooltipTheme: tooltipTheme,
  units: units,
);
