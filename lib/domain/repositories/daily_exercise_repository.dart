/// Repository port for the one-per-day exercise-burn value (the sync seam).
///
/// Pure Dart: imports [DailyExercise] and nothing from `drift`. The Drift
/// implementation lives in `lib/data/repositories/`.
///
/// [DailyExercise.dayKey] is already a date-only key, so callers pass and
/// receive the same shape `dayKeyOf()` produces — no offset conversion here.
library;

import '../models/daily_exercise.dart';

/// Persistence port for [DailyExercise] records (one per local day).
abstract interface class DailyExerciseRepository {
  /// The burn for [dayKey], or `null` when the day has no value.
  Future<DailyExercise?> getDay(DateTime dayKey);

  /// Emits the burn for [dayKey] on every change (`null` when absent).
  Stream<DailyExercise?> watchDay(DateTime dayKey);

  /// Emits the values in the half-open range `[startInclusive, endExclusive)`.
  Stream<List<DailyExercise>> watchRange({
    required DateTime startInclusive,
    required DateTime endExclusive,
  });

  /// Upserts the burn for [dayKey]. A [kcal] `<= 0` clears the day instead.
  Future<void> setKcal({required DateTime dayKey, required int kcal});
}
