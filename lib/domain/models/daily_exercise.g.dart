// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'daily_exercise.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DailyExercise _$DailyExerciseFromJson(Map<String, dynamic> json) =>
    $checkedCreate('DailyExercise', json, ($checkedConvert) {
      final val = DailyExercise(
        dayKey: $checkedConvert('dayKey', (v) => DateTime.parse(v as String)),
        kcal: $checkedConvert('kcal', (v) => kcalFromJson(v)),
      );
      return val;
    });

Map<String, dynamic> _$DailyExerciseToJson(DailyExercise instance) =>
    <String, dynamic>{
      'dayKey': instance.dayKey.toIso8601String(),
      'kcal': instance.kcal,
    };
