/// Label-priority resolution and saved-food matching for AI meal items.
///
/// When the user logs a meal, the AI returns items already scaled to their
/// grams. If a saved [Food] carries **per-100 g** values from a real
/// 营养成分表 (GB 28050) label, the label is authoritative: for every nutrient
/// field the label provides, the item is recomputed from
/// `labelPer100g * grams / 100`.
///
/// The rules, in one place:
/// * a field the label left blank (`null`) **falls back** to the AI value —
///   it is never silently zeroed;
/// * units bridge explicitly at this boundary: the label stores sodium in
///   **mg**, the item stores salt in **g** (`sodiumMgToSaltG`);
/// * every resolved field carries its [NutrientProvenance] so the UI can
///   badge "from the label" vs "AI estimate" per value;
/// * suggestion matching is deterministic and offline: exact normalized name,
///   then an exact alias ([Food.aliases], or [Food.notes] for legacy rows),
///   then substring containment in either direction, then CJK/ASCII bigram
///   similarity. Archived foods ([FoodStatus.archived]) are never suggested nor
///   recalled — the user retired them from matching. A brand string
///   contained in the AI name nudges a candidate up, and a wildly implausible
///   per-100 g energy estimate demotes non-exact candidates — an exact name is
///   never demoted. Barcode is deliberately never used;
/// * [suggestSavedFood] is a **non-binding** suggestion: it never applies
///   anything. Only an explicit user choice reaches [resolveNutrients].
///   The one automatic path is the analyze-then-link call: its id-validated
///   match may be applied for the user, but only with an immediate undo, and
///   this lexical scorer still never auto-applies.
///
/// The caller keeps `foodId` + `grams` on the [MealItem] and calls
/// [resolveNutrients] again when the grams change instead of snapshotting the
/// scaled numbers, so the per-100 g source of truth stays on the [Food].
library;

// `FoodServing` used to live here; it is a domain model now so that a `Food`
// can carry structured servings. Re-exported so existing importers keep
// compiling against this library during the transition.
export '../models/food_serving.dart' show FoodServing;

import '../../core/units/nutrition_units.dart';
import '../models/models.dart';

/// Every nutrient field [resolveNutrients] resolves, one provenance each.
enum NutrientField { kcal, carbG, proteinG, fatG, saltG }

/// Where one resolved field came from.
enum NutrientProvenance {
  /// The chosen saved food's per-100 g value (the label-priority path).
  label,

  /// The AI item's own value, used because the saved food left the field blank.
  ai,
}

/// A [MealItem]'s nutrient values after label-priority resolution.
///
/// All values are already scaled to the item's grams. [provenanceOf] reports
/// the per-field source so each value can be badged independently.
class ResolvedNutrients {
  const ResolvedNutrients({
    required this.kcal,
    required this.carbG,
    required this.proteinG,
    required this.fatG,
    required this.saltG,
    required this.provenance,
  });

  /// Energy in **whole kcal**, scaled to the item's grams.
  final int kcal;

  /// Carbohydrate in grams, scaled to the item's grams.
  final double carbG;

  /// Protein in grams, scaled to the item's grams.
  final double proteinG;

  /// Fat in grams, scaled to the item's grams.
  final double fatG;

  /// Salt in grams (the item's display unit), scaled to the item's grams.
  final double saltG;

  /// Per-field source; one entry per [NutrientField].
  final Map<NutrientField, NutrientProvenance> provenance;

  /// The source of [field]'s value; every [NutrientField] is always present.
  NutrientProvenance provenanceOf(NutrientField field) => provenance[field]!;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ResolvedNutrients &&
            other.kcal == kcal &&
            other.carbG == carbG &&
            other.proteinG == proteinG &&
            other.fatG == fatG &&
            other.saltG == saltG &&
            _mapEquals(other.provenance, provenance);
  }

  @override
  int get hashCode => Object.hash(
    kcal,
    carbG,
    proteinG,
    fatG,
    saltG,
    Object.hashAllUnordered(
      provenance.entries.map(
        (MapEntry<NutrientField, NutrientProvenance> e) =>
            Object.hash(e.key, e.value),
      ),
    ),
  );
}

