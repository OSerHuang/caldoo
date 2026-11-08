/// Drift-backed repository implementations.
///
/// These are the only classes in the app that know both the domain models and
/// the Drift schema; the interfaces they implement live in
/// `lib/domain/repositories/` and never import `drift`.
library;

export 'drift_exercise_repository.dart';
export 'drift_food_repository.dart';
export 'drift_meal_repository.dart';
export 'drift_meal_template_repository.dart';
export 'drift_profile_repository.dart';
export 'drift_weight_repository.dart';
