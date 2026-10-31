/// Shared harness for the task-32 end-to-end day -> week integration test.
///
/// This boots the **real** feature screens (`MealCaptureScreen` ->
/// `MealReviewScreen`, `LabelCaptureScreen`, `ExerciseEntryScreen`,
/// `MealDetailScreen`, `DailySummaryView`, `WeeklySummaryView`) over the
/// **real** production provider graph, with only the three unavoidable edges
/// faked:
///
/// * the drift database is the in-memory harness (`test/data/db/_test_db.dart`)
///   so every asserted number is a **persisted DB value**, not a fake map;;
/// * the Dio HTTP client is replaced with a [MockAdapter] that serves the
///   recorded task-16 fixtures — **no socket is ever opened**;
/// * `image_picker` / `flutter_secure_storage` / `connectivity_plus` platform
///   channels are replaced with in-memory seams (there are none under
///   `flutter test`).
///
/// ## The task-7 vector, decomposed
///
/// The day total must equal the hand-computed task-7 vector, now in whole kcal
/// (the old fractional vector rounded once, half away from zero):
/// `intake 1936` (1935.75), `exercise 257` (257.25), `budget 2236` (2235.75),
/// `deficit 300`. The two meals are chosen so the integer arithmetic is
/// **exact** (no tolerance-based assertion):
///
/// * label food = the recorded `label_photo_response.json` fixture
///   (`energy_kj 221` -> `kJToKcal(221)` = 53 kcal / 100 g), logged at 150 g
///   -> `roundKcal(53 * 150 / 100)` = 80 kcal;
/// * photo meal kcal = `1936 - labelMealKcal` = 1856 (an integer the AI item
///   carries verbatim, so the rollup's `photoKcal + labelKcal` is exactly 1936).
///
/// `tool/scratch` verified all of the above before this harness was written.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:clock/clock.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:caldoo/core/providers/app_providers.dart';
import 'package:caldoo/core/time/date_windows.dart';
import 'package:caldoo/core/time/day_tick_provider.dart';
import 'package:caldoo/core/units/nutrition_units.dart';
import 'package:caldoo/data/db/app_database.dart';
import 'package:caldoo/domain/models/models.dart';
import 'package:caldoo/features/dashboard/daily/daily_summary_providers.dart';
import 'package:caldoo/features/dashboard/weekly/weekly_summary_providers.dart';
import 'package:caldoo/features/exercise/exercise_providers.dart';
import 'package:caldoo/features/meals/capture/meal_capture_controller.dart';
import 'package:caldoo/features/meals/label/label_capture_controller.dart';
import 'package:caldoo/features/meals/review/meal_review_screen.dart';
import 'package:caldoo/features/meals/summary/meal_summary_providers.dart';
import 'package:caldoo/features/nav/review_args.dart';
import 'package:caldoo/features/settings/settings_providers.dart';

import '../data/db/_test_db.dart';
import '../features/settings/_fakes.dart';

/// The task-7 profile: male 175cm / 70kg, born 1995-10-22 (age 30 on the
/// pinned `now`), with a pinned BMR override of **1979** kcal (the old 1978.5
/// rounded to whole kcal; the base budget, exercise is added on top).
final UserProfile integrationProfile = UserProfile(
  sex: Sex.male,
  birthDate: DateTime.utc(1995, 10, 22),
  heightCm: 175,
  weightKg: 70,
  bmrKcalOverride: 1979,
);

/// The recorded label fixture's printed energy, kJ / 100 g.
const double labelEnergyKj = 221;

/// The label meal's consumed grams.
const double labelMealGrams = 150;

/// The label food's canonical per-100 g kcal: `kJToKcal(221)` =
/// `roundKcal(221 / 4.184)` = **53**.
final int labelFoodKcal = kJToKcal(labelEnergyKj);

/// The label meal's kcal at [labelMealGrams] — the app computes exactly this
/// (`resolveNutrients` rounds `food.kcal * grams / 100` once): `roundKcal(53 *
/// 150 / 100)` = `roundKcal(79.5)` = **80**.
final int labelMealKcal = roundKcal(labelFoodKcal * labelMealGrams / 100);

/// The photo meal's kcal, chosen so `photo + label == the task-7 intake 1936`
/// (the old 1935.75 rounded half away from zero). Both meal values are ints.
final int photoMealKcal = expectedIntakeKcal - labelMealKcal;

// --- The hand-computed task-7 vector (whole kcal ints). ---

/// Day intake: the old 1935.75 rounded half away from zero -> **1936**.
const int expectedIntakeKcal = 1936;

/// Exercise-free baseline: the pinned BMR override 1978.5 rounded -> **1979**.
const int expectedBaseBudgetKcal = 1979;

