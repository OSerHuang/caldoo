import 'package:drift/drift.dart';

import '../../../domain/models/meal.dart';

/// A reusable snapshot of a logged meal (`meal_templates`), created from the
/// meal-detail page's 存为模版 action and offered by the capture screen's
/// 从模版记录 entry.
///
/// A template is always read and written **whole** — no feature queries an
/// item line on its own — so the item list lives in one JSON text column
/// (`List<MealItem>` via json_serializable), the same shape `foods` already
/// uses for its `aliases`/`servings`. There is deliberately no `timestamp`:
/// the moment of use belongs to the new meal, not to the snapshot.
///
/// Canonical units: energy in **whole kcal** (integer-only), macros g — the
/// [MealItem] codec already enforces both at its JSON boundary.
@DataClassName('MealTemplateRow')
class MealTemplates extends Table {
  /// UUID of the template.
  TextColumn get id => text()();

  /// User-visible (editable) name; defaults to the source meal's item names.
  TextColumn get name => text()();

  /// When the template was saved (display + list ordering only).
  DateTimeColumn get createdAt => dateTime()();

  /// The source meal's type; the pre-filled meal type when the template is
  /// used (the review screen's selector can change it).
  TextColumn get mealType => textEnum<MealType>()();

  /// The copied food lines as `List<MealItem>` JSON (see the class doc).
  TextColumn get itemsJson => text()();

  @override
  Set<Column> get primaryKey => {id};
}
