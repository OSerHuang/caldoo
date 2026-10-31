import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:caldoo/core/units/display_units.dart';
import 'package:caldoo/data/db/app_database.dart';
import 'package:caldoo/features/settings/ai_settings.dart';
import 'package:caldoo/features/settings/ai_settings_screen.dart';
import 'package:caldoo/features/settings/display_settings.dart';
import 'package:caldoo/features/settings/display_settings_screen.dart';
import 'package:caldoo/features/settings/settings_providers.dart';
import 'package:caldoo/features/settings/settings_screen.dart';

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

/// A valid minimal chat completion answering the client's strict-tool probe.
ResponseBody _completion(RequestOptions options) => _json(<String, Object?>{
  'id': 'chatcmpl-test',
  'object': 'chat.completion',
  'created': 0,
  'model': 'test-model',
  'choices': <Object?>[
    <String, Object?>{
      'index': 0,
      'message': <String, Object?>{
        'role': 'assistant',
        'content': '',
        'tool_calls': <Object?>[
          <String, Object?>{
            'index': 0,
            'id': 'call_test',
            'type': 'function',
            'function': <String, Object?>{
              'name': 'ping',
              'arguments': '{"ok": true}',
            },
          },
        ],
      },
    },
  ],
}, 200);

/// Pumps one settings page directly (no router): both second-level screens are
/// self-contained forms/segments and never navigate themselves.
Future<void> _pumpScreen(
  WidgetTester tester, {
  required Widget screen,
  required AppDatabase db,
  required InMemorySecureKeyStore keyStore,
  Dio? dio,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        secureKeyStoreProvider.overrideWithValue(keyStore),
        if (dio != null) dioProvider.overrideWithValue(dio),
      ],
      child: MaterialApp(home: screen),
    ),
  );
  await tester.pumpAndSettle();
}

