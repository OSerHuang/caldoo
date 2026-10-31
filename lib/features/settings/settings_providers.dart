/// Riverpod wiring for the BYOK settings feature.
///
/// The graph: [appDatabaseProvider] + [secureKeyStoreProvider] feed
/// [aiSettingsRepositoryProvider]; [apiKeyProvider] exposes the repo's
/// secure-storage read as the `ApiKeyProvider` typedef that [AiClient]
/// consumes, so the client reads the key from secure storage and from
/// nowhere else. No key value is ever held in a provider's state.
library;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:caldoo/ai/ai_client.dart';
import 'package:caldoo/data/db/app_database.dart';
import 'package:caldoo/features/settings/ai_settings.dart';

/// Root drift database. Opened lazily on first use and closed with the scope.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final AppDatabase db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

/// The API-key boundary. Production backs it with `flutter_secure_storage`;
/// tests override it with an in-memory fake.
final secureKeyStoreProvider = Provider<SecureKeyStore>(
  (ref) => FlutterSecureKeyStore(),
);

/// Non-secret prefs (Drift) + secret key (secure storage) in one facade.
final aiSettingsRepositoryProvider = Provider<AiSettingsRepository>(
  (ref) => AiSettingsRepository(
    dao: ref.watch(appDatabaseProvider).appSettingsDao,
    keyStore: ref.watch(secureKeyStoreProvider),
  ),
);

/// The current non-secret config (`baseUrl` / `model`), loadable and
/// watchable. Invalidated after every save so [aiClientProvider] rebuilds
/// with the fresh config.
final aiSettingsConfigProvider = FutureProvider<AiSettings>(
  (ref) => ref.watch(aiSettingsRepositoryProvider).loadConfig(),
);

/// The key provider injected into [AiClient]: a thin closure over secure
/// storage. The key value itself is never stored in Riverpod state.
final apiKeyProvider = Provider<ApiKeyProvider>(
  (ref) =>
      () => ref.read(aiSettingsRepositoryProvider).readApiKey(),
);

/// Dio instance used by [aiClientProvider]. Overridable in tests so a mock
/// adapter can serve canned responses without any socket.
final dioProvider = Provider<Dio>((ref) => Dio());

/// The app-wide AI client, rebuilt whenever the saved config changes. The
/// key is read lazily per request through [apiKeyProvider].
final aiClientProvider = Provider<AiClient>((ref) {
  final AiSettings config =
      ref.watch(aiSettingsConfigProvider).value ?? AiSettings.defaults;
  return AiClient(
    baseUrl: config.baseUrl,
    model: config.model,
    apiKey: ref.watch(apiKeyProvider),
    dio: ref.watch(dioProvider),
  );
});

/// Outcome of the "测试连接" action, as a sealed taxonomy mirroring `AiError`.
sealed class ConnectionTestOutcome {
  const ConnectionTestOutcome();
}

/// No test has run yet (or the form changed since the last one).
final class ConnectionTestIdle extends ConnectionTestOutcome {
  const ConnectionTestIdle();
}

/// A probe request is in flight.
final class ConnectionTestRunning extends ConnectionTestOutcome {
  const ConnectionTestRunning();
}

/// The provider answered with a valid strict tool call.
final class ConnectionTestSuccess extends ConnectionTestOutcome {
  const ConnectionTestSuccess();
}

/// The probe failed; [error] is the typed, sanitized `AiError` (never
/// carries the key).
final class ConnectionTestFailure extends ConnectionTestOutcome {
  const ConnectionTestFailure(this.error);

  final AiError error;
}

/// View state for the settings screen.
///
/// Deliberately contains NO key value — only [hasSavedKey], so the UI can
/// render a "saved, enter to replace" hint without ever re-displaying the
/// secret.
class SettingsViewState {
  const SettingsViewState({
    required this.settings,
    required this.hasSavedKey,
    this.testOutcome = const ConnectionTestIdle(),
  });

  /// The non-secret config (current saved values).
  final AiSettings settings;

