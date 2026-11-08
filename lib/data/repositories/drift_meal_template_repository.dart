/// Drift-backed [MealTemplateRepository].
library;

import '../../domain/models/meal_template.dart';
import '../../domain/repositories/meal_template_repository.dart';
import '../db/app_database.dart';
import 'mappers.dart';
import 'meal_template_items_codec.dart' show encodeTemplateItems;

/// Stores meal templates via `MealTemplateDao`, returning domain models only.
class DriftMealTemplateRepository implements MealTemplateRepository {
  /// Creates the repository over [db].
  DriftMealTemplateRepository(this._db);

  final AppDatabase _db;

  @override
  Stream<List<MealTemplate>> watchTemplates() {
    return _db.mealTemplateDao.watchAll().map(
      (rows) => <MealTemplate>[
        for (final row in rows) mealTemplateFromRow(row),
      ],
    );
  }

  @override
  Future<List<MealTemplate>> getAllTemplates() async {
    final rows = await _db.mealTemplateDao.getAll();
    return <MealTemplate>[for (final row in rows) mealTemplateFromRow(row)];
  }

  @override
  Future<void> saveTemplate(MealTemplate template) {
    return _db.mealTemplateDao.insertTemplate(_templateCompanion(template));
  }

  @override
  Future<bool> updateTemplate(MealTemplate template) {
    return _db.mealTemplateDao.updateTemplate(_templateCompanion(template));
  }

  @override
  Future<void> deleteTemplate(String id) async {
    await _db.mealTemplateDao.deleteTemplate(id);
  }

  /// The full editable record of [template]; the one place that maps the
  /// domain [MealTemplate] into the companion both the insert and the update
  /// paths write.
  MealTemplatesCompanion _templateCompanion(MealTemplate template) {
    return MealTemplatesCompanion.insert(
      id: template.id,
      name: template.name,
      createdAt: template.createdAt,
      mealType: template.mealType,
      itemsJson: encodeTemplateItems(template.items),
    );
  }
}
