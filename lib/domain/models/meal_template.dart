import 'package:json_annotation/json_annotation.dart';

import 'meal.dart';
import 'meal_item.dart';

part 'meal_template.g.dart';

/// A user-saved snapshot of a logged meal, reusable for future records.
///
/// A template owns the source meal's [MealType] (the default for a meal filled
/// from it) and a copy of its item lines — energy in **whole kcal (int)**,
/// macros in g, exactly like [MealItem]. Items keep their `source` and
/// `foodId`: when a meal is filled from the template, a label-backed line can
/// still recompute from its saved food's per-100 g values on a grams edit.
///
/// A template has no time: the moment of use belongs to the new meal, not to
/// the snapshot. The stored item ids are meaningless — filling a meal always
/// re-issues fresh ids.
@JsonSerializable(explicitToJson: true, checked: true)
class MealTemplate {
  const MealTemplate({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.mealType,
    required this.items,
  });

  factory MealTemplate.fromJson(Map<String, dynamic> json) =>
      _$MealTemplateFromJson(json);

  /// UUID of the template.
  final String id;

  /// User-visible (editable) name; defaults to the source meal's item names.
  final String name;

  /// When the template was saved (display + list ordering only).
  final DateTime createdAt;

  /// The source meal's type; the pre-filled meal type when the template is
  /// used (the review screen's selector can change it).
  final MealType mealType;

  /// The copied food lines, in the source meal's order.
  final List<MealItem> items;

  /// Summed energy in **whole kcal** over [items].
  int get totalKcal {
    var total = 0;
    for (final MealItem item in items) {
      total += item.kcal;
    }
    return total;
  }

  Map<String, dynamic> toJson() => _$MealTemplateToJson(this);

  MealTemplate copyWith({
    String? id,
    String? name,
    DateTime? createdAt,
    MealType? mealType,
    List<MealItem>? items,
  }) {
    return MealTemplate(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      mealType: mealType ?? this.mealType,
      items: items ?? this.items,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is MealTemplate &&
            other.id == id &&
            other.name == name &&
            other.createdAt == createdAt &&
            other.mealType == mealType &&
            _itemsEqual(other.items, items);
  }

  @override
  int get hashCode =>
      Object.hash(id, name, createdAt, mealType, Object.hashAll(items));

  static bool _itemsEqual(List<MealItem> a, List<MealItem> b) {
    if (a.length != b.length) {
      return false;
    }
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) {
        return false;
      }
    }
    return true;
  }
}
