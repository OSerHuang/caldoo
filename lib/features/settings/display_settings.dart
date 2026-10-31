/// Persistence for the display-unit preferences (kcal/kJ, salt/sodium).
///
/// These are **non-secret** preferences, so they live in the Drift
/// `app_settings` key/value table next to the AI `baseUrl` / `model` — never in
/// secure storage. They are display-only: loading or switching them never
/// rewrites a meal, food, exercise or profile value, because the domain stays
/// canonical (whole kcal + sodium mg).
library;

import 'package:flutter/foundation.dart';

import 'package:caldoo/core/units/display_units.dart';
import 'package:caldoo/data/db/daos/app_settings_dao.dart';

/// The persisted display preference pair.
@immutable
class DisplaySettings {
  /// Creates the preference pair; both default to the historical display.
  const DisplaySettings({
    this.energy = EnergyDisplay.kcal,
    this.salt = SaltDisplay.salt,
  });

  /// kcal + salt.
  static const DisplaySettings defaults = DisplaySettings();

  /// The selected energy unit.
  final EnergyDisplay energy;

  /// The selected salt / sodium basis.
  final SaltDisplay salt;

  /// The resolved formatting helper for this pair.
  DisplayUnits get units => DisplayUnits(energy: energy, salt: salt);

  /// A copy with the given fields replaced.
  DisplaySettings copyWith({EnergyDisplay? energy, SaltDisplay? salt}) =>
      DisplaySettings(energy: energy ?? this.energy, salt: salt ?? this.salt);

  @override
  bool operator ==(Object other) =>
      other is DisplaySettings && other.energy == energy && other.salt == salt;

  @override
  int get hashCode => Object.hash(energy, salt);
}

/// Reads/writes [DisplaySettings] through the `app_settings` key/value table.
class DisplaySettingsRepository {
  /// Creates the repository over [dao].
  DisplaySettingsRepository(this._dao);

  /// `app_settings` key for the energy-unit preference (`kcal` / `kj`).
  static const String energyPrefKey = 'display_energy_unit';

  /// `app_settings` key for the salt/sodium preference (`salt` / `sodium`).
  static const String saltPrefKey = 'display_salt_basis';

  final AppSettingsDao _dao;

  /// Loads the persisted preferences, falling back to the defaults for absent
  /// or unrecognised values (a downgrade or a hand-edited DB can never break
  /// the screen).
  Future<DisplaySettings> load() async {
    final String? energy = await _dao.getValue(energyPrefKey);
    final String? salt = await _dao.getValue(saltPrefKey);
    return DisplaySettings(energy: _energyFrom(energy), salt: _saltFrom(salt));
  }

  /// Persists both preferences.
  Future<void> save(DisplaySettings settings) async {
    await _dao.setValue(energyPrefKey, _energyTo(settings.energy));
    await _dao.setValue(saltPrefKey, _saltTo(settings.salt));
  }

  static EnergyDisplay _energyFrom(String? raw) =>
      raw == 'kj' ? EnergyDisplay.kj : EnergyDisplay.kcal;

  static SaltDisplay _saltFrom(String? raw) =>
      raw == 'sodium' ? SaltDisplay.sodium : SaltDisplay.salt;

  static String _energyTo(EnergyDisplay value) =>
      value == EnergyDisplay.kj ? 'kj' : 'kcal';

  static String _saltTo(SaltDisplay value) =>
      value == SaltDisplay.sodium ? 'sodium' : 'salt';
}
