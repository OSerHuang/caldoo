/// Detail for one saved food.
///
/// The saved-foods list is a catalogue of what the user has captured before
/// (official 营养成分表 labels, AI estimates and manual entries), so a row must
/// be inspectable without turning it into a meal item: this screen shows the
/// brand, the structured 补充信息 (aliases, servings, per-100 basis, archived
/// state), the free-text remarks, the provenance badge and the per-100 g / ml
/// nutrient values that the label-priority resolver will use.
///
/// Every structure row is rendered only when the food actually carries the
/// value: an empty alias list, an empty serving list or an active food adds no
/// line, while a blank nutrient is displayed as 「未提供」 — the same contract
/// as the rest of the app: a blank label field is never rendered as a
/// fabricated `0`.
///
/// The per-100 readouts are display-only, so they follow the display-unit
/// preference (kcal/kJ, salt/sodium); the stored food values never change.
///
/// Everything except the supplement is read-only **on this page**: the user
/// can open [SavedFoodNotesScreen] to add or update 补充信息 (aliases, package
/// size, per-piece weight, remarks, active/archived, per-100 g / ml), and the
/// label confirm form in edit mode ([LabelCaptureScreen] with [LabelCaptureScreen.editFood])
/// to correct the nutrient values themselves — a label misread by the AI or a
/// typo in a manual entry no longer forces a delete-and-recapture. Edits
/// affect only meals logged afterwards: a logged meal item is a snapshot that
/// survives unchanged (the meal_items contract).
///
/// The app bar also carries the catalogue's delete action: a confirm dialog
/// (the food leaves the 食物库; logged meal items survive by contract) and the
/// repository delete — the library list refreshes itself through
/// [savedFoodsProvider]'s change stream.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:caldoo/core/providers/app_providers.dart'
    show foodRepositoryProvider, mealRepositoryProvider;
import 'package:caldoo/core/theme/app_dimensions.dart';
import 'package:caldoo/core/time/date_windows.dart' show MealWithItems;
import 'package:caldoo/domain/repositories/repositories.dart'
    show MealRepository;
import 'package:caldoo/core/ui/app_card.dart';
import 'package:caldoo/core/ui/shell_insets.dart';
import 'package:caldoo/core/units/display_units.dart';
import 'package:caldoo/domain/models/models.dart';
import 'package:caldoo/domain/services/food_history.dart'
    show recomputeHistoryForFood;
import 'package:caldoo/domain/services/label_priority.dart'
    show foodAliases, foodServings;
import 'package:caldoo/features/meals/label/label_capture_screen.dart';
import 'package:caldoo/l10n/app_format.dart';
import 'package:caldoo/l10n/app_strings.dart';

import 'food_source_badge.dart';
import 'food_supplement_format.dart';
import 'saved_food_notes_screen.dart';

/// Key of the detail screen scaffold.
const Key savedFoodDetailScreenKey = Key('saved_food_detail_screen');

/// Key of the food name heading.
const Key savedFoodDetailNameKey = Key('saved_food_detail_name');

/// Key of the brand line (only rendered when the food has a brand).
const Key savedFoodDetailBrandKey = Key('saved_food_detail_brand');

/// Key of the action that opens the supplement editor.
const Key savedFoodDetailNotesEditKey = Key('saved_food_detail_notes_edit');

/// Key of the action that opens the nutrient-value editor.
const Key savedFoodDetailNutrientsEditKey = Key(
  'saved_food_detail_nutrients_edit',
);

/// Key of the recompute-history confirmation dialog.
const Key savedFoodRecomputeDialogKey = Key('saved_food_recompute_dialog');

/// Key of the recompute dialog's cancel button.
const Key savedFoodRecomputeCancelKey = Key('saved_food_recompute_cancel');

/// Key of the recompute dialog's confirm button.
const Key savedFoodRecomputeConfirmKey = Key('saved_food_recompute_confirm');

/// Key of the app-bar delete action.
const Key savedFoodDetailDeleteKey = Key('saved_food_detail_delete');

/// Key of the delete confirmation dialog.
const Key savedFoodDetailDeleteDialogKey = Key('saved_food_delete_dialog');

/// Key of the delete dialog's cancel button.
const Key savedFoodDetailDeleteCancelKey = Key('saved_food_delete_cancel');

/// Key of the delete dialog's confirm button.
const Key savedFoodDetailDeleteConfirmKey = Key('saved_food_delete_confirm');

