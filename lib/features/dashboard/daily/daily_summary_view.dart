/// The daily summary dashboard (task 24, restyled).
///
/// Renders, live from the repository `watch` streams, as a hero card:
/// * a calorie ring — its sweep is `intake / budget` and its centre carries
///   the SIGNED balance (**缺口** from `deficitKcal` when positive, **盈余**
///   from `energyBalanceKcal` when positive, per the task-7 convention);
/// * the day's intake / budget / exercise figures beside the ring;
/// * the three macros and salt as a 2x2 metric-tile grid (salt against the
///   fixed 5 g/day — 2000 mg sodium — target).
///
/// Every number is read-only, so the display preference applies:
/// [DisplayUnits.of] chooses kcal vs kJ for the energy figures (the values and
/// their units) and salt vs sodium for the salt tile's label/value/unit. The
/// stored rollup is never rewritten: only the rendered number changes.
///
/// When the profile is incomplete the budget and the balance are hidden
/// ([DailySummaryNoProfile]): no deficit is ever shown without a budget. The
/// ring centre falls back to the raw intake, and the intake/macro/salt/
/// exercise numbers stay visible because they do not depend on the profile.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:caldoo/core/math/energy_balance.dart';
import 'package:caldoo/core/theme/app_dimensions.dart';
import 'package:caldoo/core/theme/app_semantic_colors.dart';
import 'package:caldoo/core/ui/app_card.dart';
import 'package:caldoo/core/ui/calorie_ring.dart';
import 'package:caldoo/core/ui/metric_tile.dart';
import 'package:caldoo/core/ui/value_unit_text.dart';
import 'package:caldoo/core/units/display_units.dart';
import 'package:caldoo/core/units/nutrition_units.dart';
import 'package:caldoo/domain/models/day_rollup.dart';
import 'package:caldoo/l10n/app_format.dart';
import 'package:caldoo/l10n/app_strings.dart';

import 'daily_summary.dart';
import 'daily_summary_providers.dart';

/// Key of the total intake kcal value.
const Key dailyIntakeKcalKey = Key('daily_intake_kcal');

/// Key of the total carbohydrate value.
const Key dailyCarbKey = Key('daily_carb');

/// Key of the total protein value.
const Key dailyProteinKey = Key('daily_protein');

/// Key of the total fat value.
const Key dailyFatKey = Key('daily_fat');

/// Key of the salt value (rendered as `3.5 / 5 g`, or `1400 / 2000 mg` when the
/// display preference asks for sodium).
const Key dailySaltKey = Key('daily_salt');

/// Key of the exercise-burn value.
const Key dailyExerciseKcalKey = Key('daily_exercise_kcal');

/// Key of the day budget value (base + exercise).
const Key dailyBudgetKey = Key('daily_budget');

/// Key of the budget-composition subline (目标/基础代谢 + 运动) under the budget.
const Key dailyBudgetSublineKey = Key('daily_budget_subline');

/// Key of the signed-balance label (缺口 / 盈余 / 平衡).
const Key dailyBalanceLabelKey = Key('daily_balance_label');

/// Key of the signed-balance value.
const Key dailyBalanceValueKey = Key('daily_balance_value');

/// Key of the "完善资料" prompt shown when the profile is incomplete.
const Key dailyProfilePromptKey = Key('daily_profile_prompt');

/// Colour for a 缺口 (deficit) — the light-palette "good" green.
const Color dailyDeficitColor = Color(0xFF15803D);

/// Colour for a 盈余 (surplus) — the light-palette warning red.
const Color dailySurplusColor = Color(0xFFDC2626);

/// Colour for an exactly-on-budget day — neutral grey.
const Color dailyBalancedColor = Color(0xFF6B7280);

/// The colour paired with a [BalanceKind] (light palette; kept as a
/// context-free API for callers outside a widget tree).
Color dailyBalanceColor(BalanceKind kind) => switch (kind) {
  BalanceKind.deficit => dailyDeficitColor,
  BalanceKind.surplus => dailySurplusColor,
  BalanceKind.balanced => dailyBalancedColor,
};

/// The ring-gradient tip for a [BalanceKind]: 缺口 green flows into the teal
/// exercise accent, 盈余 red into heat amber, 平衡 keeps the flat stroke.
/// `null` renders CalorieRing's solid colour.
Color? dailyRingGradientTip(BuildContext context, BalanceKind kind) =>
    switch (kind) {
      BalanceKind.deficit => AppSemantics.of(context).exercise,
      BalanceKind.surplus => AppSemantics.of(context).surplusHeat,
      BalanceKind.balanced => null,
    };

/// The brightness-aware balance colour (falls back to the light palette when
/// no [AppSemantics] extension is installed).
Color _balanceColor(BuildContext context, BalanceKind kind) {
  final AppSemantics semantics = AppSemantics.of(context);
  return switch (kind) {
    BalanceKind.deficit => semantics.deficit,
    BalanceKind.surplus => semantics.surplus,
    BalanceKind.balanced => semantics.balanced,
  };
}

