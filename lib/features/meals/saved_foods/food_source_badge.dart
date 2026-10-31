/// The 官方标签 / AI估算 / 手动录入 badge for a saved [Food] (task 20).
///
/// The badge is a direct projection of [Food.source] — the picker never invents
/// provenance. `label` (a GB 28050 营养成分表) is the authoritative source, so
/// it is the one the suggestion flow prefers.
library;

import 'package:flutter/material.dart';

import 'package:caldoo/domain/models/models.dart';
import 'package:caldoo/l10n/app_strings.dart';

/// Small chip labelling where a food's values came from.
class FoodSourceBadge extends StatelessWidget {
  const FoodSourceBadge({super.key, required this.source});

  final FoodSource source;

  /// The user-facing label for [source].
  static String labelFor(FoodSource source) => switch (source) {
    FoodSource.label => S.instance.foodSourceLabel,
    FoodSource.ai => S.instance.foodSourceAi,
    FoodSource.manual => S.instance.foodSourceManual,
  };

  /// A stable key so a picker tile can be asserted per food.
  static Key keyFor(String foodId) => Key('saved_food_badge_$foodId');

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final (Color background, Color foreground) = switch (source) {
      FoodSource.label => (colors.primaryContainer, colors.onPrimaryContainer),
      FoodSource.ai => (
        colors.surfaceContainerHighest,
        colors.onSurfaceVariant,
      ),
      FoodSource.manual => (
        colors.secondaryContainer,
        colors.onSecondaryContainer,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        labelFor(source),
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: foreground, fontWeight: FontWeight.w600),
      ),
    );
  }
}
