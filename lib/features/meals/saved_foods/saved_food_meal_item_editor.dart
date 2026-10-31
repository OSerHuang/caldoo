/// Review-context integration: one AI meal item + optional saved-food label.
///
/// This is the surface task 19's review screen embeds per item. It composes:
/// * a **non-blocking** [FoodSuggestionList] from `suggestSavedFood` — the best
///   candidate as a banner plus the runner-ups as chips. Nothing changes until
///   the user taps 采用;
/// * a button that opens [SavedFoodPicker];
/// * a grams field and the resulting nutrient readouts, recomputed from the
///   chosen food's per-100 g values on every change (via [MealItemEditor]);
/// * an [onChanged] callback so the owning screen can keep its draft in sync.
///
/// Before any tap / pick the readouts are exactly the AI item's values.
///
/// The readouts are display-only and follow the display-unit preference
/// (kcal/kJ, salt/sodium); the grams input and the stored item stay canonical,
/// because manual recording is deliberately unaffected by the preference.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:caldoo/core/units/display_units.dart';
import 'package:caldoo/domain/models/models.dart';
import 'package:caldoo/domain/services/label_priority.dart';
import 'package:caldoo/l10n/app_format.dart';
import 'package:caldoo/l10n/app_strings.dart';

import 'food_source_badge.dart';
import 'food_suggestion_list.dart';
import 'meal_item_editor.dart';
import 'saved_food_detail_screen.dart';
import 'saved_food_picker.dart';
import 'saved_foods_providers.dart';

/// Keys for the widget tests (and for task 19 to target).
const Key savedFoodGramsFieldKey = Key('saved_food_grams_field');
const Key savedFoodPickButtonKey = Key('saved_food_pick_button');
const Key savedFoodItemNameKey = Key('saved_food_item_name');
const Key savedFoodChosenFoodKey = Key('saved_food_chosen_food');
const Key savedFoodKcalValueKey = Key('saved_food_kcal_value');
const Key savedFoodCarbValueKey = Key('saved_food_carb_value');
const Key savedFoodProteinValueKey = Key('saved_food_protein_value');
const Key savedFoodFatValueKey = Key('saved_food_fat_value');
const Key savedFoodSaltValueKey = Key('saved_food_salt_value');

/// An editable review row for [aiItem] with the saved-food label integration.
class SavedFoodMealItemEditor extends ConsumerStatefulWidget {
  const SavedFoodMealItemEditor({
    super.key,
    required this.aiItem,
    this.onChanged,
  });

  /// The AI estimate being reviewed; its name drives suggestion matching.
  final MealItem aiItem;

  /// Called with the effective item whenever the user picks a food or edits
  /// grams, so the parent can persist the resolved values.
  final ValueChanged<MealItem>? onChanged;

  @override
  ConsumerState<SavedFoodMealItemEditor> createState() =>
      _SavedFoodMealItemEditorState();
}

