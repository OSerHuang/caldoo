/// Riverpod wiring for the display-unit preferences.
///
/// The graph mirrors the AI settings: a repository over the Drift
/// `app_settings` table, an async controller that loads the saved pair, and the
/// app root installs the resolved [DisplayUnits] as a [DisplayScope] so every
/// read-only surface re-renders when the user switches unit/basis.
///
/// Switching a preference persists immediately — there is no "save" step for
/// the display section, unlike the model settings form.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:caldoo/core/units/display_units.dart';
import 'package:caldoo/features/settings/display_settings.dart';
import 'package:caldoo/features/settings/settings_providers.dart'
    show appDatabaseProvider;

/// The display preferences repository over the app database's settings DAO.
final displaySettingsRepositoryProvider = Provider<DisplaySettingsRepository>(
  (ref) =>
      DisplaySettingsRepository(ref.watch(appDatabaseProvider).appSettingsDao),
);

/// Loads and mutates the display preferences.
class DisplaySettingsController extends AsyncNotifier<DisplaySettings> {
  @override
  Future<DisplaySettings> build() =>
      ref.watch(displaySettingsRepositoryProvider).load();

  /// Selects the energy display unit and persists it immediately.
  Future<void> setEnergy(EnergyDisplay energy) async {
    final DisplaySettings current = state.value ?? DisplaySettings.defaults;
    if (current.energy == energy) {
      return;
    }
    final DisplaySettings next = current.copyWith(energy: energy);
    state = AsyncData(next);
    await ref.read(displaySettingsRepositoryProvider).save(next);
  }

  /// Selects the salt / sodium display basis and persists it immediately.
  Future<void> setSalt(SaltDisplay salt) async {
    final DisplaySettings current = state.value ?? DisplaySettings.defaults;
    if (current.salt == salt) {
      return;
    }
    final DisplaySettings next = current.copyWith(salt: salt);
    state = AsyncData(next);
    await ref.read(displaySettingsRepositoryProvider).save(next);
  }
}

/// The current display preferences (defaults while loading).
final displaySettingsProvider =
    AsyncNotifierProvider<DisplaySettingsController, DisplaySettings>(
      DisplaySettingsController.new,
    );
