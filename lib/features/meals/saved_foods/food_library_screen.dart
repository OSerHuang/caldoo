/// The 食物库 (food library) tab: the live catalogue of every saved food.
///
/// The 记录 hub that used to live in this tab is gone. Logging a meal or an
/// exercise now starts from the 概览 dashboard's quick-add actions, so the
/// second tab is free to be the thing a user actually comes back to look at:
/// every food they have captured — official 营养成分表 labels, AI estimates and
/// manual entries — searchable and inspectable.
///
/// Tapping a row opens [SavedFoodDetailScreen] (provenance, supplement, per-100
/// values, and the catalogue's delete action behind a confirm dialog). The
/// 添加食物 action opens a small sheet with the two ways a food enters the
/// catalogue, both reusing the label-capture flow:
/// * 拍照识别营养标签 — the AI reads the printed 营养成分表;
/// * 手动录入 — the same confirm form, typed by hand (works offline).
///
/// New foods are written by `LabelCaptureController.save` through the food
/// repository, and [savedFoodsProvider] streams the catalogue, so the list
/// refreshes by itself when the add screen pops.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:caldoo/core/ui/shell_insets.dart';
import 'package:caldoo/domain/models/models.dart';
import 'package:caldoo/l10n/app_strings.dart';

import 'saved_food_detail_screen.dart';
import 'saved_food_list.dart';

/// Key of the food-library screen scaffold.
const Key foodLibraryScreenKey = Key('food_library_screen');

/// Key of the 添加食物 FAB.
const Key foodLibraryAddButtonKey = Key('food_library_add_button');

/// Key of the same action inside the empty-library state.
const Key foodLibraryEmptyAddButtonKey = Key('food_library_empty_add_button');

/// Key of the add-food bottom sheet.
const Key foodLibraryAddSheetKey = Key('food_library_add_sheet');

/// Key of the sheet's 拍照识别营养标签 option.
const Key foodLibraryAddPhotoKey = Key('food_library_add_photo');

/// Key of the sheet's 手动录入 option.
const Key foodLibraryAddManualKey = Key('food_library_add_manual');

/// The 食物库 tab.
class FoodLibraryScreen extends StatelessWidget {
  /// Creates the food-library screen.
  const FoodLibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // At this branch root, back goes to the Today tab rather than draining
      // another tab's stack (the same tab-root contract as 我的). Deeper routes
      // pushed on this branch (`/foods/add`) pop normally.
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (!didPop) {
          context.go('/today');
        }
      },
      child: Scaffold(
        key: foodLibraryScreenKey,
        appBar: AppBar(title: Text(S.of(context).foodLibraryTitle)),
        body: SavedFoodList(
          onFoodTap: (Food food) => SavedFoodDetailScreen.push(context, food),
          // Clear the extended FAB and the glass nav (extendBody): on a long
          // catalogue the last row would otherwise sit underneath either.
          listBottomInset: 88 + MediaQuery.paddingOf(context).bottom,
          emptyState: _EmptyLibrary(onAdd: () => _openAddSheet(context)),
        ),
        // The shell's glass nav floats over this screen (extendBody), and a
        // FAB is positioned by the Scaffold's own layout, which never reads
        // MediaQuery padding — lift it above the injected bar height by hand.
        floatingActionButton: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.paddingOf(context).bottom,
          ),
          child: FloatingActionButton.extended(
            key: foodLibraryAddButtonKey,
            onPressed: () => _openAddSheet(context),
            icon: const Icon(Icons.add),
            label: Text(S.of(context).foodLibraryAdd),
          ),
        ),
      ),
    );
  }

  /// Opens the two-option add-food sheet.
  void _openAddSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext sheetContext) {
        final ThemeData theme = Theme.of(sheetContext);
        return SafeArea(
          child: Padding(
            key: foodLibraryAddSheetKey,
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text(
                    S.of(sheetContext).foodLibraryAddSheetTitle,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                ListTile(
                  key: foodLibraryAddPhotoKey,
                  leading: CircleAvatar(
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Icon(
                      Icons.photo_camera_outlined,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  title: Text(S.of(sheetContext).foodLibraryAddPhotoTitle),
                  subtitle: Text(
                    S.of(sheetContext).foodLibraryAddPhotoSubtitle,
                  ),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _openAddScreen(context, manual: false);
                  },
                ),
                ListTile(
                  key: foodLibraryAddManualKey,
                  leading: CircleAvatar(
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Icon(
                      Icons.edit_outlined,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  title: Text(S.of(sheetContext).foodLibraryAddManualTitle),
                  subtitle: Text(
                    S.of(sheetContext).foodLibraryAddManualSubtitle,
                  ),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _openAddScreen(context, manual: true);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Pushes the label-capture flow in its photo or manual-entry mode.
  ///
  /// An absolute push on the 食物库 branch: the flow keeps the bottom bar, and
  /// popping it (the saved step's 完成) lands back on the live library.
  void _openAddScreen(BuildContext context, {required bool manual}) {
    GoRouter.of(context).push(manual ? '/foods/add?manual=1' : '/foods/add');
  }
}

/// The empty-library panel: what the tab is for, plus a direct add action.
class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary({required this.onAdd});

  /// Opens the add-food sheet.
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final S strings = S.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: withShellBottom(context, const EdgeInsets.all(24)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.local_offer_outlined,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(strings.savedFoodsEmpty, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              strings.foodLibraryEmptyHint,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              key: foodLibraryEmptyAddButtonKey,
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: Text(strings.foodLibraryAdd),
            ),
          ],
        ),
      ),
    );
  }
}
