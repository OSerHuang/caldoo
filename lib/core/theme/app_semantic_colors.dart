/// Semantic colours that a seeded [ColorScheme] cannot express.
///
/// A [ThemeExtension] because energy balance (缺口/盈余/平衡), the four
/// nutrients (碳水/蛋白/脂肪/盐) and the chart accents each carry meaning
/// that must stay stable across the app while still adapting to light and
/// dark brightness.
library;

import 'package:flutter/material.dart';

/// The semantic palette for one brightness.
@immutable
class AppSemantics extends ThemeExtension<AppSemantics> {
  /// Creates the palette for one brightness.
  const AppSemantics({
    required this.deficit,
    required this.surplus,
    required this.balanced,
    required this.carb,
    required this.protein,
    required this.fat,
    required this.salt,
    required this.exercise,
    required this.surplusHeat,
    required this.chartTarget,
  });

  /// 缺口 (intake under budget) — the "good" green.
  final Color deficit;

  /// 盈余 (intake over budget) — warning red.
  final Color surplus;

  /// Exactly on budget — neutral grey.
  final Color balanced;

  /// 碳水 — amber.
  final Color carb;

  /// 蛋白 — blue.
  final Color protein;

  /// 脂肪 — violet.
  final Color fat;

  /// 盐 — rose.
  final Color salt;

  /// 运动消耗 — teal.
  final Color exercise;

  /// The ring-gradient tip for a 盈余 day: the warning red flowing into heat
  /// amber (paired with [surplus] by the daily summary).
  final Color surplusHeat;

  /// Weekly-chart budget line — the warning red, by convention.
  final Color chartTarget;

  /// The light-brightness palette.
  static const AppSemantics light = AppSemantics(
    deficit: Color(0xFF15803D),
    surplus: Color(0xFFDC2626),
    balanced: Color(0xFF6B7280),
    carb: Color(0xFFD97706),
    protein: Color(0xFF2563EB),
    fat: Color(0xFF7C3AED),
    salt: Color(0xFFDB2777),
    exercise: Color(0xFF0F766E),
    surplusHeat: Color(0xFFF97316),
    chartTarget: Color(0xFFDC2626),
  );

  /// The dark-brightness palette.
  static const AppSemantics dark = AppSemantics(
    deficit: Color(0xFF4ADE80),
    surplus: Color(0xFFF87171),
    balanced: Color(0xFF9CA3AF),
    carb: Color(0xFFFBBF24),
    protein: Color(0xFF60A5FA),
    fat: Color(0xFFA78BFA),
    salt: Color(0xFFF472B6),
    exercise: Color(0xFF2DD4BF),
    surplusHeat: Color(0xFFFBBF24),
    chartTarget: Color(0xFFF87171),
  );

  /// Reads the palette from [context], falling back to the light values
  /// when the host `MaterialApp` does not install the extension (widget
  /// tests pump their own `MaterialApp` with a bare theme).
  static AppSemantics of(BuildContext context) =>
      Theme.of(context).extension<AppSemantics>() ?? light;

  @override
  AppSemantics copyWith({
    Color? deficit,
    Color? surplus,
    Color? balanced,
    Color? carb,
    Color? protein,
    Color? fat,
    Color? salt,
    Color? exercise,
    Color? surplusHeat,
    Color? chartTarget,
  }) => AppSemantics(
    deficit: deficit ?? this.deficit,
    surplus: surplus ?? this.surplus,
    balanced: balanced ?? this.balanced,
    carb: carb ?? this.carb,
    protein: protein ?? this.protein,
    fat: fat ?? this.fat,
    salt: salt ?? this.salt,
    exercise: exercise ?? this.exercise,
    surplusHeat: surplusHeat ?? this.surplusHeat,
    chartTarget: chartTarget ?? this.chartTarget,
  );

  @override
  AppSemantics lerp(AppSemantics? other, double t) {
    if (other == null) {
      return this;
    }
    return AppSemantics(
      deficit: Color.lerp(deficit, other.deficit, t)!,
      surplus: Color.lerp(surplus, other.surplus, t)!,
      balanced: Color.lerp(balanced, other.balanced, t)!,
      carb: Color.lerp(carb, other.carb, t)!,
      protein: Color.lerp(protein, other.protein, t)!,
      fat: Color.lerp(fat, other.fat, t)!,
      salt: Color.lerp(salt, other.salt, t)!,
      exercise: Color.lerp(exercise, other.exercise, t)!,
      surplusHeat: Color.lerp(surplusHeat, other.surplusHeat, t)!,
      chartTarget: Color.lerp(chartTarget, other.chartTarget, t)!,
    );
  }
}
