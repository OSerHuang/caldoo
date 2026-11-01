/// The cumulative metric grid shared by the week and month summary cards.
///
/// Both dashboards report the same five numbers below their chart — total
/// intake, total burn, the signed difference, logged days and salt adherence —
/// plus the "完善资料" prompt that the incomplete-profile state shows in place of
/// the budget-dependent values. Only the widget-test keys differ per period, so
/// the grid takes a [PeriodTotalsKeys] bundle instead of hard-coding one
/// period's keys: the week must keep its `weeklyTotalIntakeKey` family (its
/// widget tests and the golden capture pin them) while the month owns the
/// `monthly…` ones.
///
/// The values are **cumulative totals for the period so far, never averages**:
/// the views hand in pre-computed sums/tints, so the metric definitions stay in
/// the value layer and this file only renders them.
///
/// The energy tiles are read-only, so they follow the [DisplayUnits] preference
/// installed by the app root: kcal or kJ for the three energy values (including
/// the `—` placeholders' unit), and 盐达标 / 钠达标 for the salt-adherence label.
/// The stored totals stay canonical kcal — only the rendering changes.
library;

import 'package:flutter/material.dart';

import 'package:caldoo/core/theme/app_semantic_colors.dart';
import 'package:caldoo/core/ui/metric_tile.dart';
import 'package:caldoo/core/units/display_units.dart';
import 'package:caldoo/l10n/app_strings.dart';

/// The widget-test keys the metric grid attaches to its values.
///
/// A bundle rather than six parameters so the two views can keep their own
/// key set (weekly `weekly…` / monthly `monthly…`) while sharing one widget.
@immutable
class PeriodTotalsKeys {
  /// Creates a key bundle. Every value the grid renders a number for needs a
  /// key; the two budget-dependent placeholders (`—`) deliberately have none,
  /// so a test can tell "no profile" apart from "value zero".
  const PeriodTotalsKeys({
    required this.totalIntake,
    required this.totalBurn,
    required this.totalBalance,
    required this.loggedDays,
    required this.saltAdherence,
    required this.profilePrompt,
  });

  /// Key of the cumulative total-intake value.
  final Key totalIntake;

  /// Key of the cumulative total-burn value (BMR + exercise).
  final Key totalBurn;

  /// Key of the cumulative difference value (total intake - total burn).
  final Key totalBalance;

  /// Key of the logged-days value.
  final Key loggedDays;

  /// Key of the salt-adherence value (`adherent / logged`).
  final Key saltAdherence;

  /// Key of the "完善资料" prompt shown when the profile is incomplete.
  final Key profilePrompt;
}

/// The two-row metric grid under a period chart.
///
/// Row 1 is the energy triple (总摄入 / 总消耗 / 差值) and row 2 the profile-free
/// pair (记录天数 / 盐达标). When [totalBurnKcal] / [totalBalanceKcal] are
/// `null` the profile is incomplete: those two tiles render the `—` placeholder
/// (without a value key) and the "完善资料" prompt follows the rows — the same
/// behaviour for the week and the month card.
///
/// The grid is a shrink-wrapped [Column] so a card can place it inside its own
/// spacing without an extra layout box; the period cards pass the 18 px gap
/// before it themselves, which keeps each card's vertical rhythm explicit.
class PeriodTotals extends StatelessWidget {
  /// Creates the metric grid.
  const PeriodTotals({
    required this.totalIntakeKcal,
    required this.loggedDays,
    required this.adherentDays,
    required this.keys,
    super.key,
    this.totalBurnKcal,
    this.totalBalanceKcal,
    this.goalKcal,
    this.goalAdherentDays = 0,
    this.goalAdherenceKey,
  });

  /// The period's cumulative intake over its logged days, in whole kcal.
  final int totalIntakeKcal;

  /// The period's cumulative burn (BMR + exercise) over its logged days, or
  /// `null` when the profile is incomplete.
  final int? totalBurnKcal;

  /// `totalIntakeKcal - totalBurnKcal`, or `null` when the profile is
  /// incomplete (it cannot be computed without a budget).
  final int? totalBalanceKcal;

