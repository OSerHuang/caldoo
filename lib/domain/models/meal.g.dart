// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'meal.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Meal _$MealFromJson(Map<String, dynamic> json) => $checkedCreate('Meal', json, (
  $checkedConvert,
) {
  final val = Meal(
    id: $checkedConvert('id', (v) => v as String),
    timestamp: $checkedConvert('timestamp', (v) => DateTime.parse(v as String)),
    mealType: $checkedConvert(
      'mealType',
      (v) => $enumDecode(_$MealTypeEnumMap, v),
    ),
    note: $checkedConvert('note', (v) => v as String?),
  );
  return val;
});

Map<String, dynamic> _$MealToJson(Meal instance) => <String, dynamic>{
  'id': instance.id,
  'timestamp': instance.timestamp.toIso8601String(),
  'mealType': _$MealTypeEnumMap[instance.mealType]!,
  'note': instance.note,
};

const _$MealTypeEnumMap = {
  MealType.breakfast: 'breakfast',
  MealType.lunch: 'lunch',
  MealType.dinner: 'dinner',
  MealType.snack: 'snack',
};
