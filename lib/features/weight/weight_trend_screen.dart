/// The 体重趋势 page: the full weight history behind the dashboard card.
///
/// A range switcher (近30天 / 近90天 / 全部) over one fl_chart line, three
/// headline stats (当前 / 近7天 / 累计), and a newest-first list grouped by
/// month — each row opens the entry sheet pre-filled (修改/删除). Everything
/// reads the same live [weightEntriesProvider] stream the card uses, so a save
/// here updates the dashboard the moment the user navigates back.
library;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:caldoo/core/theme/app_dimensions.dart';
import 'package:caldoo/core/theme/app_semantic_colors.dart';
import 'package:caldoo/domain/models/weight_entry.dart';
import 'package:caldoo/features/dashboard/daily/daily_summary_providers.dart'
    show dashboardTodayKeyProvider;
import 'package:caldoo/l10n/app_format.dart';
import 'package:caldoo/l10n/app_strings.dart';

import 'weight_entry_sheet.dart';
import 'weight_providers.dart';

/// Key of the trend screen scaffold.
const Key weightTrendScreenKey = Key('weight_trend_screen');

/// Key of the trend chart.
const Key weightChartKey = Key('weight_chart');

/// Key of the trend empty state.
const Key weightTrendEmptyKey = Key('weight_trend_empty');

/// Key of the list row for the entry recorded on [dayKey].
Key weightRowKey(DateTime dayKey) =>
    Key('weight_row_${dayKey.year}_${dayKey.month}_${dayKey.day}');

/// The selected chart window.
enum _WeightRange {
  days30(30),
  days90(90),
  all(0);

  const _WeightRange(this.days);

  /// The number of days, or `0` for "everything".
  final int days;
}

/// The full weight-history page.
class WeightTrendScreen extends ConsumerStatefulWidget {
  /// Creates the trend page.
  const WeightTrendScreen({super.key});

  @override
  ConsumerState<WeightTrendScreen> createState() => _WeightTrendScreenState();
}

class _WeightTrendScreenState extends ConsumerState<WeightTrendScreen> {
  _WeightRange _range = _WeightRange.days90;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final DateTime todayKey = ref.watch(dashboardTodayKeyProvider);
    final AsyncValue<List<WeightEntry>> entries = ref.watch(
      weightEntriesProvider,
    );
    final AppSemantics semantics = AppSemantics.of(context);

    return Scaffold(
      key: weightTrendScreenKey,
      appBar: AppBar(title: Text(S.of(context).weightTrendTitle)),
      body: entries.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace stack) =>
            Center(child: Text(S.of(context).loadFailed)),
        data: (List<WeightEntry> data) {
          if (data.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    S.of(context).weightTrendEmpty,
                    key: weightTrendEmptyKey,
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () =>
                        showWeightEntrySheet(context, initialDay: todayKey),
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(S.of(context).weightRecordAction),
                  ),
                ],
              ),
            );
          }
          final List<WeightEntry> window = _range == _WeightRange.all
              ? data
              : entriesWithinDays(data, todayKey, _range.days);
          final WeightEntry latest = data.last;
          final double? delta7d = deltaOverDays(data, todayKey, 7);
          final double deltaAll = latest.weightKg - data.first.weightKg;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: <Widget>[
              _StatsRow(
                latestKg: latest.weightKg,
                delta7d: delta7d,
                deltaAll: deltaAll,
              ),
              const SizedBox(height: 12),
              SegmentedButton<_WeightRange>(
                segments: <ButtonSegment<_WeightRange>>[
                  ButtonSegment<_WeightRange>(
                    value: _WeightRange.days30,
                    label: Text(S.of(context).weightRange30),
                  ),
                  ButtonSegment<_WeightRange>(
                    value: _WeightRange.days90,
                    label: Text(S.of(context).weightRange90),
                  ),
                  ButtonSegment<_WeightRange>(
                    value: _WeightRange.all,
                    label: Text(S.of(context).weightRangeAll),
                  ),
                ],
                selected: <_WeightRange>{_range},
                onSelectionChanged: (Set<_WeightRange> selection) =>
                    setState(() => _range = selection.first),
              ),
              const SizedBox(height: 12),
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 16, 16, 8),
                  child: SizedBox(
                    height: 200,
                    child: _TrendChart(
                      key: weightChartKey,
                      entries: window,
                      lineColor: semantics.deficit,
                      gridColor: theme.colorScheme.outlineVariant,
                      labelColor: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _EntryList(entries: data, todayKey: todayKey),
              const SizedBox(height: 12),
              Text(
                S.of(context).weightSyncNote,
                style: theme.textTheme.bodySmall,
              ),
            ],
          );
        },
      ),
    );
  }
}

