/// Typed facade over the Drift `app_settings` key/value table.
library;

import '../db/daos/app_settings_dao.dart';

/// NON-secret app preferences, backed by the Drift `app_settings` table.
///
/// This is the generic lane for plain prefs (e.g. a future `notice_seen`
/// flag); the AI `baseUrl`/`model` prefs are owned by
/// `AiSettingsRepository` (task 17) and are deliberately NOT redefined here.
/// Secrets never pass through this class — the BYOK key lives exclusively in
/// `flutter_secure_storage`.
///
/// Key constants belong to the feature that owns them, not to this store.
class AppSettingsStore {
  /// Creates the store over the generated [AppSettingsDao].
  AppSettingsStore(this._dao);

  final AppSettingsDao _dao;

  /// The stored value for [key], or null when absent.
  Future<String?> read(String key) => _dao.getValue(key);

  /// Emits the stored value for [key] on every change (null while absent).
  Stream<String?> watch(String key) => _dao.watchValue(key);

  /// Inserts [key] or rewrites its value in place.
  Future<void> write(String key, String value) => _dao.setValue(key, value);

  /// Deletes [key]; a missing key is a no-op.
  Future<void> remove(String key) async {
    await _dao.deleteValue(key);
  }

  /// Reads a boolean pref; absent or non-`'true'` values yield [fallback].
  Future<bool> readBool(String key, {bool fallback = false}) async {
    return switch (await _dao.getValue(key)) {
      'true' => true,
      'false' => false,
      _ => fallback,
    };
  }

  /// Writes a boolean pref as `'true'`/`'false'`.
  Future<void> writeBool(String key, bool value) =>
      _dao.setValue(key, value ? 'true' : 'false');
}
