/// Wire model + strict tool schema for the AI meal analysis.
///
/// The model never sees `response_format: json_schema` (DeepSeek rejects it
/// with HTTP 400, task 1); it is given the strict tool [mealAnalysisToolName]
/// with [mealAnalysisToolParameters] and answers with a JSON object string
/// that [MealAnalysis.fromToolArguments] validates and maps.
library;

import 'package:json_annotation/json_annotation.dart';
import 'package:json_schema/json_schema.dart';

import '../../core/units/nutrition_units.dart';
import 'strict_json.dart';

part 'meal_analysis.g.dart';

/// Name of the strict tool that carries the meal-analysis schema.
///
/// Same id the task-1 spike and fixtures used (`emit_meal_items`), so the
/// recorded fixtures stay replayable against the production parser.
const String mealAnalysisToolName = 'emit_meal_items';

/// JSON Schema of the strict tool's `function.parameters`.
///
/// Strictness contract:
/// * `additionalProperties: false` at every object level, and
/// * every non-optional field listed in `required`.
///
/// `confidence` is deliberately NOT required and is nullable: the model may
/// omit it (the plan forbids making it required), and a missing value must map
/// to `null`, not fail the meal.
///
/// Every numeric field is `minimum: 0`: a negative mass or energy is never a
/// usable estimate and is rejected as a malformed response.
const Map<String, Object?> mealAnalysisToolParameters = <String, Object?>{
  'type': 'object',
  'additionalProperties': false,
  'required': <String>['items'],
  'properties': <String, Object?>{
    'items': <String, Object?>{
      'type': 'array',
      'minItems': 1,
      'items': <String, Object?>{
        'type': 'object',
        'additionalProperties': false,
        'required': <String>[
          'name',
          'grams',
          'kcal',
          'carb_g',
          'protein_g',
          'fat_g',
          'salt_g',
        ],
        'properties': <String, Object?>{
          'name': <String, Object?>{'type': 'string', 'minLength': 1},
          'grams': <String, Object?>{'type': 'number', 'minimum': 0},
          // The model is asked for whole kcal (the app's integer energy
          // contract); the schema still accepts a number so a fractional
          // estimate is rounded by [MealAnalysisItem.kcal]'s parser instead of
          // failing the whole meal.
          'kcal': <String, Object?>{'type': 'number', 'minimum': 0},
          'carb_g': <String, Object?>{'type': 'number', 'minimum': 0},
          'protein_g': <String, Object?>{'type': 'number', 'minimum': 0},
          'fat_g': <String, Object?>{'type': 'number', 'minimum': 0},
          'salt_g': <String, Object?>{'type': 'number', 'minimum': 0},
          'confidence': <String, Object?>{
            'type': <String>['number', 'null'],
            'minimum': 0,
            'maximum': 1,
          },
        },
      },
    },
  },
};

/// The complete `tools[0]` entry for the meal-analysis call.
///
/// `AiClient.completeWithTool` takes [mealAnalysisToolName] and
/// [mealAnalysisToolParameters] separately and already hard-codes
/// `strict: true`; this map exists for raw requests (and for tests asserting
/// the strict flag is really there).
Map<String, Object?> mealAnalysisTool() => <String, Object?>{
  'type': 'function',
  'function': <String, Object?>{
    'name': mealAnalysisToolName,
    'strict': true,
    'parameters': mealAnalysisToolParameters,
  },
};

/// Validator built from the same authored schema, minus `additionalProperties`.
final JsonSchema _mealAnalysisSchema = JsonSchema.create(
  lenientSchema(mealAnalysisToolParameters),
);

/// One analysed food item, already in the app's canonical units (whole kcal,
/// g).
@JsonSerializable(explicitToJson: true, checked: true)
class MealAnalysisItem {
  const MealAnalysisItem({
    required this.name,
    required this.grams,
    required this.kcal,
    required this.carbG,
    required this.proteinG,
    required this.fatG,
    required this.saltG,
    this.confidence,
  });

  factory MealAnalysisItem.fromJson(Map<String, dynamic> json) =>
      _$MealAnalysisItemFromJson(json);

  /// Food name in the language the user wrote/spoke (zh-CN in practice).
  final String name;

  /// Estimated consumed weight in grams.
  final double grams;

  /// Estimated energy in **whole kcal** (the app's integer energy unit).
  ///
  /// A fractional estimate is rounded once here by [kcalFromJson]; the rest of
  /// the app only ever sees an `int`.
  @JsonKey(fromJson: kcalFromJson)
  final int kcal;

  /// Estimated carbohydrate in grams.
  @JsonKey(name: 'carb_g')
  final double carbG;

  /// Estimated protein in grams.
  @JsonKey(name: 'protein_g')
  final double proteinG;

  /// Estimated fat in grams.
  @JsonKey(name: 'fat_g')
  final double fatG;

  /// Estimated salt in grams (the display unit the AI is asked for).
  @JsonKey(name: 'salt_g')
  final double saltG;

  /// Model self-reported confidence in `[0, 1]`, or `null` when omitted.
  final double? confidence;

  Map<String, dynamic> toJson() => _$MealAnalysisItemToJson(this);
}

/// The validated result of one meal-analysis tool call.
///
/// Construct instances through [fromToolArguments] in production: that is the
/// only entry point that enforces the schema. [fromJson] is generated for
/// round-tripping an already-validated payload.
@JsonSerializable(explicitToJson: true, checked: true)
class MealAnalysis {
  const MealAnalysis({required this.items});

  factory MealAnalysis.fromJson(Map<String, dynamic> json) =>
      _$MealAnalysisFromJson(json);

  /// Validates one strict tool call's `arguments` string and maps it.
  ///
  /// [argumentsJson] is `tool_calls[0].function.arguments` exactly as
  /// `AiClient.completeWithTool` returned it (never the whole chat-completion
  /// body). Unknown keys are ignored and reported to [onIgnoredKey]; anything
  /// else that fails the schema throws [AiError.MalformedResponse] and no
  /// partial object is produced.
  factory MealAnalysis.fromToolArguments(
    String argumentsJson, {
    IgnoredKeySink onIgnoredKey = debugLogIgnoredKey,
  }) {
    final Map<String, dynamic> data = decodeToolArguments(
      argumentsJson,
      'MealAnalysis',
    );
    validateToolArguments(data, _mealAnalysisSchema, 'MealAnalysis');
    rejectNonFiniteNumbers(data, 'MealAnalysis');
    reportUnknownKeys(data, mealAnalysisToolParameters, '', onIgnoredKey);
    return MealAnalysis.fromJson(data);
  }

  /// Analysed items; the schema guarantees at least one.
  final List<MealAnalysisItem> items;

  Map<String, dynamic> toJson() => _$MealAnalysisToJson(this);
}
