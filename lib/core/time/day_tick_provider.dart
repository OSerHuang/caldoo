/// The "local time may have moved" wake-up signal behind the app's
/// current-day seams.
///
/// Every provider that derives a date-only key from the clock
/// (`dashboardTodayKeyProvider`, `weeklyCurrentMondayKeyProvider`,
/// `monthlyCurrentMonthKeyProvider`, the meal summary's `todayWindowProvider`,
/// and the offset providers they read) watches this stream, so "today" is a
/// live value rather than a once-per-process constant:
///
/// * a plain `Provider` caches its value for the whole container lifetime, so
///   without this signal a warm start — the process surviving overnight in the
///   background — would keep the launch day's key until the app was fully
///   restarted, and the live repository streams would keep watching the *old*
///   day's window (the bug where the 概览 tab showed yesterday every morning);
/// * a tick fires when the app returns to the foreground (the process may have
///   slept across local midnight) and on a one-minute poll (the app left open
///   across midnight, or the system clock edited by hand);
/// * a tick does NOT mean the day changed: the watchers re-derive their
///   date-only keys, and an unchanged key — a value-equal UTC midnight — stops
///   the update right there, so a mid-day resume notifies no dependent.
///
/// The provider deliberately depends on nothing (no clock seam): it is the
/// wake-up layer, while every derived value stays behind the injected
/// clock/offset seams. Tests override this provider with a controlled stream
/// (`dayTickProvider.overrideWith((ref) => ticks.stream)`) — the real
/// implementation reads `WidgetsBinding`, so a plain (non-widget) test must
/// override it too.
library;

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Emits a fresh counter value whenever "today" may have moved.
///
/// Watch it for its rebuild signal, not its value: consecutive emissions only
/// matter because they make the watchers re-derive their date-only keys, and
/// an unchanged key (a value-equal UTC midnight) stops the update there.
final dayTickProvider = StreamProvider<int>((ref) {
  final StreamController<int> controller = StreamController<int>.broadcast();
  var tick = 0;
  void fire() => controller.add(++tick);

  // Back to the foreground: the process may have slept across local midnight.
  // Extra ticks (a brief background -> foreground round trip mid-day) are
  // harmless — see the re-derived-equal-key note in the library docs.
  final _DayTickObserver observer = _DayTickObserver(onResume: fire);
  WidgetsBinding.instance.addObserver(observer);

  // Foreground rollover and manual clock edits: a coarse poll. Recomputing the
  // day key once a minute is free next to what the dashboard already does per
  // frame, and it needs no exact-midnight scheduling (which DST shifts and
  // clock edits would invalidate anyway).
  final Timer poll = Timer.periodic(const Duration(minutes: 1), (_) => fire());

  ref.onDispose(() {
    WidgetsBinding.instance.removeObserver(observer);
    poll.cancel();
    controller.close();
  });

  return controller.stream;
});

/// The lifecycle half of [dayTickProvider]: one tick per foreground return.
class _DayTickObserver with WidgetsBindingObserver {
  _DayTickObserver({required this.onResume});

  /// Called when the app moves back to [AppLifecycleState.resumed].
  final void Function() onResume;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      onResume();
    }
  }
}
