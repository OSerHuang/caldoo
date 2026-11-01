/// The weekly summary dashboard (task 26, cumulative totals).
///
/// Renders, live from the repository `watch` streams:
/// * a `fl_chart` `BarChart` with **seven Mon..Sun groups**, each carrying an
///   **intake** bar (what was eaten) and, when a profile exists, a **burn** bar
///   (that logged day's budget: BMR + exercise);
/// * a **dashed target line** at the profile's resolved BMR (the user's own
///   override or the Mifflin-St Jeor estimate, excluding exercise), labelled
///   [weeklyTargetLineLabel] so it can never be confused with the daily
///   dashboard's `今日额度(含运动)`. The line
///   is a single flat reference because one line cannot represent seven
///   per-day exercise-varying budgets;
/// * the week's **running totals**: total intake, total burn (BMR + exercise)
///   and the signed difference, plus days logged and salt adherence. Totals are
///   cumulative for the week so far — never averages — and every energy number
///   is rendered in the display preference's unit (kcal by default, kJ when the
///   user chose it).
/// * a **long-press tooltip bubble** for the touched day: the weekday, intake,
///   burn (BMR + exercise) and the signed difference, in the display
///   preference's energy unit. An unlogged day says `未记录`; a missing
///   profile only has the intake row.
///
/// An all-unlogged week renders [weeklyEmptyStateKey] instead of a chart. A
/// missing profile keeps the intake bars and the profile-independent metrics
/// but hides the burn bars, the target line and the difference behind a
/// "完善资料" prompt.
///
/// The view is week-agnostic: it renders the current week by default and, when
/// [WeeklySummaryView.weekMonday] is supplied, the week starting on that
/// date-only Monday key through the week-keyed `family` providers. The
/// [isCurrentWeek] flag only changes the user-facing wording (the card title and
/// the empty state), so a historical page never claims to be "本周".
///
/// The chart construction, the tooltip bubble and the metric grid are shared
/// with the month card through the `period_chart.dart` / [PeriodTotals] library
/// in `features/dashboard/period/`; this file only supplies the week's
/// parameters (Mon..Sun x labels, weekday tooltip titles, burn bars shown) and
/// keeps the task-26 `Weekly…` names (typedefs for the shared types, plus a
/// re-export of the target-line constants). The rendered layout (paddings,
/// sizes, gaps) is deliberately unchanged: the UI goldens capture this card.
library;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:caldoo/core/theme/app_dimensions.dart';
import 'package:caldoo/core/theme/app_semantic_colors.dart';
import 'package:caldoo/core/ui/app_card.dart';
import 'package:caldoo/core/units/display_units.dart';
import 'package:caldoo/domain/models/day_rollup.dart';
import 'package:caldoo/domain/models/weight_entry.dart';
import 'package:caldoo/features/weight/weight_period_block.dart';
import 'package:caldoo/l10n/app_format.dart';
import 'package:caldoo/l10n/app_strings.dart';

import '../period/period_chart.dart';
import '../period/period_totals.dart';
import 'weekly_summary.dart';
import 'weekly_summary_providers.dart';

// The task-26 target-line constants stay importable from the weekly card's
// module even though the chart itself is now built by the shared period chart
// (which owns an equal `periodTargetLineLabel` / dash pair): consumers such as
// the integration test import the weekly card and its constants from here.
export 'weekly_summary.dart'
    show weeklyTargetLineDashArray, weeklyTargetLineLabel;

/// Key of the empty state (a week with no logged day).
const Key weeklyEmptyStateKey = Key('weekly_empty_state');

/// Key of the cumulative total-intake value.
const Key weeklyTotalIntakeKey = Key('weekly_total_intake');

/// Key of the cumulative total-burn value (BMR + exercise).
const Key weeklyTotalBurnKey = Key('weekly_total_burn');

/// Key of the cumulative difference value (total intake - total burn).
const Key weeklyTotalBalanceKey = Key('weekly_total_balance');

/// Key of the logged-days value.
const Key weeklyLoggedDaysKey = Key('weekly_logged_days');

/// Key of the salt-adherence value (`adherent / logged`).
const Key weeklySaltAdherenceKey = Key('weekly_salt_adherence');

/// Key of the goal-adherence value (`adherent / logged`, when a goal is set).
const Key weeklyGoalAdherenceKey = Key('weekly_goal_adherence');

