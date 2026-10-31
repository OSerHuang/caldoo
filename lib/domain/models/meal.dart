import 'package:json_annotation/json_annotation.dart';

part 'meal.g.dart';

/// Which meal of the day an entry belongs to.
enum MealType { breakfast, lunch, dinner, snack }

/// A logged meal: the grouping record that owns its [MealItem]s.
///
/// [timestamp] is the instant the meal is attributed to; day/week rollups
/// resolve it to a **local calendar date** using an explicit offset (see
/// `lib/core/time/date_windows.dart`, task 9).
@JsonSerializable(explicitToJson: true, checked: true)
class Meal {
  const Meal({
    required this.id,
    required this.timestamp,
    required this.mealType,
    this.note,
  });

  factory Meal.fromJson(Map<String, dynamic> json) => _$MealFromJson(json);

  final String id;
  final DateTime timestamp;
  final MealType mealType;

  /// Optional free-text note.
  final String? note;

  Map<String, dynamic> toJson() => _$MealToJson(this);

  Meal copyWith({
    String? id,
    DateTime? timestamp,
    MealType? mealType,
    String? note,
  }) {
    return Meal(
      id: id ?? this.id,
      timestamp: timestamp ?? this.timestamp,
      mealType: mealType ?? this.mealType,
      note: note ?? this.note,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is Meal &&
            other.id == id &&
            other.timestamp == timestamp &&
            other.mealType == mealType &&
            other.note == note;
  }

  @override
  int get hashCode => Object.hash(id, timestamp, mealType, note);
}