/// Exercise add-back: 30 min 跑步 @ 8 MET, 70 kg -> `(8-1)*3.5*70/200*30` =
/// 257.25 rounded -> **257**.
const int expectedExerciseKcal = 257;

/// `baseBudget + exercise` = **2236**.
const int expectedBudgetKcal = 2236;

/// `budget - intake` = **300**.
const int expectedDeficitKcal = 300;

// Deterministic ids/names (the id seams are overridden).
const String labelFoodId = 'label-food-1';
const String labelFoodName = '测试标签食品';
const String photoMealId = 'photo-meal-1';
const String labelMealId = 'label-meal-1';
const String photoItemId = 'photo-item-1';
const String blankItemId = 'blank-0';

/// The recorded label fixture as the AI provider would return it.
String labelFixtureBody() =>
    File('test/fixtures/ai/label_photo_response.json').readAsStringSync();

/// A real meal photo so the bounded image codec has something to decode.
Future<Uint8List?> mealPhotoBytes() async =>
    File('test/fixtures/ai/samples/meal_photo.jpg').readAsBytesSync();

/// A real nutrition-label photo for the label flow.
Future<Uint8List?> labelPhotoBytes() async =>
    File('test/fixtures/ai/samples/nutrition_label.jpg').readAsBytesSync();

