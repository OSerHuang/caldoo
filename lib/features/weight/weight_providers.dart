/// Riverpod wiring + pure projections for the weight-history feature.
///
/// Widgets watch [weightEntriesProvider] (a live stream over the
/// `WeightRepository` port) and project it with the pure helpers below, so the
/// "latest / 7-day / total" stats are one testable place rather than widget
/// arithmetic. Tests override the port with the in-memory fake.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:caldoo/core/providers/app_providers.dart';
import 'package:caldoo/domain/models/weight_entry.dart';

/// Every recorded weight, ordered by day, live from the repository.
final weightEntriesProvider = StreamProvider<List<WeightEntry>>((ref) {
  return ref.watch(weightRepositoryProvider).watchAll();
});

/// The most recent entry, or `null` when nothing was ever recorded.
WeightEntry? latestWeightOf(List<WeightEntry> entries) =>
    entries.isEmpty ? null : entries.last;

/// The entries within the last [days] days ending at [todayKey] (inclusive).
///
/// Entries are ascending day keys; the window is a closed date range
/// `[todayKey - (days - 1), todayKey]`, so "近30天" is 30 calendar days.
List<WeightEntry> entriesWithinDays(
  List<WeightEntry> entries,
  DateTime todayKey,
  int days,
) {
  final DateTime first = todayKey.subtract(Duration(days: days - 1));
  return <WeightEntry>[
    for (final WeightEntry entry in entries)
      if (!entry.dayKey.isBefore(first) && !entry.dayKey.isAfter(todayKey))
        entry,
  ];
}

/// The change from the latest entry back to the first entry within the
/// [lookbackDays] before it (`[latest - lookbackDays, latest - 1]`).
///
/// When the window holds no earlier entry the closest one before the window is
/// used instead, so a sparse log still shows its real trend. `null` when fewer
/// than two entries exist to compare.
double? deltaOverDays(
  List<WeightEntry> entries,
  DateTime todayKey,
  int lookbackDays,
) {
  if (entries.length < 2) {
    return null;
  }
  final WeightEntry latest = entries.last;
  final DateTime windowEnd = latest.dayKey.subtract(const Duration(days: 1));
  final List<WeightEntry> window = entriesWithinDays(
    entries,
    windowEnd,
    lookbackDays,
  );
  final WeightEntry? baseline = window.isNotEmpty
      ? window.first
      : _closestBefore(entries, windowEnd);
  return baseline == null ? null : latest.weightKg - baseline.weightKg;
}

/// The closest entry strictly before [dayKey], or `null`.
WeightEntry? _closestBefore(List<WeightEntry> entries, DateTime dayKey) {
  WeightEntry? best;
  for (final WeightEntry entry in entries) {
    if (entry.dayKey.isBefore(dayKey)) {
      best = entry;
    }
  }
  return best;
}
