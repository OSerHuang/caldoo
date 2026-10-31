import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:caldoo/core/providers/app_providers.dart';
import 'package:caldoo/domain/models/models.dart';
import 'package:caldoo/features/meals/saved_foods/saved_food_detail_screen.dart';
import 'package:caldoo/features/meals/saved_foods/saved_food_picker.dart';

import '../../../data/repositories/fake_repositories.dart';
import '_fixtures.dart';

Future<void> _pumpPicker(WidgetTester tester, List<Food> foods) async {
  final FakeFoodRepository repo = FakeFoodRepository();
  for (final Food food in foods) {
    await repo.insertFood(food);
  }
  await tester.pumpWidget(
    ProviderScope(
      overrides: [foodRepositoryProvider.overrideWithValue(repo)],
      child: const MaterialApp(home: SavedFoodPicker()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('lists saved foods with a per-food source badge', (
    WidgetTester tester,
  ) async {
    await _pumpPicker(tester, <Food>[labelMilk, aiVeg]);

    // The official-label pill is hidden; only non-authoritative sources show.
    expect(find.text('官方标签'), findsNothing);
    expect(find.text('AI估算'), findsOneWidget);
    expect(find.byKey(savedFoodTileKey('food-label-milk')), findsOneWidget);
    expect(find.byKey(savedFoodTileKey('food-ai-veg')), findsOneWidget);
  });

  testWidgets('search filters the list and a blank query restores it', (
    WidgetTester tester,
  ) async {
    await _pumpPicker(tester, <Food>[labelMilk, aiVeg]);

    await tester.enterText(find.byKey(savedFoodSearchFieldKey), '牛奶');
    await tester.pumpAndSettle();
    expect(find.byKey(savedFoodTileKey('food-label-milk')), findsOneWidget);
    expect(find.byKey(savedFoodTileKey('food-ai-veg')), findsNothing);

    await tester.enterText(find.byKey(savedFoodSearchFieldKey), '');
    await tester.pumpAndSettle();
    expect(find.byKey(savedFoodTileKey('food-ai-veg')), findsOneWidget);
  });

  testWidgets('a no-match search shows an empty state, not a crash', (
    WidgetTester tester,
  ) async {
    await _pumpPicker(tester, <Food>[labelMilk]);

    await tester.enterText(find.byKey(savedFoodSearchFieldKey), '汉堡');
    await tester.pumpAndSettle();
    expect(find.text('没有匹配的已存食物'), findsOneWidget);
  });

  testWidgets('tapping a food pops it back to the caller', (
    WidgetTester tester,
  ) async {
    final FakeFoodRepository repo = FakeFoodRepository();
    await repo.insertFood(labelMilk);
    Food? selected;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [foodRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (BuildContext context) => TextButton(
                onPressed: () async {
                  selected = await SavedFoodPicker.push(context);
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(savedFoodTileKey('food-label-milk')));
    await tester.pumpAndSettle();

    expect(selected?.id, 'food-label-milk');
  });

  testWidgets('the info button opens the details without choosing a food', (
    WidgetTester tester,
  ) async {
    final FakeFoodRepository repo = FakeFoodRepository();
    await repo.insertFood(labelMilk);
    Food? selected;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [foodRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (BuildContext context) => TextButton(
                onPressed: () async {
                  selected = await SavedFoodPicker.push(context);
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(savedFoodInfoKey('food-label-milk')));
    await tester.pumpAndSettle();

    // The detail is shown and the picker has not completed a choice.
    expect(find.byKey(savedFoodDetailScreenKey), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(savedFoodDetailNameKey)).data,
      '全脂牛奶',
    );
    expect(selected, isNull);

    // Back on the picker, tapping the row still selects and pops.
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(savedFoodTileKey('food-label-milk')));
    await tester.pumpAndSettle();
    expect(selected?.id, 'food-label-milk');
  });
}