  /// How many days logged at least one meal.
  final int loggedDays;

  /// How many logged days stayed at or under the WHO sodium ceiling.
  final int adherentDays;

  /// The user's daily energy goal in whole kcal/day, or `null` when no goal is
  /// set — the 热量达标 tile renders only when a goal exists.
  final int? goalKcal;

  /// How many logged days stayed at or under [goalKcal] (0 without a goal).
  final int goalAdherentDays;

  /// Key of the goal-adherence value; required when [goalKcal] is set.
  final Key? goalAdherenceKey;

  /// The period's widget-test keys.
  final PeriodTotalsKeys keys;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppSemantics semantics = AppSemantics.of(context);
    final ColorScheme colors = theme.colorScheme;
    // Read-only display preference: the three energy tiles (and their `—`
    // placeholders) switch unit together with the chart above them.
    final DisplayUnits units = DisplayUnits.of(context);
    final int? totalBurnKcal = this.totalBurnKcal;
    final int? totalBalanceKcal = this.totalBalanceKcal;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: MetricTile(
                label: S.of(context).labelTotalIntake,
                valueKey: keys.totalIntake,
                value: units.energyValueText(totalIntakeKcal),
                unit: units.energyUnit,
                color: colors.primary,
                dotAlways: true,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: totalBurnKcal == null
                  ? MetricTile(
                      label: S.of(context).labelTotalBurn,
                      value: '—',
                      unit: units.energyUnit,
                    )
                  : MetricTile(
                      label: S.of(context).labelTotalBurn,
                      valueKey: keys.totalBurn,
                      value: units.energyValueText(totalBurnKcal),
                      unit: units.energyUnit,
                      color: semantics.exercise,
                      dotAlways: true,
                    ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: totalBalanceKcal == null
                  ? MetricTile(
                      label: S.of(context).labelDifference,
                      value: '—',
                      unit: units.energyUnit,
                    )
                  : MetricTile(
                      label: S.of(context).labelDifference,
                      valueKey: keys.totalBalance,
                      value: units.energyValueText(totalBalanceKcal),
                      unit: units.energyUnit,
                      color: periodDifferenceTint(context, totalBalanceKcal),
                      dotAlways: true,
                    ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: <Widget>[
            Expanded(
              child: MetricTile(
                label: S.of(context).labelLoggedDays,
                valueKey: keys.loggedDays,
                value: '$loggedDays',
                unit: S.of(context).unitDays,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: MetricTile(
                label: units.showsSodium
                    ? S.of(context).labelSodiumAdherence
                    : S.of(context).labelSaltAdherence,
                valueKey: keys.saltAdherence,
                value: '$adherentDays / $loggedDays',
                unit: S.of(context).unitDays,
              ),
            ),
            // The goal tile exists only when a goal is set: "达标" without a
            // goal has no meaning (the budget then means "maintain").
            if (goalKcal != null) ...<Widget>[
              const SizedBox(width: 10),
              Expanded(
                child: MetricTile(
                  label: S.of(context).labelGoalAdherence,
                  valueKey: goalAdherenceKey,
                  value: '$goalAdherentDays / $loggedDays',
                  unit: S.of(context).unitDays,
                  color: colors.primary,
                  dotAlways: true,
                ),
              ),
            ],
          ],
        ),
        if (totalBalanceKcal == null) ...<Widget>[
          const SizedBox(height: 12),
          Text(
            S.of(context).periodProfilePrompt,
            key: keys.profilePrompt,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}

/// The signed-difference tint: green when the period runs under budget (缺口),
/// red when over (盈余), neutral at zero — the task-7 convention.
///
/// Shared so the week card and the month card can never tint the same number
/// differently.
Color periodDifferenceTint(BuildContext context, int differenceKcal) {
  if (differenceKcal == 0) {
    return AppSemantics.of(context).balanced;
  }
  return differenceKcal < 0
      ? AppSemantics.of(context).deficit
      : AppSemantics.of(context).surplus;
}
