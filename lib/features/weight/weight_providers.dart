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

/// The entry recorded on [dayKey], or `null` when that day has none.
///
/// Day pages other than today render the weight card only for days that were
/// actually recorded, so this is the gate for "does this day have a weight?".
WeightEntry? weightOnDay(List<WeightEntry> entries, DateTime dayKey) {
  for (final WeightEntry entry in entries) {
    if (entry.dayKey.isAtSameMomentAs(dayKey)) {
      return entry;
    }
  }
  return null;
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
  return deltaEndingOn(entries, entries.last.dayKey, lookbackDays);
}

/// The change of the weight recorded on [dayKey] against the first entry
/// within the [lookbackDays] before it (`[dayKey - lookbackDays, dayKey - 1]`).
///
/// The day-page card uses this on a past day: the same "近7天" arithmetic as
/// the today card, anchored on the day being viewed instead of the newest
/// entry. Falls back to the closest earlier entry when the window is empty, so
/// a sparse log still shows its real trend. `null` when [dayKey] has no record
/// or nothing was recorded before it.
double? deltaEndingOn(
  List<WeightEntry> entries,
  DateTime dayKey,
  int lookbackDays,
) {
  final WeightEntry? anchor = weightOnDay(entries, dayKey);
  if (anchor == null) {
    return null;
  }
  final List<WeightEntry> earlier = <WeightEntry>[
    for (final WeightEntry entry in entries)
      if (entry.dayKey.isBefore(dayKey)) entry,
  ];
  if (earlier.isEmpty) {
    return null;
  }
  final DateTime windowEnd = dayKey.subtract(const Duration(days: 1));
  final List<WeightEntry> window = entriesWithinDays(
    earlier,
    windowEnd,
    lookbackDays,
  );
  final WeightEntry baseline = window.isNotEmpty ? window.first : earlier.last;
  return anchor.weightKg - baseline.weightKg;
}
