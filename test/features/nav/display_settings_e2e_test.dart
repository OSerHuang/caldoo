/// End-to-end display-preference test: switch 千焦 / 钠 in 设置 → 数据显示 and
/// verify the read-only dashboard follows, and the manual-entry form adopts
/// them as its **default input units** (the rows stay switchable per field).
///
/// Boots the real app shell (production router, production settings screen) over
/// the in-memory fakes, so this covers the root `DisplayScope` wiring that no
/// isolated widget test can: the preference is persisted through the settings
/// DAO, the root rebuilds, and every mounted display surface picks it up.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:caldoo/core/units/display_units.dart';
import 'package:caldoo/features/dashboard/daily/daily_summary_view.dart';
import 'package:caldoo/features/meals/label/label_capture_screen.dart';
import 'package:caldoo/features/meals/saved_foods/food_library_screen.dart';
import 'package:caldoo/features/nav/nav_shell.dart';
import 'package:caldoo/features/nav/profile_tab_screen.dart';
import 'package:caldoo/features/settings/display_settings_screen.dart';
import 'package:caldoo/features/settings/settings_providers.dart'
    show appDatabaseProvider;
import 'package:caldoo/features/settings/settings_screen.dart';

import '../settings/_fakes.dart' show InMemorySecureKeyStore;
import '_harness.dart';

String _textOf(WidgetTester tester, Key key) =>
    tester.widget<Text>(find.byKey(key)).data!;

void main() {
  late NavTestEnv env;

  setUp(() => env = NavTestEnv());
  tearDown(() => env.dispose());

  testWidgets(
    '设置 → 数据显示 switches the dashboard to kJ / sodium and the manual-entry '
    'defaults follow',
    (WidgetTester tester) async {
      // One logged meal: 100 kcal, salt 0.5 g (200 mg sodium).
      final seeded = navMeal(id: 'display-meal', kcal: 100);
      await env.meals.saveMealWithItems(seeded.meal, seeded.items);
      // The settings screen reads the BYOK key state; without the in-memory
      // key store the real secure-storage channel would block and the screen
      // would never finish loading (so pumpAndSettle would spin forever).
      await env.pump(tester, keyStore: InMemorySecureKeyStore());

      // Default display: kcal + salt.
      expect(_textOf(tester, dailyIntakeKcalKey), '100');
      await scrollTodayUntilVisible(tester, find.byKey(dailySaltKey));
      expect(_textOf(tester, dailySaltKey), '0.5 / 5');

      // 我的 → 设置 → 数据显示: the hub lists the two pages, and the display
      // preferences live one level below it. Switch to 千焦 + 钠.
      await tester.tap(find.byKey(navProfileKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(profileTabSettingsKey));
      await tester.pumpAndSettle();
      expect(find.byType(SettingsScreen), findsOneWidget);
      await tester.tap(find.byKey(settingsHubDisplayKey));
      await tester.pumpAndSettle();
      expect(find.byType(DisplaySettingsScreen), findsOneWidget);

      await tester.tap(find.byKey(settingsEnergyKjKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(settingsSodiumOptionKey));
      await tester.pumpAndSettle();

      // The choice was persisted in the settings table.
      expect(
        await env.container
            .read(appDatabaseProvider)
            .appSettingsDao
            .getValue('display_energy_unit'),
        'kj',
      );

      // Back to 今日: the hero card now reads kJ and sodium mg, while the
      // stored values are untouched (100 kcal, 0.5 g salt).
      await tester.tap(find.byKey(navTodayKey));
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(find.byKey(dailyIntakeKcalKey)).data, '418');
      expect(find.text('kJ'), findsWidgets);
      await scrollTodayUntilVisible(tester, find.byKey(dailySaltKey));
      expect(find.text('钠'), findsWidgets);
      expect(_textOf(tester, dailySaltKey), '200 / 2000');
      expect(find.text('mg'), findsWidgets);
      // The meal itself is unchanged.
      expect(seeded.items.single.kcal, 100);
      debugPrint(
        'DISPLAY_QA energy=kj intake=418 salt=sodium sodium=200 -> PASS',
      );

      // Manual entry follows the preference as its DEFAULT input unit: the
      // no-photo form opens with the energy row in kJ and the sodium row in
      // mg — the printed-unit label is gone, the unit now lives in the row's
      // dropdown (and stays switchable there). The meal editors keep kcal / g
      // and every stored value is untouched either way.
      await tester.tap(find.byKey(navFoodsKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(foodLibraryAddButtonKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(foodLibraryAddManualKey));
      await tester.pumpAndSettle();
      expect(find.byType(LabelCaptureScreen), findsOneWidget);
      expect(find.text('能量（kJ）'), findsNothing);
      expect(find.text('钠（mg）'), findsNothing);
      expect(
        tester
            .widget<DropdownButton<EnergyDisplay>>(
              find.byKey(labelEnergyUnitKey(0)),
            )
            .value,
        EnergyDisplay.kj,
      );
      expect(
        tester
            .widget<DropdownButton<SaltDisplay>>(
              find.byKey(labelSaltUnitKey(0)),
            )
            .value,
        SaltDisplay.sodium,
      );
      debugPrint('DISPLAY_QA entry_units=follow_display -> PASS');
    },
  );
}