/// Why [suggestSavedFood] put a saved food on the candidate list.
enum FoodMatchReason {
  /// The normalized saved-food name equals the normalized AI item name.
  exactName,

  /// An alias of the saved food ([Food.aliases], or [Food.notes] for legacy
  /// rows) equals the normalized AI item name.
  alias,

  /// The AI item name and the saved-food name/alias contain each other.
  partialName,

  /// The names are not substrings, but their bigrams are similar enough.
  similarName,
}

/// A ranked, **non-binding** candidate returned by [suggestSavedFood].
class FoodSuggestion {
  const FoodSuggestion({
    required this.food,
    required this.score,
    this.reason = FoodMatchReason.exactName,
    this.matchedAlias,
  });

  /// The saved food the user may choose to apply.
  final Food food;

  /// Ranking weight in `(0, 1]` — a deterministic ordering weight, **not** a
  /// match probability.
  final double score;

  /// Why [food] matched; the UI can explain a fuzzy suggestion to the user.
  final FoodMatchReason reason;

  /// The raw alias text when [reason] is [FoodMatchReason.alias], else `null`.
  final String? matchedAlias;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is FoodSuggestion &&
            other.food == food &&
            other.score == score &&
            other.reason == reason &&
            other.matchedAlias == matchedAlias;
  }

  @override
  int get hashCode => Object.hash(food, score, reason, matchedAlias);
}

/// Characters that may appear in a normalized key: ASCII letters/digits,
/// common CJK ideographs (U+3400–U+4DBF, U+4E00–U+9FFF) and whitespace.
/// Punctuation, symbols and anything else becomes a separator space.
final RegExp _nonKeyChar = RegExp(r'[^a-z0-9\s\u3400-\u4dbf\u4e00-\u9fff]');

/// A run of whitespace, including the full-width U+3000 space.
final RegExp _whitespaceRun = RegExp(r'\s+');

/// Whitespace sitting *between* two CJK characters (Chinese does not use word
/// spaces, so `"全脂 牛奶"` and `"全脂牛奶"` are the same food name).
final RegExp _cjkInnerSpace = RegExp(
  r'(?<=[\u3400-\u4dbf\u4e00-\u9fff])\s+(?=[\u3400-\u4dbf\u4e00-\u9fff])',
);

/// Alias markers understood by [parseFoodAliases]; matched case-insensitively.
final RegExp _aliasMarker = RegExp(r'别名|又名|俗称|别称|aka', caseSensitive: false);

/// Separators between aliases inside one notes field.
final RegExp _aliasSeparator = RegExp(r'[、,，;；/／·|\n\r]+');

/// Classifiers that make a label look like a serving: 一袋 / 一块 / 两份 / 半包…
///
/// A segment only counts as a serving when its label carries one of these
/// characters, which is what keeps prose such as `每 100 g` or a date from
/// being read as a package size.
const String _servingClassifiers = '个块袋包罐瓶片根盒份碗杯勺条只把串枚颗粒听筒卷';

final RegExp _servingClassifier = RegExp('[$_servingClassifiers]');

/// Segments of [Food.notes] that may each hold one serving, e.g.
/// `一包 100 g，一块 30 g`.
final RegExp _servingSegmentSeparator = RegExp(r'[｜|；;\n\r，,]+');

/// One (possibly nested) parenthetical group, removed before matching so that
/// `一罐 450 g（盖子标 45g eiwit per pot）` reads as `一罐 450 g`.
final RegExp _parenthetical = RegExp(r'[（(][^（）()]*[）)]');

/// `<label> <amount> <unit>` — the whole segment must match.
final RegExp _servingShape = RegExp(
  r'^(.+?)\s*(\d+(?:\.\d+)?)\s*(g|克|ml|毫升)$',
  caseSensitive: false,
);

/// Labels containing arithmetic ("3块=50g") describe a *group*, not one
/// serving, so they are rejected instead of being shown as a per-unit size.
final RegExp _servingBadLabel = RegExp(r'[=＝≈~＜＞<>+＋±]');

