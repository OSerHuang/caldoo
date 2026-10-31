/// Display-only unit preferences: kcal vs kJ for energy, salt vs sodium for
/// the salt/sodium readouts.
///
/// ## Storage stays canonical
///
/// The domain never changes: energy is stored as **whole kcal** and sodium as
/// **mg** (see `nutrition_units.dart`). This layer only converts the stored
/// value into the number the user asked to *see*; nothing is re-persisted and
/// no recorded value changes when the preference is switched.
///
/// ## Display vs input
///
/// The preference applies to read-only surfaces — dashboards, meal summaries,
/// food details, chart axes and tooltips. Data-entry fields still keep their
/// own canonical storage units (whole kcal / sodium mg) and the printed source
/// material still leads: a photo-confirmed 营养成分表 is entered in **kJ / mg**
/// so its values line up with the picture, a manually edited meal item in
/// **kcal / g**, the exercise burn and the BMR in **kcal**. Since the label
/// confirm form grew per-field unit switches, the preference also seeds the
/// **default input units** of the manual entry (no photo): the 能量 row starts
/// in 大卡 or kJ and the 钠 row in 盐 or mg, and both rows accept either unit
/// via the in-field dropdown. Switching the preference never re-persists a
/// recorded value.
///
/// ## Scope
///
/// [DisplayScope] carries the resolved [DisplayUnits] down the widget tree.
/// Widgets read it with `DisplayUnits.of(context)`; when no scope is installed
/// (unit tests pumping a bare screen) the [DisplayUnits.defaults] — kcal + salt,
/// the app's historical behaviour — are used, so existing tests and goldens are
/// unaffected.
library;

import 'package:flutter/widgets.dart';

import 'package:caldoo/core/units/nutrition_units.dart';
import 'package:caldoo/l10n/app_format.dart';
import 'package:caldoo/l10n/app_strings.dart';

/// The energy unit used for read-only energy values.
enum EnergyDisplay {
  /// Kilocalories — the domain's own unit and the app's default.
  kcal,

  /// Kilojoules — converted for display only (`stored kcal × 4.184`).
  kj,
}

/// How the salt data is shown: as salt grams or as sodium milligrams.
enum SaltDisplay {
  /// Salt in grams (the historical display; derived from stored sodium).
  salt,

  /// Sodium in milligrams — the value the domain actually stores.
  sodium,
}

/// The resolved display preferences, with the formatting helpers every
/// display surface uses so the conversion rules live in exactly one place.
@immutable
class DisplayUnits {
  /// Creates a preference pair; both default to the historical display.
  const DisplayUnits({
    this.energy = EnergyDisplay.kcal,
    this.salt = SaltDisplay.salt,
  });

  /// kcal + salt: what the app showed before the preference existed.
  static const DisplayUnits defaults = DisplayUnits();

  /// The active preferences for [context] (shorthand for [DisplayScope.of];
  /// returns [defaults] when no scope is installed).
  static DisplayUnits of(BuildContext context) => DisplayScope.of(context);

  /// The selected energy unit.
  final EnergyDisplay energy;

  /// The selected salt / sodium basis.
  final SaltDisplay salt;

  /// Whether energy is displayed in kilojoules.
  bool get isKilojoules => energy == EnergyDisplay.kj;

  /// Whether salt/sodium is displayed as sodium.
  bool get showsSodium => salt == SaltDisplay.sodium;

  /// The displayed (whole) number for a stored [kcal] amount.
  ///
  /// kJ is `kcal × 4.184` rounded to a whole number by the same rounding rule
  /// as the rest of the app; kcal passes through unchanged. Only display is
  /// affected — the stored value is never written back.
  int energyValue(int kcal) => isKilojoules ? (kcal * 4.184).round() : kcal;

  /// The formatted display number, without the unit: `1715` / `7176`.
  String energyValueText(int kcal) => AppFormat.integer(energyValue(kcal));

  /// The unit label: `kcal` or `kJ`.
  String get energyUnit =>
      isKilojoules ? S.instance.unitKJ : S.instance.unitKcal;

  /// `1715 kcal` / `7176 kJ`.
  String energyText(int kcal) => '${energyValueText(kcal)} $energyUnit';

  /// The salt-data row label: `盐` or `钠`.
  String get saltLabel =>
      showsSodium ? S.instance.labelSodium : S.instance.labelSalt;

  /// The salt-data unit: `g` or `mg`.
  String get saltUnit => showsSodium ? S.instance.unitMg : S.instance.unitG;

  /// The displayed number for a salt-gram amount (converts to mg for sodium).
  num saltValueFromSaltG(double saltG) =>
      showsSodium ? saltGToSodiumMg(saltG) : saltG;

  /// The displayed (formatted) number for a salt-gram amount.
  String saltValueTextFromSaltG(double saltG) =>
      AppFormat.number(saltValueFromSaltG(saltG));

  /// The displayed (formatted) number for a stored sodium-mg amount.
  String saltValueTextFromSodiumMg(double sodiumMg) =>
      AppFormat.number(showsSodium ? sodiumMg : sodiumMgToSaltG(sodiumMg));

  /// The displayed daily target number: `5` (salt g) or `2000` (sodium mg).
  num get saltTargetValue =>
      showsSodium ? saltGToSodiumMg(dailySaltTargetG) : dailySaltTargetG;

  /// The displayed daily target, formatted: `5` / `2000`.
  String get saltTargetText => AppFormat.number(saltTargetValue);

  /// The `current / target` progress value shown beside the salt tile:
  /// `3.5 / 5` (salt) or `1400 / 2000` (sodium).
  String saltProgressFromSaltG(double saltG) =>
      S.instance.saltProgress(saltValueTextFromSaltG(saltG), saltTargetText);

  @override
  bool operator ==(Object other) =>
      other is DisplayUnits && other.energy == energy && other.salt == salt;

  @override
  int get hashCode => Object.hash(energy, salt);

  @override
  String toString() => 'DisplayUnits(energy: $energy, salt: $salt)';
}

/// Carries the resolved [DisplayUnits] down the widget tree.
///
/// Installed once at the app root from the persisted preference; every display
/// surface reads it with [DisplayUnits.of]. Absent (bare-screen widget tests,
/// isolated golden fixtures) the app defaults apply.
class DisplayScope extends InheritedWidget {
  /// Creates the scope over [child].
  const DisplayScope({required this.units, required super.child, super.key});

  /// The active preferences.
  final DisplayUnits units;

  /// The active preferences for [context], or [DisplayUnits.defaults] when no
  /// [DisplayScope] is installed.
  static DisplayUnits of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<DisplayScope>()?.units ??
      DisplayUnits.defaults;

  @override
  bool updateShouldNotify(DisplayScope oldWidget) => oldWidget.units != units;
}
