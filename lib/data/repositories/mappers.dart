/// Hand-written mappings from Drift row types to domain models.
///
/// One direction only: rows -> models. Writes build `*Companion`s in the
/// repository implementations, so a field can never be silently dropped by a
/// symmetric mapper. Nullable columns are passed through as `null` (never
/// coerced to `0`/`''`), which is what the "blank stays blank" contract
/// requires.
library;

import '../../core/time/date_windows.dart' show MealWithItems;
import '../../domain/models/models.dart';
import '../db/app_database.dart';
import '../db/daos/meal_dao.dart' show MealWithItemRows;
import 'food_supplement_codec.dart';

/// Maps the single-row profile.
UserProfile userProfileFromRow(UserProfileRow row) => UserProfile(
  sex: row.sex,
  // Drift reads a `dateTime()` back as a local-flagged instant; projecting the
  // UTC Y/M/D back to a canonical date keeps the birthday timezone-stable
  // (same trick as `dailyExerciseFromRow` for its day key).
  birthDate: canonicalBirthDate(row.birthDate.toUtc()),
  heightCm: row.heightCm,
  weightKg: row.weightKg,
  bmrKcalOverride: row.bmrKcalOverride,
  dailyKcalGoalOverride: row.dailyKcalGoalOverride,
  dailyGoalPreset: row.dailyGoalPreset,
);

/// Maps a saved food, preserving blank nutrients as `null` (energy is a whole
/// kcal integer, macros/sodium stay fractional).
///
/// The structured supplement columns are nullable for legacy rows: `NULL`
/// reads as "not structured yet" — empty aliases/servings, an active food on a
/// per-100 g basis — never as a missing food.
Food foodFromRow(FoodRow row) => Food(
  id: row.id,
  name: row.name,
  brand: row.brand,
  barcode: row.barcode,
  aliases: decodeAliases(row.aliases),
  servings: decodeServings(row.servings),
  status: row.status ?? FoodStatus.active,
  basis: row.basis ?? MeasureBasis.per100g,
  notes: row.notes,
  source: row.source,
  kcal: row.kcal,
  carbG: row.carbG,
  proteinG: row.proteinG,
  fatG: row.fatG,
  sugarG: row.sugarG,
  saturatedFatG: row.saturatedFatG,
  sodiumMg: row.sodiumMg,
);

/// Maps a logged meal.
Meal mealFromRow(MealRow row) => Meal(
  id: row.id,
  timestamp: row.timestamp,
  mealType: row.mealType,
  note: row.note,
);

/// Maps a logged meal item, preserving a blank food link/confidence as `null`.
MealItem mealItemFromRow(MealItemRow row) => MealItem(
  id: row.id,
  foodId: row.foodId,
  name: row.name,
  grams: row.grams,
  kcal: row.kcal,
  carbG: row.carbG,
  proteinG: row.proteinG,
  fatG: row.fatG,
  saltG: row.saltG,
  source: row.source,
  confidence: row.confidence,
);

/// Maps the one-per-day exercise burn.
///
/// Drift stores a `dateTime()` as unix seconds and reads it back as a
/// local-flagged instant, so the stored UTC-midnight key must be projected back
/// to its date-only shape: `toUtc()` recovers the exact instant and the
/// year/month/day rebuild a stable `DateTime.utc(y, m, d)` key regardless of the
/// machine timezone.
DailyExercise dailyExerciseFromRow(DailyExerciseRow row) {
  final DateTime utc = row.dayKey.toUtc();
  return DailyExercise(
    dayKey: DateTime.utc(utc.year, utc.month, utc.day),
    kcal: row.kcal,
  );
}

/// Maps the one-per-day body weight (same date-key trick as
/// [dailyExerciseFromRow]).
WeightEntry weightEntryFromRow(WeightEntryRow row) {
  final DateTime utc = row.dayKey.toUtc();
  return WeightEntry(
    dayKey: DateTime.utc(utc.year, utc.month, utc.day),
    weightKg: row.weightKg,
  );
}

/// Pairs a joined meal+items row group into the domain record the rollup
/// engine (`lib/core/time/date_windows.dart`) consumes.
MealWithItems mealWithItemsFromRows(MealWithItemRows rows) => (
  meal: mealFromRow(rows.meal),
  items: <MealItem>[for (final item in rows.items) mealItemFromRow(item)],
);
