/// Task 22: the per-meal summary card widget test.
///
/// Asserts the card renders BOTH blocks: the meal's own numbers (本餐合计) and
/// the running 今日累计 from the repository `watch` stream. A second, earlier
/// meal is seeded so the two values are visibly different (meal 120 kcal vs
/// day 190 kcal), proving the day line is not a copy of the meal line.
///
/// The card is read-only, so a DisplayScope switches its energy unit and its
/// salt/sodium basis; the default (no scope) rendering must stay kcal + salt.
library;

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:caldoo/core/providers/app_providers.dart';
import 'package:caldoo/core/units/display_units.dart';
import 'package:caldoo/domain/models/models.dart';
import 'package:caldoo/features/meals/summary/meal_summary_card.dart';
import 'package:caldoo/features/meals/summary/meal_summary_providers.dart';

import '../../../data/repositories/fake_repositories.dart';
import '_fixtures.dart';

/// Reads a `Text`'s data by key.
String _value(WidgetTester tester, Key key) =>
    tester.widget<Text>(find.byKey(key)).data!;

void main() {
  testWidgets('card shows both the meal numbers and the day running total', (
    WidgetTester tester,
  ) async {
    final FakeMealRepository repo = FakeMealRepository();
    addTearDown(repo.dispose);

    final Meal lunch = summaryMeal(id: 'meal-lunch', timestamp: fixedNow);
    final Meal breakfast = summaryMeal(
      id: 'meal-breakfast',
      timestamp: fixedNow.subtract(const Duration(hours: 2)),
      mealType: MealType.breakfast,
    );
    // Both meals are persisted, so the watch stream reports the day total.
    await repo.saveMealWithItems(breakfast, <MealItem>[summaryEggItem()]);
    await repo.saveMealWithItems(lunch, <MealItem>[summaryRiceItem()]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mealRepositoryProvider.overrideWithValue(repo),
          summaryClockProvider.overrideWithValue(fixedShanghaiClock()),
          localOffsetProvider.overrideWithValue(shanghai),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: MealSummaryCard(
              meal: lunch,
              items: <MealItem>[summaryRiceItem()],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 本餐合计: rice only (120 / 8 / 6 / 5 / 0.3).
    expect(_value(tester, mealSummaryKcalKey), '120');
    expect(_value(tester, mealSummaryCarbKey), '8');
    expect(_value(tester, mealSummaryProteinKey), '6');
    expect(_value(tester, mealSummaryFatKey), '5');
    expect(_value(tester, mealSummarySaltKey), '0.3');

    // 今日累计: rice + egg (190 / 9 / 13 / 9 / 0.5).
    expect(_value(tester, dayTotalKcalKey), '190');
    expect(_value(tester, dayTotalCarbKey), '9');
    expect(_value(tester, dayTotalProteinKey), '13');
    expect(_value(tester, dayTotalFatKey), '9');
    expect(_value(tester, dayTotalSaltKey), '0.5');

    // With no DisplayScope the historical defaults stay: kcal + salt in both
    // blocks, so existing screens and goldens render exactly as before.
    expect(find.text('kcal'), findsNWidgets(2));
    expect(find.text('盐'), findsNWidgets(2));

    // Manual-QA channel: both numbers rendered, meal != day.
    debugPrint(
      'TASK22_QA meal_kcal=${_value(tester, mealSummaryKcalKey)} '
      'day_total_kcal=${_value(tester, dayTotalKcalKey)} '
      'meal_salt=${_value(tester, mealSummarySaltKey)} '
      'day_total_salt=${_value(tester, dayTotalSaltKey)} -> PASS',
    );
  });

  testWidgets('a past-day meal shows ITS day total, not the wall-clock day', (
    WidgetTester tester,
  ) async {
    final FakeMealRepository repo = FakeMealRepository();
    addTearDown(repo.dispose);

    // Monday's meal (fixedNow is 2026-01-05 12:00 +08) with a second meal on
    // the same day, then Wednesday "today" with nothing logged. The card is
    // opened for the MONDAY meal; the old hardwired 今日 stream would pair it
    // with Wednesday's running intake (0 kcal) under the label 今日累计.
    final Meal monday = summaryMeal(id: 'meal-mon', timestamp: fixedNow);
    final Meal mondayBreakfast = summaryMeal(
      id: 'meal-mon-b',
      timestamp: fixedNow.subtract(const Duration(hours: 3)),
      mealType: MealType.breakfast,
    );
    await repo.saveMealWithItems(monday, <MealItem>[summaryRiceItem()]);
    await repo.saveMealWithItems(mondayBreakfast, <MealItem>[summaryEggItem()]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mealRepositoryProvider.overrideWithValue(repo),
          summaryClockProvider.overrideWithValue(
            Clock.fixed(fixedNow.add(const Duration(days: 2))),
          ),
          localOffsetProvider.overrideWithValue(shanghai),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: MealSummaryCard(
              meal: monday,
              items: <MealItem>[summaryRiceItem()],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 本餐合计 is the meal; the day line is MONDAY's running intake (190),
    // labelled 当日累计 — not Wednesday's 0 under 今日累计.
    expect(_value(tester, mealSummaryKcalKey), '120');
    expect(find.text('当日累计'), findsOneWidget);
    expect(find.text('今日累计'), findsNothing);
    expect(_value(tester, dayTotalKcalKey), '190');
    expect(_value(tester, dayTotalSaltKey), '0.5');
  });

  testWidgets('the card names the recorded time under the meal type', (
    WidgetTester tester,
  ) async {
    final FakeMealRepository repo = FakeMealRepository();
    addTearDown(repo.dispose);

    // fixedNow is 2026-01-05 12:00 at +08:00.
    final Meal lunch = summaryMeal(id: 'meal-lunch', timestamp: fixedNow);
    await repo.saveMealWithItems(lunch, <MealItem>[summaryRiceItem()]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mealRepositoryProvider.overrideWithValue(repo),
          summaryClockProvider.overrideWithValue(fixedShanghaiClock()),
          localOffsetProvider.overrideWithValue(shanghai),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: MealSummaryCard(
              meal: lunch,
              items: <MealItem>[summaryRiceItem()],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The line resolves the stored instant through the app's own offset, so a
    // meal recorded at the wrong time is visible as such.
    expect(_value(tester, mealSummaryTimeKey), '2026年1月5日 12:00');
    expect(_value(tester, mealSummaryKcalKey), '120');
  });

  testWidgets('day total reflects a later save (live watch stream)', (
    WidgetTester tester,
  ) async {
    final FakeMealRepository repo = FakeMealRepository();
    addTearDown(repo.dispose);

    final Meal lunch = summaryMeal(id: 'meal-lunch', timestamp: fixedNow);
    await repo.saveMealWithItems(lunch, <MealItem>[summaryRiceItem()]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mealRepositoryProvider.overrideWithValue(repo),
          summaryClockProvider.overrideWithValue(fixedShanghaiClock()),
          localOffsetProvider.overrideWithValue(shanghai),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: MealSummaryCard(
              meal: lunch,
              items: <MealItem>[summaryRiceItem()],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(_value(tester, dayTotalKcalKey), '120');

    // A second meal written after the card is on screen must update the line.
    final Meal dinner = summaryMeal(
      id: 'meal-dinner',
      timestamp: fixedNow.add(const Duration(hours: 6)),
      mealType: MealType.dinner,
    );
    await repo.saveMealWithItems(dinner, <MealItem>[summaryEggItem()]);
    await tester.pumpAndSettle();

    expect(_value(tester, dayTotalKcalKey), '190');
    expect(_value(tester, dayTotalSaltKey), '0.5');
  });

  testWidgets('a kJ + sodium preference switches both blocks only', (
    WidgetTester tester,
  ) async {
    final FakeMealRepository repo = FakeMealRepository();
    addTearDown(repo.dispose);

    // 200 kcal and 0.5 g salt per item: 836.8 -> 837 kJ, 200 mg sodium.
    const MealItem item = MealItem(
      id: 'item-200',
      name: '测试食物',
      grams: 100,
      kcal: 200,
      carbG: 10,
      proteinG: 5,
      fatG: 4,
      saltG: 0.5,
      source: FoodSource.manual,
    );
    final Meal lunch = summaryMeal(id: 'meal-lunch', timestamp: fixedNow);
    await repo.saveMealWithItems(lunch, <MealItem>[item]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mealRepositoryProvider.overrideWithValue(repo),
          summaryClockProvider.overrideWithValue(fixedShanghaiClock()),
          localOffsetProvider.overrideWithValue(shanghai),
        ],
        child: DisplayScope(
          units: const DisplayUnits(
            energy: EnergyDisplay.kj,
            salt: SaltDisplay.sodium,
          ),
          child: MaterialApp(
            home: Scaffold(
              body: MealSummaryCard(meal: lunch, items: const <MealItem>[item]),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Energy values convert; the salt row shows the stored sodium milligrams.
    expect(_value(tester, mealSummaryKcalKey), '837');
    expect(_value(tester, dayTotalKcalKey), '837');
    expect(_value(tester, mealSummarySaltKey), '200');
    expect(_value(tester, dayTotalSaltKey), '200');

    // Label and unit switch together in both blocks; nothing keeps kcal / salt.
    expect(find.text('kJ'), findsNWidgets(2));
    expect(find.text('钠'), findsNWidgets(2));
    expect(find.text('mg'), findsNWidgets(2));
    expect(find.text('kcal'), findsNothing);
    expect(find.text('盐'), findsNothing);

    // Macros are unaffected by the energy/salt preference.
    expect(_value(tester, mealSummaryCarbKey), '10');
    expect(find.text('g'), findsNWidgets(6));
  });
}
