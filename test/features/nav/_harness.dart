/// Shared harness for the task-27 navigation tests.
///
/// Boots the **real** app shell ([HaohaochifanApp] + [appRouterProvider]) over
/// the in-memory repository fakes, so the tests exercise the production router,
/// the production `StatefulShellRoute.indexedStack` branch navigators and the
/// production screens — only the persistence and the clock are faked.
///
/// No file database and no platform channel is touched:
/// * the four repository ports are replaced with the in-memory fakes;
/// * `connectivity_plus` is replaced with a canned stream;
/// * the task-22/24/26 monthly-and-weekly time seams are pinned to one fixed
///   +08:00 instant.
library;

import 'package:clock/clock.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'package:caldoo/core/providers/app_providers.dart';
import 'package:caldoo/core/time/day_tick_provider.dart';
import 'package:caldoo/data/db/app_database.dart';
import 'package:caldoo/domain/models/models.dart';
import 'package:caldoo/domain/repositories/repositories.dart';
import 'package:caldoo/features/dashboard/daily/daily_summary_providers.dart';
import 'package:caldoo/features/dashboard/monthly/monthly_summary_providers.dart';
import 'package:caldoo/features/dashboard/weekly/weekly_summary_providers.dart';
import 'package:caldoo/features/meals/summary/meal_summary_providers.dart';
import 'package:caldoo/features/settings/ai_settings.dart' show SecureKeyStore;
import 'package:caldoo/features/settings/privacy/privacy_notice.dart';
import 'package:caldoo/features/settings/settings_providers.dart'
    show dioProvider, secureKeyStoreProvider;
import 'package:caldoo/features/nav/glass_nav_bar.dart';
import 'package:caldoo/features/nav/today_screen.dart';
import 'package:caldoo/main.dart';

import '../../data/db/_test_db.dart';
import '../../data/repositories/fake_repositories.dart';
import '../dashboard/daily/_fixtures.dart'
    show dashboardClock, dashboardNow, dashboardOffset, dashboardProfile;

/// The repository fakes + built container for one test.
class NavTestEnv {
  /// Creates fresh fakes.
  NavTestEnv()
    : meals = FakeMealRepository(),
      exercises = FakeExerciseRepository(),
      profile = FakeProfileRepository(),
      weights = FakeWeightRepository();

  /// The in-memory meal store.
  final FakeMealRepository meals;

  /// The in-memory exercise store.
  final FakeExerciseRepository exercises;

  /// The in-memory profile store.
  final FakeProfileRepository profile;

  /// The in-memory weight-history store (the day page's 体重 card).
  final FakeWeightRepository weights;

  /// The live container after [pump].
  late ProviderContainer container;

  /// An in-memory database created by the harness for tests that do not pass
  /// their own; closed in [dispose]. The app root reads the display settings
  /// from the settings DAO, so the real file database must never be opened.
  AppDatabase? _ownedDb;

