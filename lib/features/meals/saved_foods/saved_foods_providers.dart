/// Riverpod wiring for the saved-food picker (task 20).
///
/// The picker never touches Drift or a repository implementation directly: it
/// watches [savedFoodsProvider], which projects the [FoodRepository] port's
/// change stream. Tests override `foodRepositoryProvider` with the in-memory
/// fake, so no database is opened under `flutter test`.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:caldoo/core/providers/app_providers.dart';
import 'package:caldoo/domain/models/models.dart';

/// The full saved-food catalogue, live: re-emits whenever a food is written
/// or deleted (ordered by name by the repository contract).
final savedFoodsProvider = StreamProvider<List<Food>>((ref) {
  return ref.watch(foodRepositoryProvider).watchAllFoods();
});