/// Key of the weight-change value (when the week holds two+ weight entries).
const Key weeklyWeightKey = Key('weekly_weight');

/// Key of the "完善资料" prompt shown when the profile is incomplete.
const Key weeklyProfilePromptKey = Key('weekly_profile_prompt');

/// Key of the chart's intake-bar legend item.
const Key weeklyIntakeLegendKey = Key('weekly_intake_legend');

/// Key of the chart's burn-bar legend item.
const Key weeklyBurnLegendKey = Key('weekly_burn_legend');

/// Key of the chart's target-line legend.
const Key weeklyTargetLegendKey = Key('weekly_target_legend');

/// Key of the bar chart itself.
const Key weeklyChartKey = Key('weekly_chart');

/// Fill colour of a daily intake bar (light-palette default for context-free
/// callers).
const Color weeklyBarColor = periodBarColor;

/// Fill colour of a daily burn bar (light-palette default for context-free
/// callers).
const Color weeklyBurnBarColor = periodBurnBarColor;

/// Colour of the dashed base-budget target line.
const Color weeklyTargetLineColor = periodTargetLineColor;

/// Monday..Sunday short labels for the x axis (0 = Monday).
const List<String> weeklyWeekdayLabels = S.weekdayLabelsConst;

/// The task-26 metric keys, handed to the shared [PeriodTotals] grid.
const PeriodTotalsKeys _weeklyTotalsKeys = PeriodTotalsKeys(
  totalIntake: weeklyTotalIntakeKey,
  totalBurn: weeklyTotalBurnKey,
  totalBalance: weeklyTotalBalanceKey,
  loggedDays: weeklyLoggedDaysKey,
  saltAdherence: weeklySaltAdherenceKey,
  profilePrompt: weeklyProfilePromptKey,
);

/// The three series a weekly-tooltip row can report.
///
/// An alias of the shared [PeriodTooltipKind]: the chart machinery is shared
/// with the month card, but the task-26 `Weekly…` names stay the week card's
/// public API.
typedef WeeklyTooltipKind = PeriodTooltipKind;

/// One labelled kcal row of the weekly chart's long-press tooltip.
typedef WeeklyTooltipRow = PeriodTooltipRow;

/// The content of the weekly chart's long-press tooltip bubble for one day.
typedef WeeklyDayTooltip = PeriodDayTooltip;

/// The colours of the weekly chart's long-press tooltip bubble.
typedef WeeklyTooltipTheme = PeriodTooltipTheme;

/// The weekly summary dashboard card.
class WeeklySummaryView extends ConsumerWidget {
  /// Creates the weekly summary view.
  ///
  /// [weekMonday] is the date-only Monday key of the week to render; when it is
  /// `null` the view renders the **current** week (the bare-view behaviour, so
  /// existing tests and goldens are unchanged). The history pager passes the
  /// past week's key, which selects that week's `family` provider state.
  ///
  /// [isCurrentWeek] defaults to `true` so the tab's current-week wording is
  /// unchanged; a historical page passes `false` to switch the card title and
  /// the empty state to their past-week wording.
  const WeeklySummaryView({
    this.weekMonday,
    this.isCurrentWeek = true,
    super.key,
  });

  /// The date-only Monday key of the week to render, or `null` for this week.
  final DateTime? weekMonday;

