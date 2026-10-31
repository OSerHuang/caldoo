// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ai_meal_draft.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AiMealDraft _$AiMealDraftFromJson(Map<String, dynamic> json) =>
    $checkedCreate('AiMealDraft', json, ($checkedConvert) {
      final val = AiMealDraft(
        items: $checkedConvert(
          'items',
          (v) =>
              (v as List<dynamic>?)
                  ?.map((e) => MealItem.fromJson(e as Map<String, dynamic>))
                  .toList() ??
              const <MealItem>[],
        ),
        note: $checkedConvert('note', (v) => v as String?),
        warning: $checkedConvert('warning', (v) => v as String?),
      );
      return val;
    });

Map<String, dynamic> _$AiMealDraftToJson(AiMealDraft instance) =>
    <String, dynamic>{
      'items': instance.items.map((e) => e.toJson()).toList(),
      'note': instance.note,
      'warning': instance.warning,
    };
