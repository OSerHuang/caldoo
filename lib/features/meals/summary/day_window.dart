/// The half-open instant window of a local calendar day.
///
/// `lib/core/time/date_windows.dart` (task 9) owns the day **key** (a
/// UTC-flagged midnight whose y/m/d is the local date). The repository ports
/// instead take real instant bounds `[startInclusive, endExclusive)`, so this
/// file is the one conversion between the two, using the same explicit
/// [LocalOffset] and never the machine timezone.
library;

import 'package:caldoo/core/time/date_windows.dart';

/// A local day expressed as the instant window the repository understands,
/// plus the date [key] the rollups use.
typedef LocalDayWindow = ({DateTime start, DateTime end, DateTime key});

/// The local calendar day containing [instant] at [offset].
///
/// Local midnight is `key - offset` because [dayKeyOf] returns the date at UTC
/// midnight; [DateTime] equality/comparison in drift is on the epoch instant,
/// so the returned flag (`UTC`) is irrelevant to a query.
LocalDayWindow localDayWindow(DateTime instant, LocalOffset offset) {
  final DateTime key = dayKeyOf(instant, offset);
  final DateTime start = key.subtract(offset.duration);
  return (start: start, end: start.add(const Duration(days: 1)), key: key);
}
