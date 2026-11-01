/// Widget tests for the read-only saved-food detail page.
///
/// Covers the bug report "点击已保存的食物标签不能查看信息": every saved food
/// now has an inspectable detail page showing its provenance and per-100 g
/// values, and a blank field is displayed as 未提供 instead of a fabricated 0.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:caldoo/core/providers/app_providers.dart'
    show foodRepositoryProvider;
import 'package:caldoo/core/units/display_units.dart';
import 'package:caldoo/domain/models/models.dart';
import 'package:caldoo/features/meals/label/label_capture_screen.dart'
    show labelFieldKey, labelNameFieldKey, labelNotesFieldKey;
import 'package:caldoo/features/meals/label/label_draft.dart' show LabelField;
import 'package:caldoo/features/meals/saved_foods/saved_food_detail_screen.dart';
import 'package:caldoo/features/meals/saved_foods/saved_food_notes_screen.dart';

import '../../../data/repositories/fake_repositories.dart';
import '_fixtures.dart';

Future<void> _pumpDetail(
  WidgetTester tester,
  Food food, {
  DisplayUnits? units,
}) async {
  final FakeFoodRepository repo = FakeFoodRepository();
  await repo.insertFood(food);
  final Widget app = ProviderScope(
    overrides: [foodRepositoryProvider.overrideWithValue(repo)],
    child: MaterialApp(home: SavedFoodDetailScreen(food: food)),
  );
  await tester.pumpWidget(
    units == null ? app : DisplayScope(units: units, child: app),
  );
  await tester.pumpAndSettle();
}

String _text(WidgetTester tester, Key key) =>
    tester.widget<Text>(find.byKey(key)).data!;

