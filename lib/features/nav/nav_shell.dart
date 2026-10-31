/// The bottom-navigation shell for the three primary destinations.
///
/// `StatefulShellRoute.indexedStack` (go_router 18) gives each branch its own
/// [Navigator] inside an [IndexedStack], so switching tabs never rebuilds the
/// other branches and every tab keeps its own navigation stack and widget
/// state. This widget only renders the [NavigationBar]; the branch navigators
/// themselves are owned by go_router.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:caldoo/l10n/app_strings.dart';

/// Keys for the three bottom-nav destinations (stable widget-test hooks).
///
/// The former 记录 hub is gone: logging a meal / exercise now starts from the
/// 概览 dashboard's own quick-add actions (and runs inside the 概览 branch),
/// while the nutrition-label capture — which creates saved foods rather than a
/// meal — is the 食物库 tab's 添加食物 flow. The remaining destinations are
/// therefore 概览 / 食物库 / 我的.
const Key navTodayKey = Key('nav_today');
const Key navFoodsKey = Key('nav_foods');
const Key navProfileKey = Key('nav_profile');

/// The Material 3 bottom navigation bar over the active branch.
class NavShell extends StatelessWidget {
  /// Creates the shell over the go_router [navigationShell].
  const NavShell({required this.navigationShell, super.key});

  /// The branch container go_router injects; its [body] is the active branch.
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (int index) {
          // `initialLocation` only when re-tapping the active tab, so a normal
          // switch preserves the target branch's existing stack (task 27's
          // per-tab state requirement).
          navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          );
        },
        destinations: <NavigationDestination>[
          NavigationDestination(
            key: navTodayKey,
            icon: const Icon(Icons.dashboard_outlined),
            selectedIcon: const Icon(Icons.dashboard),
            label: S.of(context).navOverview,
          ),
          NavigationDestination(
            key: navFoodsKey,
            icon: const Icon(Icons.local_offer_outlined),
            selectedIcon: const Icon(Icons.local_offer),
            label: S.of(context).navFoods,
          ),
          NavigationDestination(
            key: navProfileKey,
            icon: const Icon(Icons.person_outline),
            selectedIcon: const Icon(Icons.person),
            label: S.of(context).navProfile,
          ),
        ],
      ),
    );
  }
}
