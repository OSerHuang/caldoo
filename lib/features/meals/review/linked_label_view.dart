/// Presentation model for one review row's label-link result.
///
/// The review screen runs the link call in the background (see
/// `label_linker.dart`) and turns each matched row into one of these:
///
/// * [appliedFood] non-null + [autoApplied] — the match was written into the
///   draft and the row shows 撤销 / 更换;
/// * [appliedFood] non-null + not [autoApplied] — the user picked one of the
///   link's candidates, so there is nothing to undo;
/// * [appliedFood] null — the link found candidates but the row was edited (or
///   the numbers looked implausible), so they are offered as chips only.
///
/// It is deliberately a plain value type: the draft stays the single source of
/// truth for the meal, this only describes what the UI should offer.
library;

import 'package:caldoo/domain/models/models.dart';

/// What the review row should show for its label link.
class LinkedLabelView {
  const LinkedLabelView({
    this.appliedFood,
    this.alternatives = const <Food>[],
    this.autoApplied = false,
  });

  /// The food currently linked to the row, or `null` when only candidates
  /// exist.
  final Food? appliedFood;

  /// The remaining link candidates (never contains [appliedFood]).
  final List<Food> alternatives;

  /// `true` when the link wrote this food into the draft automatically, which
  /// is the only case that offers 撤销.
  final bool autoApplied;

  /// `true` when there is nothing to render.
  bool get isEmpty => appliedFood == null && alternatives.isEmpty;

  /// Returns a copy with the auto-apply flag cleared, keeping the foods.
  ///
  /// Used when the user picks a candidate explicitly: the choice is theirs, so
  /// the undo affordance must not appear.
  LinkedLabelView asManualChoice() =>
      LinkedLabelView(appliedFood: appliedFood, alternatives: alternatives);

  /// Returns a copy where [food] is the applied match (the user picked it from
  /// the candidate chips) and is removed from [alternatives].
  LinkedLabelView withApplied(Food food) => LinkedLabelView(
    appliedFood: food,
    alternatives: <Food>[
      for (final Food candidate in alternatives)
        if (candidate.id != food.id) candidate,
    ],
  );
}
