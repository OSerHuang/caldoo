// The weight widgets: the dashboard card (empty + filled + record flow) and
// the trend page (stats, chart presence, range switcher, entry list opening
// the edit sheet). The repository port is the in-memory fake, so no database
// is opened and no dayTick timer is started (today is overridden).
//
// dart format width=80
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:caldoo/core/providers/app_providers.dart';
import 'package:caldoo/domain/models/weight_entry.dart';
import 'package:caldoo/features/dashboard/daily/daily_summary_providers.dart'
    show dashboardTodayKeyProvider;
import 'package:caldoo/features/weight/weight_card.dart';
import 'package:caldoo/features/weight/weight_entry_sheet.dart';
import 'package:caldoo/features/weight/weight_trend_screen.dart';

import '../../data/repositories/fake_repositories.dart';

void main() {
  final DateTime todayKey = DateTime.utc(2026, 10, 31);

  Future<FakeWeightRepository> pumpCard(
    WidgetTester tester, {
    List<WeightEntry> entries = const <WeightEntry>[],
  }) async {
    final FakeWeightRepository repo = FakeWeightRepository();
    for (final WeightEntry entry in entries) {
      await repo.saveWeight(dayKey: entry.dayKey, weightKg: entry.weightKg);
    }
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          weightRepositoryProvider.overrideWithValue(repo),
          dashboardTodayKeyProvider.overrideWithValue(todayKey),
        ],
        child: MaterialApp(
          home: Scaffold(body: WeightCard(todayKey: todayKey)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return repo;
  }

  group('WeightCard', () {
    testWidgets('no history: the card renders nothing (the page gates it)', (
      WidgetTester tester,
    ) async {
      await pumpCard(tester);
      expect(find.byKey(weightCardKey), findsNothing);
      expect(find.byKey(weightCardValueKey), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('filled state: latest value, delta chip, sparkline', (
      WidgetTester tester,
    ) async {
      await pumpCard(
        tester,
        entries: <WeightEntry>[
          WeightEntry(dayKey: DateTime.utc(2026, 10, 5), weightKg: 69.0),
          WeightEntry(dayKey: DateTime.utc(2026, 10, 20), weightKg: 68.7),
          WeightEntry(dayKey: DateTime.utc(2026, 10, 30), weightKg: 68.4),
        ],
      );
      expect(find.text('68.4 kg'), findsOneWidget);
      // 68.4 - 68.7 = -0.3 within the last 7 days window (10/24..10/30).
      expect(find.text('−0.3 · 近7天'), findsOneWidget);
    });

    testWidgets('记录 opens the sheet and saving goes through the port', (
      WidgetTester tester,
    ) async {
      final FakeWeightRepository repo = await pumpCard(
        tester,
        entries: <WeightEntry>[
          WeightEntry(dayKey: DateTime.utc(2026, 10, 20), weightKg: 68.7),
        ],
      );
      await tester.tap(find.byKey(weightCardRecordKey));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(weightValueFieldKey), '67.9');
      await tester.tap(find.byKey(weightSaveKey));
      await tester.pumpAndSettle();

      expect((await repo.getDay(todayKey))!.weightKg, 67.9);
    });
  });

  group('WeightTrendScreen', () {
    Future<FakeWeightRepository> pumpTrend(
      WidgetTester tester, {
      List<WeightEntry> entries = const <WeightEntry>[],
    }) async {
      final FakeWeightRepository repo = FakeWeightRepository();
      for (final WeightEntry entry in entries) {
        await repo.saveWeight(dayKey: entry.dayKey, weightKg: entry.weightKg);
      }
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            weightRepositoryProvider.overrideWithValue(repo),
            dashboardTodayKeyProvider.overrideWithValue(todayKey),
          ],
          child: const MaterialApp(home: WeightTrendScreen()),
        ),
      );
      await tester.pumpAndSettle();
      return repo;
    }

    final List<WeightEntry> entries = <WeightEntry>[
      WeightEntry(dayKey: DateTime.utc(2026, 8, 2), weightKg: 71.5),
      WeightEntry(dayKey: DateTime.utc(2026, 9, 2), weightKg: 70.2),
      WeightEntry(dayKey: DateTime.utc(2026, 10, 2), weightKg: 69.0),
      WeightEntry(dayKey: DateTime.utc(2026, 10, 30), weightKg: 68.4),
    ];

    testWidgets('stats, chart and month-grouped list render', (
      WidgetTester tester,
    ) async {
      await pumpTrend(tester, entries: entries);

      // The latest value shows in the 当前 stat AND the newest list row.
      expect(find.text('68.4 kg'), findsWidgets);
      expect(find.text('−3.1 kg'), findsOneWidget, reason: '累计 68.4 - 71.5');
      expect(
        find.text('−0.6 kg'),
        findsOneWidget,
        reason: '近7天: no entry in [10/23..10/29], falls back to 10/2 (69.0)',
      );
      expect(find.byKey(weightChartKey), findsOneWidget);
      // The list shows every entry with a month header (10月 and 9月/8月).
      expect(find.text('10月2日'), findsOneWidget);
      expect(find.text('8月2日'), findsOneWidget);
    });

    testWidgets('tapping a row opens the edit sheet pre-filled', (
      WidgetTester tester,
    ) async {
      final FakeWeightRepository repo = await pumpTrend(
        tester,
        entries: entries,
      );

      await tester.tap(find.byKey(weightRowKey(DateTime.utc(2026, 10, 30))));
      await tester.pumpAndSettle();

      expect(
        find.text('68.4'),
        findsOneWidget,
        reason: 'the value is pre-filled',
      );
      expect(find.byKey(weightDeleteKey), findsOneWidget);

      // Editing to 68.0 overwrites that day through the port.
      await tester.enterText(find.byKey(weightValueFieldKey), '68.0');
      await tester.tap(find.byKey(weightSaveKey));
      await tester.pumpAndSettle();
      expect((await repo.getDay(DateTime.utc(2026, 10, 30)))!.weightKg, 68.0);
    });

    testWidgets('empty history shows the empty state with a record action', (
      WidgetTester tester,
    ) async {
      await pumpTrend(tester);
      expect(find.byKey(weightTrendEmptyKey), findsOneWidget);
      expect(find.byKey(weightChartKey), findsNothing);
    });
  });
}
