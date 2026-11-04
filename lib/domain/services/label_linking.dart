/// Label linking: the pure logic between the user's saved foods and the AI
/// meal items.
///
/// The link AI call (`lib/ai/prompts/label_link_prompt.dart`) returns only
/// index numbers ([LabelMatch] from `lib/ai/schemas/label_link.dart`). This file
/// turns that raw answer into something safe to act on:
///
/// * [renderLabelIndex] — renders the `#n｜name｜…` lines the model matches
///   against. One line per food, single-line fields, whole-line truncation
///   under a character budget: the index is prompt data, so a newline inside a
///   user-supplied name must never become a new prompt line;
/// * [normalizeLabelMatches] — bounds the indices, de-duplicates rows, caps the
///   candidates per item and checks the optional serving count against the
///   food's own recorded servings ([foodServings]: structured [Food.servings]
///   first, [Food.notes] parsed for legacy rows). A bad row is **dropped or
///   cleaned**, never turned into an exception: link is an enhancement and
///   must degrade silently;
/// * [decideLabelApply] — the auto-apply gate of §5.1. A match may be applied
///   without asking only when the food is still active (not
///   [FoodStatus.archived]), the row is untouched (not already labelled, not
///   user-edited, not previously rejected) and the label's energy is plausible
///   for the AI estimate (0.3×–3.3× of the per-100 g ratio). Everything else is
///   `suggestOnly`.
///
/// Everything here is pure: no I/O, no clock, no randomness, and **no Flutter**
/// (domain layer). The same inputs always produce the same output, which is
/// what makes the auto-apply decision auditable in unit tests.
library;

import 'dart:developer' as developer;

import '../../ai/schemas/label_link.dart';
import '../models/models.dart';
import 'label_priority.dart';

/// Renders the label index the link prompt matches against (§4.2).
///
/// One line per food, `#n` being the food's **index in [foods]** (so the model's
/// `food_index` is directly a list subscript):
///
/// ```
/// #0｜辛拉面(农心)｜品牌：农心｜别名：辛拉面、泡面｜份量：一包 120 g
/// #1｜鸡蛋｜份量：一个 58 g
/// ```
///
/// * a segment is omitted when the food has no value for it (blank brand, no
///   aliases, no parseable serving);
/// * aliases come from [foodAliases] and servings from [foodServings]:
///   structured [Food.aliases] / [Food.servings] win, while legacy rows that
///   still keep them in [Food.notes] are parsed on the fly (§7); several
///   servings are joined with 「、」;
/// * every field is folded to a single line (newlines and whitespace runs
///   collapse to one space) — the output goes into a prompt, so a newline in a
///   saved name must not inject a line;
/// * a nameless food produces no line (it cannot be matched meaningfully); its
///   index simply never appears, the other indices keep their true positions;
/// * an archived food ([FoodStatus.archived]) also produces no line: it is
///   retired from matching, while its `#n` slot stays reserved so every
///   rendered index is still the food's true subscript in [foods];
/// * at most [maxChars] characters are returned, dropping **whole lines** and
///   never splitting one (a cut name would be a different name); a dropped line
///   is logged with `dart:developer` for diagnosis. The result is `''` for an
///   empty library or a non-positive budget.
///
/// The caller prepends the prompt header (`labelIndexHeader`); this renderer is
/// deliberately header-free and free of prompt wording.
String renderLabelIndex(List<Food> foods, {int maxChars = 6000}) {
  if (foods.isEmpty || maxChars <= 0) {
    return '';
  }

  final StringBuffer buffer = StringBuffer();
  int dropped = 0;
  for (int i = 0; i < foods.length; i++) {
    final String? line = _labelLine(i, foods[i]);
    if (line == null) {
      continue;
    }
    final int separator = buffer.isEmpty ? 0 : 1;
    if (buffer.length + separator + line.length > maxChars) {
      dropped++;
      continue;
    }
    if (buffer.isNotEmpty) {
      buffer.write('\n');
    }
    buffer.write(line);
  }
  if (dropped > 0) {
    developer.log(
      'label index truncated: $dropped line(s) dropped '
      '(foods: ${foods.length}, maxChars: $maxChars)',
      name: 'domain.labels',
    );
  }
  return buffer.toString();
}

