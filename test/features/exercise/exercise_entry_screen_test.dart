/// The one-per-day exercise-burn flow end-to-end through the widget, with the
/// selected day's burn feeding the energy engine.
///
/// Everything runs against in-memory fakes and the real providers: no socket,
/// no platform channel, no file DB.
///
/// Covered here are the day rules the screen exists for: it opens on
/// **yesterday**, flips to **today** once yesterday is recorded, lets the user
/// pick any earlier day (never a future one), honours an explicitly pushed
/// initial day (a past 概览 page's quick-add) and saves/clears the selected day
/// only. The Material dialog strings are asserted in zh-CN, which is the locale
/// the app boots with.
library;

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:caldoo/core/math/energy_balance.dart';
import 'package:caldoo/core/providers/app_providers.dart';
import 'package:caldoo/core/time/date_windows.dart';
import 'package:caldoo/domain/models/daily_exercise.dart';
import 'package:caldoo/domain/models/user_profile.dart';
import 'package:caldoo/features/exercise/exercise_entry_controller.dart';
import 'package:caldoo/features/exercise/exercise_entry_screen.dart';
import 'package:caldoo/features/exercise/exercise_providers.dart';

import '../../data/repositories/fake_repositories.dart';

/// The task-7 profile: male 175cm 70kg, born 1995-10-22 (age 30 on [_now]),
/// with a pinned BMR of 1979 kcal (1978.5 rounded).
final UserProfile _profile = UserProfile(
  sex: Sex.male,
  birthDate: DateTime.utc(1995, 10, 22),
  heightCm: 175,
  weightKg: 70,
  bmrKcalOverride: 1979,
);

/// 2026-09-21 12:00 +08:00.
final DateTime _now = DateTime.utc(2026, 9, 21, 4);

/// The date-only key of that day.
final DateTime _todayKey = DateTime.utc(2026, 9, 21);

/// The date-only key of the preceding local day — the form's opening default.
final DateTime _yesterdayKey = DateTime.utc(2026, 9, 20);

/// The mutable "now" the injected clock reads; tests may roll it over.
DateTime _clockNow = _now;

