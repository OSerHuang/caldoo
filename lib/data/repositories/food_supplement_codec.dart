/// JSON encoding for the structured supplement columns on `foods`.
///
/// `alias`/`serving` are lists, so drift stores them as a JSON string in a
/// nullable text column instead of a child table: one row stays one row, the
/// whole food is written atomically, and a backup/restore is still one JSON
/// object per food. This file is the single place that knows the wire shape, so
/// the mappers (rows -> models) and the repository (models -> rows) cannot
/// drift apart.
///
/// Decoding is deliberately forgiving: a corrupted value (hand-edited DB, a
/// future format) yields an empty list instead of crashing the catalogue — the
/// food is still usable through its name/notes, and the next edit rewrites the
/// column cleanly.
library;

import 'dart:convert';

import 'package:caldoo/domain/models/models.dart';

/// Encodes [aliases] for the `foods.aliases` column; empty -> SQL `NULL`.
String? encodeAliases(List<String> aliases) {
  if (aliases.isEmpty) {
    return null;
  }
  return jsonEncode(aliases);
}

/// Decodes the `foods.aliases` column; `null` / malformed -> empty list.
List<String> decodeAliases(String? raw) {
  if (raw == null || raw.trim().isEmpty) {
    return const <String>[];
  }
  try {
    final Object? decoded = jsonDecode(raw);
    if (decoded is! List<Object?>) {
      return const <String>[];
    }
    return List<String>.unmodifiable(<String>[
      for (final Object? item in decoded)
        if (item is String && item.trim().isNotEmpty) item.trim(),
    ]);
  } on FormatException {
    return const <String>[];
  }
}

/// Encodes [servings] for the `foods.servings` column; empty -> SQL `NULL`.
String? encodeServings(List<FoodServing> servings) {
  if (servings.isEmpty) {
    return null;
  }
  return jsonEncode(<Object?>[
    for (final FoodServing serving in servings) serving.toJson(),
  ]);
}

/// Decodes the `foods.servings` column; `null` / malformed -> empty list.
///
/// A single malformed row is dropped, not the whole list: one bad serving must
/// not hide the other (good) ones from the matcher.
List<FoodServing> decodeServings(String? raw) {
  if (raw == null || raw.trim().isEmpty) {
    return const <FoodServing>[];
  }
  try {
    final Object? decoded = jsonDecode(raw);
    if (decoded is! List<Object?>) {
      return const <FoodServing>[];
    }
    return List<FoodServing>.unmodifiable(<FoodServing>[
      for (final Object? item in decoded)
        if (_decodeServing(item) case final FoodServing serving) serving,
    ]);
  } on FormatException {
    return const <FoodServing>[];
  }
}

FoodServing? _decodeServing(Object? item) {
  if (item is! Map<String, dynamic>) {
    return null;
  }
  try {
    final FoodServing serving = FoodServing.fromJson(item);
    if (serving.label.trim().isEmpty ||
        !serving.amount.isFinite ||
        serving.amount <= 0 ||
        (serving.unit != 'g' && serving.unit != 'ml')) {
      return null;
    }
    return serving;
  } on Object {
    return null;
  }
}
