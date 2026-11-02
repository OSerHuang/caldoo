/// Editable draft state for the AI review/edit screen (task 19).
///
/// The AI never writes to the database directly: it produces a list of
/// [MealItem] estimates, and [MealReviewScreen] wraps each one in a
/// [ReviewItem] the user can edit before anything is saved. This file is the
/// **pure-Dart** core of that step — no Flutter, no Riverpod — so the arithmetic
/// and the totals are unit-testable on their own.
///
/// The one rule that governs grams edits (the plan's defined behaviour):
/// * an AI item only defines an implied per-gram basis, so changing its grams
///   scales `kcal` / `carbG` / `proteinG` / `fatG` / `saltG` by exactly
///   `newGrams / oldGrams` (delegated to [MealItemEditor]); `kcal` is an
///   integer, so that proportional scale rounds once;
/// * a **label-backed** item (the user tapped 采用, picked a saved food, or the
///   analyze-then-link call auto-applied a match) instead recomputes every
///   field from the food's per-100 g values via the task-10 resolver — also
///   delegated to [MealItemEditor].
///
/// `kcal` is therefore always scaled or user-edited; it is never derived from
/// the 4/4/9 macro factors (a hard rule of this task).
///
/// A link auto-apply is the one change the draft makes without a user tap, so
/// [ReviewItem] remembers exactly what it wrote and offers `undoLinkedFood`;
/// a `linkRejected` row is never auto-applied twice.
library;

import 'package:caldoo/domain/models/models.dart';
import 'package:caldoo/features/meals/saved_foods/meal_item_editor.dart';

/// A nutrient field the review row lets the user edit directly.
///
/// [MealItem] field names on purpose: the draft never invents a parallel
/// vocabulary for the same five values.
enum ReviewNutrient { kcal, carbG, proteinG, fatG, saltG }

/// One editable meal line: its original AI estimate, an optional chosen saved
/// food, the current grams, and per-field manual overrides.
///
/// [MealItemEditor] owns the grams semantics (proportional for AI, per-100 g
/// for label). [ReviewItem] layers the user's direct nutrient edits on top:
/// * editing a nutrient records an override for that one field;
/// * editing grams or choosing/clearing a food **recomputes from the source**
///   and drops the overrides, exactly like the label rule (no snapshot).
///
/// Label linking (analyze-then-link) may **auto-apply** a matched label before
/// the user touches the row. That is recorded separately from user edits:
/// * [userEdited] flips on any direct name/grams/nutrient edit, and the screen
///   uses it to decide whether an incoming link result may still be applied;
/// * [applyLinkedFood] remembers exactly what it wrote (name, grams) so
///   [undoLinkedFood] can restore only fields the user has not changed since;
/// * [linkRejected] keeps the same row from being auto-applied again after the
///   user undoes a match.
class ReviewItem {
  ReviewItem({required this.base})
    : _editor = MealItemEditor(base),
      _name = base.name;

  /// The untouched AI estimate this row started from. Never mutated.
  final MealItem base;

  final MealItemEditor _editor;

  String _name;

  final Map<ReviewNutrient, double> _overrides = <ReviewNutrient, double>{};

  /// The user's direct energy edit, if any (energy is an `int` kcal).
  int? _kcalOverride;

  /// `true` once the user directly edited this row (name, grams or nutrient).
  bool _userEdited = false;

  /// `true` after the user undid an auto-applied label match.
  bool _linkRejected = false;

  /// The name auto-applied by a link match, if any.
  String? _autoAppliedName;

  /// The grams auto-applied by a link match, if any.
  double? _autoAppliedGrams;

  /// Stable row identity (the base item's id; unique within the meal).
  String get id => base.id;

  /// AI self-reported confidence, when the provider returned one.
  double? get confidence => base.confidence;

  /// Current (possibly edited) display name.
  String get name => _name;

  /// Current consumed weight in grams.
  double get grams => _editor.grams;

  /// The saved food the user chose, if any (the label-priority path).
  Food? get chosenFood => _editor.chosenFood;

  /// Whether a saved food has been chosen.
  bool get hasChosenFood => _editor.hasChosenFood;

  /// `true` once the user directly edited this row.
  bool get userEdited => _userEdited;

