/// Canonical nutrition-unit contract for 卡嘟.
///
/// **Everything stored or passed across a boundary uses exactly one unit per
/// quantity:**
/// * energy -> **whole kilocalories (integer kcal)** — energy is never stored
///   in kJ, and it is never fractional: kJ is only accepted at an input
///   boundary (a GB 28050 label) and converted with [kJToKcal], which rounds to
///   the nearest whole kcal, before it enters the domain; a typed 大卡 input is
///   converted at the same boundary with [kcalInputToKJ];
/// * macronutrients (carbohydrate / protein / fat) -> **grams (g)**;
/// * sodium -> **milligrams (mg)** — `Food` stores `sodiumMg` and never salt;
///   salt grams is a display-and-input unit that is derived with
///   [sodiumMgToSaltG] and converted back with [saltGToSodiumMg] at the
///   boundary (the confirm form's 盐 input and the read-only salt readouts).
///
/// ## Energy is integer-only
///
/// Every calorie number in the app — a food's per-100 g value, a meal item, a
/// logged exercise burn, a BMR, a budget, a daily/weekly total and a deficit —
/// is an `int` kcal. Any computation that produces a fractional number of
/// calories funnels through [roundKcal] (round half away from zero) at the one
/// point where the value crosses into the domain, so no fraction can leak into
/// storage, arithmetic or the UI.
///
/// Conversions (fixed by definition, never hard-coded at call sites):
/// * `1 kcal = 4.184 kJ` (thermochemical calorie);
/// * `1 g salt = 400 mg sodium` (WHO: 5 g salt/day == 2000 mg Na/day);
/// * Atwater factors: carbohydrate 4, protein 4, fat 9 kcal/g.
///
/// Every helper rejects malformed input (negative, NaN, infinite) with an
/// [ArgumentError] so a malformed label/AI payload can never silently poison
/// a day total.
library;

/// Kilojoules per kilocalorie: `1 kcal = 4.184 kJ` (thermochemical calorie).
/// The single definition behind [kJToKcal], [kcalToKJ] and [kcalInputToKJ] —
/// never hard-code the factor at a call site.
const double kJPerKcal = 4.184;

/// Kilocalories per gram of carbohydrate (Atwater factor).
const int kcalPerGramCarb = 4;

/// Kilocalories per gram of protein (Atwater factor).
const int kcalPerGramProtein = 4;

/// Kilocalories per gram of fat (Atwater factor).
const int kcalPerGramFat = 9;

/// Fixed adult daily salt target in grams (WHO recommendation).
///
/// The target is deliberately not configurable and has no child mode
/// (see the plan's "Must NOT have" guardrails).
const double dailySaltTargetG = 5.0;

/// Rounds an energy expression to the app's canonical whole kcal.
///
/// This is the single rounding rule for energy (`x.5` rounds away from zero,
/// Dart's [num.round]), so a fractional label conversion, an AI estimate, a
/// per-100 g scale or a BMR formula all land on whole kcal the same way.
int roundKcal(double value) {
  if (!value.isFinite) {
    throw ArgumentError.value(
      value,
      'value',
      'must be a finite number (got NaN or infinity)',
    );
  }
  if (value < 0) {
    throw ArgumentError.value(value, 'value', 'must not be negative');
  }
  return value.round();
}

/// Converts energy from kilojoules to whole kilocalories.
///
/// `kJToKcal(418.4) == 100` (1 kcal = [kJPerKcal] kJ); a non-integral result is
/// rounded to the nearest whole kcal by [roundKcal].
int kJToKcal(double kiloJoules) {
  _checkNonNegativeFinite(kiloJoules, 'kiloJoules');
  return roundKcal(kiloJoules / kJPerKcal);
}

/// Converts whole kilocalories to kilojoules.
///
/// Used only for display or when echoing a GB 28050 label back in kJ.
double kcalToKJ(int kilocalories) {
  _checkNonNegativeInt(kilocalories, 'kilocalories');
  return kilocalories * kJPerKcal;
}

/// Converts a typed kilocalorie input — possibly fractional — to kilojoules.
///
/// The input boundary for a manually typed 大卡 value: the user may type
/// `358.5`, so unlike [kcalToKJ] this takes a double and does **not** round;
/// the whole-kcal rounding still happens exactly once at the domain boundary
/// when the stored kJ is read back with [kJToKcal].
double kcalInputToKJ(double kilocalories) {
  _checkNonNegativeFinite(kilocalories, 'kilocalories');
  return kilocalories * kJPerKcal;
}

/// Converts sodium in milligrams to the display-only salt gram equivalent.
///
/// `sodiumMgToSaltG(2000) == 5.0` (1 g salt = 400 mg sodium).
double sodiumMgToSaltG(double sodiumMg) {
  _checkNonNegativeFinite(sodiumMg, 'sodiumMg');
  return sodiumMg / 400;
}

/// Converts a display-only salt gram value to canonical sodium milligrams.
///
/// `saltGToSodiumMg(5) == 2000.0` (1 g salt = 400 mg sodium).
double saltGToSodiumMg(double saltG) {
  _checkNonNegativeFinite(saltG, 'saltG');
  return saltG * 400;
}

/// Energy contributed by the three macronutrients using the Atwater factors
/// (carbohydrate 4, protein 4, fat 9 kcal/g), rounded to whole kcal.
///
/// `macroKcal(carbG: 10, proteinG: 10, fatG: 10) == 170`.
int macroKcal({
  required double carbG,
  required double proteinG,
  required double fatG,
}) {
  _checkNonNegativeFinite(carbG, 'carbG');
  _checkNonNegativeFinite(proteinG, 'proteinG');
  _checkNonNegativeFinite(fatG, 'fatG');
  return roundKcal(
    carbG * kcalPerGramCarb +
        proteinG * kcalPerGramProtein +
        fatG * kcalPerGramFat,
  );
}

/// Reads an energy value from an untrusted payload (JSON/backup/AI reply) as
/// whole kcal.
///
/// Legacy payloads may carry a fractional number of calories (older backups,
/// pre-integer rows, a model that ignored the "whole kcal" instruction); it is
/// rounded with [roundKcal] instead of being rejected, so old data keeps
/// importing. A non-numeric, negative, NaN or infinite value is malformed and
/// throws a [FormatException].
int kcalFromJson(Object? value) {
  if (value is! num) {
    throw FormatException('kcal must be a number, got $value');
  }
  final double asDouble = value.toDouble();
  if (!asDouble.isFinite || asDouble < 0) {
    throw const FormatException('kcal must be a non-negative finite number');
  }
  return roundKcal(asDouble);
}

/// Nullable flavour of [kcalFromJson]: `null`/absent stays `null` (a blank
/// nutrient never becomes `0`).
int? nullableKcalFromJson(Object? value) =>
    value == null ? null : kcalFromJson(value);

/// Rejects negative, NaN and infinite values with an [ArgumentError].
void _checkNonNegativeFinite(double value, String name) {
  if (!value.isFinite) {
    throw ArgumentError.value(
      value,
      name,
      'must be a finite number (got NaN or infinity)',
    );
  }
  if (value < 0) {
    throw ArgumentError.value(value, name, 'must not be negative');
  }
}

/// Rejects negative values with an [ArgumentError].
void _checkNonNegativeInt(int value, String name) {
  if (value < 0) {
    throw ArgumentError.value(value, name, 'must not be negative');
  }
}
