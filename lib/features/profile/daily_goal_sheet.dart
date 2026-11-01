/// The 每日热量目标 bottom sheet (opened from the profile screen's goal card).
///
/// The goal is an EXPLICIT number: the presets only pre-compute suggestions
/// from the resolved BMR (维持 = no goal, −250, −500, +250 kcal/day — the
/// 1 kg ≈ 7700 kcal convention), and the user can always type their own. The
/// stored value is whatever the preview showed when 保存 was tapped, so the
/// engine (`computeEnergyBudget`) never re-derives it.
///
/// Saving writes the whole profile back through the `ProfileRepository` port
/// with only `dailyKcalGoalOverride` changed; 恢复默认 clears the override
/// (the budget falls back to the resolved BMR). A custom value below 1200
/// kcal/day shows a non-blocking health hint — the app advises, never blocks.
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

/// The four presets, as deltas from the resolved BMR in whole kcal/day.
enum _GoalPreset {
  maintain(null),
  slowCut(-250),
  fastCut(-500),
  gain(250);

  const _GoalPreset(this.deltaKcal);

  /// The BMR delta, or `null` for 维持 (clear the goal).
  final int? deltaKcal;
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
  /// A selected preset wins; with no preset selected the custom field is the
  /// goal (empty field = 维持). A stored non-preset goal is seeded verbatim
  /// into the field on open, so the field is the single custom source.
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
    // Seed the selection from the stored goal: a preset value highlights its
    // row, anything else lands in the custom field verbatim.
    final int? stored = widget.profile.dailyKcalGoalOverride;
    if (stored != null) {
      if (stored == widget.bmrKcal - 250) {
        _preset = _GoalPreset.slowCut;
      } else if (stored == widget.bmrKcal - 500) {
        _preset = _GoalPreset.fastCut;
      } else if (stored == widget.bmrKcal + 250) {
        _preset = _GoalPreset.gain;
      } else {
        _customController.text = '$stored';
      }
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
        .saveProfile(widget.profile.copyWith(clearDailyKcalGoalOverride: true));
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
    // copyWith cannot express "set null" without the clear flag, so both are
    // passed: a non-null effective overwrites, a null one clears.
    final UserProfile updated = widget.profile.copyWith(
      dailyKcalGoalOverride: effective,
      clearDailyKcalGoalOverride: effective == null,
    );
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
    final int? customValue = int.tryParse(_customController.text.trim());

    return Padding(
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
          if (customValue != null && customValue > 0 && customValue < 1200)
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