/// Key of the alias row (only rendered when the food has aliases).
const Key savedFoodDetailAliasesKey = Key('saved_food_detail_aliases');

/// Key of the serving row (only rendered when the food has servings).
const Key savedFoodDetailServingsKey = Key('saved_food_detail_servings');

/// Key of the per-100 basis row.
const Key savedFoodDetailBasisKey = Key('saved_food_detail_basis');

/// Key of the archived status row (only rendered for an archived food).
const Key savedFoodDetailStatusKey = Key('saved_food_detail_status');

/// Key of the numeric readout (or the 未提供 text) for [field].
///
/// [field] is one of `kcal`, `carb`, `protein`, `fat`, `saturatedFat`,
/// `sugar`, `salt`.
Key savedFoodDetailValueKey(String field) => Key('saved_food_detail_$field');

/// The saved-food detail page.
class SavedFoodDetailScreen extends ConsumerStatefulWidget {
  /// Creates the detail page for [food].
  const SavedFoodDetailScreen({required this.food, super.key});

  /// The saved food to describe.
  final Food food;

  /// Pushes the detail page for [food].
  static Future<void> push(BuildContext context, Food food) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => SavedFoodDetailScreen(food: food),
      ),
    );
  }

  @override
  ConsumerState<SavedFoodDetailScreen> createState() =>
      _SavedFoodDetailScreenState();
}

class _SavedFoodDetailScreenState extends ConsumerState<SavedFoodDetailScreen> {
  /// The current (possibly updated) food; the supplement editor returns it.
  late Food _food = widget.food;

  /// Opens the supplement editor and adopts the saved result.
  Future<void> _editNotes() async {
    final Food? updated = await SavedFoodNotesScreen.push(context, _food);
    if (updated == null || !mounted) {
      return;
    }
    setState(() => _food = updated);
  }

  /// Opens the nutrient-value editor (the label confirm form in edit mode) and
  /// adopts the saved result.
  ///
  /// Same root [Navigator] as [SavedFoodNotesScreen.push]: the detail page
  /// itself lives on the root navigator, so the editor must stack on top of it
  /// (a go_router push would land on the shell branch beneath this page).
  /// After adopting, offers to recompute the logged records linked to the
  /// food — a logged item is a snapshot, so rewriting history is always an
  /// explicit, user-confirmed step.
  Future<void> _editNutrients() async {
    final Food? updated = await Navigator.of(context).push<Food>(
      MaterialPageRoute<Food>(
        builder: (BuildContext context) => LabelCaptureScreen(editFood: _food),
      ),
    );
    if (updated == null || !mounted) {
      return;
    }
    setState(() => _food = updated);
    await _offerHistoryRecompute(updated);
  }

