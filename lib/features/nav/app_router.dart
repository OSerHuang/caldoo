/// The app's single [GoRouter] (task 27).
///
/// Structure:
/// * one [StatefulShellRoute.indexedStack] with three branches — 概览 / 食物库 /
///   我的 — each with its **own** [Navigator], so per-tab state and navigation
///   stacks survive tab switches. The former 汇总 branch is gone (its week and
///   month dashboards live inside the 概览 tab, behind that screen's own
///   日/周/月 switcher), and so is the 记录 hub: the logging flows now run
///   inside the 概览 branch, started from its quick-add actions.
/// * a top-level `/meal/:id` deep link that renders the task-22 per-meal
///   summary outside the shell;
/// * every existing feature screen wired into a route: meal capture + review
///   and exercise entry under 概览, nutrition-label capture (the food library's
///   add-food flow) under 食物库, plus profile, settings, the privacy notice and
///   data backup under 我的.
///
/// The capture → review hop reuses the task-18 seam: the capture route scopes a
/// `reviewRouterProvider` override that turns a [CaptureSubmission] (the
/// validated AI draft plus the photos/text it came from) into a [ReviewArgs]
/// and pushes `/today/review`. The task-18 default (a plain placeholder push)
/// is left untouched, so its widget tests keep passing.
library;

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import 'package:caldoo/core/time/date_windows.dart'
    show LocalOffset, MealWithItems;
import 'package:caldoo/domain/models/models.dart';
import 'package:caldoo/features/exercise/exercise_entry_screen.dart';
import 'package:caldoo/features/meals/capture/meal_capture_controller.dart';
import 'package:caldoo/features/meals/capture/meal_capture_screen.dart';
import 'package:caldoo/features/meals/label/label_capture_screen.dart';
import 'package:caldoo/features/meals/review/meal_review_screen.dart';
import 'package:caldoo/features/meals/summary/meal_summary_providers.dart'
    show localOffsetProvider;
import 'package:caldoo/features/meals/saved_foods/food_library_screen.dart';
import 'package:caldoo/features/nav/meal_detail_screen.dart';
import 'package:caldoo/features/nav/nav_shell.dart';
import 'package:caldoo/features/nav/profile_tab_screen.dart';
import 'package:caldoo/features/nav/review_args.dart';
import 'package:caldoo/features/nav/today_screen.dart';
import 'package:caldoo/features/profile/profile_screen.dart';
import 'package:caldoo/features/weight/weight_trend_screen.dart';
import 'package:caldoo/features/settings/ai_settings_screen.dart';
import 'package:caldoo/features/settings/backup/backup_screen.dart';
import 'package:caldoo/features/settings/display_settings_screen.dart';
import 'package:caldoo/features/settings/privacy/privacy_notice.dart';
import 'package:caldoo/features/settings/settings_screen.dart';
import 'package:caldoo/l10n/app_strings.dart';

/// Key of the "review route reached without a draft" fallback.
const Key reviewMissingArgsKey = Key('review_missing_args');

/// Key of the meal-edit route's "meal not found" empty state.
const Key mealEditMissingKey = Key('meal_edit_missing');

/// The app-wide router. Disposed with the provider container.
final appRouterProvider = Provider<GoRouter>((ref) {
  final GoRouter router = GoRouter(
    initialLocation: '/today',
    routes: <RouteBase>[_shellRoute(), _mealDetailRoute()],
  );
  ref.onDispose(router.dispose);
  return router;
});

