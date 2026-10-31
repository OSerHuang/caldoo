/// Wire model + strict tool schema for the label-link call (design
/// `design/label-linking.md` §4).
///
/// Meal analysis (`emit_meal_items`) and saved-food matching used to share one
/// call: the analysis prompt carried the user's library as a hint and the
/// review screen later "confirmed" it with a lexical matcher. Chinese product
/// names (brand, flavour, parenthetical suffix) made both paths unreliable, and
/// a hint error was even confirmed twice.
///
/// Link is the single place where matching happens: a **pure text** call whose
/// input is the analysed items + the user's own words + a rendered label index
/// ([renderLabelIndex] in `lib/domain/services/label_linking.dart`), and whose
/// output is a **checkable index number**, never free text. This file owns the
/// wire contract:
///
/// * [labelLinkToolName] / [labelLinkToolParameters] — the strict tool the model
///   answers through (DeepSeek rejects `response_format: json_schema`, so a
///   strict tool call is the only way to get schema-enforced JSON — task 1);
/// * [LabelMatch] — one candidate row: which item, which library index, and
///   optionally how many servings of which recorded serving;
/// * [LabelLinkResult.fromToolArguments] — the four-step strict decode/validate
///   pipeline from `strict_json.dart` (decode → validate → non-finite →
///   unknown-key report), exactly like `MealAnalysis` and `LabelParse`.
///
/// The result is **raw**: index bounds, duplicate rows, the per-item candidate
/// cap and the serving-label check are all validated in the domain layer
/// (`normalizeLabelMatches`), so the same rules are testable without any AI
/// payload and a malformed match degrades to "no candidate" instead of failing
/// the whole meal.
///
/// Every object level is closed with `additionalProperties: false` and lists
/// all its properties in `required` (nullable fields are `type: [..., null]`):
/// the strict-mode contract the provider enforces.
library;

import 'package:json_schema/json_schema.dart';

import '../ai_client.dart' show MalformedResponse;
import 'strict_json.dart';

/// Name of the strict tool that carries the label-link schema.
const String labelLinkToolName = 'emit_label_matches';

/// Upper bound on candidate rows one call may return (§4.3: `maxItems: 30`).
///
/// A meal rarely exceeds ten items and each item may have at most
/// [labelLinkMaxCandidatesPerItem] candidates, so 30 rows is generous; the cap
/// keeps a runaway model from flooding the review screen.
const int labelLinkMaxMatches = 30;

/// Maximum candidates accepted per analysed item (`normalizeLabelMatches`).
///
/// Kept here next to the schema so the prompt, the normaliser and the tests
/// cannot drift apart: §4.4 allows at most three candidates per item, ordered
/// by likelihood (top-1 is the only one auto-apply ever looks at).
const int labelLinkMaxCandidatesPerItem = 3;

/// JSON Schema of the strict tool's `function.parameters` (§4.3).
///
/// One row per candidate, so the same `item_index` may repeat (that is how the
/// model ranks alternatives). Everything is required because strict mode
/// demands it — the two optional facts are expressed as nullable (`count`,
/// `serving_label`) instead of absent.
///
/// `count` cannot use `exclusiveMinimum: 0` (the strict contract used here
/// sticks to the keywords the provider verifies), so the schema accepts `0` and
/// the domain layer turns a non-positive count into `null`. The same split
/// applies to `serving_label`: the schema only checks it is a string, the
/// domain layer checks it is one of the food's recorded serving labels.
const Map<String, Object?> labelLinkToolParameters = <String, Object?>{
  'type': 'object',
  'additionalProperties': false,
  'required': <String>['matches'],
  'properties': <String, Object?>{
    'matches': <String, Object?>{
      'type': 'array',
      'minItems': 0,
      'maxItems': labelLinkMaxMatches,
      'items': <String, Object?>{
        'type': 'object',
        'additionalProperties': false,
        'required': <String>[
          'item_index',
          'food_index',
          'count',
          'serving_label',
        ],
        'properties': <String, Object?>{
          'item_index': <String, Object?>{'type': 'integer', 'minimum': 0},
          'food_index': <String, Object?>{'type': 'integer', 'minimum': 0},
          'count': <String, Object?>{
            'type': <String>['number', 'null'],
            'minimum': 0,
          },
          'serving_label': <String, Object?>{
            'type': <String>['string', 'null'],
          },
        },
      },
    },
  },
};

