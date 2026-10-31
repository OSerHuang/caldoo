/// The 概览 tab across a warm-start midnight.
///
/// The app process survives overnight in the background; the next morning it
/// is resumed, not restarted. The current-period keys used to be
/// once-per-process constants, so the first page kept replaying the launch
/// day — the live meal streams watched a day window frozen at launch. They now
/// re-derive on every dayTickProvider signal: this suite drives the real
/// [TodayScreen] — move the clock, emit a tick, and the day view must follow.
///
/// The screen is pumped directly (not through the full-app nav harness): the
/// assertions here are about the screen + its providers, and the harness's
/// router graph is irrelevant to them.
library;

import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:caldoo/core/providers/app_providers.dart';
import 'package:caldoo/core/time/day_tick_provider.dart';
import 'package:caldoo/core/ui/history_period_pager.dart';
import 'package:caldoo/core/units/display_units.dart';
import 'package:caldoo/domain/models/models.dart';
import 'package:caldoo/features/dashboard/daily/daily_summary_providers.dart';
import 'package:caldoo/features/dashboard/daily/daily_summary_view.dart';
import 'package:caldoo/features/dashboard/monthly/monthly_summary_providers.dart';
import 'package:caldoo/features/dashboard/weekly/weekly_summary_providers.dart';
import 'package:caldoo/features/nav/today_screen.dart';

import '../../data/repositories/fake_repositories.dart';
import '../dashboard/daily/_fixtures.dart'
    show dashboardNow, dashboardOffset, dashboardProfile;

String _text(WidgetTester tester, Key key) =>
    tester.widget<Text>(find.byKey(key)).data!;

void main() {
  late FakeMealRepository meals;
  late FakeExerciseRepository exercises;
  late FakeProfileRepository profile;
  DateTime now = dashboardNow;
  late StreamController<int> ticks;

  setUp(() {
    meals = FakeMealRepository();
    exercises = FakeExerciseRepository();
    profile = FakeProfileRepository();
    now = dashboardNow;
    ticks = StreamController<int>.broadcast();
  });

  tearDown(() async {
    await ticks.close();
    await meals.dispose();
    await exercises.dispose();
    await profile.dispose();
  });

  /// A real phone-sized surface (390x844 logical): the daily hero card only
  /// fits above the fold on a phone-sized screen, and an off-screen sliver
  /// child is skipped by key finders.
  void usePhoneSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(390 * 2, 844 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
  }

  Future<void> pumpOverview(WidgetTester tester) async {
    await profile.saveProfile(dashboardProfile);
    usePhoneSurface(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mealRepositoryProvider.overrideWithValue(meals),
          exerciseRepositoryProvider.overrideWithValue(exercises),
          profileRepositoryProvider.overrideWithValue(profile),
          dashboardClockProvider.overrideWithValue(Clock(() => now)),
          dashboardOffsetProvider.overrideWithValue(dashboardOffset),
          // The day view mounts the week and month current keys in build, so
          // their seams are pinned to the same instant.
          weeklyClockProvider.overrideWithValue(Clock(() => now)),
          weeklyOffsetProvider.overrideWithValue(dashboardOffset),
          monthlyClockProvider.overrideWithValue(Clock(() => now)),
          monthlyOffsetProvider.overrideWithValue(dashboardOffset),
          dayTickProvider.overrideWith((ref) => ticks.stream),
        ],
        child: const DisplayScope(
          units: DisplayUnits.defaults,
          child: MaterialApp(home: TodayScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('概览在热启动跨过午夜后跟随新的一天', (WidgetTester tester) async {
    final ({Meal meal, List<MealItem> items}) seed = (
      meal: Meal(
        id: 'launch-day',
        timestamp: dashboardNow,
        mealType: MealType.lunch,
      ),
      items: const <MealItem>[
        MealItem(
          id: 'launch-day-item',
          name: '米饭',
          grams: 150,
          kcal: 500,
          carbG: 10,
          proteinG: 5,
          fatG: 2,
          saltG: 0.5,
          source: FoodSource.manual,
        ),
      ],
    );
    await meals.saveMealWithItems(seed.meal, seed.items);
    await pumpOverview(tester);

    // The day page opens on the launch day: the meal is on the hero card.
    expect(_text(tester, dailyIntakeKcalKey), '500');
    expect(find.text('1月5日'), findsOneWidget);

    // Warm start across local midnight: the process was alive the whole time,
    // the clock moved, and the app gets a resume tick.
    now = dashboardNow.add(const Duration(days: 1));
    ticks.add(1);
    await tester.pumpAndSettle();

    // The day view is on the new day: the intake resets to 0, the date label
    // follows, the old food row is gone, and the header still says 今天
    // because offset 0 IS the new today.
    expect(_text(tester, dailyIntakeKcalKey), '0');
    expect(find.text('1月6日'), findsOneWidget);
    expect(find.byKey(todayFoodRowKey('launch-day-item')), findsNothing);
    expect(_text(tester, historyPeriodLabelKey('today')), '今天');
  });

  testWidgets('同一进程内 resume 但没跨天：今日页保持原样', (WidgetTester tester) async {
    final ({Meal meal, List<MealItem> items}) seed = (
      meal: Meal(
        id: 'same-day',
        timestamp: dashboardNow,
        mealType: MealType.lunch,
      ),
      items: const <MealItem>[
        MealItem(
          id: 'same-day-item',
          name: '米饭',
          grams: 150,
          kcal: 500,
          carbG: 10,
          proteinG: 5,
          fatG: 2,
          saltG: 0.5,
          source: FoodSource.manual,
        ),
      ],
    );
    await meals.saveMealWithItems(seed.meal, seed.items);
    await pumpOverview(tester);

    // A brief background -> foreground round trip mid-day: the tick fires,
    // the re-derived key is the value-equal UTC midnight, nothing moves.
    now = dashboardNow.add(const Duration(hours: 3));
    ticks.add(1);
    await tester.pumpAndSettle();

    expect(_text(tester, dailyIntakeKcalKey), '500');
    expect(find.byKey(todayFoodRowKey('same-day-item')), findsOneWidget);
  });
}
