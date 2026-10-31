/// Task 24 (MANUAL-QA CHANNEL): the daily summary dashboard widget test.
///
/// Drives the real providers against in-memory fakes and the task-7 fixture.
/// The two headline cases are printed to stdout with their exact numbers:
/// * intake 1936 / budget 2236 -> 缺口 300;
/// * intake 2536 / budget 2236 -> 盈余 300.
///
/// Also covered: the incomplete profile hides the budget AND the balance (no
/// deficit is shown without a budget), and the numbers are live over the
/// repository `watch` streams.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:caldoo/core/providers/app_providers.dart';
import 'package:caldoo/core/time/date_windows.dart';
import 'package:caldoo/core/time/day_tick_provider.dart';
import 'package:caldoo/core/ui/thin_progress_bar.dart';
import 'package:caldoo/core/units/display_units.dart';
import 'package:caldoo/domain/models/day_rollup.dart';
import 'package:caldoo/features/dashboard/daily/daily_summary.dart';
import 'package:caldoo/features/dashboard/daily/daily_summary_providers.dart';
import 'package:caldoo/features/dashboard/daily/daily_summary_view.dart';

import '../../../data/repositories/fake_repositories.dart';
import '_fixtures.dart';

/// The display preference pair the kJ / sodium cases install: kJ for energy,
/// sodium for the salt tile.
const DisplayUnits metricUnits = DisplayUnits(
  energy: EnergyDisplay.kj,
  salt: SaltDisplay.sodium,
);

String _text(WidgetTester tester, Key key) =>
    tester.widget<Text>(find.byKey(key)).data!;

Color? _color(WidgetTester tester, Key key) =>
    tester.widget<Text>(find.byKey(key)).style?.color;