  /// Whether this card renders the current week (the default) or a past one.
  final bool isCurrentWeek;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final DateTime? weekMonday = this.weekMonday;
    final WeeklySummaryState state = weekMonday == null
        ? ref.watch(weeklySummaryProvider)
        : ref.watch(weeklySummaryForWeekProvider(weekMonday));
    return switch (state) {
      WeeklySummaryLoading() => const AppCard(
        child: SizedBox(
          height: 200,
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      WeeklySummaryEmpty() => AppCard(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Text(
              isCurrentWeek
                  ? S.of(context).weeklyEmpty
                  : S.of(context).historyWeeklyEmpty,
              key: weeklyEmptyStateKey,
            ),
          ),
        ),
      ),
      WeeklySummaryNoProfile(
        :final List<DayRollup> days,
        :final int loggedDays,
        :final int adherentDays,
        :final int totalIntakeKcal,
        :final List<WeightEntry> weightEntries,
      ) =>
        _WeeklyCard(
          days: days,
          baseBudgetKcal: null,
          loggedDays: loggedDays,
          adherentDays: adherentDays,
          totalIntakeKcal: totalIntakeKcal,
          weightEntries: weightEntries,
          isCurrentWeek: isCurrentWeek,
        ),
      WeeklySummaryReady(:final WeeklySummary summary) => _WeeklyCard(
        days: summary.days,
        baseBudgetKcal: summary.baseBudgetKcal,
        goalKcal: summary.goalKcal,
        goalAdherentDays: summary.goalAdherentDays,
        loggedDays: summary.loggedDays,
        adherentDays: summary.adherentDays,
        totalIntakeKcal: summary.totalIntakeKcal,
        totalBurnKcal: summary.totalBurnKcal,
        totalBalanceKcal: summary.totalBalanceKcal,
        weightEntries: summary.weightEntries,
        isCurrentWeek: isCurrentWeek,
      ),
    };
  }
}

/// The card body for a known week of [days] and an optional base budget.
class _WeeklyCard extends StatelessWidget {
  const _WeeklyCard({
    required this.days,
    required this.baseBudgetKcal,
    required this.loggedDays,
    required this.adherentDays,
    required this.totalIntakeKcal,
    required this.isCurrentWeek,
    this.goalKcal,
    this.goalAdherentDays = 0,
    this.weightEntries = const <WeightEntry>[],
    this.totalBurnKcal,
    this.totalBalanceKcal,
  });

  final List<DayRollup> days;

  /// The exercise-free base budget (the user's goal when set, else the BMR), or
  /// `null` when the profile is incomplete.
  final int? baseBudgetKcal;

  /// The user's daily energy goal, or `null` when no goal is set — it selects
  /// the target-line label and the 热量达标 tile.
  final int? goalKcal;

  /// How many logged days stayed at or under [goalKcal] (0 without a goal).
  final int goalAdherentDays;

  /// The week's body-weight entries, day-ordered (feeds the 体重 line block).
  final List<WeightEntry> weightEntries;

  final int loggedDays;
  final int adherentDays;
  final int totalIntakeKcal;

  /// Whether this card is the current week (title `本周汇总`) or a past one
  /// (title `周汇总`).
  final bool isCurrentWeek;

  /// The week's cumulative burn (BMR + exercise), or `null` without a profile.
  final int? totalBurnKcal;

  /// The signed `total intake - total burn`, or `null` without a profile.
  final int? totalBalanceKcal;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppSemantics semantics = AppSemantics.of(context);
    final ColorScheme colors = theme.colorScheme;
    final int? baseBudgetKcal = this.baseBudgetKcal;
    // The card is read-only, so the display preference reaches both the chart
    // (rods / axis / target line / tooltip) and the totals grid (which reads the
    // scope itself).
    final DisplayUnits units = DisplayUnits.of(context);

    return AppCard(
      padding: const EdgeInsets.all(AppDim.heroPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            isCurrentWeek
                ? S.of(context).weeklyTitle
                : S.of(context).historyWeeklyTitle,
            style: theme.textTheme.titleMedium,
          ),
          // A little extra headroom so the topmost y-axis label never sits
          // against the title even on the first frame, before
          // SideTitleWidget's fit-inside offset is measured.
          const SizedBox(height: 16),
          SizedBox(
            height: 220,
            child: BarChart(
              weeklyChartData(
                days: days,
                baseBudgetKcal: baseBudgetKcal,
                barColor: colors.primary,
                burnColor: semantics.exercise,
                targetColor: semantics.chartTarget,
                axisLabelColor: colors.onSurfaceVariant,
                tooltipTheme: WeeklyTooltipTheme.of(context),
                units: units,
              ),
              key: weeklyChartKey,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              PeriodLegendDot(
                color: colors.primary,
                label: S.of(context).legendIntake,
                textKey: weeklyIntakeLegendKey,
              ),
              if (baseBudgetKcal != null)
                PeriodLegendDot(
                  color: semantics.exercise,
                  label: S.of(context).legendBurn,
                  textKey: weeklyBurnLegendKey,
                ),
              if (baseBudgetKcal != null)
                PeriodLegendDash(
                  color: semantics.chartTarget,
                  // The dashed line is the goal when one is set, else the BMR;
                  // the label names whichever the line actually is.
                  label: S
                      .of(context)
                      .targetLegend(
                        goalKcal != null
                            ? S.of(context).periodGoalLineLabel
                            : weeklyTargetLineLabel,
                      ),
                  textKey: weeklyTargetLegendKey,
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
            goalKcal: goalKcal,
            goalAdherentDays: goalAdherentDays,
            goalAdherenceKey: weeklyGoalAdherenceKey,
            keys: _weeklyTotalsKeys,
          ),
          const SizedBox(height: 12),
          // The week's weight line: its own kg plot, plus the period delta in
          // the header. The block is also the 周/月 discovery point (a prompt
          // with a 记录 action when the week has no weight entries).
          WeightPeriodBlock(
            key: weeklyWeightKey,
            entries: weightEntries,
            periodStart: days.first.date,
            slotCount: days.length,
            recordInitialDay: days.last.date,
            deltaKey: const Key('weekly_weight_delta'),
          ),
        ],
      ),
    );
  }
}

