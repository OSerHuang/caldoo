/// Task 18: meal capture UI (photo + free text) widget tests.
///
/// Covers the plan's acceptance criteria directly:
/// * a synthetic 4000x3000 image is downscaled before encoding — the encoded
///   base64 payload is < 1.5 MB and the long edge is <= 1600 px;
/// * submitting with no photo and no text is blocked;
/// * the 1..3 photo cap and undecodable input are rejected;
/// * a valid submit builds the task-14/16 request and routes the parsed draft
///   to review (default placeholder route, or a recorded fake router);
/// * offline disables the AI submit (G7) while the screen stays reachable;
/// * the target-day row announces 记录到：今天 on the today path and a
///   backfill entry gets the prominent banner whose 改为今天 action re-targets
///   the meal into today (the target travels with the submission).
///
/// No test opens a socket: the AI call is served by the settings `MockAdapter`.
library;

import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:caldoo/core/providers/app_providers.dart'
    show
        connectivityProvider,
        foodRepositoryProvider,
        isOfflineProvider,
        mealTemplateRepositoryProvider;
import 'package:caldoo/data/db/app_database.dart';
import 'package:caldoo/domain/models/models.dart'
    show Food, FoodSource, MealItem, MealTemplate, MealType;
import 'package:caldoo/domain/repositories/repositories.dart'
    show FoodRepository;
import 'package:caldoo/features/meals/capture/image_codec.dart';
import 'package:caldoo/features/meals/capture/meal_capture_controller.dart';
import 'package:caldoo/features/meals/capture/meal_capture_screen.dart';
import 'package:caldoo/features/meals/capture/review_placeholder_screen.dart';
import 'package:caldoo/features/meals/templates/template_apply.dart'
    show templateReviewRouterProvider;
import 'package:caldoo/features/meals/templates/template_picker_screen.dart'
    show templatePickerEmptyKey;
import 'package:caldoo/features/settings/ai_settings.dart';
import 'package:caldoo/ai/ai_client.dart' show Unknown;
import 'package:caldoo/features/settings/settings_providers.dart'
    show
        aiSettingsConfigProvider,
        appDatabaseProvider,
        dioProvider,
        secureKeyStoreProvider;
import 'package:caldoo/l10n/app_strings.dart';
import 'package:image/image.dart' as image;

import '../../../data/db/_test_db.dart';
import '../../../data/repositories/fake_repositories.dart'
    show FakeMealTemplateRepository;
import '../../settings/_fakes.dart';
import '_fakes.dart';

/// The base64 budget the plan requires: strictly under 1.5 MB.
const int _payloadBudgetBytes = 1536 * 1024;

Future<ProviderContainer> _pumpCapture(
  WidgetTester tester, {
  required AppDatabase db,
  required InMemorySecureKeyStore keyStore,
  Dio? dio,
  List<ConnectivityResult> connectivity = const <ConnectivityResult>[
    ConnectivityResult.wifi,
  ],
  MealPhotoSource? cameraSource,
  MealPhotoSource? gallerySource,
  RecordingReviewRouter? router,
  FoodRepository? foodRepository,
  DateTime? targetDay,
  List<Override> extraOverrides = const <Override>[],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        secureKeyStoreProvider.overrideWithValue(keyStore),
        if (dio != null) dioProvider.overrideWithValue(dio),
        if (foodRepository != null)
          foodRepositoryProvider.overrideWithValue(foodRepository),
        connectivityProvider.overrideWith(
          (ref) => Stream<List<ConnectivityResult>>.value(connectivity),
        ),
        if (cameraSource != null)
          cameraPhotoSourceProvider.overrideWithValue(cameraSource),
        if (gallerySource != null)
          galleryPhotoSourceProvider.overrideWithValue(gallerySource),
        if (router != null) reviewRouterProvider.overrideWithValue(router.call),
        ...extraOverrides,
      ],
      child: MaterialApp(home: MealCaptureScreen(targetDay: targetDay)),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(
    tester.element(find.byType(MealCaptureScreen)),
  );
}

FilledButton _submitButton(WidgetTester tester) =>
    tester.widget<FilledButton>(find.byKey(const Key('capture_submit_button')));

