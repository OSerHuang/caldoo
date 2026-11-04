/// The 记录体重 / 修改体重 bottom sheet.
///
/// One sheet serves both flows: recording opens with today's date and an empty
/// field; editing (from the trend page) opens with the row's day and value
/// pre-filled and a delete action. Saving goes through the `WeightRepository`
/// port — its [WeightRepository.saveWeight] contract syncs the profile's
/// `weightKg` in the same transaction, which is what the sync note under the
/// form explains.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:caldoo/core/time/date_windows.dart';
import 'package:caldoo/core/theme/app_dimensions.dart';
import 'package:caldoo/domain/models/weight_entry.dart';
import 'package:caldoo/l10n/app_format.dart';
import 'package:caldoo/l10n/app_strings.dart';
import 'package:caldoo/core/providers/app_providers.dart';

/// Key of the weight value field.
const Key weightValueFieldKey = Key('weight_value_field');

/// Key of the weight date field.
const Key weightDateFieldKey = Key('weight_date_field');

/// Key of the sheet's save action.
const Key weightSaveKey = Key('weight_save');

/// Key of the sheet's delete action.
const Key weightDeleteKey = Key('weight_delete');

/// Opens the entry sheet. [existing] selects the edit flow (pre-filled day and
/// value plus delete); `null` opens the record flow defaulting to today.
Future<void> showWeightEntrySheet(
  BuildContext context, {
  required DateTime initialDay,
  WeightEntry? existing,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (BuildContext sheetContext) =>
        WeightEntrySheet(initialDay: initialDay, existing: existing),
  );
}

/// The entry sheet body.
class WeightEntrySheet extends ConsumerStatefulWidget {
  /// Creates the sheet for [initialDay]; [existing] switches to the edit flow.
  const WeightEntrySheet({super.key, required this.initialDay, this.existing});

  /// The day the date picker starts on (the tapped day, or today).
  final DateTime initialDay;

  /// The entry being edited, or `null` in the record flow.
  final WeightEntry? existing;

  @override
  ConsumerState<WeightEntrySheet> createState() => _WeightEntrySheetState();
}

class _WeightEntrySheetState extends ConsumerState<WeightEntrySheet> {
  late DateTime _day;
  final TextEditingController _weightController = TextEditingController();
  String? _error;

  @override
  void initState() {
    super.initState();
    final DateTime todayKey = dayKeyFromLocalDate(DateTime.now());
    DateTime initial = dayKeyFromLocalDate(widget.initialDay);
    // Backfilling a past period passes the period's LAST day, which for the
    // current week/month is still in the future — clamp to today.
    if (initial.isAfter(todayKey)) {
      initial = todayKey;
    }
    _day = initial;
    final WeightEntry? existing = widget.existing;
    if (existing != null) {
      _weightController.text = AppFormat.number(existing.weightKg);
    }
  }

  @override
  void dispose() {
    _weightController.dispose();
    super.dispose();
  }

  DateTime _today() => DateTime.now();

  Future<void> _pickDay() async {
    final DateTime today = _today();
    DateTime initial = _day;
    if (initial.isAfter(today)) {
      initial = today;
    }
    if (initial.isBefore(DateTime(1900))) {
      initial = DateTime(1900);
    }
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: today,
      helpText: S.of(context).weightEntryDateLabel,
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() => _day = dayKeyFromLocalDate(picked));
  }

  Future<void> _save() async {
    final double? parsed = double.tryParse(_weightController.text.trim());
    if (parsed == null || !parsed.isFinite || parsed <= 0) {
      setState(() => _error = S.of(context).weightEntryValidationError);
      return;
    }
    setState(() => _error = null);
    await ref
        .read(weightRepositoryProvider)
        .saveWeight(dayKey: _day, weightKg: parsed);
    // An edit that MOVED the day must not leave the old row behind — that
    // would be the same weigh-in counted on two days (deltas, sparkline and
    // 近7天 all read doubles). Save first, then drop the old day: a failure
    // in between leaves a duplicate, never a lost entry.
    final WeightEntry? existing = widget.existing;
    if (existing != null && existing.dayKey != _day) {
      await ref.read(weightRepositoryProvider).deleteDay(existing.dayKey);
    }
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _delete() async {
    final WeightEntry? existing = widget.existing;
    if (existing == null) {
      return;
    }
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        key: const Key('weight_delete_confirm_dialog'),
        title: Text(S.of(dialogContext).weightDeleteConfirmTitle),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(S.of(dialogContext).cancel),
          ),
          FilledButton(
            key: const Key('weight_delete_confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(S.of(dialogContext).delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    await ref.read(weightRepositoryProvider).deleteDay(existing.dayKey);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isEdit = widget.existing != null;
    return Padding(
      padding: EdgeInsets.only(
        left: AppDim.pagePadding,
        right: AppDim.pagePadding,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppDim.pagePadding,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            isEdit
                ? S.of(context).weightEntryTitleEdit
                : S.of(context).weightEntryTitleRecord,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          InkWell(
            key: weightDateFieldKey,
            borderRadius: BorderRadius.circular(AppDim.radiusControl),
            onTap: _pickDay,
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: S.of(context).weightEntryDateLabel,
                suffixIcon: const Icon(Icons.calendar_today_outlined, size: 20),
              ),
              child: Text(AppFormat.date(_day)),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: weightValueFieldKey,
            controller: _weightController,
            autofocus: !isEdit,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
            decoration: InputDecoration(
              labelText: S.of(context).weightEntryValueLabel,
              errorText: _error,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            S.of(context).weightEntryOverwriteNote,
            style: theme.textTheme.bodySmall,
          ),
          Text(S.of(context).weightSyncNote, style: theme.textTheme.bodySmall),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              if (isEdit) ...<Widget>[
                OutlinedButton.icon(
                  key: weightDeleteKey,
                  onPressed: _delete,
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: Text(S.of(context).weightDeleteAction),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: FilledButton(
                  key: weightSaveKey,
                  onPressed: _save,
                  child: Text(S.of(context).save),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}