class _SavedFoodMealItemEditorState
    extends ConsumerState<SavedFoodMealItemEditor> {
  late final MealItemEditor _editor = MealItemEditor(widget.aiItem);
  late final TextEditingController _grams = TextEditingController(
    text: _formatGrams(widget.aiItem.grams),
  );

  @override
  void dispose() {
    _grams.dispose();
    super.dispose();
  }

  void _commit() => widget.onChanged?.call(_editor.item);

  void _onGramsChanged(String raw) {
    final double? parsed = double.tryParse(raw.trim());
    if (parsed == null || !parsed.isFinite || parsed < 0) {
      // Malformed input (empty / letters / negative) is ignored: the last
      // valid grams stays in effect and no exception reaches the UI.
      return;
    }
    setState(() => _editor.editGrams(parsed));
    _commit();
  }

  Future<void> _pickFood() async {
    final Food? food = await SavedFoodPicker.push(context);
    if (food == null || !mounted) {
      return;
    }
    setState(() => _editor.chooseFood(food));
    _commit();
  }

  void _applySuggestion(Food suggestion) {
    setState(() => _editor.chooseFood(suggestion));
    _commit();
  }

  @override
  Widget build(BuildContext context) {
    final List<Food> foods =
        ref.watch(savedFoodsProvider).value ?? const <Food>[];
    // Suggestions are only offered before a choice is made, and are never
    // applied automatically.
    final List<FoodSuggestion> suggestions = _editor.hasChosenFood
        ? const <FoodSuggestion>[]
        : suggestSavedFood(_editor.item, foods);
    final MealItem current = _editor.item;
    // Read-only value rows follow the display preference; the grams field above
    // stays canonical so manual recording is unaffected.
    final DisplayUnits units = DisplayUnits.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              widget.aiItem.name,
              key: savedFoodItemNameKey,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (suggestions.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              FoodSuggestionList(
                suggestions: suggestions,
                onApply: _applySuggestion,
              ),
            ],
            if (_editor.hasChosenFood) ...<Widget>[
              const SizedBox(height: 8),
              // The adopted food's per-100 g values back the readouts below;
              // tapping the row opens them for inspection.
              InkWell(
                key: savedFoodChosenFoodKey,
                borderRadius: BorderRadius.circular(12),
                onTap: () =>
                    SavedFoodDetailScreen.push(context, _editor.chosenFood!),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          S.of(context).adoptedFood(_editor.chosenFood!.name),
                        ),
                      ),
                      FoodSourceBadge(source: _editor.chosenFood!.source),
                      const SizedBox(width: 6),
                      Icon(
                        Icons.info_outline,
                        size: 18,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 8),
            TextField(
              key: savedFoodGramsFieldKey,
              controller: _grams,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: _onGramsChanged,
              decoration: InputDecoration(
                labelText: S
                    .of(context)
                    .fieldLabelParen(
                      S.of(context).labelGrams,
                      S.of(context).unitG,
                    ),
              ),
            ),
            const SizedBox(height: 12),
            _ValueRow(
              label: S.of(context).labelEnergy,
              unit: units.energyUnit,
              valueKey: savedFoodKcalValueKey,
              value: units.energyValue(current.kcal),
            ),
            _ValueRow(
              label: S.of(context).labelCarb,
              unit: S.of(context).unitG,
              valueKey: savedFoodCarbValueKey,
              value: current.carbG,
            ),
            _ValueRow(
              label: S.of(context).labelProtein,
              unit: S.of(context).unitG,
              valueKey: savedFoodProteinValueKey,
              value: current.proteinG,
            ),
            _ValueRow(
              label: S.of(context).labelFat,
              unit: S.of(context).unitG,
              valueKey: savedFoodFatValueKey,
              value: current.fatG,
            ),
            _ValueRow(
              label: units.saltLabel,
              unit: units.saltUnit,
              valueKey: savedFoodSaltValueKey,
              value: units.showsSodium ? current.sodiumMg : current.saltG,
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: savedFoodPickButtonKey,
                onPressed: _pickFood,
                icon: const Icon(Icons.bookmark_add_outlined),
                label: Text(S.of(context).selectSavedFood),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ValueRow extends StatelessWidget {
  const _ValueRow({
    required this.label,
    required this.unit,
    required this.valueKey,
    required this.value,
  });

  final String label;
  final String unit;
  final Key valueKey;

  /// Energy arrives as `int`, macros as `double`; [AppFormat.number] renders
  /// both without a trailing `.0`.
  final num value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: <Widget>[
          SizedBox(width: 48, child: Text(label)),
          Text(AppFormat.number(value), key: valueKey),
          const SizedBox(width: 4),
          Text(unit),
        ],
      ),
    );
  }
}

/// Whole grams print without a trailing `.0`; fractional grams are capped at
/// two decimals via the shared [AppFormat.number].
String _formatGrams(double grams) => AppFormat.number(grams);