/// Pumps the real 设置 hub over the two real sub-routes, so the hub entries
/// can be tapped like in the app.
Future<void> _pumpHub(
  WidgetTester tester, {
  required AppDatabase db,
  required InMemorySecureKeyStore keyStore,
}) async {
  final GoRouter router = GoRouter(
    initialLocation: '/profile/settings',
    routes: <RouteBase>[
      GoRoute(
        path: '/profile/settings',
        builder: (BuildContext context, GoRouterState state) =>
            const SettingsScreen(),
        routes: <RouteBase>[
          GoRoute(
            path: 'ai',
            builder: (BuildContext context, GoRouterState state) =>
                const AiSettingsScreen(),
          ),
          GoRoute(
            path: 'display',
            builder: (BuildContext context, GoRouterState state) =>
                const DisplaySettingsScreen(),
          ),
        ],
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        secureKeyStoreProvider.overrideWithValue(keyStore),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  late AppDatabase db;
  late InMemorySecureKeyStore keyStore;

  setUp(() {
    db = testDb();
    keyStore = InMemorySecureKeyStore();
  });

  tearDown(() async {
    await db.close();
  });

  testWidgets('设置 hub lists the two pages and navigates to both', (
    tester,
  ) async {
    await _pumpHub(tester, db: db, keyStore: keyStore);

    expect(find.text('设置'), findsOneWidget);
    expect(find.text('模型设置'), findsOneWidget);
    expect(find.text('API Key / 接口地址 / 模型'), findsOneWidget);
    expect(find.text('数据显示'), findsOneWidget);
    expect(find.text('热量单位 / 盐 · 钠显示'), findsOneWidget);
    // The hub itself carries no form — both forms live one level down.
    expect(find.byKey(const Key('settings_api_key_field')), findsNothing);

    await tester.tap(find.byKey(settingsHubModelKey));
    await tester.pumpAndSettle();
    expect(find.byType(AiSettingsScreen), findsOneWidget);
    expect(find.byKey(const Key('settings_api_key_field')), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(settingsHubDisplayKey));
    await tester.pumpAndSettle();
    expect(find.byType(DisplaySettingsScreen), findsOneWidget);
    expect(find.byKey(settingsEnergyUnitKey), findsOneWidget);
  });

  testWidgets('save persists the key to secure storage and reloads it', (
    tester,
  ) async {
    await _pumpScreen(
      tester,
      screen: const AiSettingsScreen(),
      db: db,
      keyStore: keyStore,
    );

    await tester.enterText(
      find.byKey(const Key('settings_api_key_field')),
      testApiKey,
    );
    await tester.enterText(
      find.byKey(const Key('settings_base_url_field')),
      'https://example.test',
    );
    await tester.enterText(
      find.byKey(const Key('settings_model_field')),
      'test-model',
    );
    await tester.tap(find.byKey(const Key('settings_save_button')));
    await tester.pumpAndSettle();

    // Key landed in secure storage only; baseUrl/model landed in Drift.
    expect(await keyStore.read(), testApiKey);
    expect(
      await db.appSettingsDao.getValue(AiSettingsRepository.baseUrlPrefKey),
      'https://example.test',
    );
    expect(
      await db.appSettingsDao.getValue(AiSettingsRepository.modelPrefKey),
      'test-model',
    );
    final rows = await db.appSettingsDao.getAll();
    for (final row in rows) {
      expect(row.value, isNot(contains(testApiKey)));
    }

    // Simulate an app relaunch: a brand-new widget tree + provider scope over
    // the SAME storage. The key is reloaded (write-only: surfaced as a hint,
    // never re-rendered into the field).
    await tester.pumpWidget(Container());
    await _pumpScreen(
      tester,
      screen: const AiSettingsScreen(),
      db: db,
      keyStore: keyStore,
    );
    expect(find.text('已保存，输入新值以更新'), findsOneWidget);
    final TextField keyField = tester.widget<TextField>(
      find.byKey(const Key('settings_api_key_field')),
    );
    expect(keyField.controller!.text, isEmpty);
    final TextField baseUrlField = tester.widget<TextField>(
      find.byKey(const Key('settings_base_url_field')),
    );
    expect(baseUrlField.controller!.text, 'https://example.test');
  });

  testWidgets('测试连接 with a valid key shows 连接成功', (tester) async {
    final mock = mockDio(_completion);
    await _pumpScreen(
      tester,
      screen: const AiSettingsScreen(),
      db: db,
      keyStore: keyStore,
      dio: mock.dio,
    );

    await tester.enterText(
      find.byKey(const Key('settings_api_key_field')),
      testApiKey,
    );
    await tester.enterText(
      find.byKey(const Key('settings_base_url_field')),
      'https://example.test',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('settings_test_button')));
    await tester.pumpAndSettle();

    expect(find.text('连接成功'), findsOneWidget);
    // The probe really went through AiClient: one POST to the configured
    // base URL carrying the stored key as the Bearer token.
    expect(mock.adapter.calls, 1);
    final RequestOptions request = mock.adapter.requests.single;
    expect(request.uri.toString(), 'https://example.test/chat/completions');
    expect(request.headers['authorization'], 'Bearer $testApiKey');
    expect(jsonEncode(request.data), contains('"model":"deepseek-flash"'));
  });

  testWidgets('测试连接 with a 401 shows 密钥无效', (tester) async {
    final mock = mockDio(
      (options) => _json(<String, Object?>{
        'error': <String, Object?>{'message': 'Incorrect API key provided'},
      }, 401),
    );
    await _pumpScreen(
      tester,
      screen: const AiSettingsScreen(),
      db: db,
      keyStore: keyStore,
      dio: mock.dio,
    );

    await tester.enterText(
      find.byKey(const Key('settings_api_key_field')),
      testApiKey,
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('settings_test_button')));
    await tester.pumpAndSettle();

    expect(find.text('密钥无效'), findsOneWidget);
    expect(find.text('连接成功'), findsNothing);
  });

  testWidgets('empty key disables 测试连接 with a hint', (tester) async {
    await _pumpScreen(
      tester,
      screen: const AiSettingsScreen(),
      db: db,
      keyStore: keyStore,
    );

    OutlinedButton testButton = tester.widget<OutlinedButton>(
      find.byKey(const Key('settings_test_button')),
    );
    expect(testButton.onPressed, isNull);
    expect(
      find.byKey(const Key('settings_test_disabled_hint')),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const Key('settings_api_key_field')),
      testApiKey,
    );
    await tester.pump();
    testButton = tester.widget<OutlinedButton>(
      find.byKey(const Key('settings_test_button')),
    );
    expect(testButton.onPressed, isNotNull);
  });

  testWidgets('数据显示 page shows the two preference groups with defaults', (
    tester,
  ) async {
    await _pumpScreen(
      tester,
      screen: const DisplaySettingsScreen(),
      db: db,
      keyStore: keyStore,
    );

    expect(find.text('热量单位'), findsOneWidget);
    expect(find.text('大卡 (kcal)'), findsOneWidget);
    expect(find.text('千焦 (kJ)'), findsOneWidget);
    expect(find.text('盐 / 钠显示'), findsOneWidget);
    expect(find.text('盐 (g)'), findsOneWidget);
    expect(find.text('钠 (mg)'), findsOneWidget);

    // Defaults: kcal + salt, matching the app's historical display.
    expect(
      tester
          .widget<SegmentedButton<EnergyDisplay>>(
            find.byKey(settingsEnergyUnitKey),
          )
          .selected,
      <EnergyDisplay>{EnergyDisplay.kcal},
    );
    expect(
      tester
          .widget<SegmentedButton<SaltDisplay>>(
            find.byKey(settingsSaltDisplayKey),
          )
          .selected,
      <SaltDisplay>{SaltDisplay.salt},
    );
  });

  testWidgets(
    'display choices save immediately, without the model save action',
    (tester) async {
      await _pumpScreen(
        tester,
        screen: const DisplaySettingsScreen(),
        db: db,
        keyStore: keyStore,
      );

      await tester.tap(find.byKey(settingsEnergyKjKey));
      await tester.pumpAndSettle();

      // Persisted immediately and selected in place.
      expect(
        await db.appSettingsDao.getValue(
          DisplaySettingsRepository.energyPrefKey,
        ),
        'kj',
      );
      expect(
        tester
            .widget<SegmentedButton<EnergyDisplay>>(
              find.byKey(settingsEnergyUnitKey),
            )
            .selected,
        <EnergyDisplay>{EnergyDisplay.kj},
      );
      // The model form's 保存 snackbar must not fire for a display toggle.
      expect(find.text('已保存'), findsNothing);

      await tester.tap(find.byKey(settingsSodiumOptionKey));
      await tester.pumpAndSettle();

      expect(
        await db.appSettingsDao.getValue(DisplaySettingsRepository.saltPrefKey),
        'sodium',
      );
      expect(
        tester
            .widget<SegmentedButton<SaltDisplay>>(
              find.byKey(settingsSaltDisplayKey),
            )
            .selected,
        <SaltDisplay>{SaltDisplay.sodium},
      );

      // Only the two display preference keys were written: no AI config, no key.
      final rows = await db.appSettingsDao.getAll();
      expect(rows.map((row) => row.key).toSet(), <String>{
        DisplaySettingsRepository.energyPrefKey,
        DisplaySettingsRepository.saltPrefKey,
      });
      expect(await keyStore.read(), isNull);
    },
  );

  testWidgets('display choices survive a relaunch of the settings screen', (
    tester,
  ) async {
    await _pumpScreen(
      tester,
      screen: const DisplaySettingsScreen(),
      db: db,
      keyStore: keyStore,
    );
    await tester.tap(find.byKey(settingsEnergyKjKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(settingsSodiumOptionKey));
    await tester.pumpAndSettle();

    // Rebuild the screen over the same storage, like a real relaunch.
    await tester.pumpWidget(Container());
    await _pumpScreen(
      tester,
      screen: const DisplaySettingsScreen(),
      db: db,
      keyStore: keyStore,
    );

    expect(
      tester
          .widget<SegmentedButton<EnergyDisplay>>(
            find.byKey(settingsEnergyUnitKey),
          )
          .selected,
      <EnergyDisplay>{EnergyDisplay.kj},
    );
    expect(
      tester
          .widget<SegmentedButton<SaltDisplay>>(
            find.byKey(settingsSaltDisplayKey),
          )
          .selected,
      <SaltDisplay>{SaltDisplay.sodium},
    );
  });
}
