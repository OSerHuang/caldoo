import 'package:flutter/foundation.dart';
import 'package:json_annotation/json_annotation.dart';

part 'weight_entry.g.dart';

/// One recorded body-weight value per local calendar day.
///
/// There is exactly one row per day (the day is the primary key): re-recording
/// a day **overwrites** it, so the history is always one clean value per date.
/// The latest entry also updates the profile's `weightKg` (the BMR input) — the
/// sync contract lives on [WeightRepository.saveWeight].
@immutable
@JsonSerializable(explicitToJson: true, checked: true)
class WeightEntry {
  const WeightEntry({required this.dayKey, required this.weightKg});

  factory WeightEntry.fromJson(Map<String, dynamic> json) =>
      _$WeightEntryFromJson(json);

  /// Local calendar date as a DATE-ONLY key: UTC-flagged midnight, exactly the
  /// shape `dayKeyOf()` in `lib/core/time/date_windows.dart` returns.
  ///
  /// Because it is already a date-only key, range queries match it with direct
  /// comparisons and perform NO offset conversion.
  final DateTime dayKey;

  /// Body weight in kilograms (positive, up to two decimals).
  @JsonKey(fromJson: weightFromJson)
  final double weightKg;

  Map<String, dynamic> toJson() => _$WeightEntryToJson(this);

  WeightEntry copyWith({DateTime? dayKey, double? weightKg}) => WeightEntry(
    dayKey: dayKey ?? this.dayKey,
    weightKg: weightKg ?? this.weightKg,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WeightEntry &&
          other.dayKey == dayKey &&
          other.weightKg == weightKg;

  @override
  int get hashCode => Object.hash(dayKey, weightKg);

  @override
  String toString() => 'WeightEntry(dayKey: $dayKey, weightKg: $weightKg)';
}

/// Tolerant JSON boundary for the stored weight: legacy/foreign writers may
/// emit `68` (int) or `68.45`; both parse, non-finite/non-positive throws.
double weightFromJson(Object? value) {
  if (value is! num) {
    throw ArgumentError.value(value, 'weightKg', 'must be a number');
  }
  final double kg = value.toDouble();
  if (!kg.isFinite || kg <= 0) {
    throw ArgumentError.value(kg, 'weightKg', 'must be finite and positive');
  }
  return kg;
}
