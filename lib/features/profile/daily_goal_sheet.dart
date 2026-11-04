/// The 每日热量目标 bottom sheet (opened from the profile screen's goal card).
///
/// The goal is either a **preset** or a **fixed custom number**:
///
/// * a preset (缓慢减脂 −250, 较快减脂 −500, 增肌增重 +250 kcal/day — the
///   1 kg ≈ 7700 kcal convention) is RELATIVE to the resolved BMR: it is
///   stored as [DailyGoalPreset] and re-derived by the energy engine on every
///   read, so a BMR change (a new weight while the BMR is derived) moves the
///   goal with it;
/// * a custom number is what the user typed: it is stored as
///   [UserProfile.dailyKcalGoalOverride] and stays fixed, weight change or not;
/// * 维持体重 / a blank custom field stores neither (the budget falls back to
///   the resolved BMR).
///
/// Saving writes the whole profile back through the `ProfileRepository` port
/// with only the goal fields changed, ALWAYS clearing the other representation
/// (a preset and an absolute override are mutually exclusive). 恢复默认 clears
/// both. A legacy profile (only an absolute `dailyKcalGoalOverride`) is treated
/// as a fixed custom value — never guessed back into a preset. A final goal
/// below 1200 kcal/day shows a non-blocking health hint; the app advises,
/// never blocks.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:caldoo/core/providers/app_providers.dart';
import 'package:caldoo/core/theme/app_dimensions.dart';
import 'package:caldoo/domain/models/user_profile.dart';
import 'package:caldoo/l10n/app_strings.dart';

import 'profile_providers.dart';

/// Key of the 保存 action.
const Key goalSaveKey = Key('goal_save');

/// Key of the 恢复默认 action.
const Key goalRestoreDefaultKey = Key('goal_restore_default');

/// Key of the custom-goal text field.
const Key goalCustomFieldKey = Key('goal_custom_field');

/// Key of the preview line.
const Key goalPreviewKey = Key('goal_preview');

/// Key of the preset-vs-custom explanation line.
const Key goalPresetNoteKey = Key('goal_preset_note');

/// The four selectable rows: three stored presets plus 维持 (no goal at all).
enum _GoalPreset {
  maintain(null),
  slowCut(DailyGoalPreset.slowCut),
  fastCut(DailyGoalPreset.fastCut),
  gain(DailyGoalPreset.gain);

  const _GoalPreset(this.storedPreset);

  /// The [DailyGoalPreset] persisted for this row, or `null` for 维持 (which
  /// stores no goal at all).
  final DailyGoalPreset? storedPreset;

  /// The BMR delta in whole kcal/day, or `null` for 维持.
  int? get deltaKcal => storedPreset?.deltaKcal;

  /// The row matching a stored [DailyGoalPreset].
  static _GoalPreset fromStored(DailyGoalPreset preset) => switch (preset) {
    DailyGoalPreset.slowCut => slowCut,
    DailyGoalPreset.fastCut => fastCut,
    DailyGoalPreset.gain => gain,
  };
}

/// Opens the goal sheet for [profile] (whose BMR must already resolve).
///
/// [bmrKcal] is the resolved basal metabolic rate the presets offset; the
/// caller takes it from the energy engine so the sheet never re-derives it.
Future<void> showDailyGoalSheet(
  BuildContext context, {
  required UserProfile profile,
  required int bmrKcal,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (BuildContext sheetContext) =>
        DailyGoalSheet(profile: profile, bmrKcal: bmrKcal),
  );
}

/// The goal sheet body.
class DailyGoalSheet extends ConsumerStatefulWidget {
  /// Creates the sheet for [profile] against the resolved [bmrKcal].
  const DailyGoalSheet({
    super.key,
    required this.profile,
    required this.bmrKcal,
  });

  /// The stored profile (read-only here; saving rewrites only the goal).
  final UserProfile profile;

  /// The resolved BMR in whole kcal/day — the presets' base.
  final int bmrKcal;

  @override
  ConsumerState<DailyGoalSheet> createState() => _DailyGoalSheetState();
}

class _DailyGoalSheetState extends ConsumerState<DailyGoalSheet> {
  _GoalPreset? _preset;
  final TextEditingController _customController = TextEditingController();
  String? _error;

  /// The goal the current selection represents: `null` = 维持 (no goal),
  /// otherwise a positive whole kcal/day value.
  ///
  /// A selected row wins (preset → `bmr + delta`, 维持 → no goal); with no row
  /// selected the custom field is the goal (empty field = 维持).
  int? get _effectiveGoal {
    final _GoalPreset? preset = _preset;
    if (preset != null) {
      final int? delta = preset.deltaKcal;
      return delta == null ? null : widget.bmrKcal + delta;
    }
    return int.tryParse(_customController.text.trim());
  }

  @override
  void initState() {
    super.initState();
    // Seed the selection from what is stored — never infer a preset from an
    // absolute number: a legacy value is a fixed custom goal by definition.
    final DailyGoalPreset? storedPreset = widget.profile.dailyGoalPreset;
    final int? storedOverride = widget.profile.dailyKcalGoalOverride;
    if (storedPreset != null) {
      _preset = _GoalPreset.fromStored(storedPreset);
    } else if (storedOverride != null) {
      _customController.text = '$storedOverride';
    } else {
      _preset = _GoalPreset.maintain;
    }
  }

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  void _selectPreset(_GoalPreset preset) {
    setState(() {
      _preset = preset;
      _error = null;
      _customController.clear();
    });
  }

  void _onCustomEdited(String text) {
    setState(() {
      _preset = null;
      _error = null;
    });
  }