/// The complete `tools[0]` entry for the label-link call.
///
/// `AiClient.completeWithTool` takes [labelLinkToolName] and
/// [labelLinkToolParameters] separately and hard-codes `strict: true`; this map
/// exists for raw requests (and for tests asserting the strict flag is really
/// there), mirroring `mealAnalysisTool()`.
Map<String, Object?> labelLinkTool() => <String, Object?>{
  'type': 'function',
  'function': <String, Object?>{
    'name': labelLinkToolName,
    'strict': true,
    'parameters': labelLinkToolParameters,
  },
};

/// Validator built from the same authored schema, minus `additionalProperties`.
///
/// The copy sent to the model forbids extras so the provider cannot drift; the
/// local copy tolerates one unknown key and reports it instead of rejecting an
/// otherwise usable match list (the `strict_json.dart` contract).
final JsonSchema _labelLinkSchema = JsonSchema.create(
  lenientSchema(labelLinkToolParameters),
);

/// One candidate match: item `itemIndex` (0-based analysis order) may be the
/// saved food at `foodIndex` (0-based label-index order).
///
/// [count] and [servingLabel] describe a package/piece count, e.g. the user
/// wrote 「一袋辛拉面」 and the model returned `count: 1` + `servingLabel: 一包`.
/// Both are `null` when the user did not describe the food by package or piece;
/// the normaliser rejects a count/serving pair that does not line up with the
/// food's recorded servings, and `decideLabelApply` only derives grams when
/// both survive.
class LabelMatch {
  const LabelMatch({
    required this.itemIndex,
    required this.foodIndex,
    this.count,
    this.servingLabel,
  });

  /// 0-based index into the analysed item list sent with the prompt.
  final int itemIndex;

  /// 0-based index into the `List<Food>` rendered by `renderLabelIndex`.
  final int foodIndex;

  /// Number of servings/items the user described, or `null`.
  ///
  /// May be fractional (「半盒」 → `0.5`). The schema allows `0`; the domain
  /// layer treats any non-positive or non-finite count as absent.
  final double? count;

  /// The food's serving label the count refers to (`一包`, `一块`), verbatim
  /// from the rendered index, or `null`.
  ///
  /// The domain layer matches it against the food's structured servings
  /// (`foodServings(food)`: `Food.servings`, or legacy `Food.notes`) after
  /// whitespace folding; an unknown label is treated as absent.
  final String? servingLabel;

  /// Serializes in the tool-schema shape, so a candidate can be logged or
  /// compared before anything is applied.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'item_index': itemIndex,
    'food_index': foodIndex,
    'count': count,
    'serving_label': servingLabel,
  };

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is LabelMatch &&
            other.itemIndex == itemIndex &&
            other.foodIndex == foodIndex &&
            other.count == count &&
            other.servingLabel == servingLabel;
  }

  @override
  int get hashCode => Object.hash(itemIndex, foodIndex, count, servingLabel);

  @override
  String toString() =>
      'LabelMatch(item: $itemIndex, food: $foodIndex, '
      'count: $count, serving: $servingLabel)';
}

/// The validated result of one label-link tool call: the raw candidate rows.
///
/// Construct instances through [fromToolArguments] in production; that is the
/// only entry point that enforces the schema. An empty [matches] list is a
/// legal answer ("nothing in the library matches") and must be treated as
/// success-with-no-suggestions, not as a failure (§4.6).
class LabelLinkResult {
  const LabelLinkResult({required this.matches});

