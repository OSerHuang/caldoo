/// An ERRORED repository stream must not render as a zero day/week/month.
///
/// The rollup providers fold `.value ?? []`, so an errored stream used to fall
/// through the loading gate (an error is neither loading nor hasValue) and the
/// summary claimed 摄入 0 against a full budget — a factual lie on the worst
/// possible surface. All three levels now keep their loading state; the meal
/// list under the card carries the retry UI for the underlying failure.
///
/// A saved profile is part of the fixture deliberately: without one the state
/// would be `NoProfile` and the gate untestable — the regression only shows
/// with a complete profile, where the state used to become `Ready` with zeros.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'package:caldoo/core/providers/app_providers.dart';
import 'package:caldoo/core/time/day_tick_provider.dart';
import 'package:caldoo/core/time/date_windows.dart' show MealWithItems;
import 'package:caldoo/domain/models/models.dart';
import 'package:caldoo/features/dashboard/daily/daily_summary.dart';
import 'package:caldoo/features/dashboard/daily/daily_summary_providers.dart';
import 'package:caldoo/features/dashboard/monthly/monthly_summary_providers.dart';
import 'package:caldoo/features/dashboard/period/period_summary.dart';
import 'package:caldoo/features/dashboard/weekly/weekly_summary_providers.dart';

import '../../data/repositories/fake_repositories.dart';
import 'daily/_fixtures.dart' show dashboardClock, dashboardOffset;
import 'monthly/_fixtures.dart' show monthlyClock, monthlyOffset;
import 'weekly/_fixtures.dart' show weeklyClock, weeklyOffset;

/// A meal repository whose live streams fail — the disk-I/O shape the gate
/// exists for. Every windowed watch delegates to [watchMealsInRange].
class _ErroringMealRepository extends FakeMealRepository {
  @override
  Stream<List<MealWithItems>> watchMealsInRange({
    required DateTime startInclusive,
    required DateTime endExclusive,
  }) => Stream.error(StateError('disk I/O failed'));
}

/// The task-7 profile, saved so the summary would otherwise render `Ready`
/// with the errored stream's zeros.
Future<void> _saveProfile(FakeProfileRepository repo) async {
  await repo.saveProfile(
    UserProfile(
      sex: Sex.male,
      birthDate: DateTime.utc(1995, 10, 22),
      heightCm: 175,
      weightKg: 70,
    ),
  );
}

/// One container per level: the level's time seams and profile port are
/// supplied by the caller, the day tick is silent, the meal streams error and
/// the exercise port is a healthy empty fake.
ProviderContainer _container(List<Override> overrides) {
  return ProviderContainer(
    overrides: <Override>[
      mealRepositoryProvider.overrideWithValue(_ErroringMealRepository()),
      exerciseRepositoryProvider.overrideWithValue(FakeExerciseRepository()),
      dayTickProvider.overrideWith((ref) => const Stream<int>.empty()),
      ...overrides,
    ],
  );
}

void main() {
  test('daily: an errored meal stream stays on the loading state', () async {
    final FakeProfileRepository profileRepo = FakeProfileRepository();
    await _saveProfile(profileRepo);
    final ProviderContainer container = _container(<Override>[
      dashboardClockProvider.overrideWithValue(dashboardClock()),
      dashboardOffsetProvider.overrideWithValue(dashboardOffset),
      profileRepositoryProvider.overrideWithValue(profileRepo),
    ]);
    addTearDown(container.dispose);

    final DateTime dayKey = container.read(dashboardTodayKeyProvider);

    expect(
      container.read(dailySummaryForDayProvider(dayKey)),
      isA<DailySummaryLoading>(),
      reason: 'no intake number may be claimed from a failed stream',
    );
  });

  test('weekly: an errored meal stream stays on the loading state', () async {
    final FakeProfileRepository profileRepo = FakeProfileRepository();
    await _saveProfile(profileRepo);
    final ProviderContainer container = _container(<Override>[
      weeklyClockProvider.overrideWithValue(weeklyClock()),
      weeklyOffsetProvider.overrideWithValue(weeklyOffset),
      profileRepositoryProvider.overrideWithValue(profileRepo),
    ]);
    addTearDown(container.dispose);

    final DateTime mondayKey = container.read(weeklyCurrentMondayKeyProvider);

    expect(
      container.read(weeklySummaryForWeekProvider(mondayKey)),
      isA<PeriodSummaryLoading>(),
      reason: 'no intake number may be claimed from a failed stream',
    );
  });

  test('monthly: an errored meal stream stays on the loading state', () async {
    final FakeProfileRepository profileRepo = FakeProfileRepository();
    await _saveProfile(profileRepo);
    final ProviderContainer container = _container(<Override>[
      monthlyClockProvider.overrideWithValue(monthlyClock()),
      monthlyOffsetProvider.overrideWithValue(monthlyOffset),
      profileRepositoryProvider.overrideWithValue(profileRepo),
    ]);
    addTearDown(container.dispose);

    final DateTime monthKey = container.read(monthlyCurrentMonthKeyProvider);

    expect(
      container.read(monthlySummaryForMonthProvider(monthKey)),
      isA<PeriodSummaryLoading>(),
      reason: 'no intake number may be claimed from a failed stream',
    );
  });
}
