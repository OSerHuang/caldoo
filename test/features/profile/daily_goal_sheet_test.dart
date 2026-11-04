// The 每日热量目标 sheet: a preset is stored as a BMR-relative
// DailyGoalPreset (so it follows a weight change), a custom number as a fixed
// dailyKcalGoalOverride, 维持 clears both; 恢复默认 clears the goal; the custom
// field validates + warns on very low final goals. A legacy profile that only
// carries an absolute number is treated as a fixed custom value — never
// guessed back into a preset.
//
// dart format width=80
import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:caldoo/core/providers/app_providers.dart'
    show profileRepositoryProvider;
import 'package:caldoo/features/profile/daily_goal_sheet.dart';
import 'package:caldoo/features/profile/profile_providers.dart';
import 'package:caldoo/domain/models/user_profile.dart';

import '../../data/repositories/fake_repositories.dart';

void main() {
  final DateTime today = DateTime(2026, 10, 22);
  // Mifflin-St Jeor: male 30y 175cm 70kg -> 1648.75 -> 1649.
  final UserProfile profile = UserProfile(
    sex: Sex.male,
    birthDate: DateTime.utc(1996, 10, 22),
    heightCm: 175,
    weightKg: 70,
  );

  Future<FakeProfileRepository> pumpSheet(
    WidgetTester tester, {
    UserProfile? stored,
    int bmrKcal = 1649,
  }) async {
    // Tall enough for the whole sheet (presets + note + preview + actions).
    tester.view.physicalSize = const Size(900, 1500);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final FakeProfileRepository repo = FakeProfileRepository();
    final UserProfile sheetProfile = stored ?? profile;
    if (stored != null) {
      await repo.saveProfile(stored);
    }
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileRepositoryProvider.overrideWithValue(repo),
          profileClockProvider.overrideWithValue(Clock.fixed(today)),
          goalSheetExerciseKcalProvider.overrideWith(
            (Ref ref) => Future<int>.value(220),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: DailyGoalSheet(profile: sheetProfile, bmrKcal: bmrKcal),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return repo;
  }

  Finder preset(String name) => find.text(name);

  /// The radio icon inside the row labelled [name] (checked or not).
  Finder presetRadio(String name, {required bool selected}) => find.descendant(
    of: find.ancestor(of: find.text(name), matching: find.byType(InkWell)),
    matching: find.byIcon(
      selected ? Icons.radio_button_checked : Icons.radio_button_off,
    ),
  );

  String customFieldText(WidgetTester tester) =>
      tester.widget<TextField>(find.byKey(goalCustomFieldKey)).controller!.text;

  testWidgets('no stored goal opens on 维持 and previews the BMR', (
    WidgetTester tester,
  ) async {
    await pumpSheet(tester);
    expect(
      find.text('不设目标，按基础代谢 1649 + 运动 220 = 每日额度 1869 大卡'),
      findsOneWidget,
      reason: 'no stored goal: the preview means "maintain"',
    );
    expect(presetRadio('维持体重', selected: true), findsOneWidget);

    // The preset-vs-custom explanation is always visible.
    expect(find.byKey(goalPresetNoteKey), findsOneWidget);
    expect(find.text('档位按基础代谢计算，体重变化后每日额度会自动更新；自定义数值固定不变。'), findsOneWidget);
  });

  testWidgets('a preset drives the preview equation', (
    WidgetTester tester,
  ) async {
    await pumpSheet(tester);

    await tester.tap(preset('缓慢减脂'));
    await tester.pump();
    expect(
      find.text('目标 1399 + 运动 220 = 每日额度 1619 大卡'),
      findsOneWidget,
      reason: '1649 - 250 = 1399',
    );
    expect(customFieldText(tester), isEmpty, reason: 'a preset is not custom');
  });

  testWidgets('保存 stores a preset instead of a fixed number', (
    WidgetTester tester,
  ) async {
    final FakeProfileRepository repo = await pumpSheet(tester);

    await tester.tap(preset('较快减脂'));
    await tester.pump();
    await tester.tap(find.byKey(goalSaveKey));
    await tester.pumpAndSettle();

    final UserProfile? saved = await repo.loadProfile();
    expect(saved!.dailyGoalPreset, DailyGoalPreset.fastCut);
    expect(
      saved.dailyKcalGoalOverride,
      isNull,
      reason: 'a preset must not be frozen into an absolute number',
    );
  });

  testWidgets('保存 a custom number stores a fixed override, preset cleared', (
    WidgetTester tester,
  ) async {
    final FakeProfileRepository repo = await pumpSheet(
      tester,
      stored: profile.copyWith(dailyGoalPreset: DailyGoalPreset.slowCut),
    );
    expect(customFieldText(tester), isEmpty);

    await tester.enterText(find.byKey(goalCustomFieldKey), '1500');
    await tester.pump();
    await tester.tap(find.byKey(goalSaveKey));
    await tester.pumpAndSettle();

    final UserProfile? saved = await repo.loadProfile();
    expect(saved!.dailyKcalGoalOverride, 1500);
    expect(saved.dailyGoalPreset, isNull);
  });

  testWidgets('维持体重 clears a stored preset', (WidgetTester tester) async {
    final FakeProfileRepository repo = await pumpSheet(
      tester,
      stored: profile.copyWith(dailyGoalPreset: DailyGoalPreset.slowCut),
    );

    await tester.tap(preset('维持体重'));
    await tester.pump();
    await tester.tap(find.byKey(goalSaveKey));
    await tester.pumpAndSettle();

    final UserProfile? saved = await repo.loadProfile();
    expect(saved!.dailyGoalPreset, isNull);
    expect(saved.dailyKcalGoalOverride, isNull);
  });

  testWidgets('恢复默认 clears both goal representations', (
    WidgetTester tester,
  ) async {
    final FakeProfileRepository repo = await pumpSheet(
      tester,
      stored: profile.copyWith(dailyGoalPreset: DailyGoalPreset.gain),
    );

    await tester.tap(find.byKey(goalRestoreDefaultKey));
    await tester.pumpAndSettle();

    final UserProfile? saved = await repo.loadProfile();
    expect(saved!.dailyGoalPreset, isNull);
    expect(saved.dailyKcalGoalOverride, isNull);
  });

  testWidgets('a stored preset highlights its row and previews bmr + delta', (
    WidgetTester tester,
  ) async {
    await pumpSheet(
      tester,
      stored: profile.copyWith(dailyGoalPreset: DailyGoalPreset.slowCut),
    );

    expect(presetRadio('缓慢减脂', selected: true), findsOneWidget);
    expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
    expect(customFieldText(tester), isEmpty);
    expect(find.text('目标 1399 + 运动 220 = 每日额度 1619 大卡'), findsOneWidget);
  });

  testWidgets('a legacy absolute goal is a fixed custom value, not a preset', (
    WidgetTester tester,
  ) async {
    // 1399 happens to equal 1649 - 250, but it was stored as a fixed number
    // before presets existed: it must NOT be inferred back into 缓慢减脂.
    await pumpSheet(
      tester,
      stored: profile.copyWith(dailyKcalGoalOverride: 1399),
    );

    expect(customFieldText(tester), '1399');
    expect(find.byIcon(Icons.radio_button_checked), findsNothing);
    expect(find.text('目标 1399 + 运动 220 = 每日额度 1619 大卡'), findsOneWidget);
  });

  testWidgets('a non-preset stored goal seeds the custom field', (
    WidgetTester tester,
  ) async {
    await pumpSheet(
      tester,
      stored: profile.copyWith(dailyKcalGoalOverride: 1234),
    );
    expect(
      tester.widget<TextField>(find.byKey(goalCustomFieldKey)).controller!.text,
      '1234',
    );
    expect(find.text('目标 1234 + 运动 220 = 每日额度 1454 大卡'), findsOneWidget);
  });

  testWidgets('a custom goal below 1200 shows the non-blocking hint', (
    WidgetTester tester,
  ) async {
    final FakeProfileRepository repo = await pumpSheet(tester);
    await tester.enterText(find.byKey(goalCustomFieldKey), '1100');
    await tester.pump();

    expect(find.byKey(const Key('goal_low_hint')), findsOneWidget);
    expect(find.text('目标 1100 + 运动 220 = 每日额度 1320 大卡'), findsOneWidget);

    await tester.tap(find.byKey(goalSaveKey));
    await tester.pumpAndSettle();
    // The hint advises but never blocks: the value is stored.
    final UserProfile? saved = await repo.loadProfile();
    expect(saved!.dailyKcalGoalOverride, 1100);
  });

  testWidgets('the low hint also applies to a low preset-derived goal', (
    WidgetTester tester,
  ) async {
    await pumpSheet(tester);

    // 1649 - 500 = 1149 < 1200: the hint tracks the FINAL effective goal, not
    // just what was typed into the custom field.
    await tester.tap(preset('较快减脂'));
    await tester.pump();
    expect(find.text('目标 1149 + 运动 220 = 每日额度 1369 大卡'), findsOneWidget);
    expect(find.byKey(const Key('goal_low_hint')), findsOneWidget);
  });

  testWidgets('a stored preset previews against the CURRENT BMR', (
    WidgetTester tester,
  ) async {
    // A body-weight change (70 -> 68.4 kg) re-derives the BMR 1649 -> 1633,
    // so 缓慢减脂 moves 1399 -> 1383 without anything being re-saved.
    await pumpSheet(
      tester,
      stored: profile.copyWith(
        weightKg: 68.4,
        dailyGoalPreset: DailyGoalPreset.slowCut,
      ),
      bmrKcal: 1633,
    );

    expect(presetRadio('缓慢减脂', selected: true), findsOneWidget);
    expect(customFieldText(tester), isEmpty);
    expect(find.text('目标 1383 + 运动 220 = 每日额度 1603 大卡'), findsOneWidget);
  });

  testWidgets('a zero custom goal is rejected with the validation error', (
    WidgetTester tester,
  ) async {
    await pumpSheet(tester);
    await tester.enterText(find.byKey(goalCustomFieldKey), '0');
    await tester.pump();
    await tester.tap(find.byKey(goalSaveKey));
    await tester.pump();

    expect(find.byKey(const Key('goal_validation_error')), findsOneWidget);
  });
}
