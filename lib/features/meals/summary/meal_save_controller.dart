/// The validated save path for a logged meal (task 22).
///
/// Nothing reaches the database until [validateMealItems] accepts the draft.
/// The controller is a thin, pure-interface wrapper over [MealRepository] so a
/// test can swap the Drift implementation for the in-memory fake and assert
/// both what was written and what was rejected.
///
/// The `Meal` owns the id; each [MealItem] carries its own [FoodSource] and the
/// repository persists it verbatim, so the per-item provenance survives the
/// round-trip.
library;

import 'package:caldoo/domain/models/models.dart';
import 'package:caldoo/domain/repositories/repositories.dart';
import 'package:caldoo/l10n/app_strings.dart';

/// Thrown when a meal draft fails item validation; no write is attempted.
class MealValidationException implements Exception {
  /// Creates the exception with a zh-CN, user-facing [message].
  const MealValidationException(this.message);

  /// The reason the draft was rejected (shown by the UI).
  final String message;

  @override
  String toString() => 'MealValidationException: $message';
}

/// The save guard: returns the validation error for [items], or `null` when
/// the draft may be written.
///
/// A meal needs at least one item, and every item needs a non-blank name.
String? validateMealItems(List<MealItem> items) {
  if (items.isEmpty) {
    return S.instance.errorNeedAtLeastOneItem;
  }
  for (final MealItem item in items) {
    if (item.name.trim().isEmpty) {
      return S.instance.errorFoodNameRequired;
    }
  }
  return null;
}

/// Validates and persists `(meal, items)` through the [MealRepository] port.
class MealSaveController {
  /// Creates the controller over [repository].
  MealSaveController(this._repository);

  final MealRepository _repository;

  /// Writes [meal] with [items] as one atomic unit.
  ///
  /// Throws [MealValidationException] (and writes nothing) when
  /// [validateMealItems] rejects the draft. On success the item order and each
  /// item's `source` are preserved.
  Future<void> save({required Meal meal, required List<MealItem> items}) async {
    final String? error = validateMealItems(items);
    if (error != null) {
      throw MealValidationException(error);
    }
    await _repository.saveMealWithItems(
      meal,
      List<MealItem>.unmodifiable(items),
    );
  }
}
