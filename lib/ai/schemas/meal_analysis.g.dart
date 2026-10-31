// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'meal_analysis.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MealAnalysisItem _$MealAnalysisItemFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'MealAnalysisItem',
      json,
      ($checkedConvert) {
        final val = MealAnalysisItem(
          name: $checkedConvert('name', (v) => v as String),
          grams: $checkedConvert('grams', (v) => (v as num).toDouble()),
          kcal: $checkedConvert('kcal', (v) => kcalFromJson(v)),
          carbG: $checkedConvert('carb_g', (v) => (v as num).toDouble()),
          proteinG: $checkedConvert('protein_g', (v) => (v as num).toDouble()),
          fatG: $checkedConvert('fat_g', (v) => (v as num).toDouble()),
          saltG: $checkedConvert('salt_g', (v) => (v as num).toDouble()),
          confidence: $checkedConvert(
            'confidence',
            (v) => (v as num?)?.toDouble(),
          ),
        );
        return val;
      },
      fieldKeyMap: const {
        'carbG': 'carb_g',
        'proteinG': 'protein_g',
        'fatG': 'fat_g',
        'saltG': 'salt_g',
      },
    );

Map<String, dynamic> _$MealAnalysisItemToJson(MealAnalysisItem instance) =>
    <String, dynamic>{
      'name': instance.name,
      'grams': instance.grams,
      'kcal': instance.kcal,
      'carb_g': instance.carbG,
      'protein_g': instance.proteinG,
      'fat_g': instance.fatG,
      'salt_g': instance.saltG,
      'confidence': instance.confidence,
    };

MealAnalysis _$MealAnalysisFromJson(Map<String, dynamic> json) =>
    $checkedCreate('MealAnalysis', json, ($checkedConvert) {
      final val = MealAnalysis(
        items: $checkedConvert(
          'items',
          (v) => (v as List<dynamic>)
              .map((e) => MealAnalysisItem.fromJson(e as Map<String, dynamic>))
              .toList(),
        ),
      );
      return val;
    });

Map<String, dynamic> _$MealAnalysisToJson(MealAnalysis instance) =>
    <String, dynamic>{'items': instance.items.map((e) => e.toJson()).toList()};