  /// `true` after the user undid an auto-applied label match.
  bool get linkRejected => _linkRejected;

  /// `true` when this row was auto-applied by a link match (the undo target).
  bool get autoAppliedLink =>
      _autoAppliedName != null || _autoAppliedGrams != null;

  /// `true` when the name is blank — such a row blocks saving.
  bool get hasBlankName => _name.trim().isEmpty;

  /// The effective item: source-derived nutrients with the manual overrides
  /// applied. This is what gets totalled and persisted.
  MealItem get item {
    final MealItem derived = _editor.item;
    return derived.copyWith(
      name: _name,
      kcal: _kcalOverride ?? derived.kcal,
      carbG: _override(ReviewNutrient.carbG, derived.carbG),
      proteinG: _override(ReviewNutrient.proteinG, derived.proteinG),
      fatG: _override(ReviewNutrient.fatG, derived.fatG),
      saltG: _override(ReviewNutrient.saltG, derived.saltG),
    );
  }

  double _override(ReviewNutrient nutrient, double derived) =>
      _overrides[nutrient] ?? derived;

  /// Sets the display name (blank allowed while typing; validation happens at
  /// save time).
  void editName(String name) {
    _name = name;
    _userEdited = true;
  }

  /// Sets the consumed weight.
  ///
  /// Delegates the scaling/recompute to [MealItemEditor] (proportional for AI
  /// items, per-100 g for label items). Whenever the editor actually
  /// recomputes from a source of truth — a chosen food's per-100 g values, or
  /// a positive base weight to scale — the per-field overrides are cleared, or
  /// they would freeze the previous value on top of the fresh numbers.
  ///
  /// A row with no basis (a manually added blank row, or an AI row that
  /// returned grams 0) cannot rescale: the overrides ARE the values there, so
  /// they are kept and the grams edit changes the weight only. Malformed
  /// grams (negative / NaN / infinite) propagate the editor's
  /// [ArgumentError] so the UI layer can ignore them.
  void editGrams(double grams) {
    _editor.editGrams(grams);
    if (_editor.hasChosenFood || _editor.aiItem.grams > 0) {
      _clearOverrides();
    }
    _userEdited = true;
  }

  /// Records a direct, per-field manual override for a fractional nutrient.
  ///
  /// [ReviewNutrient.kcal] is integer-only and uses [editKcal] instead.
  void editNutrient(ReviewNutrient nutrient, double value) {
    if (nutrient == ReviewNutrient.kcal) {
      throw ArgumentError.value(
        nutrient,
        'nutrient',
        'kcal is an integer; use editKcal',
      );
    }
    _overrides[nutrient] = value;
    _userEdited = true;
  }

  /// Records a direct energy edit (whole kcal).
  void editKcal(int value) {
    if (value < 0) {
      throw ArgumentError.value(value, 'value', 'must not be negative');
    }
    _kcalOverride = value;
    _userEdited = true;
  }

  /// Adopts [food] (the explicit 采用 / picker tap) and recomputes from its
  /// per-100 g values at the current grams.
  ///
  /// A manual choice supersedes any auto-applied link match, so the undo
  /// affordance disappears afterwards.
  void chooseFood(Food food) {
    _editor.chooseFood(food);
    _clearOverrides();
    _autoAppliedName = null;
    _autoAppliedGrams = null;
  }

  /// Drops the chosen food and returns to the AI estimate.
  void clearFood() {
    _editor.clearFood();
    _clearOverrides();
    _autoAppliedName = null;
    _autoAppliedGrams = null;
  }

  /// Applies a link match **without** marking the row as user-edited.
  ///
  /// [name] (the saved food's name) and [grams] (a serving-count correction)
  /// are optional: only what the link actually determined is written, and each
  /// written field is remembered so [undoLinkedFood] can restore it.
  void applyLinkedFood(Food food, {String? name, double? grams}) {
    _editor.chooseFood(food);
    _clearOverrides();
    if (name != null && name.trim().isNotEmpty) {
      _name = name;
      _autoAppliedName = name;
    }
    if (grams != null && grams.isFinite && grams >= 0) {
      _editor.editGrams(grams);
      _autoAppliedGrams = grams;
    }
  }

