/// Domain models for 卡嘟.
///
/// Plain, immutable classes with `json_serializable` code generation (no
/// freezed). Canonical units are defined in
/// `lib/core/units/nutrition_units.dart`: energy in **whole kcal** (int),
/// macros g, sodium mg.
library;

export 'ai_meal_draft.dart';
export 'daily_exercise.dart';
export 'day_rollup.dart';
export 'food.dart';
export 'food_serving.dart';
export 'meal.dart';
export 'meal_item.dart';
export 'user_profile.dart';
export 'weight_entry.dart';
