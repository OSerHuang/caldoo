import 'package:flutter/foundation.dart';
import 'package:json_annotation/json_annotation.dart';

import '../../core/units/nutrition_units.dart';

part 'daily_exercise.g.dart';

/// One editable exercise-burn value per local calendar day.
///
/// There is exactly one row per day: the burn is a single **whole kcal**
/// number the user edits (typically copied from a smartwatch), not a list of
/// logged sessions. The number is added back to the day's budget by the energy
/// engine (`lib/core/math/energy_balance.dart`) as `exerciseKcal`.
@immutable
@JsonSerializable(explicitToJson: true, checked: true)
class DailyExercise {
  const DailyExercise({required this.dayKey, required this.kcal});

  factory DailyExercise.fromJson(Map<String, dynamic> json) =>
      _$DailyExerciseFromJson(json);

  /// Local calendar date as a DATE-ONLY key: UTC-flagged midnight, exactly the
  /// shape `dayKeyOf()` in `lib/core/time/date_windows.dart` returns.
  ///
  /// Because it is already a date-only key, the day/week rollups match it with
  /// a direct `==` and perform NO offset conversion.
  final DateTime dayKey;

  /// Burn in **whole kcal** for that day (integer-only, like every energy
  /// number). A legacy fractional value is rounded at the JSON boundary by
  /// [kcalFromJson].
  @JsonKey(fromJson: kcalFromJson)
  final int kcal;

  Map<String, dynamic> toJson() => _$DailyExerciseToJson(this);

  DailyExercise copyWith({DateTime? dayKey, int? kcal}) =>
      DailyExercise(dayKey: dayKey ?? this.dayKey, kcal: kcal ?? this.kcal);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DailyExercise && other.dayKey == dayKey && other.kcal == kcal;

  @override
  int get hashCode => Object.hash(dayKey, kcal);

  @override
  String toString() => 'DailyExercise(dayKey: $dayKey, kcal: $kcal)';
}