void main() {
  testWidgets('shows the identity rows and per-100 g label values', (
    WidgetTester tester,
  ) async {
    await _pumpDetail(tester, labelMilk);

    expect(find.byKey(savedFoodDetailScreenKey), findsOneWidget);
    expect(find.text('食物信息'), findsOneWidget);
    expect(find.text('基本信息'), findsOneWidget);
    expect(_text(tester, savedFoodDetailNameKey), '全脂牛奶');
    // Brand / aliases / servings / status / basis are separate rows.
    expect(_text(tester, savedFoodDetailBrandKey), '光明');
    expect(_text(tester, savedFoodDetailAliasesKey), '未填写');
    expect(_text(tester, savedFoodDetailServingsKey), '未填写');
    expect(_text(tester, savedFoodDetailStatusKey), '仍在使用');
    expect(_text(tester, savedFoodDetailBasisKey), '每 100 g');
    // The official-label pill is gone; it says nothing on a label catalogue.
    expect(find.text('官方标签'), findsNothing);
    expect(find.text('营养成分（每 100 g）'), findsOneWidget);

    expect(_text(tester, savedFoodDetailValueKey('kcal')), '200');
    expect(_text(tester, savedFoodDetailValueKey('carb')), '20');
    expect(_text(tester, savedFoodDetailValueKey('protein')), '10');
    expect(_text(tester, savedFoodDetailValueKey('fat')), '5');
    // Food stores sodium in mg; the detail shows the derived salt in g.
    expect(_text(tester, savedFoodDetailValueKey('salt')), '0.5');
  });

  testWidgets('a blank nutrient renders 未提供, never 0', (
    WidgetTester tester,
  ) async {
    await _pumpDetail(
      tester,
      const Food(
        id: 'food-energy-only',
        name: '只有能量',
        source: FoodSource.label,
        kcal: 120,
      ),
    );

    expect(_text(tester, savedFoodDetailValueKey('kcal')), '120');
    for (final String field in <String>['carb', 'protein', 'fat', 'salt']) {
      expect(_text(tester, savedFoodDetailValueKey(field)), '未提供');
    }
    expect(find.text('0'), findsNothing);
  });

  testWidgets('a kJ + sodium preference converts the per-100 readouts', (
    WidgetTester tester,
  ) async {
    await _pumpDetail(
      tester,
      labelMilk,
      units: const DisplayUnits(
        energy: EnergyDisplay.kj,
        salt: SaltDisplay.sodium,
      ),
    );

    // 200 kcal -> 836.8 -> 837 kJ; the stored 200 mg sodium is shown as-is.
    expect(_text(tester, savedFoodDetailValueKey('kcal')), '837');
    expect(find.text('kJ'), findsOneWidget);
    expect(_text(tester, savedFoodDetailValueKey('salt')), '200');
    expect(find.text('钠'), findsOneWidget);
    expect(find.text('mg'), findsOneWidget);
    // The macro rows keep their gram unit.
    expect(_text(tester, savedFoodDetailValueKey('carb')), '20');
    expect(find.text('g'), findsNWidgets(3));
  });

  testWidgets('a blank readout stays 未提供 in kJ + sodium mode', (
    WidgetTester tester,
  ) async {
    await _pumpDetail(
      tester,
      const Food(
        id: 'food-partial',
        name: '部分字段',
        source: FoodSource.label,
        sodiumMg: 120,
      ),
      units: const DisplayUnits(
        energy: EnergyDisplay.kj,
        salt: SaltDisplay.sodium,
      ),
    );

    // A missing energy value converts to nothing, never a fabricated 0 / unit.
    expect(_text(tester, savedFoodDetailValueKey('kcal')), '未提供');
    expect(find.text('kJ'), findsNothing);
    // A declared sodium value shows as-is (canonical mg in sodium mode).
    expect(_text(tester, savedFoodDetailValueKey('salt')), '120');
    expect(find.text('钠'), findsOneWidget);
    expect(find.text('mg'), findsOneWidget);
  });

  testWidgets('parses a legacy food\'s aliases into the separate rows', (
    WidgetTester tester,
  ) async {
    await _pumpDetail(tester, aliasedFood);

    expect(_text(tester, savedFoodDetailNameKey), '苏打饼干');
    expect(_text(tester, savedFoodDetailBrandKey), '未填写');
    // Legacy prose still produces the separate alias/serving rows.
    expect(_text(tester, savedFoodDetailAliasesKey), '小饼干');
    expect(_text(tester, savedFoodDetailServingsKey), '一包 45 g');
    // A non-authoritative source keeps its badge.
    expect(find.text('手动录入'), findsOneWidget);
  });

  testWidgets('an AI estimate keeps its badge', (WidgetTester tester) async {
    await _pumpDetail(tester, aiVeg);

    expect(find.text('AI估算'), findsOneWidget);
  });

  testWidgets('shows the structured aliases, servings and per-100 ml basis', (
    WidgetTester tester,
  ) async {
    await _pumpDetail(tester, structuredOatMilk);

    expect(_text(tester, savedFoodDetailAliasesKey), '燕麦奶、oat milk');
    expect(_text(tester, savedFoodDetailServingsKey), '一盒 250 ml、一袋 120 g');
    expect(_text(tester, savedFoodDetailBasisKey), '每 100 ml');
    expect(find.text('营养成分（每 100 ml）'), findsOneWidget);
    // Status is shown for every food, active included.
    expect(_text(tester, savedFoodDetailStatusKey), '仍在使用');
  });

  testWidgets('missing identity fields render 未填写, never disappear', (
    WidgetTester tester,
  ) async {
    await _pumpDetail(tester, labelMilk);

    expect(_text(tester, savedFoodDetailAliasesKey), '未填写');
    expect(_text(tester, savedFoodDetailServingsKey), '未填写');
    expect(_text(tester, savedFoodDetailBasisKey), '每 100 g');
    expect(find.text('营养成分（每 100 g）'), findsOneWidget);
  });

  testWidgets('sugar and saturated fat render only when declared', (
    WidgetTester tester,
  ) async {
    await _pumpDetail(
      tester,
      const Food(
        id: 'food-declared',
        name: '含糖饼干',
        source: FoodSource.label,
        kcal: 400,
        sugarG: 18.5,
        saturatedFatG: 3.2,
      ),
    );
    expect(_text(tester, savedFoodDetailValueKey('sugar')), '18.5');
    expect(_text(tester, savedFoodDetailValueKey('saturatedFat')), '3.2');
  });

  testWidgets('undeclared sugar / saturated fat are hidden, not 0', (
    WidgetTester tester,
  ) async {
    await _pumpDetail(
      tester,
      const Food(
        id: 'food-plain',
        name: '无声明',
        source: FoodSource.label,
        kcal: 100,
      ),
    );
    expect(find.byKey(savedFoodDetailValueKey('sugar')), findsNothing);
    expect(find.byKey(savedFoodDetailValueKey('saturatedFat')), findsNothing);
  });

  testWidgets('an archived food shows the archived status row', (
    WidgetTester tester,
  ) async {
    await _pumpDetail(tester, archivedBiscuit);

    expect(_text(tester, savedFoodDetailStatusKey), '已停用');
    // The alias row is rendered even for an archived food.
    expect(_text(tester, savedFoodDetailAliasesKey), '旧饼干');
  });

  supplementTests();
  deleteTests();
}

