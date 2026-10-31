/// A value + unit text pair (e.g. `1,842` + `kcal`), baseline-aligned with
/// tabular figures so numbers of equal width align across rows.
library;

import 'package:flutter/material.dart';

/// The numeric text with its trailing unit.
class ValueUnitText extends StatelessWidget {
  /// Creates the pair. [value] should be pre-formatted; the unit renders in
  /// a smaller, muted style unless [unitStyle] overrides it.
  const ValueUnitText(
    this.value,
    this.unit, {
    super.key,
    this.valueKey,
    this.valueStyle,
    this.unitStyle,
  });

  /// The numeric value, pre-formatted.
  final String value;

  /// The unit label (kcal / g …).
  final String unit;

  /// Optional key attached to the value [Text] (widget-test hooks).
  final Key? valueKey;

  /// Style for [value]; must keep `fontFeatures` tabular figures.
  final TextStyle? valueStyle;

  /// Style for [unit].
  final TextStyle? unitStyle;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TextStyle resolvedValue = valueStyle ?? theme.textTheme.titleMedium!;
    final TextStyle resolvedUnit =
        unitStyle ??
        theme.textTheme.labelSmall!.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        );
    // Scale down instead of overflowing when the parent is narrower than the
    // natural `1,935.75 kcal` width (tight hero rows).
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: <Widget>[
          Text(
            value,
            key: valueKey,
            style: resolvedValue.copyWith(
              fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: 3),
          Text(unit, style: resolvedUnit),
        ],
      ),
    );
  }
}
