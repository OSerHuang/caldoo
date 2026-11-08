/// The 餐食模版 library (the 我的 tab's template entry, `/profile/templates`).
///
/// The management surface the picker deliberately is not: every row carries a
/// 重命名 action (the shared naming sheet, pre-filled) and a 删除 action
/// (behind a confirm dialog, like the meal-detail delete). The list is live
/// via `mealTemplatesProvider`, so a delete or rename updates in place and the
/// capture picker reflects it on its next open.
///
/// Templates are CREATED only from a logged meal's detail page (存为模版) —
/// there is no blank-new affordance here, on purpose: a template is a snapshot
/// of a meal that was actually eaten.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:caldoo/core/providers/app_providers.dart';
import 'package:caldoo/core/units/display_units.dart';
import 'package:caldoo/domain/models/models.dart';
import 'package:caldoo/l10n/app_strings.dart';

import 'meal_templates_providers.dart';
import 'save_template_sheet.dart';

/// Key of the template-library scaffold.
const Key templateLibraryScreenKey = Key('template_library_screen');

/// Key of the library's empty state.
const Key templateLibraryEmptyKey = Key('template_library_empty');

/// The template library screen.
class TemplateLibraryScreen extends ConsumerWidget {
  /// Creates the library screen.
  const TemplateLibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<MealTemplate>> templates = ref.watch(
      mealTemplatesProvider,
    );
    return Scaffold(
      key: templateLibraryScreenKey,
      appBar: AppBar(title: Text(S.of(context).templateLibraryTitle)),
      body: templates.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace stack) =>
            Center(child: Text(S.of(context).loadFailed)),
        data: (List<MealTemplate> list) {
          if (list.isEmpty) {
            return Center(
              child: Text(
                S.of(context).templateLibraryEmpty,
                key: templateLibraryEmptyKey,
                textAlign: TextAlign.center,
              ),
            );
          }
          return ListView.builder(
            itemCount: list.length,
            itemBuilder: (BuildContext context, int index) =>
                _TemplateRow(template: list[index]),
          );
        },
      ),
    );
  }
}

/// One library row: name, item preview + total energy, and the two actions.
class _TemplateRow extends ConsumerWidget {
  const _TemplateRow({required this.template});

  final MealTemplate template;

  Future<void> _rename(BuildContext context, WidgetRef ref) async {
    final String? name = await showTemplateNameSheet(
      context,
      title: S.of(context).templateRenameTitle,
      initialName: template.name,
    );
    if (name == null || !context.mounted) {
      return;
    }
    try {
      await ref
          .read(mealTemplateRepositoryProvider)
          .updateTemplate(template.copyWith(name: name));
    } on Object {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(S.of(context).errorSaveFailed)));
      return;
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(S.of(dialogContext).templateDeleteConfirmTitle),
        content: Text(S.of(dialogContext).templateDeleteConfirmBody),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(S.of(dialogContext).cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
              foregroundColor: Theme.of(dialogContext).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(S.of(dialogContext).delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) {
      return;
    }
    try {
      await ref
          .read(mealTemplateRepositoryProvider)
          .deleteTemplate(template.id);
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(S.of(context).templateDeletedSnack)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String names = template.items
        .map((MealItem item) => item.name)
        .join('、');
    return ListTile(
      key: Key('template_row_${template.id}'),
      title: Text(template.name),
      subtitle: Text(
        S
            .of(context)
            .templateRowLineWith(
              names,
              DisplayUnits.of(context).energyText(template.totalKcal),
            ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          IconButton(
            key: Key('template_rename_${template.id}'),
            tooltip: S.of(context).templateRenameAction,
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => _rename(context, ref),
          ),
          IconButton(
            key: Key('template_delete_${template.id}'),
            tooltip: S.of(context).delete,
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _delete(context, ref),
          ),
        ],
      ),
    );
  }
}
