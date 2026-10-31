/// Widget tests for the saved-food editor (identity + structured supplement).
///
/// The editor owns name, brand, aliases, servings, active/archived and the
/// per-100 basis; nutrients are read-only. Nothing is persisted until 保存, a
/// blank name is rejected, and cleared fields really clear the stored values.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:caldoo/core/providers/app_providers.dart'
    show foodRepositoryProvider;
import 'package:caldoo/domain/models/models.dart';
import 'package:caldoo/features/meals/saved_foods/saved_food_notes_screen.dart';

import '../../../data/repositories/fake_repositories.dart';
import '_fixtures.dart';

class _Harness {
  _Harness(this.repo);

  final FakeFoodRepository repo;

  /// The food the editor popped back, once it was saved.
  Food? returned;
}

/// Host page that pushes the editor and captures its result.
class _Host extends StatelessWidget {
  const _Host({required this.food, required this.harness});

  final Food food;
  final _Harness harness;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: TextButton(
          key: const Key('open_editor'),
          onPressed: () async {
            harness.returned = await SavedFoodNotesScreen.push(context, food);
          },
          child: const Text('edit'),
        ),
      ),
    );
  }
}

Future<_Harness> _pumpEditor(WidgetTester tester, {required Food food}) async {
  final FakeFoodRepository repo = FakeFoodRepository();
  await repo.insertFood(food);
  final _Harness harness = _Harness(repo);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [foodRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(
        home: _Host(food: food, harness: harness),
      ),
    ),
  );
  await tester.tap(find.byKey(const Key('open_editor')));
  await tester.pumpAndSettle();
  return harness;
}

/// Gives the editor enough vertical space that every field is built.
void _tallViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 3200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

String _fieldText(WidgetTester tester, Key key) =>
    tester.widget<TextField>(find.byKey(key)).controller!.text;

/// Scrolls [finder] into the viewport, building it first when the editor's
/// [ListView] has not reached it yet.
Future<void> _ensure(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      300,
      scrollable: find.byType(Scrollable).first,
    );
  } else {
    await tester.ensureVisible(finder);
  }
  await tester.pumpAndSettle();
}

extension on WidgetTester {
  Future<void> tapAndSettle(Finder finder) async {
    await _ensure(this, finder);
    await tap(finder);
    await pumpAndSettle();
  }
}

Future<void> _enter(WidgetTester tester, Key key, String text) async {
  await _ensure(tester, find.byKey(key));
  await tester.enterText(find.byKey(key), text);
  await tester.pump();
}

Future<void> _save(WidgetTester tester) async {
  await tester.tapAndSettle(find.byKey(savedFoodNotesSaveButtonKey));
}

