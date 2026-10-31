/// Pure mapping from a validated AI meal analysis to editable meal rows.
///
/// This is the one place that turns the wire model ([MealAnalysis]) into the
/// `source: ai` [MealItem]s the review screen edits. Both the first-pass route
/// (`review_args.dart`) and the AI-correction path (`meal_revision.dart`) use
/// it, so a revised draft is mapped exactly like the original one.
///
/// Deliberately pure Dart — no Flutter, no Riverpod — so the router glue does
/// not have to depend on the AI settings graph just to convert a draft.
library;

import 'package:uuid/uuid.dart';

import 'package:caldoo/ai/schemas/meal_analysis.dart';
import 'package:caldoo/domain/models/models.dart';

/// Maps one validated [MealAnalysis] to fresh `source: ai` [MealItem]s.
///
/// Every item gets a new id from [idGenerator] so a revised draft never
/// collides with the row it replaces. The optional AI confidence is carried
/// through unchanged (never invented).
List<MealItem> mealItemsFromAnalysis(
  MealAnalysis analysis, {
  String Function() idGenerator = newMealItemId,
}) {
  return <MealItem>[
    for (final MealAnalysisItem item in analysis.items)
      MealItem(
        id: idGenerator(),
        name: item.name,
        grams: item.grams,
        kcal: item.kcal,
        carbG: item.carbG,
        proteinG: item.proteinG,
        fatG: item.fatG,
        saltG: item.saltG,
        source: FoodSource.ai,
        confidence: item.confidence,
      ),
  ];
}

/// The production id source for mapped meal rows.
String newMealItemId() => const Uuid().v4();
