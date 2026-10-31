/// One editable meal-item row on the AI review screen (task 19).
///
/// Every field the plan lists is directly editable — name, grams, kcal, carbs,
/// protein, fat and salt. The card owns the [TextEditingController]s for its
/// [ReviewItem] and pushes mutations back through [onChanged] so the owning
/// screen can recompute the meal totals live.
///
/// The label-priority integration (task 20) is reused rather than duplicated:
/// `suggestSavedFood` ranks the saved foods against the row's **current** name
/// (so correcting the name re-ranks the candidates), [FoodSuggestionList] shows
/// the best one as a non-binding banner plus the runner-ups as chips, and both
/// it and [SavedFoodPicker] route through [ReviewItem.chooseFood] so the
/// per-100 g resolver applies.
///
/// Since analyze-then-link, a row may also carry a [LinkedLabelView]: the
/// background link call's match, auto-applied by the screen with an immediate
/// undo ([LabelLinkRow]). That block takes precedence over the lexical
/// suggestions; the lexical list only remains while the link has not answered
/// (or failed), which keeps this card's non-binding rule intact for it.
///
/// A **photo** capture disables the whole matching surface
/// ([libraryMatchingEnabled] `false`): no link block and no lexical suggestions,
/// because a photographed dish has no saved label behind it and a forced match
/// would show wrong nutrition. The 「选择已存食物」 button stays: a manual
/// attachment is the user's explicit choice, not a guess.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:caldoo/domain/models/models.dart';
import 'package:caldoo/domain/services/label_priority.dart';
import 'package:caldoo/features/meals/saved_foods/food_source_badge.dart';
import 'package:caldoo/features/meals/saved_foods/food_suggestion_list.dart';
import 'package:caldoo/features/meals/saved_foods/saved_food_detail_screen.dart';
import 'package:caldoo/features/meals/saved_foods/saved_food_picker.dart';
import 'package:caldoo/features/meals/saved_foods/saved_foods_providers.dart';
import 'package:caldoo/l10n/app_format.dart';
import 'package:caldoo/l10n/app_strings.dart';

import 'label_link_row.dart';
import 'linked_label_view.dart';
import 'meal_review_draft.dart';

/// Key of one item's name field.
Key reviewNameKey(String id) => Key('review_name_$id');

/// Key of one item's grams field.
Key reviewGramsKey(String id) => Key('review_grams_$id');

/// Key of one item's energy field.
Key reviewKcalKey(String id) => Key('review_kcal_$id');

/// Key of one item's carbohydrate field.
Key reviewCarbKey(String id) => Key('review_carb_$id');

/// Key of one item's protein field.
Key reviewProteinKey(String id) => Key('review_protein_$id');

/// Key of one item's fat field.
Key reviewFatKey(String id) => Key('review_fat_$id');

/// Key of one item's salt field.
Key reviewSaltKey(String id) => Key('review_salt_$id');

/// Key of one item's confidence chip (only rendered when confidence is set).
Key reviewConfidenceKey(String id) => Key('review_confidence_$id');

/// Key of one item's adopted saved food (only rendered once a food is chosen).
Key reviewChosenFoodKey(String id) => Key('review_chosen_food_$id');

/// Key of one item's remove button.
Key reviewRemoveKey(String id) => Key('review_remove_$id');

/// An editable review row for [reviewItem].
class ReviewItemCard extends ConsumerStatefulWidget {
  const ReviewItemCard({
    super.key,
    required this.reviewItem,
    required this.onChanged,
    required this.onRemove,
    this.linkView,
    this.linkCompleted = false,
    this.libraryMatchingEnabled = true,
    this.onUndoLink,
    this.onChangeLink,
    this.onApplyLinkCandidate,
    this.onNameEdited,
  });

  /// The mutable row state this card edits.
  final ReviewItem reviewItem;

  /// Called after every mutation so the parent can refresh the totals.
  final VoidCallback onChanged;

  /// Called when the user taps the remove button.
  final VoidCallback onRemove;

  /// The background link result for this row, or `null` while there is none.
  final LinkedLabelView? linkView;

  /// `true` once the link call has produced a result for the meal (even an
  /// empty one). A successful-but-empty result must **not** fall back to the
  /// lexical suggestions.
  final bool linkCompleted;

  /// Whether this capture may show any saved-library matching.
  ///
  /// `false` for photo captures: the card then renders neither the link block
  /// nor the lexical suggestions, so the row is purely the AI prediction plus
  /// the manual 「选择已存食物」 escape hatch. Defaults to `true` for callers that
  /// have no capture context.
  final bool libraryMatchingEnabled;

  /// Undoes the auto-applied link match (only called when [linkView] is
  /// [LinkedLabelView.autoApplied]).
  final VoidCallback? onUndoLink;

  /// Opens the saved-food picker to change the matched label.
  final VoidCallback? onChangeLink;

  /// Adopts one of the link's alternative candidates.
  final ValueChanged<Food>? onApplyLinkCandidate;

