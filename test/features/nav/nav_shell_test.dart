/// Task 27 — the go_router bottom-nav shell widget tests.
///
/// MANUAL-QA CHANNEL: prints one `TASK27_NAV_QA` / `MERGED_DASH_QA` /
/// `FOOD_LIBRARY_QA` line per verified behaviour.
///
/// Covers the plan's acceptance criteria directly:
/// * tapping each of 概览 / 食物库 / 我的 shows the matching screen (the former
///   记录 hub is gone: logging starts from 概览's quick-add actions and the
///   second tab is the live food library);
/// * the merged 概览 tab opens on the day view and switches between the day,
///   week and month dashboards without leaving the tab;
/// * switching tabs preserves the 概览 branch's pushed route and its typed
///   state (each branch keeps its own [Navigator]);
/// * the 食物库 tab lists saved foods, opens a food's detail (never the
///   meal-selection picker), and its 添加食物 → 手动录入 lane saves a food that
///   appears in the live list;
/// * a system back press at a non-Today tab root returns to 今日 instead of
///   draining another tab's stack.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:caldoo/domain/models/models.dart';
import 'package:caldoo/features/dashboard/daily/daily_summary_view.dart';
import 'package:caldoo/features/dashboard/monthly/monthly_summary_view.dart';
import 'package:caldoo/features/dashboard/weekly/weekly_summary_view.dart';
import 'package:caldoo/features/exercise/exercise_entry_screen.dart';
import 'package:caldoo/features/meals/capture/meal_capture_screen.dart';
import 'package:caldoo/features/meals/label/label_capture_screen.dart';
import 'package:caldoo/features/meals/saved_foods/food_library_screen.dart';
import 'package:caldoo/features/meals/saved_foods/saved_food_detail_screen.dart';
import 'package:caldoo/features/meals/saved_foods/saved_food_list.dart';
import 'package:caldoo/features/nav/nav_shell.dart';
import 'package:caldoo/features/nav/profile_tab_screen.dart';
import 'package:caldoo/features/nav/today_screen.dart';

import '../../data/repositories/fake_repositories.dart';
import '_harness.dart';

/// Only the on-screen (hit-testable) instance of [key]; the other
/// `IndexedStack` branches stay mounted but are not hit-testable.
Finder visible(Key key) => find.byKey(key).hitTestable();