/// The description field widget (for `readOnly` / controller assertions).
TextField _textField(WidgetTester tester) =>
    tester.widget<TextField>(find.byKey(const Key('capture_text_field')));

/// Extracts the raw base64 of the first `image_url` part from a request body.
String _firstImageBase64(Map<String, Object?> body) {
  final List<Object?> messages = body['messages']! as List<Object?>;
  for (final Object? message in messages) {
    final Map<String, Object?> map = message! as Map<String, Object?>;
    final Object? content = map['content'];
    if (content is! List<Object?>) {
      continue;
    }
    for (final Object? part in content) {
      final Map<String, Object?> partMap = part! as Map<String, Object?>;
      if (partMap['type'] != 'image_url') {
        continue;
      }
      final Map<String, Object?> imageUrl =
          partMap['image_url']! as Map<String, Object?>;
      final String url = imageUrl['url']! as String;
      return url.substring(url.indexOf('base64,') + 'base64,'.length);
    }
  }
  throw StateError('request carries no image_url part');
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

  testWidgets(
    'a synthetic 4000x3000 photo is downscaled below 1.5 MB with a <=1600 px '
    'long edge',
    (tester) async {
      final ProviderContainer container = await _pumpCapture(
        tester,
        db: db,
        keyStore: keyStore,
      );

      container
          .read(captureControllerProvider.notifier)
          .addFrame(syntheticFrame(4000, 3000));
      await tester.pumpAndSettle();

      final CaptureState state = container.read(captureControllerProvider);
      expect(state.photos, hasLength(1));
      final PreparedPhoto photo = state.photos.single;
      final int longEdge = math.max(photo.width, photo.height);

      // The plan's hard acceptance criteria.
      expect(longEdge, lessThanOrEqualTo(maxLongEdge));
      expect(longEdge, maxLongEdge);
      expect(photo.base64Data.length, lessThan(_payloadBudgetBytes));

      // Manual-QA channel: surface the measured numbers in the test output.
      debugPrint(
        'MEAL_CAPTURE_QA payload=${photo.base64Data.length}B '
        '(${photo.base64KiB}KiB) longEdge=${longEdge}px '
        'maxLongEdge=${maxLongEdge}px budget=${_payloadBudgetBytes}B '
        'source=4000x3000 -> PASS',
      );

      // A thumbnail with a working remove action is rendered.
      expect(find.byKey(const Key('capture_thumb_0')), findsOneWidget);
      await tester.tap(find.byKey(const Key('capture_remove_0')));
      await tester.pumpAndSettle();
      expect(container.read(captureControllerProvider).photos, isEmpty);
    },
  );

  testWidgets('submitting with no photo and no text is blocked', (
    tester,
  ) async {
    final mock = mockDio((options) => mealCompletion(mealArguments));
    final ProviderContainer container = await _pumpCapture(
      tester,
      db: db,
      keyStore: keyStore,
      dio: mock.dio,
    );

    expect(_submitButton(tester).onPressed, isNull);

    // Whitespace-only text is still empty input.
    await tester.enterText(find.byKey(const Key('capture_text_field')), '   ');
    await tester.pump();
    expect(_submitButton(tester).onPressed, isNull);

    await tester.tap(
      find.byKey(const Key('capture_submit_button')),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();
    expect(mock.adapter.calls, 0);

    // The controller blocks it too, without touching the client.
    expect(
      await container.read(captureControllerProvider.notifier).submit('  '),
      isNull,
    );
    expect(mock.adapter.calls, 0);

    // Manual-QA channel: the blocked-empty-submit assertion.
    debugPrint(
      'MEAL_CAPTURE_QA empty_submit_blocked=true buttonEnabled=false '
      'clientCalls=${mock.adapter.calls} -> PASS',
    );
  });

  testWidgets('a failing settings-config read fails the submit, not the UI', (
    tester,
  ) async {
    // The config read sits between the submitting flag and the AI call. When
    // it throws (settings storage failure), the old ordering leaked the raw
    // exception past the screen's error handling and left submitting true
    // forever — button and retry both dead until the user navigated away.
    final ProviderContainer container = await _pumpCapture(
      tester,
      db: db,
      keyStore: keyStore,
      extraOverrides: <Override>[
        aiSettingsConfigProvider.overrideWith(
          (Ref ref) => Future<AiSettings>.error(StateError('db broken')),
        ),
      ],
    );
    await tester.enterText(find.byKey(const Key('capture_text_field')), '一碗米饭');

    expect(
      await container.read(captureControllerProvider.notifier).submit('一碗米饭'),
      isNull,
    );
    final CaptureState state = container.read(captureControllerProvider);
    expect(state.submitting, isFalse, reason: 'the flow must unwind');
    expect(state.outcome, CaptureOutcome.failed);
    expect(state.error, isA<Unknown>());
    await tester.pump();
    expect(find.byKey(captureErrorKey), findsOneWidget);
  });

  testWidgets('a 4th photo is rejected at the 3-photo cap', (tester) async {
    final ProviderContainer container = await _pumpCapture(
      tester,
      db: db,
      keyStore: keyStore,
    );
    final CaptureController notifier = container.read(
      captureControllerProvider.notifier,
    );
    for (int i = 0; i < 4; i++) {
      notifier.addFrame(syntheticFrame(40, 30));
    }
    await tester.pumpAndSettle();

    expect(container.read(captureControllerProvider).photos, hasLength(3));
    expect(find.byKey(const Key('capture_thumb_2')), findsOneWidget);
    expect(find.byKey(const Key('capture_thumb_3')), findsNothing);
    // Both pick lanes are disabled once the cap is reached.
    expect(
      tester
          .widget<OutlinedButton>(
            find.byKey(const Key('capture_camera_button')),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<OutlinedButton>(
            find.byKey(const Key('capture_gallery_button')),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('an undecodable photo is rejected and never added', (
    tester,
  ) async {
    final FakePhotoSource source = FakePhotoSource(<Uint8List?>[
      Uint8List.fromList(<int>[1, 2, 3, 4, 5]),
    ]);
    final ProviderContainer container = await _pumpCapture(
      tester,
      db: db,
      keyStore: keyStore,
      gallerySource: source.call,
    );

    await tester.tap(find.byKey(const Key('capture_gallery_button')));
    await tester.pumpAndSettle();

    expect(source.calls, 1);
    expect(container.read(captureControllerProvider).photos, isEmpty);
  });

  testWidgets('the gallery lane runs a picked JPEG through the bounded path', (
    tester,
  ) async {
    final FakePhotoSource source = FakePhotoSource(<Uint8List?>[
      jpegBytes(syntheticFrame(800, 600)),
    ]);
    final ProviderContainer container = await _pumpCapture(
      tester,
      db: db,
      keyStore: keyStore,
      gallerySource: source.call,
    );

    await tester.tap(find.byKey(const Key('capture_gallery_button')));
    await tester.pumpAndSettle();

    expect(source.calls, 1);
    final PreparedPhoto photo = container
        .read(captureControllerProvider)
        .photos
        .single;
    expect(math.max(photo.width, photo.height), 800);
    expect(find.byKey(const Key('capture_thumb_0')), findsOneWidget);
  });

  testWidgets('text-only submit sends the text prompt and routes the draft', (
    tester,
  ) async {
    final RecordingReviewRouter router = RecordingReviewRouter();
    final mock = mockDio((options) => mealCompletion(mealArguments));
    await keyStore.write(testApiKey);
    await _pumpCapture(
      tester,
      db: db,
      keyStore: keyStore,
      dio: mock.dio,
      router: router,
    );

    await tester.enterText(
      find.byKey(const Key('capture_text_field')),
      '两个鸡蛋一碗米饭',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('capture_submit_button')));
    await tester.pumpAndSettle();

    expect(mock.adapter.calls, 1);
    expect(router.calls, 1);
    expect(router.draft!.items.single.name, '米饭');
    // The review screen receives the exact inputs for an AI correction: no
    // photos (text-only meal) plus the trimmed text.
    expect(router.submission!.photos, isEmpty);
    expect(router.submission!.userText, '两个鸡蛋一碗米饭');
    final String body = jsonEncode(mock.adapter.requests.single.data);
    expect(body, contains('两个鸡蛋一碗米饭'));
    expect(body, contains('emit_meal_items'));
    // Text-only mode carries no image part.
    expect(body, isNot(contains('image_url')));
  });

  testWidgets('submit uses the saved config, not the cold-start defaults', (
    tester,
  ) async {
    final RecordingReviewRouter router = RecordingReviewRouter();
    final mock = mockDio((options) => mealCompletion(mealArguments));
    // A saved non-default config. Nothing reads aiSettingsConfigProvider
    // before this submit, so the request must wait for the saved values —
    // reading the client eagerly would carry the user's key to the default
    // endpoint instead.
    await AiSettingsRepository(
      dao: db.appSettingsDao,
      keyStore: keyStore,
    ).saveConfig(
      const AiSettings(
        baseUrl: 'https://saved.example.com',
        model: 'saved-model',
      ),
    );
    await keyStore.write(testApiKey);
    await _pumpCapture(
      tester,
      db: db,
      keyStore: keyStore,
      dio: mock.dio,
      router: router,
    );

    await tester.enterText(
      find.byKey(const Key('capture_text_field')),
      '两个鸡蛋一碗米饭',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('capture_submit_button')));
    await tester.pumpAndSettle();

    expect(mock.adapter.calls, 1);
    expect(router.calls, 1);
    expect(mock.adapter.requests.single.uri.host, 'saved.example.com');
    expect(
      jsonEncode(mock.adapter.requests.single.data),
      contains('saved-model'),
    );
  });

  testWidgets('photo+text submit carries a downscaled image and routes', (
    tester,
  ) async {
    final RecordingReviewRouter router = RecordingReviewRouter();
    final mock = mockDio((options) => mealCompletion(mealArguments));
    await keyStore.write(testApiKey);
    final ProviderContainer container = await _pumpCapture(
      tester,
      db: db,
      keyStore: keyStore,
      dio: mock.dio,
      router: router,
    );
    container
        .read(captureControllerProvider.notifier)
        .addFrame(syntheticFrame(4000, 3000));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('capture_text_field')), '这是午饭');
    await tester.pump();
    await tester.tap(find.byKey(const Key('capture_submit_button')));
    await tester.pumpAndSettle();

    expect(mock.adapter.calls, 1);
    expect(router.calls, 1);
    // The same bounded photo travels to review so the AI can be asked to
    // correct the estimate without re-picking anything.
    expect(router.submission!.photos, hasLength(1));
    expect(router.submission!.userText, '这是午饭');
    expect(router.submission!.photos.single.base64Data, isNotEmpty);

    final Map<String, Object?> body =
        mock.adapter.requests.single.data! as Map<String, Object?>;
    expect(jsonEncode(body), contains('这是午饭'));

    // The image actually sent is the downscaled payload, not the original.
    final String base64Data = _firstImageBase64(body);
    expect(base64Data.length, lessThan(_payloadBudgetBytes));
    final image.Image decoded = image.decodeImage(base64Decode(base64Data))!;
    expect(
      math.max(decoded.width, decoded.height),
      lessThanOrEqualTo(maxLongEdge),
    );
  });

  testWidgets('a saved record clears the captured photos and text', (
    tester,
  ) async {
    final RecordingReviewRouter router = RecordingReviewRouter(saved: true);
    final mock = mockDio((options) => mealCompletion(mealArguments));
    await keyStore.write(testApiKey);
    final ProviderContainer container = await _pumpCapture(
      tester,
      db: db,
      keyStore: keyStore,
      dio: mock.dio,
      router: router,
    );
    container
        .read(captureControllerProvider.notifier)
        .addFrame(syntheticFrame(80, 60));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('capture_text_field')), '午饭');
    await tester.pump();

    await tester.tap(find.byKey(const Key('capture_submit_button')));
    await tester.pumpAndSettle();

    // The review screen reported "saved": the capture flow starts clean.
    expect(router.calls, 1);
    expect(container.read(captureControllerProvider).photos, isEmpty);
    expect(find.byKey(const Key('capture_thumb_0')), findsNothing);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('capture_text_field')))
          .controller!
          .text,
      isEmpty,
    );
    // Nothing left to submit.
    expect(_submitButton(tester).onPressed, isNull);
  });

  testWidgets('a review left without saving keeps the inputs for a retry', (
    tester,
  ) async {
    final RecordingReviewRouter router = RecordingReviewRouter();
    final mock = mockDio((options) => mealCompletion(mealArguments));
    await keyStore.write(testApiKey);
    final ProviderContainer container = await _pumpCapture(
      tester,
      db: db,
      keyStore: keyStore,
      dio: mock.dio,
      router: router,
    );
    container
        .read(captureControllerProvider.notifier)
        .addFrame(syntheticFrame(80, 60));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('capture_text_field')), '午饭');
    await tester.pump();

    await tester.tap(find.byKey(const Key('capture_submit_button')));
    await tester.pumpAndSettle();

    // A cancelled review (null result) must not throw away the capture.
    expect(router.calls, 1);
    expect(container.read(captureControllerProvider).photos, hasLength(1));
    expect(find.byKey(const Key('capture_thumb_0')), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('capture_text_field')))
          .controller!
          .text,
      '午饭',
    );
  });

  testWidgets('the default router pushes the task-19 placeholder route', (
    tester,
  ) async {
    final mock = mockDio((options) => mealCompletion(mealArguments));
    await keyStore.write(testApiKey);
    await _pumpCapture(tester, db: db, keyStore: keyStore, dio: mock.dio);

    await tester.enterText(find.byKey(const Key('capture_text_field')), '一碗面');
    await tester.pump();
    await tester.tap(find.byKey(const Key('capture_submit_button')));
    await tester.pumpAndSettle();

    expect(find.byType(MealReviewPlaceholderScreen), findsOneWidget);
  });

  testWidgets(
    'offline disables AI submit with the G7 message but keeps the screen '
    'reachable',
    (tester) async {
      final mock = mockDio((options) => mealCompletion(mealArguments));
      final ProviderContainer container = await _pumpCapture(
        tester,
        db: db,
        keyStore: keyStore,
        dio: mock.dio,
        connectivity: const <ConnectivityResult>[ConnectivityResult.none],
      );

      expect(container.read(isOfflineProvider), isTrue);
      expect(find.byKey(const Key('capture_offline_hint')), findsOneWidget);
      // The screen is reachable offline and manual entry stays on screen.
      expect(find.byKey(const Key('capture_text_field')), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('capture_text_field')),
        '离线时也能先记录',
      );
      await tester.pump();
      expect(_submitButton(tester).onPressed, isNull);

      await tester.tap(
        find.byKey(const Key('capture_submit_button')),
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();
      expect(mock.adapter.calls, 0);
    },
  );

  group('target-day indicator', () {
    /// A date-only day key in the `dayKeyOf` shape (2026-01-03, a Saturday).
    final DateTime backfillDay = DateTime.utc(2026, 1, 3);

    testWidgets('the today path shows the quiet 记录到：今天 row', (tester) async {
      await _pumpCapture(tester, db: db, keyStore: keyStore);

      expect(find.byKey(captureTargetDayKey), findsOneWidget);
      expect(find.text(S.instance.captureTargetToday), findsOneWidget);
      // Nothing to correct on the today path.
      expect(find.byKey(captureChangeToTodayKey), findsNothing);
    });

    testWidgets('a backfill entry shows the target day and 改为今天', (
      tester,
    ) async {
      await _pumpCapture(
        tester,
        db: db,
        keyStore: keyStore,
        targetDay: backfillDay,
      );

      expect(find.byKey(captureTargetDayKey), findsOneWidget);
      // 概览 date rule: a same-year date drops its year, and the weekday
      // comes from the date itself — so `1月3日` matches whatever year the
      // wall clock of this test run is in.
      expect(find.textContaining('1月3日'), findsOneWidget);
      expect(find.text(S.instance.captureChangeToToday), findsOneWidget);
    });

    testWidgets('改为今天 clears the target and keeps the typed text', (
      tester,
    ) async {
      final ProviderContainer container = await _pumpCapture(
        tester,
        db: db,
        keyStore: keyStore,
        targetDay: backfillDay,
      );
      await tester.enterText(find.byKey(const Key('capture_text_field')), '午饭');
      await tester.pump();

      await tester.tap(find.byKey(captureChangeToTodayKey));
      await tester.pump();

      expect(container.read(captureControllerProvider).targetDay, isNull);
      // The banner collapsed back into the quiet today row…
      expect(find.text(S.instance.captureTargetToday), findsOneWidget);
      expect(find.textContaining('1月3日'), findsNothing);
      // …without throwing away what the user already entered.
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('capture_text_field')))
            .controller!
            .text,
        '午饭',
      );
    });

    testWidgets('the backfill target travels with the submission', (
      tester,
    ) async {
      final RecordingReviewRouter router = RecordingReviewRouter();
      final mock = mockDio((options) => mealCompletion(mealArguments));
      await keyStore.write(testApiKey);
      await _pumpCapture(
        tester,
        db: db,
        keyStore: keyStore,
        dio: mock.dio,
        router: router,
        targetDay: backfillDay,
      );

      await tester.enterText(find.byKey(const Key('capture_text_field')), '午饭');
      await tester.pump();
      await tester.tap(find.byKey(const Key('capture_submit_button')));
      await tester.pumpAndSettle();

      expect(router.calls, 1);
      expect(router.submission!.targetDay, backfillDay);
    });

    testWidgets('改为今天 before submit submits a null target', (tester) async {
      final RecordingReviewRouter router = RecordingReviewRouter();
      final mock = mockDio((options) => mealCompletion(mealArguments));
      await keyStore.write(testApiKey);
      await _pumpCapture(
        tester,
        db: db,
        keyStore: keyStore,
        dio: mock.dio,
        router: router,
        targetDay: backfillDay,
      );

      await tester.tap(find.byKey(captureChangeToTodayKey));
      await tester.pump();
      await tester.enterText(find.byKey(const Key('capture_text_field')), '午饭');
      await tester.pump();
      await tester.tap(find.byKey(const Key('capture_submit_button')));
      await tester.pumpAndSettle();

      expect(router.calls, 1);
      expect(router.submission!.targetDay, isNull);
    });
  });

  group('no saved-food catalogue in the analysis request', () {
    /// The user message of the single captured request, as a plain string.
    String userMessageOf(MockAdapter adapter) {
      final Map<String, Object?> body =
          adapter.requests.single.data! as Map<String, Object?>;
      final List<Object?> messages = body['messages']! as List<Object?>;
      return (messages.last! as Map<String, Object?>)['content']! as String;
    }

    /// The system message of the single captured request.
    String systemMessageOf(MockAdapter adapter) {
      final Map<String, Object?> body =
          adapter.requests.single.data! as Map<String, Object?>;
      final List<Object?> messages = body['messages']! as List<Object?>;
      return (messages.first! as Map<String, Object?>)['content']! as String;
    }

    testWidgets(
      'a saved food in the library is never sent with the analysis request',
      (tester) async {
        final RecordingReviewRouter router = RecordingReviewRouter();
        final mock = mockDio((options) => mealCompletion(mealArguments));
        await keyStore.write(testApiKey);
        final ProviderContainer container = await _pumpCapture(
          tester,
          db: db,
          keyStore: keyStore,
          dio: mock.dio,
          router: router,
        );

        // Seed the library exactly the way the label-photo flow saves a food.
        await container
            .read(foodRepositoryProvider)
            .insertFood(
              const Food(
                id: 'food-milk',
                name: '光明 全脂牛奶',
                brand: '光明',
                notes: '一包 250 ml；别名：牛奶',
                source: FoodSource.label,
                kcal: 65,
                carbG: 4.8,
                proteinG: 3.3,
                fatG: 3.6,
                sodiumMg: 50,
              ),
            );

        await tester.enterText(
          find.byKey(const Key('capture_text_field')),
          '早上喝了250毫升牛奶',
        );
        await tester.pump();
        await tester.tap(find.byKey(const Key('capture_submit_button')));
        await tester.pumpAndSettle();

        expect(mock.adapter.calls, 1);
        expect(router.calls, 1);

        // The library lives in a separate link call: the analysis message
        // carries neither the catalogue block nor the naming rule.
        final String user = userMessageOf(mock.adapter);
        final String system = systemMessageOf(mock.adapter);
        expect(user, contains('早上喝了250毫升牛奶'));
        expect(user, isNot(contains('库内已存食物')));
        expect(user, isNot(contains('光明 全脂牛奶')));
        expect(user, isNot(contains('；份量：一包 250 ml')));
        expect(user, isNot(contains('；别名：牛奶')));
        expect(user, isNot(contains('钠 50 mg')));
        expect(system, isNot(contains('库内已存食物对应规则')));
        expect(system, isNot(contains('光明 全脂牛奶')));
      },
    );

    testWidgets('an empty catalogue submits with no catalogue block', (
      tester,
    ) async {
      final RecordingReviewRouter router = RecordingReviewRouter();
      final mock = mockDio((options) => mealCompletion(mealArguments));
      await keyStore.write(testApiKey);
      await _pumpCapture(
        tester,
        db: db,
        keyStore: keyStore,
        dio: mock.dio,
        router: router,
      );

      await tester.enterText(
        find.byKey(const Key('capture_text_field')),
        '两个鸡蛋一碗米饭',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('capture_submit_button')));
      await tester.pumpAndSettle();

      expect(mock.adapter.calls, 1);
      expect(router.calls, 1);
      expect(userMessageOf(mock.adapter), isNot(contains('库内已存食物（仅作命名与份量参考')));
    });

    testWidgets('a failing catalogue read never blocks the meal', (
      tester,
    ) async {
      final RecordingReviewRouter router = RecordingReviewRouter();
      final mock = mockDio((options) => mealCompletion(mealArguments));
      await keyStore.write(testApiKey);
      await _pumpCapture(
        tester,
        db: db,
        keyStore: keyStore,
        dio: mock.dio,
        router: router,
        foodRepository: ThrowingFoodRepository(),
      );

      await tester.enterText(
        find.byKey(const Key('capture_text_field')),
        '两个鸡蛋一碗米饭',
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('capture_submit_button')));
      await tester.pumpAndSettle();

      // A broken catalogue must never block or fail the meal.
      expect(mock.adapter.calls, 1);
      expect(router.calls, 1);
      expect(readCaptureOutcome(tester), CaptureOutcome.submitted);
      expect(userMessageOf(mock.adapter), isNot(contains('库内已存食物（仅作命名与份量参考')));
    });
  });

  group('voice input (task 32)', () {
    testWidgets('the voice entry opens the keyboard and explains itself', (
      tester,
    ) async {
      await _pumpCapture(tester, db: db, keyStore: keyStore);

      // The entry is an input-method helper, not an in-app recogniser: it
      // focuses the field (which opens the keyboard) and says where the IME's
      // microphone key is. No permission, no plugin, no audio handled here.
      expect(find.text(S.instance.voiceInputHint), findsOneWidget);
      await tester.tap(find.byKey(captureVoiceButtonKey));
      await tester.pumpAndSettle();

      expect(_textField(tester).focusNode!.hasFocus, isTrue);
      expect(find.text(S.instance.voiceKeyboardHint), findsOneWidget);
    });

    testWidgets('the keyboard transcript is just text: it is editable and '
        'never auto-submits', (tester) async {
      final RecordingReviewRouter router = RecordingReviewRouter();
      final mock = mockDio((options) => mealCompletion(mealArguments));
      await keyStore.write(testApiKey);
      await _pumpCapture(
        tester,
        db: db,
        keyStore: keyStore,
        dio: mock.dio,
        router: router,
      );

      // What the IME writes into the field is ordinary text.
      await tester.enterText(
        find.byKey(const Key('capture_text_field')),
        '中午吃了一碗牛肉面',
      );
      await tester.pump();
      expect(mock.adapter.calls, 0);
      expect(router.calls, 0);
      expect(_submitButton(tester).onPressed, isNotNull);

      await tester.tap(find.byKey(const Key('capture_submit_button')));
      await tester.pumpAndSettle();
      expect(router.submission!.userText, '中午吃了一碗牛肉面');
    });
  });

  group('从模版记录 entry', () {
    MealTemplate seededTemplate() => MealTemplate(
      id: 'tpl-1',
      name: '早餐标配',
      createdAt: DateTime(2026, 3, 4, 8),
      mealType: MealType.breakfast,
      items: const <MealItem>[
        MealItem(
          id: 'ti-1',
          name: '米饭',
          grams: 150,
          kcal: 174,
          carbG: 38.9,
          proteinG: 4.2,
          fatG: 0.6,
          saltG: 0.01,
          source: FoodSource.ai,
        ),
      ],
    );

    testWidgets('the picker opens, and a chosen template routes to review '
        'without any AI call', (tester) async {
      final FakeMealTemplateRepository fakeTemplates =
          FakeMealTemplateRepository();
      await fakeTemplates.saveTemplate(seededTemplate());
      final RecordingTemplateRouter templateRouter = RecordingTemplateRouter(
        saved: true,
      );
      await _pumpCapture(
        tester,
        db: db,
        keyStore: keyStore,
        extraOverrides: <Override>[
          mealTemplateRepositoryProvider.overrideWithValue(fakeTemplates),
          templateReviewRouterProvider.overrideWithValue(templateRouter.call),
        ],
      );

      // The template lane sits below the primary CTA at the bottom of the
      // capture form — off-screen on the 800x600 test viewport until scrolled.
      final Finder templateButton = find.byKey(captureTemplateButtonKey);
      await tester.ensureVisible(templateButton);
      await tester.pumpAndSettle();
      await tester.tap(templateButton);
      await tester.pumpAndSettle();

      // The picker is on stage with the seeded row.
      expect(find.byKey(const Key('template_pick_tpl-1')), findsOneWidget);

      await tester.tap(find.byKey(const Key('template_pick_tpl-1')));
      await tester.pumpAndSettle();

      expect(templateRouter.calls, 1);
      expect(templateRouter.template!.id, 'tpl-1');
      // A completed record clears the capture inputs, like the AI path.
      expect(_textField(tester).controller!.text, isEmpty);
    });

    testWidgets('a cancelled pick leaves the capture inputs untouched', (
      tester,
    ) async {
      final FakeMealTemplateRepository fakeTemplates =
          FakeMealTemplateRepository();
      await fakeTemplates.saveTemplate(seededTemplate());
      final RecordingTemplateRouter templateRouter = RecordingTemplateRouter();
      await _pumpCapture(
        tester,
        db: db,
        keyStore: keyStore,
        extraOverrides: <Override>[
          mealTemplateRepositoryProvider.overrideWithValue(fakeTemplates),
          templateReviewRouterProvider.overrideWithValue(templateRouter.call),
        ],
      );

      await tester.enterText(
        find.byKey(const Key('capture_text_field')),
        '半碗面',
      );
      await tester.pump();
      final Finder templateButton = find.byKey(captureTemplateButtonKey);
      await tester.ensureVisible(templateButton);
      await tester.pumpAndSettle();
      await tester.tap(templateButton);
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(templateRouter.calls, 0);
      expect(_textField(tester).controller!.text, '半碗面');
    });

    testWidgets('an empty catalogue shows the pointing empty state', (
      tester,
    ) async {
      await _pumpCapture(
        tester,
        db: db,
        keyStore: keyStore,
        extraOverrides: <Override>[
          mealTemplateRepositoryProvider.overrideWithValue(
            FakeMealTemplateRepository(),
          ),
        ],
      );

      final Finder templateButton = find.byKey(captureTemplateButtonKey);
      await tester.ensureVisible(templateButton);
      await tester.pumpAndSettle();
      await tester.tap(templateButton);
      await tester.pumpAndSettle();

      expect(find.byKey(templatePickerEmptyKey), findsOneWidget);
    });
  });
}

/// Reads the capture outcome from the on-screen provider container.
CaptureOutcome readCaptureOutcome(WidgetTester tester) {
  final ProviderContainer container = ProviderScope.containerOf(
    tester.element(find.byType(MealCaptureScreen)),
  );
  return container.read(captureControllerProvider).outcome;
}
