/// The `/meal/:id` meal-detail route (task 27).
///
/// Renders the task-22 per-meal summary card (本餐合计 + live 今日累计) for the
/// meal named by the route parameter, live over
/// [MealRepository.watchMealWithItems]. A missing id renders an explicit empty
/// state instead of a blank screen, and additions/edits to the meal re-emit
/// through the watch stream.
///
/// The app bar carries the catalogue-style maintenance actions: 编辑 pushes
/// `/meal/:id/edit` (the saved meal reopened in the review form) and 删除
/// removes the whole meal behind a confirm dialog. The summary streams are all
/// watch-based, so both actions update every total by themselves.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:caldoo/core/providers/app_providers.dart';
import 'package:caldoo/core/time/date_windows.dart';
import 'package:caldoo/core/ui/shell_insets.dart';
import 'package:caldoo/core/units/display_units.dart';
import 'package:caldoo/domain/models/models.dart';
import 'package:caldoo/features/meals/summary/meal_summary_card.dart';
import 'package:caldoo/l10n/app_format.dart';
import 'package:caldoo/l10n/app_strings.dart';

/// Key of the meal-detail scaffold.
const Key mealDetailScreenKey = Key('meal_detail_screen');

/// Key of the "meal not found" empty state.
const Key mealDetailMissingKey = Key('meal_detail_missing');

/// Key of the app-bar edit action (opens the meal editor).
const Key mealDetailEditKey = Key('meal_detail_edit');

/// Key of the app-bar delete action.
const Key mealDetailDeleteKey = Key('meal_detail_delete');

/// Key of the delete confirmation dialog.
const Key mealDetailDeleteDialogKey = Key('meal_delete_dialog');

/// Key of the delete dialog's cancel button.
const Key mealDetailDeleteCancelKey = Key('meal_delete_cancel');

/// Key of the delete dialog's confirm button.
const Key mealDetailDeleteConfirmKey = Key('meal_delete_confirm');

/// The live meal-with-items for one id (null while absent).
final mealDetailProvider = StreamProvider.family<MealWithItems?, String>((
  Ref ref,
  String id,
) {
  return ref.watch(mealRepositoryProvider).watchMealWithItems(id);
});

/// Per-meal detail screen; [mealId] comes from the `/meal/:id` path.
class MealDetailScreen extends ConsumerWidget {
  /// Creates the detail screen for [mealId].
  const MealDetailScreen({required this.mealId, super.key});

  /// The id of the meal to render.
  final String mealId;

  /// Confirms and performs the whole-meal delete, then returns to 概览.
  ///
  /// Cancelling (or dismissing) the dialog is a strict no-op. The navigation
  /// is `go('/today')` rather than a pop because the detail route is also a
  /// deep link: a deep-linked detail has nothing to pop back to. The snackbars
  /// use the outer context only after a `context.mounted` check.
  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        key: mealDetailDeleteDialogKey,
        title: Text(S.of(dialogContext).mealDeleteConfirmTitle),
        content: Text(S.of(dialogContext).mealDeleteConfirmBody),
        actions: <Widget>[
          TextButton(
            key: mealDetailDeleteCancelKey,
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(S.of(dialogContext).cancel),
          ),
          FilledButton(
            key: mealDetailDeleteConfirmKey,
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
              foregroundColor: Theme.of(dialogContext).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(S.of(dialogContext).mealDeleteAction),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) {
      return;
    }
    try {
      await ref.read(mealRepositoryProvider).deleteMeal(mealId);
    } on Object {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(S.of(context).errorSaveFailed)));
      return;
    }
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(S.of(context).mealDeletedSnack)));
    // The day/week summaries are watch streams: removing the meal updates
    // every total by itself, no manual refresh needed.
    context.go('/today');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<MealWithItems?> detail = ref.watch(
      mealDetailProvider(mealId),
    );
    // The maintenance actions exist only for a meal that actually loaded; a
    // missing meal has nothing to edit or delete.
    final bool loaded = detail.value != null;
    return Scaffold(
      key: mealDetailScreenKey,
      appBar: AppBar(
        title: Text(S.of(context).mealDetailTitle),
        actions: <Widget>[
          if (loaded) ...<Widget>[
            IconButton(
              key: mealDetailEditKey,
              tooltip: S.of(context).mealEditAction,
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => context.push('/meal/$mealId/edit'),
            ),
            IconButton(
              key: mealDetailDeleteKey,
              tooltip: S.of(context).mealDeleteAction,
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _confirmDelete(context, ref),
            ),
          ],
        ],
      ),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace stack) =>
            Center(child: Text(S.of(context).loadFailed)),
        data: (MealWithItems? group) {
          if (group == null) {
            return Center(
              child: Text(
                S.of(context).mealNotFound,
                key: mealDetailMissingKey,
              ),
            );
          }
          return SingleChildScrollView(
            padding: withShellBottom(context, const EdgeInsets.all(16)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                MealSummaryCard(meal: group.meal, items: group.items),
                const SizedBox(height: 16),
                Text(
                  S.of(context).mealItemsHeading,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Card(
                  margin: EdgeInsets.zero,
                  child: Column(
                    children: <Widget>[
                      for (final MealItem item in group.items)
                        ListTile(
                          key: Key('meal_detail_item_${item.id}'),
                          title: Text(item.name),
                          subtitle: Text(
                            S
                                .of(context)
                                .mealDetailItemLineWith(
                                  // The shared number format, like the review
                                  // card and the today screen: 74.5 stays
                                  // 74.5 instead of rounding up to 75.
                                  AppFormat.number(item.grams),
                                  DisplayUnits.of(context)
                                      .energyText(item.kcal),
                                ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
