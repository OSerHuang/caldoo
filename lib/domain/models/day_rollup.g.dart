// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'day_rollup.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DayRollup _$DayRollupFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('DayRollup', json, ($checkedConvert) {
  final val = DayRollup(
    date: $checkedConvert('date', (v) => DateTime.parse(v as String)),
    intakeKcal: $checkedConvert(
      'intakeKcal',
      (v) => v == null ? 0 : kcalFromJson(v),
    ),
    carbG: $checkedConvert('carbG', (v) => (v as num?)?.toDouble() ?? 0),
    proteinG: $checkedConvert('proteinG', (v) => (v as num?)?.toDouble() ?? 0),
    fatG: $checkedConvert('fatG', (v) => (v as num?)?.toDouble() ?? 0),
    sodiumMg: $checkedConvert('sodiumMg', (v) => (v as num?)?.toDouble() ?? 0),
    exerciseKcal: $checkedConvert(
      'exerciseKcal',
      (v) => v == null ? 0 : kcalFromJson(v),
    ),
    mealCount: $checkedConvert('mealCount', (v) => (v as num?)?.toInt() ?? 0),
  );
  return val;
});

Map<String, dynamic> _$DayRollupToJson(DayRollup instance) => <String, dynamic>{
  'date': instance.date.toIso8601String(),
  'intakeKcal': instance.intakeKcal,
  'carbG': instance.carbG,
  'proteinG': instance.proteinG,
  'fatG': instance.fatG,
  'sodiumMg': instance.sodiumMg,
  'exerciseKcal': instance.exerciseKcal,
  'mealCount': instance.mealCount,
};