  /// Called after the user changes the row's name.
  ///
  /// The screen debounces this into a single-item re-link: a corrected name is
  /// new evidence for which saved label the row is, and the background link
  /// result must not keep pointing at the old name's candidates.
  final VoidCallback? onNameEdited;

  @override
  ConsumerState<ReviewItemCard> createState() => _ReviewItemCardState();
}

class _ReviewItemCardState extends ConsumerState<ReviewItemCard> {
  late final TextEditingController _name = TextEditingController(
    text: widget.reviewItem.name,
  );
  late final TextEditingController _grams = TextEditingController(
    text: _formatGrams(widget.reviewItem.grams),
  );
  late final TextEditingController _kcal = TextEditingController();
  late final TextEditingController _carb = TextEditingController();
  late final TextEditingController _protein = TextEditingController();
  late final TextEditingController _fat = TextEditingController();
  late final TextEditingController _salt = TextEditingController();

  @override
  void initState() {
    super.initState();
    _seedNutrients();
  }

  @override
  void didUpdateWidget(covariant ReviewItemCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A link match (or its undo) rewrites the row from outside the text
    // fields, so the controllers must follow. Only an applied-food change
    // triggers this: a candidates-only update must not clobber values the user
    // typed while the link call was in flight.
    final String? oldApplied = oldWidget.linkView?.appliedFood?.id;
    final String? newApplied = widget.linkView?.appliedFood?.id;
    if (oldApplied != newApplied) {
      _syncFromItem();
    }
  }

  /// Re-reads name / grams / nutrients from the effective [ReviewItem] after an
  /// external change (auto-applied link match or undo).
  void _syncFromItem() {
    final MealItem item = widget.reviewItem.item;
    if (_name.text != item.name) {
      _name.text = item.name;
    }
    final String grams = _formatGrams(item.grams);
    if (_grams.text != grams) {
      _grams.text = grams;
    }
    _seedNutrients();
  }

  @override
  void dispose() {
    _name.dispose();
    _grams.dispose();
    _kcal.dispose();
    _carb.dispose();
    _protein.dispose();
    _fat.dispose();
    _salt.dispose();
    super.dispose();
  }

  /// Refreshes the five nutrient controllers from the effective item.
  ///
  /// Called on init and after a grams edit / food choice, when the source
  /// values genuinely change. It is deliberately NOT called while the user is
  /// typing in a nutrient field (re-seeding would fight the cursor).
  void _seedNutrients() {
    final MealItem item = widget.reviewItem.item;
    _kcal.text = AppFormat.integer(item.kcal);
    _carb.text = AppFormat.number(item.carbG);
    _protein.text = AppFormat.number(item.proteinG);
    _fat.text = AppFormat.number(item.fatG);
    _salt.text = AppFormat.number(item.saltG);
  }

  void _onNameChanged(String value) {
    widget.reviewItem.editName(value);
    widget.onChanged();
    widget.onNameEdited?.call();
  }

  void _onGramsChanged(String raw) {
    final double? parsed = double.tryParse(raw.trim());
    if (parsed == null || !parsed.isFinite || parsed < 0) {
      // Malformed input is ignored: the last valid grams stays in effect.
      return;
    }
    try {
      widget.reviewItem.editGrams(parsed);
    } on ArgumentError {
      return;
    }
    _seedNutrients();
    widget.onChanged();
  }

  void _onNutrientChanged(ReviewNutrient nutrient, String raw) {
    final double? parsed = double.tryParse(raw.trim());
    if (parsed == null || !parsed.isFinite || parsed < 0) {
      return;
    }
    widget.reviewItem.editNutrient(nutrient, parsed);
    widget.onChanged();
  }

  /// Energy is whole kcal: only digits are accepted and the draft stores an
  /// `int`.
  void _onKcalChanged(String raw) {
    final int? parsed = int.tryParse(raw.trim());
    if (parsed == null || parsed < 0) {
      return;
    }
    widget.reviewItem.editKcal(parsed);
    widget.onChanged();
  }

  void _applyFood(Food food) {
    setState(() => widget.reviewItem.chooseFood(food));
    _seedNutrients();
    widget.onChanged();
  }

