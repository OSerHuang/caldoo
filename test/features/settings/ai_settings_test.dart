import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart' hide Timeout;
import 'package:caldoo/ai/ai_client.dart';
import 'package:caldoo/data/db/app_database.dart';
import 'package:caldoo/features/settings/ai_settings.dart';
import 'package:caldoo/features/settings/settings_providers.dart';

import '../../data/db/_test_db.dart';
import '_fakes.dart';

ResponseBody _json(Object? body, int status) {
  return ResponseBody.fromString(
    body is String ? body : jsonEncode(body),
    status,
    headers: <String, List<String>>{
      Headers.contentTypeHeader: <String>[Headers.jsonContentType],
    },
  );
}

void main() {
  late AppDatabase db;
  late InMemorySecureKeyStore keyStore;
  late AiSettingsRepository repo;

  setUp(() {
    db = testDb();
    keyStore = InMemorySecureKeyStore();
    repo = AiSettingsRepository(dao: db.appSettingsDao, keyStore: keyStore);
  });

  tearDown(() async {
    await db.close();
  });

  group('AiSettingsRepository', () {
    test('defaults come from the task-1-verified constants', () async {
      final AiSettings settings = await repo.loadConfig();
      expect(settings.baseUrl, 'https://api.deepseek.com');
      expect(settings.model, 'deepseek-flash');
      expect(settings, AiSettings.defaults);
    });

    test('config round-trips through the app_settings table', () async {
      await repo.saveConfig(
        const AiSettings(baseUrl: 'https://example.test', model: 'test-model'),
      );
      expect(
        await db.appSettingsDao.getValue(AiSettingsRepository.baseUrlPrefKey),
        'https://example.test',
      );
      expect(
        await db.appSettingsDao.getValue(AiSettingsRepository.modelPrefKey),
        'test-model',
      );
      final AiSettings loaded = await repo.loadConfig();
      expect(loaded.baseUrl, 'https://example.test');
      expect(loaded.model, 'test-model');
    });

    test('key saves to secure storage ONLY, never to Drift', () async {
      await repo.saveConfig(
        const AiSettings(baseUrl: 'https://example.test', model: 'test-model'),
      );
      await repo.saveApiKey('  $testApiKey  ');

      expect(await keyStore.read(), testApiKey);
      expect(await repo.readApiKey(), testApiKey);
      expect(await repo.hasApiKey(), isTrue);

      // The Drift prefs must contain the non-secret config and NOTHING else:
      // no key-shaped entry, and the secret value nowhere in the table.
      final rows = await db.appSettingsDao.getAll();
      expect(rows, hasLength(2));
      for (final row in rows) {
        expect(row.key, isNot(contains('key')));
        expect(row.value, isNot(contains(testApiKey)));
      }
    });
  });

  group('aiSettingsExportProjection', () {
    test('contains exactly the two non-secret fields, no key field', () {
      final Map<String, Object?> projection = aiSettingsExportProjection(
        const AiSettings(baseUrl: 'https://example.test', model: 'test-model'),
      );
      expect(projection.keys, unorderedEquals(<String>['baseUrl', 'model']));
      for (final String field in projection.keys) {
        expect(field.toLowerCase(), isNot(contains('key')));
        expect(field.toLowerCase(), isNot(contains('token')));
        expect(field.toLowerCase(), isNot(contains('secret')));
      }
    });

    test('a stored key value never appears in the projection', () async {
      await repo.saveApiKey(testApiKey);
      final AiSettings settings = await repo.loadConfig();
      final String serialized = jsonEncode(
        aiSettingsExportProjection(settings),
      );
      expect(serialized, isNot(contains(testApiKey)));
      expect(serialized, isNot(contains(FlutterSecureKeyStore.keyName)));
    });
  });

  group('secret hygiene', () {
    test('a stored key never reaches logs or the surfaced error', () async {
      // A hostile provider that echoes the Authorization header back in its
      // error body: even then neither a log line nor the AiError may carry
      // the key (AiClient redacts it).
      final mock = mockDio(
        (options) => _json(<String, Object?>{
          'error': <String, Object?>{
            'message': 'Invalid authentication: $testApiKey',
          },
        }, 401),
      );
      final List<String> logs = <String>[];
      final ProviderContainer container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          secureKeyStoreProvider.overrideWithValue(keyStore),
          dioProvider.overrideWithValue(mock.dio),
        ],
      );
      addTearDown(container.dispose);

      await runZoned(
        () async {
          await container.read(settingsControllerProvider.future);
          await container
              .read(settingsControllerProvider.notifier)
              .saveAndTestConnection(
                baseUrl: 'https://example.test',
                model: 'test-model',
                apiKey: testApiKey,
              );
        },
        zoneSpecification: ZoneSpecification(
          print: (self, parent, zone, line) => logs.add(line),
        ),
      );

      final SettingsViewState state = await container.read(
        settingsControllerProvider.future,
      );
      final ConnectionTestOutcome outcome = state.testOutcome;
      expect(outcome, isA<ConnectionTestFailure>());
      final AiError error = (outcome as ConnectionTestFailure).error;
      expect(error, isA<Unauthorized>());

      expect(logs.join('\n'), isNot(contains(testApiKey)));
      expect(error.toString(), isNot(contains(testApiKey)));
      expect(state.toString(), isNot(contains(testApiKey)));
    });
  });
}
