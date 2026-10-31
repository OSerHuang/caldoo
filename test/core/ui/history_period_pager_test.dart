/// The shared past-only history pager: swipe, ‹/› buttons, bounds and the
/// "back to now" action.
///
/// The pager carries no data of its own, so this test pins the interaction
/// contract the merged 概览 dashboard's day/week/month views rely on:
/// * page 0 (the initial page) is the current period;
/// * swiping the finger right (or tapping ‹) goes one period back in time;
/// * there is no future page, so the › button is not even mounted on the
///   current period (an arrow that leads nowhere is a dead end); it appears
///   as soon as the user has gone back in time, where it steps towards now;
/// * the "back to now" action exists only once the user is in history and
///   returns to offset 0.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:caldoo/core/ui/history_period_pager.dart';

void main() {
  Future<void> pumpPager(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HistoryPeriodPager(
            id: 'test',
            periodLabel: (int offset) => offset == 0 ? '今天' : '$offset 个周期前',
            previousTooltip: '前一天',
            nextTooltip: '后一天',
            backToNowLabel: '回到今天',
            periodBuilder: (BuildContext context, int offset) =>
                Center(child: Text('PAGE $offset')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  String label(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(historyPeriodLabelKey('test'))).data!;

  bool newerShown(WidgetTester tester) =>
      find.byKey(historyNewerKey('test')).evaluate().isNotEmpty;

  bool newerEnabled(WidgetTester tester) =>
      tester
          .widget<IconButton>(find.byKey(historyNewerKey('test')))
          .onPressed !=
      null;

  bool olderEnabled(WidgetTester tester) =>
      tester
          .widget<IconButton>(find.byKey(historyOlderKey('test')))
          .onPressed !=
      null;

  testWidgets('starts on the current period: no back-to-now, no › button', (
    WidgetTester tester,
  ) async {
    await pumpPager(tester);

    expect(label(tester), '今天');
    expect(find.text('PAGE 0'), findsOneWidget);
    expect(find.byKey(historyBackToNowKey('test')), findsNothing);
    expect(olderEnabled(tester), isTrue);
    expect(
      newerShown(tester),
      isFalse,
      reason:
          'today is the last page, so there is nowhere the › arrow could go',
    );
  });

  testWidgets('swiping the finger right reveals the previous period', (
    WidgetTester tester,
  ) async {
    await pumpPager(tester);

    await tester.drag(
      find.byKey(historyPagerKey('test')),
      const Offset(600, 0),
    );
    await tester.pumpAndSettle();

    expect(label(tester), '1 个周期前');
    expect(find.text('PAGE 1'), findsOneWidget);
    expect(find.byKey(historyBackToNowKey('test')), findsOneWidget);
    expect(newerShown(tester), isTrue);
    expect(newerEnabled(tester), isTrue);
  });

  testWidgets('swiping left at the current period cannot reach the future', (
    WidgetTester tester,
  ) async {
    await pumpPager(tester);

    await tester.drag(
      find.byKey(historyPagerKey('test')),
      const Offset(-600, 0),
    );
    await tester.pumpAndSettle();

    expect(label(tester), '今天');
    expect(find.text('PAGE 0'), findsOneWidget);
    expect(find.byKey(historyBackToNowKey('test')), findsNothing);
    expect(newerShown(tester), isFalse);
  });

  testWidgets('the ‹ / › buttons step back through periods and back to now', (
    WidgetTester tester,
  ) async {
    await pumpPager(tester);

    await tester.tap(find.byKey(historyOlderKey('test')));
    await tester.pumpAndSettle();
    expect(label(tester), '1 个周期前');
    expect(newerShown(tester), isTrue);

    await tester.tap(find.byKey(historyOlderKey('test')));
    await tester.pumpAndSettle();
    expect(label(tester), '2 个周期前');
    expect(find.text('PAGE 2'), findsOneWidget);

    await tester.tap(find.byKey(historyNewerKey('test')));
    await tester.pumpAndSettle();
    expect(label(tester), '1 个周期前');

    await tester.tap(find.byKey(historyBackToNowKey('test')));
    await tester.pumpAndSettle();
    expect(label(tester), '今天');
    expect(find.text('PAGE 0'), findsOneWidget);
    expect(find.byKey(historyBackToNowKey('test')), findsNothing);
    expect(
      newerShown(tester),
      isFalse,
      reason: 'back on today the › arrow has nowhere to go and is removed',
    );
  });
}
