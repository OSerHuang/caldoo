/// The one-per-day exercise-burn screen.
///
/// A single numeric field 「运动消耗 (kcal)」 for the chosen calendar day, a
/// 保存 button and a 清除 action. Saving goes through the
/// [DailyExerciseRepository] port; the day's burn is added back to that day's
/// budget by the energy engine — exercise is never folded into the BMR
/// baseline.
///
/// ## Which day is being edited?
///
/// Exercise is normally copied off a smartwatch the morning after, so the form
/// opens on **yesterday**; when yesterday already has a burn the default moves
/// to **today** (nothing left to backfill). The date card opens a picker for
/// any earlier day — a burn is never logged for a future day — and the
/// 昨天/今天 shortcut switches between the two common cases without the picker.
///
/// An empty day is graceful: the readout shows the empty state and the field is
/// simply blank.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:caldoo/core/time/date_windows.dart';
import 'package:caldoo/core/ui/app_card.dart';
import 'package:caldoo/l10n/app_format.dart';
import 'package:caldoo/l10n/app_strings.dart';

import 'exercise_entry_controller.dart';
import 'exercise_providers.dart';

/// Key of the burn (kcal) text field.
const Key exerciseKcalFieldKey = Key('exercise_kcal_field');

/// Key of the save button.
const Key exerciseSaveButtonKey = Key('exercise_save_button');

/// Key of the clear action.
const Key exerciseClearButtonKey = Key('exercise_clear_button');

/// Key of the validation/error message.
const Key exerciseErrorKey = Key('exercise_error');

/// Key of the tappable date card (opens the date picker).
const Key exerciseDateCardKey = Key('exercise_date_card');

/// Key of the selected day's date line.
const Key exerciseSelectedDateKey = Key('exercise_selected_date');

/// Key of the readout of the selected day's stored burn.
const Key exerciseDayValueKey = Key('exercise_day_value');

/// Key of the 昨天/今天 shortcut.
const Key exerciseDayShortcutKey = Key('exercise_day_shortcut');

/// How far back the date picker lets the user backfill: one year of burn rows.
const Duration exerciseHistoryWindow = Duration(days: 365);

/// Formats a whole-kcal value for display (`300 -> "300"`).
///
/// Energy is integer-only, so no trailing `.0` (or fraction) can ever appear.
String formatKcal(int kcal) => AppFormat.integer(kcal);

/// The date card's line for [day] read against [today]:
/// `今天 · 2026年9月21日`, `昨天 · 2026年9月20日`, or `2026年9月18日`.
String exerciseDayLabel(S strings, DateTime day, DateTime today) {
  final String date = AppFormat.date(day);
  final int daysAgo = today.difference(day).inDays;
  if (daysAgo == 0) {
    return '${strings.exerciseDayToday} · $date';
  }
  if (daysAgo == 1) {
    return '${strings.exerciseDayYesterday} · $date';
  }
  return date;
}

/// The exercise-burn entry screen.
class ExerciseEntryScreen extends ConsumerStatefulWidget {
  const ExerciseEntryScreen({super.key});

  @override
  ConsumerState<ExerciseEntryScreen> createState() =>
      _ExerciseEntryScreenState();
}

class _ExerciseEntryScreenState extends ConsumerState<ExerciseEntryScreen> {
  final TextEditingController _kcal = TextEditingController();

  /// The day whose stored burn is currently loaded into [_kcal].
  ///
  /// A live stream re-emission must not overwrite what the user is typing, so
  /// the field is seeded exactly once per selected day; typing takes the day
  /// over (see [_onChanged]).
  DateTime? _prefilledDay;

  @override
  void initState() {
    super.initState();
    // Re-apply the opening date default on every entry: an async read of
    // yesterday's row decides between yesterday and today. Riverpod forbids
    // modifying a provider while the tree is building, so the reset is deferred
    // by one microtask (it runs before the first frame the user can tap).
    Future<void>.microtask(() {
      if (mounted) {
        ref.read(exerciseSelectedDayProvider.notifier).reset();
      }
    });
  }

  @override
  void dispose() {
    _kcal.dispose();
    super.dispose();
  }

  /// Parses the field text: blank clears the draft; unparseable/negative text
  /// is ignored (the widget never lets a stray character break the form).
  void _onChanged(String text) {
    // Typing takes the field over for the selected day, so the stored value
    // that may still be arriving must not replace it.
    _prefilledDay = ref.read(exerciseEntryControllerProvider).day;
    final String trimmed = text.trim();
    if (trimmed.isEmpty) {
      ref.read(exerciseEntryControllerProvider.notifier).setKcal(null);
      return;
    }
    final int? parsed = int.tryParse(trimmed);
    if (parsed == null || parsed < 0) {
      return;
    }
    ref.read(exerciseEntryControllerProvider.notifier).setKcal(parsed);
  }

