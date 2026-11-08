/// Riverpod dependency-injection graph for the whole app.
///
/// One place to wire the runtime object graph: the Drift [AppDatabase], the
/// four repository ports (Drift implementations in production, fakes in
/// tests), the non-secret [AppSettingsStore], and the `connectivity_plus`
/// seam consumed by the offline UI (task 30).
///
/// Rules this graph exists to enforce:
/// * widgets NEVER construct repositories or the database inline — they
///   `ref.watch` a provider from this file;
/// * there are NO global singletons; every object is owned by the
///   [ProviderContainer] and disposed with it;
/// * tests override [appDatabaseProvider] with the in-memory harness from
///   `test/data/db/_test_db.dart` (and [connectivityProvider] with a canned
///   stream), so the real file DB is never opened under `flutter test`.
///
/// [appDatabaseProvider] itself is declared in
/// `features/settings/settings_providers.dart` (task 17 built the settings
/// graph first) and re-exported here so consumers of this file see exactly
/// ONE database element — two same-named providers in two libraries would
/// otherwise open two connections to the same SQLite file and drift streams
/// would stop seeing each other's writes. That file is intentionally not
/// modified.
library;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:caldoo/data/repositories/repositories.dart';
import 'package:caldoo/data/settings/app_settings_store.dart';
import 'package:caldoo/domain/repositories/repositories.dart';
import 'package:caldoo/features/settings/settings_providers.dart'
    show appDatabaseProvider;

export 'package:caldoo/features/settings/settings_providers.dart'
    show appDatabaseProvider;

/// The `ProfileRepository` port, backed by the app database.
final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => DriftProfileRepository(ref.watch(appDatabaseProvider)),
);

/// The `FoodRepository` port, backed by the app database.
final foodRepositoryProvider = Provider<FoodRepository>(
  (ref) => DriftFoodRepository(ref.watch(appDatabaseProvider)),
);

/// The `MealRepository` port, backed by the app database.
final mealRepositoryProvider = Provider<MealRepository>(
  (ref) => DriftMealRepository(ref.watch(appDatabaseProvider)),
);

/// The `MealTemplateRepository` port, backed by the app database.
final mealTemplateRepositoryProvider = Provider<MealTemplateRepository>(
  (ref) => DriftMealTemplateRepository(ref.watch(appDatabaseProvider)),
);

/// The `DailyExerciseRepository` port, backed by the app database.
final exerciseRepositoryProvider = Provider<DailyExerciseRepository>(
  (ref) => DriftExerciseRepository(ref.watch(appDatabaseProvider)),
);

/// The `WeightRepository` port, backed by the app database.
final weightRepositoryProvider = Provider<WeightRepository>(
  (ref) => DriftWeightRepository(ref.watch(appDatabaseProvider)),
);

/// Non-secret key/value prefs over the Drift `app_settings` table.
///
/// This is the generic lane (e.g. a future `notice_seen` flag). The AI
/// `baseUrl`/`model` prefs are owned by `AiSettingsRepository`
/// (`aiSettingsRepositoryProvider`) and are NOT duplicated here.
final appSettingsStoreProvider = Provider<AppSettingsStore>(
  (ref) => AppSettingsStore(ref.watch(appDatabaseProvider).appSettingsDao),
);

/// Raw device connectivity, straight from `connectivity_plus`.
///
/// Per the plugin contract the emitted list is never empty; no connectivity
/// is reported as exactly `[ConnectivityResult.none]`. Override this in
/// tests with a canned stream (`Stream.value([...])`) — the plugin channel is
/// not available under `flutter test`.
final connectivityProvider = StreamProvider<List<ConnectivityResult>>((ref) {
  return Connectivity().onConnectivityChanged;
});

/// `true` when the device has no network transport at all.
///
/// Convenience projection for the offline UI (task 30). While the stream is
/// still loading (or errored) the device is assumed reachable, so the UI
/// never flashes an offline banner at startup and a connectivity-plugin
/// failure can never block saving (draft G7).
final isOfflineProvider = Provider<bool>((ref) {
  final List<ConnectivityResult>? results = ref
      .watch(connectivityProvider)
      .value;
  return results != null && results.contains(ConnectivityResult.none);
});
