/// Task 30 — app-wide offline / error / empty-state hardening.
///
/// MANUAL-QA CHANNEL: each test prints one `TASK30_OFFLINE_QA` line with the
/// observed state, so the widget-test output itself is the evidence that
/// offline disables AI while the manual paths keep working.
///
/// Covers the plan's acceptance criteria directly:
/// * PROACTIVE: offline (`connectivity == [none]`) disables the AI action on
///   every AI surface (capture, label, review) and shows the draft-G7 notice;
/// * REACTIVE: a call that still fails with `AiError.Network` surfaces an error
///   message + a retry affordance (no crash);
/// * offline does NOT block manual logging, manual label entry, saving or
///   navigation: a manual meal saves and the day totals update.
///
/// No test opens a socket — the AI client is served by a mocked Dio adapter.
library;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:caldoo/core/providers/app_providers.dart';
import 'package:caldoo/data/db/app_database.dart';
import 'package:caldoo/domain/models/models.dart';
import 'package:caldoo/features/dashboard/daily/daily_summary_providers.dart';
import 'package:caldoo/features/dashboard/daily/daily_summary_view.dart';
import 'package:caldoo/features/dashboard/weekly/weekly_summary_view.dart';
import 'package:caldoo/features/meals/capture/meal_capture_controller.dart';
import 'package:caldoo/features/meals/capture/meal_capture_screen.dart';
import 'package:caldoo/features/meals/label/label_capture_controller.dart';
import 'package:caldoo/features/meals/label/label_capture_screen.dart';
import 'package:caldoo/features/meals/review/meal_review_screen.dart';
import 'package:caldoo/features/meals/saved_foods/food_library_screen.dart';
import 'package:caldoo/features/nav/app_router.dart';
import 'package:caldoo/features/nav/nav_shell.dart';
import 'package:caldoo/features/nav/profile_tab_screen.dart';
import 'package:caldoo/features/nav/review_args.dart';
import 'package:caldoo/features/nav/today_screen.dart';
import 'package:caldoo/features/offline/offline_ui.dart';
import 'package:caldoo/features/settings/settings_providers.dart'
    show appDatabaseProvider, dioProvider, secureKeyStoreProvider;

import '../../data/db/_test_db.dart';
import '../../data/repositories/fake_repositories.dart';
import '../dashboard/daily/_fixtures.dart';
import '../meals/capture/_fakes.dart';
import '../nav/_harness.dart';
import '../settings/_fakes.dart';

/// An offline transport, as `connectivity_plus` reports it.
const List<ConnectivityResult> _offline = <ConnectivityResult>[
  ConnectivityResult.none,
];

/// Only the on-screen instance of [key] (other `IndexedStack` branches stay
/// mounted but are not hit-testable).
Finder _visible(Key key) => find.byKey(key).hitTestable();

String _textOf(WidgetTester tester, Key key) =>
    tester.widget<Text>(find.byKey(key)).data!;

