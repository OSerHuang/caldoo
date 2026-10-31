// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'food.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Food _$FoodFromJson(Map<String, dynamic> json) => $checkedCreate('Food', json, (
  $checkedConvert,
) {
  final val = Food(
    id: $checkedConvert('id', (v) => v as String),
    name: $checkedConvert('name', (v) => v as String),
    brand: $checkedConvert('brand', (v) => v as String?),
    barcode: $checkedConvert('barcode', (v) => v as String?),
    aliases: $checkedConvert(
      'aliases',
      (v) =>
          (v as List<dynamic>?)?.map((e) => e as String).toList() ??
          const <String>[],
    ),
    servings: $checkedConvert(
      'servings',
      (v) =>
          (v as List<dynamic>?)
              ?.map((e) => FoodServing.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <FoodServing>[],
    ),
    status: $checkedConvert(
      'status',
      (v) => $enumDecodeNullable(_$FoodStatusEnumMap, v) ?? FoodStatus.active,
    ),
    basis: $checkedConvert(
      'basis',
      (v) =>
          $enumDecodeNullable(_$MeasureBasisEnumMap, v) ?? MeasureBasis.per100g,
    ),
    notes: $checkedConvert('notes', (v) => v as String?),
    source: $checkedConvert(
      'source',
      (v) => $enumDecode(_$FoodSourceEnumMap, v),
    ),
    kcal: $checkedConvert('kcal', (v) => nullableKcalFromJson(v)),
    carbG: $checkedConvert('carbG', (v) => (v as num?)?.toDouble()),
    proteinG: $checkedConvert('proteinG', (v) => (v as num?)?.toDouble()),
    fatG: $checkedConvert('fatG', (v) => (v as num?)?.toDouble()),
    sugarG: $checkedConvert('sugarG', (v) => (v as num?)?.toDouble()),
    saturatedFatG: $checkedConvert(
      'saturatedFatG',
      (v) => (v as num?)?.toDouble(),
    ),
    sodiumMg: $checkedConvert('sodiumMg', (v) => (v as num?)?.toDouble()),
  );
  return val;
});

Map<String, dynamic> _$FoodToJson(Food instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'brand': instance.brand,
  'barcode': instance.barcode,
  'aliases': instance.aliases,
  'servings': instance.servings.map((e) => e.toJson()).toList(),
  'status': _$FoodStatusEnumMap[instance.status]!,
  'basis': _$MeasureBasisEnumMap[instance.basis]!,
  'notes': instance.notes,
  'source': _$FoodSourceEnumMap[instance.source]!,
  'kcal': instance.kcal,
  'carbG': instance.carbG,
  'proteinG': instance.proteinG,
  'fatG': instance.fatG,
  'sugarG': instance.sugarG,
  'saturatedFatG': instance.saturatedFatG,
  'sodiumMg': instance.sodiumMg,
};

const _$FoodStatusEnumMap = {
  FoodStatus.active: 'active',
  FoodStatus.archived: 'archived',
};

const _$MeasureBasisEnumMap = {
  MeasureBasis.per100g: 'per100g',
  MeasureBasis.per100ml: 'per100ml',
};

const _$FoodSourceEnumMap = {
  FoodSource.label: 'label',
  FoodSource.ai: 'ai',
  FoodSource.manual: 'manual',
};
