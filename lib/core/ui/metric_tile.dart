/// A compact "label + big value + unit (+ progress)" tile — the metric cell
/// used in dashboard grids (碳水 / 蛋白 / 脂肪 / 盐 …).
library;

import 'package:flutter/material.dart';

import '../theme/app_dimensions.dart';
import 'thin_progress_bar.dart';
import 'value_unit_text.dart';

/// The tile. When [progress] is set (a `0..1` fraction) a thin bar renders
/// under the value; when [color] is set the label gets a small colour dot
/// and the bar (if any) is tinted with it.
class MetricTile extends StatelessWidget {
  /// Creates the tile.
  const MetricTile({
    required this.label,
    required this.value,
    required this.unit,
    super.key,
    this.valueKey,
    this.progress,
    this.color,
    this.dotAlways = false,
  });

  /// The metric name (碳水 …).
  final String label;

  /// The pre-formatted numeric value.
  final String value;

  /// The unit (g / kcal …).
  final String unit;

  /// Optional key attached to the value [Text] (widget-test hooks).
  final Key? valueKey;

  /// Optional `0..1` fraction shown as a thin bar.
  final double? progress;

  /// Accent colour for the dot / bar; defaults to the primary.
  final Color? color;

  /// Show the colour dot even without a [progress] bar.
  final bool dotAlways;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color? accent = color;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDim.cardPadding,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppDim.radiusContainer),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              if (accent != null &&
                  (dotAlways || progress != null)) ...<Widget>[
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: accent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: theme.textTheme.labelMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          const SizedBox(height: 6),
          ValueUnitText(
            value,
            unit,
            valueKey: valueKey,
            valueStyle: theme.textTheme.titleMedium!.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          if (progress != null) ...<Widget>[
            const SizedBox(height: 8),
            ThinProgressBar(value: progress, color: accent),
          ],
        ],
      ),
    );
  }
}