/// The one and only match key: `trim` -> lowercase -> punctuation/symbols
/// become separators -> whitespace runs collapse to a single space -> spaces
/// between two CJK characters are removed.
///
/// `normalizeName(' 全脂 牛奶！') == '全脂牛奶'`. The key is deterministic and
/// idempotent; it is used by every matcher in this file.
String normalizeName(String raw) {
  final folded = raw.trim().toLowerCase().replaceAll(_nonKeyChar, ' ');
  final collapsed = folded.replaceAll(_whitespaceRun, ' ').trim();
  return collapsed.replaceAll(_cjkInnerSpace, '');
}

/// Extracts aliases recorded in [Food.notes], e.g.
/// `"一包 45 g；别名：小饼干、牛奶"` -> `['小饼干', '牛奶']`.
///
/// The heuristic is deliberately deterministic and conservative:
/// * markers: 别名 / 又名 / 俗称 / 别称 / AKA (case-insensitive), optionally
///   followed by a colon;
/// * the value runs to the next marker (or the end of the notes);
/// * values split on `、 , ， ; ； / ／ · |` and newlines;
/// * surrounding whitespace is trimmed, blank aliases are dropped, and exact
///   duplicates are removed while order is preserved.
///
/// Notes with no marker, `null`, or blank notes yield an empty list. Aliases
/// are returned **raw** (trimmed, not normalized).
List<String> parseFoodAliases(String? notes) {
  if (notes == null) {
    return const <String>[];
  }
  final text = notes.trim();
  if (text.isEmpty) {
    return const <String>[];
  }

  final markers = _aliasMarker.allMatches(text).toList();
  if (markers.isEmpty) {
    return const <String>[];
  }

  final parsed = <String>[];
  for (var i = 0; i < markers.length; i++) {
    final start = markers[i].end;
    final end = i + 1 < markers.length ? markers[i + 1].start : text.length;
    if (end <= start) {
      continue;
    }
    final value = text
        .substring(start, end)
        .replaceFirst(RegExp(r'^\s*[:：]?\s*'), '');
    for (final segment in value.split(_aliasSeparator)) {
      final alias = segment.trim();
      if (alias.isNotEmpty) {
        parsed.add(alias);
      }
    }
  }

  final seen = <String>{};
  final aliases = <String>[
    for (final alias in parsed)
      if (seen.add(alias)) alias,
  ];
  return List<String>.unmodifiable(aliases);
}

/// Extracts servings recorded in [Food.notes], e.g.
/// `"一包 100 g；一块 30 g；别名：饼干"` -> `一包 100 g` + `一块 30 g`.
///
/// The heuristic is deliberately deterministic and conservative:
/// * parenthetical remarks are removed first (nested groups included), so
///   `一罐 450 g（整罐≈450g=270kcal）` is read as `一罐 450 g`;
/// * the notes are split on `｜ | ； ; ， ,` and newlines, and one whole segment
///   must read `<label> <amount> <g|克|ml|毫升>`;
/// * the label must contain a serving classifier (个块袋包罐瓶片根盒份碗杯勺
///   条只把串枚颗粒听筒卷), which keeps `每 100 g`, dates and prose out;
/// * blank / zero / unparseable amounts, `null` and blank notes yield `[]`.
///
/// At most three distinct servings are returned (order preserved). A wrong
/// serving would silently change the AI's grams, so anything ambiguous is
/// dropped rather than guessed.
List<FoodServing> parseFoodServings(String? notes) {
  if (notes == null) {
    return const <FoodServing>[];
  }
  final text = notes.trim();
  if (text.isEmpty) {
    return const <FoodServing>[];
  }

  final servings = <FoodServing>[];
  for (final raw in _stripParentheticals(
    text,
  ).split(_servingSegmentSeparator)) {
    final segment = raw.replaceAll(_whitespaceRun, ' ').trim();
    if (segment.isEmpty) {
      continue;
    }
    final match = _servingShape.firstMatch(segment);
    if (match == null) {
      continue;
    }
    final label = match.group(1)!.trim();
    if (label.isEmpty || label.length > 16) {
      continue;
    }
    if (!_servingClassifier.hasMatch(label)) {
      continue;
    }
    if (_servingBadLabel.hasMatch(label)) {
      continue;
    }
    final amount = double.tryParse(match.group(2)!);
    if (amount == null || !amount.isFinite || amount <= 0) {
      continue;
    }
    final unit = switch (match.group(3)!.toLowerCase()) {
      'g' || '克' => 'g',
      _ => 'ml',
    };
    final serving = FoodServing(label: label, amount: amount, unit: unit);
    if (servings.contains(serving)) {
      continue;
    }
    servings.add(serving);
    if (servings.length == 3) {
      break;
    }
  }
  return List<FoodServing>.unmodifiable(servings);
}

