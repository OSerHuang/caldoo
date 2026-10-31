/// The 数据显示 page: the display-only unit preferences, one level below the
/// 设置 hub.
///
/// The energy unit (大卡 / 千焦) and the salt/sodium basis (盐 / 钠) apply
/// immediately (no save button) and never touch recorded values. Read-only
/// surfaces switch outright; the manual-entry form only adopts them as its
/// default input units (the rows themselves are switchable per field). The
/// BYOK form lives on its own page ([AiSettingsScreen]).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:caldoo/core/units/display_units.dart';
import 'package:caldoo/features/settings/display_settings.dart';
import 'package:caldoo/features/settings/display_settings_providers.dart';
import 'package:caldoo/l10n/app_strings.dart';

/// Key of the energy-unit segmented control.
const Key settingsEnergyUnitKey = Key('settings_energy_unit');

/// Key of the 大卡 (kcal) energy option.
const Key settingsEnergyKcalKey = Key('settings_energy_kcal');

/// Key of the 千焦 (kJ) energy option.
const Key settingsEnergyKjKey = Key('settings_energy_kj');

/// Key of the salt/sodium segmented control.
const Key settingsSaltDisplayKey = Key('settings_salt_display');

/// Key of the 盐 (g) option.
const Key settingsSaltOptionKey = Key('settings_salt_option');

/// Key of the 钠 (mg) option.
const Key settingsSodiumOptionKey = Key('settings_sodium_option');

/// The 数据显示 screen.
class DisplaySettingsScreen extends ConsumerWidget {
  /// Creates the display-settings page.
  const DisplaySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    // Display preferences load independently of the model form; while they
    // load (or on a DB error) the app's defaults are shown, exactly like the
    // root DisplayScope does.
    final DisplaySettings display =
        ref.watch(displaySettingsProvider).value ?? DisplaySettings.defaults;
    return Scaffold(
      appBar: AppBar(title: Text(S.of(context).settingsSectionDisplay)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Text(
            S.of(context).displayEnergyTitle,
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 2),
          Text(
            S.of(context).displayEnergySubtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          SegmentedButton<EnergyDisplay>(
            key: settingsEnergyUnitKey,
            expandedInsets: EdgeInsets.zero,
            showSelectedIcon: false,
            segments: <ButtonSegment<EnergyDisplay>>[
              ButtonSegment<EnergyDisplay>(
                value: EnergyDisplay.kcal,
                label: Text(
                  S.of(context).displayEnergyKcalOption,
                  key: settingsEnergyKcalKey,
                ),
              ),
              ButtonSegment<EnergyDisplay>(
                value: EnergyDisplay.kj,
                label: Text(
                  S.of(context).displayEnergyKjOption,
                  key: settingsEnergyKjKey,
                ),
              ),
            ],
            selected: <EnergyDisplay>{display.energy},
            onSelectionChanged: (Set<EnergyDisplay> selection) => ref
                .read(displaySettingsProvider.notifier)
                .setEnergy(selection.first),
          ),
          const SizedBox(height: 20),
          Text(
            S.of(context).displaySaltTitle,
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 2),
          Text(
            S.of(context).displaySaltSubtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          SegmentedButton<SaltDisplay>(
            key: settingsSaltDisplayKey,
            expandedInsets: EdgeInsets.zero,
            showSelectedIcon: false,
            segments: <ButtonSegment<SaltDisplay>>[
              ButtonSegment<SaltDisplay>(
                value: SaltDisplay.salt,
                label: Text(
                  S.of(context).displaySaltOption,
                  key: settingsSaltOptionKey,
                ),
              ),
              ButtonSegment<SaltDisplay>(
                value: SaltDisplay.sodium,
                label: Text(
                  S.of(context).displaySodiumOption,
                  key: settingsSodiumOptionKey,
                ),
              ),
            ],
            selected: <SaltDisplay>{display.salt},
            onSelectionChanged: (Set<SaltDisplay> selection) => ref
                .read(displaySettingsProvider.notifier)
                .setSalt(selection.first),
          ),
          const SizedBox(height: 12),
          Text(
            S.of(context).displayEntryNote,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
