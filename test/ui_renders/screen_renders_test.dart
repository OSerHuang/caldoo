/// UI render harness: pumps the REAL app over the in-memory fakes at a phone
/// viewport (390x844 @3x) and captures a golden PNG per screen, in both
/// brightnesses, for the visual design review.
///
/// Run with:
///   flutter test --update-goldens test/ui_renders
/// to (re)generate `test/ui_renders/goldens/*.png`, then the plain
///   flutter test test/ui_renders
/// verifies them. The PNGs are review artifacts, not CI gates.
library;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:caldoo/core/providers/app_providers.dart';
import 'package:caldoo/core/time/date_windows.dart' show MealWithItems;
import 'package:caldoo/core/time/day_tick_provider.dart';
import 'package:caldoo/data/db/app_database.dart';
import 'package:caldoo/data/repositories/drift_food_repository.dart';
import 'package:caldoo/domain/models/models.dart';
import 'package:caldoo/features/dashboard/daily/daily_summary_providers.dart';
import 'package:caldoo/features/dashboard/monthly/monthly_summary_providers.dart';
import 'package:caldoo/features/dashboard/weekly/weekly_summary_providers.dart';
import 'package:caldoo/features/dashboard/weekly/weekly_summary_view.dart';
import 'package:caldoo/features/exercise/exercise_providers.dart';
import 'package:caldoo/features/meals/saved_foods/food_library_screen.dart';
import 'package:caldoo/features/meals/summary/meal_summary_providers.dart';
import 'package:caldoo/features/nav/app_router.dart';
import 'package:caldoo/features/nav/review_args.dart';
import 'package:caldoo/features/nav/today_screen.dart';
import 'package:caldoo/features/profile/profile_providers.dart';
import 'package:caldoo/features/settings/backup/auto_backup_providers.dart';
import 'package:caldoo/features/settings/privacy/privacy_notice.dart';
import 'package:caldoo/features/settings/settings_providers.dart'
    show secureKeyStoreProvider;
import 'package:caldoo/main.dart';

import '../data/db/_test_db.dart';
import '../data/repositories/fake_repositories.dart';
import '../features/dashboard/daily/_fixtures.dart' as daily;
import '../features/dashboard/weekly/_fixtures.dart' as weekly;
import '../features/settings/_fakes.dart' show InMemorySecureKeyStore;
import '../features/settings/backup/_auto_backup_fakes.dart';

/// Logical test viewport (phone).
const Size _logicalSize = Size(390, 844);
const double _dpr = 2.0;

const Key _captureKey = Key('ui_render_capture');

Future<void> _loadMiSans() async {
  final Future<ByteData> regular = rootBundle.load(
    'assets/fonts/MiSans-Regular.ttf',
  );
  final Future<ByteData> medium = rootBundle.load(
    'assets/fonts/MiSans-Medium.ttf',
  );
  final Future<ByteData> demibold = rootBundle.load(
    'assets/fonts/MiSans-Demibold.ttf',
  );
  final Future<ByteData> bold = rootBundle.load('assets/fonts/MiSans-Bold.ttf');
  final FontLoader loader = FontLoader('MiSans')
    ..addFont(regular)
    ..addFont(medium)
    ..addFont(demibold)
    ..addFont(bold);
  await loader.load();
  // Icon glyphs: automatic on-device (uses-material-design), manual in tests.
  final FontLoader icons = FontLoader('MaterialIcons')
    ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
  await icons.load();
}