/// Normalises the raw candidates from one link answer (§4.4).
///
/// [matches] is `LabelLinkResult.matches` in model order; [itemCount] is the
/// number of analysed items sent with the prompt and [foods] the exact list
/// rendered by [renderLabelIndex] (index = list subscript). Rules, in order:
///
/// * an `itemIndex` outside `[0, itemCount)` or a `foodIndex` outside
///   `[0, foods.length)` is **dropped** — the model cannot reach a label it was
///   not shown;
/// * the same `(itemIndex, foodIndex)` pair is kept once (first occurrence,
///   the model's ranking);
/// * at most [maxPerItem] candidates survive per item, in the original order;
/// * a `count` that is non-finite or `<= 0` is cleared to `null`; a serving
///   label that does not equal one of the food's recorded [FoodServing.label]
///   values ([foodServings], compared after whitespace folding) is cleared to
///   `null`. A count without a valid serving, or a serving without a valid
///   count, cannot produce grams, so `decideLabelApply` derives nothing from a
///   half pair.
///
/// Returns an unmodifiable list; empty input (or a non-positive [itemCount] /
/// [maxPerItem], or an empty [foods]) yields an empty list.
List<LabelMatch> normalizeLabelMatches({
  required List<LabelMatch> matches,
  required int itemCount,
  required List<Food> foods,
  int maxPerItem = labelLinkMaxCandidatesPerItem,
}) {
  if (matches.isEmpty || itemCount <= 0 || foods.isEmpty || maxPerItem <= 0) {
    return const <LabelMatch>[];
  }

  final Set<(int, int)> seen = <(int, int)>{};
  final Map<int, int> perItem = <int, int>{};
  final List<LabelMatch> normalized = <LabelMatch>[];

  for (final LabelMatch match in matches) {
    if (match.itemIndex < 0 || match.itemIndex >= itemCount) {
      continue;
    }
    if (match.foodIndex < 0 || match.foodIndex >= foods.length) {
      continue;
    }
    final int used = perItem[match.itemIndex] ?? 0;
    if (used >= maxPerItem) {
      continue;
    }
    if (!seen.add((match.itemIndex, match.foodIndex))) {
      continue;
    }
    perItem[match.itemIndex] = used + 1;
    normalized.add(_cleanMatch(match, foods[match.foodIndex]));
  }
  return List<LabelMatch>.unmodifiable(normalized);
}

/// What [decideLabelApply] decided for one candidate.
enum LabelApplyAction {
  /// Apply the label without asking; the UI must still offer undo (§5.3).
  autoApply,

  /// Only show the candidate; the user must choose it explicitly.
  suggestOnly,
}

/// Why [decideLabelApply] chose its action.
enum LabelApplyReason {
  /// Nothing blocks the match: it may be auto-applied.
  ok,

  /// The matched food is archived ([FoodStatus.archived]): the user retired it
  /// from matching, so it may only be offered for an explicit choice.
  archived,

  /// The row already has a user-chosen saved food.
  alreadyChosen,

  /// The user edited the row (name, grams or nutrients) after the analysis.
  userEdited,

  /// The user undid an earlier auto-apply for this row; the same link result
  /// must not apply again until a new analysis/link (§5.3).
  linkRejected,

  /// The label's per-100 g energy is far from the AI's implied value — likely
  /// a wrong match, so the user must confirm (§5.1 step 3).
  implausibleNutrients,

  /// The model's [LabelMatch.servingLabel] talks about a different unit than
  /// the one the user spelled out (`两片` vs a `一包 70 g` serving). Applying
  /// that match would write a wildly wrong weight (2 × 70 g for two slices),
  /// so it is only offered for an explicit choice.
  servingUnitMismatch,
}

/// One quantity the user spelled out in the capture text, e.g. `两片` →
/// `count: 2, unit: '片'`.
///
/// The analysis call never sees the saved-food library, so its `grams` is a
/// model guess; this is the deterministic evidence that lets the review screen
/// turn a recorded serving (`一片 25 g`) into real grams without depending on
/// the link model returning `count`/`serving_label`.
///
/// Plain value type: no Flutter, no I/O (domain layer contract).
class LocalQuantity {
  const LocalQuantity({required this.count, required this.unit});

  /// Number of servings/items the user described (`两` → 2, `半` → 0.5).
  final double count;

