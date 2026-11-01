/// Repository port for the one-per-day body-weight history (the sync seam).
///
/// Pure Dart: imports [WeightEntry] and nothing from `drift`. The Drift
/// implementation lives in `lib/data/repositories/`.
///
/// [WeightEntry.dayKey] is already a date-only key, so callers pass and
/// receive the same shape `dayKeyOf()` produces — no offset conversion here.
library;

import '../models/weight_entry.dart';

/// Persistence port for [WeightEntry] records (one per local day).
///
/// The save contract is the feature's single source of truth for "current
/// weight": [saveWeight] records the day's value AND keeps the profile's
/// `weightKg` (the BMR input) in sync, so the basal metabolism always follows
/// the latest measurement. Deleting does NOT rewind the profile weight.
abstract interface class WeightRepository {
  /// The weight for [dayKey], or `null` when the day has no entry.
  Future<WeightEntry?> getDay(DateTime dayKey);

  /// Emits the weight for [dayKey] on every change (`null` when absent).
  Stream<WeightEntry?> watchDay(DateTime dayKey);

  /// Emits the values in the half-open range `[startInclusive, endExclusive)`.
  Stream<List<WeightEntry>> watchRange({
    required DateTime startInclusive,
    required DateTime endExclusive,
  });

  /// Emits every entry, ordered by day (the trend page's full series).
  Stream<List<WeightEntry>> watchAll();

  /// Upserts [weightKg] for [dayKey] and syncs the stored profile's weight.
  ///
  /// One transaction: when a profile row exists and its `weightKg` differs, it
  /// is rewritten with the new value so the derived BMR follows the latest
  /// measurement. Without a stored profile only the history row is written.
  /// [weightKg] must be finite and positive; anything else throws.
  Future<void> saveWeight({required DateTime dayKey, required double weightKg});

  /// Deletes the entry for [dayKey]; the profile weight is NOT rewound (the
  /// deletion cleans the history, never the BMR input). Returns the number of
  /// rows removed (0 or 1).
  Future<int> deleteDay(DateTime dayKey);
}