void main() {
  late FakeMealRepository meals;
  late FakeExerciseRepository exercises;
  late FakeProfileRepository profile;
  late AppDatabase db;

  setUp(() {
    meals = FakeMealRepository();
    exercises = FakeExerciseRepository();
    profile = FakeProfileRepository();
    db = testDb();
  });

  tearDown(() async {
    await meals.dispose();
    await exercises.dispose();
    await profile.dispose();
    await db.close();
  });

  /// Boots the real app over the fakes, seeded with a plausible logged day,
  /// and captures [route] as `<name>_<mode>.png`.
  ///
  /// [view] switches the merged 今日 dashboard to the week or month view after
  /// the route lands (the 汇总 tab is gone: the week/month dashboards are views
  /// of 今日). [holdDayIndex] long-presses the weekly chart's bar for that
  /// Mon..Sun day (0 = Monday) before the capture, so the screenshot shows the
  /// bar chart's long-press tooltip bubble instead of the resting chart. The
  /// finger is lifted again after the capture.
  ///
  /// [afterLand] runs once the route has landed and its settle frames have
  /// been pumped, so a case can drive one more interaction (e.g. open the
  /// 食物库 add-food sheet) before the capture. It must not pump forever:
  /// `pumpAndSettle` is only safe here when every animation it waits on is
  /// finite (an open modal sheet is).
  Future<void> render(
    WidgetTester tester, {
    required String name,
    required String route,
    Object? extra,
    Brightness brightness = Brightness.light,
    bool noticeSeen = true,
    int? holdDayIndex,
    DashboardView? view,
    Future<void> Function(WidgetTester tester)? afterLand,
  }) async {
    // Load inside the test body: a setUpAll FontLoader does not stick for
    // later testWidgets cases under the automated test binding.
    await _loadMiSans();
    final InMemorySecureKeyStore keyStore = InMemorySecureKeyStore();
    // Automatic backup: an in-memory durable store seeded with two fixed
    // copies, and the lifecycle trigger off — a golden must not depend on how
    // far an asynchronous capture got before the frame was captured.
    final InMemoryAutoBackupStorage backupStorage =
        InMemoryAutoBackupStorage(now: () => DateTime(2026, 1, 5, 12))
          ..seed(
            'data-20260105-113000.json',
            '{"schemaVersion":4}',
            savedAt: DateTime(2026, 1, 5, 11, 30),
          )
          ..seed(
            'data-20260105-090000.json',
            '{"schemaVersion":4}',
            savedAt: DateTime(2026, 1, 5, 9),
          );
    tester.view.physicalSize = _logicalSize * _dpr;
    tester.view.devicePixelRatio = _dpr;
    tester.view.platformDispatcher.platformBrightnessTestValue = brightness;
    addTearDown(tester.view.reset);

    // Seed: today's task-7 deficit day (whole-kcal intake 1936, exercise 257),
    // plus the Tue..Fri meals of the fixture week so the weekly chart is full.
    await profile.saveProfile(daily.dashboardProfile);
    for (final MealWithItems group in daily.dashboardDeficitMeals()) {
      await meals.saveMealWithItems(group.meal, group.items);
    }
    await exercises.setKcal(
      dayKey: daily.dashboardDayKey,
      kcal: daily.dashboardExercise().kcal,
    );
    for (final MealWithItems group in weekly.weeklyMeals()) {
      // Monday (Jan 5) is "today" — already seeded above.
      if (group.meal.timestamp.day == 5) {
        continue;
      }
      await meals.saveMealWithItems(group.meal, group.items);
    }
    // Saved foods so the picker / suggestion surfaces have content.
    final DriftFoodRepository foodRepo = DriftFoodRepository(db);
    await foodRepo.upsertFood(
      const Food(
        id: 'render-food-label',
        name: '乐纯希腊酸奶',
        brand: '乐纯',
        source: FoodSource.label,
        kcal: 59,
        carbG: 4.2,
        proteinG: 9.8,
        fatG: 0.6,
        sodiumMg: 36,
      ),
    );
    await foodRepo.upsertFood(
      const Food(
        id: 'render-food-ai',
        name: '番茄炒蛋',
        source: FoodSource.ai,
        kcal: 130,
        carbG: 6.4,
        proteinG: 5.9,
        fatG: 8.6,
        sodiumMg: 320,
      ),
    );
    await foodRepo.upsertFood(
      const Food(
        id: 'render-food-manual',
        name: '全麦面包',
        brand: '曼可顿',
        source: FoodSource.manual,
        kcal: 246,
        carbG: 41,
        proteinG: 9,
        fatG: 3.4,
        sodiumMg: 400,
      ),
    );

    await tester.pumpWidget(
      RepaintBoundary(
        key: _captureKey,
        child: ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            mealRepositoryProvider.overrideWithValue(meals),
            exerciseRepositoryProvider.overrideWithValue(exercises),
            profileRepositoryProvider.overrideWithValue(profile),
            dashboardClockProvider.overrideWithValue(daily.dashboardClock()),
            dashboardOffsetProvider.overrideWithValue(daily.dashboardOffset),
            summaryClockProvider.overrideWithValue(daily.dashboardClock()),
            // The profile derives the age (and BMR) from the birthday on
            // "today"; pin it so the golden never drifts with the calendar.
            profileClockProvider.overrideWithValue(daily.dashboardClock()),
            localOffsetProvider.overrideWithValue(daily.dashboardOffset),
            weeklyClockProvider.overrideWithValue(weekly.weeklyClock()),
            weeklyOffsetProvider.overrideWithValue(weekly.weeklyOffset),
            // The merged 今日 tab also mounts the month dashboard; pin its
            // seams too, or the month capture would follow the real calendar
            // and show an empty month.
            monthlyClockProvider.overrideWithValue(weekly.weeklyClock()),
            monthlyOffsetProvider.overrideWithValue(weekly.weeklyOffset),
            // The exercise-burn screen opens on yesterday by default and shows
            // that date; pin its time seam so the golden's date never drifts.
            exerciseClockProvider.overrideWithValue(daily.dashboardClock()),
            exerciseOffsetProvider.overrideWithValue(daily.dashboardOffset),
            // The current-day seams follow the day-tick signal; the goldens
            // pin the day instead, so the tick stays quiet (and its
            // production Timer out of the fake-async zone).
            dayTickProvider.overrideWith((ref) => const Stream<int>.empty()),
            connectivityProvider.overrideWith(
              (ref) => Stream<List<ConnectivityResult>>.value(
                const <ConnectivityResult>[ConnectivityResult.wifi],
              ),
            ),
            privacyNoticeSeenProvider.overrideWith((ref) => noticeSeen),
            autoBackupLifecycleEnabledProvider.overrideWithValue(false),
            autoBackupStorageProvider.overrideWithValue(backupStorage),
            // The settings screen reads the BYOK key: without this override
            // the secure-storage plugin channel hangs the form forever.
            secureKeyStoreProvider.overrideWithValue(keyStore),
          ],
          child: const HaohaochifanApp(),
        ),
      ),
    );
    // Bounded pumps, never pumpAndSettle: the ring's intro tween and any
    // route transition are done after ~1s, and an always-animating widget
    // (an indeterminate spinner) would otherwise spin this test to the
    // 10-minute pumpAndSettle timeout.
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 600));

    final ProviderContainer container = ProviderScope.containerOf(
      tester.element(find.byType(HaohaochifanApp)),
    );
    final GoRouter router = container.read(appRouterProvider);
    router.go(route, extra: extra);
    // Extra frames so live streams (meal watch, today totals) can emit after
    // the route lands — the totals blocks render the first emission.
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    // One extra scripted interaction with the landed screen, if the case needs
    // it (e.g. opening the 食物库 add-food sheet). Bounded pumps are over by
    // this point; the hook may settle because its animations are finite.
    if (afterLand != null) {
      await afterLand(tester);
    }

    // The merged 今日 dashboard opens on the day view; switch to the week or
    // month view through the real switcher so the capture shows what the user
    // would see after tapping it.
    final DashboardView? targetView = view;
    if (targetView != null && targetView != DashboardView.day) {
      final Key segmentKey = switch (targetView) {
        DashboardView.day => todayViewDayKey,
        DashboardView.week => todayViewWeekKey,
        DashboardView.month => todayViewMonthKey,
      };
      await tester.tap(find.byKey(segmentKey));
      await tester.pumpAndSettle();
    }

    // Long-press a weekly bar so the capture includes the tooltip bubble. The
    // finger stays down across the capture (releasing it hides the bubble).
    TestGesture? heldGesture;
    if (holdDayIndex != null) {
      final Rect chart = tester.getRect(find.byKey(weeklyChartKey));
      // Same plot geometry the chart itself uses: a 40 px left title gutter and
      // a 24 px bottom weekday strip; the rods' centres sit in the middle of
      // each of the seven evenly spaced slots, and two 14 px rods are 2 px
      // apart, so the intake rod's centre is 8 px left of the group centre.
      const double leftGutter = 40;
      const double bottomGutter = 24;
      final double plotWidth = chart.width - leftGutter;
      final double plotHeight = chart.height - bottomGutter;
      final double groupX =
          chart.left + leftGutter + (holdDayIndex + 0.5) * plotWidth / 7;
      final double intakeX = groupX - 8;
      heldGesture = await tester.startGesture(
        Offset(intakeX, chart.top + plotHeight * 0.7),
      );
      // Past kLongPressTimeout so fl_chart treats it as a long press.
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump();
    }

    final String mode = brightness == Brightness.light ? 'light' : 'dark';
    await expectLater(
      find.byKey(_captureKey),
      matchesGoldenFile('goldens/${name}_$mode.png'),
    );

    await heldGesture?.up();
    await tester.pump();
  }

  // The goldens are macOS-generated review artifacts (see the library doc
  // above); text rasterization differs across platforms, so CI excludes them
  // with `flutter test --exclude-tags=ui-renders` (tag declared in
  // dart_test.yaml).
  void renderTest(String description, WidgetTesterCallback body) {
    testWidgets(description, body, tags: 'ui-renders');
  }

  for (final Brightness brightness in Brightness.values) {
    renderTest('today (${brightness.name})', (WidgetTester tester) async {
      await render(
        tester,
        name: '01_today',
        route: '/today',
        brightness: brightness,
      );
    });

    renderTest('food library (${brightness.name})', (
      WidgetTester tester,
    ) async {
      await render(
        tester,
        name: '02_food_library',
        route: '/foods',
        brightness: brightness,
      );
    });

    renderTest('add food sheet (${brightness.name})', (
      WidgetTester tester,
    ) async {
      await render(
        tester,
        name: '18_add_food_sheet',
        route: '/foods',
        brightness: brightness,
        // Open the FAB's two-option sheet so the capture shows both entry
        // points (拍照识别营养标签 / 手动录入) fully laid out.
        afterLand: (WidgetTester tester) async {
          await tester.tap(find.byKey(foodLibraryAddButtonKey));
          await tester.pumpAndSettle();
        },
      );
    });

    renderTest('meal capture (${brightness.name})', (
      WidgetTester tester,
    ) async {
      await render(
        tester,
        name: '03_capture',
        route: '/today/capture',
        brightness: brightness,
      );
    });

    renderTest('meal review (${brightness.name})', (WidgetTester tester) async {
      await render(
        tester,
        name: '04_review',
        route: '/today/review',
        brightness: brightness,
        extra: ReviewArgs(
          draft: const AiMealDraft(
            items: <MealItem>[
              MealItem(
                id: 'render-item-1',
                name: '番茄炒蛋',
                grams: 220,
                kcal: 286,
                carbG: 14,
                proteinG: 13,
                fatG: 19,
                saltG: 1.4,
                source: FoodSource.ai,
              ),
              MealItem(
                id: 'render-item-2',
                name: '米饭',
                grams: 180,
                kcal: 207,
                carbG: 45,
                proteinG: 4,
                fatG: 1,
                saltG: 0.3,
                source: FoodSource.label,
              ),
            ],
          ),
          meal: Meal(
            id: 'render-review-meal',
            timestamp: daily.dashboardNow,
            mealType: MealType.lunch,
          ),
        ),
      );
    });

    renderTest('label capture (${brightness.name})', (
      WidgetTester tester,
    ) async {
      await render(
        tester,
        name: '05_label',
        route: '/foods/add',
        brightness: brightness,
      );
    });

    renderTest('exercise (${brightness.name})', (WidgetTester tester) async {
      await render(
        tester,
        name: '07_exercise',
        route: '/today/exercise',
        brightness: brightness,
      );
    });

    renderTest('weekly summary (${brightness.name})', (
      WidgetTester tester,
    ) async {
      await render(
        tester,
        name: '08_summary',
        route: '/today',
        brightness: brightness,
        view: DashboardView.week,
      );
    });

    renderTest('monthly summary (${brightness.name})', (
      WidgetTester tester,
    ) async {
      await render(
        tester,
        name: '17_month',
        route: '/today',
        brightness: brightness,
        view: DashboardView.month,
      );
    });

    renderTest('weekly summary long-press tooltip (${brightness.name})', (
      WidgetTester tester,
    ) async {
      await render(
        tester,
        name: '16_summary_tooltip',
        route: '/today',
        brightness: brightness,
        view: DashboardView.week,
        // Friday carries the week's tallest bar, so the tooltip is pushed
        // inside the plot — the case that used to be clipped.
        holdDayIndex: 4,
      );
    });

    renderTest('profile hub (${brightness.name})', (WidgetTester tester) async {
      await render(
        tester,
        name: '09_profile',
        route: '/profile',
        brightness: brightness,
      );
    });

    renderTest('profile details (${brightness.name})', (
      WidgetTester tester,
    ) async {
      await render(
        tester,
        name: '10_profile_details',
        route: '/profile/details',
        brightness: brightness,
      );
    });

    renderTest('settings hub (${brightness.name})', (
      WidgetTester tester,
    ) async {
      await render(
        tester,
        name: '11_settings',
        route: '/profile/settings',
        brightness: brightness,
      );
    });

    renderTest('settings ai (${brightness.name})', (WidgetTester tester) async {
      await render(
        tester,
        name: '20_settings_ai',
        route: '/profile/settings/ai',
        brightness: brightness,
      );
    });

    renderTest('settings display (${brightness.name})', (
      WidgetTester tester,
    ) async {
      // 数据显示 is its own second-level page: both preference groups fit on
      // one screen without scrolling.
      await render(
        tester,
        name: '19_settings_display',
        route: '/profile/settings/display',
        brightness: brightness,
      );
    });

    renderTest('privacy (${brightness.name})', (WidgetTester tester) async {
      await render(
        tester,
        name: '12_privacy',
        route: '/profile/privacy',
        brightness: brightness,
      );
    });

    renderTest('backup (${brightness.name})', (WidgetTester tester) async {
      await render(
        tester,
        name: '13_backup',
        route: '/profile/backup',
        brightness: brightness,
      );
    });

    renderTest('meal detail (${brightness.name})', (WidgetTester tester) async {
      await render(
        tester,
        name: '14_meal_detail',
        route: '/meal/meal-a',
        brightness: brightness,
      );
    });

    renderTest('first-run privacy gate (${brightness.name})', (
      WidgetTester tester,
    ) async {
      await render(
        tester,
        name: '15_privacy_gate',
        route: '/today',
        brightness: brightness,
        noticeSeen: false,
      );
    });
  }
}
