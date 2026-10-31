/// Tests the production [dayTickProvider] itself.
///
/// Every other suite overrides the provider with a controlled stream (its
/// Timer/observer must not run there); these tests are the ones that exercise
/// the real wake-up layer: the foreground return and the minute poll. The
/// container is disposed inside each test body — flutter_test's pending-timer
/// check runs before `addTearDown`, and only `dispose` cancels the poll.
library;

import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:caldoo/core/time/day_tick_provider.dart';

void main() {
  testWidgets('emits a tick when the app returns to the foreground', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = ProviderContainer();
    try {
      // A listener keeps the provider mounted: without one the container
      // drops the unlistened subscription and the tick would be lost.
      container.listen(
        dayTickProvider,
        (AsyncValue<int>? _, AsyncValue<int> _) {},
      );

      expect(container.read(dayTickProvider).value, isNull);

      // A background -> foreground round trip: the process may have slept
      // across local midnight.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      expect(container.read(dayTickProvider).value, 1);
    } finally {
      container.dispose();
    }
  });

  testWidgets(
    'the minute poll fires while foregrounded (no lifecycle change)',
    (WidgetTester tester) async {
      final ProviderContainer container = ProviderContainer();
      try {
        container.listen(
          dayTickProvider,
          (AsyncValue<int>? _, AsyncValue<int> _) {},
        );

        // Covers the app left open across midnight and a manually edited clock:
        // the coarse poll re-derives "today" without any resume event.
        await tester.pump(const Duration(minutes: 1));
        expect(container.read(dayTickProvider).value, 1);

        await tester.pump(const Duration(minutes: 1));
        expect(container.read(dayTickProvider).value, 2);
      } finally {
        container.dispose();
      }
    },
  );

  testWidgets('a pause alone does not tick (only the foreground return does)', (
    WidgetTester tester,
  ) async {
    final ProviderContainer container = ProviderContainer();
    try {
      container.listen(
        dayTickProvider,
        (AsyncValue<int>? _, AsyncValue<int> _) {},
      );

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();

      expect(container.read(dayTickProvider).value, isNull);
    } finally {
      container.dispose();
    }
  });
}