  Future<void> _restoreDefault() async {
    await ref
        .read(profileRepositoryProvider)
        .saveProfile(
          widget.profile.copyWith(
            clearDailyKcalGoalOverride: true,
            clearDailyGoalPreset: true,
          ),
        );
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _save() async {
    final int? effective = _effectiveGoal;
    if (effective != null && effective <= 0) {
      setState(() => _error = S.of(context).goalValidationError);
      return;
    }
    // A preset and an absolute override are mutually exclusive, so each branch
    // clears the representation it does not write. `copyWith` cannot express
    // "set null" without the clear flags, hence both are always passed.
    final _GoalPreset? preset = _preset;
    final UserProfile updated;
    if (preset != null) {
      final DailyGoalPreset? stored = preset.storedPreset;
      updated = stored == null
          // 维持体重: no goal at all.
          ? widget.profile.copyWith(
              clearDailyKcalGoalOverride: true,
              clearDailyGoalPreset: true,
            )
          : widget.profile.copyWith(
              dailyGoalPreset: stored,
              clearDailyKcalGoalOverride: true,
            );
    } else {
      // The custom field is the source; blank means 维持 (no goal).
      updated = effective == null
          ? widget.profile.copyWith(
              clearDailyKcalGoalOverride: true,
              clearDailyGoalPreset: true,
            )
          : widget.profile.copyWith(
              dailyKcalGoalOverride: effective,
              clearDailyGoalPreset: true,
            );
    }
    await ref.read(profileRepositoryProvider).saveProfile(updated);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final int exerciseKcal =
        ref.watch(goalSheetExerciseKcalProvider).value ?? 0;
    final int? effective = _effectiveGoal;

    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: AppDim.pagePadding,
        right: AppDim.pagePadding,
        // Keep the actions above the keyboard.
        bottom: MediaQuery.of(context).viewInsets.bottom + AppDim.pagePadding,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  S.of(context).dailyGoalSheetTitle,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            S.of(context).dailyGoalSheetCaption(widget.bmrKcal),
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 4),
          Text(
            S.of(context).goalSheetPresetNote,
            key: goalPresetNoteKey,
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          _presetRow(
            preset: _GoalPreset.maintain,
            name: S.of(context).goalPresetMaintain,
            subtitle: S.of(context).goalPresetMaintainSub(widget.bmrKcal),
            value: widget.bmrKcal,
          ),
          _presetRow(
            preset: _GoalPreset.slowCut,
            name: S.of(context).goalPresetSlowCut,
            subtitle: S.of(context).goalPresetSlowCutSub(widget.bmrKcal),
            value: widget.bmrKcal - 250,
          ),
          _presetRow(
            preset: _GoalPreset.fastCut,
            name: S.of(context).goalPresetFastCut,
            subtitle: S.of(context).goalPresetFastCutSub(widget.bmrKcal),
            value: widget.bmrKcal - 500,
          ),
          _presetRow(
            preset: _GoalPreset.gain,
            name: S.of(context).goalPresetGain,
            subtitle: S.of(context).goalPresetGainSub(widget.bmrKcal),
            value: widget.bmrKcal + 250,
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Text(
                S.of(context).goalCustomLabel,
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 96,
                child: TextField(
                  key: goalCustomFieldKey,
                  controller: _customController,
                  keyboardType: TextInputType.number,
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  onChanged: _onCustomEdited,
                  decoration: const InputDecoration(isDense: true),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                S.of(context).goalCustomUnit,
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
          // The hint applies to whatever goal the current selection would
          // actually store (preset-derived or custom), and never blocks.
          if (effective != null && effective > 0 && effective < 1200)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                S.of(context).goalLowHint,
                key: const Key('goal_low_hint'),
                style: theme.textTheme.bodySmall!.copyWith(
                  color: theme.colorScheme.tertiary,
                ),
              ),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                _error!,
                key: const Key('goal_validation_error'),
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(AppDim.radiusContainer),
            ),
            child: Text(
              key: goalPreviewKey,
              effective == null
                  ? S
                        .of(context)
                        .goalPreviewNoGoal(
                          widget.bmrKcal,
                          exerciseKcal,
                          widget.bmrKcal + exerciseKcal,
                        )
                  : S
                        .of(context)
                        .goalPreview(
                          effective,
                          exerciseKcal,
                          effective + exerciseKcal,
                        ),
              style: theme.textTheme.bodySmall,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              TextButton.icon(
                key: goalRestoreDefaultKey,
                onPressed: _restoreDefault,
                icon: const Icon(Icons.restart_alt, size: 18),
                label: Text(S.of(context).goalRestoreDefault),
              ),
              FilledButton(
                key: goalSaveKey,
                onPressed: _save,
                child: Text(S.of(context).save),
              ),
            ],
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _presetRow({
    required _GoalPreset preset,
    required String name,
    required String subtitle,
    required int value,
  }) {
    final ThemeData theme = Theme.of(context);
    final bool selected = _preset == preset;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppDim.radiusContainer),
        onTap: () => _selectPreset(preset),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            border: Border.all(
              color: selected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outlineVariant,
            ),
            borderRadius: BorderRadius.circular(AppDim.radiusContainer),
            color: selected
                ? theme.colorScheme.primaryContainer
                : theme.colorScheme.surface,
          ),
          child: Row(
            children: <Widget>[
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                size: 18,
                color: selected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outline,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(name, style: theme.textTheme.titleSmall),
                    Text(subtitle, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              Text(
                S.of(context).budgetValue('$value'),
                style: theme.textTheme.titleSmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
