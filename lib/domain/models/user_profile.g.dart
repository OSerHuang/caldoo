// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_profile.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UserProfile _$UserProfileFromJson(Map<String, dynamic> json) =>
    $checkedCreate('UserProfile', json, ($checkedConvert) {
      final val = UserProfile(
        sex: $checkedConvert('sex', (v) => $enumDecode(_$SexEnumMap, v)),
        birthDate: $checkedConvert(
          'birthDate',
          (v) => DateTime.parse(v as String),
        ),
        heightCm: $checkedConvert('heightCm', (v) => (v as num).toDouble()),
        weightKg: $checkedConvert('weightKg', (v) => (v as num).toDouble()),
        bmrKcalOverride: $checkedConvert(
          'bmrKcalOverride',
          (v) => nullableKcalFromJson(v),
        ),
        dailyKcalGoalOverride: $checkedConvert(
          'dailyKcalGoalOverride',
          (v) => nullableKcalFromJson(v),
        ),
      );
      return val;
    });

Map<String, dynamic> _$UserProfileToJson(UserProfile instance) =>
    <String, dynamic>{
      'sex': _$SexEnumMap[instance.sex]!,
      'birthDate': instance.birthDate.toIso8601String(),
      'heightCm': instance.heightCm,
      'weightKg': instance.weightKg,
      'bmrKcalOverride': instance.bmrKcalOverride,
      'dailyKcalGoalOverride': instance.dailyKcalGoalOverride,
    };

const _$SexEnumMap = {Sex.male: 'male', Sex.female: 'female'};