/// 当前 / 近7天 / 累计 — the three headline numbers.
class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.latestKg,
    required this.delta7d,
    required this.deltaAll,
  });

  final double latestKg;
  final double? delta7d;
  final double deltaAll;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      children: <Widget>[
        Expanded(
          child: _Stat(
            label: S.of(context).weightStatNow,
            value: '${AppFormat.number(latestKg)} kg',
            color: null,
          ),
        ),
        Expanded(
          child: _Stat(
            label: S.of(context).weightStat7d,
            value: delta7d == null ? '—' : _signed(delta7d!),
            color: theme.colorScheme.primary,
          ),
        ),
        Expanded(
          child: _Stat(
            label: S.of(context).weightStatAll,
            value: _signed(deltaAll),
            color: theme.colorScheme.primary,
          ),
        ),
      ],
    );
  }

  static String _signed(double delta) {
    final String sign = delta > 0 ? '+' : (delta < 0 ? '−' : '');
    return '$sign${AppFormat.number(delta.abs())} kg';
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 3),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppDim.radiusControl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: theme.textTheme.labelSmall),
          const SizedBox(height: 2),
          Text(
            value,
            style: theme.textTheme.titleMedium!.copyWith(
              fontWeight: FontWeight.w700,
              color: color,
              fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// The window's line chart: x is the calendar window, y the recorded weight.
class _TrendChart extends StatelessWidget {
  const _TrendChart({
    super.key,
    required this.entries,
    required this.lineColor,
    required this.gridColor,
    required this.labelColor,
  });

  final List<WeightEntry> entries;
  final Color lineColor;
  final Color gridColor;
  final Color labelColor;

  @override
  Widget build(BuildContext context) {
    if (entries.length < 2) {
      return Center(
        child: Text(
          S.of(context).weightTrendEmpty,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }
    final DateTime windowStart = entries.first.dayKey;
    final DateTime windowEnd = entries.last.dayKey;
    final double maxX = windowEnd.difference(windowStart).inDays.toDouble();
    final double minY = entries
        .map((WeightEntry e) => e.weightKg)
        .reduce((double a, double b) => a < b ? a : b);
    final double maxY = entries
        .map((WeightEntry e) => e.weightKg)
        .reduce((double a, double b) => a > b ? a : b);
    final double pad = ((maxY - minY) * 0.25).clamp(0.2, 1.5);

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: maxX == 0 ? 1 : maxX,
        minY: minY - pad,
        maxY: maxY + pad,
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (List<LineBarSpot> spots) => <LineTooltipItem?>[
              for (final LineBarSpot spot in spots)
                LineTooltipItem(
                  '${AppFormat.number(entries[spot.spotIndex].weightKg)} kg\n'
                  '${AppFormat.date(windowStart.add(Duration(days: spot.x.round())))}',
                  const TextStyle(),
                ),
            ],
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: _interval(minY, maxY),
          getDrawingHorizontalLine: (double value) =>
              FlLine(color: gridColor, strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          leftTitles: const AxisTitles(),
          rightTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 38,
              interval: _interval(minY, maxY),
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
              reservedSize: 22,
              interval: maxX <= 0 ? 1 : (maxX / 3).clamp(1, double.infinity),
              getTitlesWidget: (double value, TitleMeta meta) {
                final DateTime day = windowStart.add(
                  Duration(days: value.round()),
                );
                return SideTitleWidget(
                  meta: meta,
                  child: Text(
                    '${day.month}月',
                    style: TextStyle(color: labelColor, fontSize: 10),
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: <LineChartBarData>[
          LineChartBarData(
            spots: <FlSpot>[
              for (final WeightEntry entry in entries)
                FlSpot(
                  entry.dayKey.difference(windowStart).inDays.toDouble(),
                  entry.weightKg,
                ),
            ],
            isCurved: false,
            barWidth: 2.2,
            color: lineColor,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: lineColor.withValues(alpha: 0.08),
            ),
          ),
        ],
      ),
    );
  }

  /// A "nice" y interval: ~3 grid lines between the padded bounds.
  static double _interval(double minY, double maxY) {
    final double span = (maxY - minY).clamp(0.4, double.infinity);
    return (span / 3).roundToDouble().clamp(0.5, double.infinity);
  }
}

/// The newest-first, month-grouped entry list.
class _EntryList extends StatelessWidget {
  const _EntryList({required this.entries, required this.todayKey});

  final List<WeightEntry> entries;

  /// Today's date-only key; rows use the same "year only outside the current
  /// year" date rule as the rest of the app.
  final DateTime todayKey;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<Widget> children = <Widget>[];
    // Walk newest-first; a month header precedes the first row of each group.
    // The group key is year*12+month, not the bare month number: a year
    // boundary with the same month number (2026-01 above 2025-01) must open a
    // new group, and the header then carries the year (2025年1月) to tell the
    // two apart.
    int? currentMonthIndex;
    for (int i = entries.length - 1; i >= 0; i--) {
      final WeightEntry entry = entries[i];
      final int monthIndex = entry.dayKey.year * 12 + entry.dayKey.month;
      if (currentMonthIndex != monthIndex || i == entries.length - 1) {
        currentMonthIndex = monthIndex;
        children.add(
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Text(
              AppFormat.month(
                DateTime.utc(entry.dayKey.year, entry.dayKey.month),
                // Same "current year" the rows use, so a header of an earlier
                // year keeps its year instead of printing it vacuously bare.
                currentYear: todayKey.year,
              ),
              style: theme.textTheme.titleSmall,
            ),
          ),
        );
      }
      final double? delta = i > 0
          ? entry.weightKg - entries[i - 1].weightKg
          : null;
      children.add(
        ListTile(
          key: weightRowKey(entry.dayKey),
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: Text(
            AppFormat.date(entry.dayKey, currentYear: todayKey.year),
            style: theme.textTheme.bodyMedium,
          ),
          subtitle: delta == null
              ? null
              : Text(_deltaText(delta), style: theme.textTheme.bodySmall),
          trailing: Text(
            '${AppFormat.number(entry.weightKg)} kg',
            style: theme.textTheme.titleMedium!.copyWith(
              fontWeight: FontWeight.w600,
              fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
          onTap: () => showWeightEntrySheet(
            context,
            initialDay: entry.dayKey,
            existing: entry,
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  static String _deltaText(double delta) {
    if (delta == 0) {
      return '±0.0';
    }
    final String sign = delta > 0 ? '+' : '−';
    return '$sign${AppFormat.number(delta.abs())}';
  }
}
