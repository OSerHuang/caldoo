// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'label_parse.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

LabelParseItem _$LabelParseItemFromJson(
  Map<String, dynamic> json,
) => $checkedCreate(
  'LabelParseItem',
  json,
  ($checkedConvert) {
    final val = LabelParseItem(
      energyKj: $checkedConvert('energy_kj', (v) => (v as num).toDouble()),
      proteinG: $checkedConvert('protein_g', (v) => (v as num).toDouble()),
      fatG: $checkedConvert('fat_g', (v) => (v as num).toDouble()),
      saturatedFatG: $checkedConvert(
        'saturated_fat_g',
        (v) => (v as num).toDouble(),
      ),
      carbohydrateG: $checkedConvert(
        'carbohydrate_g',
        (v) => (v as num).toDouble(),
      ),
      sugarG: $checkedConvert('sugar_g', (v) => (v as num).toDouble()),
      sodiumMg: $checkedConvert('sodium_mg', (v) => (v as num).toDouble()),
      foodName: $checkedConvert('food_name', (v) => v as String?),
      brand: $checkedConvert('brand', (v) => v as String?),
      nameAliases: $checkedConvert(
        'name_aliases',
        (v) => (v as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
      ),
      nrvEnergy: $checkedConvert('nrv_energy', (v) => (v as num?)?.toDouble()),
      nrvProtein: $checkedConvert(
        'nrv_protein',
        (v) => (v as num?)?.toDouble(),
      ),
      nrvFat: $checkedConvert('nrv_fat', (v) => (v as num?)?.toDouble()),
      nrvSaturatedFat: $checkedConvert(
        'nrv_saturated_fat',
        (v) => (v as num?)?.toDouble(),
      ),
      nrvCarbohydrate: $checkedConvert(
        'nrv_carbohydrate',
        (v) => (v as num?)?.toDouble(),
      ),
      nrvSugar: $checkedConvert('nrv_sugar', (v) => (v as num?)?.toDouble()),
      nrvSodium: $checkedConvert('nrv_sodium', (v) => (v as num?)?.toDouble()),
    );
    return val;
  },
  fieldKeyMap: const {
    'energyKj': 'energy_kj',
    'proteinG': 'protein_g',
    'fatG': 'fat_g',
    'saturatedFatG': 'saturated_fat_g',
    'carbohydrateG': 'carbohydrate_g',
    'sugarG': 'sugar_g',
    'sodiumMg': 'sodium_mg',
    'foodName': 'food_name',
    'nameAliases': 'name_aliases',
    'nrvEnergy': 'nrv_energy',
    'nrvProtein': 'nrv_protein',
    'nrvFat': 'nrv_fat',
    'nrvSaturatedFat': 'nrv_saturated_fat',
    'nrvCarbohydrate': 'nrv_carbohydrate',
    'nrvSugar': 'nrv_sugar',
    'nrvSodium': 'nrv_sodium',
  },
);

Map<String, dynamic> _$LabelParseItemToJson(LabelParseItem instance) =>
    <String, dynamic>{
      'food_name': instance.foodName,
      'brand': instance.brand,
      'name_aliases': instance.nameAliases,
      'energy_kj': instance.energyKj,
      'protein_g': instance.proteinG,
      'fat_g': instance.fatG,
      'saturated_fat_g': instance.saturatedFatG,
      'carbohydrate_g': instance.carbohydrateG,
      'sugar_g': instance.sugarG,
      'sodium_mg': instance.sodiumMg,
      'nrv_energy': instance.nrvEnergy,
      'nrv_protein': instance.nrvProtein,
      'nrv_fat': instance.nrvFat,
      'nrv_saturated_fat': instance.nrvSaturatedFat,
      'nrv_carbohydrate': instance.nrvCarbohydrate,
      'nrv_sugar': instance.nrvSugar,
      'nrv_sodium': instance.nrvSodium,
    };

LabelParse _$LabelParseFromJson(Map<String, dynamic> json) =>
    $checkedCreate('LabelParse', json, ($checkedConvert) {
      final val = LabelParse(
        labels: $checkedConvert(
          'labels',
          (v) => (v as List<dynamic>)
              .map((e) => LabelParseItem.fromJson(e as Map<String, dynamic>))
              .toList(),
        ),
      );
      return val;
    });

Map<String, dynamic> _$LabelParseToJson(LabelParse instance) =>
    <String, dynamic>{
      'labels': instance.labels.map((e) => e.toJson()).toList(),
    };
