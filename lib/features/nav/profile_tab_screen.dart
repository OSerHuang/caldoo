/// The "我的" tab: profile, settings, privacy and backup entries.
///
/// A hub rather than the profile form itself so every personal/settings screen
/// lives under one parent route (`/profile/...`) while keeping the tab's own
/// navigation stack. Includes the task-29 "delete all local data" action. The
/// weight feature is NOT a hub entry: its 周/月 dashboard block and the
/// dashboard card are the discovery points.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:caldoo/features/settings/privacy/delete_all_data.dart';
import 'package:caldoo/l10n/app_strings.dart';

/// Key of the Profile tab scaffold.
const Key profileTabScreenKey = Key('profile_tab_screen');

/// Keys of the hub entries.
const Key profileTabDetailsKey = Key('profile_tab_details');
const Key profileTabSettingsKey = Key('profile_tab_settings');
const Key profileTabPrivacyKey = Key('profile_tab_privacy');
const Key profileTabBackupKey = Key('profile_tab_backup');

/// The "我的" hub.
class ProfileTabScreen extends StatelessWidget {
  /// Creates the profile hub.
  const ProfileTabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) {
          context.go('/today');
        }
      },
      child: Scaffold(
        key: profileTabScreenKey,
        appBar: AppBar(title: Text(S.of(context).profileTabTitle)),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: <Widget>[
            Card(
              margin: EdgeInsets.zero,
              child: Column(
                children: <Widget>[
                  _Entry(
                    tileKey: profileTabDetailsKey,
                    icon: Icons.person_outline,
                    title: S.of(context).profileDetailsTitle,
                    subtitle: S.of(context).profileDetailsSubtitle,
                    location: '/profile/details',
                  ),
                  Divider(
                    height: 1,
                    indent: 68,
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  _Entry(
                    tileKey: profileTabSettingsKey,
                    icon: Icons.settings_outlined,
                    title: S.of(context).settingsTitle,
                    subtitle: S.of(context).settingsEntrySubtitle,
                    location: '/profile/settings',
                  ),
                  Divider(
                    height: 1,
                    indent: 68,
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  _Entry(
                    tileKey: profileTabPrivacyKey,
                    icon: Icons.privacy_tip_outlined,
                    title: S.of(context).privacyTitle,
                    subtitle: S.of(context).privacyEntrySubtitle,
                    location: '/profile/privacy',
                  ),
                  Divider(
                    height: 1,
                    indent: 68,
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  _Entry(
                    tileKey: profileTabBackupKey,
                    icon: Icons.backup_outlined,
                    title: S.of(context).backupTitle,
                    subtitle: S.of(context).backupEntrySubtitle,
                    location: '/profile/backup',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: DeleteAllDataButton(),
            ),
          ],
        ),
      ),
    );
  }
}

/// One hub row that pushes its [location] within the current branch.
class _Entry extends StatelessWidget {
  const _Entry({
    required this.tileKey,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.location,
  });

  final Key tileKey;
  final IconData icon;
  final String title;
  final String subtitle;
  final String location;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return ListTile(
      key: tileKey,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: colors.primaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, size: 21, color: colors.primary),
      ),
      title: Text(title, style: Theme.of(context).textTheme.titleMedium),
      subtitle: Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
      trailing: Icon(
        Icons.chevron_right,
        size: 22,
        color: colors.onSurfaceVariant,
      ),
      onTap: () => context.push(location),
    );
  }
}
