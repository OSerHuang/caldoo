/// JSON encoding for the `meal_templates.items_json` column.
///
/// A template's item lines live in one JSON text column instead of a child
/// table: one template is one row, the whole snapshot is written atomically,
/// and a backup/restore is still one JSON object per template. This file is
/// the single place that knows the wire shape (`List<MealItem>` via
/// json_serializable), so the mappers (rows -> models) and the repository
/// (models -> rows) cannot drift apart.
///
/// Decoding is deliberately forgiving, mirroring `food_supplement_codec.dart`:
/// a corrupted value (hand-edited DB, a future format) drops the bad items
/// instead of crashing the list — the template stays usable, and the next edit
/// rewrites the column cleanly.
library;

import 'dart:convert';

import 'package:caldoo/domain/models/models.dart';

/// Encodes [items] for the `meal_templates.items_json` column.
String encodeTemplateItems(List<MealItem> items) {
  return jsonEncode(<Object?>[
    for (final MealItem item in items) item.toJson(),
  ]);
}

/// Decodes the `meal_templates.items_json` column; `null` / malformed -> an
/// empty list, and a single malformed item is dropped, not the whole list.
List<MealItem> decodeTemplateItems(String? raw) {
  if (raw == null || raw.trim().isEmpty) {
    return const <MealItem>[];
  }
  try {
    final Object? decoded = jsonDecode(raw);
    if (decoded is! List<Object?>) {
      return const <MealItem>[];
    }
    return List<MealItem>.unmodifiable(<MealItem>[
      for (final Object? item in decoded)
        if (_decodeItem(item) case final MealItem mealItem) mealItem,
    ]);
  } on FormatException {
    return const <MealItem>[];
  }
}

MealItem? _decodeItem(Object? item) {
  if (item is! Map<String, dynamic>) {
    return null;
  }
  try {
    return MealItem.fromJson(item);
  } on Object {
    return null;
  }
}
