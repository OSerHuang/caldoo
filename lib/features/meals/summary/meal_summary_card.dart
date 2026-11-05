/// The per-meal summary card (task 22).
///
/// Shows two blocks for one logged meal:
/// * **本餐合计** — this meal's kcal / macros / salt, summed from its items;
/// * **今日累计 / 当日累计** — the running day intake of the MEAL'S OWN day,
///   driven by the repository `watch` stream (never a cached read): today's
///   meal shows 今日累计, a history meal shows 当日累计 for its own day.
///
/// Both blocks are read-only, so they follow the display-unit preference
/// (`DisplayUnits.of`): energy shows kcal or kJ, and the salt row shows salt
/// grams or sodium milligrams. The stored totals stay canonical.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:caldoo/core/time/date_windows.dart'
    show LocalOffset, currentDayKey, dayKeyOf, wallClockOf;
import 'package:caldoo/core/units/display_units.dart';
import 'package:caldoo/domain/models/models.dart';
import 'package:caldoo/l10n/app_format.dart';
import 'package:caldoo/l10n/app_strings.dart';

import 'meal_summary_providers.dart';
import 'meal_totals.dart';

/// Key of the meal-total energy value.
const Key mealSummaryKcalKey = Key('meal_summary_kcal');

/// Key of the meal-total carbohydrate value.
const Key mealSummaryCarbKey = Key('meal_summary_carb');

/// Key of the meal-total protein value.
const Key mealSummaryProteinKey = Key('meal_summary_protein');

/// Key of the meal-total fat value.
const Key mealSummaryFatKey = Key('meal_summary_fat');

/// Key of the meal-total salt value.
const Key mealSummarySaltKey = Key('meal_summary_salt');

/// Key of the day-running-total energy value.
const Key dayTotalKcalKey = Key('day_total_kcal');

/// Key of the day-running-total carbohydrate value.
const Key dayTotalCarbKey = Key('day_total_carb');

/// Key of the day-running-total protein value.
const Key dayTotalProteinKey = Key('day_total_protein');

/// Key of the day-running-total fat value.
const Key dayTotalFatKey = Key('day_total_fat');

/// Key of the day-running-total salt value.
const Key dayTotalSaltKey = Key('day_total_salt');

/// Key of the card's recorded-time line.
const Key mealSummaryTimeKey = Key('meal_summary_time');

/// A zh-CN label for a [MealType].
String mealTypeLabel(MealType type) => switch (type) {
  MealType.breakfast => S.instance.mealTypeBreakfast,
  MealType.lunch => S.instance.mealTypeLunch,
  MealType.dinner => S.instance.mealTypeDinner,
  MealType.snack => S.instance.mealTypeSnack,
};

/// Renders one meal's totals plus the live day running total.
class MealSummaryCard extends ConsumerWidget {
  /// Creates the card for [meal] and its [items].
  const MealSummaryCard({super.key, required this.meal, required this.items});

  /// The meal the card is titled after.
  final Meal meal;

  /// The meal's items; summed for the 本餐合计 block.
  final List<MealItem> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final MealTotals mealTotals = MealTotals.fromItems(items);
    // The 累计 line is the meal's OWN day's running total: a past-day meal
    // opened from history must show that day's numbers, never the wall-clock
    // day's (the old hardwired 今日 stream paired Monday's meal with
    // Wednesday's running intake).
    final LocalOffset offset = ref.watch(localOffsetProvider);
    final DateTime mealDayKey = dayKeyOf(meal.timestamp, offset);
    final bool isToday =
        mealDayKey ==
        currentDayKey(clock: ref.watch(summaryClockProvider), offset: offset);
    final MealTotals dayTotals = isToday
        ? ref.watch(todayTotalsProvider)
        : ref.watch(dayTotalsForDayProvider(mealDayKey));
    // The time the record is attributed to, resolved to the app's own local
    // wall clock (never the machine timezone): a mis-stamped meal is otherwise
    // indistinguishable from a correctly stamped one on the day log.
    final DateTime wallClock = wallClockOf(meal.timestamp, offset);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              mealTypeLabel(meal.mealType),
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 2),
            Text(
              AppFormat.dateTimeMinute(wallClock),
              key: mealSummaryTimeKey,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            _TotalsBlock(
              title: S.of(context).mealTotalsThis,
              kcalKey: mealSummaryKcalKey,
              carbKey: mealSummaryCarbKey,
              proteinKey: mealSummaryProteinKey,
              fatKey: mealSummaryFatKey,
              saltKey: mealSummarySaltKey,
              totals: mealTotals,
            ),
            const Divider(height: 24),
            _TotalsBlock(
              title: isToday
                  ? S.of(context).mealTotalsToday
                  : S.of(context).mealTotalsThatDay,
              kcalKey: dayTotalKcalKey,
              carbKey: dayTotalCarbKey,
              proteinKey: dayTotalProteinKey,
              fatKey: dayTotalFatKey,
              saltKey: dayTotalSaltKey,
              totals: dayTotals,
            ),
          ],
        ),
      ),
    );
  }
}

/// One titled kcal / carb / protein / fat / salt block.
class _TotalsBlock extends StatelessWidget {
  const _TotalsBlock({
    required this.title,
    required this.kcalKey,
    required this.carbKey,
    required this.proteinKey,
    required this.fatKey,
    required this.saltKey,
    required this.totals,
  });

  final String title;
  final Key kcalKey;
  final Key carbKey;
  final Key proteinKey;
  final Key fatKey;
  final Key saltKey;
  final MealTotals totals;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    // Read-only totals: the energy unit and the salt/sodium basis follow the
    // display preference, while the stored kcal / sodium mg stay canonical.
    final DisplayUnits units = DisplayUnits.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(title, style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        _TotalRow(
          label: S.of(context).labelEnergy,
          unit: units.energyUnit,
          valueKey: kcalKey,
          value: units.energyValue(totals.kcal),
        ),
        _TotalRow(
          label: S.of(context).labelCarb,
          unit: S.of(context).unitG,
          valueKey: carbKey,
          value: totals.carbG,
        ),
        _TotalRow(
          label: S.of(context).labelProtein,
          unit: S.of(context).unitG,
          valueKey: proteinKey,
          value: totals.proteinG,
        ),
        _TotalRow(
          label: S.of(context).labelFat,
          unit: S.of(context).unitG,
          valueKey: fatKey,
          value: totals.fatG,
        ),
        _TotalRow(
          label: units.saltLabel,
          unit: units.saltUnit,
          valueKey: saltKey,
          value: units.showsSodium ? totals.sodiumMg : totals.saltG,
        ),
      ],
    );
  }
}

/// One label / value / unit line.
class _TotalRow extends StatelessWidget {
  const _TotalRow({
    required this.label,
    required this.unit,
    required this.valueKey,
    required this.value,
  });

  final String label;
  final String unit;
  final Key valueKey;

  /// Energy arrives as `int`, macros as `double`; [AppFormat.number] renders
  /// both without a trailing `.0`.
  final num value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 52,
            child: Text(label, style: theme.textTheme.labelMedium),
          ),
          Text(
            AppFormat.number(value),
            key: valueKey,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: 4),
          Text(unit, style: theme.textTheme.labelSmall),
        ],
      ),
    );
  }
}
