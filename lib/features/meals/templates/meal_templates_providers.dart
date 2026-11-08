/// Riverpod wiring for the meal-template feature.
///
/// The templates feature never touches Drift or a repository implementation
/// directly: it watches [mealTemplatesProvider], which projects the
/// [MealTemplateRepository] port's change stream. Tests override
/// `mealTemplateRepositoryProvider` with the in-memory fake, so no database is
/// opened under `flutter test`.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:caldoo/core/providers/app_providers.dart';
import 'package:caldoo/domain/models/models.dart';

/// Every saved meal template, newest first (the repository contract), live.
final mealTemplatesProvider = StreamProvider<List<MealTemplate>>((ref) {
  return ref.watch(mealTemplateRepositoryProvider).watchTemplates();
});
