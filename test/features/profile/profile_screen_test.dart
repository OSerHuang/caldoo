/// Widget + unit tests for the profile & settings screen.
///
/// The repository port is overridden with the in-memory
/// [FakeProfileRepository], so no Drift database is opened. The budget shown
/// on screen comes from the real energy engine, so the assertions below prove
/// what the engine was actually fed — not what a stub returned.
///
/// The clock is pinned ([profileClockProvider]) because the age — and therefore
/// the derived BMR — is computed from the birthday against today's date.
library;

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:caldoo/core/math/energy_balance.dart';
import 'package:caldoo/core/providers/app_providers.dart';
import 'package:caldoo/core/units/display_units.dart';
import 'package:caldoo/core/units/nutrition_units.dart';
import 'package:caldoo/domain/models/user_profile.dart';
import 'package:caldoo/features/profile/profile_providers.dart';
import 'package:caldoo/features/profile/profile_screen.dart';

import '../../data/repositories/fake_repositories.dart';

/// Pinned "today" for every test in this file: a plain local date.
final DateTime _today = DateTime(2026, 10, 22);

/// The fixture birthday: exactly 30 years old on [_today].
final DateTime _birthday30 = DateTime.utc(1996, 10, 22);

/// Mifflin-St Jeor BMR for the fixture: male 30y, 175cm, 70kg.
/// `10*70 + 6.25*175 - 5*30 + 5 == 1648.75`, rounded once to whole kcal by the
/// engine -> **1649**.
const int _maleBmr = 1649;

/// A complete saved profile without a manual BMR override.
final UserProfile _autoProfile = UserProfile(
  sex: Sex.male,
  birthDate: _birthday30,
  heightCm: 175,
  weightKg: 70,
);

