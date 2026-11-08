/// Repository port for saved meal templates (the phase-2 sync seam).
///
/// Pure Dart: imports domain models and nothing from `drift`. The Drift
/// implementation lives in `lib/data/repositories/`.
///
/// A template is a small, self-contained snapshot that is always read and
/// written **whole** — there is deliberately no item-level API and no window
/// query, because a template has no time of its own.
library;

import '../models/meal_template.dart';

/// Persistence port for [MealTemplate] records.
abstract interface class MealTemplateRepository {
  /// Every saved template, newest first, live.
  Stream<List<MealTemplate>> watchTemplates();

  /// One-shot variant of [watchTemplates] (the backup capture path).
  Future<List<MealTemplate>> getAllTemplates();

  /// Writes [template] as a new row; fails on a duplicate id.
  Future<void> saveTemplate(MealTemplate template);

  /// Replaces the stored template identified by [template.id] with the
  /// complete record. Returns false when no such row exists.
  Future<bool> updateTemplate(MealTemplate template);

  /// Deletes the template with [id]; other templates are untouched.
  Future<void> deleteTemplate(String id);
}