  Future<void> _pickFood() async {
    final Food? food = await SavedFoodPicker.push(context);
    if (food == null || !mounted) {
      return;
    }
    _applyFood(food);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<Food> foods =
        ref.watch(savedFoodsProvider).value ?? const <Food>[];
    // The background link result owns the suggestion surface once it exists;
    // the lexical matcher is only the fallback while the link call has not
    // answered (or failed). A successful-but-empty link shows nothing, and a
    // photo capture shows no matching at all (prediction-only).
    final LinkedLabelView? linkView = widget.linkView;
    final bool linkOnSurface =
        widget.libraryMatchingEnabled && linkView != null && !linkView.isEmpty;
    final List<FoodSuggestion> suggestions =
        (!widget.libraryMatchingEnabled ||
            linkOnSurface ||
            widget.linkCompleted ||
            widget.reviewItem.hasChosenFood)
        ? const <FoodSuggestion>[]
        : suggestSavedFood(widget.reviewItem.item, foods);
    final double? confidence = widget.reviewItem.confidence;
    final Food? chosen = widget.reviewItem.chosenFood;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    key: reviewNameKey(widget.reviewItem.id),
                    controller: _name,
                    onChanged: _onNameChanged,
                    decoration: InputDecoration(
                      labelText: S.of(context).reviewFoodName,
                    ),
                  ),
                ),
                IconButton(
                  key: reviewRemoveKey(widget.reviewItem.id),
                  onPressed: widget.onRemove,
                  tooltip: S.of(context).delete,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: <Widget>[
                FoodSourceBadge(source: widget.reviewItem.item.source),
                if (confidence != null) ...<Widget>[
                  const SizedBox(width: 8),
                  Text(
                    S
                        .of(context)
                        .confidenceLabel(confidence.toStringAsFixed(2)),
                    key: reviewConfidenceKey(widget.reviewItem.id),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ],
            ),
            if (linkOnSurface) ...<Widget>[
              const SizedBox(height: 8),
              LabelLinkRow(
                itemId: widget.reviewItem.id,
                view: linkView,
                onUndo: linkView.autoApplied ? widget.onUndoLink : null,
                onChange: widget.onChangeLink ?? () {},
                onApply: widget.onApplyLinkCandidate ?? (Food _) {},
                onOpenDetail: linkView.appliedFood == null
                    ? null
                    : () => SavedFoodDetailScreen.push(
                        context,
                        linkView.appliedFood!,
                      ),
              ),
            ] else ...[
              if (suggestions.isNotEmpty) ...<Widget>[
                const SizedBox(height: 8),
                FoodSuggestionList(
                  suggestions: suggestions,
                  onApply: _applyFood,
                ),
              ],
              if (chosen != null) ...<Widget>[
                const SizedBox(height: 8),
                // Tapping the adopted label food opens its per-100 g details,
                // so the values backing the recomputed row can be checked.
                InkWell(
                  key: reviewChosenFoodKey(widget.reviewItem.id),
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => SavedFoodDetailScreen.push(context, chosen),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(S.of(context).adoptedFood(chosen.name)),
                        ),
                        FoodSourceBadge(source: chosen.source),
                        const SizedBox(width: 6),
                        Icon(
                          Icons.info_outline,
                          size: 18,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
            const SizedBox(height: 12),
            _Field(
              fieldKey: reviewGramsKey(widget.reviewItem.id),
              controller: _grams,
              label: S.of(context).labelGrams,
              unit: S.of(context).unitG,
              onChanged: _onGramsChanged,
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: _Field(
                    fieldKey: reviewKcalKey(widget.reviewItem.id),
                    controller: _kcal,
                    label: S.of(context).labelEnergy,
                    unit: S.of(context).unitKcal,
                    integerOnly: true,
                    onChanged: _onKcalChanged,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _Field(
                    fieldKey: reviewCarbKey(widget.reviewItem.id),
                    controller: _carb,
                    label: S.of(context).labelCarb,
                    unit: S.of(context).unitG,
                    onChanged: (String value) =>
                        _onNutrientChanged(ReviewNutrient.carbG, value),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: _Field(
                    fieldKey: reviewProteinKey(widget.reviewItem.id),
                    controller: _protein,
                    label: S.of(context).labelProtein,
                    unit: S.of(context).unitG,
                    onChanged: (String value) =>
                        _onNutrientChanged(ReviewNutrient.proteinG, value),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _Field(
                    fieldKey: reviewFatKey(widget.reviewItem.id),
                    controller: _fat,
                    label: S.of(context).labelFat,
                    unit: S.of(context).unitG,
                    onChanged: (String value) =>
                        _onNutrientChanged(ReviewNutrient.fatG, value),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _Field(
              fieldKey: reviewSaltKey(widget.reviewItem.id),
              controller: _salt,
              label: S.of(context).labelSalt,
              unit: S.of(context).unitG,
              onChanged: (String value) =>
                  _onNutrientChanged(ReviewNutrient.saltG, value),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
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

/// A compact labelled numeric text field.
class _Field extends StatelessWidget {
  const _Field({
    required this.fieldKey,
    required this.controller,
    required this.label,
    required this.unit,
    required this.onChanged,
    this.integerOnly = false,
  });

  final Key fieldKey;
  final TextEditingController controller;
  final String label;
  final String unit;
  final ValueChanged<String> onChanged;

  /// Energy fields are whole kcal: digits only, no decimal point.
  final bool integerOnly;

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: fieldKey,
      controller: controller,
      keyboardType: integerOnly
          ? TextInputType.number
          : const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: integerOnly
          ? <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly]
          : null,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: S.of(context).fieldLabelParen(label, unit),
      ),
    );
  }
}

/// Whole grams print without a trailing `.0`; fractional grams are capped at
/// two decimals via the shared [AppFormat.number].
String _formatGrams(double grams) => AppFormat.number(grams);
