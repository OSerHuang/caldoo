/// The 体重 block inside the weekly/monthly dashboard cards.
///
/// A SEPARATE line chart with its own kg axis — deliberately not overlaid on
/// the kcal bar chart (mixing units on one plot needs a second axis and reads
/// badly). The block is also the 周/月 discovery point for the weight feature:
/// with no in-period entries it shows a recording prompt instead of a chart,
/// and any state taps through to the full trend page (`/today/weight`).
///
/// `entries` must already be bounded to the period and day-ordered (the period
/// providers slice them with the same date-only keys as the meals/exercises).
library;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:caldoo/core/theme/app_dimensions.dart';
import 'package:caldoo/core/ui/app_card.dart';
import 'package:caldoo/core/ui/section_header.dart';
import 'package:caldoo/domain/models/weight_entry.dart';
import 'package:caldoo/l10n/app_format.dart';
import 'package:caldoo/l10n/app_strings.dart';

import 'weight_entry_sheet.dart';

/// The signed-kg text for a delta chip: `−0.6`, `+0.4`, `0` (no sign on zero).
String weightDeltaText(double deltaKg) {
  if (deltaKg == 0) {
    return AppFormat.number(0);
  }
  final String sign = deltaKg > 0 ? '+' : '−';
  return '$sign${AppFormat.number(deltaKg.abs())}';
}

/// The period's weight block: header (体重 + 期间变化) over its own kg line.
class WeightPeriodBlock extends ConsumerWidget {
  /// Creates the block for one period.
  ///
  /// [periodStart] is the date-only key of the FIRST slot (the week's Monday /
  /// the month's 1st); [slotCount] is 7 for a week, 28..31 for a month and
  /// drives both the x mapping and the tick labels. [recordInitialDay] is the
  /// day the 记录 sheet starts on (the period's last day; the sheet clamps a
  /// future day back to today itself).
  const WeightPeriodBlock({
    super.key,
    required this.entries,
    required this.periodStart,
    required this.slotCount,
    required this.recordInitialDay,
    required this.deltaKey,
  });

  /// The period's day-ordered weight entries.
  final List<WeightEntry> entries;

  /// The date-only key of the period's first slot.
  final DateTime periodStart;

  /// The period's slot count (7 = week, 28..31 = month).
  final int slotCount;

  /// The initial day for the 记录 sheet.
  final DateTime recordInitialDay;

  /// Key of the delta chip value (null with fewer than two entries).
  final Key? deltaKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final double? delta = entries.length < 2
        ? null
        : entries.last.weightKg - entries.first.weightKg;

    return AppCard(
      padding: const EdgeInsets.all(AppDim.cardPadding),
      onTap: () => context.push('/today/weight'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: SectionHeader(title: S.of(context).weightCardTitle),
              ),
              if (delta != null) ...<Widget>[
                Text(
                  '${weightDeltaText(delta)} kg',
                  key: deltaKey,
                  style: theme.textTheme.titleSmall!.copyWith(
                    fontWeight: FontWeight.w700,
                    color: delta < 0
                        ? theme.colorScheme.primary
                        : delta > 0
                        ? theme.colorScheme.error
                        : theme.colorScheme.onSurfaceVariant,
                    fontFeatures: const <FontFeature>[
                      FontFeature.tabularFigures(),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Text(
                S.of(context).weightCardOpenTrend,
                style: theme.textTheme.bodySmall,
              ),
              Icon(
                Icons.chevron_right,
                size: 18,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (entries.isEmpty)
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    S.of(context).weightCardEmptyPrompt,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.tonalIcon(
                  key: const Key('weight_block_record'),
                  onPressed: () => showWeightEntrySheet(
                    context,
                    initialDay: recordInitialDay,
                  ),
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(S.of(context).weightRecordAction),
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            )
          else
            SizedBox(
              height: 120,
              child: _PeriodWeightChart(
                entries: entries,
                periodStart: periodStart,
                slotCount: slotCount,
                lineColor: theme.colorScheme.primary,
                gridColor: theme.colorScheme.outlineVariant,
                labelColor: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}

/// The block's line chart: x = the period's day slots, y = kg, own axis.
class _PeriodWeightChart extends StatelessWidget {
  const _PeriodWeightChart({
    required this.entries,
    required this.periodStart,
    required this.slotCount,
    required this.lineColor,
    required this.gridColor,
    required this.labelColor,
  });

  final List<WeightEntry> entries;
  final DateTime periodStart;
  final int slotCount;
  final Color lineColor;
  final Color gridColor;
  final Color labelColor;

  @override
  Widget build(BuildContext context) {
    final double minY = entries
        .map((WeightEntry e) => e.weightKg)
        .reduce((double a, double b) => a < b ? a : b);
    final double maxY = entries
        .map((WeightEntry e) => e.weightKg)
        .reduce((double a, double b) => a > b ? a : b);
    final double pad = ((maxY - minY) * 0.3).clamp(0.2, 1.2);
    final double maxX = (slotCount - 1).toDouble();

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: maxX == 0 ? 1 : maxX,
        minY: minY - pad,
        maxY: maxY + pad,
        lineTouchData: const LineTouchData(enabled: false),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: (maxY - minY) / 2 == 0 ? 0.5 : (maxY - minY) / 2,
          getDrawingHorizontalLine: (double value) =>
              FlLine(color: gridColor, strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          leftTitles: const AxisTitles(),
          rightTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 34,
              interval: (maxY - minY) / 2 == 0 ? 0.5 : (maxY - minY) / 2,
              getTitlesWidget: (double value, TitleMeta meta) =>
                  SideTitleWidget(
                    meta: meta,
                    child: Text(
                      AppFormat.number(value),
                      style: TextStyle(color: labelColor, fontSize: 10),
                    ),
                  ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 20,
              getTitlesWidget: (double value, TitleMeta meta) =>
                  _xLabel(value, meta),
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: <LineChartBarData>[
          LineChartBarData(
            spots: <FlSpot>[
              for (final WeightEntry entry in entries)
                FlSpot(
                  entry.dayKey.difference(periodStart).inDays.toDouble(),
                  entry.weightKg,
                ),
            ],
            // A single recording draws as its dot only (isCurved over one
            // spot renders the dot anyway; the line simply has no length).
            isCurved: false,
            barWidth: 2.2,
            color: lineColor,
            dotData: FlDotData(
              show: true,
              getDotPainter: (
                FlSpot spot,
                double _,
                LineChartBarData _,
                int _,
              ) => FlDotCirclePainter(radius: 3, color: lineColor),
            ),
            belowBarData: BarAreaData(
              show: entries.length > 1,
              color: lineColor.withValues(alpha: 0.08),
            ),
          ),
        ],
      ),
    );
  }

  /// The x tick for slot [value]: weekday characters on a week, day-of-month
  /// numbers every 5 days on a month.
  Widget _xLabel(double value, TitleMeta meta) {
    final int slot = value.round();
    final String text;
    if (slotCount <= 7) {
      text = S.weekdayLabelsConst[slot.clamp(0, slotCount - 1)];
    } else {
      final int day = slot + 1; // 1-based day of month
      if (day != 1 && (day - 1) % 5 != 0) {
        return const SizedBox.shrink();
      }
      text = '$day';
    }
    return SideTitleWidget(
      meta: meta,
      child: Text(text, style: TextStyle(color: labelColor, fontSize: 10)),
    );
  }
}