  /// Whether a key exists in secure storage.
  final bool hasSavedKey;

  /// Latest connection-test outcome.
  final ConnectionTestOutcome testOutcome;

  SettingsViewState copyWith({
    AiSettings? settings,
    bool? hasSavedKey,
    ConnectionTestOutcome? testOutcome,
  }) => SettingsViewState(
    settings: settings ?? this.settings,
    hasSavedKey: hasSavedKey ?? this.hasSavedKey,
    testOutcome: testOutcome ?? this.testOutcome,
  );
}

/// Loads and mutates the BYOK settings.
class SettingsController extends AsyncNotifier<SettingsViewState> {
  @override
  Future<SettingsViewState> build() async {
    final AiSettingsRepository repo = ref.watch(aiSettingsRepositoryProvider);
    final AiSettings settings = await repo.loadConfig();
    final bool hasKey = await repo.hasApiKey();
    return SettingsViewState(settings: settings, hasSavedKey: hasKey);
  }

  /// Persists the form: non-secret config to Drift, a non-empty [apiKey] to
  /// secure storage. Blank baseUrl/model fall back to the verified defaults;
  /// a blank key leaves the stored key untouched (write-only UX).
  Future<void> save({
    required String baseUrl,
    required String model,
    String? apiKey,
  }) async {
    final AiSettingsRepository repo = ref.read(aiSettingsRepositoryProvider);
    final AiSettings settings = AiSettings(
      baseUrl: baseUrl.trim().isEmpty
          ? AiSettings.defaults.baseUrl
          : baseUrl.trim(),
      model: model.trim().isEmpty ? AiSettings.defaults.model : model.trim(),
    );
    await repo.saveConfig(settings);
    final String trimmedKey = apiKey?.trim() ?? '';
    if (trimmedKey.isNotEmpty) {
      await repo.saveApiKey(trimmedKey);
    }
    ref.invalidate(aiSettingsConfigProvider);
    state = AsyncData(
      SettingsViewState(
        settings: settings,
        hasSavedKey: await repo.hasApiKey(),
      ),
    );
  }

  /// Saves the form, then issues one minimal probe through [aiClientProvider]
  /// (a tiny strict-tool completion) and records the typed outcome. Success
  /// means the provider answered with a parseable tool call — anything else
  /// surfaces the real `AiError`, never a fake success.
  Future<void> saveAndTestConnection({
    required String baseUrl,
    required String model,
    String? apiKey,
  }) async {
    await save(baseUrl: baseUrl, model: model, apiKey: apiKey);
    final SettingsViewState? current = state.value;
    if (current == null) {
      return;
    }
    state = AsyncData(
      current.copyWith(testOutcome: const ConnectionTestRunning()),
    );
    // Make sure the client is rebuilt against the just-saved config before
    // the probe reads it.
    await ref.read(aiSettingsConfigProvider.future);
    final AiError? failure = await _probe(ref.read(aiClientProvider));
    final SettingsViewState? after = state.value;
    if (after == null) {
      return;
    }
    state = AsyncData(
      after.copyWith(
        testOutcome: failure == null
            ? const ConnectionTestSuccess()
            : ConnectionTestFailure(failure),
      ),
    );
  }

  /// One minimal strict-tool completion: a tiny prompt, schema and token
  /// budget. Returns `null` on success or the typed [AiError] on failure.
  static Future<AiError?> _probe(AiClient client) async {
    try {
      await client.completeWithTool(
        messages: <AiMessage>[
          AiMessage.user(const <AiPart>[AiTextPart('ping')]),
        ],
        toolName: 'ping',
        parameters: const <String, Object?>{
          'type': 'object',
          'properties': <String, Object?>{
            'ok': <String, Object?>{'type': 'boolean'},
          },
          'additionalProperties': false,
        },
        maxTokens: 256,
      );
      return null;
    } on AiError catch (error) {
      return error;
    }
  }
}

/// The settings screen controller.
final settingsControllerProvider =
    AsyncNotifierProvider<SettingsController, SettingsViewState>(
      SettingsController.new,
    );
