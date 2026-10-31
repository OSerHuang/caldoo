/// The standard rounded card used across the app.
///
/// A flat elevated surface (`surfaceContainerLow`) with a large radius and
/// no shadow — separation comes from the background contrast. With [onTap]
/// it clips an ink ripple to the rounded shape.
library;

import 'package:flutter/material.dart';

import '../theme/app_dimensions.dart';

/// The standard card surface.
class AppCard extends StatelessWidget {
  /// Creates the card. [padding] defaults to [AppDim.cardPadding]; pass
  /// [EdgeInsets.zero] to lay out the content edge-to-edge.
  const AppCard({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.all(AppDim.cardPadding),
    this.onTap,
    this.radius = AppDim.radiusCard,
    this.color,
  });

  /// The card content.
  final Widget child;

  /// Padding around [child]; `null` falls back to the standard card padding.
  final EdgeInsetsGeometry? padding;

  /// When set the whole card is tappable with an ink response.
  final VoidCallback? onTap;

  /// Corner radius; defaults to the large card token.
  final double radius;

  /// Overrides the surface colour (defaults to `surfaceContainerLow`).
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color ?? Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(radius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding!, child: child),
      ),
    );
  }
}