void main() {
  late FakeMealRepository mealRepo;
  late FakeExerciseRepository exerciseRepo;
  late FakeProfileRepository profileRepo;

  setUp(() {
    mealRepo = FakeMealRepository();
    exerciseRepo = FakeExerciseRepository();
    profileRepo = FakeProfileRepository();
  });

  tearDown(() async {
    await mealRepo.dispose();
    await exerciseRepo.dispose();
    await profileRepo.dispose();
  });

  /// Pumps the dashboard over the fakes and returns the live container.
  ///
  /// [units] installs the display preference above the app; the default
  /// (kcal + salt) reproduces the historical surface, so it is also what the
  /// existing tests run under.
  Future<ProviderContainer> pumpDashboard(
    WidgetTester tester, {
    DisplayUnits units = DisplayUnits.defaults,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mealRepositoryProvider.overrideWithValue(mealRepo),
          exerciseRepositoryProvider.overrideWithValue(exerciseRepo),
          profileRepositoryProvider.overrideWithValue(profileRepo),
          dashboardClockProvider.overrideWithValue(dashboardClock()),
          dashboardOffsetProvider.overrideWithValue(dashboardOffset),
          // The current-day pointer follows the day-tick signal; these tests
          // pin the day instead, so the tick stays quiet (and its production
          // Timer out of the fake-async zone).
          dayTickProvider.overrideWith((ref) => const Stream<int>.empty()),
        ],
        child: DisplayScope(
          units: units,
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(child: DailySummaryView()),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(
      tester.element(find.byType(DailySummaryView)),
    );
  }

  testWidgets('deficit fixture: intake 1936, budget 2236, 缺口 300 kcal', (
    WidgetTester tester,
  ) async {
    await seedDashboard(
      meals: mealRepo,
      exercises: exerciseRepo,
      profile: profileRepo,
      mealGroups: dashboardDeficitMeals(),
      withExercise: true,
    );

    await pumpDashboard(tester);

    expect(_text(tester, dailyIntakeKcalKey), '1936');
    expect(_text(tester, dailyCarbKey), '180');
    expect(_text(tester, dailyProteinKey), '90');
    expect(_text(tester, dailyFatKey), '55');
    expect(_text(tester, dailySaltKey), '3.5 / 5');
    expect(_text(tester, dailyExerciseKcalKey), '257');
    expect(_text(tester, dailyBudgetKey), '2236');

    // SIGNED balance: 缺口 from deficitKcal (budget - intake) = 300, and it
    // must NOT be labelled 盈余.
    expect(_text(tester, dailyBalanceLabelKey), '缺口');
    expect(_text(tester, dailyBalanceValueKey), '300');
    expect(_color(tester, dailyBalanceLabelKey), dailyDeficitColor);
    expect(_color(tester, dailyBalanceValueKey), dailyDeficitColor);

    // MANUAL-QA CHANNEL: the exact numbers, printed for the record.
    debugPrint(
      'TASK24_QA deficit intake=${_text(tester, dailyIntakeKcalKey)} '
      'budget=${_text(tester, dailyBudgetKey)} '
      'exercise=${_text(tester, dailyExerciseKcalKey)} '
      'balance=${_text(tester, dailyBalanceLabelKey)} '
      '${_text(tester, dailyBalanceValueKey)} kcal -> PASS',
    );
  });

  testWidgets('surplus fixture: intake 2536, budget 2236, 盈余 300 kcal', (
    WidgetTester tester,
  ) async {
    await seedDashboard(
      meals: mealRepo,
      exercises: exerciseRepo,
      profile: profileRepo,
      mealGroups: dashboardSurplusMeals(),
      withExercise: true,
    );

    await pumpDashboard(tester);

    expect(_text(tester, dailyIntakeKcalKey), '2536');
    expect(_text(tester, dailyBudgetKey), '2236');
    expect(_text(tester, dailyExerciseKcalKey), '257');

    // SIGNED balance: 盈余 from energyBalanceKcal (intake - budget) = 300,
    // with a colour inverted from the deficit case.
    expect(_text(tester, dailyBalanceLabelKey), '盈余');
    expect(_text(tester, dailyBalanceValueKey), '300');
    expect(_color(tester, dailyBalanceLabelKey), dailySurplusColor);
    expect(
      dailySurplusColor,
      isNot(dailyDeficitColor),
      reason: 'the surplus colour must be inverted from the deficit colour',
    );

    debugPrint(
      'TASK24_QA surplus intake=${_text(tester, dailyIntakeKcalKey)} '
      'budget=${_text(tester, dailyBudgetKey)} '
      'balance=${_text(tester, dailyBalanceLabelKey)} '
      '${_text(tester, dailyBalanceValueKey)} kcal -> PASS',
    );
  });

  testWidgets(
    'incomplete profile hides the budget and the balance (no 缺口 shown)',
    (WidgetTester tester) async {
      // Same totals as the deficit fixture, but no profile is stored.
      await seedDashboard(
        meals: mealRepo,
        exercises: exerciseRepo,
        profile: profileRepo,
        mealGroups: dashboardDeficitMeals(),
        withExercise: true,
        withProfile: false,
      );

      final ProviderContainer container = await pumpDashboard(tester);

      // Non-profile-dependent numbers stay visible.
      expect(_text(tester, dailyIntakeKcalKey), '1936');
      expect(_text(tester, dailyExerciseKcalKey), '257');

      // The budget / balance are HIDDEN, not guessed.
      expect(find.byKey(dailyBudgetKey), findsNothing);
      expect(find.byKey(dailyBalanceLabelKey), findsNothing);
      expect(find.byKey(dailyBalanceValueKey), findsNothing);
      expect(find.text('缺口'), findsNothing);
      expect(find.text('盈余'), findsNothing);
      expect(find.byKey(dailyProfilePromptKey), findsOneWidget);

      // The provider itself reports the typed incomplete-profile state.
      expect(
        container.read(dailySummaryProvider),
        isA<DailySummaryNoProfile>(),
      );
    },
  );

  testWidgets('totals are live over the repository watch stream', (
    WidgetTester tester,
  ) async {
    await seedDashboard(
      meals: mealRepo,
      exercises: exerciseRepo,
      profile: profileRepo,
    );

    await pumpDashboard(tester);
    expect(_text(tester, dailyIntakeKcalKey), '0');

    // A meal written after the dashboard is on screen must update the total.
    final MealWithItems a = dashboardMealA();
    await mealRepo.saveMealWithItems(a.meal, a.items);
    await tester.pumpAndSettle();
    expect(_text(tester, dailyIntakeKcalKey), '1001');

    final MealWithItems b = dashboardMealB();
    await mealRepo.saveMealWithItems(b.meal, b.items);
    await tester.pumpAndSettle();
    expect(_text(tester, dailyIntakeKcalKey), '1936');
  });

  testWidgets(
    'kJ + sodium preference: intake/budget/exercise/balance and salt tile switch',
    (WidgetTester tester) async {
      await seedDashboard(
        meals: mealRepo,
        exercises: exerciseRepo,
        profile: profileRepo,
        mealGroups: dashboardDeficitMeals(),
        withExercise: true,
      );

      await pumpDashboard(tester, units: metricUnits);

      // 1936 kcal * 4.184 = 8100.224 -> 8100 kJ; budget 2236 -> 9355;
      // burn 257 -> 1075; the signed 缺口 300 -> 1255.
      expect(_text(tester, dailyIntakeKcalKey), '8100');
      expect(_text(tester, dailyBudgetKey), '9355');
      expect(_text(tester, dailyExerciseKcalKey), '1075');
      expect(_text(tester, dailyBalanceValueKey), '1255');

      // Every energy unit reads kJ: intake, budget, exercise and the ring
      // centre's balance unit (the macros keep their g units).
      expect(find.text('kJ'), findsNWidgets(4));
      expect(find.text('kcal'), findsNothing);
      expect(
        find.text('1936'),
        findsNothing,
        reason: 'stored kcal not rendered',
      );

      // Salt tile switches to sodium: 盐 -> 钠, 3.5 g -> 1400 mg, target 2000 mg.
      expect(find.text('钠'), findsOneWidget);
      expect(find.text('盐'), findsNothing);
      expect(_text(tester, dailySaltKey), '1400 / 2000');
      expect(find.text('mg'), findsOneWidget);
      expect(find.text('g'), findsNWidgets(3), reason: 'the three macros');

      // The progress fraction stays salt-vs-target (3.5 / 5 = 0.7): the
      // preference is display-only and never rescales the bar.
      final ThinProgressBar bar = tester.widget<ThinProgressBar>(
        find.byType(ThinProgressBar),
      );
      expect(bar.value, closeTo(3.5 / 5, 1e-9));
    },
  );

  testWidgets(
    'a 1715 kcal / 1400 mg day renders as 7176 kJ and 钠 under the scope',
    (WidgetTester tester) async {
      final DayRollup rollup = DayRollup(
        date: dashboardNow,
        intakeKcal: 1715,
        sodiumMg: 1400,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dailySummaryProvider.overrideWithValue(
              DailySummaryNoProfile(rollup),
            ),
            // The card reads the live today key for the 概览 date rule, so the
            // time seams (and the tick behind them) must be pinned here too.
            dashboardClockProvider.overrideWithValue(dashboardClock()),
            dashboardOffsetProvider.overrideWithValue(dashboardOffset),
            dayTickProvider.overrideWith((ref) => const Stream<int>.empty()),
          ],
          child: const DisplayScope(
            units: metricUnits,
            child: MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(child: DailySummaryView()),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1715 kcal * 4.184 = 7175.56 -> 7176 kJ (the conversion documented on
      // DisplayUnits), shown in the ring centre because there is no budget.
      expect(_text(tester, dailyIntakeKcalKey), '7176');
      expect(find.text('kJ'), findsNWidgets(2), reason: 'ring + exercise');
      expect(find.text('7176 kcal'), findsNothing);

      // The stored 1400 mg is what the sodium tile shows, with its 2000 mg
      // target: no salt-gram round-trip can drift the number.
      expect(find.text('钠'), findsOneWidget);
      expect(_text(tester, dailySaltKey), '1400 / 2000');
      expect(find.text('mg'), findsOneWidget);
    },
  );

  testWidgets(
    'kJ preference without a profile: ring intake + exercise keep the kJ unit',
    (WidgetTester tester) async {
      await seedDashboard(
        meals: mealRepo,
        exercises: exerciseRepo,
        profile: profileRepo,
        mealGroups: dashboardDeficitMeals(),
        withExercise: true,
        withProfile: false,
      );

      await pumpDashboard(tester, units: metricUnits);

      // The ring centre falls back to the raw intake; the exercise line is
      // beside it. Both are kJ now.
      expect(_text(tester, dailyIntakeKcalKey), '8100');
      expect(_text(tester, dailyExerciseKcalKey), '1075');
      expect(find.text('kJ'), findsNWidgets(2));
      expect(find.text('kcal'), findsNothing);

      // Profile-dependent values stay hidden.
      expect(find.byKey(dailyBudgetKey), findsNothing);
      expect(find.byKey(dailyBalanceLabelKey), findsNothing);
      expect(find.byKey(dailyProfilePromptKey), findsOneWidget);

      // The salt tile is profile-independent and switches too.
      expect(find.text('钠'), findsOneWidget);
      expect(_text(tester, dailySaltKey), '1400 / 2000');
      expect(find.text('mg'), findsOneWidget);
    },
  );
}
