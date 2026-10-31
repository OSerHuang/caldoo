/// Unit-preference tests: the display conversions, the salt/sodium mapping and
/// the [DisplayScope] fallback contract.
///
/// The domain stores whole kcal and sodium mg; these tests pin that the display
/// layer only *renders* the alternate unit and that the defaults reproduce the
/// historical kcal + salt surface exactly.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:caldoo/core/units/display_units.dart';
import 'package:caldoo/core/units/nutrition_units.dart';

void main() {
  group('energy display', () {
    const DisplayUnits kcal = DisplayUnits.defaults;
    const DisplayUnits kj = DisplayUnits(energy: EnergyDisplay.kj);

    test('kcal passes the stored value through unchanged', () {
      expect(kcal.isKilojoules, isFalse);
      expect(kcal.energyValue(0), 0);
      expect(kcal.energyValue(1715), 1715);
      expect(kcal.energyValueText(1715), '1715');
      expect(kcal.energyUnit, 'kcal');
      expect(kcal.energyText(1715), '1715 kcal');
    });

    test(
      'kJ converts with the one fixed factor and rounds to a whole number',
      () {
        expect(kj.isKilojoules, isTrue);
        expect(kj.energyUnit, 'kJ');
        // 100 kcal * 4.184 = 418.4 -> 418.
        expect(kj.energyValue(100), 418);
        // 1715 kcal * 4.184 = 7175.56 -> 7176.
        expect(kj.energyValue(1715), 7176);
        expect(kj.energyValueText(1715), '7176');
        expect(kj.energyText(1715), '7176 kJ');
        // Zero stays zero in both systems.
        expect(kj.energyValue(0), 0);
        // The stored model value is never mutated.
        const int stored = 1715;
        expect(kj.energyValue(stored), isNot(stored));
        expect(stored, 1715);
        // Matches the canonical conversion helper's factor.
        expect(kj.energyValue(500), kcalToKJ(500).round());
      },
    );

    test('a negative signed balance keeps its sign in kJ', () {
      // The period difference can be negative (盈余); display must preserve it.
      expect(kj.energyValue(-150), (-150 * 4.184).round());
      expect(kj.energyText(-150), '-628 kJ');
    });
  });

  group('salt / sodium display', () {
    const DisplayUnits salt = DisplayUnits.defaults;
    const DisplayUnits sodium = DisplayUnits(salt: SaltDisplay.sodium);

    test('salt is the default: grams of salt, 5 g target', () {
      expect(salt.showsSodium, isFalse);
      expect(salt.saltLabel, '盐');
      expect(salt.saltUnit, 'g');
      expect(salt.saltValueFromSaltG(3.5), 3.5);
      expect(salt.saltValueTextFromSaltG(3.5), '3.5');
      expect(salt.saltValueTextFromSodiumMg(2000), '5');
      expect(salt.saltTargetValue, 5);
      expect(salt.saltTargetText, '5');
      expect(salt.saltProgressFromSaltG(3.5), '3.5 / 5');
    });

    test('sodium shows the stored mineral in mg with a 2000 mg target', () {
      expect(sodium.showsSodium, isTrue);
      expect(sodium.saltLabel, '钠');
      expect(sodium.saltUnit, 'mg');
      // 1 g salt = 400 mg sodium (the app's fixed definition).
      expect(sodium.saltValueFromSaltG(3.5), 1400);
      expect(sodium.saltValueFromSaltG(0.5), 200);
      expect(sodium.saltProgressFromSaltG(3.5), '1400 / 2000');
      expect(sodium.saltValueTextFromSodiumMg(2000), '2000');
      expect(sodium.saltTargetValue, saltGToSodiumMg(dailySaltTargetG));
      expect(sodium.saltTargetText, '2000');
      // Fractional mg stays readable (AppFormat.number caps at two decimals).
      expect(sodium.saltValueTextFromSaltG(0.123), '49.2');
    });
  });

  test('DisplayUnits equality covers both preferences', () {
    expect(
      const DisplayUnits(energy: EnergyDisplay.kj, salt: SaltDisplay.sodium),
      const DisplayUnits(energy: EnergyDisplay.kj, salt: SaltDisplay.sodium),
    );
    expect(
      const DisplayUnits(energy: EnergyDisplay.kj),
      isNot(
        const DisplayUnits(energy: EnergyDisplay.kj, salt: SaltDisplay.sodium),
      ),
    );
  });

  group('DisplayScope', () {
    testWidgets('falls back to kcal + salt when no scope is installed', (
      WidgetTester tester,
    ) async {
      late DisplayUnits seen;
      await tester.pumpWidget(
        Builder(
          builder: (BuildContext context) {
            seen = DisplayUnits.of(context);
            return const SizedBox.shrink();
          },
        ),
      );
      expect(seen, DisplayUnits.defaults);
      expect(seen.energyUnit, 'kcal');
      expect(seen.saltLabel, '盐');
    });

    testWidgets('exposes the installed preferences to descendants', (
      WidgetTester tester,
    ) async {
      late DisplayUnits seen;
      await tester.pumpWidget(
        DisplayScope(
          units: const DisplayUnits(
            energy: EnergyDisplay.kj,
            salt: SaltDisplay.sodium,
          ),
          child: Builder(
            builder: (BuildContext context) {
              seen = DisplayUnits.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(seen.energyUnit, 'kJ');
      expect(seen.saltLabel, '钠');
    });

    testWidgets('a changed scope notifies dependent widgets', (
      WidgetTester tester,
    ) async {
      Widget build(DisplayUnits units) => Directionality(
        textDirection: TextDirection.ltr,
        child: DisplayScope(
          units: units,
          child: Builder(
            builder: (BuildContext context) =>
                Text(DisplayUnits.of(context).energyUnit),
          ),
        ),
      );
      await tester.pumpWidget(build(DisplayUnits.defaults));
      expect(find.text('kcal'), findsOneWidget);
      await tester.pumpWidget(
        build(const DisplayUnits(energy: EnergyDisplay.kj)),
      );
      expect(find.text('kJ'), findsOneWidget);
    });
  });
}