/// Pumps the detail page over a placeholder catalogue screen, pushed the way
/// the 食物库 pushes it, so the delete action's pop has somewhere to land.
/// Returns the fake repository the detail page reads.
Future<FakeFoodRepository> _pumpDetailPushed(
  WidgetTester tester,
  Food food,
) async {
  final FakeFoodRepository repo = FakeFoodRepository();
  await repo.insertFood(food);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [foodRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(
        home: Builder(
          builder: (BuildContext context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => SavedFoodDetailScreen.push(context, food),
                child: const Text('食物库'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('食物库'));
  await tester.pumpAndSettle();
  return repo;
}

/// Pumps the detail page with the providers the supplement editor needs.
Future<void> _pumpDetailWithProviders(WidgetTester tester, Food food) async {
  final FakeFoodRepository repo = FakeFoodRepository();
  await repo.insertFood(food);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [foodRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(home: SavedFoodDetailScreen(food: food)),
    ),
  );
  await tester.pumpAndSettle();
}

/// Scrolls [finder] into the viewport, building it first when the enclosing
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

/// Scrolls [finder] into view, then taps it.
Future<void> _tap(WidgetTester tester, Finder finder) async {
  await _ensure(tester, finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Pushes [text] into the editor field [key].
Future<void> _enter(WidgetTester tester, Key key, String text) async {
  await _ensure(tester, find.byKey(key));
  await tester.enterText(find.byKey(key), text);
  await tester.pump();
}

void supplementTests() {
  testWidgets('the app-bar 编辑 action opens the editor and saves changes', (
    WidgetTester tester,
  ) async {
    await _pumpDetailWithProviders(tester, labelMilk);

    expect(find.byKey(savedFoodDetailNotesEditKey), findsOneWidget);
    // The retired 补充说明 field is gone from the detail page entirely.
    expect(find.text('补充说明'), findsNothing);

    await _tap(tester, find.byKey(savedFoodDetailNotesEditKey));
    expect(find.byKey(savedFoodNotesScreenKey), findsOneWidget);

    await _enter(tester, savedFoodNotesNameFieldKey, '光明 全脂牛奶');
    await _enter(tester, savedFoodNotesAliasesFieldKey, '牛奶、纯牛奶');
    await _enter(tester, savedFoodNotesServingsFieldKey, '一盒 250 ml');
    await _tap(tester, find.byKey(savedFoodNotesStatusSwitchKey));
    await _tap(tester, find.text('每 100 ml'));
    await _tap(tester, find.byKey(savedFoodNotesSaveButtonKey));

    // Back on the detail page, showing the freshly saved identity.
    expect(find.byKey(savedFoodDetailScreenKey), findsOneWidget);
    expect(_text(tester, savedFoodDetailNameKey), '光明 全脂牛奶');
    expect(_text(tester, savedFoodDetailAliasesKey), '牛奶、纯牛奶');
    expect(_text(tester, savedFoodDetailServingsKey), '一盒 250 ml');
    expect(_text(tester, savedFoodDetailBasisKey), '每 100 ml');
    expect(_text(tester, savedFoodDetailStatusKey), '已停用');
    // The authoritative nutrient values are untouched by the identity edit.
    expect(_text(tester, savedFoodDetailValueKey('kcal')), '200');
  });

  testWidgets('the 编辑数值 action opens the nutrient editor and adopts the '
      'result', (WidgetTester tester) async {
    final FakeFoodRepository repo = await _pumpDetailPushed(tester, labelMilk);

    await _tap(tester, find.byKey(savedFoodDetailNutrientsEditKey));

    // The label confirm form, pre-filled with the stored food and showing the
    // edit copy; the notes field and include switch are capture-only.
    expect(find.text('编辑数值'), findsOneWidget);
    expect(find.text('修改后保存，将直接更新这个食物（每 100 g / 100 mL）'), findsOneWidget);
    expect(_field(tester, labelNameFieldKey(0)), '全脂牛奶');
    expect(_field(tester, labelFieldKey(0, LabelField.energy)), '200');
    expect(find.byKey(labelNotesFieldKey(0)), findsNothing);

    // Correct the energy to 180 kcal and save.
    await tester.enterText(
      find.byKey(labelFieldKey(0, LabelField.energy)),
      '180',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('label_save_button')));
    await tester.pumpAndSettle();

    // Back on the detail page with the adopted update, repository updated in
    // place (same id, no duplicate).
    expect(find.byKey(savedFoodDetailScreenKey), findsOneWidget);
    expect(_text(tester, savedFoodDetailValueKey('kcal')), '180');
    final Food? stored = await repo.getFood(labelMilk.id);
    expect(stored!.kcal, 180);
    expect(await repo.getAllFoods(), hasLength(1));
  });
}

/// Reads a text field's current controller text (the displayed value).
String _field(WidgetTester tester, Key key) =>
    tester.widget<TextField>(find.byKey(key)).controller!.text;

/// Widget tests for the food-library delete action (the app-bar 删除 icon on
/// the detail page): the confirm dialog is mandatory, cancelling keeps the
/// food, confirming deletes it from the repository and pops back.
void deleteTests() {
  testWidgets('the delete action confirms, and cancelling keeps the food', (
    WidgetTester tester,
  ) async {
    final FakeFoodRepository repo = await _pumpDetailPushed(tester, labelMilk);

    await tester.tap(find.byKey(savedFoodDetailDeleteKey));
    await tester.pumpAndSettle();

    // The dialog names the food and states the meal-record contract.
    expect(find.byKey(savedFoodDetailDeleteDialogKey), findsOneWidget);
    expect(find.text('删除这个食物？'), findsOneWidget);
    expect(find.text('「全脂牛奶」会从食物库移除。已有的饮食记录不受影响。'), findsOneWidget);

    // Cancel: strict no-op.
    await tester.tap(find.byKey(savedFoodDetailDeleteCancelKey));
    await tester.pumpAndSettle();
    expect(find.byKey(savedFoodDetailDeleteDialogKey), findsNothing);
    expect(find.byKey(savedFoodDetailScreenKey), findsOneWidget);
    expect(await repo.getFood(labelMilk.id), isNotNull);
  });

  testWidgets('confirming the dialog deletes the food and pops back', (
    WidgetTester tester,
  ) async {
    final FakeFoodRepository repo = await _pumpDetailPushed(tester, labelMilk);

    await tester.tap(find.byKey(savedFoodDetailDeleteKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(savedFoodDetailDeleteConfirmKey));
    await tester.pumpAndSettle();

    // Popped back to the catalogue, snackbar confirms, row gone from storage.
    expect(find.byKey(savedFoodDetailScreenKey), findsNothing);
    expect(find.text('已删除'), findsOneWidget);
    expect(await repo.getFood(labelMilk.id), isNull);
  });
}
