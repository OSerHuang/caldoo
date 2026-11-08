/// The 从模版记录 template picker.
///
/// A full-screen selection list of every saved meal template (modeled on the
/// saved-food picker): each row names the template, previews its item lines
/// and shows the pre-formatted total energy. Tapping a row pops the picker
/// with the chosen [MealTemplate]; the CALLER decides how to apply it (the
/// capture screen routes into the review form via
/// `templateReviewRouterProvider`).
///
/// The list is live via `mealTemplatesProvider` and ordered newest-first by
/// the repository contract. An empty catalogue shows a pointing empty state
/// instead of an error — the first template can only come from a logged meal's
/// detail page (存为模版).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:caldoo/core/units/display_units.dart';
import 'package:caldoo/domain/models/models.dart';
import 'package:caldoo/l10n/app_strings.dart';

import 'meal_templates_providers.dart';

/// Key of the picker's empty state.
const Key templatePickerEmptyKey = Key('template_picker_empty');

/// The picker screen.
class MealTemplatePicker extends ConsumerWidget {
  /// Creates the picker.
  const MealTemplatePicker({super.key});

  /// Pushes the picker and completes with the chosen template, or `null` when
  /// the user backed out without choosing.
  static Future<MealTemplate?> push(BuildContext context) {
    return Navigator.of(context).push<MealTemplate>(
      MaterialPageRoute<MealTemplate>(
        builder: (_) => const MealTemplatePicker(),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<MealTemplate>> templates = ref.watch(
      mealTemplatesProvider,
    );
    return Scaffold(
      appBar: AppBar(title: Text(S.of(context).templatePickerTitle)),
      body: templates.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, StackTrace stack) =>
            Center(child: Text(S.of(context).loadFailed)),
        data: (List<MealTemplate> list) {
          if (list.isEmpty) {
            return Center(
              child: Text(
                S.of(context).templatePickerEmpty,
                key: templatePickerEmptyKey,
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

class _TemplateRow extends StatelessWidget {
  const _TemplateRow({required this.template});

  final MealTemplate template;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String names = template.items
        .map((MealItem item) => item.name)
        .join('、');
    return ListTile(
      key: Key('template_pick_${template.id}'),
      title: Text(template.name),
      subtitle: Text(
        S
            .of(context)
            .templateRowLineWith(
              names,
              DisplayUnits.of(context).energyText(template.totalKcal),
            ),
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.of(context).pop(template),
    );
  }
}