  /// Validates one strict tool call's `arguments` string and maps it.
  ///
  /// [argumentsJson] is `tool_calls[0].function.arguments` exactly as
  /// `AiClient.completeWithTool` returned it (never the whole chat-completion
  /// body). Unknown keys are ignored and reported to [onIgnoredKey]; anything
  /// else that fails the schema throws [MalformedResponse] and no partial
  /// object is produced (the link layer catches it and degrades silently, §4.6).
  ///
  /// The rows are returned **raw**: bounds, duplicates and the per-item cap are
  /// enforced by `normalizeLabelMatches`, not here. The only cleanup done here
  /// is representation-only: indices become `int`, a non-finite count is
  /// rejected outright (it would poison every derived gram figure), and the
  /// serving label is folded onto one line (the value is displayed in the
  /// review UI and compared against single-line serving labels).
  factory LabelLinkResult.fromToolArguments(
    String argumentsJson, {
    IgnoredKeySink onIgnoredKey = debugLogIgnoredKey,
  }) {
    final Map<String, dynamic> data = decodeToolArguments(
      argumentsJson,
      'LabelLinkResult',
    );
    validateToolArguments(data, _labelLinkSchema, 'LabelLinkResult');
    rejectNonFiniteNumbers(data, 'LabelLinkResult');
    reportUnknownKeys(data, labelLinkToolParameters, '', onIgnoredKey);
    final Object? rawMatches = data['matches'];
    if (rawMatches is! List<dynamic>) {
      throw const MalformedResponse('LabelLinkResult: matches is not an array');
    }
    final List<LabelMatch> matches = <LabelMatch>[
      for (int i = 0; i < rawMatches.length; i++)
        _matchFromJson(rawMatches[i], i),
    ];
    return LabelLinkResult(matches: List<LabelMatch>.unmodifiable(matches));
  }

  /// Candidate rows in the order the model returned them (best first per item).
  final List<LabelMatch> matches;

  /// `true` when the model found no corresponding library entry at all.
  bool get isEmpty => matches.isEmpty;

  /// Serializes in the tool-schema shape.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'matches': <Map<String, dynamic>>[
      for (final LabelMatch match in matches) match.toJson(),
    ],
  };

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! LabelLinkResult || other.matches.length != matches.length) {
      return false;
    }
    for (int i = 0; i < matches.length; i++) {
      if (other.matches[i] != matches[i]) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(matches);

  @override
  String toString() => 'LabelLinkResult(matches: $matches)';
}

/// Maps one schema-validated match row.
///
/// The schema round has already established the types; the casts are still
/// checked explicitly (with [MalformedResponse] on a surprise) so a lenient
/// decode can never throw a raw `TypeError` out of the AI layer.
LabelMatch _matchFromJson(Object? raw, int index) {
  if (raw is! Map<String, dynamic>) {
    throw MalformedResponse(
      'LabelLinkResult: matches[$index] is not an object',
    );
  }
  final int itemIndex = _indexValue(
    raw['item_index'],
    'matches[$index].item_index',
  );
  final int foodIndex = _indexValue(
    raw['food_index'],
    'matches[$index].food_index',
  );

  final Object? rawCount = raw['count'];
  double? count;
  if (rawCount != null) {
    if (rawCount is! num) {
      throw MalformedResponse(
        'LabelLinkResult: matches[$index].count is not a number',
      );
    }
    count = rawCount.toDouble();
    if (!count.isFinite) {
      // JSON has no "finite" keyword; `1e999` decodes to infinity. The
      // four-step pipeline already rejects it at the payload level, this is
      // the defensive local check for a manually constructed instance.
      throw MalformedResponse(
        'LabelLinkResult: matches[$index].count is not finite',
      );
    }
  }

  final Object? rawServingLabel = raw['serving_label'];
  String? servingLabel;
  if (rawServingLabel != null) {
    if (rawServingLabel is! String) {
      throw MalformedResponse(
        'LabelLinkResult: matches[$index].serving_label is not a string',
      );
    }
    final String folded = rawServingLabel
        .replaceAll(_whitespaceRun, ' ')
        .trim();
    servingLabel = folded.isEmpty ? null : folded;
  }

  return LabelMatch(
    itemIndex: itemIndex,
    foodIndex: foodIndex,
    count: count,
    servingLabel: servingLabel,
  );
}

/// Reads a non-negative integer that JSON may have decoded as `1.0`.
int _indexValue(Object? value, String path) {
  if (value is int) {
    return value;
  }
  if (value is num && value.isFinite && value == value.roundToDouble()) {
    return value.toInt();
  }
  throw MalformedResponse('LabelLinkResult: $path is not an integer');
}

/// Any whitespace run (newlines included) folded to one space.
final RegExp _whitespaceRun = RegExp(r'\s+');
