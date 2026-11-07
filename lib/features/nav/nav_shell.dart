/// The bottom-navigation shell for the three primary destinations.
///
/// `StatefulShellRoute.indexedStack` (go_router 18) gives each branch its own
/// [Navigator] inside an [IndexedStack], so switching tabs never rebuilds the
/// other branches and every tab keeps its own navigation stack and widget
/// state. This widget only renders the [GlassNavBar]; the branch navigators
/// themselves are owned by go_router.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:caldoo/l10n/app_strings.dart';

import 'glass_nav_bar.dart';

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

/// The glass bottom navigation over the active branch.
class NavShell extends StatelessWidget {
  /// Creates the shell over the go_router [navigationShell].
  const NavShell({required this.navigationShell, super.key});

  /// The branch container go_router injects; its [body] is the active branch.
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      // The glass bar floats over the branch content, so scrolling lists pass
      // beneath the blur. Scrollables inside the shell add the bar's height
      // (MediaQuery bottom padding) to their own insets to stay clear.
      extendBody: true,
      bottomNavigationBar: GlassNavBar(
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
        destinations: <GlassNavDestination>[
          GlassNavDestination(
            key: navTodayKey,
            icon: Icons.dashboard_outlined,
            selectedIcon: Icons.dashboard,
            label: S.of(context).navOverview,
          ),
          GlassNavDestination(
            key: navFoodsKey,
            icon: Icons.local_offer_outlined,
            selectedIcon: Icons.local_offer,
            label: S.of(context).navFoods,
          ),
          GlassNavDestination(
            key: navProfileKey,
            icon: Icons.person_outline,
            selectedIcon: Icons.person,
            label: S.of(context).navProfile,
          ),
        ],
      ),
    );
  }
}