/// Removes every parenthetical group, innermost first, so a nested
/// `（净重 500 g（不含冰衣））` never leaves a stray fragment behind.
String _stripParentheticals(String text) {
  var result = text;
  while (true) {
    final String next = result.replaceAll(_parenthetical, ' ');
    if (next == result) {
      return result;
    }
    result = next;
  }
}

/// The aliases used by **every** matcher for [food].
///
/// Structured [Food.aliases] win; legacy rows that still carry them in
/// [Food.notes] are parsed on the fly, so old and new data behave the same.
List<String> foodAliases(Food food) =>
    food.aliases.isNotEmpty ? food.aliases : parseFoodAliases(food.notes);

/// The serving sizes used by **every** matcher for [food].
///
/// Structured [Food.servings] win; legacy rows that still carry them in
/// [Food.notes] are parsed on the fly. The gram bridge
/// (`decideLabelApply`'s `count × serving`) reads this, never `notes` directly.
List<FoodServing> foodServings(Food food) =>
    food.servings.isNotEmpty ? food.servings : parseFoodServings(food.notes);

/// One-time legacy cleanup for the retired 补充说明 field.
///
/// P2 moved aliases/servings out of [Food.notes] but kept the prose for safety;
/// the app no longer shows or edits a 备注 field at all, so this is the single
/// place that migrates a legacy row:
/// * existing structured aliases/servings win; otherwise the prose is parsed;
/// * the legacy 「已停用」 marker becomes [FoodStatus.archived];
/// * [Food.notes] is cleared (the text is dropped, not rewritten).
///
/// Idempotent: a food without notes is returned unchanged. Used by the v9 data
/// migration and by backup import, so restored old backups are cleaned too.
Food migrateLegacyNotes(Food food) {
  final String? raw = food.notes;
  if (raw == null) {
    return food;
  }
  final String notes = raw.trim();
  if (notes.isEmpty) {
    return food.withSupplement(notes: null);
  }
  final List<String> aliases = food.aliases.isNotEmpty
      ? food.aliases
      : parseFoodAliases(notes);
  final List<FoodServing> servings = food.servings.isNotEmpty
      ? food.servings
      : parseFoodServings(notes);
  final FoodStatus status =
      food.status == FoodStatus.active && notes.startsWith('已停用')
      ? FoodStatus.archived
      : food.status;
  return food.withSupplement(
    notes: null,
    aliases: aliases,
    servings: servings,
    status: status,
  );
}