void main() {
  late FakeExerciseRepository exerciseRepo;
  late ProviderContainer container;

  setUp(() {
    _clockNow = _now;
    exerciseRepo = FakeExerciseRepository();
    container = ProviderContainer(
      overrides: [
        exerciseRepositoryProvider.overrideWithValue(exerciseRepo),
        exerciseClockProvider.overrideWithValue(Clock(() => _clockNow)),
        exerciseOffsetProvider.overrideWithValue(const LocalOffset(480)),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await exerciseRepo.dispose();
  });

  /// Pumps the screen (real zh-CN Material localizations, like production) on
  /// a tall surface. The container is owned by the test so a re-entry can share
  /// it. [initialDay] forwards the route's pushed target day, if any.
  Future<void> pumpScreen(WidgetTester tester, {DateTime? initialDay}) async {
    tester.view.physicalSize = const Size(1200, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('zh', 'CN'),
          supportedLocales: const <Locale>[Locale('zh', 'CN')],
          localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: ExerciseEntryScreen(initialDay: initialDay),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  String fieldText(WidgetTester tester) => tester
      .widget<TextField>(find.byKey(exerciseKcalFieldKey))
      .controller!
      .text;

  String dateText(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(exerciseSelectedDateKey)).data!;

  String valueText(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(exerciseDayValueKey)).data!;

  Future<void> save(WidgetTester tester) async {
    await tester.tap(find.byKey(exerciseSaveButtonKey));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'opens on yesterday: empty readout, blank field, nothing stored',
    (WidgetTester tester) async {
      await pumpScreen(tester);

      expect(dateText(tester), '昨天 · 2026年9月20日');
      expect(valueText(tester), '还没有记录运动消耗');
      expect(fieldText(tester), '');
      expect(await exerciseRepo.getDay(_yesterdayKey), isNull);
    },
  );

  testWidgets(
    'a typed burn saves for yesterday and drives that day\'s budget',
    (WidgetTester tester) async {
      await pumpScreen(tester);

      await tester.enterText(find.byKey(exerciseKcalFieldKey), '257');
      await tester.pumpAndSettle();
      // The burn field is digits-only: a decimal point cannot be entered, so a
      // user typing "257." still has "257" in the field.
      await tester.enterText(find.byKey(exerciseKcalFieldKey), '257.');
      await tester.pumpAndSettle();
      expect(fieldText(tester), '257');
      await save(tester);

      final DailyExercise? stored = await exerciseRepo.getDay(_yesterdayKey);
      expect(stored, isNotNull);
      expect(stored!.dayKey, _yesterdayKey);
      expect(stored.kcal, 257);
      expect(await exerciseRepo.getDay(_todayKey), isNull);

      expect(find.text('已记录：257 kcal'), findsOneWidget);
      expect(valueText(tester), '已记录：257 kcal');

      // The burn is added back to the day's budget by the energy engine.
      final EnergyBudget budget = computeEnergyBudget(
        profile: _profile,
        intakeKcal: 0,
        exerciseKcal: stored.kcal,
        today: _now,
      ) as EnergyBudget;
      expect(budget.baseBudgetKcal, 1979);
      expect(budget.budgetKcal, 2236);
      expect(budget.exerciseKcal, 257);

      expect(container.read(exerciseEntryControllerProvider).kcal, 257);
    },
  );

  testWidgets('once yesterday is recorded, the form opens on today', (
    WidgetTester tester,
  ) async {
    await exerciseRepo.setKcal(dayKey: _yesterdayKey, kcal: 300);
    await pumpScreen(tester);

    expect(dateText(tester), '今天 · 2026年9月21日');
    expect(valueText(tester), '还没有记录运动消耗');
    expect(fieldText(tester), '');

    await tester.enterText(find.byKey(exerciseKcalFieldKey), '120');
    await tester.pumpAndSettle();
    await save(tester);

    expect((await exerciseRepo.getDay(_todayKey))!.kcal, 120);
    expect((await exerciseRepo.getDay(_yesterdayKey))!.kcal, 300);
    expect(valueText(tester), '已记录：120 kcal');
  });

  testWidgets('when both days are recorded, today is prefilled and editable', (
    WidgetTester tester,
  ) async {
    await exerciseRepo.setKcal(dayKey: _yesterdayKey, kcal: 300);
    await exerciseRepo.setKcal(dayKey: _todayKey, kcal: 120);
    await pumpScreen(tester);

    expect(dateText(tester), '今天 · 2026年9月21日');
    expect(fieldText(tester), '120');
    expect(valueText(tester), '已记录：120 kcal');
  });

  testWidgets(
    'a pushed initial day opens on exactly that day and saves there',
    (WidgetTester tester) async {
      // The quick-add on a past 概览 day page pushes the browsed day as the
      // route's extra; the form must open on that day, not on its own
      // yesterday/today default.
      final DateTime pushedDay = DateTime.utc(2026, 9, 18);
      await exerciseRepo.setKcal(dayKey: pushedDay, kcal: 90);
      await pumpScreen(tester, initialDay: pushedDay);

      // The pushed day — not the default — with its stored burn prefilled.
      expect(dateText(tester), '2026年9月18日');
      expect(fieldText(tester), '90');
      expect(valueText(tester), '已记录：90 kcal');

      await tester.enterText(find.byKey(exerciseKcalFieldKey), '180');
      await tester.pumpAndSettle();
      await save(tester);

      expect((await exerciseRepo.getDay(pushedDay))!.kcal, 180);
      // The default days are untouched by the explicit pick.
      expect(await exerciseRepo.getDay(_yesterdayKey), isNull);
      expect(await exerciseRepo.getDay(_todayKey), isNull);
    },
  );

  testWidgets('the 昨天/今天 shortcut switches days and loads their value', (
    WidgetTester tester,
  ) async {
    await exerciseRepo.setKcal(dayKey: _yesterdayKey, kcal: 300);
    await pumpScreen(tester);
    // Yesterday is recorded, so the default is today.
    expect(dateText(tester), '今天 · 2026年9月21日');

    await tester.tap(find.text('昨天'));
    await tester.pumpAndSettle();

    expect(dateText(tester), '昨天 · 2026年9月20日');
    expect(fieldText(tester), '300');
    expect(valueText(tester), '已记录：300 kcal');

    await tester.tap(find.text('今天'));
    await tester.pumpAndSettle();

    expect(dateText(tester), '今天 · 2026年9月21日');
    expect(fieldText(tester), '');
    expect(valueText(tester), '还没有记录运动消耗');
  });

  testWidgets(
    'the date card opens a picker limited to today and the past year',
    (WidgetTester tester) async {
      await exerciseRepo.setKcal(dayKey: DateTime.utc(2026, 9, 18), kcal: 400);
      await pumpScreen(tester);

      await tester.tap(find.byKey(exerciseDateCardKey));
      await tester.pumpAndSettle();

      expect(find.text('选择记录日期'), findsOneWidget);
      final DatePickerDialog dialog = tester.widget<DatePickerDialog>(
        find.byType(DatePickerDialog),
      );
      // A burn is never logged for a future day, and the picker starts on the
      // day currently being edited.
      expect(dialog.firstDate, DateTime(2025, 9, 21));
      expect(dialog.lastDate, DateTime(2026, 9, 21));
      expect(dialog.initialDate, DateTime(2026, 9, 20));

      // Pick the 18th (an older, already recorded day) and confirm.
      await tester.tap(find.text('18'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('确定'));
      await tester.pumpAndSettle();

      expect(dateText(tester), '2026年9月18日');
      expect(fieldText(tester), '400');
      expect(valueText(tester), '已记录：400 kcal');

      // Editing saves to the picked day only.
      await tester.enterText(find.byKey(exerciseKcalFieldKey), '450');
      await tester.pumpAndSettle();
      await save(tester);

      expect((await exerciseRepo.getDay(DateTime.utc(2026, 9, 18)))!.kcal, 450);
      expect(await exerciseRepo.getDay(_yesterdayKey), isNull);
      expect(dateText(tester), '2026年9月18日');
    },
  );

  testWidgets('clear removes the selected day only and empties the field', (
    WidgetTester tester,
  ) async {
    await exerciseRepo.setKcal(dayKey: _yesterdayKey, kcal: 300);
    await exerciseRepo.setKcal(dayKey: _todayKey, kcal: 120);
    await pumpScreen(tester);

    await tester.tap(find.text('昨天'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(exerciseClearButtonKey));
    await tester.pumpAndSettle();

    expect(await exerciseRepo.getDay(_yesterdayKey), isNull);
    expect((await exerciseRepo.getDay(_todayKey))!.kcal, 120);
    expect(fieldText(tester), '');
    expect(valueText(tester), '还没有记录运动消耗');
  });

  testWidgets('a blank value is refused on save (documented), nothing stored', (
    WidgetTester tester,
  ) async {
    await pumpScreen(tester);

    await save(tester);

    expect(find.byKey(exerciseErrorKey), findsOneWidget);
    expect(find.text('请输入大于 0 的运动消耗'), findsOneWidget);
    expect(await exerciseRepo.getDay(_yesterdayKey), isNull);
  });

  testWidgets('editing a saved value replaces the same day', (
    WidgetTester tester,
  ) async {
    await exerciseRepo.setKcal(dayKey: _yesterdayKey, kcal: 300);
    await pumpScreen(tester);
    await tester.tap(find.text('昨天'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(exerciseKcalFieldKey), '450');
    await tester.pumpAndSettle();
    await save(tester);

    expect((await exerciseRepo.getDay(_yesterdayKey))!.kcal, 450);
  });

  testWidgets('opening the next morning resolves against the new day', (
    WidgetTester tester,
  ) async {
    await pumpScreen(tester);
    expect(dateText(tester), '昨天 · 2026年9月20日');

    // The app stays alive overnight; the next open must read the new date, not
    // the cached one from the previous visit.
    _clockNow = DateTime.utc(2026, 9, 22, 3); // 2026-09-22 11:00 +08:00
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await pumpScreen(tester);

    expect(dateText(tester), '昨天 · 2026年9月21日');
    expect(fieldText(tester), '');
  });

  testWidgets('re-entering the screen re-applies the opening default', (
    WidgetTester tester,
  ) async {
    await pumpScreen(tester);
    await tester.tap(find.text('今天'));
    await tester.pumpAndSettle();
    expect(dateText(tester), '今天 · 2026年9月21日');

    // Leave the screen and come back: nothing was recorded, so the next open
    // must fall back to yesterday instead of the stale explicit pick.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await pumpScreen(tester);

    expect(dateText(tester), '昨天 · 2026年9月20日');
    expect(fieldText(tester), '');
  });
}
