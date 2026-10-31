/// End-to-end wiring: capture → the real `/today/review` route → AI correction.
///
/// The capture widget tests inject a recording router, and the nav/golden tests
/// build [ReviewArgs] by hand, so neither proves that `app_router.dart` really
/// forwards the capture inputs (`photos` / `userText`) into the review screen.
/// That forwarding is what enables the AI-correction panel in production; this
/// test drives the real shell, the real router and the real reviser.
///
/// No socket: the AI call is served by the settings `MockAdapter`.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'package:caldoo/ai/schemas/label_link.dart'
    show LabelLinkResult, LabelMatch;
import 'package:caldoo/data/db/app_database.dart';
import 'package:caldoo/domain/models/models.dart'
    show Food, FoodSource, MealItem;
import 'package:caldoo/features/meals/capture/meal_capture_controller.dart'
    show captureControllerProvider;
import 'package:caldoo/features/meals/capture/meal_capture_screen.dart';
import 'package:caldoo/features/meals/review/label_linker.dart'
    show labelLinkerProvider;
import 'package:caldoo/features/meals/review/meal_review_screen.dart';
import 'package:caldoo/features/meals/saved_foods/label_suggestion_banner.dart';

import '../../data/db/_test_db.dart';
import '../../data/repositories/fake_repositories.dart' show FakeFoodRepository;
import '../meals/capture/_fakes.dart'
    show mealArguments, mealCompletion, syntheticFrame;
import '../settings/_fakes.dart';
import '_harness.dart';

/// A label-link fake: records calls and never matches.
///
/// The photo-capture test only needs to prove the linker is **never** called, so
/// it must not depend on a real AI request: with the gate broken, a failed
/// request would leave a pending future behind and muddy the teardown.
class _RecordingLinker {
  int calls = 0;

  Future<LabelLinkResult> call({
    required List<MealItem> items,
    required List<Food> foods,
    required String userText,
  }) async {
    calls++;
    return const LabelLinkResult(matches: <LabelMatch>[]);
  }
}

void main() {
  late AppDatabase db;

  setUp(() {
    db = testDb();
  });

  tearDown(() async {
    await db.close();
  });

  testWidgets('the real capture route forwards photos + text and the review '
      'screen can re-estimate the meal', (WidgetTester tester) async {
    final mock = mockDio((options) => mealCompletion(mealArguments));
    final InMemorySecureKeyStore keyStore = InMemorySecureKeyStore();
    await keyStore.write(testApiKey);
    final NavTestEnv env = NavTestEnv();
    addTearDown(env.dispose);
    await env.pump(tester, dio: mock.dio, keyStore: keyStore, database: db);

    // 今日 quick-add 记录一餐 → capture, through the real shell navigation.
    await openMealCaptureFromToday(tester);

    // Add a photo through the capture controller's bounding seam (the picker
    // plugin is not available under `flutter test`), then submit with text.
    final ProviderContainer captureContainer = ProviderScope.containerOf(
      tester.element(find.byType(MealCaptureScreen)),
    );
    captureContainer
        .read(captureControllerProvider.notifier)
        .addFrame(syntheticFrame(80, 60));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('capture_text_field')), '午饭');
    await tester.pump();
    await tester.tap(find.byKey(const Key('capture_submit_button')));
    await tester.pumpAndSettle();

    // The real review route got a payload carrying the capture inputs: the
    // panel only exists when photos/userText actually arrived.
    expect(find.byType(MealReviewScreen), findsOneWidget);
    expect(find.byKey(reviewRevisionCardKey), findsOneWidget);

    // Tell the AI what was wrong and let it re-estimate end-to-end.
    await tester.enterText(find.byKey(reviewCorrectionFieldKey), '米饭是两碗');
    await tester.pump();
    await tester.ensureVisible(find.byKey(reviewReviseButtonKey));
    await tester.pump();
    await tester.tap(find.byKey(reviewReviseButtonKey));
    await tester.pumpAndSettle();

    expect(mock.adapter.calls, 2);
    final String revisionBody = jsonEncode(mock.adapter.requests.last.data);
    expect(revisionBody, contains('米饭是两碗'));
    expect(revisionBody, contains('用户的原始描述'));
    expect(revisionBody, contains('午饭'));
    // The bounded photo was resent with the correction.
    expect(revisionBody, contains('image_url'));
    expect(find.byKey(reviewReviseErrorKey), findsNothing);

    // Let the revision-success snackbar auto-dismiss: it overlays the bottom
    // of the screen, where the save button lives.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    // Save the revised meal: the record is complete, so the capture screen it
    // returns to must not still show the old photo/text.
    await tester.ensureVisible(find.byKey(reviewSaveButtonKey));
    await tester.pump();
    await tester.tap(find.byKey(reviewSaveButtonKey));
    await tester.pumpAndSettle();

    expect(find.byType(MealCaptureScreen), findsOneWidget);
    expect(find.byKey(const Key('capture_thumb_0')), findsNothing);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('capture_text_field')))
          .controller!
          .text,
      isEmpty,
    );
  });

  testWidgets('a photo-only capture stays prediction-only on the real route', (
    WidgetTester tester,
  ) async {
    final mock = mockDio((options) => mealCompletion(mealArguments));
    final InMemorySecureKeyStore keyStore = InMemorySecureKeyStore();
    await keyStore.write(testApiKey);
    // A non-empty library whose food name matches the AI item exactly: any
    // matching attempt would call the AI a second time and surface a banner.
    final FakeFoodRepository foods = FakeFoodRepository();
    await foods.insertFood(
      const Food(
        id: 'wiring-rice',
        name: '米饭',
        source: FoodSource.label,
        kcal: 150,
        carbG: 30,
        proteinG: 3,
        fatG: 0.5,
        sodiumMg: 400,
      ),
    );
    final _RecordingLinker linker = _RecordingLinker();
    final NavTestEnv env = NavTestEnv();
    addTearDown(env.dispose);
    await env.pump(
      tester,
      dio: mock.dio,
      keyStore: keyStore,
      database: db,
      foodRepository: foods,
      extraOverrides: <Override>[
        labelLinkerProvider.overrideWithValue(linker.call),
      ],
    );

    await openMealCaptureFromToday(tester);

    // Photo only, no text: the revision panel exists only when the photos
    // actually reached the review route, so it proves the production wiring.
    final ProviderContainer captureContainer = ProviderScope.containerOf(
      tester.element(find.byType(MealCaptureScreen)),
    );
    captureContainer
        .read(captureControllerProvider.notifier)
        .addFrame(syntheticFrame(80, 60));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('capture_submit_button')));
    await tester.pumpAndSettle();

    expect(find.byType(MealReviewScreen), findsOneWidget);
    expect(find.byKey(reviewRevisionCardKey), findsOneWidget);

    // Prediction-only: exactly one AI call (the analysis) and no link call at
    // all — the non-empty library would have produced one on any matching path.
    expect(mock.adapter.calls, 1);
    expect(linker.calls, 0);
    expect(find.byKey(LabelSuggestionBanner.containerKey), findsNothing);
  });
}
