/// Repository port for logged meals and their items (the phase-2 sync seam).
///
/// Pure Dart: imports domain models (and the shared [MealWithItems] record
/// type used by the rollup engine) and nothing from `drift`. The Drift
/// implementation lives in `lib/data/repositories/`.
///
/// **No calendar logic lives here.** Days and weeks are half-open instant
/// windows `[start, end)` supplied by the caller; `lib/core/time/date_windows.dart`
/// owns the timezone-to-window conversion.
library;

import '../../core/time/date_windows.dart' show MealWithItems;
import '../models/meal.dart';
import '../models/meal_item.dart';

/// Persistence port for [Meal] + [MealItem] records.
abstract interface class MealRepository {
  /// Writes [meal] and its [items] as one atomic unit.
  ///
  /// The owning meal id is taken from [meal]; a domain [MealItem] carries no
  /// `mealId`. The write is a transaction (in the Drift implementation), so a
  /// `watch` stream never observes a half-saved meal.
  Future<void> saveMealWithItems(Meal meal, List<MealItem> items);

  /// Replaces the stored meal [meal] and its items as one atomic unit.
  ///
  /// The meal row is updated (id, timestamp, type, note) and the stored item
  /// list is swapped wholesale for [items] — the edit flow saves the complete
  /// record, so callers pass every item that should remain. The write is a
  /// transaction; a `watch` stream never observes a half-saved meal. Fails
  /// (completes with an error) when no meal with [meal.id] exists.
  Future<void> updateMealWithItems(Meal meal, List<MealItem> items);

  /// Deletes the meal; its items are deleted with it (cascade). Other meals
  /// and their items are untouched.
  Future<void> deleteMeal(String id);

  /// Meals in `[startInclusive, endExclusive)`, ordered by timestamp.
  Future<List<Meal>> getMealsInRange({
    required DateTime startInclusive,
    required DateTime endExclusive,
  });

  /// Meals **with their items** in `[startInclusive, endExclusive)`, ordered
  /// by timestamp (items ordered by id within a meal).
  Future<List<MealWithItems>> getMealsWithItemsInRange({
    required DateTime startInclusive,
    required DateTime endExclusive,
  });

  /// Emits the arbitrary instant window `[startInclusive, endExclusive)` on
  /// change.
  ///
  /// The generic form of [watchMealsForDay] / [watchMealsForWeek]: the
  /// dashboard's month view needs a 28..31 day window, which is just another
  /// half-open range. The day and week methods delegate here so there is
  /// exactly one window query per implementation.
  Stream<List<MealWithItems>> watchMealsInRange({
    required DateTime startInclusive,
    required DateTime endExclusive,
  });

  /// Emits the day window `[dayStartInclusive, dayEndExclusive)` on change.
  Stream<List<MealWithItems>> watchMealsForDay({
    required DateTime dayStartInclusive,
    required DateTime dayEndExclusive,
  });

  /// Emits the week window `[weekStartInclusive, weekEndExclusive)` on change.
  Stream<List<MealWithItems>> watchMealsForWeek({
    required DateTime weekStartInclusive,
    required DateTime weekEndExclusive,
  });

  /// Emits the meal with [id] and its items on every change.
  ///
  /// Emits `null` when no meal with [id] exists (and whenever it is deleted),
  /// so the meal-detail route (task 27's `/meal/:id`) can render an empty
  /// state instead of a stale card. Items are ordered by id, matching the
  /// window queries.
  Stream<MealWithItems?> watchMealWithItems(String id);
}