  /// Boots the app over the fakes and settles the first frame.
  ///
  /// [connectivity] defaults to an online transport; pass
  /// `[ConnectivityResult.none]` to boot the whole app offline (task 30).
  /// [foodRepository] replaces the saved-food catalogue port (defaults to the
  /// real Drift repository over [database], which most nav tests never touch).
  /// [dio] / [keyStore] / [database] forward the AI seams so a test can drive a
  /// real capture → review → re-estimate flow without touching a platform
  /// channel or the file database; when omitted the AI graph is left at its
  /// production defaults (which those tests must not touch).
  /// [extraOverrides] are appended last, so a test can replace any further seam
  /// (e.g. `labelLinkerProvider`) without touching the shared defaults.
  /// [now] re-pins every clock seam to a different instant (same +08:00
  /// offset), for tests that need a fixture date the shared instant cannot
  /// express — the first days of January, say.
  Future<void> pump(
    WidgetTester tester, {
    bool withProfile = true,
    List<ConnectivityResult> connectivity = const <ConnectivityResult>[
      ConnectivityResult.wifi,
    ],
    FoodRepository? foodRepository,
    Dio? dio,
    SecureKeyStore? keyStore,
    AppDatabase? database,
    DateTime? now,
    List<Override> extraOverrides = const <Override>[],
  }) async {
    if (withProfile) {
      await profile.saveProfile(dashboardProfile);
    }
    // The app root (DisplayScope) loads the display preferences from the
    // settings DAO through [appDatabaseProvider]; give every test an in-memory
    // database so no test ever opens the on-disk file DB.
    final AppDatabase db = database ?? (_ownedDb ??= testDb());
    final Clock clock = now == null ? dashboardClock() : Clock.fixed(now);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mealRepositoryProvider.overrideWithValue(meals),
          exerciseRepositoryProvider.overrideWithValue(exercises),
          profileRepositoryProvider.overrideWithValue(profile),
          weightRepositoryProvider.overrideWithValue(weights),
          // task-24 daily dashboard time seam
          dashboardClockProvider.overrideWithValue(clock),
          dashboardOffsetProvider.overrideWithValue(dashboardOffset),
          // The merged 今日 tab also mounts the week and month dashboards, so
          // pin their time seams to the same instant as the day view; a test
          // that only exercises the day view would otherwise read the real
          // clock through those offstage views.
          weeklyClockProvider.overrideWithValue(clock),
          weeklyOffsetProvider.overrideWithValue(dashboardOffset),
          monthlyClockProvider.overrideWithValue(clock),
          monthlyOffsetProvider.overrideWithValue(dashboardOffset),
          // task-22 per-meal summary time seam
          summaryClockProvider.overrideWithValue(clock),
          localOffsetProvider.overrideWithValue(dashboardOffset),
          // The current-day seams follow the day-tick signal; the harness pins
          // the day instead, so the tick stays quiet (and its production
          // Timer out of the widget-test fake-async zone).
          dayTickProvider.overrideWith((ref) => const Stream<int>.empty()),
          connectivityProvider.overrideWith(
            (ref) => Stream<List<ConnectivityResult>>.value(connectivity),
          ),
          // The nav tests boot the real app; mark the first-run privacy notice
          // as seen so the gate reveals the shell without touching the DB.
          privacyNoticeSeenProvider.overrideWith((ref) => true),
          appDatabaseProvider.overrideWithValue(db),
          if (foodRepository != null)
            foodRepositoryProvider.overrideWithValue(foodRepository),
          if (dio != null) dioProvider.overrideWithValue(dio),
          if (keyStore != null)
            secureKeyStoreProvider.overrideWithValue(keyStore),
          ...extraOverrides,
        ],
        child: const HaohaochifanApp(),
      ),
    );
    await tester.pumpAndSettle();
    container = ProviderScope.containerOf(
      tester.element(find.byType(HaohaochifanApp)),
    );
  }

  /// Closes every fake's broadcast stream and the harness-owned test database.
  Future<void> dispose() async {
    await meals.dispose();
    await exercises.dispose();
    await profile.dispose();
    await weights.dispose();
    await _ownedDb?.close();
    _ownedDb = null;
  }
}

/// A meal at the pinned "now" with [kcal] of food, for seeding the fakes.
({Meal meal, List<MealItem> items}) navMeal({
  required String id,
  required int kcal,
  MealType mealType = MealType.lunch,
  String name = '米饭',
}) {
  return (
    meal: Meal(id: id, timestamp: dashboardNow, mealType: mealType),
    items: <MealItem>[
      MealItem(
        id: '$id-item',
        name: name,
        grams: 150,
        kcal: kcal,
        carbG: 10,
        proteinG: 5,
        fatG: 2,
        saltG: 0.5,
        source: FoodSource.manual,
      ),
    ],
  );
}

/// The active [GlassNavBar] tab index.
int selectedTab(WidgetTester tester) =>
    tester.widget<GlassNavBar>(find.byType(GlassNavBar)).selectedIndex;

/// Scrolls the 今日 day view until [finder] is on stage.
///
/// The day page's vertical list is the first down-axis [Scrollable] (the
/// horizontal history pager wraps it), and the quick-add row starts below the
/// fold on the default 800x600 test surface.
Future<void> scrollTodayUntilVisible(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    120,
    scrollable: find
        .byWidgetPredicate(
          (Widget widget) =>
              widget is Scrollable &&
              widget.axisDirection == AxisDirection.down,
        )
        .first,
  );
  await tester.pumpAndSettle();
  // extendBody: the glass nav floats over the list, so a merely-rendered row
  // can still sit beneath it — keep scrolling until it is actually tappable.
  for (int i = 0; i < 50; i++) {
    if (tester.any(finder.hitTestable())) {
      return;
    }
    await tester.drag(
      find
          .byWidgetPredicate(
            (Widget widget) =>
                widget is Scrollable &&
                widget.axisDirection == AxisDirection.down,
          )
          .first,
      const Offset(0, -120),
    );
    await tester.pumpAndSettle();
  }
}

/// Opens the meal-capture screen from 今日's 记录一餐 quick-add action.
///
/// Logging moved off the former 记录 hub: the quick-add lives on the 今日 day
/// page and pushes `/today/capture` onto the 今日 branch.
Future<void> openMealCaptureFromToday(WidgetTester tester) async {
  await scrollTodayUntilVisible(tester, find.byKey(todayQuickAddMealKey));
  await tester.tap(find.byKey(todayQuickAddMealKey));
  await tester.pumpAndSettle();
}

/// Delivers a system back press through the same `flutter/navigation` channel
/// the Android engine uses, so the real `PopScope` / go_router path runs.
Future<void> systemBack(WidgetTester tester) async {
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    'flutter/navigation',
    const JSONMethodCodec().encodeMethodCall(const MethodCall('popRoute')),
    (ByteData? data) {},
  );
  await tester.pumpAndSettle();
}
