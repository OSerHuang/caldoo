/// Wire model + strict tool schema for the GB 28050-2025 nutrition label(s) in
/// one photo.
///
/// Same mechanism as [MealAnalysis]: the model is given the strict tool
/// [labelParseToolName] with [labelParseToolParameters] and answers with a JSON
/// object string that [LabelParse.fromToolArguments] validates and maps.
///
/// A single photo can contain **more than one** 营养成分表 (the front and back
/// of one package, or several products side by side), so the payload is a
/// `labels` array with one item per label. Each item carries the GB 28050 field
/// set — energy (kJ), protein, fat, saturated fat, carbohydrate, sugar and
/// sodium, plus the NRV% column — normalised to per 100 g / 100 mL, and an
/// optional `food_name` / `brand` the model read off the packaging. The name is
/// requested in the system language (Chinese, brand stripped) and the optional
/// `name_aliases` array carries the source-language original and other aliases.
/// A label photo frequently shows the packaging around the table; inferring the
/// product there is exactly what saves the user from typing the name.
library;

import 'package:json_annotation/json_annotation.dart';
import 'package:json_schema/json_schema.dart';

import '../../core/units/nutrition_units.dart';
import 'strict_json.dart';

part 'label_parse.g.dart';

/// Name of the strict tool that carries the label schema.
///
/// The plural id is deliberate: the schema returns one entry per label found in
/// the photo, not one label per call.
const String labelParseToolName = 'emit_nutrition_labels';

/// The seven GB 28050-2025 mandatory declarations, in printed order.
///
/// Exported so the prompt test can assert the prompt names exactly these keys.
const List<String> labelParseRequiredFields = <String>[
  'energy_kj',
  'protein_g',
  'fat_g',
  'saturated_fat_g',
  'carbohydrate_g',
  'sugar_g',
  'sodium_mg',
];

/// The seven optional NRV% cells, in printed order.
const List<String> labelParseNrvFields = <String>[
  'nrv_energy',
  'nrv_protein',
  'nrv_fat',
  'nrv_saturated_fat',
  'nrv_carbohydrate',
  'nrv_sugar',
  'nrv_sodium',
];

/// Upper bound on labels accepted from one photo.
///
/// A photo with more than eight distinct nutrition tables is almost certainly a
/// mis-parse (or a payload trying to blow up the review form), so the schema
/// refuses it rather than rendering an unbounded form.
const int labelParseMaxLabels = 8;

/// `required` for one label item: the GB 28050 mandatory declarations.
///
/// `food_name`, `brand` and the `nrv_*` cells stay optional: a label photo may
/// show only the table (no packaging text), and a partially legible table may
/// not yield the NRV% column. Task 21 leaves unread fields blank rather than
/// guessing.
const List<String> _itemRequired = labelParseRequiredFields;

/// JSON Schema of the strict tool's `function.parameters`.
///
/// `additionalProperties: false` at every object level, every non-optional
/// field listed in `required`, and every nutrient `minimum: 0`.
const Map<String, Object?> labelParseToolParameters = <String, Object?>{
  'type': 'object',
  'additionalProperties': false,
  'required': <String>['labels'],
  'properties': <String, Object?>{
    'labels': <String, Object?>{
      'type': 'array',
      'minItems': 1,
      'maxItems': labelParseMaxLabels,
      'items': <String, Object?>{
        'type': 'object',
        'additionalProperties': false,
        'required': _itemRequired,
        'properties': <String, Object?>{
          'food_name': <String, Object?>{
            'type': <String>['string', 'null'],
            'minLength': 1,
          },
          'brand': <String, Object?>{
            'type': <String>['string', 'null'],
            'minLength': 1,
          },
          'name_aliases': <String, Object?>{
            'type': 'array',
            'maxItems': 6,
            'items': <String, Object?>{'type': 'string', 'minLength': 1},
          },
          'energy_kj': _nutrient,
          'protein_g': _nutrient,
          'fat_g': _nutrient,
          'saturated_fat_g': _nutrient,
          'carbohydrate_g': _nutrient,
          'sugar_g': _nutrient,
          'sodium_mg': _nutrient,
          'nrv_energy': _nrv,
          'nrv_protein': _nrv,
          'nrv_fat': _nrv,
          'nrv_saturated_fat': _nrv,
          'nrv_carbohydrate': _nrv,
          'nrv_sugar': _nrv,
          'nrv_sodium': _nrv,
        },
      },
    },
  },
};

/// One mandatory nutrient cell: a non-negative number.
const Map<String, Object?> _nutrient = <String, Object?>{
  'type': 'number',
  'minimum': 0,
};

/// NRV% cell: optional, nullable, never negative.
const Map<String, Object?> _nrv = <String, Object?>{
  'type': <String>['number', 'null'],
  'minimum': 0,
};

/// The complete `tools[0]` entry for the label-parse call.
Map<String, Object?> labelParseTool() => <String, Object?>{
  'type': 'function',
  'function': <String, Object?>{
    'name': labelParseToolName,
    'strict': true,
    'parameters': labelParseToolParameters,
  },
};

/// Validator built from the same authored schema, minus `additionalProperties`.
final JsonSchema _labelParseSchema = JsonSchema.create(
  lenientSchema(labelParseToolParameters),
);

