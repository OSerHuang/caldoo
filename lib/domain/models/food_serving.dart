/// One serving / package size recorded on a saved [Food], e.g. `一袋 120 g`.
///
/// This is structured data now: the label-capture and supplement editors write
/// it, and the label-link call uses it to turn 「一袋辛拉面」 into real grams.
/// `notes` used to carry the same facts as prose and is still parsed for legacy
/// rows (`parseFoodServings` in `label_priority.dart`), but new data never has
/// to be re-parsed from text.
///
/// Unit contract: [unit] is `'g'` (weight) or `'ml'` (volume). `ml` is kept
/// distinct because weight cannot be derived without a density; the AI prompt
/// and the gram resolver use the existing `1 ml ≈ 1 g` convention on top.
library;

import 'package:json_annotation/json_annotation.dart';

part 'food_serving.g.dart';

/// A named serving size, e.g. `一包 / 120 g` or `一盒 / 500 ml`.
@JsonSerializable()
class FoodServing {
  const FoodServing({
    required this.label,
    required this.amount,
    required this.unit,
  });

  factory FoodServing.fromJson(Map<String, dynamic> json) =>
      _$FoodServingFromJson(json);

  /// The serving label exactly as the user wrote it: `一袋`, `一块`, `一份/一袋`.
  final String label;

  /// The amount, always positive and finite.
  final double amount;

  /// Normalised unit: `'g'` (weight) or `'ml'` (volume).
  final String unit;

  /// `true` when the serving is a volume (`ml`), not a weight.
  bool get isVolume => unit == 'ml';

  Map<String, dynamic> toJson() => _$FoodServingToJson(this);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is FoodServing &&
            other.label == label &&
            other.amount == amount &&
            other.unit == unit;
  }

  @override
  int get hashCode => Object.hash(label, amount, unit);

  @override
  String toString() => 'FoodServing($label $amount $unit)';
}