  /// Offers to recompute every logged item linked to [food] from the food's
  /// freshly saved values; a no-op when nothing links to it or the read
  /// fails (the offer is best effort, never a blocker).
  Future<void> _offerHistoryRecompute(Food food) async {
    final List<MealWithItems> affected;
    try {
      affected = await ref
          .read(mealRepositoryProvider)
          .getMealsWithItemsForFood(food.id);
    } on Object {
      return;
    }
    if (!mounted || affected.isEmpty) {
      return;
    }
    final int itemCount = affected.fold<int>(
      0,
      (int n, MealWithItems entry) =>
          n + entry.items.where((MealItem it) => it.foodId == food.id).length,
    );
    if (!mounted) {
      return;
    }
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        key: savedFoodRecomputeDialogKey,
        title: Text(S.of(dialogContext).foodRecomputeTitle),
        content: Text(
          S.of(dialogContext).foodRecomputeBody(itemCount, affected.length),
        ),
        actions: <Widget>[
          TextButton(
            key: savedFoodRecomputeCancelKey,
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(S.of(dialogContext).cancel),
          ),
          FilledButton(
            key: savedFoodRecomputeConfirmKey,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(S.of(dialogContext).foodRecomputeConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    final List<MealWithItems> recomputed = recomputeHistoryForFood(
      food,
      affected,
    );
    // Hoisted out of the loop: `ref.read` throws once the widget is unmounted,
    // so a user tapping back mid-loop would abort the remaining writes and
    // leave the history half-rewritten with no report. A repository port is
    // state-safe to hold across awaits.
    final MealRepository mealRepository = ref.read(mealRepositoryProvider);
    var recomputedCount = 0;
    for (var i = 0; i < recomputed.length; i++) {
      // Unchanged meals come back as the same instance — skip the rewrite.
      if (identical(recomputed[i], affected[i])) {
        continue;
      }
      await mealRepository.updateMealWithItems(
        recomputed[i].meal,
        recomputed[i].items,
      );
      recomputedCount += recomputed[i].items
          .where((MealItem it) => it.foodId == food.id)
          .length;
    }
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(S.of(context).foodRecomputeSnack(recomputedCount)),
      ),
    );
  }

  /// Confirms and performs the delete, then pops back to the catalogue.
  ///
  /// Cancelling the dialog (or dismissing it) is a strict no-op; the snackbars
  /// need the screen's [S] strings, so they use the outer context only after a
  /// `mounted` check.
  Future<void> _confirmDelete() async {
    final Food food = _food;
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        key: savedFoodDetailDeleteDialogKey,
        title: Text(S.of(dialogContext).foodDeleteConfirmTitle),
        content: Text(S.of(dialogContext).foodDeleteConfirmBody(food.name)),
        actions: <Widget>[
          TextButton(
            key: savedFoodDetailDeleteCancelKey,
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(S.of(dialogContext).cancel),
          ),
          FilledButton(
            key: savedFoodDetailDeleteConfirmKey,
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
              foregroundColor: Theme.of(dialogContext).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(S.of(dialogContext).foodDeleteAction),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    try {
      await ref.read(foodRepositoryProvider).deleteFood(food.id);
    } on Object {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(S.of(context).errorSaveFailed)));
      return;
    }
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(S.of(context).foodDeletedSnack)));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Food food = _food;
    final S strings = S.of(context);
    // Read-only per-100 readouts follow the display preference: kcal or kJ,
    // salt g or sodium mg. A blank nutrient stays 未提供 in either mode.
    final DisplayUnits units = DisplayUnits.of(context);
    // Display the *effective* values: structured fields win, and a legacy
    // food's prose is parsed as the fallback so an old alias/serving is not
    // silently invisible here.
    final List<String> aliases = foodAliases(food);
    final List<FoodServing> servings = foodServings(food);
    final String notFilled = strings.foodDetailNotFilled;
    final bool archived = food.status == FoodStatus.archived;
    return Scaffold(
      key: savedFoodDetailScreenKey,
      appBar: AppBar(
        title: Text(strings.savedFoodDetailTitle),
        actions: <Widget>[
          IconButton(
            key: savedFoodDetailDeleteKey,
            tooltip: strings.foodDeleteAction,
            onPressed: _confirmDelete,
            color: theme.colorScheme.error,
            icon: const Icon(Icons.delete_outline),
          ),
          TextButton.icon(
            key: savedFoodDetailNutrientsEditKey,
            onPressed: _editNutrients,
            icon: const Icon(Icons.edit_note_outlined),
            label: Text(strings.foodNutrientsEditAction),
          ),
          TextButton.icon(
            key: savedFoodDetailNotesEditKey,
            onPressed: _editNotes,
            icon: const Icon(Icons.edit_outlined),
            label: Text(strings.foodEditAction),
          ),
        ],
      ),
      body: ListView(
        padding: withShellBottom(
          context,
          const EdgeInsets.all(AppDim.pagePadding),
        ),
        children: <Widget>[
          AppCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Text(
                    food.name,
                    key: savedFoodDetailNameKey,
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                // The official-label pill is noise for a label catalogue; the
                // non-authoritative sources keep a badge worth noticing.
                if (food.source != FoodSource.label) ...<Widget>[
                  const SizedBox(width: AppDim.gapTight),
                  FoodSourceBadge(source: food.source),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppDim.gap),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(strings.foodInfoTitle, style: theme.textTheme.titleMedium),
                const SizedBox(height: AppDim.gapTight),
                _InfoRow(
                  label: strings.foodBrandFieldLabel,
                  value: food.brand ?? notFilled,
                  valueKey: savedFoodDetailBrandKey,
                  dim: food.brand == null,
                ),
                _InfoRow(
                  label: strings.foodAliasesLabel,
                  value: aliases.isEmpty ? notFilled : aliases.join('、'),
                  valueKey: savedFoodDetailAliasesKey,
                  dim: aliases.isEmpty,
                ),
                _InfoRow(
                  label: strings.foodServingsLabel,
                  value: servings.isEmpty
                      ? notFilled
                      : formatFoodServings(servings),
                  valueKey: savedFoodDetailServingsKey,
                  dim: servings.isEmpty,
                ),
                _InfoRow(
                  label: strings.foodStatusLabel,
                  value: archived
                      ? strings.foodStatusArchived
                      : strings.foodStatusActive,
                  valueKey: savedFoodDetailStatusKey,
                  color: archived ? theme.colorScheme.error : null,
                ),
                _InfoRow(
                  label: strings.foodBasisLabel,
                  value: _basisLabel(context, food.basis),
                  valueKey: savedFoodDetailBasisKey,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDim.gap),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  food.basis == MeasureBasis.per100ml
                      ? strings.foodDetailPer100ml
                      : strings.foodDetailPer100g,
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: AppDim.gapTight),
                _NutrientRow(
                  field: 'kcal',
                  label: strings.labelEnergy,
                  unit: units.energyUnit,
                  value: food.kcal == null
                      ? null
                      : units.energyValue(food.kcal!),
                ),
                _NutrientRow(
                  field: 'carb',
                  label: strings.labelCarb,
                  unit: strings.unitG,
                  value: food.carbG,
                ),
                _NutrientRow(
                  field: 'protein',
                  label: strings.labelProtein,
                  unit: strings.unitG,
                  value: food.proteinG,
                ),
                _NutrientRow(
                  field: 'fat',
                  label: strings.labelFat,
                  unit: strings.unitG,
                  value: food.fatG,
                ),
                // The two optional GB 28050 declarations are shown only when
                // the label actually declared them: hiding a blank one is the
                // honest rendering (a missing sugar row is not "0 g sugar").
                if (food.saturatedFatG != null)
                  _NutrientRow(
                    field: 'saturatedFat',
                    label: strings.labelFieldSaturatedFat,
                    unit: strings.unitG,
                    value: food.saturatedFatG,
                  ),
                if (food.sugarG != null)
                  _NutrientRow(
                    field: 'sugar',
                    label: strings.labelFieldSugar,
                    unit: strings.unitG,
                    value: food.sugarG,
                  ),
                // Food stores sodium in mg; the salt/sodium row is display-only.
                _NutrientRow(
                  field: 'salt',
                  label: units.saltLabel,
                  unit: units.saltUnit,
                  value: units.showsSodium ? food.sodiumMg : food.saltG,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// The display label of [basis] (`每 100 g` / `每 100 ml`).
  String _basisLabel(BuildContext context, MeasureBasis basis) {
    return switch (basis) {
      MeasureBasis.per100g => S.of(context).foodBasisPer100g,
      MeasureBasis.per100ml => S.of(context).foodBasisPer100ml,
    };
  }
}

/// One `label  value` line of the identity card.
class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    required this.valueKey,
    this.dim = false,
    this.color,
  });

  final String label;
  final String value;
  final Key valueKey;

  /// `true` when the value is the 未填写 placeholder.
  final bool dim;

  /// Optional value colour (used for an archived status).
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 88,
            child: Text(label, style: theme.textTheme.labelMedium),
          ),
          Expanded(
            child: Text(
              value,
              key: valueKey,
              style: theme.textTheme.bodyMedium?.copyWith(
                color:
                    color ?? (dim ? theme.colorScheme.onSurfaceVariant : null),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One `label  value unit` line of the per-100 g table.
class _NutrientRow extends StatelessWidget {
  const _NutrientRow({
    required this.field,
    required this.label,
    required this.unit,
    required this.value,
  });

  /// Test-key discriminator, see [savedFoodDetailValueKey].
  final String field;

  final String label;

  final String unit;

  /// The per-100 g value (energy is an `int` kcal, macros are doubles);
  /// `null` renders 未提供.
  final num? value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Key valueKey = savedFoodDetailValueKey(field);
    final num? current = value;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 64,
            child: Text(label, style: theme.textTheme.labelMedium),
          ),
          if (current == null)
            Text(
              S.of(context).foodDetailNotProvided,
              key: valueKey,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          else ...<Widget>[
            Text(
              AppFormat.number(current),
              key: valueKey,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(width: 4),
            Text(unit, style: theme.textTheme.labelSmall),
          ],
        ],
      ),
    );
  }
}