  /// The measure word, exactly as written (`片`, `包`, `碗`, …).
  final String unit;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocalQuantity && other.count == count && other.unit == unit;

  @override
  int get hashCode => Object.hash(count, unit);

  @override
  String toString() => 'LocalQuantity($count × $unit)';
}

/// The measure words a capture text may use for a portion (single-character
/// units; a unit is matched as written, e.g. `片` inside `一片`).
const List<String> _measureUnits = <String>[
  '片', '包', '盒', '块', '袋', '瓶', '罐', '个', '只', '根', '条', '份', //
  '碗', '杯', '勺', '把', '串', '粒', '颗', '枚', '张', '听', '桶', '支', //
  '板', '排', '卷',
];

/// Parses the **single** quantity a text spells out, or `null`.
///
/// Only an unambiguous text is used: `两片emmental 奶酪片` → `2 × 片`, but
/// `两个鸡蛋一碗米饭` has two quantities and yields `null` (assigning one of
/// them to a row would be a guess). Arabic (`2片`), Chinese (`两片`) and `半`
/// (0.5) counts are supported; a unit that is not in [_measureUnits] (e.g.
/// `150克`) is not a portion unit and yields `null`.
LocalQuantity? parseLocalQuantity(String text) {
  final String folded = _oneLine(text);
  if (folded.isEmpty) {
    return null;
  }
  final RegExp pattern = RegExp(
    r'(\d+(?:\.\d+)?|[零一二两俩三四五六七八九十半]+)\s*('
    '${_measureUnits.join('|')})',
  );
  final List<RegExpMatch> matches = pattern.allMatches(folded).toList();
  if (matches.length != 1) {
    return null;
  }
  final double? count = _parseCount(matches.single.group(1)!);
  if (count == null || !count.isFinite || count <= 0) {
    return null;
  }
  return LocalQuantity(count: count, unit: matches.single.group(2)!);
}

/// The first recorded serving of [food] whose label mentions [unit]
/// (`片` → `一片 25 g`), or `null`.
FoodServing? servingForUnit(Food food, String unit) {
  final String wanted = _oneLine(unit);
  if (wanted.isEmpty) {
    return null;
  }
  for (final FoodServing serving in foodServings(food)) {
    if (!serving.amount.isFinite || serving.amount <= 0) {
      continue;
    }
    if (_oneLine(serving.label).contains(wanted)) {
      return serving;
    }
  }
  return null;
}

/// How many units the serving's own label claims, defaulting to 1: `一片` → 1,
/// `三块` / `3块` → 3, `半盒` → 0.5. The amount of such a label describes the
/// WHOLE group (`三块 21 g` = three pieces weigh 21 g), so the per-unit grams
/// are the amount divided by this count.
double _labelUnitCount(String label) {
  final RegExpMatch? match = RegExp(r'^(\d+(?:\.\d+)?|[零一二两俩三四五六七八九十半]+)')
      .firstMatch(_oneLine(label));
  if (match == null) {
    return 1;
  }
  final double? count = _parseCount(match.group(1)!);
  return (count != null && count.isFinite && count > 0) ? count : 1;
}

/// Per-unit grams of [serving]: the recorded amount over the units its own
/// label claims (`一片 25 g` → 25, `三块 21 g` → 7, `半盒 50 g` → 100).
double _perUnitGrams(FoodServing serving) =>
    serving.amount / _labelUnitCount(serving.label);

/// `count × per-unit grams` for the serving of [food] that matches
/// [quantity]'s unit, or `null` when the food records no such serving.
///
/// The serving's own numeral is a GROUP size, never a multiplier again: the
/// written 「三块 21 g」 means one 块 is 7 g, so 「两块」 → 14 g — not
/// `2 × 21 = 42 g`.
double? servingGramsForQuantity(Food food, LocalQuantity quantity) {
  final FoodServing? serving = servingForUnit(food, quantity.unit);
  if (serving == null) {
    return null;
  }
  final double grams = quantity.count * _perUnitGrams(serving);
  return grams.isFinite && grams > 0 ? grams : null;
}

