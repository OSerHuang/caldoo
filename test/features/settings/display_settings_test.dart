/// Tests for the persisted display-unit preferences.
///
/// These are display-only, non-secret prefs stored in the Drift `app_settings`
/// key/value table next to the AI config. The tests pin the defaults (kcal +
/// salt), the round-trip, the unrecognised-value fallback and the controller's
/// immediate persistence.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:caldoo/core/units/display_units.dart';
import 'package:caldoo/data/db/app_database.dart';
import 'package:caldoo/features/settings/display_settings.dart';
import 'package:caldoo/features/settings/display_settings_providers.dart';
import 'package:caldoo/features/settings/settings_providers.dart'
    show appDatabaseProvider;

import '../../data/db/_test_db.dart';

void main() {
  late AppDatabase db;
  late DisplaySettingsRepository repo;

  setUp(() {
    db = testDb();
    repo = DisplaySettingsRepository(db.appSettingsDao);
  });

  tearDown(() async {
    await db.close();
  });

  group('DisplaySettingsRepository', () {
    test('defaults to kcal + salt when nothing is stored', () async {
      final DisplaySettings settings = await repo.load();
      expect(settings, DisplaySettings.defaults);
      expect(settings.energy, EnergyDisplay.kcal);
      expect(settings.salt, SaltDisplay.salt);
      // Defaults reproduce the historical display layer exactly.
      expect(settings.units, DisplayUnits.defaults);
    });

    test('round-trips both preferences through app_settings', () async {
      await repo.save(
        const DisplaySettings(
          energy: EnergyDisplay.kj,
          salt: SaltDisplay.sodium,
        ),
      );
      expect(
        await db.appSettingsDao.getValue(
          DisplaySettingsRepository.energyPrefKey,
        ),
        'kj',
      );
      expect(
        await db.appSettingsDao.getValue(DisplaySettingsRepository.saltPrefKey),
        'sodium',
      );

      final DisplaySettings loaded = await repo.load();
      expect(loaded.energy, EnergyDisplay.kj);
      expect(loaded.salt, SaltDisplay.sodium);
      expect(loaded.units.energyUnit, 'kJ');
      expect(loaded.units.saltLabel, '钠');
    });

    test('unrecognised stored values fall back to the defaults', () async {
      await db.appSettingsDao.setValue(
        DisplaySettingsRepository.energyPrefKey,
        'calories?',
      );
      await db.appSettingsDao.setValue(
        DisplaySettingsRepository.saltPrefKey,
        'NaCl',
      );
      expect(await repo.load(), DisplaySettings.defaults);
    });

    test(
      'only display preferences are written (no data rows touched)',
      () async {
        await repo.save(const DisplaySettings(energy: EnergyDisplay.kj));
        final rows = await db.appSettingsDao.getAll();
        expect(rows, hasLength(2));
        expect(rows.map((row) => row.key).toSet(), <String>{
          DisplaySettingsRepository.energyPrefKey,
          DisplaySettingsRepository.saltPrefKey,
        });
      },
    );
  });

  group('DisplaySettingsController', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);
    });

    test('loads the saved pair and persists switches immediately', () async {
      expect(
        await container.read(displaySettingsProvider.future),
        DisplaySettings.defaults,
      );

      await container
          .read(displaySettingsProvider.notifier)
          .setEnergy(EnergyDisplay.kj);
      expect(
        container.read(displaySettingsProvider).value!.energy,
        EnergyDisplay.kj,
      );
      expect(
        await db.appSettingsDao.getValue(
          DisplaySettingsRepository.energyPrefKey,
        ),
        'kj',
      );

      await container
          .read(displaySettingsProvider.notifier)
          .setSalt(SaltDisplay.sodium);
      expect(
        container.read(displaySettingsProvider).value!.salt,
        SaltDisplay.sodium,
      );
      expect(
        await db.appSettingsDao.getValue(DisplaySettingsRepository.saltPrefKey),
        'sodium',
      );

      // A fresh controller (as after an app restart) loads the persisted pair.
      container.invalidate(displaySettingsProvider);
      final DisplaySettings reloaded = await container.read(
        displaySettingsProvider.future,
      );
      expect(reloaded.energy, EnergyDisplay.kj);
      expect(reloaded.salt, SaltDisplay.sodium);
    });

    test('re-selecting the current value is a no-op', () async {
      await container.read(displaySettingsProvider.future);
      await container
          .read(displaySettingsProvider.notifier)
          .setEnergy(EnergyDisplay.kcal);
      expect(
        await db.appSettingsDao.getValue(
          DisplaySettingsRepository.energyPrefKey,
        ),
        isNull,
      );
    });
  });
}
