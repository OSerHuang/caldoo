/// Controller-level behaviour of the one-per-day exercise-burn entry.
///
/// Exercises [ExerciseEntryController] directly against the in-memory fake (no
/// widget, no DB): the opening-day default (yesterday unless yesterday is
/// recorded), malformed-input handling, the positive-value refusal, and
/// set/save/clear round-trips on the selected day.
library;

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:caldoo/core/providers/app_providers.dart';
import 'package:caldoo/core/time/date_windows.dart';
import 'package:caldoo/domain/models/daily_exercise.dart';
import 'package:caldoo/features/exercise/exercise_entry_controller.dart';
import 'package:caldoo/features/exercise/exercise_providers.dart';

import '../../data/repositories/fake_repositories.dart';

/// 2026-09-21 12:00 +08:00, i.e. the 2026-09-21 local day.
final DateTime _now = DateTime.utc(2026, 9, 21, 4);

/// The date-only key of that day.
final DateTime _todayKey = DateTime.utc(2026, 9, 21);

/// The date-only key of the preceding local day.
final DateTime _yesterdayKey = DateTime.utc(2026, 9, 20);

void main() {
  late FakeExerciseRepository repo;
  late ProviderContainer container;
  ProviderSubscription<ExerciseEntryState>? subscription;

  setUp(() {
    repo = FakeExerciseRepository();
    container = ProviderContainer(
      overrides: [
        exerciseRepositoryProvider.overrideWithValue(repo),
        exerciseClockProvider.overrideWithValue(Clock.fixed(_now)),
        exerciseOffsetProvider.overrideWithValue(const LocalOffset(480)),
      ],
    );
  });

  tearDown(() async {
    subscription?.close();
    subscription = null;
    container.dispose();
    await repo.dispose();
  });

  ExerciseEntryState state() => container.read(exerciseEntryControllerProvider);

  ExerciseEntryController controller() =>
      container.read(exerciseEntryControllerProvider.notifier);

  /// Opens the form the way the screen does: a live listener (so the selected
  /// day's stream is not paused), then the async opening default settles.
  Future<void> open() async {
    subscription ??= container.listen(
      exerciseEntryControllerProvider,
      (ExerciseEntryState? previous, ExerciseEntryState next) {},
      fireImmediately: true,
    );
    await container.read(exerciseDefaultDayProvider.future);
    await pumpEventQueue();
  }

  group('opening day default', () {
    test(
      'yesterday, when yesterday has no burn, and it is read as empty',
      () async {
        await open();

        expect(container.read(exerciseSelectedDayProvider), _yesterdayKey);
        expect(state().day, _yesterdayKey);
        expect(state().loaded, isTrue);
        expect(state().kcal, isNull);
        expect(state().ready, isTrue);
      },
    );

    test('today, when yesterday already has a burn', () async {
      await repo.setKcal(dayKey: _yesterdayKey, kcal: 300);

      await open();

      expect(container.read(exerciseSelectedDayProvider), _todayKey);
      expect(state().day, _todayKey);
      expect(state().kcal, isNull);
    });

    test('today, when both days have a burn', () async {
      await repo.setKcal(dayKey: _yesterdayKey, kcal: 300);
      await repo.setKcal(dayKey: _todayKey, kcal: 120);

      await open();

      expect(state().day, _todayKey);
      expect(state().kcal, 120);
    });

    test(
      'reset re-reads it: recording yesterday flips the next open to today',
      () async {
        await open();
        expect(state().day, _yesterdayKey);

        controller().setKcal(300);
        expect(await controller().save(), isTrue);

        container.read(exerciseSelectedDayProvider.notifier).reset();
        await container.read(exerciseDefaultDayProvider.future);
        await pumpEventQueue();

        expect(container.read(exerciseSelectedDayProvider), _todayKey);
        expect(state().day, _todayKey);
      },
    );

    test('an explicit pick survives the stream but not a reset', () async {
      final DateTime older = DateTime.utc(2026, 9, 15);
      await open();

      container.read(exerciseSelectedDayProvider.notifier).select(older);
      await pumpEventQueue();

      expect(state().day, older);
      expect(state().loaded, isTrue);
      expect(container.read(exerciseSelectedDayProvider), older);

      container.read(exerciseSelectedDayProvider.notifier).reset();
      await container.read(exerciseDefaultDayProvider.future);
      await pumpEventQueue();

      expect(state().day, _yesterdayKey);
    });
  });

  group('setKcal', () {
    test('a negative value fails fast, a positive value sticks', () async {
      await open();

      // Energy is an int, so NaN/infinity are not even representable: the
      // digits-only field can only ever produce a whole non-negative number.
      expect(() => controller().setKcal(-1), throwsArgumentError);

      controller().setKcal(300);
      expect(state().kcal, 300);
      expect(state().hasValue, isTrue);
    });

    test('setKcal(null) clears the draft but keeps the day', () async {
      await open();
      controller().setKcal(300);

      controller().setKcal(null);

      expect(state().kcal, isNull);
      expect(state().hasValue, isFalse);
      expect(state().day, _yesterdayKey);
    });
  });

  group('save', () {
    test('refuses a missing or zero value and stores nothing', () async {
      await open();

      expect(await controller().save(), isFalse);
      expect(state().error, '请输入大于 0 的运动消耗');
      expect(await repo.getDay(_yesterdayKey), isNull);

      controller().setKcal(0);
      expect(await controller().save(), isFalse);
      expect(await repo.getDay(_yesterdayKey), isNull);
    });

    test('persists the value on the default day (yesterday)', () async {
      await open();
      controller().setKcal(257);

      expect(await controller().save(), isTrue);

      final DailyExercise? stored = await repo.getDay(_yesterdayKey);
      expect(stored, isNotNull);
      expect(stored!.dayKey, _yesterdayKey);
      expect(stored.kcal, 257);
      expect(await repo.getDay(_todayKey), isNull);
      expect(state().loaded, isTrue);
      expect(state().kcal, 257);
    });

    test('persists on an explicitly picked day', () async {
      final DateTime older = DateTime.utc(2026, 9, 15);
      await open();
      container.read(exerciseSelectedDayProvider.notifier).select(older);
      await pumpEventQueue();
      controller().setKcal(400);

      expect(await controller().save(), isTrue);

      expect((await repo.getDay(older))!.kcal, 400);
      expect(await repo.getDay(_yesterdayKey), isNull);
    });

    test('upserts: a second save replaces the same day', () async {
      await open();
      controller().setKcal(100);
      await controller().save();
      controller().setKcal(400);
      await controller().save();

      expect((await repo.getDay(_yesterdayKey))!.kcal, 400);
      final List<DailyExercise> range = await repo
          .watchRange(
            startInclusive: _yesterdayKey,
            endExclusive: _yesterdayKey.add(const Duration(days: 1)),
          )
          .first;
      expect(range, hasLength(1));
    });
  });

  group('clear', () {
    test('deletes the selected day and resets the draft', () async {
      await open();
      controller().setKcal(300);
      await controller().save();

      await controller().clear();

      expect(await repo.getDay(_yesterdayKey), isNull);
      expect(state().kcal, isNull);
      expect(state().day, _yesterdayKey);
      expect(state().loaded, isTrue);
    });
  });
}
