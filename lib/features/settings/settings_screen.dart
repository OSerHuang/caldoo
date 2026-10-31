/// The 设置 hub: one menu above the two settings pages.
///
/// **模型设置** (the BYOK form with its explicit 保存 / 测试连接 actions) and
/// **数据显示** (the display-only unit preferences that apply immediately) each
/// live on their own page — `/profile/settings/ai` and
/// `/profile/settings/display` — so the hub itself stays a plain two-row menu
/// in the same tile style as the 我的 hub.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:caldoo/l10n/app_strings.dart';

/// Key of the 设置 hub scaffold.
const Key settingsHubScreenKey = Key('settings_hub_screen');

/// Key of the 模型设置 hub entry.
const Key settingsHubModelKey = Key('settings_hub_model');

/// Key of the 数据显示 hub entry.
const Key settingsHubDisplayKey = Key('settings_hub_display');

/// The 设置 hub.
class SettingsScreen extends StatelessWidget {
  /// Creates the settings hub.
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: settingsHubScreenKey,
      appBar: AppBar(title: Text(S.of(context).settingsTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: <Widget>[
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: <Widget>[
                _Entry(
                  tileKey: settingsHubModelKey,
                  icon: Icons.memory_outlined,
                  title: S.of(context).settingsSectionModel,
                  subtitle: S.of(context).settingsModelEntrySubtitle,
                  location: '/profile/settings/ai',
                ),
                Divider(
                  height: 1,
                  indent: 68,
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
                _Entry(
                  tileKey: settingsHubDisplayKey,
                  icon: Icons.visibility_outlined,
                  title: S.of(context).settingsSectionDisplay,
                  subtitle: S.of(context).settingsDisplayEntrySubtitle,
                  location: '/profile/settings/display',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One hub row that pushes its [location] within the current branch — the
/// same tile style as the 我的 hub's rows.
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
