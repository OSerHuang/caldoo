/// The editable, blank-safe form model behind the label confirm screen.
///
/// The AI schema ([LabelParseItem]) requires all seven GB 28050-2025 mandatory
/// declarations, but a label can genuinely lack a value. [LabelDraft] therefore
/// models **every** nutrient as nullable, so a missing field stays blank
/// through the form and into the saved [Food] instead of being fabricated as
/// `0` (the plan's explicit "no fake zeros" rule).
///
/// A draft also carries the human-facing identity fields:
/// * [name] — the food name; pre-filled from the model's packaging reading but
///   always editable, and required before saving (never invented);
/// * [brand] — pre-filled from the model when visible;
/// * [aliases] — the model's other names for the food (the source-language
///   original of a translated name, variant scripts, common aliases), merged
///   with the note-parsed aliases when the [Food] is built;
/// * [notes] — the user's supplement (package size, aliases, remarks), typed on
///   the pick step and/or edited per label;
/// * [included] — whether this label is part of the batch save (the photo may
///   contain a label the user does not want to keep).
///
/// Energy crosses the boundary here exactly once: the GB 28050 grid is printed
/// in kilojoules, [LabelDraft.energyKj] keeps that printed value, and
/// [energyKcal] is the canonical per-100 g value (via [kJToKcal]) that reaches
/// the domain. The confirm form may *type* the energy in 大卡 or the sodium in
/// 盐 g — the card converts both into these canonical fields at the input
/// boundary ([kcalInputToKJ] / [saltGToSodiumMg]); the draft itself only ever
/// holds kJ and mg.
library;

import 'package:flutter/foundation.dart';

import 'package:caldoo/ai/schemas/label_parse.dart';
import 'package:caldoo/core/units/nutrition_units.dart';
import 'package:caldoo/l10n/app_strings.dart';

/// One nutrient row the confirm form renders.
///
/// [label] is the Chinese GB 28050 declaration name and [unit] is the printed
/// unit. The order is the order the form lists them in.
enum LabelField {
  /// 能量, printed on the label in kilojoules (the confirm form also types it
  /// in 大卡; the card converts before the draft sees it).
  energy('kJ'),

  /// 蛋白质, grams per 100 g.
  protein('g'),

  /// 脂肪, grams per 100 g.
  fat('g'),

  /// 饱和脂肪, grams per 100 g (shown for confirmation; [Food] has no column).
  saturatedFat('g'),

  /// 碳水化合物, grams per 100 g.
  carbohydrate('g'),

  /// 糖, grams per 100 g (shown for confirmation; [Food] has no column).
  sugar('g'),

  /// 钠, milligrams per 100 g — the canonical sodium value on [Food] (the
  /// confirm form also types it as 盐 g; the card converts before the draft
  /// sees it).
  sodium('mg');

  const LabelField(this.unit);

  /// Printed unit for this row (`kJ`, `g`, `mg`).
  final String unit;

  /// Chinese GB 28050-2025 declaration name, from the single string table.
  String get label => switch (this) {
    LabelField.energy => S.instance.labelFieldEnergy,
    LabelField.protein => S.instance.labelFieldProtein,
    LabelField.fat => S.instance.labelFieldFat,
    LabelField.saturatedFat => S.instance.labelFieldSaturatedFat,
    LabelField.carbohydrate => S.instance.labelFieldCarbohydrate,
    LabelField.sugar => S.instance.labelFieldSugar,
    LabelField.sodium => S.instance.labelFieldSodium,
  };
}

/// A mutable-by-copy nutrition label draft; every nutrient is nullable.
///
/// A `null` nutrient means the label did not provide it and it must stay blank
/// (never a fabricated `0`).
@immutable
class LabelDraft {
  const LabelDraft({
    this.name = '',
    this.brand = '',
    this.aliases = const <String>[],
    this.notes = '',
    this.included = true,
    this.energyKj,
    this.proteinG,
    this.fatG,
    this.saturatedFatG,
    this.carbohydrateG,
    this.sugarG,
    this.sodiumMg,
  });

  /// Seeds a full draft from one schema-complete [LabelParseItem] (the AI path).
  ///
  /// Every value the model returned is carried through unchanged; [notes] is
  /// the user's supplement typed on the pick step (empty when none), which is
  /// pre-filled into every parsed label so a one-label photo keeps the text
  /// without retyping. [aliases] comes from the model's `name_aliases` — the
  /// source-language original of a translated name and its other names — with
  /// blanks dropped and duplicates collapsed, keeping the first occurrence.
  factory LabelDraft.fromParse(LabelParseItem parse, {String notes = ''}) {
    return LabelDraft(
      name: parse.foodName?.trim() ?? '',
      brand: parse.brand?.trim() ?? '',
      aliases: _cleanAliases(parse.nameAliases),
      notes: notes,
      energyKj: parse.energyKj,
      proteinG: parse.proteinG,
      fatG: parse.fatG,
      saturatedFatG: parse.saturatedFatG,
      carbohydrateG: parse.carbohydrateG,
      sugarG: parse.sugarG,
      sodiumMg: parse.sodiumMg,
    );
  }

