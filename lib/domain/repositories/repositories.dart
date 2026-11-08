/// Repository ports — the boundary the UI/domain talks to instead of Drift.
///
/// Every interface here is pure Dart (no `drift` import) and returns domain
/// models from `lib/domain/models/`, so phase-2 sync can be added as another
/// implementation without touching callers. Drift-backed implementations live
/// in `lib/data/repositories/`.
library;

export 'daily_exercise_repository.dart';
export 'food_repository.dart';
export 'meal_repository.dart';
export 'meal_template_repository.dart';
export 'profile_repository.dart';
export 'weight_repository.dart';