/// Ranks saved foods that plausibly describe [aiItem], best first.
///
/// Matching is deterministic and entirely offline (see [FoodMatchReason] for
/// the precedence). Higher scores mean a better match; [limit] caps the
/// candidate list (at most [limit] entries, `limit <= 0` yields `[]`).
/// Candidates scoring below `0.5` are dropped, and `[]` means "no suggestion,
/// keep the AI values".
///
/// **Non-binding.** This never mutates [aiItem], never writes `foodId` and
/// never resolves nutrients; the caller MUST show the suggestion and wait for
/// an explicit user confirmation before passing a chosen [Food] to
/// [resolveNutrients].
///
/// Foods with [FoodStatus.archived] are skipped before matching: an archived
/// food is retired from suggestions even when its name/alias would match
/// exactly.
List<FoodSuggestion> suggestSavedFood(
  MealItem aiItem,
  List<Food> savedFoods, {
  int limit = 3,
}) {
  final key = normalizeName(aiItem.name);
  if (key.isEmpty || limit <= 0) {
    return const <FoodSuggestion>[];
  }

  final ranked = <FoodSuggestion>[];
  for (final food in savedFoods) {
    if (!food.isMatchable) {
      continue;
    }
    final identity = _bestIdentity(key, food);
    if (identity == null) {
      continue;
    }

    var identityScore = identity.score;
    final brandKey = normalizeName(food.brand ?? '');
    if (brandKey.isNotEmpty && key.contains(brandKey)) {
      identityScore = identityScore + 0.05 > 1.0 ? 1.0 : identityScore + 0.05;
    }

    // An exact name is authoritative: a wrong AI kcal estimate must never
    // demote (or filter out) the label the user actually saved.
    final nutrientFactor = identity.reason == FoodMatchReason.exactName
        ? 1.0
        : _nutrientPlausibilityFactor(aiItem, food);
    final score =
        identityScore * nutrientFactor * _sourceAuthority(food.source);
    if (score < 0.5) {
      continue;
    }

    ranked.add(
      FoodSuggestion(
        food: food,
        score: score,
        reason: identity.reason,
        matchedAlias: identity.matchedAlias,
      ),
    );
  }

  ranked.sort(_compareSuggestions);
  final capped = ranked.length <= limit ? ranked : ranked.sublist(0, limit);
  return List<FoodSuggestion>.unmodifiable(capped);
}

/// The saved foods most relevant to a free-text [query], for grounding an AI
/// prompt with the user's own library.
///
/// This is a **recall-oriented** helper: its threshold is intentionally looser
/// than [suggestSavedFood]'s, and it returns [Food] (not [FoodSuggestion])
/// because it never proposes applying anything.
///
/// * A blank [query] (no usable key after [normalizeName]) yields `[]`.
/// * Archived foods ([FoodStatus.archived]) are skipped before anything else,
///   including the small-catalogue shortcut: they are never recalled.
/// * When the remaining `foods.length <= limit` the whole (small) catalogue is
///   returned, ordered by source priority (label, manual, ai) then normalized
///   name.
/// * Otherwise only foods with a non-zero relevance score are returned,
///   best first: name/alias containment (shorter key at least 2 chars) ranks
///   highest, then bigram similarity, then a brand string appearing in the
///   query; a one-character CJK query falls back to any shared CJK character.
///   Ties break by source priority then normalized name. At most `limit`
///   entries are returned (`limit` is clamped to `>= 1`). Aliases are
///   [Food.aliases], with [Food.notes] parsed for legacy rows ([foodAliases]).
List<Food> rankCatalogueForQuery(
  String query,
  List<Food> foods, {
  int limit = 20,
}) {
  final cappedLimit = limit < 1 ? 1 : limit;
  final key = normalizeName(query);
  if (key.isEmpty) {
    return const <Food>[];
  }

  final ordered = <Food>[
    for (final food in foods)
      if (food.isMatchable) food,
  ]..sort(_compareCatalogueFoods);
  if (ordered.length <= cappedLimit) {
    return List<Food>.unmodifiable(ordered);
  }

  final scored = <(Food, double)>[];
  for (final food in ordered) {
    final score = _relevanceScore(key, food);
    if (score > 0) {
      scored.add((food, score));
    }
  }
  scored.sort(((Food, double) a, (Food, double) b) {
    final byScore = b.$2.compareTo(a.$2);
    if (byScore != 0) {
      return byScore;
    }
    return _compareCatalogueFoods(a.$1, b.$1);
  });

  final top = <Food>[
    for (final (Food food, double _) in scored.take(cappedLimit)) food,
  ];
  return List<Food>.unmodifiable(top);
}

