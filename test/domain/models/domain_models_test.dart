import 'package:flutter_test/flutter_test.dart';
import 'package:caldoo/domain/models/models.dart';

void main() {
  group('UserProfile', () {
    final profile = UserProfile(
      sex: Sex.female,
      birthDate: DateTime.utc(1995, 10, 22),
      heightCm: 165,
      weightKg: 58.5,
      bmrKcalOverride: 1721,
    );

    test('exposes exactly sex/birthDate/heightCm/weightKg/bmrKcalOverride', () {
      expect(profile.toJson().keys.toSet(), <String>{
        'sex',
        'birthDate',
        'heightCm',
        'weightKg',
        'bmrKcalOverride',
      });
    });

    test('json round-trip preserves equality and the birthday', () {
      final decoded = UserProfile.fromJson(profile.toJson());
      expect(decoded, profile);
      expect(decoded.hashCode, profile.hashCode);
      expect(decoded.birthDate, DateTime.utc(1995, 10, 22));
      expect(decoded.bmrKcalOverride, 1721);
    });

    test('serializes birthDate as an ISO-8601 string, not an age', () {
      expect(profile.toJson()['birthDate'], '1995-10-22T00:00:00.000Z');
    });

    test('canonicalBirthDate pins the Y/M/D to UTC midnight', () {
      expect(
        canonicalBirthDate(DateTime(2026, 3, 4, 15, 30)),
        DateTime.utc(2026, 3, 4),
      );
      expect(
        canonicalBirthDate(DateTime.utc(2026, 3, 4, 23, 59)),
        DateTime.utc(2026, 3, 4),
      );
    });

    test('age is derived from the birthday on the caller\'s day', () {
      // The birthday itself counts as reached (whole years, calendar dates).
      expect(profile.ageOn(DateTime.utc(2025, 10, 22)), 30);
      expect(profile.ageOn(DateTime.utc(2025, 10, 21)), 29);
      expect(profile.ageOn(DateTime.utc(2026, 10, 22)), 31);
      // The time of day is irrelevant.
      expect(profile.ageOn(DateTime(2026, 10, 22, 23, 59)), 31);
      expect(ageOnBirthday(profile.birthDate, DateTime.utc(2026, 1, 1)), 30);
    });

    test('a null override ("auto") round-trips as null', () {
      final auto = profile.copyWith(clearBmrKcalOverride: true);
      final json = auto.toJson();
      expect(json['bmrKcalOverride'], isNull);
      final decoded = UserProfile.fromJson(json);
      expect(decoded.bmrKcalOverride, isNull);
      expect(decoded, auto);
    });

    test('copyWith edits only the requested field (weight is editable)', () {
      final heavier = profile.copyWith(weightKg: 60);
      expect(heavier.weightKg, 60);
      expect(heavier.sex, profile.sex);
      expect(heavier.heightCm, profile.heightCm);
      expect(heavier.birthDate, profile.birthDate);
      expect(heavier.bmrKcalOverride, profile.bmrKcalOverride);
    });

    test('copyWith edits the birthday, and the derived age follows it', () {
      final older = profile.copyWith(birthDate: DateTime.utc(1990, 1, 2));
      expect(older.birthDate, DateTime.utc(1990, 1, 2));
      expect(older.ageOn(DateTime.utc(2026, 1, 2)), 36);
      expect(older.sex, profile.sex);
      expect(older.weightKg, profile.weightKg);
    });

    test('copyWith sets the override, and clearBmrKcalOverride removes it', () {
      final pinned = profile.copyWith(bmrKcalOverride: 1800);
      expect(pinned.bmrKcalOverride, 1800);
      expect(pinned.weightKg, profile.weightKg);

      final cleared = pinned.copyWith(clearBmrKcalOverride: true);
      expect(cleared.bmrKcalOverride, isNull);
    });
  });

  group('Food', () {
    const food = Food(
      id: 'food-1',
      name: '全脂牛奶',
      brand: '光明',
      barcode: '6901234567890',
      source: FoodSource.label,
      kcal: 65,
      carbG: 4.8,
      proteinG: 3.3,
      fatG: 3.6,
      sodiumMg: 50,
    );

    test('round-trip preserves every field', () {
      final decoded = Food.fromJson(food.toJson());
      expect(decoded, food);
      expect(decoded.brand, '光明');
      expect(decoded.barcode, '6901234567890');
      expect(decoded.source, FoodSource.label);
    });

    test('brand/barcode are optional', () {
      final decoded = Food.fromJson(const <String, dynamic>{
        'id': 'food-2',
        'name': '米饭',
        'source': 'ai',
        'kcal': 116,
        'carbG': 25.9,
        'proteinG': 2.6,
        'fatG': 0.3,
        'sodiumMg': 2,
      });
      expect(decoded.brand, isNull);
      expect(decoded.barcode, isNull);
      expect(decoded.source, FoodSource.ai);
    });

    test('sodium mg is canonical; salt g is derived for display', () {
      expect(food.sodiumMg, 50);
      expect(food.saltG, closeTo(0.125, 1e-12));
    });

    test('blank label fields stay null (never faked as zero)', () {
      final decoded = Food.fromJson(const <String, dynamic>{
        'id': 'food-3',
        'name': '只标了热量的标签',
        'source': 'label',
        'kcal': 200,
      });
      expect(decoded.carbG, isNull);
      expect(decoded.proteinG, isNull);
      expect(decoded.fatG, isNull);
      expect(decoded.sodiumMg, isNull);
      expect(decoded.saltG, isNull);
    });

    test('source enum covers label|ai|manual', () {
      expect(FoodSource.values, <FoodSource>[
        FoodSource.label,
        FoodSource.ai,
        FoodSource.manual,
      ]);
    });
  });

  group('Meal', () {
    final meal = Meal(
      id: 'meal-1',
      timestamp: DateTime(2026, 9, 22, 12, 30, 15),
      mealType: MealType.lunch,
    );

    test('round-trip preserves id/timestamp/type and a null note', () {
      final decoded = Meal.fromJson(meal.toJson());
      expect(decoded, meal);
      expect(decoded.timestamp, meal.timestamp);
      expect(decoded.mealType, MealType.lunch);
      expect(decoded.note, isNull);
    });

    test('note is optional', () {
      final decoded = Meal.fromJson(meal.copyWith(note: '公司食堂').toJson());
      expect(decoded.note, '公司食堂');
    });

    test('meal type covers the four meals', () {
      expect(MealType.values, <MealType>[
        MealType.breakfast,
        MealType.lunch,
        MealType.dinner,
        MealType.snack,
      ]);
    });
  });

  group('MealItem', () {
    const item = MealItem(
      id: 'item-1',
      foodId: 'food-1',
      name: '全脂牛奶',
      grams: 150,
      kcal: 98,
      carbG: 7.2,
      proteinG: 4.95,
      fatG: 5.4,
      saltG: 0.1875,
      source: FoodSource.label,
      confidence: 0.9,
    );

    test('round-trip preserves every field', () {
      final decoded = MealItem.fromJson(item.toJson());
      expect(decoded, item);
      expect(decoded.foodId, 'food-1');
      expect(decoded.confidence, 0.9);
      expect(decoded.source, FoodSource.label);
    });

    test('foodId and confidence are optional', () {
      final decoded = MealItem.fromJson(const <String, dynamic>{
        'id': 'item-2',
        'name': '两个鸡蛋',
        'grams': 100,
        'kcal': 144,
        'carbG': 1.1,
        'proteinG': 12.6,
        'fatG': 9.8,
        'saltG': 0.3,
        'source': 'ai',
      });
      expect(decoded.foodId, isNull);
      expect(decoded.confidence, isNull);
      expect(decoded.source, FoodSource.ai);
    });

    test('saltG is the stored display unit; sodiumMg is derived (x400)', () {
      expect(item.saltG, 0.1875);
      expect(item.sodiumMg, closeTo(75, 1e-9));
    });
  });

  group('DailyExercise', () {
    final entry = DailyExercise(dayKey: DateTime.utc(2026, 9, 22), kcal: 257);

    test('round-trip preserves every field', () {
      final decoded = DailyExercise.fromJson(entry.toJson());
      expect(decoded, entry);
      expect(decoded.dayKey, DateTime.utc(2026, 9, 22));
      expect(decoded.kcal, 257);
    });

    test('serializes dayKey as an ISO-8601 string and kcal as num', () {
      final json = entry.toJson();
      expect(json.keys.toSet(), <String>{'dayKey', 'kcal'});
      expect(json['dayKey'], '2026-09-22T00:00:00.000Z');
      expect(json['kcal'], 257);
    });

    test('copyWith edits only the requested field', () {
      final heavier = entry.copyWith(kcal: 300);
      expect(heavier.kcal, 300);
      expect(heavier.dayKey, entry.dayKey);
    });
  });

  group('DayRollup', () {
    final rollup = DayRollup(
      date: DateTime(2026, 9, 22),
      intakeKcal: 1936,
      carbG: 200,
      proteinG: 90,
      fatG: 60,
      sodiumMg: 1800,
      exerciseKcal: 257,
      mealCount: 3,
    );

    test('round-trip preserves every field', () {
      final decoded = DayRollup.fromJson(rollup.toJson());
      expect(decoded, rollup);
      expect(decoded.mealCount, 3);
      expect(decoded.exerciseKcal, 257);
    });

    test('empty rollup defaults to zero totals', () {
      final empty = DayRollup(date: DateTime(2026, 9, 21));
      expect(empty.intakeKcal, 0);
      expect(empty.exerciseKcal, 0);
      expect(empty.mealCount, 0);
      expect(empty.saltG, 0);
    });

    test('salt g is derived from canonical sodium mg', () {
      expect(rollup.saltG, closeTo(4.5, 1e-12));
    });
  });

  group('legacy fractional kcal JSON is rounded at the boundary', () {
    test('Food.kcal: 65.4 -> 65', () {
      final decoded = Food.fromJson(const <String, dynamic>{
        'id': 'f-old',
        'name': '旧数据',
        'source': 'label',
        'kcal': 65.4,
      });
      expect(decoded.kcal, 65);
    });

    test('Food.kcal absent stays null, never 0', () {
      final decoded = Food.fromJson(const <String, dynamic>{
        'id': 'f-blank',
        'name': '无热量',
        'source': 'manual',
      });
      expect(decoded.kcal, isNull);
    });

    test('MealItem.kcal: 97.5 -> 98 (half away from zero)', () {
      final decoded = MealItem.fromJson(const <String, dynamic>{
        'id': 'i-old',
        'name': '旧餐',
        'grams': 150,
        'kcal': 97.5,
        'carbG': 7.2,
        'proteinG': 4.95,
        'fatG': 5.4,
        'saltG': 0.1875,
        'source': 'ai',
      });
      expect(decoded.kcal, 98);
    });

    test('DailyExercise.kcal: 257.25 -> 257', () {
      final decoded = DailyExercise.fromJson(const <String, dynamic>{
        'dayKey': '2026-09-22T00:00:00.000Z',
        'kcal': 257.25,
      });
      expect(decoded.kcal, 257);
    });

    test('DayRollup energy: 1935.75/257.25 -> 1936/257', () {
      final decoded = DayRollup.fromJson(const <String, dynamic>{
        'date': '2026-09-22T00:00:00.000Z',
        'intakeKcal': 1935.75,
        'exerciseKcal': 257.25,
      });
      expect(decoded.intakeKcal, 1936);
      expect(decoded.exerciseKcal, 257);
    });

    test(
      'UserProfile.bmrKcalOverride: 1978.5 -> 1979 (half away from zero)',
      () {
        final decoded = UserProfile.fromJson(const <String, dynamic>{
          'sex': 'male',
          'birthDate': '1995-10-22T00:00:00.000Z',
          'heightCm': 175,
          'weightKg': 70,
          'bmrKcalOverride': 1978.5,
        });
        expect(decoded.bmrKcalOverride, 1979);
      },
    );
  });

  group('AiMealDraft', () {
    test('round-trip with nested items uses explicitToJson', () {
      const draft = AiMealDraft(
        items: <MealItem>[
          MealItem(
            id: 'item-1',
            name: '两个鸡蛋',
            grams: 100,
            kcal: 144,
            carbG: 1.1,
            proteinG: 12.6,
            fatG: 9.8,
            saltG: 0.3,
            source: FoodSource.ai,
            confidence: 0.8,
          ),
        ],
        note: '两个鸡蛋一碗米饭',
      );
      final json = draft.toJson();
      expect(json['items'], isA<List<dynamic>>());
      final decoded = AiMealDraft.fromJson(json);
      expect(decoded, draft);
      expect(decoded.items.single.name, '两个鸡蛋');
      expect(decoded.warning, isNull);
    });

    test('empty draft carries a warning for the review banner', () {
      const draft = AiMealDraft(items: <MealItem>[], warning: 'AI 解析失败，请手动填写');
      final decoded = AiMealDraft.fromJson(draft.toJson());
      expect(decoded.items, isEmpty);
      expect(decoded.warning, 'AI 解析失败，请手动填写');
      expect(decoded, draft);
    });
  });
}
