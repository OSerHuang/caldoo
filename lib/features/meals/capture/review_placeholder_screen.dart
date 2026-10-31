/// Placeholder for the AI review/edit screen.
///
/// Task 18 (capture) owns only the submit pipeline; task 19 owns the real
/// editable review screen. Until then the capture flow routes a validated
/// [MealAnalysis] draft here so the navigation contract is real and testable,
/// and the parsed items are visible instead of being silently dropped.
///
/// This screen is intentionally read-only: no save action, no editing — the
/// plan forbids persisting AI values without passing through task 19's
/// editable draft.
library;

import 'package:flutter/material.dart';

import 'package:caldoo/ai/schemas/meal_analysis.dart';
import 'package:caldoo/l10n/app_strings.dart';

class MealReviewPlaceholderScreen extends StatelessWidget {
  const MealReviewPlaceholderScreen({super.key, required this.draft});

  /// The schema-validated AI draft the capture screen submitted.
  final MealAnalysis draft;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(S.of(context).reviewPlaceholderTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Text(
            S.of(context).reviewAiBanner,
            key: const Key('review_placeholder_banner'),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(S.of(context).reviewPlaceholderBody),
          const Divider(height: 32),
          for (final MealAnalysisItem item in draft.items)
            ListTile(
              key: Key('review_placeholder_item_${item.name}'),
              title: Text(item.name),
              subtitle: Text(
                S
                    .of(context)
                    .reviewPlaceholderItemLine(
                      grams: item.grams.toStringAsFixed(0),
                      kcal: item.kcal.toString(),
                      carb: item.carbG.toStringAsFixed(1),
                      protein: item.proteinG.toStringAsFixed(1),
                      fat: item.fatG.toStringAsFixed(1),
                      salt: item.saltG.toStringAsFixed(2),
                    ),
              ),
              trailing: item.confidence == null
                  ? null
                  : Text(
                      S
                          .of(context)
                          .confidenceLabel(item.confidence!.toStringAsFixed(2)),
                    ),
            ),
        ],
      ),
    );
  }
}
