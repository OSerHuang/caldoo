/// BYOK AI settings: the non-secret config (`baseUrl` / `model`) plus the
/// secret-store boundary for the API key.
///
/// Security contract:
/// * The API key lives ONLY behind [SecureKeyStore] (production:
///   `flutter_secure_storage` with `AndroidOptions()`). It is never written
///   to the Drift `app_settings` table, never logged, and never part of the
///   export projection ([aiSettingsExportProjection]).
/// * `baseUrl` / `model` are non-secret preferences stored in the Drift
///   `app_settings` key/value table via `AppSettingsDao`.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:caldoo/ai/ai_client.dart' as ai;
import 'package:caldoo/data/db/daos/app_settings_dao.dart';

/// Non-secret AI provider config with the task-1-verified DeepSeek defaults.
@immutable
class AiSettings {
  const AiSettings({this.baseUrl = ai.baseUrl, this.model = ai.model});

  /// Verified default config (`https://api.deepseek.com` + `deepseek-flash`).
  static const AiSettings defaults = AiSettings();

  /// OpenAI-compatible base URL (no secret; stored in `app_settings`).
  final String baseUrl;

  /// Model id (no secret; stored in `app_settings`).
  final String model;

  @override
  bool operator ==(Object other) =>
      other is AiSettings && other.baseUrl == baseUrl && other.model == model;

  @override
  int get hashCode => Object.hash(baseUrl, model);

  /// Debug-safe: contains only the non-secret config, never the key.
  @override
  String toString() => 'AiSettings(baseUrl: $baseUrl, model: $model)';
}

/// The only gateway to the API key. Implementations must never log the value.
abstract interface class SecureKeyStore {
  /// The stored key, or `null` when absent.
  Future<String?> read();

  /// Persists [value] (already trimmed by the caller).
  Future<void> write(String value);

  /// Removes the key (used by "delete all local data", task 29).
  Future<void> delete();
}

/// Production [SecureKeyStore]: `flutter_secure_storage` 11.x.
///
/// `AndroidOptions()` is the v11 default: RSA-OAEP(SHA-256/MGF1) key wrapping
/// + AES-GCM storage encryption via the Android Keystore, API 23+. The app
/// manifest sets `android:allowBackup="false"`, so the encrypted prefs are
/// never swept into an unencrypted device backup.
class FlutterSecureKeyStore implements SecureKeyStore {
  FlutterSecureKeyStore([FlutterSecureStorage? storage])
    : _storage =
          storage ?? const FlutterSecureStorage(aOptions: AndroidOptions());

  /// Secure-storage entry name. Deliberately NOT reused as an `app_settings`
  /// key, so a Drift dump can never collide with the secret entry.
  static const String keyName = 'byok_api_key';

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read() => _storage.read(key: keyName);

  @override
  Future<void> write(String value) =>
      _storage.write(key: keyName, value: value);

  @override
  Future<void> delete() => _storage.delete(key: keyName);
}

/// Reads/writes the BYOK config: non-secret prefs via [AppSettingsDao], the
/// key via [SecureKeyStore]. The two never mix.
class AiSettingsRepository {
  // Public parameter names keep call sites readable; they map 1:1 onto the
  // private fields.
  // ignore_for_file: prefer_initializing_formals
  AiSettingsRepository({
    required AppSettingsDao dao,
    required SecureKeyStore keyStore,
  }) : _dao = dao,
       _keyStore = keyStore;

  /// `app_settings` key for the non-secret base URL pref.
  static const String baseUrlPrefKey = 'ai_base_url';

  /// `app_settings` key for the non-secret model pref.
  static const String modelPrefKey = 'ai_model';

  final AppSettingsDao _dao;
  final SecureKeyStore _keyStore;

  /// Loads the config, falling back to [AiSettings.defaults] for absent or
  /// blank prefs.
  Future<AiSettings> loadConfig() async {
    final String? savedBaseUrl = await _dao.getValue(baseUrlPrefKey);
    final String? savedModel = await _dao.getValue(modelPrefKey);
    return AiSettings(
      baseUrl: _nonBlankOr(savedBaseUrl, ai.baseUrl),
      model: _nonBlankOr(savedModel, ai.model),
    );
  }

  /// Persists the non-secret config to `app_settings`. Never touches the key.
  Future<void> saveConfig(AiSettings settings) async {
    await _dao.setValue(baseUrlPrefKey, settings.baseUrl);
    await _dao.setValue(modelPrefKey, settings.model);
  }

  /// The stored key (trimmed), or `null` when absent.
  Future<String?> readApiKey() async {
    final String? key = await _keyStore.read();
    final String trimmed = key?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }

  /// Whether a non-blank key is stored (without exposing it).
  Future<bool> hasApiKey() async => await readApiKey() != null;

  /// Stores [key] (trimmed) in secure storage ONLY.
  Future<void> saveApiKey(String key) => _keyStore.write(key.trim());

  /// Removes the key from secure storage.
  Future<void> deleteApiKey() => _keyStore.delete();

  static String _nonBlankOr(String? value, String fallback) {
    final String trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? fallback : trimmed;
  }
}

/// The settings portion of the versioned JSON export (task 28).
///
/// SECURITY: this projection is the ONLY shape the exporter may consume, and
/// it contains exactly the two non-secret fields. The API key has no field
/// here by construction; a test pins the key set and asserts a stored key
/// value never appears in the serialized projection.
Map<String, Object?> aiSettingsExportProjection(AiSettings settings) =>
    <String, Object?>{'baseUrl': settings.baseUrl, 'model': settings.model};