double? _parseCount(String token) {
  final String t = token.trim();
  if (t.isEmpty) {
    return null;
  }
  if (RegExp(r'^\d+(\.\d+)?$').hasMatch(t)) {
    return double.tryParse(t);
  }
  if (t == '半') {
    return 0.5;
  }
  if (t.contains('十')) {
    final List<String> parts = t.split('十');
    if (parts.length > 2) {
      return null;
    }
    final double? tens = parts[0].isEmpty ? 1 : _digit(parts[0]);
    final double? ones = parts.length == 2 && parts[1].isNotEmpty
        ? _digit(parts[1])
        : 0;
    if (tens == null || ones == null) {
      return null;
    }
    return tens * 10 + ones;
  }
  return _digit(t);
}

double? _digit(String token) {
  const Map<String, double> values = <String, double>{
    '零': 0,
    '一': 1,
    '二': 2,
    '两': 2,
    '俩': 2,
    '三': 3,
    '四': 4,
    '五': 5,
    '六': 6,
    '七': 7,
    '八': 8,
    '九': 9,
  };
  return values[token];
}

/// The outcome of the auto-apply gate: an action, the reason for it, and the
/// grams to write when (and only when) it is an auto-apply with a serving.
class LabelApplyDecision {
  const LabelApplyDecision({
    required this.action,
    required this.reason,
    this.grams,
  });

  /// Whether to apply now or only offer the candidate.
  final LabelApplyAction action;

  /// Why; stable machine-readable detail for tests and diagnostics.
  final LabelApplyReason reason;

  /// Grams to write on the item, or `null` to keep the AI's grams.
  ///
  /// Only ever non-null with [LabelApplyAction.autoApply]: it is
  /// `count × serving.amount` for the matched serving (ml treated as g).
  final double? grams;

  /// `true` when this decision may be applied without asking.
  bool get isAutoApply => action == LabelApplyAction.autoApply;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is LabelApplyDecision &&
            other.action == action &&
            other.reason == reason &&
            other.grams == grams;
  }

  @override
  int get hashCode => Object.hash(action, reason, grams);

  @override
  String toString() =>
      'LabelApplyDecision(action: ${action.name}, '
      'reason: ${reason.name}, grams: $grams)';
}