Future<ProviderContainer> _pumpProfile(
  WidgetTester tester,
  FakeProfileRepository repo, {
  DisplayUnits units = DisplayUnits.defaults,
}) async {
  // The screen is taller than the default 800x600 surface; a tall viewport
  // keeps every field, the salt card and the save button laid out (a lazy
  // ListView would otherwise not build the off-screen ones).
  tester.view.physicalSize = const Size(1200, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final ProviderContainer container = ProviderContainer(
    overrides: [
      profileRepositoryProvider.overrideWithValue(repo),
      profileClockProvider.overrideWithValue(Clock.fixed(_today)),
      // The goal sheet reads today's exercise burn; a canned 0 keeps the DB
      // unopened when a test taps the goal card.
      goalSheetExerciseKcalProvider.overrideWith(
        (Ref ref) => Future<int>.value(0),
      ),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: DisplayScope(
        units: units,
        child: const MaterialApp(home: ProfileScreen()),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

Future<void> _fillHeightWeight(WidgetTester tester) async {
  await tester.enterText(find.byKey(const Key('profile_height_field')), '175');
  await tester.enterText(find.byKey(const Key('profile_weight_field')), '70');
  await tester.pump();
}

/// Taps the birthday field and confirms the picker's default date.
///
/// The picker opens 30 years before the pinned today (1996-10-22), so this is
/// deterministic and exercises the real `showDatePicker` wiring.
Future<void> _pickDefaultBirthday(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('profile_birthday_field')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
}

/// The current text of the editable field identified by [key].
String _fieldText(WidgetTester tester, String key) {
  return tester.widget<TextField>(find.byKey(Key(key))).controller!.text;
}

String _bmrText(WidgetTester tester) => _fieldText(tester, 'profile_bmr_field');

/// The rendered value of the daily-goal card.
String _goalValue(WidgetTester tester) => tester
    .widget<Text>(find.byKey(const Key('profile_daily_goal_value')))
    .data!;

String _birthdayText(WidgetTester tester) {
  return tester
      .widget<Text>(find.byKey(const Key('profile_birthday_value')))
      .data!;
}

Finder _bmrAutoButton() => find.byKey(const Key('profile_bmr_auto_button'));

Future<void> _save(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('profile_save_button')));
  await tester.pumpAndSettle();
}

void main() {
  group('validateProfileInputs', () {
    test('accepts a past birthday plus positive height/weight', () {
      expect(
        validateProfileInputs(
          birthDate: _birthday30,
          height: '175',
          weight: '70',
          today: _today,
        ),
        isNull,
      );
    });

    test('accepts a positive manual BMR', () {
      expect(
        validateProfileInputs(
          birthDate: _birthday30,
          height: '175',
          weight: '70',
          bmr: '1800',
          today: _today,
        ),
        isNull,
      );
    });

    test('rejects a missing, future or less-than-one-year-old birthday', () {
      final List<DateTime?> malformed = <DateTime?>[
        null,
        DateTime.utc(2027, 1, 1), // future
        DateTime.utc(2026, 10, 22), // born today -> age 0
        DateTime.utc(2025, 12, 1), // age 0 on the pinned today
      ];
      for (final DateTime? birthDate in malformed) {
        expect(
          validateProfileInputs(
            birthDate: birthDate,
            height: '175',
            weight: '70',
            today: _today,
          ),
          isNotNull,
          reason: 'expected birthday rejection for $birthDate',
        );
      }
    });

    test('rejects blank, zero and negative height/weight', () {
      final List<({String height, String weight})> malformed =
          <({String height, String weight})>[
            (height: '', weight: '70'),
            (height: '0', weight: '70'),
            (height: '-170', weight: '70'),
            (height: '175', weight: ''),
            (height: '175', weight: '0'),
            (height: '175', weight: '-1'),
            (height: '175', weight: 'abc'),
          ];
      for (final ({String height, String weight}) input in malformed) {
        expect(
          validateProfileInputs(
            birthDate: _birthday30,
            height: input.height,
            weight: input.weight,
            today: _today,
          ),
          isNotNull,
          reason: 'expected rejection for $input',
        );
      }
    });

    test('rejects a blank, zero, negative or non-numeric manual BMR', () {
      for (final String bmr in <String>['', '0', '-1', 'abc']) {
        expect(
          validateProfileInputs(
            birthDate: _birthday30,
            height: '175',
            weight: '70',
            bmr: bmr,
            today: _today,
          ),
          isNotNull,
          reason: 'expected BMR rejection for "$bmr"',
        );
      }
    });
  });

  testWidgets('the screen has no activity-level picker anywhere', (
    WidgetTester tester,
  ) async {
    final FakeProfileRepository repo = FakeProfileRepository();
    addTearDown(repo.dispose);
    await _pumpProfile(tester, repo);

    expect(find.byKey(const Key('profile_activity_section')), findsNothing);
    expect(find.textContaining('活动量'), findsNothing);
    expect(find.textContaining('久坐'), findsNothing);
    expect(find.textContaining('不含刻意运动'), findsNothing);
    // There is no free-text age field either: the age is derived.
    expect(find.byKey(const Key('profile_age_field')), findsNothing);
    expect(find.text('年龄（岁）'), findsNothing);
  });

  testWidgets('the birthday is picked once and the age is derived live', (
    WidgetTester tester,
  ) async {
    final FakeProfileRepository repo = FakeProfileRepository();
    addTearDown(repo.dispose);
    final ProviderContainer container = await _pumpProfile(tester, repo);

    expect(_birthdayText(tester), '点击选择生日');
    expect(find.textContaining('年龄按生日自动计算'), findsOneWidget);

    await _pickDefaultBirthday(tester);
    expect(_birthdayText(tester), '1996年10月22日');
    expect(find.text('当前年龄：30 岁'), findsOneWidget);

    // No saved profile yet, so the budget is still hidden.
    expect(container.read(profileBudgetProvider), isA<ProfileIncomplete>());

    await _fillHeightWeight(tester);
    expect(_bmrText(tester), '1649');
    expect(_bmrAutoButton(), findsNothing);

    await _save(tester);
    final UserProfile? saved = await repo.loadProfile();
    expect(saved, isNotNull);
    expect(saved!.sex, Sex.male);
    expect(saved.birthDate, _birthday30);
    expect(saved.heightCm, 175);
    expect(saved.weightKg, 70);
    expect(saved.bmrKcalOverride, isNull);

    final EnergyBudget budget =
        container.read(profileBudgetProvider)! as EnergyBudget;
    expect(budget.bmrKcal, _maleBmr);
    expect(find.text('1649 kcal'), findsOneWidget);
  });

  testWidgets('a saved birthday seeds the field and the derived age', (
    WidgetTester tester,
  ) async {
    final FakeProfileRepository repo = FakeProfileRepository();
    addTearDown(repo.dispose);
    await repo.saveProfile(_autoProfile);
    await _pumpProfile(tester, repo);

    expect(_birthdayText(tester), '1996年10月22日');
    expect(find.text('当前年龄：30 岁'), findsOneWidget);
    expect(_bmrText(tester), '1649');
    expect(_bmrAutoButton(), findsNothing);
  });

  testWidgets('switching sex re-derives the age-based BMR estimate', (
    WidgetTester tester,
  ) async {
    final FakeProfileRepository repo = FakeProfileRepository();
    addTearDown(repo.dispose);
    await repo.saveProfile(_autoProfile);
    await _pumpProfile(tester, repo);

    await tester.tap(find.text('女'));
    await tester.pump();
    expect(_bmrText(tester), '1483'); // 1482.75 rounded

    await tester.tap(find.text('男'));
    await tester.pump();
    expect(_bmrText(tester), '1649'); // 1648.75 rounded
  });

  testWidgets('a typed BMR is stored as an override; 自动计算 restores it', (
    WidgetTester tester,
  ) async {
    final FakeProfileRepository repo = FakeProfileRepository();
    addTearDown(repo.dispose);
    await repo.saveProfile(_autoProfile);
    final ProviderContainer container = await _pumpProfile(tester, repo);

    await tester.enterText(find.byKey(const Key('profile_bmr_field')), '1800');
    await tester.pump();
    expect(_bmrAutoButton(), findsOneWidget);

    await _save(tester);
    UserProfile? saved = await repo.loadProfile();
    expect(saved!.bmrKcalOverride, 1800);
    EnergyBudget budget =
        container.read(profileBudgetProvider)! as EnergyBudget;
    expect(budget.baseBudgetKcal, 1800);
    expect(find.text('1800 kcal'), findsOneWidget);

    await tester.tap(_bmrAutoButton());
    await tester.pump();
    expect(_bmrText(tester), '1649');
    expect(_bmrAutoButton(), findsNothing);

    await _save(tester);
    saved = await repo.loadProfile();
    expect(saved!.bmrKcalOverride, isNull);
    budget = container.read(profileBudgetProvider)! as EnergyBudget;
    expect(budget.baseBudgetKcal, _maleBmr);
  });

  testWidgets('a stored override seeds the cell and ignores weight changes', (
    WidgetTester tester,
  ) async {
    final FakeProfileRepository repo = FakeProfileRepository();
    addTearDown(repo.dispose);
    await repo.saveProfile(_autoProfile.copyWith(bmrKcalOverride: 1800));
    await _pumpProfile(tester, repo);

    expect(_bmrText(tester), '1800');
    expect(_bmrAutoButton(), findsOneWidget);

    await tester.enterText(find.byKey(const Key('profile_weight_field')), '80');
    await tester.pump();
    expect(_bmrText(tester), '1800');

    await tester.tap(_bmrAutoButton());
    await tester.pump();
    // male 30y 175cm 80kg: 10*80 + 6.25*175 - 5*30 + 5 = 1748.75, rounded.
    expect(_bmrText(tester), '1749');
    expect(_bmrAutoButton(), findsNothing);
  });

  testWidgets(
    'an incomplete profile hides the budget and shows the 完善资料 prompt',
    (WidgetTester tester) async {
      final FakeProfileRepository repo = FakeProfileRepository();
      addTearDown(repo.dispose);
      final ProviderContainer container = await _pumpProfile(tester, repo);

      expect(
        find.byKey(const Key('profile_budget_incomplete')),
        findsOneWidget,
      );
      expect(find.text('完善资料以计算每日额度'), findsOneWidget);
      expect(find.byKey(const Key('profile_budget_value')), findsNothing);
      expect(container.read(profileBudgetProvider), isA<ProfileIncomplete>());

      await _pickDefaultBirthday(tester);
      await _fillHeightWeight(tester);
      await _save(tester);

      expect(find.byKey(const Key('profile_budget_incomplete')), findsNothing);
      expect(find.byKey(const Key('profile_budget_value')), findsOneWidget);
      expect(find.text('完善资料以计算每日额度'), findsNothing);
    },
  );

  testWidgets('saving the form preserves a fixed custom daily goal', (
    WidgetTester tester,
  ) async {
    // Regression: _save used to rebuild the profile from the form fields
    // alone, wiping dailyKcalGoalOverride on every 资料页保存.
    final FakeProfileRepository repo = FakeProfileRepository();
    addTearDown(repo.dispose);
    await repo.saveProfile(_autoProfile.copyWith(dailyKcalGoalOverride: 1399));
    await _pumpProfile(tester, repo);

    // The goal card shows the engine's goal (and so does the 基础额度 card —
    // with a goal set the baseline IS the goal). The subtitle marks it fixed.
    expect(find.byKey(const Key('profile_daily_goal')), findsOneWidget);
    expect(_goalValue(tester), '1399 kcal');
    expect(find.text('低于基础代谢 250 大卡/日（固定值，不随体重变化）'), findsOneWidget);

    // ...and a plain form save keeps it (untouched by this screen).
    await _save(tester);

    final UserProfile? saved = await repo.loadProfile();
    expect(saved!.dailyKcalGoalOverride, 1399);
    expect(saved.dailyGoalPreset, isNull);
    expect(find.text('低于基础代谢 250 大卡/日（固定值，不随体重变化）'), findsOneWidget);
  });

  testWidgets('saving the form preserves a stored preset goal', (
    WidgetTester tester,
  ) async {
    // Regression: the form save carries BOTH goal representations over; a
    // preset must not be wiped by an unrelated 资料页保存.
    final FakeProfileRepository repo = FakeProfileRepository();
    addTearDown(repo.dispose);
    await repo.saveProfile(
      _autoProfile.copyWith(dailyGoalPreset: DailyGoalPreset.gain),
    );
    await _pumpProfile(tester, repo);

    await _save(tester);

    final UserProfile? saved = await repo.loadProfile();
    expect(saved!.dailyGoalPreset, DailyGoalPreset.gain);
    expect(saved.dailyKcalGoalOverride, isNull);
    expect(find.text('高于基础代谢 250 大卡/日，随体重自动更新'), findsOneWidget);
  });

  testWidgets('a preset goal follows a body-weight change automatically', (
    WidgetTester tester,
  ) async {
    final FakeProfileRepository repo = FakeProfileRepository();
    addTearDown(repo.dispose);
    await repo.saveProfile(
      _autoProfile.copyWith(dailyGoalPreset: DailyGoalPreset.slowCut),
    );
    final ProviderContainer container = await _pumpProfile(tester, repo);

    // BMR 1649 - 250 = 1399.
    expect(_goalValue(tester), '1399 kcal');
    expect(find.text('低于基础代谢 250 大卡/日，随体重自动更新'), findsOneWidget);
    EnergyBudget budget =
        container.read(profileBudgetProvider)! as EnergyBudget;
    expect(budget.bmrKcal, _maleBmr);
    expect(budget.goalKcal, 1399);
    expect(budget.baseBudgetKcal, 1399);

    // A body-weight recording rewrites the profile weight (the same write
    // DriftWeightRepository.saveWeight performs, preserving the preset).
    // BMR 1649 -> 1633, so the preset goal moves 1399 -> 1383 on its own.
    await repo.saveProfile(
      _autoProfile.copyWith(
        weightKg: 68.4,
        dailyGoalPreset: DailyGoalPreset.slowCut,
      ),
    );
    await tester.pumpAndSettle();

    expect(_fieldText(tester, 'profile_weight_field'), '68.4');
    expect(_bmrText(tester), '1633');
    expect(_goalValue(tester), '1383 kcal');
    expect(find.text('低于基础代谢 250 大卡/日，随体重自动更新'), findsOneWidget);
    budget = container.read(profileBudgetProvider)! as EnergyBudget;
    expect(budget.goalKcal, 1383);
    expect(budget.baseBudgetKcal, 1383);

    // The goal sheet previews against the CURRENT (new) BMR as well.
    await tester.tap(find.byKey(const Key('profile_daily_goal')));
    await tester.pumpAndSettle();
    expect(find.text('目标 1383 + 运动 0 = 每日额度 1383 大卡'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
  });

  testWidgets('an external weight recording live-syncs the weight cell', (
    WidgetTester tester,
  ) async {
    // Regression: the form seeded its fields once, so a body-weight recording
    // (which rewrites the profile's weight externally) left a stale value in
    // the cell — and the next 保存 would write that stale value back.
    final FakeProfileRepository repo = FakeProfileRepository();
    addTearDown(repo.dispose);
    await repo.saveProfile(_autoProfile);
    await _pumpProfile(tester, repo);
    expect(_fieldText(tester, 'profile_weight_field'), '70');

    // Simulate the weight log path: the stored profile's weight changes
    // (the same write DriftWeightRepository.saveWeight performs).
    await repo.saveProfile(_autoProfile.copyWith(weightKg: 68.4));
    await tester.pumpAndSettle();

    expect(_fieldText(tester, 'profile_weight_field'), '68.4');
    // The derived BMR cell follows the new weight (auto mode, not pinned):
    // 10*68.4 + 6.25*175 - 5*30 + 5 == 1632.75 -> 1633.
    expect(_bmrText(tester), '1633');
  });

  testWidgets(
    'the fixed 5 g/day salt target renders read-only, no child mode',
    (WidgetTester tester) async {
      final FakeProfileRepository repo = FakeProfileRepository();
      addTearDown(repo.dispose);
      await _pumpProfile(tester, repo);

      expect(find.byKey(const Key('profile_salt_target')), findsOneWidget);
      expect(
        find.byKey(const Key('profile_salt_target_value')),
        findsOneWidget,
      );
      expect(find.text('5 g'), findsOneWidget);
      expect(dailySaltTargetG, 5.0);

      final Finder saltEditable = find.descendant(
        of: find.byKey(const Key('profile_salt_target')),
        matching: find.byType(EditableText),
      );
      expect(saltEditable, findsNothing);
      expect(find.byType(Switch), findsNothing);
      expect(find.byType(Checkbox), findsNothing);
    },
  );

  testWidgets(
    'the display preference shows the derived budget in kJ while the BMR input '
    'stays kcal',
    (WidgetTester tester) async {
      final FakeProfileRepository repo = FakeProfileRepository();
      addTearDown(repo.dispose);
      await _pumpProfile(
        tester,
        repo,
        units: const DisplayUnits(energy: EnergyDisplay.kj),
      );

      await _pickDefaultBirthday(tester);
      await _fillHeightWeight(tester);
      await _save(tester);

      // 1649 kcal * 4.184 = 6899.4 -> 6899 kJ (the engine value is untouched).
      expect(
        tester.widget<Text>(find.byKey(const Key('profile_budget_value'))).data,
        '6899 kJ',
      );
      // The BMR field is data entry: its label and digits stay canonical kcal.
      expect(find.text('基础代谢消耗 (kcal)'), findsOneWidget);
      expect(_bmrText(tester), '1649');
    },
  );

  testWidgets('the display preference switches the salt target to 钠 / mg', (
    WidgetTester tester,
  ) async {
    final FakeProfileRepository repo = FakeProfileRepository();
    addTearDown(repo.dispose);
    await _pumpProfile(
      tester,
      repo,
      units: const DisplayUnits(salt: SaltDisplay.sodium),
    );

    expect(find.text('每日钠目标'), findsOneWidget);
    expect(find.text('每日盐目标'), findsNothing);
    expect(
      tester
          .widget<Text>(find.byKey(const Key('profile_salt_target_value')))
          .data,
      '2000 mg',
    );
  });

  testWidgets('saving without a birthday is rejected and nothing is saved', (
    WidgetTester tester,
  ) async {
    final FakeProfileRepository repo = FakeProfileRepository();
    addTearDown(repo.dispose);
    await _pumpProfile(tester, repo);

    await _fillHeightWeight(tester);
    await _save(tester);

    expect(find.byKey(const Key('profile_validation_error')), findsOneWidget);
    expect(find.text('请选择生日（需早于今天，且年龄大于 0）'), findsOneWidget);
    expect(await repo.loadProfile(), isNull);
    expect(find.byKey(const Key('profile_budget_incomplete')), findsOneWidget);
  });

  testWidgets('non-positive height/weight are rejected and nothing is saved', (
    WidgetTester tester,
  ) async {
    final FakeProfileRepository repo = FakeProfileRepository();
    addTearDown(repo.dispose);
    await _pumpProfile(tester, repo);

    await _pickDefaultBirthday(tester);
    await tester.enterText(find.byKey(const Key('profile_height_field')), '0');
    await tester.enterText(find.byKey(const Key('profile_weight_field')), '70');
    await _save(tester);

    expect(find.byKey(const Key('profile_validation_error')), findsOneWidget);
    expect(await repo.loadProfile(), isNull);

    await tester.enterText(
      find.byKey(const Key('profile_height_field')),
      '175',
    );
    await tester.enterText(find.byKey(const Key('profile_weight_field')), '0');
    await _save(tester);

    expect(find.byKey(const Key('profile_validation_error')), findsOneWidget);
    expect(await repo.loadProfile(), isNull);
  });

  testWidgets('an invalid manual BMR is rejected and nothing is saved', (
    WidgetTester tester,
  ) async {
    final FakeProfileRepository repo = FakeProfileRepository();
    addTearDown(repo.dispose);
    await repo.saveProfile(_autoProfile);
    await _pumpProfile(tester, repo);

    await tester.enterText(find.byKey(const Key('profile_bmr_field')), '0');
    await tester.pump();
    await _save(tester);

    expect(find.byKey(const Key('profile_validation_error')), findsOneWidget);
    expect(find.text('基础代谢消耗需为大于 0 的数字'), findsOneWidget);
  });

  // MANUAL-QA channel: prints, in the raw widget-test output, what the screen
  // shows — the derived age/BMR, the persisted profile, and the prompt.
  testWidgets('MANUAL-QA: birthday, derived age/BMR, saved profile', (
    WidgetTester tester,
  ) async {
    final FakeProfileRepository repo = FakeProfileRepository();
    addTearDown(repo.dispose);
    final ProviderContainer container = await _pumpProfile(tester, repo);

    final Text prompt = tester.widget<Text>(
      find.byKey(const Key('profile_budget_incomplete')),
    );
    print('INCOMPLETE-PROFILE PROMPT: "${prompt.data}"');

    await _pickDefaultBirthday(tester);
    await _fillHeightWeight(tester);
    print(
      'BIRTHDAY CELL: "${_birthdayText(tester)}" · '
      'AGE/BMR: ${_bmrText(tester)}',
    );
    await _save(tester);

    final UserProfile saved = (await repo.loadProfile())!;
    final EnergyBudget budget =
        container.read(profileBudgetProvider)! as EnergyBudget;
    final String rendered = tester
        .widget<Text>(find.byKey(const Key('profile_budget_value')))
        .data!;
    print('SAVED PROFILE: ${saved.toJson()}');
    print(
      'ENGINE: bmr=${budget.bmrKcal}, base=${budget.baseBudgetKcal}, '
      'rendered="$rendered"',
    );
    expect(saved.ageOn(_today), 30);
    expect(saved.bmrKcalOverride, isNull);
    expect(budget.baseBudgetKcal, _maleBmr);
  });
}