void main() {
  testWidgets('pre-fills identity, aliases, servings, status and basis', (
    WidgetTester tester,
  ) async {
    _tallViewport(tester);
    await _pumpEditor(tester, food: structuredOatMilk);

    expect(_fieldText(tester, savedFoodNotesNameFieldKey), '燕麦奶');
    expect(_fieldText(tester, savedFoodNotesBrandFieldKey), 'OATLY');
    expect(_fieldText(tester, savedFoodNotesAliasesFieldKey), '燕麦奶、oat milk');
    expect(
      _fieldText(tester, savedFoodNotesServingsFieldKey),
      '一盒 250 ml、一袋 120 g',
    );
    expect(find.text('每 100 ml'), findsOneWidget);
  });

  testWidgets('pre-fills a legacy food from its notes', (
    WidgetTester tester,
  ) async {
    _tallViewport(tester);
    const Food legacy = Food(
      id: 'food-legacy-kwark',
      name: 'AH Protein Kwark',
      source: FoodSource.label,
      notes: '标签 2026-09-14 | 一罐 450 g | 别名：ah kwark、夸克',
      kcal: 60,
    );
    final _Harness harness = await _pumpEditor(tester, food: legacy);

    expect(_fieldText(tester, savedFoodNotesAliasesFieldKey), 'ah kwark、夸克');
    expect(_fieldText(tester, savedFoodNotesServingsFieldKey), '一罐 450 g');

    // Saving migrates the prose into the structured fields and clears notes.
    await _save(tester);
    final Food stored = (await harness.repo.getFood('food-legacy-kwark'))!;
    expect(stored.aliases, <String>['ah kwark', '夸克']);
    expect(stored.servings.single.label, '一罐');
    expect(stored.notes, isNull);
  });

  testWidgets('saves name, brand and supplement in one write', (
    WidgetTester tester,
  ) async {
    _tallViewport(tester);
    final _Harness harness = await _pumpEditor(tester, food: labelMilk);

    await _enter(tester, savedFoodNotesNameFieldKey, '光明 全脂牛奶');
    await _enter(tester, savedFoodNotesBrandFieldKey, '蒙牛');
    await _enter(tester, savedFoodNotesAliasesFieldKey, '牛奶、纯牛奶');
    await _enter(tester, savedFoodNotesServingsFieldKey, '一盒 250 ml');
    await _enter(tester, savedFoodNotesServingsFieldKey, '一盒 250 ml、破损');
    await tester.tapAndSettle(find.byKey(savedFoodNotesStatusSwitchKey));
    await tester.tapAndSettle(find.text('每 100 ml'));
    await _save(tester);

    expect(harness.returned!.name, '光明 全脂牛奶');
    expect(harness.returned!.brand, '蒙牛');
    expect(harness.returned!.aliases, <String>['牛奶', '纯牛奶']);
    expect(harness.returned!.servings.single.label, '一盒');
    expect(harness.returned!.servings.single.amount, 250);
    expect(harness.returned!.status, FoodStatus.archived);
    expect(harness.returned!.basis, MeasureBasis.per100ml);
    expect(harness.returned!.notes, isNull, reason: 'the field is retired');

    final Food stored = (await harness.repo.getFood('food-label-milk'))!;
    expect(stored.name, '光明 全脂牛奶');
    expect(stored.brand, '蒙牛');
  });

  testWidgets('a blank name blocks the save', (WidgetTester tester) async {
    _tallViewport(tester);
    final _Harness harness = await _pumpEditor(tester, food: labelMilk);

    await _enter(tester, savedFoodNotesNameFieldKey, '   ');
    await _save(tester);

    expect(find.text('食物名称不能为空'), findsOneWidget);
    final Food stored = (await harness.repo.getFood('food-label-milk'))!;
    expect(stored.name, '全脂牛奶', reason: 'nothing was persisted');
    expect(harness.returned, isNull);
  });

  testWidgets('invalid servings are dropped and alias limits are enforced', (
    WidgetTester tester,
  ) async {
    _tallViewport(tester);
    final _Harness harness = await _pumpEditor(tester, food: labelMilk);

    await _enter(
      tester,
      savedFoodNotesServingsFieldKey,
      '一袋 120 g、随便写点什么、一块 30 g',
    );
    final String aliases = List<String>.generate(
      11,
      (int i) => '别${i.toString().padLeft(2, '0')}${'名' * 40}',
    ).join('、');
    await _enter(tester, savedFoodNotesAliasesFieldKey, aliases);
    await _save(tester);

    final Food stored = (await harness.repo.getFood('food-label-milk'))!;
    expect(stored.servings.map((FoodServing s) => s.label).toList(), <String>[
      '一袋',
      '一块',
    ]);
    expect(stored.aliases, hasLength(10));
    expect(stored.aliases.every((String a) => a.length <= 30), isTrue);
  });

  testWidgets('clearing the fields clears them in storage', (
    WidgetTester tester,
  ) async {
    _tallViewport(tester);
    final _Harness harness = await _pumpEditor(tester, food: structuredOatMilk);

    await _enter(tester, savedFoodNotesAliasesFieldKey, '');
    await _enter(tester, savedFoodNotesServingsFieldKey, '');
    await _enter(tester, savedFoodNotesBrandFieldKey, '');
    await _save(tester);

    final Food stored = (await harness.repo.getFood('food-structured-oat'))!;
    expect(stored.aliases, isEmpty);
    expect(stored.servings, isEmpty);
    expect(stored.brand, isNull);
    expect(stored.notes, isNull);
  });
}
