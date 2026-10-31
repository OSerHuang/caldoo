import 'package:json_annotation/json_annotation.dart';

import '../../core/units/nutrition_units.dart';

part 'day_rollup.g.dart';

/// Aggregated totals for one **local calendar day**.
///
/// Produced by the day/week rollup functions (task 9); consumed by the daily
/// and weekly dashboards. It deliberately does NOT carry a budget or a
/// deficit: the budget comes from the energy engine (task 7) applied to the
/// profile, and the dashboard composes the two so the formula lives in exactly
/// one place.
///
/// Canonical units: energy **whole kcal (int)**, macros g, sodium **mg**
/// ([saltG] is derived for display).
@JsonSerializable(explicitToJson: true, checked: true)
class DayRollup {
  const DayRollup({
    required this.date,
    this.intakeKcal = 0,
    this.carbG = 0,
    this.proteinG = 0,
    this.fatG = 0,
    this.sodiumMg = 0,
    this.exerciseKcal = 0,
    this.mealCount = 0,
  });

  factory DayRollup.fromJson(Map<String, dynamic> json) =>
      _$DayRollupFromJson(json);

  /// The local calendar day this rollup covers (local midnight).
  final DateTime date;

  /// Total food energy in **whole kcal** (integer-only).
  @JsonKey(fromJson: kcalFromJson)
  final int intakeKcal;

  /// Total carbohydrate in grams.
  final double carbG;

  /// Total protein in grams.
  final double proteinG;

  /// Total fat in grams.
  final double fatG;

  /// Total sodium in mg (canonical).
  final double sodiumMg;

  /// Total exercise burn added back to the budget, in **whole kcal**
  /// (integer-only).
  @JsonKey(fromJson: kcalFromJson)
  final int exerciseKcal;

  /// Number of meals logged that day (a "logged day" has >= 1).
  final int mealCount;

  /// Display-only salt equivalent of [sodiumMg] (1 g salt = 400 mg Na).
  double get saltG => sodiumMgToSaltG(sodiumMg);

  Map<String, dynamic> toJson() => _$DayRollupToJson(this);

  DayRollup copyWith({
    DateTime? date,
    int? intakeKcal,
    double? carbG,
    double? proteinG,
    double? fatG,
    double? sodiumMg,
    int? exerciseKcal,
    int? mealCount,
  }) {
    return DayRollup(
      date: date ?? this.date,
      intakeKcal: intakeKcal ?? this.intakeKcal,
      carbG: carbG ?? this.carbG,
      proteinG: proteinG ?? this.proteinG,
      fatG: fatG ?? this.fatG,
      sodiumMg: sodiumMg ?? this.sodiumMg,
      exerciseKcal: exerciseKcal ?? this.exerciseKcal,
      mealCount: mealCount ?? this.mealCount,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is DayRollup &&
            other.date == date &&
            other.intakeKcal == intakeKcal &&
            other.carbG == carbG &&
            other.proteinG == proteinG &&
            other.fatG == fatG &&
            other.sodiumMg == sodiumMg &&
            other.exerciseKcal == exerciseKcal &&
            other.mealCount == mealCount;
  }

  @override
  int get hashCode => Object.hash(
    date,
    intakeKcal,
    carbG,
    proteinG,
    fatG,
    sodiumMg,
    exerciseKcal,
    mealCount,
  );
}