void main() {
  late NavTestEnv env;

  setUp(() => env = NavTestEnv());
  tearDown(() => env.dispose());

  /// Boots the app with a fresh in-memory food catalogue.
  ///
  /// The 食物库 tab watches the saved-food stream as soon as it is visited, so
  /// any test that opens it must replace the real Drift port with the fake.
  Future<FakeFoodRepository> pumpWithEmptyLibrary(WidgetTester tester) async {
    final FakeFoodRepository foods = FakeFoodRepository();
    addTearDown(foods.dispose);
    await env.pump(tester, foodRepository: foods);
    return foods;
  }

  testWidgets('tapping each tab shows the matching screen', (
    WidgetTester tester,
  ) async {
    await pumpWithEmptyLibrary(tester);

    // Landing tab.
    expect(selectedTab(tester), 0);
    expect(visible(todayScreenKey), findsOneWidget);
    debugPrint('TASK27_NAV_QA tab=今日 index=0 -> PASS');

    await tester.tap(find.byKey(navFoodsKey));
    await tester.pumpAndSettle();
    expect(selectedTab(tester), 1);
    expect(visible(foodLibraryScreenKey), findsOneWidget);
    expect(visible(todayScreenKey), findsNothing);
    debugPrint('TASK27_NAV_QA tab=食物库 index=1 -> PASS');

    await tester.tap(find.byKey(navProfileKey));
    await tester.pumpAndSettle();
    expect(selectedTab(tester), 2);
    expect(visible(profileTabScreenKey), findsOneWidget);
    debugPrint('TASK27_NAV_QA tab=我的 index=2 -> PASS');

    await tester.tap(find.byKey(navTodayKey));
    await tester.pumpAndSettle();
    expect(selectedTab(tester), 0);
    expect(visible(todayScreenKey), findsOneWidget);
    debugPrint('TASK27_NAV_QA tab=今日 index=0 -> PASS');
  });

  testWidgets('the merged 今日 tab hosts the 日/周/月 dashboards', (
    WidgetTester tester,
  ) async {
    await env.pump(tester);

    // The former 汇总 tab is gone; its week dashboard is now a view of 今日.
    expect(find.byKey(const Key('nav_summary')), findsNothing);
    expect(visible(todayViewSwitcherKey), findsOneWidget);
    debugPrint('MERGED_DASH_QA tabs=3 汇总=merged -> PASS');

    // The day view is the default: the daily hero card is on screen (its
    // signed-balance label only exists for a complete profile, which the
    // harness seeds).
    expect(visible(dailyBalanceLabelKey), findsOneWidget);
    debugPrint('MERGED_DASH_QA default_view=日 -> PASS');

    await tester.tap(find.byKey(todayViewWeekKey));
    await tester.pumpAndSettle();
    // The real task-26 weekly dashboard: an unlogged week shows its empty state.
    expect(visible(weeklyEmptyStateKey), findsOneWidget);
    expect(visible(todayViewSwitcherKey), findsOneWidget);
    debugPrint('MERGED_DASH_QA view=周 -> weekly dashboard -> PASS');

    await tester.tap(find.byKey(todayViewMonthKey));
    await tester.pumpAndSettle();
    // The monthly dashboard, likewise empty for an unlogged month.
    expect(visible(monthlyEmptyStateKey), findsOneWidget);
    debugPrint('MERGED_DASH_QA view=月 -> monthly dashboard -> PASS');

    await tester.tap(find.byKey(todayViewDayKey));
    await tester.pumpAndSettle();
    expect(visible(dailyBalanceLabelKey), findsOneWidget);
    debugPrint('MERGED_DASH_QA view=日 -> today dashboard -> PASS');
  });

  testWidgets('switching tabs preserves the 今日 branch stack and its state', (
    WidgetTester tester,
  ) async {
    await pumpWithEmptyLibrary(tester);

    // Logging starts on the 今日 branch now: quick-add pushes the capture
    // screen inside that branch, under the bottom bar.
    await openMealCaptureFromToday(tester);
    expect(find.byType(MealCaptureScreen).hitTestable(), findsOneWidget);

    const String typed = '保留这条记录';
    await tester.enterText(find.byKey(const Key('capture_text_field')), typed);
    await tester.pump();
    expect(find.text(typed), findsOneWidget);

    // Leave the 今日 branch entirely.
    await tester.tap(find.byKey(navFoodsKey));
    await tester.pumpAndSettle();
    expect(visible(foodLibraryScreenKey), findsOneWidget);

    // Returning restores the pushed capture route AND the typed text.
    await tester.tap(find.byKey(navTodayKey));
    await tester.pumpAndSettle();
    expect(find.byType(MealCaptureScreen).hitTestable(), findsOneWidget);
    expect(find.text(typed).hitTestable(), findsOneWidget);
    debugPrint(
      'TASK27_NAV_QA per_tab_state branch=今日 route=/today/capture '
      'text="$typed" -> PASS',
    );
  });

  testWidgets('the 食物库 tab browses saved foods and opens a food detail', (
    WidgetTester tester,
  ) async {
    // The real router over the in-memory food fake, so this guards the route
    // wiring that the bug report hit: the entry used to push the selection
    // picker, which popped on tap and showed no details.
    final FakeFoodRepository foodRepo = FakeFoodRepository();
    addTearDown(foodRepo.dispose);
    await foodRepo.insertFood(
      const Food(
        id: 'nav-food',
        name: '全脂牛奶',
        source: FoodSource.label,
        kcal: 60,
      ),
    );
    await env.pump(tester, foodRepository: foodRepo);

    await tester.tap(find.byKey(navFoodsKey));
    await tester.pumpAndSettle();

    expect(visible(foodLibraryScreenKey), findsOneWidget);
    expect(find.byKey(savedFoodTileKey('nav-food')), findsOneWidget);
    expect(find.text('选择已存食物'), findsNothing);
    debugPrint('FOOD_LIBRARY_QA tab=食物库 seeded_food=全脂牛奶 -> PASS');

    await tester.tap(find.byKey(savedFoodTileKey('nav-food')));
    await tester.pumpAndSettle();

    // A catalogue row opens the detail page, never the meal-selection picker.
    expect(visible(savedFoodDetailScreenKey), findsOneWidget);
    expect(find.text('选择已存食物'), findsNothing);
    debugPrint('FOOD_LIBRARY_QA row -> detail_page not_picker -> PASS');
  });

  testWidgets('the 食物库 add-food flow saves a manual food into the live list', (
    WidgetTester tester,
  ) async {
    final FakeFoodRepository foodRepo = await pumpWithEmptyLibrary(tester);

    await tester.tap(find.byKey(navFoodsKey));
    await tester.pumpAndSettle();
    // An empty catalogue renders the add call-to-action panel.
    expect(visible(foodLibraryEmptyAddButtonKey), findsOneWidget);

    // FAB → the two-lane add sheet.
    await tester.tap(find.byKey(foodLibraryAddButtonKey));
    await tester.pumpAndSettle();
    expect(find.byKey(foodLibraryAddSheetKey), findsOneWidget);

    // 手动录入 skips the photo step and opens the confirm form directly.
    await tester.tap(find.byKey(foodLibraryAddManualKey));
    await tester.pumpAndSettle();

    expect(find.byType(LabelCaptureScreen).hitTestable(), findsOneWidget);
    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('手动录入')),
      findsOneWidget,
    );
    expect(find.byKey(labelNameFieldKey(0)), findsOneWidget);

    const String name = '手工酸奶';
    await tester.enterText(find.byKey(labelNameFieldKey(0)), name);
    await tester.pump();
    await tester.tap(find.byKey(const Key('label_save_button')));
    await tester.pumpAndSettle();

    // The saved step's 完成 pops back to the live library.
    await tester.ensureVisible(find.byKey(labelDoneButtonKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(labelDoneButtonKey));
    await tester.pumpAndSettle();

    expect(visible(foodLibraryScreenKey), findsOneWidget);
    final List<Food> foods = await foodRepo.getAllFoods();
    expect(foods, hasLength(1));
    expect(foods.single.name, name);
    // The list is driven by the repository stream: the new food is on it and
    // the empty-state panel is gone.
    expect(find.byKey(savedFoodTileKey(foods.single.id)), findsOneWidget);
    expect(find.byKey(foodLibraryEmptyAddButtonKey), findsNothing);
    debugPrint(
      'FOOD_LIBRARY_QA add=手动录入 saved=${foods.single.id} '
      'live_list=true -> PASS',
    );
  });

  testWidgets(
    'back at a non-Today tab root returns to 今日, not another tab stack',
    (WidgetTester tester) async {
      await pumpWithEmptyLibrary(tester);

      await tester.tap(find.byKey(navFoodsKey));
      await tester.pumpAndSettle();
      expect(visible(foodLibraryScreenKey), findsOneWidget);

      await systemBack(tester);

      expect(selectedTab(tester), 0);
      expect(visible(todayScreenKey), findsOneWidget);
      expect(visible(foodLibraryScreenKey), findsNothing);
      debugPrint('TASK27_NAV_QA back_at_tab_root -> 今日 -> PASS');
    },
  );

  testWidgets('the 今日 quick-add 记录运动 opens the exercise screen', (
    WidgetTester tester,
  ) async {
    await env.pump(tester);

    // The history pager adds a header above the dashboard, so on the 800x600
    // test surface the quick-add row starts below the fold: scroll the page's
    // vertical list until it is on stage before tapping it.
    await scrollTodayUntilVisible(tester, find.byKey(todayQuickAddExerciseKey));

    await tester.tap(find.byKey(todayQuickAddExerciseKey));
    await tester.pumpAndSettle();

    // The date-selecting entry screen, not the former 记录 hub tile.
    expect(find.byType(ExerciseEntryScreen), findsOneWidget);
    expect(visible(todayScreenKey), findsNothing);
    debugPrint('TASK27_NAV_QA quick_add=记录运动 -> /today/exercise -> PASS');
  });
}
