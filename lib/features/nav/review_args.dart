/// Glue between the task-18 capture pipeline and the task-19 review screen.
///
/// The capture screen submits a [CaptureSubmission] (a schema-validated
/// [MealAnalysis] plus the exact photos/text it came from); the review screen
/// edits an [AiMealDraft] under an owning [Meal]. This file owns the payload the
/// route carries and the two conversions that bridge them, so the router stays
/// declarative:
///
/// * [draftFromAnalysis] maps the AI wire items to editable `source: ai`
///   [MealItem]s (fresh ids, confidence preserved);
/// * [mealTypeForHour] guesses the meal a fresh capture belongs to from the
///   local hour, since the AI response carries no meal grouping.
///
/// [ReviewArgs.photos] / [ReviewArgs.userText] forward the capture inputs so the
/// review screen can ask the AI to correct a wrong estimate; they stay optional
/// because a review payload may also be built by hand (deep links, tests).
library;

import 'package:caldoo/ai/schemas/meal_analysis.dart';
import 'package:caldoo/domain/models/models.dart';
import 'package:caldoo/features/meals/capture/image_codec.dart'
    show PreparedPhoto;
import 'package:caldoo/features/meals/review/meal_item_mapping.dart'
    show mealItemsFromAnalysis;
import 'package:uuid/uuid.dart';

/// The `(draft, meal, capture inputs)` payload the `/today/review` route
/// carries as `extra`.
///
/// A dedicated type (rather than a raw record) keeps `state.extra is ReviewArgs`
/// unambiguous and readable at the route builder.
class ReviewArgs {
  /// Creates the review payload.
  const ReviewArgs({
    required this.draft,
    required this.meal,
    this.photos = const <PreparedPhoto>[],
    this.userText = '',
  });

  /// The editable AI draft to review.
  final AiMealDraft draft;

  /// The owning meal record the edited items are saved under.
  final Meal meal;

  /// The bounded photos the draft was produced from (empty for text-only).
  final List<PreparedPhoto> photos;

  /// The text the user typed at capture time, or an empty string.
  final String userText;
}

/// Converts one validated [MealAnalysis] into an editable [AiMealDraft].
///
/// Every item becomes a fresh [MealItem] with `source: FoodSource.ai`; the
/// optional AI confidence is carried through unchanged (never invented). The
/// mapping itself lives in [mealItemsFromAnalysis] so the review screen's
/// AI-correction path reuses it.
AiMealDraft draftFromAnalysis(
  MealAnalysis analysis, {
  String Function() idGenerator = _newId,
}) {
  return AiMealDraft(
    items: mealItemsFromAnalysis(analysis, idGenerator: idGenerator),
  );
}

/// The meal type a capture at [hour] (0..23 local) most plausibly belongs to.
///
/// A coarse, deterministic mapping so a fresh meal is grouped sensibly without
/// asking: 05-10 早餐, 11-14 午餐, 17-20 晚餐, everything else 加餐.
MealType mealTypeForHour(int hour) {
  if (hour >= 5 && hour < 11) {
    return MealType.breakfast;
  }
  if (hour >= 11 && hour < 15) {
    return MealType.lunch;
  }
  if (hour >= 17 && hour < 21) {
    return MealType.dinner;
  }
  return MealType.snack;
}

String _newId() => const Uuid().v4();
