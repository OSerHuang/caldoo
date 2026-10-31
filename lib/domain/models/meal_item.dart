import 'package:json_annotation/json_annotation.dart';

import '../../core/units/nutrition_units.dart';
import 'food.dart';

part 'meal_item.g.dart';

/// One food line inside a [Meal], already scaled to the consumed [grams].
///
/// Canonical units: energy in **whole kcal (int)**, macros in **g**. Salt is
/// the one display-unit field that lives on an item — `MealItem` carries
/// [saltG] (that is what the UI shows and what the AI returns) and converts at
/// the boundary: [sodiumMg] derives the canonical milligram value with
/// `saltGToSodiumMg`. `Food` remains the single place where sodium mg is
/// stored canonically.
@JsonSerializable(explicitToJson: true, checked: true)
class MealItem {
  const MealItem({
    required this.id,
    this.foodId,
    required this.name,
    required this.grams,
    required this.kcal,
    required this.carbG,
    required this.proteinG,
    required this.fatG,
    required this.saltG,
    required this.source,
    this.confidence,
  });

  factory MealItem.fromJson(Map<String, dynamic> json) =>
      _$MealItemFromJson(json);

  final String id;

  /// Link to the saved [Food] this item was resolved from, when any.
  ///
  /// The caller stores `foodId` + [grams] so a later grams edit can recompute
  /// from the per-100 g values instead of freezing a snapshot.
  final String? foodId;

  final String name;

  /// Consumed weight in grams.
  final double grams;

  /// Energy in **whole kcal** (canonical, integer-only).
  ///
  /// A fractional value in a legacy backup/row is rounded once at this
  /// boundary by [kcalFromJson].
  @JsonKey(fromJson: kcalFromJson)
  final int kcal;

  /// Carbohydrate in grams.
  final double carbG;

  /// Protein in grams.
  final double proteinG;

  /// Fat in grams.
  final double fatG;

  /// Salt in grams — the display unit carried on the item.
  final double saltG;

  /// Per-item provenance (`label` when a saved label food was applied).
  final FoodSource source;

  /// AI self-reported confidence (0..1) when the provider returned one.
  final double? confidence;

  /// Canonical sodium in mg, derived from [saltG] (1 g salt = 400 mg Na).
  double get sodiumMg => saltGToSodiumMg(saltG);

  Map<String, dynamic> toJson() => _$MealItemToJson(this);

  MealItem copyWith({
    String? id,
    String? foodId,
    String? name,
    double? grams,
    int? kcal,
    double? carbG,
    double? proteinG,
    double? fatG,
    double? saltG,
    FoodSource? source,
    double? confidence,
  }) {
    return MealItem(
      id: id ?? this.id,
      foodId: foodId ?? this.foodId,
      name: name ?? this.name,
      grams: grams ?? this.grams,
      kcal: kcal ?? this.kcal,
      carbG: carbG ?? this.carbG,
      proteinG: proteinG ?? this.proteinG,
      fatG: fatG ?? this.fatG,
      saltG: saltG ?? this.saltG,
      source: source ?? this.source,
      confidence: confidence ?? this.confidence,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is MealItem &&
            other.id == id &&
            other.foodId == foodId &&
            other.name == name &&
            other.grams == grams &&
            other.kcal == kcal &&
            other.carbG == carbG &&
            other.proteinG == proteinG &&
            other.fatG == fatG &&
            other.saltG == saltG &&
            other.source == source &&
            other.confidence == confidence;
  }

  @override
  int get hashCode => Object.hash(
    id,
    foodId,
    name,
    grams,
    kcal,
    carbG,
    proteinG,
    fatG,
    saltG,
    source,
    confidence,
  );
}