/// Resolves [aiItem]'s nutrients for [grams] from [chosenFood].
///
/// For every [NutrientField]:
/// * non-null (finite, non-negative) per-100 g label value ->
///   `labelPer100g * grams / 100` (energy is rounded to whole kcal with
///   [roundKcal]), provenance [NutrientProvenance.label];
/// * blank label value -> the AI item's value **verbatim** (already scaled to
///   the AI item's own grams), provenance [NutrientProvenance.ai]. A blank
///   label field is never turned into `0`.
///
/// Salt bridges units explicitly: label `sodiumMg` ->
/// `sodiumMgToSaltG(sodiumMg * grams / 100)`, because [MealItem] carries salt
/// grams while [Food] stores sodium milligrams.
///
/// The result is a plain value object: nothing is mutated and no snapshot is
/// taken. The caller stores `foodId` + `grams` on the item and re-calls this
/// function when grams change.
///
/// Throws [ArgumentError] for malformed [grams] (negative/NaN/infinite) and
/// for a malformed AI value that would have to be returned (negative/NaN/
/// infinite) — a broken payload must never silently poison a day total.
ResolvedNutrients resolveNutrients(
  MealItem aiItem,
  Food chosenFood,
  double grams,
) {
  if (!grams.isFinite) {
    throw ArgumentError.value(
      grams,
      'grams',
      'must be a finite number (got NaN or infinity)',
    );
  }
  if (grams < 0) {
    throw ArgumentError.value(grams, 'grams', 'must not be negative');
  }

  final provenance = <NutrientField, NutrientProvenance>{};

  double scale(NutrientField field, double? labelPer100g, double aiValue) {
    if (_isUsable(labelPer100g)) {
      provenance[field] = NutrientProvenance.label;
      return labelPer100g! * grams / 100;
    }
    _requireUsableAiValue(aiValue, field);
    provenance[field] = NutrientProvenance.ai;
    return aiValue;
  }

  // Energy is integer-only: a per-100 g scale keeps its fractional products
  // internally and rounds once, right here.
  int resolveItemKcal() {
    final int? labelPer100g = chosenFood.kcal;
    if (_isUsable(labelPer100g)) {
      provenance[NutrientField.kcal] = NutrientProvenance.label;
      return roundKcal(labelPer100g! * grams / 100);
    }
    _requireUsableAiValue(aiItem.kcal.toDouble(), NutrientField.kcal);
    provenance[NutrientField.kcal] = NutrientProvenance.ai;
    return aiItem.kcal;
  }

  final saltG = _resolveSalt(
    chosenFood.sodiumMg,
    aiItem.saltG,
    grams,
    provenance,
  );

  return ResolvedNutrients(
    kcal: resolveItemKcal(),
    carbG: scale(NutrientField.carbG, chosenFood.carbG, aiItem.carbG),
    proteinG: scale(
      NutrientField.proteinG,
      chosenFood.proteinG,
      aiItem.proteinG,
    ),
    fatG: scale(NutrientField.fatG, chosenFood.fatG, aiItem.fatG),
    saltG: saltG,
    provenance: Map<NutrientField, NutrientProvenance>.unmodifiable(provenance),
  );
}

/// The best match identity for [food] against [itemKey], or `null` when the
/// food is not a candidate at all.
_MatchIdentity? _bestIdentity(String itemKey, Food food) {
  final nameKey = normalizeName(food.name);
  final rawAliases = <String>[];
  final aliasKeys = <String>[];
  for (final raw in foodAliases(food)) {
    final aliasKey = normalizeName(raw);
    if (aliasKey.isEmpty) {
      continue;
    }
    rawAliases.add(raw);
    aliasKeys.add(aliasKey);
  }
  if (nameKey.isEmpty && aliasKeys.isEmpty) {
    return null;
  }

  // 1. Exact normalized name.
  if (nameKey.isNotEmpty && nameKey == itemKey) {
    return const _MatchIdentity(1.0, FoodMatchReason.exactName, null);
  }

  // 2. Exact normalized alias (the first recorded alias wins).
  for (var i = 0; i < aliasKeys.length; i++) {
    if (aliasKeys[i] == itemKey) {
      return _MatchIdentity(0.97, FoodMatchReason.alias, rawAliases[i]);
    }
  }

  // 3. Containment in either direction; the shorter key needs >= 2 chars.
  _MatchIdentity? best;
  var bestRatio = 0.0;
  if (nameKey.isNotEmpty) {
    final ratio = _containmentRatio(itemKey, nameKey);
    if (ratio != null) {
      best = _MatchIdentity(
        0.72 + 0.22 * ratio,
        FoodMatchReason.partialName,
        null,
      );
      bestRatio = ratio;
    }
  }
  for (final aliasKey in aliasKeys) {
    final ratio = _containmentRatio(itemKey, aliasKey);
    if (ratio != null && (best == null || ratio > bestRatio)) {
      best = _MatchIdentity(
        0.72 + 0.22 * ratio,
        FoodMatchReason.partialName,
        null,
      );
      bestRatio = ratio;
    }
  }
  if (best != null) {
    return best;
  }

  // 4. Bigram Dice similarity, only when it is genuinely similar.
  var bestDice = 0.0;
  final keys = <String>[if (nameKey.isNotEmpty) nameKey, ...aliasKeys];
  for (final key in keys) {
    final dice = _diceSimilarity(itemKey, key);
    if (dice > bestDice) {
      bestDice = dice;
    }
  }
  if (bestDice < 0.5) {
    return null;
  }
  return _MatchIdentity(
    0.55 + 0.10 * bestDice,
    FoodMatchReason.similarName,
    null,
  );
}