/// The long-press tooltip content for one chart day: the weekday and — for a
/// logged day — its intake, burn (BMR + exercise) and signed difference.
///
/// A missing profile ([baseBudgetKcal] `null`) only reports intake; an unlogged
/// day reports `logged: false` so the bubble says `未记录` rather than a row of
/// zeros. Exposed (not private) so the widget test can pin the exact content the
/// bubble shows without decoding the styled spans. [units] selects the display
/// unit the bubble formats its kcal rows with; the rows themselves stay kcal.
WeeklyDayTooltip weeklyDayTooltip({
  required DayRollup day,
  required int? baseBudgetKcal,
  DisplayUnits units = DisplayUnits.defaults,
}) => periodDayTooltip(
  day: day,
  baseBudgetKcal: baseBudgetKcal,
  title: AppFormat.weekday(day.date),
  units: units,
);

/// Builds the `fl_chart` data: seven Mon..Sun groups, each with an intake bar
/// plus — when [baseBudgetKcal] is known — the day's burn bar (base + exercise),
/// and the dashed target line.
///
/// Exposed (not private) so the widget test can assert the exact bar values and
/// the target-line `y` through the rendered `BarChart` without duplicating the
/// chart construction. The colour params default to the light-palette
/// constants; the view passes brightness-aware colours. [tooltipTheme] defaults
/// to the light tooltip palette for the same context-free reason.
///
/// Only LOGGED days get a non-zero burn bar: an unlogged day (even one with an
/// exercise-only entry) is not part of the week's picture, exactly like its
/// zero intake bar.
///
/// [units] is the read-only display preference: the rods, the y-axis and the
/// target line are converted to kJ when it asks for it, while the tooltip rows
/// keep their kcal values and convert only when formatted.
BarChartData weeklyChartData({
  required List<DayRollup> days,
  required int? baseBudgetKcal,
  Color? barColor,
  Color? burnColor,
  Color? targetColor,
  Color? axisLabelColor,
  WeeklyTooltipTheme? tooltipTheme,
  DisplayUnits units = DisplayUnits.defaults,
}) => periodChartData(
  days: days,
  xLabels: weeklyWeekdayLabels,
  baseBudgetKcal: baseBudgetKcal,
  tooltipTitle: (DayRollup day) => AppFormat.weekday(day.date),
  barColor: barColor,
  burnColor: burnColor,
  targetColor: targetColor,
  axisLabelColor: axisLabelColor,
  tooltipTheme: tooltipTheme,
  units: units,
);

/// The burn [day] contributes to the chart and to the week's totals: the
/// day's budget (`base + exercise`) for a logged day, otherwise zero.
///
/// Exposed (not private) so the widget test can state the expected burn bars
/// without duplicating the rule.
int weeklyBurnFor(DayRollup day, int? baseBudgetKcal) =>
    periodBurnFor(day, baseBudgetKcal);

/// The y-axis tick step for a week whose highest bar / budget is [top].
///
/// Picks a "nice" 1-2-5 x 10^n step targeting ~5 ticks, so [weeklyChartData]
/// can round `maxY` up to a whole multiple of it and emit evenly spaced
/// integer labels. Exposed so the widget test can assert the step.
double weeklyChartInterval(double top) => periodChartInterval(top);
