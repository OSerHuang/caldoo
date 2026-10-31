/// The current-period seams re-derive on a [dayTickProvider] signal.
///
/// Locks the warm-start contract at the provider boundary: a plain `Provider`
/// caches its value for the whole container lifetime, so when the process
/// survives overnight in the background the day/week/month keys used to stay
/// frozen on the launch period until a full restart. They now watch the tick —
/// moving the clock alone changes nothing (the frozen behaviour this removes),
/// and one tick re-derives everything from the injected clock.
library;

import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:caldoo/core/time/day_tick_provider.dart';
import 'package:caldoo/features/dashboard/daily/daily_summary_providers.dart';
import 'package:caldoo/features/dashboard/monthly/monthly_summary_providers.dart';
import 'package:caldoo/features/dashboard/weekly/weekly_summary_providers.dart';
import 'package:caldoo/features/meals/summary/day_window.dart';
import 'package:caldoo/features/meals/summary/meal_summary_providers.dart';

import 'daily/_fixtures.dart' show dashboardNow, dashboardOffset;

void main() {
  /// A container whose every time seam reads the mutable [now] and whose tick
  /// comes from the returned controller.
  (ProviderContainer, StreamController<int>) env({
    required DateTime Function() now,
  }) {
    final StreamController<int> ticks = StreamController<int>.broadcast();
    final ProviderContainer container = ProviderContainer(
      overrides: [
        dashboardClockProvider.overrideWithValue(Clock(now)),
        dashboardOffsetProvider.overrideWithValue(dashboardOffset),
        weeklyClockProvider.overrideWithValue(Clock(now)),
        weeklyOffsetProvider.overrideWithValue(dashboardOffset),
        monthlyClockProvider.overrideWithValue(Clock(now)),
        monthlyOffsetProvider.overrideWithValue(dashboardOffset),
        summaryClockProvider.overrideWithValue(Clock(now)),
        localOffsetProvider.overrideWithValue(dashboardOffset),
        dayTickProvider.overrideWith((ref) => ticks.stream),
      ],
    );
    return (container, ticks);
  }

  test(
    'day / week / month keys re-derive on a tick after the clock moves',
    () async {
      DateTime now = dashboardNow; // 2026-01-05 12:00 +08: a Monday.
      final (ProviderContainer container, StreamController<int> ticks) = env(
        now: () => now,
      );
      addTearDown(container.dispose);
      addTearDown(ticks.close);
      // Listeners keep the providers mounted (and the tick subscribed) between
      // reads; without them the container would drop unlistened state.
      container.listen(dashboardTodayKeyProvider, (DateTime? _, DateTime _) {});
      container.listen(
        weeklyCurrentMondayKeyProvider,
        (DateTime? _, DateTime _) {},
      );
      container.listen(
        monthlyCurrentMonthKeyProvider,
        (DateTime? _, DateTime _) {},
      );

      // The fixture period: Monday 2026-01-05, month 2026-01.
      expect(
        container.read(dashboardTodayKeyProvider),
        DateTime.utc(2026, 1, 5),
      );
      expect(
        container.read(weeklyCurrentMondayKeyProvider),
        DateTime.utc(2026, 1, 5),
      );
      expect(
        container.read(monthlyCurrentMonthKeyProvider),
        DateTime.utc(2026, 1, 1),
      );

      // The process slept across the month boundary; the clock reads the new
      // period but nothing re-derives the keys without a tick — exactly the
      // once-per-process caching this fix removes.
      now = DateTime.utc(2026, 2, 2, 4); // 2026-02-02 12:00 +08: a Monday.
      expect(
        container.read(dashboardTodayKeyProvider),
        DateTime.utc(2026, 1, 5),
      );

      // One resume tick: the keys follow the calendar (day 02-02, week of
      // 02-02, month 02-01).
      ticks.add(1);
      await pumpEventQueue();

      expect(
        container.read(dashboardTodayKeyProvider),
        DateTime.utc(2026, 2, 2),
      );
      expect(
        container.read(weeklyCurrentMondayKeyProvider),
        DateTime.utc(2026, 2, 2),
      );
      expect(
        container.read(monthlyCurrentMonthKeyProvider),
        DateTime.utc(2026, 2, 1),
      );
    },
  );

  test(
    'the meal summary 今日窗口 re-derives on a tick after the clock moves',
    () async {
      DateTime now = dashboardNow;
      final (ProviderContainer container, StreamController<int> ticks) = env(
        now: () => now,
      );
      addTearDown(container.dispose);
      addTearDown(ticks.close);
      container.listen(
        todayWindowProvider,
        (LocalDayWindow? _, LocalDayWindow _) {},
      );

      // Local midnight of 2026-01-05 is 2026-01-04T16:00Z at +08:00.
      expect(
        container.read(todayWindowProvider).start,
        DateTime.utc(2026, 1, 4, 16),
      );

      now = DateTime.utc(2026, 2, 2, 4);
      ticks.add(1);
      await pumpEventQueue();

      expect(
        container.read(todayWindowProvider).start,
        DateTime.utc(2026, 2, 1, 16),
      );
    },
  );

  test('a tick that does not cross a boundary keeps the keys (and notifies nothing)', () async {
    DateTime now = dashboardNow;
    final (ProviderContainer container, StreamController<int> ticks) = env(
      now: () => now,
    );
    addTearDown(container.dispose);
    addTearDown(ticks.close);
    final List<DateTime> dayKeys = <DateTime>[];
    container.listen(
      dashboardTodayKeyProvider,
      (DateTime? _, DateTime key) => dayKeys.add(key),
    );
    expect(container.read(dashboardTodayKeyProvider), DateTime.utc(2026, 1, 5));

    // A mid-day resume (the clock moved hours, not the calendar date): the
    // re-derived key is the value-equal UTC midnight, so no dependent update.
    now = dashboardNow.add(const Duration(hours: 3));
    ticks.add(1);
    await pumpEventQueue();

    expect(dayKeys, isEmpty);
    expect(container.read(dashboardTodayKeyProvider), DateTime.utc(2026, 1, 5));

    // Crossing the boundary then notifies exactly once.
    now = DateTime.utc(2026, 1, 6, 4);
    ticks.add(2);
    await pumpEventQueue();

    expect(dayKeys, <DateTime>[DateTime.utc(2026, 1, 6)]);
    expect(container.read(dashboardTodayKeyProvider), DateTime.utc(2026, 1, 6));
  });
}