void main() {
  group('capture (AI meal analysis)', () {
    late AppDatabase db;
    late InMemorySecureKeyStore keyStore;

    setUp(() {
      db = testDb();
      keyStore = InMemorySecureKeyStore();
    });

    tearDown(() async {
      await db.close();
    });

    Future<ProviderContainer> pumpCapture(
      WidgetTester tester, {
      required List<ConnectivityResult> connectivity,
      Dio? dio,
      RecordingReviewRouter? router,
    }) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            secureKeyStoreProvider.overrideWithValue(keyStore),
            if (dio != null) dioProvider.overrideWithValue(dio),
            connectivityProvider.overrideWith(
              (ref) => Stream<List<ConnectivityResult>>.value(connectivity),
            ),
            if (router != null)
              reviewRouterProvider.overrideWithValue(router.call),
          ],
          child: const MaterialApp(home: MealCaptureScreen()),
        ),
      );
      await tester.pumpAndSettle();
      return ProviderScope.containerOf(
        tester.element(find.byType(MealCaptureScreen)),
      );
    }

    testWidgets(
      'offline: AI submit is disabled with the G7 notice, the screen stays '
      'reachable and no request is sent',
      (WidgetTester tester) async {
        final mock = mockDio((options) => mealCompletion(mealArguments));
        final ProviderContainer container = await pumpCapture(
          tester,
          connectivity: _offline,
          dio: mock.dio,
        );

        expect(container.read(isOfflineProvider), isTrue);
        expect(find.byKey(captureOfflineHintKey), findsOneWidget);
        expect(_textOf(tester, captureOfflineHintKey), aiUnavailableMessage);
        // Manual entry stays on screen and navigation still works.
        expect(find.byKey(const Key('capture_text_field')), findsOneWidget);

        await tester.enterText(
          find.byKey(const Key('capture_text_field')),
          '离线时也能先记录',
        );
        await tester.pump();
        expect(
          tester
              .widget<FilledButton>(
                find.byKey(const Key('capture_submit_button')),
              )
              .onPressed,
          isNull,
        );
        await tester.tap(
          find.byKey(const Key('capture_submit_button')),
          warnIfMissed: false,
        );
        await tester.pumpAndSettle();
        expect(mock.adapter.calls, 0);

        debugPrint(
          'TASK30_OFFLINE_QA capture offline=true ai_disabled=true '
          'g7_notice="$aiUnavailableMessage" clientCalls=${mock.adapter.calls} '
          'manual_screen_reachable=true -> PASS',
        );
      },
    );

    testWidgets('reactive: a still-failing call shows an error + retry, and retry '
        'succeeds without a crash', (WidgetTester tester) async {
      await keyStore.write(testApiKey);
      bool fail = true;
      final mock = mockDio((RequestOptions options) {
        if (fail) {
          throw DioException(
            requestOptions: options,
            type: DioExceptionType.connectionError,
          );
        }
        return mealCompletion(mealArguments);
      });
      final RecordingReviewRouter router = RecordingReviewRouter();
      await pumpCapture(
        tester,
        connectivity: const <ConnectivityResult>[ConnectivityResult.wifi],
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

      // One automatic retry for a transport failure (the capture analysis
      // opts into `retryNetworkErrors`), then the normal error path.
      expect(mock.adapter.calls, 2);
      expect(find.byKey(captureErrorKey), findsOneWidget);
      expect(find.textContaining('网络不可用'), findsOneWidget);
      expect(find.textContaining('手动录入'), findsOneWidget);
      expect(find.byKey(captureRetryButtonKey), findsOneWidget);
      expect(router.calls, 0);

      // Retry succeeds; the failed call never blocked the manual/label path.
      fail = false;
      await tester.tap(find.byKey(captureRetryButtonKey));
      await tester.pumpAndSettle();
      // Two attempts on the failed submit + one successful retry.
      expect(mock.adapter.calls, 3);
      expect(router.calls, 1);
      expect(find.byKey(captureErrorKey), findsNothing);

      debugPrint(
        'TASK30_OFFLINE_QA capture reactive=AiError.Network '
        'error_shown=true retry_action=true retry_calls=${mock.adapter.calls} '
        'routed=${router.calls} -> PASS',
      );
    });
  });

  group('label (AI nutrition-label parse)', () {
    testWidgets(
      'offline: parse is disabled with the G7 notice, and manual label entry '
      'still saves a food',
      (WidgetTester tester) async {
        final FakeFoodRepository foods = FakeFoodRepository();
        addTearDown(foods.dispose);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              connectivityProvider.overrideWith(
                (ref) => Stream<List<ConnectivityResult>>.value(_offline),
              ),
              foodRepositoryProvider.overrideWithValue(foods),
              labelIdGeneratorProvider.overrideWithValue(() => 'offline-label'),
              // A real pickable photo so "parse" would be enabled online; the
              // disabled assertion below then genuinely tests the offline gate.
              labelPhotoSourceProvider.overrideWithValue(
                (LabelPhotoLane lane) async =>
                    jpegBytes(syntheticFrame(20, 20)),
              ),
            ],
            child: const MaterialApp(home: LabelCaptureScreen()),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(labelOfflineHintKey), findsOneWidget);

        await tester.tap(find.byKey(const Key('label_pick_button')));
        await tester.pumpAndSettle();
        // A photo is picked, yet the AI parse stays disabled offline.
        expect(
          tester
              .widget<FilledButton>(find.byKey(const Key('label_parse_button')))
              .onPressed,
          isNull,
        );
        // Manual entry is available offline.
        expect(find.byKey(labelManualEntryButtonKey), findsOneWidget);

        await tester.ensureVisible(find.byKey(labelManualEntryButtonKey));
        await tester.tap(find.byKey(labelManualEntryButtonKey));
        await tester.pumpAndSettle();

        expect(find.byKey(labelNameFieldKey(0)), findsOneWidget);
        await tester.enterText(find.byKey(labelNameFieldKey(0)), '离线手输食品');
        await tester.pump();
        await tester.ensureVisible(find.byKey(const Key('label_save_button')));
        await tester.tap(find.byKey(const Key('label_save_button')));
        await tester.pumpAndSettle();

        final Food? saved = await foods.getFood('offline-label');
        expect(saved, isNotNull);
        expect(saved!.name, '离线手输食品');

        debugPrint(
          'TASK30_OFFLINE_QA label offline=true ai_parse_disabled=true '
          'g7_notice=true manual_entry_saved=${saved.id} -> PASS',
        );
      },
    );
  });

  group('review (manual save)', () {
    testWidgets(
      'offline: the notice is shown, and a manual meal still saves so the day '
      'total updates',
      (WidgetTester tester) async {
        final FakeMealRepository meals = FakeMealRepository();
        final FakeFoodRepository foods = FakeFoodRepository();
        addTearDown(meals.dispose);
        addTearDown(foods.dispose);

        final Meal meal = Meal(
          id: 'offline-meal',
          timestamp: dashboardNow,
          mealType: MealType.lunch,
        );
        const MealItem item = MealItem(
          id: 'offline-item',
          name: '手动米饭',
          grams: 150,
          kcal: 200,
          carbG: 40,
          proteinG: 4,
          fatG: 1,
          saltG: 0.2,
          source: FoodSource.manual,
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              mealRepositoryProvider.overrideWithValue(meals),
              foodRepositoryProvider.overrideWithValue(foods),
              connectivityProvider.overrideWith(
                (ref) => Stream<List<ConnectivityResult>>.value(_offline),
              ),
              dashboardClockProvider.overrideWithValue(dashboardClock()),
              dashboardOffsetProvider.overrideWithValue(dashboardOffset),
              reviewIdGeneratorProvider.overrideWithValue(() => 'blank-0'),
            ],
            child: MaterialApp(
              home: MealReviewScreen(
                draft: const AiMealDraft(items: <MealItem>[item]),
                meal: meal,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final ProviderContainer container = ProviderScope.containerOf(
          tester.element(find.byType(MealReviewScreen)),
        );

        expect(container.read(isOfflineProvider), isTrue);
        expect(find.byKey(reviewOfflineHintKey), findsOneWidget);

        await tester.ensureVisible(find.byKey(reviewSaveButtonKey));
        await tester.tap(find.byKey(reviewSaveButtonKey));
        await tester.pumpAndSettle();

        // The manual meal is persisted and the save flow completed (the day
        // total update itself is asserted end-to-end in the nav test below).
        expect(find.text('已保存'), findsOneWidget);
        final stored = await meals.getMealsWithItemsInRange(
          startInclusive: dashboardNow.subtract(const Duration(hours: 1)),
          endExclusive: dashboardNow.add(const Duration(hours: 1)),
        );
        expect(stored, hasLength(1));
        expect(stored.single.items.single.kcal, 200);

        debugPrint(
          'TASK30_OFFLINE_QA review offline=true g7_notice=true '
          'manual_save_ok=true persisted_kcal='
          '${stored.single.items.single.kcal} -> PASS',
        );
      },
    );
  });

  group('navigation + today', () {
    testWidgets('the whole app navigates and logs offline', (
      WidgetTester tester,
    ) async {
      final NavTestEnv env = NavTestEnv();
      addTearDown(env.dispose);
      final FakeFoodRepository foods = FakeFoodRepository();
      addTearDown(foods.dispose);
      await env.pump(tester, connectivity: _offline, foodRepository: foods);

      expect(_visible(todayScreenKey), findsOneWidget);
      // The Today empty state renders offline (no crash, no spinner). The
      // restyled dashboard hero is taller than the 800x600 test viewport, so
      // bring the empty state into view before asserting it. The page's
      // vertical list now lives inside the horizontal history pager, so the
      // default "first Scrollable" would be the pager: target the vertical
      // list explicitly.
      final Finder todayVerticalList = find
          .byWidgetPredicate(
            (Widget widget) =>
                widget is Scrollable &&
                widget.axisDirection == AxisDirection.down,
          )
          .first;
      await tester.scrollUntilVisible(
        find.byKey(todayMealsEmptyKey),
        120,
        scrollable: todayVerticalList,
      );
      await tester.pumpAndSettle();
      expect(_visible(todayMealsEmptyKey), findsOneWidget);

      // The second tab is the 食物库 now: its live catalogue renders offline
      // too (the empty fake repository shows the add-food empty state).
      await tester.tap(find.byKey(navFoodsKey));
      await tester.pumpAndSettle();
      expect(_visible(foodLibraryScreenKey), findsOneWidget);
      expect(_visible(foodLibraryEmptyAddButtonKey), findsOneWidget);
      // The 汇总 tab is merged into 今日: the week dashboard is one of the
      // merged screen's views and still renders offline.
      await tester.tap(find.byKey(navTodayKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(todayViewWeekKey));
      await tester.pumpAndSettle();
      // No meal has been logged yet in this test, so the week dashboard is
      // the task-26 empty state — proof the merged view rendered offline.
      expect(_visible(weeklyEmptyStateKey), findsOneWidget);
      // Back to the day view: the rest of this test asserts today's numbers.
      await tester.tap(find.byKey(todayViewDayKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(navProfileKey));
      await tester.pumpAndSettle();
      expect(_visible(profileTabScreenKey), findsOneWidget);
      await tester.tap(find.byKey(navTodayKey));
      await tester.pumpAndSettle();
      expect(_visible(todayScreenKey), findsOneWidget);

      // 今日's quick-add still reaches the capture screen offline, where the
      // G7 notice replaces a hard block.
      await openMealCaptureFromToday(tester);
      expect(_visible(captureOfflineHintKey), findsOneWidget);
      // The capture screen watches connectivity, so the offline state is live.
      expect(env.container.read(isOfflineProvider), isTrue);

      // End-to-end manual meal while offline: edit the review draft (no AI
      // call) and save it through the real router, then watch Today update.
      final GoRouter router = env.container.read(appRouterProvider);
      router.go(
        '/today/review',
        extra: ReviewArgs(
          draft: const AiMealDraft(
            items: <MealItem>[
              MealItem(
                id: 'offline-item',
                name: '离线手动米饭',
                grams: 150,
                kcal: 321,
                carbG: 50,
                proteinG: 5,
                fatG: 2,
                saltG: 0.3,
                source: FoodSource.manual,
              ),
            ],
          ),
          meal: Meal(
            id: 'offline-meal',
            timestamp: dashboardNow,
            mealType: MealType.lunch,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(MealReviewScreen).hitTestable(), findsOneWidget);
      expect(find.byKey(reviewOfflineHintKey).hitTestable(), findsOneWidget);
      await tester.ensureVisible(find.byKey(reviewSaveButtonKey));
      await tester.tap(find.byKey(reviewSaveButtonKey));
      await tester.pumpAndSettle();

      router.go('/today');
      await tester.pumpAndSettle();

      // The day page is still scrolled at the quick-add row it was left on;
      // the dashboard hero (which owns the intake total) must be on stage.
      await tester.scrollUntilVisible(
        find.byKey(dailyIntakeKcalKey),
        -120,
        scrollable: todayVerticalList,
      );
      await tester.pumpAndSettle();
      expect(_textOf(tester, dailyIntakeKcalKey), '321');

      debugPrint(
        'TASK30_OFFLINE_QA nav offline=true tabs=navigable '
        'review_manual_save=true today_day_kcal='
        '${_textOf(tester, dailyIntakeKcalKey)} -> PASS',
      );
    });
  });
}
