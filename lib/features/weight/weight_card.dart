/// The 体重 card on the dashboard's day page (today only).
///
/// A compact window on the weight history: the latest value, the 7-day change
/// and a 30-day sparkline, plus a 记录 action opening the entry sheet. Tapping
/// the card opens the full trend page (`/today/weight`). With no recorded
/// weight it is a one-line prompt instead of an empty chart.
///
/// The card renders TODAY's state regardless of which day page it sits on
/// (the weight log is a "current self" metric, not a per-day rollup), which is
/// why it is mounted only on the today page.
library;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:caldoo/core/ui/app_card.dart';
import 'package:caldoo/core/theme/app_dimensions.dart';
import 'package:caldoo/domain/models/weight_entry.dart';
import 'package:caldoo/l10n/app_format.dart';
import 'package:caldoo/l10n/app_strings.dart';

import 'weight_entry_sheet.dart';
import 'weight_providers.dart';

/// Key of the 体重 card root.
const Key weightCardKey = Key('weight_card');

/// Key of the card's 记录 action.
const Key weightCardRecordKey = Key('weight_card_record');

/// Key of the card's latest-weight value.
const Key weightCardValueKey = Key('weight_card_value');

/// The compact weight card for the today page.
class WeightCard extends ConsumerWidget {
  /// Creates the card; [todayKey] bounds the sparkline window.
  const WeightCard({super.key, required this.todayKey});

  /// The date-only key of the day the card is rendered on.
  final DateTime todayKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final AsyncValue<List<WeightEntry>> entries = ref.watch(
      weightEntriesProvider,
    );
    // The page mounts the card only when the history is non-empty, so the
    // loading / error / empty cases degrade to "nothing" instead of taking
    // vertical space on the dense day page.
    return entries.maybeWhen(
      data: (List<WeightEntry> data) {
        final WeightEntry? latest = latestWeightOf(data);
        if (latest == null) {
          return const SizedBox.shrink();
        }
        final double? delta7d = deltaOverDays(data, todayKey, 7);
        return AppCard(
          key: weightCardKey,
          onTap: () => context.push('/today/weight'),
          padding: const EdgeInsets.all(AppDim.cardPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      S.of(context).weightCardTitle,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  FilledButton.tonalIcon(
                    key: weightCardRecordKey,
                    onPressed: () =>
                        showWeightEntrySheet(context, initialDay: todayKey),
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(S.of(context).weightRecordAction),
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Text(
                    '${AppFormat.number(latest.weightKg)} kg',
                    key: weightCardValueKey,
                    style: theme.textTheme.headlineSmall!.copyWith(
                      fontFeatures: const <FontFeature>[
                        FontFeature.tabularFigures(),
                      ],
                    ),
                  ),
                  if (delta7d != null) ...<Widget>[
                    const SizedBox(width: 10),
                    _DeltaChip(deltaKg: delta7d),
                  ],
                  const Spacer(),
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
              SizedBox(
                height: 56,
                child: _WeightSparkline(
                  entries: entriesWithinDays(data, todayKey, 30),
                ),
              ),
            ],
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

/// The 7-day change chip: green for a loss, red for a gain, grey for flat.
class _DeltaChip extends StatelessWidget {
  const _DeltaChip({required this.deltaKg});

  final double deltaKg;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String sign = deltaKg > 0 ? '+' : (deltaKg < 0 ? '−' : '');
    final String text = '$sign${AppFormat.number(deltaKg.abs())}';
    final Color color = deltaKg < 0
        ? theme.colorScheme.primary
        : deltaKg > 0
        ? theme.colorScheme.error
        : theme.colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppDim.radiusBadge),
      ),
      child: Text(
        S.of(context).weightDelta7d(text),
        style: theme.textTheme.labelSmall!.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
          fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

/// The 30-day sparkline: a single flat line, no axes, no interaction.
class _WeightSparkline extends StatelessWidget {
  const _WeightSparkline({required this.entries});

  final List<WeightEntry> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.length < 2) {
      return const SizedBox.shrink();
    }
    final ThemeData theme = Theme.of(context);
    final double minY = entries
        .map((WeightEntry e) => e.weightKg)
        .reduce((double a, double b) => a < b ? a : b);
    final double maxY = entries
        .map((WeightEntry e) => e.weightKg)
        .reduce((double a, double b) => a > b ? a : b);
    final double pad = ((maxY - minY) * 0.2).clamp(0.1, 1.0);
    return LineChart(
      LineChartData(
        minY: minY - pad,
        maxY: maxY + pad,
        minX: 0,
        maxX: (entries.length - 1).toDouble(),
        lineTouchData: const LineTouchData(enabled: false),
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineBarsData: <LineChartBarData>[
          LineChartBarData(
            spots: <FlSpot>[
              for (int i = 0; i < entries.length; i++)
                FlSpot(i.toDouble(), entries[i].weightKg),
            ],
            isCurved: false,
            barWidth: 2,
            color: theme.colorScheme.primary,
            dotData: const FlDotData(show: false),
          ),
        ],
      ),
    );
  }
}