/// One nutrition label parsed into typed values (all per 100 g / 100 mL).
///
/// [foodName] and [brand] are the model's reading of the packaging; both are
/// `null` when the photo shows no usable product text. They are **suggestions**
/// — the confirm form always lets the user edit them, and a blank name blocks
/// saving rather than inventing one.
@JsonSerializable(explicitToJson: true, checked: true)
class LabelParseItem {
  const LabelParseItem({
    required this.energyKj,
    required this.proteinG,
    required this.fatG,
    required this.saturatedFatG,
    required this.carbohydrateG,
    required this.sugarG,
    required this.sodiumMg,
    this.foodName,
    this.brand,
    this.nameAliases = const <String>[],
    this.nrvEnergy,
    this.nrvProtein,
    this.nrvFat,
    this.nrvSaturatedFat,
    this.nrvCarbohydrate,
    this.nrvSugar,
    this.nrvSodium,
  });

  factory LabelParseItem.fromJson(Map<String, dynamic> json) =>
      _$LabelParseItemFromJson(json);

  /// Product name read or inferred from the packaging — **in the system
  /// language (Chinese)** and never carrying the brand — or `null` when the
  /// photo only shows the nutrition table.
  @JsonKey(name: 'food_name')
  final String? foodName;

  /// Brand name read from the packaging, or `null` when not visible.
  final String? brand;

  /// Other names of the food, as returned by the model: the source-language
  /// original of a translated name (a foreign label's printed name verbatim),
  /// variant scripts and obvious common aliases. Empty when the model supplied
  /// none (the field is optional in the schema).
  @JsonKey(name: 'name_aliases', defaultValue: <String>[])
  final List<String> nameAliases;

  /// Energy in kilojoules, exactly as printed on the label.
  @JsonKey(name: 'energy_kj')
  final double energyKj;

  /// Protein in grams per 100 g / 100 mL.
  @JsonKey(name: 'protein_g')
  final double proteinG;

  /// Fat in grams per 100 g / 100 mL.
  @JsonKey(name: 'fat_g')
  final double fatG;

  /// Saturated fat in grams per 100 g / 100 mL (GB 28050-2025 mandatory).
  @JsonKey(name: 'saturated_fat_g')
  final double saturatedFatG;

  /// Carbohydrate in grams per 100 g / 100 mL.
  @JsonKey(name: 'carbohydrate_g')
  final double carbohydrateG;

  /// Sugar in grams per 100 g / 100 mL (GB 28050-2025 mandatory).
  @JsonKey(name: 'sugar_g')
  final double sugarG;

  /// Sodium in milligrams per 100 g / 100 mL.
  @JsonKey(name: 'sodium_mg')
  final double sodiumMg;

  /// NRV% of energy, when the label (or the model) provided it.
  @JsonKey(name: 'nrv_energy')
  final double? nrvEnergy;

  /// NRV% of protein, when provided.
  @JsonKey(name: 'nrv_protein')
  final double? nrvProtein;

  /// NRV% of fat, when provided.
  @JsonKey(name: 'nrv_fat')
  final double? nrvFat;

  /// NRV% of saturated fat, when provided.
  @JsonKey(name: 'nrv_saturated_fat')
  final double? nrvSaturatedFat;

  /// NRV% of carbohydrate, when provided.
  @JsonKey(name: 'nrv_carbohydrate')
  final double? nrvCarbohydrate;

  /// NRV% of sugar, when provided.
  @JsonKey(name: 'nrv_sugar')
  final double? nrvSugar;

  /// NRV% of sodium, when provided.
  @JsonKey(name: 'nrv_sodium')
  final double? nrvSodium;

  /// [energyKj] in the app's canonical **whole** kcal, via the single canonical
  /// conversion (1 kcal = 4.184 kJ, rounded to the nearest integer).
  int get energyKcal => kJToKcal(energyKj);

  Map<String, dynamic> toJson() => _$LabelParseItemToJson(this);
}

/// The validated result of one label-parse tool call: every label in the photo.
@JsonSerializable(explicitToJson: true, checked: true)
class LabelParse {
  const LabelParse({required this.labels});

  factory LabelParse.fromJson(Map<String, dynamic> json) =>
      _$LabelParseFromJson(json);

  /// Validates one strict tool call's `arguments` string and maps it.
  ///
  /// Unknown keys (top-level or per label) are ignored and reported to
  /// [onIgnoredKey]; a payload whose `labels` array is empty, missing, or whose
  /// item misses a required GB 28050 field (e.g. `sodium_mg`) throws
  /// [AiError.MalformedResponse] and no partial object is produced.
  factory LabelParse.fromToolArguments(
    String argumentsJson, {
    IgnoredKeySink onIgnoredKey = debugLogIgnoredKey,
  }) {
    final Map<String, dynamic> data = decodeToolArguments(
      argumentsJson,
      'LabelParse',
    );
    validateToolArguments(data, _labelParseSchema, 'LabelParse');
    rejectNonFiniteNumbers(data, 'LabelParse');
    reportUnknownKeys(data, labelParseToolParameters, '', onIgnoredKey);
    return LabelParse.fromJson(data);
  }

  /// One entry per label found in the photo; the schema guarantees at least one.
  final List<LabelParseItem> labels;

  /// The single label's item, or `null` when the photo contained more than one.
  ///
  /// Convenience for callers that only handle the common one-label case (the
  /// integration test asserts the recorded single-label fixture).
  LabelParseItem? get singleLabel => labels.length == 1 ? labels.single : null;

  Map<String, dynamic> toJson() => _$LabelParseToJson(this);
}