  /// Trims [raw], drops blanks and collapses duplicates (first wins).
  static List<String> _cleanAliases(List<String> raw) {
    final List<String> cleaned = <String>[];
    for (final String alias in raw) {
      final String trimmed = alias.trim();
      if (trimmed.isNotEmpty && !cleaned.contains(trimmed)) {
        cleaned.add(trimmed);
      }
    }
    return cleaned;
  }

  /// The saved food's display name (user-editable; never auto-invented).
  final String name;

  /// The saved food's brand (user-editable; pre-filled when the model read it).
  final String brand;

  /// The model's other names for the food (source-language original, variant
  /// scripts, common aliases). Merged with the note-parsed aliases when the
  /// [Food] is built; empty for manual entry.
  final List<String> aliases;

  /// Free-form user supplement: package size, aliases, remarks.
  final String notes;

  /// Whether this label is included in the batch save.
  ///
  /// The confirm screen shows one card per label; a photo may contain a label
  /// the user does not want to keep, so the card can be excluded instead of
  /// deleted (excluded cards keep their entered values if re-included).
  final bool included;

  /// Energy exactly as printed, in kilojoules (never stored on [Food]).
  final double? energyKj;

  /// Per-100 g protein in grams.
  final double? proteinG;

  /// Per-100 g fat in grams.
  final double? fatG;

  /// Per-100 g saturated fat in grams.
  final double? saturatedFatG;

  /// Per-100 g carbohydrate in grams.
  final double? carbohydrateG;

  /// Per-100 g sugar in grams.
  final double? sugarG;

  /// Per-100 g sodium in milligrams.
  final double? sodiumMg;

  /// Canonical per-100 g energy in **whole kcal**, or `null` when energy is
  /// blank.
  ///
  /// Uses the single canonical conversion ([kJToKcal]), which rounds to the
  /// nearest whole kcal; no kJ ever leaves this class.
  int? get energyKcal {
    final double? kJ = energyKj;
    return kJ == null ? null : kJToKcal(kJ);
  }

  /// The current value of [field], or `null` when blank.
  double? valueOf(LabelField field) => switch (field) {
    LabelField.energy => energyKj,
    LabelField.protein => proteinG,
    LabelField.fat => fatG,
    LabelField.saturatedFat => saturatedFatG,
    LabelField.carbohydrate => carbohydrateG,
    LabelField.sugar => sugarG,
    LabelField.sodium => sodiumMg,
  };

  /// Returns a copy with [field] set to [value] (`null` clears it).
  ///
  /// Every other field is preserved exactly, including an explicit `null`.
  LabelDraft withValue(LabelField field, double? value) {
    return LabelDraft(
      name: name,
      brand: brand,
      aliases: aliases,
      notes: notes,
      included: included,
      energyKj: field == LabelField.energy ? value : energyKj,
      proteinG: field == LabelField.protein ? value : proteinG,
      fatG: field == LabelField.fat ? value : fatG,
      saturatedFatG: field == LabelField.saturatedFat ? value : saturatedFatG,
      carbohydrateG: field == LabelField.carbohydrate ? value : carbohydrateG,
      sugarG: field == LabelField.sugar ? value : sugarG,
      sodiumMg: field == LabelField.sodium ? value : sodiumMg,
    );
  }

  /// Returns a copy with the display [name] replaced.
  LabelDraft withName(String name) => _copy(name: name);

  /// Returns a copy with the [brand] replaced.
  LabelDraft withBrand(String brand) => _copy(brand: brand);

  /// Returns a copy with the [notes] replaced.
  LabelDraft withNotes(String notes) => _copy(notes: notes);

  /// Returns a copy with [included] replaced.
  LabelDraft withIncluded(bool included) => _copy(included: included);

  LabelDraft _copy({
    String? name,
    String? brand,
    String? notes,
    bool? included,
  }) {
    return LabelDraft(
      name: name ?? this.name,
      brand: brand ?? this.brand,
      aliases: aliases,
      notes: notes ?? this.notes,
      included: included ?? this.included,
      energyKj: energyKj,
      proteinG: proteinG,
      fatG: fatG,
      saturatedFatG: saturatedFatG,
      carbohydrateG: carbohydrateG,
      sugarG: sugarG,
      sodiumMg: sodiumMg,
    );
  }

  /// `true` when no nutrient value has been set (identity fields aside).
  bool get isEmpty => LabelField.values.every((f) => valueOf(f) == null);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is LabelDraft &&
            other.name == name &&
            other.brand == brand &&
            listEquals(other.aliases, aliases) &&
            other.notes == notes &&
            other.included == included &&
            other.energyKj == energyKj &&
            other.proteinG == proteinG &&
            other.fatG == fatG &&
            other.saturatedFatG == saturatedFatG &&
            other.carbohydrateG == carbohydrateG &&
            other.sugarG == sugarG &&
            other.sodiumMg == sodiumMg;
  }

  @override
  int get hashCode => Object.hash(
    name,
    brand,
    Object.hashAll(aliases),
    notes,
    included,
    energyKj,
    proteinG,
    fatG,
    saturatedFatG,
    carbohydrateG,
    sugarG,
    sodiumMg,
  );
}