  /// Undoes an auto-applied link match.
  ///
  /// Only the fields the link wrote **and the user has not changed since** are
  /// restored; a name or grams the user typed is kept verbatim. The row is
  /// marked [linkRejected] so a late duplicate result cannot apply again.
  void undoLinkedFood() {
    final String? appliedName = _autoAppliedName;
    if (appliedName != null && _name == appliedName) {
      _name = base.name;
    }
    final double? appliedGrams = _autoAppliedGrams;
    if (appliedGrams != null && _editor.grams == appliedGrams) {
      _editor.editGrams(base.grams);
    }
    _editor.clearFood();
    _clearOverrides();
    _autoAppliedName = null;
    _autoAppliedGrams = null;
    _linkRejected = true;
  }

  /// Marks the row as "the user said no to a link match".
  void markLinkRejected() => _linkRejected = true;

  /// Adopts a link candidate the user tapped explicitly.
  ///
  /// The name follows the label (a link candidate is already the user's
  /// intended food), but this is a manual choice: no undo affordance is
  /// recorded.
  void adoptLinkedCandidate(Food food) {
    _editor.chooseFood(food);
    _clearOverrides();
    _name = food.name;
    _autoAppliedName = null;
    _autoAppliedGrams = null;
  }

  /// Drops every manual override, including the integer energy one.
  void _clearOverrides() {
    _overrides.clear();
    _kcalOverride = null;
  }
}

/// The whole meal draft: an ordered list of [ReviewItem]s plus live totals.
///
/// Mutable on purpose: [MealReviewScreen] owns one instance and calls
/// `setState` after each mutation, mirroring [MealItemEditor]'s design and
/// keeping the widget free of a provider just to recompute a sum.
class MealReviewDraft {
  MealReviewDraft({required List<MealItem> items})
    : items = <ReviewItem>[
        for (final MealItem item in items) ReviewItem(base: item),
      ];

  /// Editable lines, in display order.
  final List<ReviewItem> items;

  /// A meal with no items can never be saved.
  bool get isEmpty => items.isEmpty;

  /// At least one row has a blank name, so the draft is not saveable yet.
  bool get hasBlankName => items.any((ReviewItem item) => item.hasBlankName);

  /// The save guard: a meal must have at least one (named) item.
  bool get canSave => items.isNotEmpty && !hasBlankName;

  /// Appends a blank, manually-entered row the user can fill in.
  ///
  /// [id] is supplied by the caller (the screen's id seam) so this class stays
  /// pure Dart and free of any id-generation dependency.
  void addBlankItem(String id) {
    items.add(ReviewItem(base: blankReviewItem(id)));
  }

  /// Removes the row at [index]; out-of-range indices are ignored.
  void removeAt(int index) {
    if (index < 0 || index >= items.length) {
      return;
    }
    items.removeAt(index);
  }

  /// The effective, source-resolved items to persist (in the same order).
  List<MealItem> get effectiveItems => <MealItem>[
    for (final ReviewItem item in items) item.item,
  ];

  /// Summed energy in **whole kcal** over the effective items.
  int get totalKcal {
    var total = 0;
    for (final ReviewItem item in items) {
      total += item.item.kcal;
    }
    return total;
  }

  /// Summed carbohydrate in grams.
  double get totalCarbG => _sum((MealItem item) => item.carbG);

  /// Summed protein in grams.
  double get totalProteinG => _sum((MealItem item) => item.proteinG);

  /// Summed fat in grams.
  double get totalFatG => _sum((MealItem item) => item.fatG);

  /// Summed salt in grams.
  double get totalSaltG => _sum((MealItem item) => item.saltG);

  double _sum(double Function(MealItem item) pick) {
    double total = 0;
    for (final ReviewItem item in items) {
      total += pick(item.item);
    }
    return total;
  }
}

/// A blank, manually-entered item with a fresh [id].
///
/// Zero nutrients (not `null`): the user is expected to type the real values,
/// and a blank row can never be saved because its name is empty.
MealItem blankReviewItem(String id) => MealItem(
  id: id,
  name: '',
  grams: 0,
  kcal: 0,
  carbG: 0,
  proteinG: 0,
  fatG: 0,
  saltG: 0,
  source: FoodSource.manual,
);
