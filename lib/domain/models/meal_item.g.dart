// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'meal_item.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MealItem _$MealItemFromJson(Map<String, dynamic> json) => $checkedCreate(
  'MealItem',
  json,
  ($checkedConvert) {
    final val = MealItem(
      id: $checkedConvert('id', (v) => v as String),
      foodId: $checkedConvert('foodId', (v) => v as String?),
      name: $checkedConvert('name', (v) => v as String),
      grams: $checkedConvert('grams', (v) => (v as num).toDouble()),
      kcal: $checkedConvert('kcal', (v) => kcalFromJson(v)),
      carbG: $checkedConvert('carbG', (v) => (v as num).toDouble()),
      proteinG: $checkedConvert('proteinG', (v) => (v as num).toDouble()),
      fatG: $checkedConvert('fatG', (v) => (v as num).toDouble()),
      saltG: $checkedConvert('saltG', (v) => (v as num).toDouble()),
      source: $checkedConvert(
        'source',
        (v) => $enumDecode(_$FoodSourceEnumMap, v),
      ),
      confidence: $checkedConvert('confidence', (v) => (v as num?)?.toDouble()),
    );
    return val;
  },
);

Map<String, dynamic> _$MealItemToJson(MealItem instance) => <String, dynamic>{
  'id': instance.id,
  'foodId': instance.foodId,
  'name': instance.name,
  'grams': instance.grams,
  'kcal': instance.kcal,
  'carbG': instance.carbG,
  'proteinG': instance.proteinG,
  'fatG': instance.fatG,
  'saltG': instance.saltG,
  'source': _$FoodSourceEnumMap[instance.source]!,
  'confidence': instance.confidence,
};

const _$FoodSourceEnumMap = {
  FoodSource.label: 'label',
  FoodSource.ai: 'ai',
  FoodSource.manual: 'manual',
};
