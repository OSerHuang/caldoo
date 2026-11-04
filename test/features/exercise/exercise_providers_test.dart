/// The exercise time seams re-derive on a [dayTickProvider] signal.
///
/// Locks the current-day contract at the provider boundary: the day key behind
/// the date picker and the no-day deep link must follow the tick (app resume,
/// the minute poll), not the launch moment — a warm start surviving midnight
/// used to keep offering the launch day, exactly the frozen-seam bug the
/// dashboard seams fixed. The offset seam ([exerciseOffsetProvider]) watches
/// the same tick so a zone change while the process is alive re-reads the
/// device zone; the zone itself cannot be flipped by a test, so the locked
/// behaviour here is the day-key re-derivation.
library;

import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:caldoo/core/time/day_tick_provider.dart';
import 'package:caldoo/core/time/date_windows.dart';
import 'package:caldoo/features/exercise/exercise_providers.dart';

void main() {
  test(
    'exerciseDayKeyProvider re-derives on a tick after the clock moves',
    () async {
      DateTime now = DateTime.utc(2026, 1, 5, 12); // a Monday midday.
      final StreamController<int> ticks = StreamController<int>.broadcast();
      final ProviderContainer container = ProviderContainer(
        overrides: [
          exerciseClockProvider.overrideWithValue(Clock(() => now)),
          dayTickProvider.overrideWith((ref) => ticks.stream),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(ticks.close);
      // Listeners keep the provider mounted (and the tick subscribed) between
      // reads; without one the container would drop unlistened state.
      container.listen(exerciseDayKeyProvider, (DateTime? _, DateTime _) {});

      expect(
        container.read(exerciseDayKeyProvider),
        dayKeyOf(now, LocalOffset(DateTime.now().timeZoneOffset.inMinutes)),
        // 2026-01-05 as a date-only key.
      );
      expect(container.read(exerciseDayKeyProvider), DateTime.utc(2026, 1, 5));

      // The process slept past midnight; without a tick the key must stay.
      now = DateTime.utc(2026, 1, 6, 12);
      expect(container.read(exerciseDayKeyProvider), DateTime.utc(2026, 1, 5));

      // One tick re-derives the key from the injected clock.
      ticks.add(1);
      await pumpEventQueue();
      expect(container.read(exerciseDayKeyProvider), DateTime.utc(2026, 1, 6));
    },
  );
}
