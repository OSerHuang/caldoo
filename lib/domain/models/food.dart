import 'package:json_annotation/json_annotation.dart';

import '../../core/units/nutrition_units.dart';
import 'food_serving.dart';

part 'food.g.dart';

/// Where a [Food]'s nutrient values came from.
enum FoodSource {
  /// Parsed from an official 营养成分表 (GB 28050) label — authoritative.
  label,

  /// Estimated by the AI model.
  ai,

  /// Entered by hand.
  manual,
}

/// Whether a saved food is still offered when matching meals.
///
/// Archiving never deletes anything: meal history and meal items that reference
/// the food keep working, but the food is skipped by the label-link index and
/// the deterministic suggestions, so it cannot be offered again by accident.
enum FoodStatus {
  /// Normal: searched, listed, matched and suggested.
  active,

  /// Hidden from matching (still listed in the catalogue for inspection).
  archived,
}

/// The per-100 basis the nutrient values of a [Food] are stored on.
///
/// GB 28050 labels declare solids per 100 g and drinks per 100 mL; the numbers
/// are stored unchanged and this enum keeps the meaning explicit instead of
/// silently pretending every product is a solid.
enum MeasureBasis {
  /// Nutrients are per 100 g (solids).
  per100g,

  /// Nutrients are per 100 mL (drinks).
  per100ml,
}

/// A saved food with **per-100 g** nutrient values.
///
/// Canonical units (see `lib/core/units/nutrition_units.dart`): energy in
/// **whole kcal (int)**, macros in **g**, sodium in **mg**. Salt is never
/// stored here — [saltG] is derived for display only.
///
/// A `null` nutrient means the source left that field blank (a GB 28050 label
/// may omit a value); consumers must fall back per field instead of treating
/// it as zero.
///
/// The selection surface is structured: [name], [brand], [aliases] and (for
/// grams) [servings] are what the label-link call renders into its index.
/// [notes] stays free text for remarks; legacy rows still carry aliases and
/// servings in it, which `parseFoodAliases` / `parseFoodServings` read during
/// the transition.
@JsonSerializable(explicitToJson: true, checked: true)
class Food {
  const Food({
    required this.id,
    required this.name,
    this.brand,
    this.barcode,
    this.aliases = const <String>[],
    this.servings = const <FoodServing>[],
    this.status = FoodStatus.active,
    this.basis = MeasureBasis.per100g,
    this.notes,
    required this.source,
    this.kcal,
    this.carbG,
    this.proteinG,
    this.fatG,
    this.sugarG,
    this.saturatedFatG,
    this.sodiumMg,
  });

  factory Food.fromJson(Map<String, dynamic> json) {
    // Old backups (and rows captured before the structured supplement existed)
    // simply lack the new keys: default them here so importing an older file
    // never fails and never invents an archive state.
    return _$FoodFromJson(<String, dynamic>{
      if (!json.containsKey('aliases')) 'aliases': const <String>[],
      if (!json.containsKey('servings')) 'servings': const <FoodServing>[],
      if (!json.containsKey('status')) 'status': FoodStatus.active.name,
      if (!json.containsKey('basis')) 'basis': MeasureBasis.per100g.name,
      ...json,
    });
  }

  final String id;
  final String name;
  final String? brand;

  /// Optional barcode. The column exists for phase 2; there is no scanner UI.
  final String? barcode;

  /// The user's habitual names for this food (`泡面`, `小饼干`), used by the
  /// label-link index and by search. Always trimmed, de-duplicated and
  /// non-blank (the writers normalise; readers still tolerate anything).
  final List<String> aliases;

  /// Structured serving / package sizes, e.g. `一袋 120 g`, at most three.
  final List<FoodServing> servings;

  /// Whether the food is still offered for matching.
  final FoodStatus status;

  /// The per-100 basis of the nutrient values ([MeasureBasis.per100g] or
  /// [MeasureBasis.per100ml]).
  final MeasureBasis basis;

  /// **Legacy only.** The old free-text 补充说明 (aliases/servings/remarks all
  /// in one blob). Since schema v9 the app never writes it: the v9 data
  /// migration and backup import fold the prose into [aliases]/[servings] and
  /// drop the text. The field stays so older backups still decode.
  final String? notes;

  final FoodSource source;

  /// Per-100 g energy in **whole kcal** (canonical energy unit — never kJ).
  ///
  /// Integer-only: a fractional value in an old backup/label is rounded once
  /// at this boundary by [nullableKcalFromJson].
  @JsonKey(fromJson: nullableKcalFromJson)
  final int? kcal;

  /// Per-100 g carbohydrate in grams.
  final double? carbG;

  /// Per-100 g protein in grams.
  final double? proteinG;

  /// Per-100 g fat in grams.
  final double? fatG;

  /// Per-100 g sugar in grams (GB 28050 optional declaration).
  final double? sugarG;

  /// Per-100 g saturated fat in grams (GB 28050 optional declaration).
  final double? saturatedFatG;

  /// Per-100 g sodium in mg — the canonical salt/sodium value on [Food].
  final double? sodiumMg;

