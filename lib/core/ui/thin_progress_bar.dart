/// A thin rounded progress bar (macro / salt / budget progress).
library;

import 'package:flutter/material.dart';

/// The bar. [value] is clamped to `0..1`; pass `null` for an indeterminate
/// shimmer-free idle state (renders as an empty track).
class ThinProgressBar extends StatelessWidget {
  /// Creates the bar.
  const ThinProgressBar({
    required this.value,
    super.key,
    this.color,
    this.trackColor,
    this.height = 6,
  });

  /// Fraction complete, `0..1` (values outside are clamped).
  final double? value;

  /// Fill colour; defaults to `colorScheme.primary`.
  final Color? color;

  /// Track colour; defaults to `colorScheme.surfaceContainerHighest`.
  final Color? trackColor;

  /// Bar thickness.
  final double height;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final double? clamped = value?.clamp(0.0, 1.0);
    return LinearProgressIndicator(
      value: clamped,
      minHeight: height,
      borderRadius: BorderRadius.circular(height / 2),
      color: color ?? colors.primary,
      backgroundColor: trackColor ?? colors.surfaceContainerHighest,
    );
  }
}
