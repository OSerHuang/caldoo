// The 每日热量目标 sheet: preset selection drives the preview equation, saving
// stores the explicit number through the ProfileRepository port, 恢复默认
// clears the override, and the custom field validates + warns on very low
// values.
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
  }) async {
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
            body: DailyGoalSheet(profile: sheetProfile, bmrKcal: 1649),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return repo;
  }

  Finder preset(String name) => find.text(name);

  testWidgets('a preset drives the preview equation', (
    WidgetTester tester,
  ) async {
    await pumpSheet(tester);
    expect(
      find.text('不设目标，按基础代谢 1649 + 运动 220 = 每日额度 1869 大卡'),
      findsOneWidget,
      reason: 'no stored goal: the preview means "maintain"',
    );

    await tester.tap(preset('缓慢减脂'));
    await tester.pump();
    expect(
      find.text('目标 1399 + 运动 220 = 每日额度 1619 大卡'),
      findsOneWidget,
      reason: '1649 - 250 = 1399',
    );
  });

  testWidgets('保存 stores the explicit goal number', (
    WidgetTester tester,
  ) async {
    final FakeProfileRepository repo = await pumpSheet(tester);

    await tester.tap(preset('较快减脂'));
    await tester.pump();
    await tester.tap(find.byKey(goalSaveKey));
    await tester.pumpAndSettle();

    final UserProfile? saved = await repo.loadProfile();
    expect(saved!.dailyKcalGoalOverride, 1149, reason: '1649 - 500');
  });

  testWidgets('恢复默认 clears a stored goal', (WidgetTester tester) async {
    final FakeProfileRepository repo = await pumpSheet(
      tester,
      stored: profile.copyWith(dailyKcalGoalOverride: 1399),
    );

    await tester.tap(find.byKey(goalRestoreDefaultKey));
    await tester.pumpAndSettle();

    final UserProfile? saved = await repo.loadProfile();
    expect(saved!.dailyKcalGoalOverride, isNull);
  });

  testWidgets('a non-preset stored goal seeds the custom field', (
    WidgetTester tester,
  ) async {
    await pumpSheet(
      tester,
      stored: profile.copyWith(dailyKcalGoalOverride: 1234),
    );
    expect(find.text('1234'), findsOneWidget);
    expect(find.text('目标 1234 + 运动 220 = 每日额度 1454 大卡'), findsOneWidget);
  });

  testWidgets('a custom goal below 1200 shows the non-blocking hint', (
    WidgetTester tester,
  ) async {
    await pumpSheet(tester);
    await tester.enterText(find.byKey(goalCustomFieldKey), '1100');
    await tester.pump();

    expect(find.byKey(const Key('goal_low_hint')), findsOneWidget);
    expect(find.text('目标 1100 + 运动 220 = 每日额度 1320 大卡'), findsOneWidget);

    await tester.tap(find.byKey(goalSaveKey));
    await tester.pumpAndSettle();
    // The hint advises but never blocks: the value is stored.
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