  @override
  Widget build(BuildContext context) {
    final S strings = S.of(context);
    final ExerciseEntryState state = ref.watch(exerciseEntryControllerProvider);
    final DateTime today = ref.watch(exerciseDayKeyProvider);
    final DateTime? day = state.day;

    // Seed the field with the selected day's stored burn once it is known. The
    // write is deferred to a post-frame callback so mutating the controller
    // cannot mark the field dirty during build.
    if (day != null && state.loaded && _prefilledDay != day) {
      _prefilledDay = day;
      final int? stored = state.kcal;
      final String text = (stored == null || stored <= 0)
          ? ''
          : formatKcal(stored);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _kcal.text = text;
        }
      });
    }

    final DateTime yesterday = today.subtract(const Duration(days: 1));
    final bool editable = state.ready && !state.saving;

    return Scaffold(
      appBar: AppBar(title: Text(strings.exerciseTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          _DayCard(
            day: day,
            today: today,
            loaded: state.loaded,
            loadFailed: state.loadFailed,
            kcal: state.kcal,
            onTap: state.saving || day == null ? null : _pickDate,
          ),
          const SizedBox(height: 12),
          SegmentedButton<DateTime>(
            key: exerciseDayShortcutKey,
            showSelectedIcon: false,
            emptySelectionAllowed: true,
            segments: <ButtonSegment<DateTime>>[
              ButtonSegment<DateTime>(
                value: yesterday,
                label: Text(strings.exerciseDayYesterday),
              ),
              ButtonSegment<DateTime>(
                value: today,
                label: Text(strings.exerciseDayToday),
              ),
            ],
            selected: <DateTime>{
              if (day == yesterday) yesterday else if (day == today) today,
            },
            onSelectionChanged: state.saving
                ? null
                : (Set<DateTime> selection) {
                    if (selection.isEmpty) {
                      return;
                    }
                    ref
                        .read(exerciseSelectedDayProvider.notifier)
                        .select(selection.first);
                  },
          ),
          const SizedBox(height: 16),
          TextField(
            key: exerciseKcalFieldKey,
            controller: _kcal,
            enabled: editable,
            // Energy is whole kcal: digits only, no decimal point.
            keyboardType: TextInputType.number,
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.digitsOnly,
            ],
            onChanged: _onChanged,
            decoration: InputDecoration(labelText: strings.labelExerciseKcal),
          ),
          if (state.error != null) ...<Widget>[
            const SizedBox(height: 12),
            Text(
              state.error!,
              key: exerciseErrorKey,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              Expanded(
                child: FilledButton(
                  key: exerciseSaveButtonKey,
                  onPressed: editable ? _save : null,
                  child: Text(strings.save),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                key: exerciseClearButtonKey,
                onPressed: editable ? _clear : null,
                child: Text(strings.clearExercise),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Opens the date picker for any day inside the history window up to today.
  Future<void> _pickDate() async {
    final DateTime? selected = ref.read(exerciseEntryControllerProvider).day;
    if (selected == null) {
      return;
    }
    final DateTime today = ref.read(exerciseDayKeyProvider);
    final DateTime firstDay = today.subtract(exerciseHistoryWindow);
    final DateTime initialDay = selected.isBefore(firstDay)
        ? firstDay
        : selected;
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: localDateOfKey(initialDay),
      firstDate: localDateOfKey(firstDay),
      lastDate: localDateOfKey(today),
      helpText: S.of(context).exerciseDatePickerTitle,
    );
    if (picked == null || !mounted) {
      return;
    }
    ref
        .read(exerciseSelectedDayProvider.notifier)
        .select(dayKeyFromLocalDate(picked));
  }

  Future<void> _save() async {
    final bool ok = await ref
        .read(exerciseEntryControllerProvider.notifier)
        .save();
    if (!ok || !mounted) {
      return;
    }
    final ExerciseEntryState state = ref.read(exerciseEntryControllerProvider);
    _prefilledDay = state.day;
    final int? value = state.kcal;
    _kcal.text = value == null ? '' : formatKcal(value);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(S.of(context).savedSnack)));
  }

  Future<void> _clear() async {
    await ref.read(exerciseEntryControllerProvider.notifier).clear();
    if (!mounted) {
      return;
    }
    _prefilledDay = ref.read(exerciseEntryControllerProvider).day;
    _kcal.clear();
  }
}

/// The date card: the selected day on top, its stored burn underneath.
///
/// The whole card is the date-picker affordance (chevron on the right); it is
/// inert (no ink, no picker) while the opening default resolves or a write is
/// in flight.
class _DayCard extends StatelessWidget {
  const _DayCard({
    required this.day,
    required this.today,
    required this.loaded,
    required this.loadFailed,
    required this.kcal,
    required this.onTap,
  });

  final DateTime? day;
  final DateTime today;
  final bool loaded;
  final bool loadFailed;
  final int? kcal;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final S strings = S.of(context);

    final String dateLabel = day == null
        ? strings.exerciseDayLoading
        : exerciseDayLabel(strings, day!, today);
    final bool hasValue = loaded && kcal != null && kcal! > 0;
    final String valueLabel;
    if (loadFailed) {
      valueLabel = strings.loadFailed;
    } else if (!loaded) {
      valueLabel = strings.exerciseDayLoading;
    } else if (hasValue) {
      valueLabel = strings.exerciseDayValue(formatKcal(kcal!));
    } else {
      valueLabel = strings.exerciseDayEmpty;
    }

    return AppCard(
      key: exerciseDateCardKey,
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: colors.secondaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.calendar_month,
                  size: 20,
                  color: colors.secondary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      strings.exerciseDateLabel,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      dateLabel,
                      key: exerciseSelectedDateKey,
                      style: theme.textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 20,
                color: colors.onSurfaceVariant,
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Icon(
                Icons.local_fire_department,
                size: 18,
                color: hasValue ? colors.secondary : colors.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  valueLabel,
                  key: exerciseDayValueKey,
                  style: hasValue
                      ? theme.textTheme.titleSmall
                      : theme.textTheme.bodyMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
