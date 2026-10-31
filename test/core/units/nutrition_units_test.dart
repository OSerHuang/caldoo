import 'package:flutter_test/flutter_test.dart';
import 'package:caldoo/core/units/nutrition_units.dart';

void main() {
  group('canonical contract constants', () {
    test('macro energy factors are the Atwater 4/4/9', () {
      expect(kcalPerGramCarb, 4);
      expect(kcalPerGramProtein, 4);
      expect(kcalPerGramFat, 9);
    });

    test('WHO daily salt target is 5 g (= 2000 mg sodium)', () {
      expect(dailySaltTargetG, 5.0);
      expect(saltGToSodiumMg(dailySaltTargetG), 2000.0);
    });
  });

  group('kJ <-> kcal (kcal is a whole number)', () {
    test('418.4 kJ -> 100 kcal (int)', () {
      expect(kJToKcal(418.4), 100);
    });

    test('100 kcal -> 418.4 kJ', () {
      expect(kcalToKJ(100), closeTo(418.4, 1e-9));
    });

    test('zero stays zero', () {
      expect(kJToKcal(0), 0);
      expect(kcalToKJ(0), 0);
    });

    test('round-trips kJ -> kcal -> kJ for kJ values that divide evenly', () {
      for (final v in <double>[0, 418.4, 836.8, 4184]) {
        expect(kcalToKJ(kJToKcal(v)), closeTo(v, 1e-9), reason: 'v=$v');
      }
    });

    test('the conversion factor constant matches the functions', () {
      expect(kJPerKcal, 4.184);
      expect(kcalToKJ(1), kJPerKcal);
    });
  });

  group('kcalInputToKJ: the typed-大卡 input boundary', () {
    test('keeps fractional kcal (no rounding at the input boundary)', () {
      expect(kcalInputToKJ(358.5), closeTo(358.5 * 4.184, 1e-9));
      expect(kJToKcal(kcalInputToKJ(358.5)), 359); // roundKcal(358.5) = 359
    });

    test('zero stays zero, negatives and non-finites throw', () {
      expect(kcalInputToKJ(0), 0);
      expect(() => kcalInputToKJ(-1), throwsArgumentError);
      expect(() => kcalInputToKJ(double.nan), throwsArgumentError);
      expect(() => kcalInputToKJ(double.infinity), throwsArgumentError);
    });
  });

  group('roundKcal: half away from zero, the single rounding rule', () {
    test('whole values pass through unchanged', () {
      expect(roundKcal(0), 0);
      expect(roundKcal(1649), 1649);
    });

    test('fractions round to the nearest whole kcal', () {
      expect(roundKcal(100.4), 100);
      expect(roundKcal(100.6), 101);
    });

    test('exact halves round away from zero (num.round)', () {
      expect(roundKcal(3.5), 4);
      expect(roundKcal(2.5), 3);
      expect(roundKcal(1935.5), 1936);
    });

    test('legacy literals from the pre-integer suite', () {
      expect(roundKcal(1648.75), 1649);
      expect(roundKcal(1653.75), 1654);
      expect(roundKcal(1935.75), 1936);
      expect(roundKcal(2235.75), 2236);
      expect(roundKcal(257.25), 257);
    });

    test('negative / NaN / infinite throw ArgumentError', () {
      expect(() => roundKcal(-1), throwsArgumentError);
      expect(() => roundKcal(double.nan), throwsArgumentError);
      expect(() => roundKcal(double.infinity), throwsArgumentError);
      expect(() => roundKcal(double.negativeInfinity), throwsArgumentError);
    });
  });

  group('kcalFromJson: untrusted payloads, rounded not rejected', () {
    test('integers pass through', () {
      expect(kcalFromJson(0), 0);
      expect(kcalFromJson(1936), 1936);
    });

    test('legacy fractional JSON is rounded at the boundary', () {
      expect(kcalFromJson(1935.75), 1936);
      expect(kcalFromJson(3.5), 4);
      expect(kcalFromJson(100.4), 100);
    });

    test('nullable flavour: null/absent stays null', () {
      expect(nullableKcalFromJson(null), isNull);
      expect(nullableKcalFromJson(257.25), 257);
    });

    test('non-numeric / negative / non-finite JSON throws FormatException', () {
      for (final bad in <Object?>['100', -1, double.nan, double.infinity]) {
        expect(
          () => kcalFromJson(bad),
          throwsFormatException,
          reason: 'value=$bad',
        );
      }
    });
  });

  group('sodium (mg) <-> salt (g)', () {
    test('2000 mg Na -> 5.0 g salt (WHO)', () {
      expect(sodiumMgToSaltG(2000), 5.0);
    });

    test('5 g salt -> 2000 mg Na', () {
      expect(saltGToSodiumMg(5), 2000.0);
    });

    test(
      'property: saltGToSodiumMg(sodiumMgToSaltG(x)) ~= x for x in 0..10000',
      () {
        for (var i = 0; i <= 10000; i++) {
          final x = i.toDouble();
          expect(
            saltGToSodiumMg(sodiumMgToSaltG(x)),
            closeTo(x, 1e-9),
            reason: 'x=$x',
          );
        }
      },
    );
  });

  group('macro kcal (4/4/9, rounded to int)', () {
    test('10 g carb + 10 g protein + 10 g fat = 170 kcal', () {
      expect(macroKcal(carbG: 10, proteinG: 10, fatG: 10), 170);
    });

    test('isolates each factor', () {
      expect(macroKcal(carbG: 10, proteinG: 0, fatG: 0), 40);
      expect(macroKcal(carbG: 0, proteinG: 10, fatG: 0), 40);
      expect(macroKcal(carbG: 0, proteinG: 0, fatG: 10), 90);
    });

    test('all-zero input is valid and yields zero', () {
      expect(macroKcal(carbG: 0, proteinG: 0, fatG: 0), 0);
    });

    test('a fractional macro result is rounded once, half away from zero', () {
      // 4*1.1 + 4*1.1 + 9*1.1 = 18.7 -> 19.
      expect(macroKcal(carbG: 1.1, proteinG: 1.1, fatG: 1.1), 19);
      // 9*0.5 = 4.5 -> 5.
      expect(macroKcal(carbG: 0, proteinG: 0, fatG: 0.5), 5);
    });
  });

  group('guards: non-finite or negative input throws ArgumentError', () {
    test('negative', () {
      expect(() => kJToKcal(-1), throwsArgumentError);
      expect(() => kcalToKJ(-1), throwsArgumentError);
      expect(() => sodiumMgToSaltG(-1), throwsArgumentError);
      expect(() => saltGToSodiumMg(-1), throwsArgumentError);
      expect(
        () => macroKcal(carbG: -1, proteinG: 0, fatG: 0),
        throwsArgumentError,
      );
      expect(
        () => macroKcal(carbG: 0, proteinG: -1, fatG: 0),
        throwsArgumentError,
      );
      expect(
        () => macroKcal(carbG: 0, proteinG: 0, fatG: -1),
        throwsArgumentError,
      );
    });

    test('NaN', () {
      expect(() => kJToKcal(double.nan), throwsArgumentError);
      expect(() => sodiumMgToSaltG(double.nan), throwsArgumentError);
      expect(() => saltGToSodiumMg(double.nan), throwsArgumentError);
      expect(
        () => macroKcal(carbG: double.nan, proteinG: 0, fatG: 0),
        throwsArgumentError,
      );
      expect(
        () => macroKcal(carbG: 0, proteinG: double.nan, fatG: 0),
        throwsArgumentError,
      );
      expect(
        () => macroKcal(carbG: 0, proteinG: 0, fatG: double.nan),
        throwsArgumentError,
      );
    });

    test('infinity', () {
      expect(() => kJToKcal(double.infinity), throwsArgumentError);
      expect(() => sodiumMgToSaltG(double.infinity), throwsArgumentError);
      expect(
        () => saltGToSodiumMg(double.negativeInfinity),
        throwsArgumentError,
      );
      expect(
        () => macroKcal(carbG: 0, proteinG: 0, fatG: double.infinity),
        throwsArgumentError,
      );
    });
  });
}