/// Decides whether one candidate match may be applied automatically (§5.1).
///
/// Order matters:
/// 1. an archived [food] ([FoodStatus.archived]) is never auto-applied —
///    `suggestOnly` with [LabelApplyReason.archived]. It is checked first
///    because it is a durable property of the candidate itself, not of the row;
/// 2. [hasChosenFood] / [userEdited] / [linkRejected] — the row is not in the
///    state link may act on — yield `suggestOnly` with the matching reason, in
///    that precedence order;
/// 3. the numeric gate: when the item has usable [MealItem.grams] and
///    [MealItem.kcal] and the food has a usable per-100 g `kcal`, compare
///    `ratio = food.kcal / (item.kcal / item.grams × 100)`. A ratio outside
///    `[0.3, 3.3]` means the label and the AI estimate describe wildly
///    different foods → `suggestOnly` ([LabelApplyReason.implausibleNutrients]);
/// 4. when the caller also passes the quantity parsed from the capture text
///    ([localQuantity], see [parseLocalQuantity]) the user's own words are the
///    strongest evidence:
///    * a model [LabelMatch.servingLabel] that talks about a different unit
///      (`两片` vs `一包`) yields `suggestOnly` with
///      [LabelApplyReason.servingUnitMismatch] — applying it would write
///      `2 × 70 g` for two slices;
///    * a recorded serving whose label mentions the user's unit (`一片 25 g`)
///      yields `localQuantity.count × serving.amount` as grams, even when the
///      model returned no `count`/`serving_label` at all;
/// 5. otherwise the model pair is used: when [LabelMatch.count] is usable
///    **and** [LabelMatch.servingLabel] matches one of the food's recorded
///    servings ([foodServings]: structured [Food.servings] first, [Food.notes]
///    fallback for legacy rows), grams are `count × serving.amount`; `ml`
///    servings use the existing 1 ml ≈ 1 g convention. Otherwise grams stay
///    `null`, meaning "apply name + nutrients, keep the AI grams";
/// 6. otherwise `autoApply` with [LabelApplyReason.ok].
///
/// The caller must still implement the undo contract (§5.3): auto-apply is
/// allowed only because it is one tap away from being reverted.
LabelApplyDecision decideLabelApply({
  required MealItem item,
  required Food food,
  required LabelMatch match,
  required bool userEdited,
  required bool hasChosenFood,
  required bool linkRejected,
  LocalQuantity? localQuantity,
}) {
  if (!food.isMatchable) {
    return const LabelApplyDecision(
      action: LabelApplyAction.suggestOnly,
      reason: LabelApplyReason.archived,
    );
  }
  if (hasChosenFood) {
    return const LabelApplyDecision(
      action: LabelApplyAction.suggestOnly,
      reason: LabelApplyReason.alreadyChosen,
    );
  }
  if (userEdited) {
    return const LabelApplyDecision(
      action: LabelApplyAction.suggestOnly,
      reason: LabelApplyReason.userEdited,
    );
  }
  if (linkRejected) {
    return const LabelApplyDecision(
      action: LabelApplyAction.suggestOnly,
      reason: LabelApplyReason.linkRejected,
    );
  }

  final double grams = item.grams;
  final int kcal = item.kcal;
  final int? foodKcal = food.kcal;
  if (grams > 0 && kcal > 0 && foodKcal != null && foodKcal > 0) {
    final double aiPer100g = kcal / grams * 100;
    final double ratio = foodKcal / aiPer100g;
    // A NaN ratio (impossible here: both sides are finite and positive) falls
    // through the comparisons, so guard the finite check explicitly.
    if (!ratio.isFinite || ratio < 0.3 || ratio > 3.3) {
      return const LabelApplyDecision(
        action: LabelApplyAction.suggestOnly,
        reason: LabelApplyReason.implausibleNutrients,
      );
    }
  }

  // The user's explicit unit (`两片`) is trusted over the model's serving
  // guess: a mismatch must never write `2 × 一包 70 g`, and a matching recorded
  // serving can supply grams even when the model returned no count at all.
  if (localQuantity != null) {
    final String? modelServingLabel = match.servingLabel;
    if (modelServingLabel != null &&
        !_oneLine(modelServingLabel).contains(localQuantity.unit)) {
      return const LabelApplyDecision(
        action: LabelApplyAction.suggestOnly,
        reason: LabelApplyReason.servingUnitMismatch,
      );
    }
    final double? localGrams = servingGramsForQuantity(food, localQuantity);
    if (localGrams != null) {
      return LabelApplyDecision(
        action: LabelApplyAction.autoApply,
        reason: LabelApplyReason.ok,
        grams: localGrams,
      );
    }
  }

  return LabelApplyDecision(
    action: LabelApplyAction.autoApply,
    reason: LabelApplyReason.ok,
    grams: _servingGrams(food, match),
  );
}

/// One `#n｜name｜品牌：…｜别名：…｜份量：…` line, or `null` for a nameless or
/// archived food (both keep their index slot without being rendered).
String? _labelLine(int index, Food food) {
  if (!food.isMatchable) {
    return null;
  }
  final String name = _oneLine(food.name);
  if (name.isEmpty) {
    return null;
  }

  final List<String> parts = <String>['#$index', name];

  final String brand = _oneLine(food.brand ?? '');
  if (brand.isNotEmpty) {
    parts.add('品牌：$brand');
  }

  final List<String> aliases = _fieldAliases(food);
  if (aliases.isNotEmpty) {
    parts.add('别名：${aliases.join('、')}');
  }

  final List<String> servings = _fieldServings(food);
  if (servings.isNotEmpty) {
    parts.add('份量：${servings.join('、')}');
  }

  return parts.join('｜');
}

/// Single-line, de-duplicated aliases for [food] (may be empty).
List<String> _fieldAliases(Food food) {
  final List<String> aliases = <String>[];
  for (final String raw in foodAliases(food)) {
    final String alias = _oneLine(raw);
    if (alias.isNotEmpty && !aliases.contains(alias)) {
      aliases.add(alias);
    }
  }
  return aliases;
}

/// `一包 120 g` / `一包 250 ml` for every recorded serving of [food].
List<String> _fieldServings(Food food) {
  final List<String> servings = <String>[];
  for (final FoodServing serving in foodServings(food)) {
    final String label = _oneLine(serving.label);
    if (label.isEmpty) {
      continue;
    }
    servings.add('$label ${_amountText(serving.amount)} ${serving.unit}');
  }
  return servings;
}