  /// Display-only salt equivalent of [sodiumMg] (1 g salt = 400 mg Na).
  ///
  /// Returns `null` when [sodiumMg] is blank.
  double? get saltG {
    final sodium = sodiumMg;
    return sodium == null ? null : sodiumMgToSaltG(sodium);
  }

  /// `true` when this food may be offered by matching (index / suggestions).
  bool get isMatchable => status == FoodStatus.active;

  Map<String, dynamic> toJson() => _$FoodToJson(this);

  Food copyWith({
    String? id,
    String? name,
    String? brand,
    String? barcode,
    List<String>? aliases,
    List<FoodServing>? servings,
    FoodStatus? status,
    MeasureBasis? basis,
    String? notes,
    FoodSource? source,
    int? kcal,
    double? carbG,
    double? proteinG,
    double? fatG,
    double? sugarG,
    double? saturatedFatG,
    double? sodiumMg,
  }) {
    return Food(
      id: id ?? this.id,
      name: name ?? this.name,
      brand: brand ?? this.brand,
      barcode: barcode ?? this.barcode,
      aliases: aliases ?? this.aliases,
      servings: servings ?? this.servings,
      status: status ?? this.status,
      basis: basis ?? this.basis,
      notes: notes ?? this.notes,
      source: source ?? this.source,
      kcal: kcal ?? this.kcal,
      carbG: carbG ?? this.carbG,
      proteinG: proteinG ?? this.proteinG,
      fatG: fatG ?? this.fatG,
      sugarG: sugarG ?? this.sugarG,
      saturatedFatG: saturatedFatG ?? this.saturatedFatG,
      sodiumMg: sodiumMg ?? this.sodiumMg,
    );
  }

  /// Returns a copy with the human-facing identity replaced exactly.
  ///
  /// Unlike [copyWith], a `null` [brand] really clears it. Nutrients and the
  /// structured supplement are untouched: renaming a food never rewrites the
  /// values it was captured with, and meal history keeps its own name/values
  /// snapshots.
  Food withIdentity({required String name, required String? brand}) {
    return Food(
      id: id,
      name: name,
      brand: brand,
      barcode: barcode,
      aliases: aliases,
      servings: servings,
      status: status,
      basis: basis,
      notes: notes,
      source: source,
      kcal: kcal,
      carbG: carbG,
      proteinG: proteinG,
      fatG: fatG,
      sugarG: sugarG,
      saturatedFatG: saturatedFatG,
      sodiumMg: sodiumMg,
    );
  }

  /// Returns a copy with [notes] replaced exactly; a `null` really clears it.
  ///
  /// [copyWith] treats a `null` argument as "keep", which is what a partial
  /// patch wants — but the saved-food supplement editor must be able to delete
  /// the note, and the storage contract requires a cleared note to be SQL
  /// `NULL` rather than an empty string.
  Food withNotes(String? notes) => withSupplement(notes: notes);

  /// Returns a copy with the **user-supplied supplement** replaced exactly.
  ///
  /// Every argument is authoritative (unlike [copyWith], a `null` [notes] and
  /// empty lists really clear the stored values), which is what the supplement
  /// editor needs: deleting the last alias must delete it from the database.
  Food withSupplement({
    required String? notes,
    List<String>? aliases,
    List<FoodServing>? servings,
    FoodStatus? status,
    MeasureBasis? basis,
  }) {
    return Food(
      id: id,
      name: name,
      brand: brand,
      barcode: barcode,
      aliases: aliases ?? this.aliases,
      servings: servings ?? this.servings,
      status: status ?? this.status,
      basis: basis ?? this.basis,
      notes: notes,
      source: source,
      kcal: kcal,
      carbG: carbG,
      proteinG: proteinG,
      fatG: fatG,
      sugarG: sugarG,
      saturatedFatG: saturatedFatG,
      sodiumMg: sodiumMg,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is Food &&
            other.id == id &&
            other.name == name &&
            other.brand == brand &&
            other.barcode == barcode &&
            _listEquals(other.aliases, aliases) &&
            _listEquals(other.servings, servings) &&
            other.status == status &&
            other.basis == basis &&
            other.notes == notes &&
            other.source == source &&
            other.kcal == kcal &&
            other.carbG == carbG &&
            other.proteinG == proteinG &&
            other.fatG == fatG &&
            other.sugarG == sugarG &&
            other.saturatedFatG == saturatedFatG &&
            other.sodiumMg == sodiumMg;
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    brand,
    barcode,
    Object.hashAll(aliases),
    Object.hashAll(servings),
    status,
    basis,
    notes,
    source,
    kcal,
    carbG,
    proteinG,
    fatG,
    sugarG,
    saturatedFatG,
    sodiumMg,
  );
}

/// Element-wise list equality (models are pure Dart, so no `flutter/foundation`).
bool _listEquals<T>(List<T> a, List<T> b) {
  if (identical(a, b)) {
    return true;
  }
  if (a.length != b.length) {
    return false;
  }
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) {
      return false;
    }
  }
  return true;
}