/// One food's best identity match against the AI item key.
class _MatchIdentity {
  const _MatchIdentity(this.score, this.reason, this.matchedAlias);

  final double score;
  final FoodMatchReason reason;
  final String? matchedAlias;
}

/// `shorter.length / longer.length` when one key contains the other (and the
/// shorter key is at least 2 characters long), else `null`. Equality gives 1.0.
double? _containmentRatio(String a, String b) {
  if (a.isEmpty || b.isEmpty) {
    return null;
  }
  final shorter = a.length <= b.length ? a : b;
  final longer = a.length <= b.length ? b : a;
  if (shorter.length < 2 || !longer.contains(shorter)) {
    return null;
  }
  return shorter.length / longer.length;
}

/// Bigram Dice coefficient over a normalized key (CJK + ASCII bigrams, spaces
/// included so `"milk powder"` and `"powder milk"` are similar).
double _diceSimilarity(String a, String b) {
  final aGrams = _bigrams(a);
  final bGrams = _bigrams(b);
  if (aGrams.isEmpty || bGrams.isEmpty) {
    return 0.0;
  }
  final counts = <String, int>{};
  for (final gram in aGrams) {
    counts[gram] = (counts[gram] ?? 0) + 1;
  }
  var intersection = 0;
  for (final gram in bGrams) {
    final remaining = counts[gram];
    if (remaining != null && remaining > 0) {
      intersection++;
      counts[gram] = remaining - 1;
    }
  }
  return 2 * intersection / (aGrams.length + bGrams.length);
}

List<String> _bigrams(String value) {
  if (value.length < 2) {
    return const <String>[];
  }
  return <String>[
    for (var i = 0; i + 1 < value.length; i++) value.substring(i, i + 2),
  ];
}

/// Nutrient plausibility demotion for non-exact matches: a saved food whose
/// per-100 g kcal is wildly off the AI's implied per-100 g kcal is less likely
/// to be the food the user meant.
double _nutrientPlausibilityFactor(MealItem aiItem, Food food) {
  final grams = aiItem.grams;
  final kcal = aiItem.kcal;
  final foodKcal = food.kcal;
  if (!(grams > 0) || !(kcal > 0) || foodKcal == null || !(foodKcal > 0)) {
    return 1.0;
  }
  final aiPer100g = kcal / grams * 100;
  if (!aiPer100g.isFinite || aiPer100g <= 0) {
    return 1.0;
  }
  final ratio = foodKcal / aiPer100g;
  if (!ratio.isFinite) {
    return 1.0;
  }
  if (ratio >= 0.55 && ratio <= 1.8) {
    return 1.0;
  }
  if (ratio >= 0.3 && ratio <= 3.3) {
    return 0.85;
  }
  return 0.55;
}

