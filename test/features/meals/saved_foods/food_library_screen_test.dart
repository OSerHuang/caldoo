/// Widget tests for the 食物库 (food library) tab root.
///
/// The former 记录 → 已存食物 browse page is now the second bottom-nav tab
/// itself: a live catalogue with search, a per-food detail page and the
/// 添加食物 sheet that feeds new foods through the label-capture flow.
///
/// The add-flow tests drive the real production routes (`/foods` → `/foods/add`
/// and `/foods/add?manual=1`) over a minimal GoRouter, with the in-memory food
/// repository fake, so they cover navigation, the manual-entry mode and the
/// live refresh after 完成 without touching a platform channel or a real DB.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:caldoo/core/providers/app_providers.dart';
import 'package:caldoo/domain/models/models.dart';
import 'package:caldoo/features/meals/label/label_capture_screen.dart';
import 'package:caldoo/features/meals/saved_foods/food_library_screen.dart';
import 'package:caldoo/features/meals/saved_foods/saved_food_detail_screen.dart';
import 'package:caldoo/features/meals/saved_foods/saved_food_list.dart';

import '../../../data/repositories/fake_repositories.dart';
import '_fixtures.dart';

/// Pumps the real food-library routes over [foods] in a fake repository.
///
/// `/foods` is the tab root, `/foods/add` the photo path and
/// `/foods/add?manual=1` the manual-entry path — the same wiring
/// `lib/features/nav/app_router.dart` installs.
Future<FakeFoodRepository> _pumpLibrary(
  WidgetTester tester, {
  List<Food> foods = const <Food>[],
}) async {
  final FakeFoodRepository repo = FakeFoodRepository();
  for (final Food food in foods) {
    await repo.insertFood(food);
  }
  final GoRouter router = GoRouter(
    initialLocation: '/foods',
    routes: <RouteBase>[
      GoRoute(
        path: '/foods',
        builder: (BuildContext context, GoRouterState state) =>
            const FoodLibraryScreen(),
        routes: <RouteBase>[
          GoRoute(
            path: 'add',
            builder: (BuildContext context, GoRouterState state) =>
                LabelCaptureScreen(
                  startManualEntry: state.uri.queryParameters['manual'] == '1',
                ),
          ),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [foodRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return repo;
}

void main() {
  testWidgets('lists every saved food with its provenance badge', (
    WidgetTester tester,
  ) async {
    await _pumpLibrary(tester, foods: <Food>[labelMilk, aiVeg]);

    expect(find.byKey(foodLibraryScreenKey), findsOneWidget);
    expect(find.text('食物库'), findsOneWidget);
    expect(find.byKey(savedFoodTileKey('food-label-milk')), findsOneWidget);
    expect(find.byKey(savedFoodTileKey('food-ai-veg')), findsOneWidget);
    // The official-label pill is hidden; the AI badge still marks an estimate.
    expect(find.text('官方标签'), findsNothing);
    expect(find.text('AI估算'), findsOneWidget);
  });

  testWidgets('tapping a saved food opens its details', (
    WidgetTester tester,
  ) async {
    await _pumpLibrary(tester, foods: <Food>[labelMilk]);

    await tester.tap(find.byKey(savedFoodTileKey('food-label-milk')));
    await tester.pumpAndSettle();

    expect(find.byKey(savedFoodDetailScreenKey), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(savedFoodDetailNameKey)).data,
      '全脂牛奶',
    );
    expect(tester.widget<Text>(find.byKey(savedFoodDetailBrandKey)).data, '光明');
    expect(find.text('营养成分（每 100 g）'), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(savedFoodDetailValueKey('kcal'))).data,
      '200',
    );

    // Back returns to the catalogue rather than leaving it.
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byKey(foodLibraryScreenKey), findsOneWidget);
  });

  testWidgets('search still filters the catalogue', (
    WidgetTester tester,
  ) async {
    await _pumpLibrary(tester, foods: <Food>[labelMilk, aiVeg]);

    await tester.enterText(find.byKey(savedFoodSearchFieldKey), '牛奶');
    await tester.pumpAndSettle();
    expect(find.byKey(savedFoodTileKey('food-label-milk')), findsOneWidget);
    expect(find.byKey(savedFoodTileKey('food-ai-veg')), findsNothing);
  });

  testWidgets('an archived food keeps its row and gets the 已停用 tag', (
    WidgetTester tester,
  ) async {
    await _pumpLibrary(tester, foods: <Food>[labelMilk, archivedBiscuit]);

    // Archived foods stay listed: only the row gains a tag.
    expect(
      find.byKey(savedFoodTileKey('food-archived-biscuit')),
      findsOneWidget,
    );
    expect(
      find.byKey(savedFoodArchivedBadgeKey('food-archived-biscuit')),
      findsOneWidget,
    );
    expect(find.text('已停用'), findsOneWidget);
    // An active food never shows the tag.
    expect(
      find.byKey(savedFoodArchivedBadgeKey('food-label-milk')),
      findsNothing,
    );
  });

  testWidgets('an empty catalogue shows the empty state and an add action', (
    WidgetTester tester,
  ) async {
    await _pumpLibrary(tester);

    expect(find.text('食物库还是空的'), findsOneWidget);
    expect(find.text('拍一张营养成分表或手动录入，食物就会收进这里'), findsOneWidget);
    expect(find.byKey(foodLibraryEmptyAddButtonKey), findsOneWidget);
    expect(find.byKey(foodLibraryAddButtonKey), findsOneWidget);
    expect(find.byKey(foodLibraryScreenKey), findsOneWidget);
  });

  testWidgets('the row title reads 名称（品牌）and the meta line drops it', (
    WidgetTester tester,
  ) async {
    await _pumpLibrary(tester, foods: <Food>[structuredOatMilk]);

    // 品牌+食物名 in the title, the same format as the suggestion chips.
    expect(find.text('燕麦奶（OATLY）'), findsOneWidget);

    final String meta = tester
        .widget<Text>(find.byKey(savedFoodTileMetaKey('food-structured-oat')))
        .data!;
    // The brand moved to the title; the meta line keeps aliases/servings.
    expect(meta, isNot(contains('品牌')));
    expect(meta, contains('别名：燕麦奶、oat milk'));
    expect(meta, contains('份量：一盒 250 ml、一袋 120 g'));
  });

  testWidgets('legacy notes still produce the structured meta line', (
    WidgetTester tester,
  ) async {
    const Food legacy = Food(
      id: 'food-legacy',
      name: 'AH豆腐(Bio)',
      source: FoodSource.label,
      notes: '标签 2026-09-08 | 别名：ah豆腐 | 一份 100 g',
      kcal: 113,
    );
    await _pumpLibrary(tester, foods: <Food>[legacy]);

    final String meta = tester
        .widget<Text>(find.byKey(savedFoodTileMetaKey('food-legacy')))
        .data!;
    expect(meta, contains('别名：ah豆腐'));
    expect(meta, contains('份量：一份 100 g'));
  });

  testWidgets('a row without identity details shows no subtitle', (
    WidgetTester tester,
  ) async {
    const Food onlyGuess = Food(
      id: 'food-only-notes',
      name: '冷藏食物',
      source: FoodSource.manual,
      notes: '冷藏保存，三天内吃完',
    );
    await _pumpLibrary(tester, foods: <Food>[onlyGuess]);

    // The retired 补充说明 is never shown as a subtitle; there is no meta line.
    expect(find.byKey(savedFoodTileMetaKey('food-only-notes')), findsNothing);
    expect(find.text('冷藏保存，三天内吃完'), findsNothing);
  });

  testWidgets('the add-food FAB opens the two-option sheet', (
    WidgetTester tester,
  ) async {
    await _pumpLibrary(tester, foods: <Food>[labelMilk]);

    await tester.tap(find.byKey(foodLibraryAddButtonKey));
    await tester.pumpAndSettle();

    expect(find.byKey(foodLibraryAddSheetKey), findsOneWidget);
    expect(find.text('拍照识别营养标签'), findsOneWidget);
    expect(find.text('手动录入'), findsOneWidget);
    expect(find.text('拍营养成分表，AI 识别后保存'), findsOneWidget);
    expect(find.text('自己填写名称与营养数值，可离线'), findsOneWidget);
  });

  testWidgets('拍照识别营养标签 opens the label-capture photo step', (
    WidgetTester tester,
  ) async {
    await _pumpLibrary(tester);

    await tester.tap(find.byKey(foodLibraryEmptyAddButtonKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(foodLibraryAddPhotoKey));
    await tester.pumpAndSettle();

    expect(find.byType(LabelCaptureScreen), findsOneWidget);
    expect(find.text('识别营养标签'), findsOneWidget);
    expect(find.byKey(labelCameraButtonKey), findsOneWidget);
    expect(find.byKey(labelManualEntryButtonKey), findsOneWidget);
  });

  testWidgets(
    '手动录入 opens the blank confirm form and the saved food lands in the '
    'library after 完成',
    (WidgetTester tester) async {
      final FakeFoodRepository repo = await _pumpLibrary(tester);

      await tester.tap(find.byKey(foodLibraryEmptyAddButtonKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(foodLibraryAddManualKey));
      await tester.pumpAndSettle();

      // The manual mode skips the photo step: the blank confirm form is up.
      expect(find.byType(LabelCaptureScreen), findsOneWidget);
      expect(find.text('手动录入'), findsOneWidget);
      expect(find.byKey(labelNameFieldKey(0)), findsOneWidget);
      expect(find.byKey(labelCameraButtonKey), findsNothing);

      await tester.enterText(find.byKey(labelNameFieldKey(0)), '手输饼干');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('label_save_button')));
      await tester.pumpAndSettle();

      // Persisted as a saved food and the flow offers its way out.
      final List<Food> stored = await repo.getAllFoods();
      expect(stored, hasLength(1));
      expect(stored.single.name, '手输饼干');
      expect(find.byKey(labelDoneButtonKey), findsOneWidget);

      await tester.tap(find.byKey(labelDoneButtonKey));
      await tester.pumpAndSettle();

      // Back on the live library: the catalogue stream already shows it.
      expect(find.byKey(foodLibraryScreenKey), findsOneWidget);
      expect(find.text('手输饼干'), findsOneWidget);
      expect(find.text('食物库还是空的'), findsNothing);
    },
  );
}