/// Clears a match whose count/serving are unusable (§4.4).
///
/// Returns a new [LabelMatch] only when something was cleared, so the common
/// valid case allocates nothing new.
LabelMatch _cleanMatch(LabelMatch match, Food food) {
  final double? count = match.count;
  final String? rawServingLabel = match.servingLabel;

  double? cleanCount = count;
  String? servingLabel = rawServingLabel == null
      ? null
      : _normalizeServingLabel(rawServingLabel);
  if (servingLabel != null && servingLabel.isEmpty) {
    servingLabel = null;
  }
  if (cleanCount != null && (!cleanCount.isFinite || cleanCount <= 0)) {
    cleanCount = null;
    servingLabel = null;
  }
  if (servingLabel != null && _findServing(food, servingLabel) == null) {
    servingLabel = null;
  }

  if (cleanCount == count && servingLabel == rawServingLabel) {
    return match;
  }
  return LabelMatch(
    itemIndex: match.itemIndex,
    foodIndex: match.foodIndex,
    count: cleanCount,
    servingLabel: servingLabel,
  );
}

/// The serving whose label equals [foldedLabel] after whitespace folding and
/// amount-stripping ([_normalizeServingLabel]), or `null` when the food records
/// no such serving.
FoodServing? _findServing(Food food, String foldedLabel) {
  final String wanted = _normalizeServingLabel(foldedLabel);
  for (final FoodServing serving in foodServings(food)) {
    if (_normalizeServingLabel(serving.label) == wanted) {
      return serving;
    }
  }
  return null;
}

/// `一片 25 g` → `一片` (also `一片（25 g）`): whitespace folded, then one
/// trailing amount+unit token dropped.
///
/// The link prompt renders each serving as `label amount unit`, and the model
/// routinely copies the whole rendered string into `serving_label` (observed
/// live: `一片 25 g` for a recorded `一片`). A strict literal comparison would
/// throw the count away and silently fall back to the AI grams, which is the
/// 「两片 Emmental 奶酪片」 bug: the same serving must be recognised whether or
/// not the model echoed its amount.
String _normalizeServingLabel(String value) {
  String label = _oneLine(value);
  label = label.replaceFirst(
    RegExp(
      r'[\s（(]*\d+(?:\.\d+)?\s*(?:g|ml|克|毫升)\s*[）)]*$',
      caseSensitive: false,
    ),
    '',
  );
  return label.trim();
}

/// `count × serving.amount` in grams when both the count and the serving are
/// usable, else `null` (§5.1 step 4).
///
/// `ml` servings are handled exactly like `g` ones: the app's long-standing
/// convention is 1 ml ≈ 1 g for drinks, and [FoodServing.unit] only distinguishes
/// the printed unit, not a density.
double? _servingGrams(Food food, LabelMatch match) {
  final double? count = match.count;
  final String? servingLabel = match.servingLabel;
  if (count == null || !count.isFinite || count <= 0 || servingLabel == null) {
    return null;
  }
  final String folded = _normalizeServingLabel(servingLabel);
  if (folded.isEmpty) {
    return null;
  }
  final FoodServing? serving = _findServing(food, folded);
  if (serving == null) {
    return null;
  }
  // Same group rule as the local-quantity path: the serving's own numeral is
  // the units its amount covers, so the model's count multiplies the PER-UNIT
  // grams (count 3 × 「三块 21 g」 → 21 g, not 63 g).
  final double grams = count * _perUnitGrams(serving);
  if (!grams.isFinite || grams <= 0) {
    return null;
  }
  return grams;
}

/// `120` / `16.67` — an amount as prompt data without trailing zeros.
///
/// Deliberately local (the domain layer must not depend on the UI's
/// `AppFormat`); capped at two decimals like the rest of the app's
/// display formatting.
String _amountText(double value) {
  if (!value.isFinite) {
    return '0';
  }
  if (value == value.roundToDouble()) {
    return value.toStringAsFixed(0);
  }
  return value.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
}

/// Collapses every whitespace run (including newlines) to one space and trims.
///
/// Used both to keep a rendered index line single-line and to compare a
/// model-returned serving label with a recorded one.
String _oneLine(String value) => value.replaceAll(RegExp(r'\s+'), ' ').trim();