/// Relevance score for [rankCatalogueForQuery]; `0` means "not relevant".
double _relevanceScore(String queryKey, Food food) {
  final keys = <String>[
    if (normalizeName(food.name).isNotEmpty) normalizeName(food.name),
  ];
  for (final raw in foodAliases(food)) {
    final aliasKey = normalizeName(raw);
    if (aliasKey.isNotEmpty) {
      keys.add(aliasKey);
    }
  }

  var best = 0.0;
  for (final key in keys) {
    final ratio = _containmentRatio(queryKey, key);
    if (ratio != null) {
      final score = 0.8 + 0.2 * ratio;
      if (score > best) {
        best = score;
      }
      continue;
    }
    final dice = _diceSimilarity(queryKey, key);
    if (dice > 0 && 0.2 + 0.6 * dice > best) {
      best = 0.2 + 0.6 * dice;
    }
  }

  // A one-character CJK query cannot contain/be contained usefully; fall back
  // to any shared CJK character so e.g. "奶" still recalls "牛奶".
  if (queryKey.length == 1 && _isCjkChar(queryKey)) {
    for (final key in keys) {
      if (key.contains(queryKey) && best < 0.5) {
        best = 0.5;
      }
    }
  }

  final brandKey = normalizeName(food.brand ?? '');
  if (brandKey.isNotEmpty && queryKey.contains(brandKey) && best < 0.9) {
    best = 0.9;
  }
  return best;
}

/// True when [value] is a single common CJK ideograph.
bool _isCjkChar(String value) {
  if (value.isEmpty) {
    return false;
  }
  final code = value.codeUnitAt(0);
  return (code >= 0x3400 && code <= 0x4dbf) ||
      (code >= 0x4e00 && code <= 0x9fff);
}

int _compareSuggestions(FoodSuggestion a, FoodSuggestion b) {
  final byScore = b.score.compareTo(a.score);
  if (byScore != 0) {
    return byScore;
  }
  final bySource = _sourceRank(a.food.source)
      .compareTo(_sourceRank(b.food.source));
  if (bySource != 0) {
    return bySource;
  }
  final byName = normalizeName(a.food.name)
      .compareTo(normalizeName(b.food.name));
  if (byName != 0) {
    return byName;
  }
  return a.food.id.compareTo(b.food.id);
}

int _compareCatalogueFoods(Food a, Food b) {
  final bySource = _sourceRank(a.source).compareTo(_sourceRank(b.source));
  if (bySource != 0) {
    return bySource;
  }
  final byName = normalizeName(a.name).compareTo(normalizeName(b.name));
  if (byName != 0) {
    return byName;
  }
  return a.id.compareTo(b.id);
}

/// Source authority order for ranking: label > manual > ai.
int _sourceRank(FoodSource source) {
  return switch (source) {
    FoodSource.label => 0,
    FoodSource.manual => 1,
    FoodSource.ai => 2,
  };
}

/// Multiplicative source-authority factor applied to every suggestion score.
double _sourceAuthority(FoodSource source) {
  return switch (source) {
    FoodSource.label => 1.0,
    FoodSource.manual => 0.98,
    FoodSource.ai => 0.95,
  };
}

/// The sodium mg -> salt g bridge, scaled to [grams].
double _resolveSalt(
  double? sodiumMg,
  double aiSaltG,
  double grams,
  Map<NutrientField, NutrientProvenance> provenance,
) {
  if (_isUsable(sodiumMg)) {
    provenance[NutrientField.saltG] = NutrientProvenance.label;
    return sodiumMgToSaltG(sodiumMg! * grams / 100);
  }
  _requireUsableAiValue(aiSaltG, NutrientField.saltG);
  provenance[NutrientField.saltG] = NutrientProvenance.ai;
  return aiSaltG;
}

/// A label value is usable only when it is a finite, non-negative number;
/// `null` (blank), NaN, infinity and negatives are all treated as blank.
bool _isUsable(num? value) {
  return value != null && value.isFinite && value >= 0;
}

/// A value handed back from the AI must be finite and non-negative.
void _requireUsableAiValue(double value, NutrientField field) {
  if (value.isFinite && value >= 0) {
    return;
  }
  throw ArgumentError.value(
    value,
    field.name,
    'malformed AI fallback value: must be a finite, non-negative number',
  );
}

bool _mapEquals<K, V>(Map<K, V> a, Map<K, V> b) {
  if (a.length != b.length) {
    return false;
  }
  for (final MapEntry<K, V> entry in a.entries) {
    if (!b.containsKey(entry.key) || b[entry.key] != entry.value) {
      return false;
    }
  }
  return true;
}
