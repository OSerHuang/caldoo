/// The Home / 概览 tab: one dashboard with day, week and month views.
///
/// The app used to expose two separate dashboards — 今日 (a day, swipeable
/// through past days) and 汇总 (a week, swipeable through past weeks). They are
/// now **one screen**: the landing tab always opens on the **day** view (今日),
/// and a 日 / 周 / 月 segmented switcher above the content selects the period
/// the whole screen reports on. Adding the month view is why the two dashboards
/// could be merged rather than kept side by side: the switcher is the only way
/// a user changes "how much" they are looking at, and every mode is browsable
/// history in exactly the same way.
///
/// Each mode keeps the task-27 [HistoryPeriodPager] behaviour: offset 0 is the
/// current period (the rightmost, non-future page) and dragging the finger
/// right reveals the previous day / week / month, with a ‹ header button, a ›
/// button that only appears in history (there is no newer period to reach from
/// today / this week / this month), and a "back to now" action. Once a mode has
/// been visited its pager lives in an [IndexedStack], so each mode keeps **its
/// own** browsed period and scroll position while the user switches between
/// them; switching back to 日 after browsing September in 月 therefore does not
/// reset the month page. A mode is mounted only on its **first** visit: opening
/// the app on 日 must not pay for a month-wide query and 28..31 rollups the user
/// may never look at.
///
/// There is still no global "selected day/week/month" state: every page maps
/// its offset to a date-only key and hands that key to the period's keyed
/// *family* providers (`DailySummaryView(dayKey:)`,
/// `WeeklySummaryView(weekMonday:)`, `MonthlySummaryView(monthKey:)`,
/// `dailyMealsForDayProvider(dayKey)`, …), so each page renders its own live
/// period while the header is shared.
///
/// The day view composes the task-24 daily summary hero card with two quick-add
/// actions (a meal and an exercise) and a live, FLAT list of everything eaten on
/// the viewed day: one row per food (name, grams, kcal), never the meal-type
/// buckets (早餐/午餐/晚餐/加餐). Tapping a food row opens the `/meal/:id` detail
/// of the meal it belongs to. Week and month views show their chart and
/// cumulative totals only.
///
/// The quick-add actions push the capture and exercise-entry routes on this
/// tab's own branch (`/today/capture`, `/today/exercise`): the former 记录 hub
/// is gone, so logging a meal / exercise is a flow of the 概览 tab and returns
/// here.
///
/// Quick-add is only offered on today's day page: meal capture records "now",
/// so adding from a past page — or from a week/month view — would log the meal
/// on the wrong day.
///
/// Everything is driven by the task-24/22/26 `watch` streams, so the numbers and
/// the list update the moment a meal or exercise is saved on another route.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:caldoo/core/time/date_windows.dart';
import 'package:caldoo/core/ui/app_card.dart';
import 'package:caldoo/core/ui/history_period_pager.dart';
import 'package:caldoo/core/ui/section_header.dart';
import 'package:caldoo/core/ui/value_unit_text.dart';
import 'package:caldoo/core/units/display_units.dart';
import 'package:caldoo/domain/models/models.dart';
import 'package:caldoo/features/dashboard/daily/daily_summary_providers.dart';
import 'package:caldoo/features/dashboard/daily/daily_summary_view.dart';
import 'package:caldoo/features/dashboard/monthly/monthly_summary_providers.dart';
import 'package:caldoo/features/dashboard/monthly/monthly_summary_view.dart';
import 'package:caldoo/features/dashboard/weekly/weekly_summary_providers.dart';
import 'package:caldoo/features/dashboard/weekly/weekly_summary_view.dart';
import 'package:caldoo/l10n/app_format.dart';
import 'package:caldoo/l10n/app_strings.dart';

/// Key of the Today screen scaffold.
const Key todayScreenKey = Key('today_screen');

/// Key of the 日 / 周 / 月 period switcher.
const Key todayViewSwitcherKey = Key('today_view_switcher');

/// Key of the switcher's 日 (day) segment label.
const Key todayViewDayKey = Key('today_view_day');

/// Key of the switcher's 周 (week) segment label.
const Key todayViewWeekKey = Key('today_view_week');

/// Key of the switcher's 月 (month) segment label.
const Key todayViewMonthKey = Key('today_view_month');

/// Key of the quick-add-meal action.
const Key todayQuickAddMealKey = Key('today_quick_add_meal');

