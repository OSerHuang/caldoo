/// Glue between a saved [MealTemplate] and the task-19 review screen.
///
/// The capture screen's 从模版记录 entry hands the chosen template to
/// [templateReviewRouterProvider], which builds the same `/today/review`
/// payload the AI path does — an [AiMealDraft] under a fresh owning [Meal] —
/// without any AI call. The mapping rules:
///
/// * every item line keeps its `source` and `foodId` (a label-backed line
///   still recomputes from its saved food's per-100 g values on a grams edit)
///   and its confidence is carried through verbatim (never invented), but the
///   ids are always FRESH: two fills of one template must never share ids
///   within a meal;
/// * the meal type comes from the template (the source meal's type; the review
///   screen's selector can change it);
/// * the timestamp is the shared capture rule (`captureTimestampFor`) — today
///   that is always "now"; when the capture flow carries a backfill target
///   (the target-day change), the same call site picks it up unchanged.
///
/// The router is a provider seam like `reviewRouterProvider`: the screen never
/// routes inline, so widget tests override it with a recorder.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import 'package:caldoo/core/logging/meal_trace.dart';
import 'package:caldoo/core/time/date_windows.dart' show LocalOffset;
import 'package:caldoo/domain/models/models.dart';
import 'package:caldoo/features/meals/summary/meal_summary_providers.dart'
    show localOffsetProvider;
import 'package:caldoo/features/nav/review_args.dart'
    show ReviewArgs, captureTimestampFor;

/// Generates an item id; the indirection keeps the mapping pure-Dart testable.
typedef TemplateIdGenerator = String Function();

/// Maps [template]'s item lines into an editable [AiMealDraft] with fresh ids.
///
/// See the library doc for what is kept and what is re-issued.
AiMealDraft draftFromTemplate(
  MealTemplate template, {
  TemplateIdGenerator? idGenerator,
}) {
  final String Function() newId = idGenerator ?? _newId;
  return AiMealDraft(
    items: <MealItem>[
      for (final MealItem item in template.items) item.copyWith(id: newId()),
    ],
  );
}

/// Callback the capture screen injects; production pushes `/today/review` with
/// a meal filled from [template] and reports whether the meal was saved, tests
/// record the template and return a canned result.
///
/// The `true` result is what lets the screen clear the capture inputs once a
/// record is complete, exactly like the AI path's review router.
typedef TemplateReviewRouter = Future<bool?> Function(
  BuildContext context,
  MealTemplate template,
);

/// Default router: pushes the review route with the template-filled draft.
/// Tests override this to record the template.
final templateReviewRouterProvider = Provider<TemplateReviewRouter>(
  (ref) => _pushTemplateReview,
);

Future<bool?> _pushTemplateReview(BuildContext context, MealTemplate template) {
  final ProviderContainer container = ProviderScope.containerOf(context);
  // The template lane has no backfill target of its own yet (a template meal
  // records "now"); the shared rule keeps that decision in one place.
  const DateTime? targetDay = null;
  final LocalOffset offset = container.read(localOffsetProvider);
  mealTraceJson('capture.template', <String, Object?>{
    'templateName': template.name,
    'items': template.items.length,
    'kcal': template.totalKcal,
    'backfill': targetDay != null,
  });
  return GoRouter.of(context).push<bool>(
    '/today/review',
    extra: ReviewArgs(
      draft: draftFromTemplate(template),
      meal: Meal(
        id: const Uuid().v4(),
        timestamp: captureTimestampFor(targetDay, offset),
        mealType: template.mealType,
      ),
    ),
  );
}

String _newId() => const Uuid().v4();