/// The three-branch bottom-navigation shell.
StatefulShellRoute _shellRoute() {
  return StatefulShellRoute.indexedStack(
    builder: (
      BuildContext context,
      GoRouterState state,
      StatefulNavigationShell navigationShell,
    ) => NavShell(navigationShell: navigationShell),
    branches: <StatefulShellBranch>[
      StatefulShellBranch(
        routes: <RouteBase>[
          GoRoute(
            path: '/today',
            builder: (BuildContext context, GoRouterState state) =>
                const TodayScreen(),
            // Meal capture, review and exercise entry are pushed onto the 概览
            // branch from its quick-add actions, so the bottom bar stays
            // visible and the branch keeps whatever the user was doing.
            routes: <RouteBase>[
              _captureRoute(),
              _reviewRoute(),
              GoRoute(
                path: 'exercise',
                builder: (BuildContext context, GoRouterState state) {
                  // Optional explicit day, pushed as `extra` by a past-day
                  // page's quick-add; without it the screen applies its own
                  // opening default (yesterday, or today when recorded).
                  final Object? extra = state.extra;
                  return ExerciseEntryScreen(
                    initialDay: extra is DateTime ? extra : null,
                  );
                },
              ),
              // The weight-trend page, opened from the today page's 体重 card.
              GoRoute(
                path: 'weight',
                builder: (BuildContext context, GoRouterState state) =>
                    const WeightTrendScreen(),
              ),
            ],
          ),
        ],
      ),
      StatefulShellBranch(
        routes: <RouteBase>[
          GoRoute(
            path: '/foods',
            builder: (BuildContext context, GoRouterState state) =>
                const FoodLibraryScreen(),
            routes: <RouteBase>[
              GoRoute(
                path: 'add',
                builder: (BuildContext context, GoRouterState state) =>
                    LabelCaptureScreen(
                      // `?manual=1` skips the photo step and opens the blank
                      // confirm form: the entry point chosen in the library's
                      // add-food sheet.
                      startManualEntry:
                          state.uri.queryParameters['manual'] == '1',
                    ),
              ),
            ],
          ),
        ],
      ),
      StatefulShellBranch(
        routes: <RouteBase>[
          GoRoute(
            path: '/profile',
            builder: (BuildContext context, GoRouterState state) =>
                const ProfileTabScreen(),
            routes: <RouteBase>[
              GoRoute(
                path: 'details',
                builder: (BuildContext context, GoRouterState state) =>
                    const ProfileScreen(),
              ),
              // 设置 is a hub: the model form and the display preferences are
              // second-level pages, so the hub stays a plain two-row menu.
              GoRoute(
                path: 'settings',
                builder: (BuildContext context, GoRouterState state) =>
                    const SettingsScreen(),
                routes: <RouteBase>[
                  GoRoute(
                    path: 'ai',
                    builder: (BuildContext context, GoRouterState state) =>
                        const AiSettingsScreen(),
                  ),
                  GoRoute(
                    path: 'display',
                    builder: (BuildContext context, GoRouterState state) =>
                        const DisplaySettingsScreen(),
                  ),
                ],
              ),
              GoRoute(
                path: 'privacy',
                builder: (BuildContext context, GoRouterState state) =>
                    Consumer(
                      builder:
                          (
                            BuildContext context,
                            WidgetRef ref,
                            Widget? child,
                          ) => PrivacyNoticeScreen(
                            onAccept: () async {
                              await ref
                                  .read(privacyNoticeControllerProvider)
                                  .markSeen();
                              if (context.mounted) {
                                context.pop();
                              }
                            },
                          ),
                    ),
              ),
              GoRoute(
                path: 'backup',
                builder: (BuildContext context, GoRouterState state) =>
                    const BackupScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

/// `/today/capture`: the task-18 screen, plus the reviewed-draft wiring.
///
/// The nested [ProviderScope] overrides `reviewRouterProvider` only for this
/// route, so the capture screen's AI submit pushes the real task-19 review
/// screen with a fresh owning [Meal] instead of the task-18 placeholder.
///
/// The route takes an optional backfill target: a past-day page's quick-add
/// pushes the browsed day (a date-only day key, the `dayKeyOf` shape) as
/// `extra`. Without it — today's page — the meal records "now" as before.
GoRoute _captureRoute() {
  return GoRoute(
    path: 'capture',
    builder: (BuildContext context, GoRouterState state) {
      final Object? extra = state.extra;
      final DateTime? targetDay = extra is DateTime ? extra : null;
      return ProviderScope(
        overrides: [
          reviewRouterProvider.overrideWithValue((
            BuildContext captureContext,
            CaptureSubmission submission,
          ) {
            final DateTime now = clock.now();
            final LocalOffset offset = ProviderScope.containerOf(captureContext)
                .read(localOffsetProvider);
            // Backfill: stamp the meal at **noon of the target day under the
            // app's own offset** — the same offset every day window resolves
            // with — so the instant is provably inside that day's window for
            // any supported UTC offset (±14h) and never depends on the
            // machine's clock or timezone. The hour-based type guess is
            // meaningless for a backfill, so it defaults to the noon meal;
            // the review screen's type selector corrects it.
            final DateTime timestamp;
            final MealType mealType;
            if (targetDay == null) {
              timestamp = now;
              mealType = mealTypeForHour(now.hour);
            } else {
              timestamp = DateTime.utc(
                targetDay.year,
                targetDay.month,
                targetDay.day,
              ).subtract(offset.duration).add(const Duration(hours: 12));
              mealType = MealType.lunch;
            }
            return GoRouter.of(captureContext).push<bool>(
              '/today/review',
              extra: ReviewArgs(
                draft: draftFromAnalysis(submission.draft),
                meal: Meal(
                  id: const Uuid().v4(),
                  timestamp: timestamp,
                  mealType: mealType,
                ),
                photos: submission.photos,
                userText: submission.userText,
              ),
            );
          }),
        ],
        child: const MealCaptureScreen(),
      );
    },
  );
}

/// `/today/review`: the task-19 editable review screen.
GoRoute _reviewRoute() {
  return GoRoute(
    path: 'review',
    builder: (BuildContext context, GoRouterState state) {
      final Object? extra = state.extra;
      if (extra is ReviewArgs) {
        return MealReviewScreen(
          draft: extra.draft,
          meal: extra.meal,
          photos: extra.photos,
          userText: extra.userText,
        );
      }
      return const _MissingReviewArgsScreen();
    },
  );
}

/// `/meal/:id`: the task-22 per-meal summary for one meal.
GoRoute _mealDetailRoute() {
  return GoRoute(
    path: '/meal/:id',
    builder: (BuildContext context, GoRouterState state) =>
        MealDetailScreen(mealId: state.pathParameters['id']!),
    routes: <RouteBase>[
      // `/meal/:id/edit`: the saved meal opened in the review form (the detail
      // page's 编辑 action). Nested so popping the editor lands on the detail.
      GoRoute(
        path: 'edit',
        builder: (BuildContext context, GoRouterState state) =>
            _MealEditLoader(mealId: state.pathParameters['id']!),
      ),
    ],
  );
}

/// Loads `/meal/:id/edit`'s meal, then renders the review screen in edit mode.
///
/// The route cannot carry the meal in `extra` (a deep link has no sender), so
/// the loader reads the same live [mealDetailProvider] the detail page uses:
/// loading shows a spinner, a missing id the explicit 未找到 empty state, and
/// the loaded meal seeds the review screen with its stored items. The screen
/// then never rebuilds from later stream events — the rows own their edits,
/// which is exactly the review screen's draft semantics.
class _MealEditLoader extends ConsumerWidget {
  const _MealEditLoader({required this.mealId});

  final String mealId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<MealWithItems?> detail = ref.watch(
      mealDetailProvider(mealId),
    );
    return detail.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (Object error, StackTrace stack) =>
          Scaffold(body: Center(child: Text(S.of(context).loadFailed))),
      data: (MealWithItems? group) {
        if (group == null) {
          return Scaffold(
            appBar: AppBar(title: Text(S.of(context).mealDetailTitle)),
            body: Center(
              child: Text(S.of(context).mealNotFound, key: mealEditMissingKey),
            ),
          );
        }
        return MealReviewScreen(
          draft: AiMealDraft(items: group.items),
          meal: group.meal,
          editing: true,
        );
      },
    );
  }
}

/// Shown when `/today/review` is reached without a [ReviewArgs] payload
/// (e.g. a hand-typed deep link); never crashes.
class _MissingReviewArgsScreen extends StatelessWidget {
  const _MissingReviewArgsScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: reviewMissingArgsKey,
      body: Center(child: Text(S.of(context).reviewMissingArgs)),
    );
  }
}
