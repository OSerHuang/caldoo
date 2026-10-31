import 'package:drift/drift.dart';

import '../app_database.dart';

part 'app_settings_dao.g.dart';

/// Key/value access to the `app_settings` table.
///
/// This table holds **non-secret** preferences only (e.g. `notice_seen`, the
/// AI `baseUrl`/`model`). Secrets never pass through here — the BYOK key lives
/// exclusively in `flutter_secure_storage`.
@DriftAccessor(tables: [AppSettings])
class AppSettingsDao extends DatabaseAccessor<AppDatabase>
    with _$AppSettingsDaoMixin {
  AppSettingsDao(super.attachedDatabase);

  /// The stored value for [key], or null when the key is absent.
  Future<String?> getValue(String key) async {
    final row = await (select(
      appSettings,
    )..where((t) => t.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  /// Emits the stored value for [key] on every change (null while absent).
  Stream<String?> watchValue(String key) {
    final query = select(appSettings)..where((t) => t.key.equals(key));
    return query.watchSingleOrNull().map((row) => row?.value);
  }

  /// Inserts [key] or rewrites its value in place.
  Future<void> setValue(String key, String value) {
    return into(appSettings).insertOnConflictUpdate(
      AppSettingsCompanion.insert(key: key, value: value),
    );
  }

  /// Deletes [key]; returns the number of rows removed.
  Future<int> deleteValue(String key) {
    return (delete(appSettings)..where((t) => t.key.equals(key))).go();
  }

  /// Every setting, ordered by key.
  Future<List<AppSetting>> getAll() {
    return (select(
      appSettings,
    )..orderBy([(t) => OrderingTerm.asc(t.key)])).get();
  }

  /// Emits the full key/value set on every change.
  Stream<List<AppSetting>> watchAll() {
    final query = select(appSettings)
      ..orderBy([(t) => OrderingTerm.asc(t.key)]);
    return query.watch();
  }

  /// Removes every setting (used by "delete all local data", task 29).
  Future<int> clear() => delete(appSettings).go();
}
