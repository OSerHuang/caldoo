// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'meal_template.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MealTemplate _$MealTemplateFromJson(Map<String, dynamic> json) =>
    $checkedCreate('MealTemplate', json, ($checkedConvert) {
      final val = MealTemplate(
        id: $checkedConvert('id', (v) => v as String),
        name: $checkedConvert('name', (v) => v as String),
        createdAt: $checkedConvert(
          'createdAt',
          (v) => DateTime.parse(v as String),
        ),
        mealType: $checkedConvert(
          'mealType',
          (v) => $enumDecode(_$MealTypeEnumMap, v),
        ),
        items: $checkedConvert(
          'items',
          (v) => (v as List<dynamic>)
              .map((e) => MealItem.fromJson(e as Map<String, dynamic>))
              .toList(),
        ),
      );
      return val;
    });

Map<String, dynamic> _$MealTemplateToJson(MealTemplate instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'createdAt': instance.createdAt.toIso8601String(),
      'mealType': _$MealTypeEnumMap[instance.mealType]!,
      'items': instance.items.map((e) => e.toJson()).toList(),
    };

const _$MealTypeEnumMap = {
  MealType.breakfast: 'breakfast',
  MealType.lunch: 'lunch',
  MealType.dinner: 'dinner',
  MealType.snack: 'snack',
};