/// The daily summary dashboard card.
class DailySummaryView extends ConsumerWidget {
  /// Creates the daily summary view.
  ///
  /// [dayKey] selects which day to render: `null` (the default) is the current
  /// day — the bare-view behaviour used by the tab root, the tests and the
  /// goldens — while the history pager passes a past day's date-only key and
  /// the card reads that day's `dailySummaryForDayProvider` family state.
  ///
  /// [isToday] only selects the card title: the default (`true`) renders
  /// 今日汇总 exactly as before, while a history page renders 当日汇总.
  const DailySummaryView({super.key, this.dayKey, this.isToday = true});

  /// The date-only key of the day to render, or `null` for the current day.
  final DateTime? dayKey;

  /// Whether this card summarizes the current day (default) or a past one.
  final bool isToday;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final DateTime? dayKey = this.dayKey;
    final DailySummaryState state = dayKey == null
        ? ref.watch(dailySummaryProvider)
        : ref.watch(dailySummaryForDayProvider(dayKey));
    // The 概览 date rule ("year only outside the current year") keys off the
    // live today key, so the card's label follows the calendar on a tick too.
    final int currentYear = ref.watch(dashboardTodayKeyProvider).year;
    return switch (state) {
      DailySummaryLoading() => const AppCard(
        child: SizedBox(
          height: 160,
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      DailySummaryNoProfile(:final DayRollup rollup) => _SummaryCard(
        rollup: rollup,
        budget: null,
        isToday: isToday,
        currentYear: currentYear,
      ),
      DailySummaryReady(:final DayRollup rollup, :final EnergyBudget budget) =>
        _SummaryCard(
          rollup: rollup,
          budget: budget,
          isToday: isToday,
          currentYear: currentYear,
        ),
    };
  }
}

/// The card body for a known [rollup] and an optional engine [budget].
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.rollup,
    required this.budget,
    required this.isToday,
    required this.currentYear,
  });

  final DayRollup rollup;

  /// The engine budget, or `null` when the profile is incomplete.
  final EnergyBudget? budget;

  /// Whether this card summarizes the current day (default) or a past one.
  final bool isToday;

  /// The current year for the header's 概览 date rule (see [AppFormat.date]).
  final int currentYear;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppSemantics semantics = AppSemantics.of(context);
    // Read-only energy/salt values follow the display preference; the rollup
    // itself stays canonical (whole kcal + sodium mg).
    final DisplayUnits units = DisplayUnits.of(context);
    final EnergyBudget? budget = this.budget;
    final SignedBalance? balance = budget == null
        ? null
        : SignedBalance.fromBudget(budget);
    final Color ringColor = balance == null
        ? theme.colorScheme.primary
        : _balanceColor(context, balance.kind);
    // No budget → no signed balance → the flat primary stroke (a deficit is
    // never shown without a budget).
    final Color? ringTip = balance == null
        ? null
        : dailyRingGradientTip(context, balance.kind);
    final double ringProgress = budget == null || budget.budgetKcal <= 0
        ? 0
        : (rollup.intakeKcal / budget.budgetKcal).clamp(0.0, 1.0);

    return AppCard(
      padding: const EdgeInsets.all(AppDim.heroPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                isToday
                    ? S.of(context).dailySummaryTitle
                    : S.of(context).historyDailySummaryTitle,
                style: theme.textTheme.titleMedium,
              ),
              const Spacer(),
              Text(
                AppFormat.date(rollup.date, currentYear: currentYear),
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              CalorieRing(
                progress: ringProgress,
                color: ringColor,
                gradientEndColor: ringTip,
                size: 150,
                strokeWidth: 12,
                child: _RingCenter(
                  rollup: rollup,
                  balance: balance,
                  ringColor: ringColor,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (budget != null) ...<Widget>[
                      Text(
                        S.of(context).labelEnergy,
                        style: theme.textTheme.labelMedium,
                      ),
                      const SizedBox(height: 2),
                      _CountUp(
                        value: rollup.intakeKcal,
                        builder: (BuildContext context, int v) => ValueUnitText(
                          units.energyValueText(v),
                          units.energyUnit,
                          valueKey: dailyIntakeKcalKey,
                          valueStyle: theme.textTheme.headlineSmall!.copyWith(
                            fontFeatures: const <FontFeature>[
                              FontFeature.tabularFigures(),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _SideStat(
                        label: S.of(context).labelDailyBudget,
                        valueKey: dailyBudgetKey,
                        value: units.energyValueText(budget.budgetKcal),
                        unit: units.energyUnit,
                      ),
                      // The budget's composition is ALWAYS shown: with a goal
                      // it reads 目标 X + 运动 Y, without one 基础代谢 X +
                      // 运动 Y — so 额度 (and the 缺口/盈余 against it) never
                      // appears as an unexplained number.
                      const SizedBox(height: 2),
                      Text(
                        budget.goalKcal != null
                            ? S
                                  .of(context)
                                  .dailyGoalSubline(
                                    budget.goalKcal!,
                                    rollup.exerciseKcal,
                                  )
                            : S
                                  .of(context)
                                  .budgetBmrSubline(
                                    budget.bmrKcal,
                                    rollup.exerciseKcal,
                                  ),
                        key: dailyBudgetSublineKey,
                        style: theme.textTheme.labelSmall,
                      ),
                      const SizedBox(height: 10),
                    ],
                    _SideStat(
                      label: S.of(context).labelExerciseBurn,
                      valueKey: dailyExerciseKcalKey,
                      value: units.energyValueText(rollup.exerciseKcal),
                      unit: units.energyUnit,
                    ),
                    if (budget == null) ...<Widget>[
                      const SizedBox(height: 12),
                      Text(
                        S.of(context).dailyProfilePrompt,
                        key: dailyProfilePromptKey,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: <Widget>[
              Expanded(
                child: MetricTile(
                  label: S.of(context).labelCarb,
                  valueKey: dailyCarbKey,
                  value: formatDailyNumber(rollup.carbG),
                  unit: S.of(context).unitG,
                  color: semantics.carb,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: MetricTile(
                  label: S.of(context).labelProtein,
                  valueKey: dailyProteinKey,
                  value: formatDailyNumber(rollup.proteinG),
                  unit: S.of(context).unitG,
                  color: semantics.protein,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: MetricTile(
                  label: S.of(context).labelFat,
                  valueKey: dailyFatKey,
                  value: formatDailyNumber(rollup.fatG),
                  unit: S.of(context).unitG,
                  color: semantics.fat,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: MetricTile(
                  label: units.saltLabel,
                  valueKey: dailySaltKey,
                  value: units.saltProgressFromSaltG(rollup.saltG),
                  unit: units.saltUnit,
                  color: semantics.salt,
                  progress: (rollup.saltG / dailySaltTargetG).clamp(0.0, 1.0),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The ring's centre: the signed balance when a budget exists, otherwise the
/// raw intake (a deficit is never shown without a budget).
class _RingCenter extends StatelessWidget {
  const _RingCenter({
    required this.rollup,
    required this.balance,
    required this.ringColor,
  });

  final DayRollup rollup;
  final SignedBalance? balance;
  final Color ringColor;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    // The centre is read-only too: it switches to kJ with the rest of the card.
    final DisplayUnits units = DisplayUnits.of(context);
    final SignedBalance? balance = this.balance;
    final TextStyle bigValue = theme.textTheme.headlineSmall!.copyWith(
      fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
    );
    if (balance == null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(S.of(context).labelEnergy, style: theme.textTheme.labelSmall),
          _CountUp(
            value: rollup.intakeKcal,
            builder: (BuildContext context, int v) => Text(
              units.energyValueText(v),
              key: dailyIntakeKcalKey,
              style: bigValue.copyWith(fontSize: 24),
            ),
          ),
          Text(units.energyUnit, style: theme.textTheme.labelSmall),
        ],
      );
    }
    final Color color = _balanceColor(context, balance.kind);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          balance.label,
          key: dailyBalanceLabelKey,
          style: theme.textTheme.labelSmall!.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
        _CountUp(
          value: balance.valueKcal,
          builder: (BuildContext context, int v) => Text(
            units.energyValueText(v),
            key: dailyBalanceValueKey,
            style: bigValue.copyWith(color: color),
          ),
        ),
        Text(units.energyUnit, style: theme.textTheme.labelSmall),
      ],
    );
  }
}

/// One label-left / value-right line beside the ring.
class _SideStat extends StatelessWidget {
  const _SideStat({
    required this.label,
    required this.valueKey,
    required this.value,
    required this.unit,
  });

  final String label;
  final Key valueKey;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      children: <Widget>[
        Text(label, style: theme.textTheme.labelMedium),
        const SizedBox(width: 8),
        Flexible(
          child: ValueUnitText(
            value,
            unit,
            valueKey: valueKey,
            valueStyle: theme.textTheme.titleMedium!.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

/// The count-up wrapper for the hero's headline numbers: animates 0 → value
/// on first appearance and eases from the old to the new value when the
/// day's data changes. Honours the platform reduced-motion setting.
class _CountUp extends StatelessWidget {
  const _CountUp({required this.value, required this.builder});

  /// The settled value; also the tween's end.
  final int value;

  /// Builds the display for an intermediate (or settled) value.
  final Widget Function(BuildContext context, int value) builder;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return builder(context, value);
    }
    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: 0, end: value),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (BuildContext context, int v, Widget? _) => builder(context, v),
    );
  }
}
