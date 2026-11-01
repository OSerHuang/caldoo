// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'weight_entry.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WeightEntry _$WeightEntryFromJson(Map<String, dynamic> json) =>
    $checkedCreate('WeightEntry', json, ($checkedConvert) {
      final val = WeightEntry(
        dayKey: $checkedConvert('dayKey', (v) => DateTime.parse(v as String)),
        weightKg: $checkedConvert('weightKg', (v) => weightFromJson(v)),
      );
      return val;
    });

Map<String, dynamic> _$WeightEntryToJson(WeightEntry instance) =>
    <String, dynamic>{
      'dayKey': instance.dayKey.toIso8601String(),
      'weightKg': instance.weightKg,
    };
