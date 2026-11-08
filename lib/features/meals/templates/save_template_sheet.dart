/// The 模版名称 bottom sheet, shared by 存为模版 (meal detail) and 重命名
/// (template library).
///
/// A pure name collector: it opens pre-filled, validates non-blank locally and
/// pops with the trimmed name — the CALLER owns the repository write (and its
/// error handling), exactly like `SavedFoodPicker.push` hands back the chosen
/// food instead of applying it. Cancelling (or dismissing) pops `null`.
library;

import 'package:flutter/material.dart';

import 'package:caldoo/core/theme/app_dimensions.dart';
import 'package:caldoo/l10n/app_strings.dart';

/// Key of the template-name text field.
const Key templateNameFieldKey = Key('template_name_field');

/// Key of the sheet's 保存 action.
const Key templateSaveConfirmKey = Key('template_save_confirm');

/// Opens the naming sheet pre-filled with [initialName].
///
/// Completes with the trimmed, non-blank name on 保存, or `null` when the user
/// backed out. The blank name simply disables 保存 — no error copy needed for
/// a field the user is about to type into.
Future<String?> showTemplateNameSheet(
  BuildContext context, {
  required String title,
  required String initialName,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (BuildContext sheetContext) =>
        _TemplateNameSheet(title: title, initialName: initialName),
  );
}

class _TemplateNameSheet extends StatefulWidget {
  const _TemplateNameSheet({required this.title, required this.initialName});

  final String title;
  final String initialName;

  @override
  State<_TemplateNameSheet> createState() => _TemplateNameSheetState();
}

class _TemplateNameSheetState extends State<_TemplateNameSheet> {
  late final TextEditingController _name = TextEditingController(
    text: widget.initialName,
  );

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() {
    final String name = _name.text.trim();
    if (name.isEmpty) {
      return;
    }
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _name,
      builder: (BuildContext context, TextEditingValue value, _) {
        final bool canSave = value.text.trim().isNotEmpty;
        return SingleChildScrollView(
          padding: EdgeInsets.only(
            left: AppDim.pagePadding,
            right: AppDim.pagePadding,
            // Keep the actions above the keyboard AND above the floating glass
            // navigation bar: the shell's `extendBody` injects the bar height
            // as the branch's bottom MediaQuery padding, and a sheet pushed on
            // the branch slides under the bar — without the extra inset the
            // 保存 button is covered and untappable.
            bottom:
                MediaQuery.of(context).viewInsets.bottom +
                MediaQuery.paddingOf(context).bottom +
                AppDim.pagePadding,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      widget.title,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                key: templateNameFieldKey,
                controller: _name,
                maxLength: 30,
                decoration: InputDecoration(
                  labelText: S.of(context).templateNameLabel,
                  hintText: S.of(context).templateNameHint,
                ),
                onSubmitted: (_) => _save(),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: templateSaveConfirmKey,
                  onPressed: canSave ? _save : null,
                  child: Text(S.of(context).save),
                ),
              ),
              const SizedBox(height: 4),
            ],
          ),
        );
      },
    );
  }
}
