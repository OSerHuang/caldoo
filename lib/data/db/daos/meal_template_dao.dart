import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/meal_templates.dart';

part 'meal_template_dao.g.dart';

/// Reads and writes [MealTemplates].
///
/// Templates are small and always used whole, so this DAO is a thin CRUD
/// surface: a live list for the picker/library screens and the three writes.
/// No calendar or window logic — a template has no time of its own.
@DriftAccessor(tables: [MealTemplates])
class MealTemplateDao extends DatabaseAccessor<AppDatabase>
    with _$MealTemplateDaoMixin {
  MealTemplateDao(super.attachedDatabase);

  /// Every template, newest first, live.
  Stream<List<MealTemplateRow>> watchAll() {
    return (select(
      mealTemplates,
    )..orderBy([(t) => OrderingTerm.desc(t.createdAt)])).watch();
  }

  /// One-shot variant of [watchAll] (the backup capture path).
  Future<List<MealTemplateRow>> getAll() {
    return (select(
      mealTemplates,
    )..orderBy([(t) => OrderingTerm.desc(t.createdAt)])).get();
  }

  /// Inserts a new template; fails on a duplicate [MealTemplates.id].
  Future<void> insertTemplate(MealTemplatesCompanion template) {
    return into(mealTemplates).insert(template);
  }

  /// Replaces the stored template identified by the companion's id.
  ///
  /// Returns false when no such row exists. Pass the complete record: drift's
  /// [UpdateStatement.replace] writes the row verbatim.
  Future<bool> updateTemplate(MealTemplatesCompanion template) {
    return update(mealTemplates).replace(template);
  }

  /// Deletes the template; returns the number of rows removed (0 or 1).
  Future<int> deleteTemplate(String id) {
    return (delete(mealTemplates)..where((t) => t.id.equals(id))).go();
  }
}
