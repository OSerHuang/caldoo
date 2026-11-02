/// The 体重 card on the 概览 day pager, across the browsed days.
///
/// Boots the real app shell over the in-memory fakes with the clock pinned to
/// 2026-01-05 12:00 +08:00 and three weight records: today (01-05), yesterday
/// (01-04) and one two days back (01-03).
///
/// * today's page shows the NEWEST record — the weight log is the "current
///   self" metric, so it does not go blank on a day that was not measured;
/// * a past page with its own record shows THAT day's value, never today's;
/// * a past page with no record shows no card at all.
///
/// The surface is left at the 800x600 test default (not the phone-sized one the
/// day-history tests use): the test fonts are square metrics, which would make
/// the card's value/delta/hint row overflow for reasons no device reproduces.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:caldoo/core/ui/history_period_pager.dart';
import 'package:caldoo/features/weight/weight_card.dart';

import '_harness.dart';

void main() {
  late NavTestEnv env;

  setUp(() => env = NavTestEnv());
  tearDown(() => env.dispose());

  /// Seeds the weight records and boots the app on the 概览 tab.
  Future<void> pumpSeeded(WidgetTester tester) async {
    final DateTime todayKey = DateTime.utc(2026, 1, 5);
    await env.weights.saveWeight(dayKey: todayKey, weightKg: 68.0);
    await env.weights.saveWeight(
      dayKey: todayKey.subtract(const Duration(days: 1)),
      weightKg: 68.4,
    );
    // 01-03 is left out on purpose: it is the "no record that day" page.
    await env.pump(tester);
  }

  /// Swipes the day pager back by [days] days.
  Future<void> swipeBack(WidgetTester tester, {required int days}) async {
    for (int i = 0; i < days; i++) {
      await tester.drag(
        find.byKey(historyPagerKey('today')),
        const Offset(600, 0),
      );
      await tester.pumpAndSettle();
    }
  }

  /// Scrolls the day page down to the region below the quick-add row.
  ///
  /// A plain drag rather than `scrollUntilVisible`: the card is ABSENT on a day
  /// without a record, and `scrollUntilVisible` would fail on a finder that
  /// never appears.
  Future<void> scrollToCardRegion(WidgetTester tester) async {
    await tester.drag(
      find
          .byWidgetPredicate(
            (Widget widget) =>
                widget is Scrollable &&
                widget.axisDirection == AxisDirection.down,
          )
          .first,
      const Offset(0, -400),
    );
    await tester.pumpAndSettle();
  }

  /// The card's rendered weight value, or `null` when the card is not mounted.
  ///
  /// The day page is a lazy [ListView], so the card below the fold is not built
  /// until the list is scrolled to it.
  Future<String?> shownWeight(WidgetTester tester) async {
    await scrollToCardRegion(tester);
    if (find.byKey(weightCardKey).evaluate().isEmpty) {
      return null;
    }
    return tester.widget<Text>(find.byKey(weightCardValueKey)).data;
  }

  testWidgets('today shows the newest record', (WidgetTester tester) async {
    await pumpSeeded(tester);
    expect(await shownWeight(tester), '68 kg');
  });

  testWidgets('a past day with its own record shows that day, not the newest', (
    WidgetTester tester,
  ) async {
    await pumpSeeded(tester);
    await swipeBack(tester, days: 1);
    expect(await shownWeight(tester), '68.4 kg');
  });

  testWidgets('a past day without a record shows no card', (
    WidgetTester tester,
  ) async {
    await pumpSeeded(tester);
    await swipeBack(tester, days: 2);
    expect(find.byKey(weightCardKey), findsNothing);
    expect(await shownWeight(tester), isNull);
  });
}
