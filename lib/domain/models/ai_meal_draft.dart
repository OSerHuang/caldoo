import 'package:json_annotation/json_annotation.dart';

import 'meal_item.dart';

part 'ai_meal_draft.g.dart';

/// An editable draft produced by the AI meal analysis.
///
/// Every AI result reaches the review screen as one of these; the user edits
/// [items] before anything is persisted (saving never depends on AI success).
/// Items are [MealItem]s with `source: FoodSource.ai` and, when the provider
/// returned one, a per-item `confidence`.
///
/// When the AI call or its parsing fails, the draft arrives with an empty
/// [items] list and a [warning] so the review screen can show an error banner
/// over a blank editable row instead of losing the meal.
@JsonSerializable(explicitToJson: true, checked: true)
class AiMealDraft {
  const AiMealDraft({this.items = const <MealItem>[], this.note, this.warning});

  factory AiMealDraft.fromJson(Map<String, dynamic> json) =>
      _$AiMealDraftFromJson(json);

  /// Editable meal items; empty when the analysis produced nothing usable.
  final List<MealItem> items;

  /// Free text the user typed when logging (kept for display/context).
  final String? note;

  /// Non-fatal degradation notice to surface in the review banner
  /// (e.g. a malformed AI response); `null` when the draft is clean.
  final String? warning;

  Map<String, dynamic> toJson() => _$AiMealDraftToJson(this);

  AiMealDraft copyWith({List<MealItem>? items, String? note, String? warning}) {
    return AiMealDraft(
      items: items ?? this.items,
      note: note ?? this.note,
      warning: warning ?? this.warning,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is AiMealDraft &&
            _itemsEqual(other.items, items) &&
            other.note == note &&
            other.warning == warning;
  }

  @override
  int get hashCode => Object.hash(Object.hashAll(items), note, warning);
}

bool _itemsEqual(List<MealItem> a, List<MealItem> b) {
  if (identical(a, b)) {
    return true;
  }
  if (a.length != b.length) {
    return false;
  }
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) {
      return false;
    }
  }
  return true;
}
