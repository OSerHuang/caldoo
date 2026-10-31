/// The structured supplement on [Food] (P2): JSON defaults, round-trip and the
/// exact-replacement semantics the editor relies on.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:caldoo/domain/models/models.dart';

const FoodServing _bag = FoodServing(label: '一袋', amount: 120, unit: 'g');

Food _food({
  List<String> aliases = const <String>[],
  List<FoodServing> servings = const <FoodServing>[],
  FoodStatus status = FoodStatus.active,
  MeasureBasis basis = MeasureBasis.per100g,
  String? notes,
}) => Food(
  id: 'f1',
  name: '辛拉面(农心)',
  brand: '农心',
  aliases: aliases,
  servings: servings,
  status: status,
  basis: basis,
  notes: notes,
  source: FoodSource.label,
  kcal: 422,
  sugarG: 12.5,
  saturatedFatG: 1.2,
  sodiumMg: 1520,
);

void main() {
  group('JSON compatibility', () {
    test('a pre-P2 food object decodes with safe defaults', () {
      final Food legacy = Food.fromJson(<String, dynamic>{
        'id': 'f-legacy',
        'name': '米饭',
        'source': 'manual',
        'kcal': 116,
      });

      expect(legacy.aliases, isEmpty);
      expect(legacy.servings, isEmpty);
      expect(legacy.status, FoodStatus.active);
      expect(legacy.basis, MeasureBasis.per100g);
      expect(legacy.notes, isNull);
      expect(legacy.kcal, 116);
      expect(legacy.isMatchable, isTrue);
    });

    test('toJson/fromJson round-trips the structured surface', () {
      final Food food = _food(
        aliases: const <String>['辛拉面', '泡面'],
        servings: const <FoodServing>[_bag],
        status: FoodStatus.archived,
        basis: MeasureBasis.per100ml,
        notes: '备注',
      );

      final Food decoded = Food.fromJson(food.toJson());

      expect(decoded, food);
      expect(decoded.aliases, <String>['辛拉面', '泡面']);
      expect(decoded.servings.single, _bag);
      expect(decoded.status, FoodStatus.archived);
      expect(decoded.basis, MeasureBasis.per100ml);
      expect(decoded.isMatchable, isFalse);
    });

    test('FoodServing round-trips and distinguishes volume', () {
      const FoodServing bottle = FoodServing(
        label: '一盒',
        amount: 500,
        unit: 'ml',
      );
      expect(FoodServing.fromJson(bottle.toJson()), bottle);
      expect(bottle.isVolume, isTrue);
      expect(_bag.isVolume, isFalse);
    });
  });

  group('withSupplement replaces exactly', () {
    test('clears notes and lists instead of keeping the old values', () {
      final Food food = _food(
        aliases: const <String>['泡面'],
        servings: const <FoodServing>[_bag],
        notes: '旧备注',
      );

      final Food cleared = food.withSupplement(notes: null);

      expect(cleared.notes, isNull);
      expect(cleared.aliases, <String>['泡面']);
      expect(cleared.servings, <FoodServing>[_bag]);
    });

    test('writes every structured field', () {
      final Food food = _food();

      final Food updated = food.withSupplement(
        notes: '新备注',
        aliases: const <String>['辛拉面', '泡面'],
        servings: const <FoodServing>[_bag],
        status: FoodStatus.archived,
        basis: MeasureBasis.per100ml,
      );

      expect(updated.notes, '新备注');
      expect(updated.aliases, <String>['辛拉面', '泡面']);
      expect(updated.servings.single, _bag);
      expect(updated.status, FoodStatus.archived);
      expect(updated.basis, MeasureBasis.per100ml);
      // Nutrients and identity are untouched by a supplement edit.
      expect(updated.kcal, 422);
      expect(updated.name, '辛拉面(农心)');
      expect(updated.id, 'f1');
    });

    test('withNotes keeps the structured surface', () {
      final Food food = _food(
        aliases: const <String>['泡面'],
        servings: const <FoodServing>[_bag],
      );
      final Food updated = food.withNotes('只有备注变了');
      expect(updated.notes, '只有备注变了');
      expect(updated.aliases, <String>['泡面']);
      expect(updated.servings, <FoodServing>[_bag]);
    });
  });

  group('optional GB 28050 declarations', () {
    test('a pre-P3 food decodes them as null (not declared)', () {
      final Food legacy = Food.fromJson(<String, dynamic>{
        'id': 'f-legacy',
        'name': '米饭',
        'source': 'manual',
      });
      expect(legacy.sugarG, isNull);
      expect(legacy.saturatedFatG, isNull);
    });

    test('round-trip and equality include sugar / saturated fat', () {
      final Food food = _food();
      final Food decoded = Food.fromJson(food.toJson());
      expect(decoded.sugarG, 12.5);
      expect(decoded.saturatedFatG, 1.2);
      expect(decoded, food);
      expect(food.copyWith(sugarG: 1), isNot(food));
    });
  });

  group('equality', () {
    test('list contents matter, not identity', () {
      expect(
        _food(aliases: const <String>['泡面']),
        _food(aliases: const <String>['泡面']),
      );
      expect(
        _food(aliases: const <String>['泡面']).hashCode,
        _food(aliases: const <String>['泡面']).hashCode,
      );
      expect(
        _food(aliases: const <String>['泡面']),
        isNot(_food(aliases: const <String>['拉面'])),
      );
      expect(_food(servings: const <FoodServing>[_bag]), isNot(_food()));
      expect(_food(status: FoodStatus.archived), isNot(_food()));
    });
  });
}
