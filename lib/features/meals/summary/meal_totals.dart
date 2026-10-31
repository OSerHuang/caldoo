/// Summed intake totals over a set of [MealItem]s.
///
/// One value type powers both halves of the per-meal summary card (task 22):
/// * the card's **本餐合计** is [MealTotals.fromItems] over that meal's items;
/// * the **今日累计** line is [MealTotals.fromMeals] over the meals the
///   repository `watch` stream reports for the local day window.
///
/// Canonical units follow `lib/core/units/nutrition_units.dart`: energy in
/// **whole kcal**, macros g, sodium **mg**. Salt is display-only and derived via [saltG]
/// (`1 g salt = 400 mg Na`), exactly like [DayRollup].
///
/// Pure Dart: no Flutter and no repository import, so the arithmetic is
/// unit-testable on its own.
library;

import 'package:caldoo/core/time/date_windows.dart' show MealWithItems;
import 'package:caldoo/core/units/nutrition_units.dart';
import 'package:caldoo/domain/models/models.dart';

/// A summed set of meal-item nutrients.
class MealTotals {
  /// Creates totals; every field defaults to zero so an empty set is valid.
  const MealTotals({
    this.kcal = 0,
    this.carbG = 0,
    this.proteinG = 0,
    this.fatG = 0,
    this.sodiumMg = 0,
  });

  /// Sums [items] in iteration order.
  ///
  /// [MealItem.sodiumMg] is the canonical milligram value derived from the
  /// item's display salt grams, so the day total is summed in the same unit as
  /// [DayRollup].
  factory MealTotals.fromItems(Iterable<MealItem> items) {
    var kcal = 0;
    var carbG = 0.0;
    var proteinG = 0.0;
    var fatG = 0.0;
    var sodiumMg = 0.0;
    for (final MealItem item in items) {
      kcal += item.kcal;
      carbG += item.carbG;
      proteinG += item.proteinG;
      fatG += item.fatG;
      sodiumMg += item.sodiumMg;
    }
    return MealTotals(
      kcal: kcal,
      carbG: carbG,
      proteinG: proteinG,
      fatG: fatG,
      sodiumMg: sodiumMg,
    );
  }

  /// Sums every item of every meal in [meals] (the day running total input).
  factory MealTotals.fromMeals(Iterable<MealWithItems> meals) {
    final List<MealItem> items = <MealItem>[
      for (final MealWithItems group in meals) ...group.items,
    ];
    return MealTotals.fromItems(items);
  }

  /// The additive identity; an empty item set yields precisely this.
  static const MealTotals zero = MealTotals();

  /// Energy in **whole kcal** (integer-only).
  final int kcal;

  /// Carbohydrate in grams.
  final double carbG;

  /// Protein in grams.
  final double proteinG;

  /// Fat in grams.
  final double fatG;

  /// Sodium in mg (canonical).
  final double sodiumMg;

  /// Display-only salt equivalent of [sodiumMg] in grams.
  double get saltG => sodiumMgToSaltG(sodiumMg);

  /// Field-wise sum, used to fold meal totals into a running day total.
  MealTotals operator +(MealTotals other) => MealTotals(
    kcal: kcal + other.kcal,
    carbG: carbG + other.carbG,
    proteinG: proteinG + other.proteinG,
    fatG: fatG + other.fatG,
    sodiumMg: sodiumMg + other.sodiumMg,
  );

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is MealTotals &&
            other.kcal == kcal &&
            other.carbG == carbG &&
            other.proteinG == proteinG &&
            other.fatG == fatG &&
            other.sodiumMg == sodiumMg;
  }

  @override
  int get hashCode => Object.hash(kcal, carbG, proteinG, fatG, sodiumMg);

  @override
  String toString() =>
      'MealTotals(kcal: $kcal, carbG: $carbG, proteinG: $proteinG, '
      'fatG: $fatG, sodiumMg: $sodiumMg)';
}