/// Key of the quick-add-exercise action.
const Key todayQuickAddExerciseKey = Key('today_quick_add_exercise');

/// Key of the "no meals logged" empty state.
const Key todayMealsEmptyKey = Key('today_meals_empty');

/// Key of the meals load-failure message.
const Key todayMealsErrorKey = Key('today_meals_error');

/// Key of the meals retry action.
const Key todayMealsRetryKey = Key('today_meals_retry');

/// Key of the day-log row for the food (meal item) with [id].
Key todayFoodRowKey(String id) => Key('today_food_$id');

/// The period the dashboard is currently reporting on.
///
/// The first value is the default: the app lands on the day view (今日), which
/// is the screen's historical behaviour.
enum DashboardView {
  /// One local day (the task-24 daily summary + the day's food log).
  day,

  /// The fixed Mon..Sun local week (the task-26 weekly summary).
  week,

  /// The local calendar month (the monthly summary).
  month,
}

/// The landing "概览" tab: the day, week and month dashboards behind one
/// switcher, each browsable through its own past.
class TodayScreen extends ConsumerStatefulWidget {
  /// Creates the Today screen.
  const TodayScreen({super.key});

  @override
  ConsumerState<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends ConsumerState<TodayScreen> {
  /// The selected view. Deliberately widget state, not a provider: the user
  /// asked for the day view to be what the tab opens on, so a fresh mount
  /// always starts at [DashboardView.day].
  DashboardView _view = DashboardView.day;

  /// The views that have been opened at least once.
  ///
  /// The day view is always built (it is the landing view). A week/month pager
  /// is mounted on its first visit and stays mounted afterwards, so the data
  /// cost of a mode is paid when the user actually asks for it — and never
  /// again after that.
  final Set<DashboardView> _visited = <DashboardView>{DashboardView.day};

  @override
  Widget build(BuildContext context) {
    // The pagers are past-only and page 0 is "now": the current day / week /
    // month keys come from the current-key providers, which re-derive on every
    // dayTickProvider signal — so a warm start that slept across local
    // midnight lands the day view on the new day without a restart.
    final DateTime todayKey = ref.watch(dashboardTodayKeyProvider);
    final DateTime currentMonday = ref.watch(weeklyCurrentMondayKeyProvider);
    final DateTime currentMonth = ref.watch(monthlyCurrentMonthKeyProvider);

    return Scaffold(
      key: todayScreenKey,
      appBar: AppBar(title: Text(S.of(context).overviewTitle)),
      body: Column(
        children: <Widget>[
          _ViewSwitcher(
            view: _view,
            onChanged: (DashboardView view) => setState(() {
              _view = view;
              _visited.add(view);
            }),
          ),
          Expanded(
            // IndexedStack (not a plain `switch`) so each mode's pager keeps
            // its browsed period and scroll position while another mode is
            // shown: swapping the child would dispose its PageView state. A
            // never-visited mode is a zero-sized placeholder instead, which is
            // what keeps the month's wide query off the app's start-up path.
            // IndexedStack hides the non-selected children from painting,
            // hit-testing, semantics and (for Finders) the tree walk.
            child: IndexedStack(
              index: _view.index,
              children: <Widget>[
                _dayPager(todayKey),
                if (_visited.contains(DashboardView.week))
                  _weekPager(currentMonday)
                else
                  const SizedBox.shrink(),
                if (_visited.contains(DashboardView.month))
                  _monthPager(currentMonth)
                else
                  const SizedBox.shrink(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// The day view's pager: offset 0 is today, offset N the day N days before.
  Widget _dayPager(DateTime todayKey) {
    return HistoryPeriodPager(
      id: 'today',
      previousTooltip: S.of(context).historyPreviousDay,
      nextTooltip: S.of(context).historyNextDay,
      backToNowLabel: S.of(context).historyBackToToday,
      periodLabel: (int offset) => offset == 0
          ? S.of(context).historyToday
          : AppFormat.dateWithWeekday(
              todayKey.subtract(Duration(days: offset)),
              // 概览's date rule: the year is shown only on dates outside the
              // current one, so history stays compact while browsing.
              currentYear: todayKey.year,
            ),
      periodBuilder: (BuildContext context, int offset) =>
          _DayPage(todayKey: todayKey, pageOffset: offset),
    );
  }

  /// The week view's pager: offset 0 is the current Mon..Sun week.
  Widget _weekPager(DateTime currentMonday) {
    return HistoryPeriodPager(
      id: 'week',
      previousTooltip: S.of(context).historyPreviousWeek,
      nextTooltip: S.of(context).historyNextWeek,
      backToNowLabel: S.of(context).historyBackToThisWeek,
      periodLabel: (int offset) {
        if (offset == 0) {
          return S.of(context).historyThisWeek;
        }
        final DateTime monday = _mondayFor(currentMonday, offset);
        return AppFormat.dateRange(
          monday,
          monday.add(const Duration(days: 6)),
          currentYear: currentMonday.year,
        );
      },
      periodBuilder: (BuildContext context, int offset) {
        final DateTime monday = _mondayFor(currentMonday, offset);
        return SingleChildScrollView(
          // Same page padding as the day and month views, so switching views
          // never shifts the card sideways or up.
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: WeeklySummaryView(
            weekMonday: monday,
            isCurrentWeek: offset == 0,
          ),
        );
      },
    );
  }

  /// The month view's pager: offset 0 is the current calendar month.
  Widget _monthPager(DateTime currentMonth) {
    return HistoryPeriodPager(
      id: 'month',
      previousTooltip: S.of(context).historyPreviousMonth,
      nextTooltip: S.of(context).historyNextMonth,
      backToNowLabel: S.of(context).historyBackToThisMonth,
      periodLabel: (int offset) => offset == 0
          ? S.of(context).historyThisMonth
          : AppFormat.month(
              monthKeyAfter(currentMonth, -offset),
              currentYear: currentMonth.year,
            ),
      periodBuilder: (BuildContext context, int offset) {
        final DateTime monthKey = monthKeyAfter(currentMonth, -offset);
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: MonthlySummaryView(
            monthKey: monthKey,
            isCurrentMonth: offset == 0,
          ),
        );
      },
    );
  }

  /// The date-only Monday key of the week [offset] weeks before [currentMonday].
  static DateTime _mondayFor(DateTime currentMonday, int offset) =>
      currentMonday.subtract(Duration(days: 7 * offset));
}

/// The 日 / 周 / 月 switcher above the dashboard content.
///
/// A [SegmentedButton] rather than a tab bar: the three views are three ways of
/// looking at the same data, not three destinations, so the bottom navigation
/// keeps exactly three destinations (概览 / 食物库 / 我的).
class _ViewSwitcher extends StatelessWidget {
  const _ViewSwitcher({required this.view, required this.onChanged});

  /// The currently selected view.
  final DashboardView view;

  /// Called with the newly selected view.
  final ValueChanged<DashboardView> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: SegmentedButton<DashboardView>(
        key: todayViewSwitcherKey,
        // Full-width segments: the switcher is the screen's primary control.
        expandedInsets: EdgeInsets.zero,
        // The three segments are short enough that the leading checkmark would
        // only squeeze the labels.
        showSelectedIcon: false,
        segments: <ButtonSegment<DashboardView>>[
          ButtonSegment<DashboardView>(
            value: DashboardView.day,
            label: Text(S.of(context).viewDay, key: todayViewDayKey),
          ),
          ButtonSegment<DashboardView>(
            value: DashboardView.week,
            label: Text(S.of(context).viewWeek, key: todayViewWeekKey),
          ),
          ButtonSegment<DashboardView>(
            value: DashboardView.month,
            label: Text(S.of(context).viewMonth, key: todayViewMonthKey),
          ),
        ],
        selected: <DashboardView>{view},
        onSelectionChanged: (Set<DashboardView> selection) =>
            onChanged(selection.first),
      ),
    );
  }
}

/// One page of the day view's pager: the day [pageOffset] days before
/// [todayKey].
///
/// The page hands its own date-only key to the day-keyed **family** providers
/// (`DailySummaryView(dayKey:)` and `dailyMealsForDayProvider(dayKey)`), so each
/// page renders its own day while the unscoped "current day" projections keep
/// their existing behaviour. A nested `ProviderScope` override of the day seam
/// deliberately is NOT used: Riverpod 3 only re-mounts providers that declare
/// `$allTransitiveDependencies` (code-generated ones) in a nested scope, so the
/// hand-written daily providers would have kept reading the root/current day.
class _DayPage extends StatelessWidget {
  const _DayPage({required this.todayKey, required this.pageOffset});

  /// The date-only key of today (offset 0).
  final DateTime todayKey;

  /// How many days before [todayKey] this page is (`0` = today).
  final int pageOffset;

  @override
  Widget build(BuildContext context) {
    final DateTime dayKey = todayKey.subtract(Duration(days: pageOffset));
    return _DayPageBody(dayKey: dayKey, isToday: pageOffset == 0);
  }
}

/// The scrollable content of one day's page.
class _DayPageBody extends StatelessWidget {
  const _DayPageBody({required this.dayKey, required this.isToday});

  /// The date-only key of the day this page renders.
  final DateTime dayKey;

  /// Whether this page is the current day (offset 0).
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: <Widget>[
        DailySummaryView(dayKey: dayKey, isToday: isToday),
        if (isToday) ...<Widget>[
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              Expanded(
                child: FilledButton.icon(
                  key: todayQuickAddMealKey,
                  onPressed: () => context.push('/today/capture'),
                  icon: const Icon(Icons.restaurant_menu),
                  label: Text(S.of(context).quickAddMeal),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  key: todayQuickAddExerciseKey,
                  onPressed: () => context.push('/today/exercise'),
                  icon: const Icon(Icons.directions_run),
                  label: Text(S.of(context).quickAddExercise),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 24),
        SectionHeader(
          title: isToday
              ? S.of(context).todayLogHeading
              : S.of(context).historyLogHeading,
        ),
        const SizedBox(height: 12),
        _DayFoodList(dayKey: dayKey, isToday: isToday),
      ],
    );
  }
}

/// One food entry in the day log: the item plus the meal it belongs to (the
/// tap target's `/meal/:id` route).
typedef _LoggedFood = ({MealWithItems group, MealItem item});

/// The live, FLAT list of everything eaten on the viewed day.
///
/// The list is chronological — the repository orders meals by timestamp and
/// each meal's items keep their stored order — and contains one row per FOOD.
/// Meal-type buckets (早餐/午餐/晚餐/加餐) are deliberately NOT rendered here, so
/// the log answers "what did I eat today?" directly instead of grouping it.
class _DayFoodList extends ConsumerWidget {
  const _DayFoodList({required this.dayKey, required this.isToday});

  /// The date-only key of the day this list renders.
  final DateTime dayKey;

  /// Whether this list belongs to the current day (offset 0).
  final bool isToday;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<MealWithItems>> meals = ref.watch(
      dailyMealsForDayProvider(dayKey),
    );
    return meals.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (Object error, StackTrace stack) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            isToday
                ? S.of(context).todayMealsError
                : S.of(context).historyMealsError,
            key: todayMealsErrorKey,
          ),
          TextButton(
            key: todayMealsRetryKey,
            onPressed: () => ref.invalidate(dailyMealsForDayProvider(dayKey)),
            child: Text(S.of(context).retry),
          ),
        ],
      ),
      data: (List<MealWithItems> groups) {
        final List<_LoggedFood> foods = <_LoggedFood>[
          for (final MealWithItems group in groups)
            for (final MealItem item in group.items) (group: group, item: item),
        ];
        if (foods.isEmpty) {
          return AppCard(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            child: Row(
              children: <Widget>[
                Icon(
                  Icons.rice_bowl_outlined,
                  size: 20,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isToday
                        ? S.of(context).todayMealsEmpty
                        : S.of(context).historyMealsEmpty,
                    key: todayMealsEmptyKey,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          );
        }
        return Column(
          children: <Widget>[
            for (final _LoggedFood food in foods)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _FoodRow(
                  item: food.item,
                  onTap: () => context.push('/meal/${food.group.meal.id}'),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// One food row: the food name and its weight on the left, the food's own kcal
/// on the right. Tapping opens the meal the food belongs to.
class _FoodRow extends StatelessWidget {
  const _FoodRow({required this.item, required this.onTap});

  final MealItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    // Display-only preference: kcal or kJ, never a rewrite of the stored item.
    final DisplayUnits units = DisplayUnits.of(context);
    return AppCard(
      key: todayFoodRowKey(item.id),
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  item.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 3),
                Text(
                  S.of(context).foodGrams(AppFormat.number(item.grams)),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ValueUnitText(
            units.energyValueText(item.kcal),
            units.energyUnit,
            valueStyle: theme.textTheme.titleMedium!.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.chevron_right,
            size: 20,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}
