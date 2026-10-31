// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'food_serving.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FoodServing _$FoodServingFromJson(Map<String, dynamic> json) => FoodServing(
  label: json['label'] as String,
  amount: (json['amount'] as num).toDouble(),
  unit: json['unit'] as String,
);

Map<String, dynamic> _$FoodServingToJson(FoodServing instance) =>
    <String, dynamic>{
      'label': instance.label,
      'amount': instance.amount,
      'unit': instance.unit,
    };