/// One end-to-end environment: in-memory DB + mocked AI + fake platforms.
class IntegrationEnv {
  /// Builds the DB, the mocked Dio and the provider container.
  IntegrationEnv() {
    db = testDb();
    keyStore = InMemorySecureKeyStore()..value = testApiKey;
    final DateTime pinned = DateTime.now();
    now = pinned;
    offset = LocalOffset(pinned.timeZoneOffset.inMinutes);
    final ({Dio dio, MockAdapter adapter}) mock = mockDio(_respond);
    dio = mock.dio;
    adapter = mock.adapter;

    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        secureKeyStoreProvider.overrideWithValue(keyStore),
        dioProvider.overrideWithValue(dio),
        connectivityProvider.overrideWith(
          (Ref ref) => Stream<List<ConnectivityResult>>.value(
            const <ConnectivityResult>[ConnectivityResult.wifi],
          ),
        ),
        cameraPhotoSourceProvider.overrideWithValue(mealPhotoBytes),
        galleryPhotoSourceProvider.overrideWithValue(mealPhotoBytes),
        labelPhotoSourceProvider.overrideWithValue(
          (LabelPhotoLane lane) => labelPhotoBytes(),
        ),
        // Pin every time seam to one instant so the day/week windows are
        // deterministic; the exercise burn is keyed to the same local day.
        dashboardClockProvider.overrideWithValue(Clock.fixed(pinned)),
        summaryClockProvider.overrideWithValue(Clock.fixed(pinned)),
        weeklyClockProvider.overrideWithValue(Clock.fixed(pinned)),
        exerciseClockProvider.overrideWithValue(Clock.fixed(pinned)),
        dashboardOffsetProvider.overrideWithValue(offset),
        localOffsetProvider.overrideWithValue(offset),
        weeklyOffsetProvider.overrideWithValue(offset),
        exerciseOffsetProvider.overrideWithValue(offset),
        // The current-day seams follow the day-tick signal; this environment
        // pins the day instead, so the tick stays quiet (the real one needs a
        // WidgetsBinding and a Timer, neither of which belongs here).
        dayTickProvider.overrideWith((ref) => const Stream<int>.empty()),
        reviewIdGeneratorProvider.overrideWithValue(() => blankItemId),
        labelIdGeneratorProvider.overrideWithValue(() => labelFoodId),
        reviewRouterProvider.overrideWithValue(_pushReview),
      ],
    );
  }

  /// The in-memory drift database every assertion reads from.
  late final AppDatabase db;

  /// The secure-storage fake holding the (non-secret-shaped) test key.
  late final InMemorySecureKeyStore keyStore;

  /// The mocked, socket-free HTTP client.
  late final Dio dio;

  /// The recording mock adapter (call count + captured requests).
  late final MockAdapter adapter;

  /// The single provider container shared by every pumped screen.
  late final ProviderContainer container;

  /// The pinned "now" used for meal timestamps and the time seams.
  late final DateTime now;

  /// The pinned local offset (machine offset, so it matches `DateTime.now()`).
  late final LocalOffset offset;

  /// The date-only key of the pinned local day (the exercise-burn row key).
  DateTime get todayKey => dayKeyOf(now, offset);

  /// When true, `emit_meal_items` answers with a malformed completion (an AI
  /// parse failure) instead of the fixture meal.
  bool mealFails = false;

  /// True when the AI transport is the in-process mock adapter (never a real
  /// socket): the no-live-network guarantee, asserted by the tests.
  bool get usesMockTransport => dio.httpClientAdapter is MockAdapter;

  /// Seeds the task-7 profile through the real Drift repository.
  Future<void> seedProfile() =>
      container.read(profileRepositoryProvider).saveProfile(integrationProfile);

  /// The owning meal for the label-meal review save, pinned to **local noon of
  /// [now]'s day**.
  ///
  /// Not `now + 1 hour`: a late-evening run would move the label meal past
  /// midnight, so it would fall outside the day window and the flow would fail
  /// for a wall-clock reason rather than an app one.
  Meal labelMeal() => Meal(
    id: labelMealId,
    timestamp: DateTime(now.year, now.month, now.day, 12),
    mealType: MealType.dinner,
  );

  /// Pumps [child] inside the shared container on a tall surface.
  ///
  /// Any SnackBar left over from the previous step is cleared: the steps share
  /// one MaterialApp element, so a SnackBar shown by the review save would
  /// otherwise stay on screen and overlay the next screen's bottom action
  /// (e.g. the label confirm's save button) — a test-harness artifact, not an
  /// app behavior under test.
  Future<void> pump(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: child),
      ),
    );
    final Finder messenger = find.byType(ScaffoldMessenger);
    if (messenger.evaluate().isNotEmpty) {
      tester.state<ScaffoldMessengerState>(messenger.first).clearSnackBars();
    }
    await tester.pumpAndSettle();
  }

  /// Closes the DB and the container.
  Future<void> dispose() async {
    container.dispose();
    await db.close();
  }

  // ---------------------------------------------------------------------
  // Mock AI transport: no socket, fixtures only.
  // ---------------------------------------------------------------------

  ResponseBody _respond(RequestOptions options) {
    final Map<String, Object?> body = (options.data! as Map<Object?, Object?>)
        .cast<String, Object?>();
    final String tool = _toolName(body);
    if (tool == 'emit_nutrition_labels') {
      return _jsonBody(labelFixtureBody(), 200);
    }
    if (mealFails) {
      // A 200 chat completion with no tool call: a genuine parse failure.
      return _jsonBody(
        jsonEncode(<String, Object?>{
          'id': 'chatcmpl-broken',
          'object': 'chat.completion',
          'created': 0,
          'model': 'test-model',
          'choices': <Object?>[
            <String, Object?>{
              'index': 0,
              'message': <String, Object?>{
                'role': 'assistant',
                'content': '抱歉，我无法识别这张图片',
              },
            },
          ],
        }),
        200,
      );
    }
    return _jsonBody(_mealCompletion(), 200);
  }

  /// The recorded-shape meal completion whose single item carries
  /// [photoMealKcal].
  String _mealCompletion() {
    final String arguments = jsonEncode(<String, Object?>{
      'items': <Object?>[
        <String, Object?>{
          'name': '宫保鸡丁',
          'grams': 150,
          'kcal': photoMealKcal,
          'carb_g': 30.0,
          'protein_g': 25.0,
          'fat_g': 35.0,
          'salt_g': 2.0,
          'confidence': 0.9,
        },
      ],
    });
    return jsonEncode(<String, Object?>{
      'id': 'chatcmpl-itest',
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
                'id': 'call_itest',
                'type': 'function',
                'function': <String, Object?>{
                  'name': 'emit_meal_items',
                  'arguments': arguments,
                },
              },
            ],
          },
        },
      ],
    });
  }

  static String _toolName(Map<String, Object?> body) {
    final Object? tools = body['tools'];
    if (tools is List<Object?> && tools.isNotEmpty) {
      final Object? first = tools.first;
      if (first is Map<Object?, Object?>) {
        final Object? function = first['function'];
        if (function is Map<Object?, Object?> && function['name'] is String) {
          return function['name']! as String;
        }
      }
    }
    return '';
  }

  static ResponseBody _jsonBody(String body, int status) =>
      ResponseBody.fromString(
        body,
        status,
        headers: <String, List<String>>{
          Headers.contentTypeHeader: <String>[Headers.jsonContentType],
        },
      );

  /// Pushes the **real** review screen for a validated capture submission. This
  /// is the task-27 `/today/review` wiring, minus go_router.
  Future<bool?> _pushReview(
    BuildContext context,
    CaptureSubmission submission,
  ) {
    return Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        settings: const RouteSettings(name: reviewRoutePath),
        builder: (BuildContext _) => MealReviewScreen(
          draft: draftFromAnalysis(
            submission.draft,
            idGenerator: () => photoItemId,
          ),
          meal: Meal(id: photoMealId, timestamp: now, mealType: MealType.lunch),
          photos: submission.photos,
          userText: submission.userText,
        ),
      ),
    );
  }
}

/// Reads a keyed `Text`'s data (the widget assertions' one-liner).
String textOf(WidgetTester tester, Key key) =>
    tester.widget<Text>(find.byKey(key)).data!;
