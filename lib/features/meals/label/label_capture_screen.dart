/// The nutrition-label capture screen: pick a photo, preview it, add optional
/// supplementary text, parse **every** label in the photo, confirm/edit each
/// one, and save them as `source: label` foods.
///
/// This is also the 食物库 tab's **添加食物** flow: the photo step is the
/// 拍照识别营养标签 entry point, and [startManualEntry] opens the blank confirm
/// form directly for the 手动录入 entry point (no photo, no network).
///
/// The save button only exists on the confirm step, so a label can never be
/// saved without the parsed values being shown first. Every nutrient field is
/// nullable: a blank input clears the value, and
/// [LabelCaptureController.save] stores it as `null` (never a fabricated `0`).
/// The saved step ends with a 完成 action so the add flow returns to the
/// library it was started from.
///
/// The energy and sodium rows accept two units each: 能量 types kJ or 大卡, and
/// the 钠 row types mg or 盐 g. A suffix dropdown on each row picks the input
/// unit; the draft always stores the canonical kJ / mg and switching the unit
/// only re-derives the text, so a round trip never shifts the value. Manual
/// entry (no photo) starts in the user's display units; a photo-confirmed
/// label starts in the printed kJ / mg.
///
/// Design notes:
/// * the picked photo is rendered before recognition, because the user cannot
///   otherwise tell whether the right (and a legible) photo was selected;
/// * one photo may contain several 营养成分表, so the confirm step renders one
///   editable card per label, each with its own include switch;
/// * the supplementary text typed on the pick step is sent to the model as a
///   hint and pre-filled into each label's notes (package size, aliases, …).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:caldoo/core/providers/app_providers.dart'
    show isOfflineProvider;
import 'package:caldoo/core/units/display_units.dart';
import 'package:caldoo/core/units/nutrition_units.dart';
import 'package:caldoo/features/offline/offline_ui.dart';
import 'package:caldoo/l10n/app_format.dart';
import 'package:caldoo/l10n/app_strings.dart';

import 'label_capture_controller.dart';
import 'label_draft.dart';

/// Key of the G7 offline notice on the pick step.
const Key labelOfflineHintKey = Key('label_offline_hint');

/// Key of the always-available manual-entry fallback (works offline).
const Key labelManualEntryButtonKey = Key('label_manual_entry_button');

/// Key of the selected-photo preview on the pick step.
const Key labelPhotoPreviewKey = Key('label_photo_preview');

/// Key of the "take a photo" button on the pick step.
const Key labelCameraButtonKey = Key('label_camera_button');

/// Key of the 完成 action on the saved step (pops back to the food library).
const Key labelDoneButtonKey = Key('label_done_button');

/// Key of the supplementary-text field on the pick step.
const Key labelNoteFieldKey = Key('label_note_field');

/// Key of the confirmation-step photo thumbnail.
const Key labelPhotoThumbKey = Key('label_photo_thumb');

/// Key of the [index]-th label's name field on the confirm step.
Key labelNameFieldKey(int index) => Key('label_name_field_$index');

/// Key of the [index]-th label's brand field on the confirm step.
Key labelBrandFieldKey(int index) => Key('label_brand_field_$index');

/// Key of the [index]-th label's notes field on the confirm step.
Key labelNotesFieldKey(int index) => Key('label_notes_field_$index');

/// Key of the [index]-th label's include switch on the confirm step.
Key labelIncludeSwitchKey(int index) => Key('label_include_$index');

/// Key of the [index]-th label's [field] input on the confirm step.
Key labelFieldKey(int index, LabelField field) =>
    Key('label_field_${field.name}_$index');

/// Key of the [index]-th card's energy-unit dropdown (kJ / kcal).
Key labelEnergyUnitKey(int index) => Key('label_energy_unit_$index');

/// Key of the [index]-th card's sodium-unit dropdown (mg / salt g).
Key labelSaltUnitKey(int index) => Key('label_salt_unit_$index');

/// Key of the [index]-th label's card.
Key labelCardKey(int index) => Key('label_card_$index');

class LabelCaptureScreen extends ConsumerStatefulWidget {
  const LabelCaptureScreen({this.startManualEntry = false, super.key});

  /// Opens the blank confirm form straight away instead of the photo step.
  ///
  /// Set by the 食物库's 添加食物 → 手动录入 entry; the normal photo path leaves
  /// it `false`.
  final bool startManualEntry;

  @override
  ConsumerState<LabelCaptureScreen> createState() => _LabelCaptureScreenState();
}

class _LabelCaptureScreenState extends ConsumerState<LabelCaptureScreen> {
  /// Pick-step supplementary text. The card fields own their own controllers.
  final TextEditingController _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // The controller is a non-autoDispose provider that outlives this screen,
    // so a stale `saved`/`confirm` state would otherwise be shown when the
    // user leaves and re-opens 「识别营养标签」. `context.push` recreates this
    // State on re-entry, so resetting here always starts from the pick step.
    // Riverpod forbids modifying a provider while the widget tree is building,
    // so the reset is deferred by one microtask (runs as soon as the build
    // phase finishes, before the user can interact).
    // NOTE: a branch-preserving tab switch would not remount the widget; the
    // reported repro (navigate away then re-open) does.
    Future<void>.microtask(() {
      if (!mounted) {
        return;
      }
      final LabelCaptureController controller = ref.read(
        labelCaptureControllerProvider.notifier,
      );
      controller.reset();
      if (widget.startManualEntry) {
        controller.startManualEntry();
      }
    });
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pick(LabelPhotoLane lane) async {
    await ref.read(labelCaptureControllerProvider.notifier).pickPhoto(lane);
  }

  Future<void> _parse() async {
    await ref.read(labelCaptureControllerProvider.notifier).parse();
  }

  void _manualEntry() {
    ref.read(labelCaptureControllerProvider.notifier).startManualEntry();
  }

  Future<void> _save() async {
    final bool ok = await ref
        .read(labelCaptureControllerProvider.notifier)
        .save();
    if (!mounted || !ok) {
      return;
    }
    final int count = ref.read(labelCaptureControllerProvider).saved.length;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          count > 1
              ? S.of(context).labelSavedSnackCount(count)
              : S.of(context).labelSavedSnack,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final LabelCaptureState state = ref.watch(labelCaptureControllerProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.startManualEntry
              ? S.of(context).labelManualTitle
              : S.of(context).labelTitle,
        ),
      ),
      body: switch (state.stage) {
        LabelStage.pick || LabelStage.ready => _buildPick(context, state),
        LabelStage.parsing => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(S.of(context).labelRecognizing),
            ],
          ),
        ),
        LabelStage.confirm => _buildConfirm(context, state),
        LabelStage.saved => _buildSaved(context, state),
        LabelStage.failed => _buildFailed(context, state),
      },
    );
  }

  Widget _buildPick(BuildContext context, LabelCaptureState state) {
    final bool picked = state.photoBytes != null;
    final bool offline = ref.watch(isOfflineProvider);
    // A non-lazy scroll view (SingleChildScrollView + Column): the pick step
    // is short, and every action must be built even while scrolled out of view
    // so `ensureVisible`/tests and accessibility traversal always find it.
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(S.of(context).labelPickHint),
          if (picked) ...<Widget>[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.memory(
                state.photoBytes!,
                key: labelPhotoPreviewKey,
                height: 220,
                width: double.infinity,
                fit: BoxFit.cover,
                cacheWidth: 900,
                errorBuilder:
                    (BuildContext context, Object error, StackTrace? s) =>
                        Container(
                          height: 120,
                          alignment: Alignment.center,
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                          child: Text(S.of(context).labelPhotoPreviewFailed),
                        ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              S.of(context).labelPhotoSelected,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 16),
          // Two explicit lanes: taking a new photo and picking an existing one
          // are different intents, and a label is usually photographed right
          // at the package rather than found in the gallery later.
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton.icon(
                  key: labelCameraButtonKey,
                  onPressed: () => _pick(LabelPhotoLane.camera),
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: Text(
                    picked
                        ? S.of(context).labelRetakePhoto
                        : S.of(context).labelTakePhoto,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('label_pick_button'),
                  onPressed: () => _pick(LabelPhotoLane.gallery),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: Text(
                    picked
                        ? S.of(context).labelReselectPhoto
                        : S.of(context).labelSelectPhoto,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            key: labelNoteFieldKey,
            controller: _noteController,
            minLines: 1,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: S.of(context).labelSupplementLabel,
              hintText: S.of(context).labelSupplementHint,
              helperText: S.of(context).labelSupplementHelp,
              helperMaxLines: 2,
              prefixIcon: const Icon(Icons.edit_note),
            ),
            onChanged: ref
                .read(labelCaptureControllerProvider.notifier)
                .setExtraNote,
          ),
          const SizedBox(height: 16),
          const AiOfflineNotice(noticeKey: labelOfflineHintKey),
          FilledButton(
            key: const Key('label_parse_button'),
            onPressed: picked && !offline ? _parse : null,
            child: Text(S.of(context).labelRecognize),
          ),
          const SizedBox(height: 8),
          // Manual entry never depends on the network (draft G7).
          TextButton.icon(
            key: labelManualEntryButtonKey,
            onPressed: _manualEntry,
            icon: const Icon(Icons.edit_outlined),
            label: Text(S.of(context).labelManualEntry),
          ),
          if (state.error != null) ...<Widget>[
            const SizedBox(height: 16),
            Text(
              state.error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildConfirm(BuildContext context, LabelCaptureState state) {
    final ThemeData theme = Theme.of(context);
    final int count = state.drafts.length;
    final int included = state.drafts
        .where((LabelDraft draft) => draft.included)
        .length;
    final bool hasPhoto = state.photoBytes != null;
    // Manual entry has no printed source, so it starts in the user's display
    // units; a photo-confirmed label starts in the printed GB 28050 units so
    // the typed values line up with the photo behind it. Either row can switch
    // units once on screen.
    final DisplayUnits units = DisplayUnits.of(context);
    final EnergyDisplay energyUnit = hasPhoto ? EnergyDisplay.kj : units.energy;
    final SaltDisplay saltUnit = hasPhoto ? SaltDisplay.sodium : units.salt;
    return Column(
      children: <Widget>[
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            children: <Widget>[
              if (hasPhoto) ...<Widget>[
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(
                    state.photoBytes!,
                    key: labelPhotoThumbKey,
                    height: 110,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    cacheWidth: 700,
                    errorBuilder: (
                      BuildContext context,
                      Object error,
                      StackTrace? s,
                    ) => const SizedBox.shrink(),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Card(
                color: theme.colorScheme.surfaceContainerHighest,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    count > 1
                        ? S.of(context).labelRecognizedCount(count)
                        : S.of(context).labelConfirmHint,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              for (int i = 0; i < count; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _LabelDraftCard(
                    key: labelCardKey(i),
                    index: i,
                    draft: state.drafts[i],
                    hasPhoto: hasPhoto,
                    initialEnergyUnit: energyUnit,
                    initialSaltUnit: saltUnit,
                  ),
                ),
              if (state.error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    state.error!,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: FilledButton(
              key: const Key('label_save_button'),
              onPressed: _save,
              child: Text(
                included > 1
                    ? S.of(context).labelConfirmSaveCount(included)
                    : S.of(context).labelConfirmSave,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSaved(BuildContext context, LabelCaptureState state) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        Icon(
          Icons.check_circle_outline,
          size: 48,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 16),
        for (final food in state.saved)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              S.of(context).labelSaved(food.name),
              textAlign: TextAlign.center,
            ),
          ),
        const SizedBox(height: 8),
        Text(S.of(context).labelSourceLine, textAlign: TextAlign.center),
        const SizedBox(height: 20),
        // Leaves the add flow: the food library is live, so it already shows
        // the new food behind this screen.
        FilledButton(
          key: labelDoneButtonKey,
          onPressed: () => Navigator.of(context).maybePop(),
          child: Text(S.of(context).labelDoneAction),
        ),
      ],
    );
  }

  Widget _buildFailed(BuildContext context, LabelCaptureState state) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              state.error ?? S.of(context).labelRecognizeFailed,
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('label_retry_button'),
              onPressed: _parse,
              child: Text(S.of(context).retry),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              key: labelManualEntryButtonKey,
              onPressed: _manualEntry,
              icon: const Icon(Icons.edit_outlined),
              label: Text(S.of(context).labelManualEntry),
            ),
          ],
        ),
      ),
    );
  }
}

/// One editable label card in the confirm step.
///
/// The controllers are seeded once from [draft] in [initState] and then own the
/// text: re-seeding on every provider update would fight the cursor while the
/// user types. The card only reports changes upward — in each field's
/// **canonical** unit (kJ / mg), converting a typed 大卡 / 盐 value at this
/// input boundary.
///
/// The energy and sodium rows carry a unit dropdown (kJ ⇄ 大卡, mg ⇄ 盐 g).
/// Switching a unit never writes to the draft: it only re-derives the text
/// from the draft's canonical value, so a kJ → 大卡 → kJ round trip is
/// lossless. (If the last typed text was unparseable — and therefore never
/// reached the draft — switching replaces it with the draft's value.)
class _LabelDraftCard extends ConsumerStatefulWidget {
  const _LabelDraftCard({
    super.key,
    required this.index,
    required this.draft,
    required this.hasPhoto,
    required this.initialEnergyUnit,
    required this.initialSaltUnit,
  });

  final int index;
  final LabelDraft draft;

  /// Whether a photo exists (only then is the name helper about the AI guess
  /// accurate; manual entry has no photo to infer from).
  final bool hasPhoto;

  /// The energy row's starting input unit: the display preference for manual
  /// entry, the printed kJ for a photo-confirmed label.
  final EnergyDisplay initialEnergyUnit;

  /// The sodium row's starting input unit: the display preference for manual
  /// entry, the printed mg for a photo-confirmed label.
  final SaltDisplay initialSaltUnit;

  @override
  ConsumerState<_LabelDraftCard> createState() => _LabelDraftCardState();
}

class _LabelDraftCardState extends ConsumerState<_LabelDraftCard> {
  late final TextEditingController _name;
  late final TextEditingController _brand;
  late final TextEditingController _notes;
  late final Map<LabelField, TextEditingController> _fields;
  late EnergyDisplay _energyUnit;
  late SaltDisplay _saltUnit;

  @override
  void initState() {
    super.initState();
    _energyUnit = widget.initialEnergyUnit;
    _saltUnit = widget.initialSaltUnit;
    _name = TextEditingController(text: widget.draft.name);
    _brand = TextEditingController(text: widget.draft.brand);
    _notes = TextEditingController(text: widget.draft.notes);
    _fields = <LabelField, TextEditingController>{
      for (final LabelField field in LabelField.values)
        field: TextEditingController(text: _fieldText(field)),
    };
  }

  @override
  void dispose() {
    _name.dispose();
    _brand.dispose();
    _notes.dispose();
    for (final TextEditingController controller in _fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  /// The current value of [field] expressed in the row's selected input unit
  /// (kJ / whole kcal for energy, mg / salt g for sodium), or `null` when
  /// blank. The draft stores the canonical unit only.
  double? _inputValueOf(LabelField field) {
    final double? canonical = widget.draft.valueOf(field);
    if (canonical == null) {
      return null;
    }
    if (field == LabelField.energy) {
      return _energyUnit == EnergyDisplay.kj
          ? canonical
          : kJToKcal(canonical).toDouble();
    }
    if (field == LabelField.sodium) {
      return _saltUnit == SaltDisplay.sodium
          ? canonical
          : sodiumMgToSaltG(canonical);
    }
    return canonical;
  }

  /// Formats [field]'s value for its text field: blank for `null`, no trailing
  /// `.0` for whole numbers. Energy in kcal renders as an integer — energy is
  /// whole-kcal only in this app.
  String _fieldText(LabelField field) {
    final double? value = _inputValueOf(field);
    if (value == null) {
      return '';
    }
    if (field == LabelField.energy && _energyUnit == EnergyDisplay.kcal) {
      return AppFormat.integer(value);
    }
    return AppFormat.number(value);
  }

  /// Converts a typed non-negative [input] from the row's selected unit into
  /// the draft's canonical unit (kJ for energy, mg for sodium) — the one
  /// conversion between a typed 大卡 / 盐 value and the stored kJ / mg.
  double _toCanonical(LabelField field, double input) {
    if (field == LabelField.energy && _energyUnit == EnergyDisplay.kcal) {
      return kcalInputToKJ(input);
    }
    if (field == LabelField.sodium && _saltUnit == SaltDisplay.salt) {
      return saltGToSodiumMg(input);
    }
    return input;
  }

  /// Reports a text edit upward in the canonical unit: blank clears the value,
  /// unparseable text is ignored (the stale text is corrected by the next unit
  /// switch), everything else is converted via [_toCanonical].
  void _onFieldChanged(
    LabelCaptureController controller,
    LabelField field,
    String text,
  ) {
    final String trimmed = text.trim();
    if (trimmed.isEmpty) {
      controller.updateFieldValue(widget.index, field, null);
      return;
    }
    final double? parsed = double.tryParse(trimmed);
    if (parsed == null || !parsed.isFinite || parsed < 0) {
      return;
    }
    controller.updateFieldValue(
      widget.index,
      field,
      _toCanonical(field, parsed),
    );
  }

  /// Switches the energy row's input unit and re-derives its text from the
  /// draft's canonical kJ. The draft is never written here, so a kJ → 大卡 →
  /// kJ round trip is lossless.
  void _switchEnergyUnit(EnergyDisplay unit) {
    setState(() {
      _energyUnit = unit;
      _fields[LabelField.energy]!.text = _fieldText(LabelField.energy);
    });
  }

  /// Switches the sodium row's input unit (mg ⇄ 盐 g) and re-derives its text
  /// from the draft's canonical mg.
  void _switchSaltUnit(SaltDisplay unit) {
    setState(() {
      _saltUnit = unit;
      _fields[LabelField.sodium]!.text = _fieldText(LabelField.sodium);
    });
  }

  /// The input decoration for [field]'s row. The two dual-unit rows name only
  /// the substance (能量 / 钠⇄盐) and carry the unit in a suffix dropdown; the
  /// other rows keep the full GB 28050 declaration (label + printed unit).
  InputDecoration _fieldDecoration(BuildContext context, LabelField field) {
    final S strings = S.of(context);
    if (field == LabelField.energy) {
      return InputDecoration(
        labelText: strings.labelFieldEnergy,
        suffixIcon: _unitDropdown<EnergyDisplay>(
          key: labelEnergyUnitKey(widget.index),
          value: _energyUnit,
          labels: <EnergyDisplay, String>{
            EnergyDisplay.kj: strings.unitKJ,
            EnergyDisplay.kcal: strings.unitKcal,
          },
          onChanged: _switchEnergyUnit,
        ),
        helperText: _energyHelperText(context),
      );
    }
    if (field == LabelField.sodium) {
      return InputDecoration(
        labelText: _saltUnit == SaltDisplay.salt
            ? strings.labelSalt
            : strings.labelSodium,
        suffixIcon: _unitDropdown<SaltDisplay>(
          key: labelSaltUnitKey(widget.index),
          value: _saltUnit,
          labels: <SaltDisplay, String>{
            SaltDisplay.sodium: strings.unitMg,
            SaltDisplay.salt: strings.unitG,
          },
          onChanged: _switchSaltUnit,
        ),
      );
    }
    return InputDecoration(
      labelText: strings.fieldLabelFullWidth(field.label, field.unit),
    );
  }

  /// The energy row's helper: the equivalent in the *other* unit (kcal under a
  /// kJ input, kJ under a 大卡 input), or the hint when energy is blank.
  String? _energyHelperText(BuildContext context) {
    final double? kJ = widget.draft.energyKj;
    if (kJ == null) {
      return S.of(context).labelEnergyBlankHint;
    }
    return _energyUnit == EnergyDisplay.kj
        ? S.of(context).foodEnergyApprox(widget.draft.energyKcal!.toString())
        : S.of(context).foodEnergyKjApprox(AppFormat.integer(kJ));
  }

  /// The compact unit dropdown rendered in a row's suffix.
  Widget _unitDropdown<T extends Object>({
    required Key key,
    required T value,
    required Map<T, String> labels,
    required ValueChanged<T> onChanged,
  }) {
    return DropdownButtonHideUnderline(
      child: DropdownButton<T>(
        key: key,
        value: value,
        isDense: true,
        borderRadius: BorderRadius.circular(8),
        items: <DropdownMenuItem<T>>[
          for (final MapEntry<T, String> label in labels.entries)
            DropdownMenuItem<T>(value: label.key, child: Text(label.value)),
        ],
        onChanged: (T? selected) {
          if (selected != null) {
            onChanged(selected);
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final LabelCaptureController controller = ref.read(
      labelCaptureControllerProvider.notifier,
    );
    final String name = _name.text.trim();
    return Card(
      color: widget.draft.included
          ? null
          : theme.colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    S.of(context).labelCardTitle(widget.index + 1),
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                Flexible(
                  child: Text(
                    S.of(context).labelInclude,
                    style: theme.textTheme.bodySmall,
                    textAlign: TextAlign.end,
                  ),
                ),
                Switch(
                  key: labelIncludeSwitchKey(widget.index),
                  value: widget.draft.included,
                  onChanged: (bool value) =>
                      controller.setIncluded(widget.index, value),
                ),
              ],
            ),
            if (!widget.draft.included)
              Text(
                S.of(context).labelIncludeHint,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            const SizedBox(height: 8),
            TextField(
              key: labelNameFieldKey(widget.index),
              controller: _name,
              decoration: InputDecoration(
                labelText: S.of(context).labelFoodName,
                hintText: S.of(context).labelFoodNameHint,
                helperText: widget.hasPhoto && name.isNotEmpty
                    ? S.of(context).labelFoodNameFromImage
                    : null,
              ),
              onChanged: (String value) =>
                  controller.updateName(widget.index, value),
            ),
            const SizedBox(height: 12),
            TextField(
              key: labelNotesFieldKey(widget.index),
              controller: _notes,
              minLines: 1,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: S.of(context).labelNotes,
                hintText: S.of(context).labelNotesHint,
              ),
              onChanged: (String value) =>
                  controller.updateNotes(widget.index, value),
            ),
            const SizedBox(height: 12),
            TextField(
              key: labelBrandFieldKey(widget.index),
              controller: _brand,
              decoration: InputDecoration(
                labelText: S.of(context).labelBrand,
                hintText: S.of(context).labelBrandHint,
              ),
              onChanged: (String value) =>
                  controller.updateBrand(widget.index, value),
            ),
            const SizedBox(height: 12),
            for (final LabelField field in LabelField.values)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: TextField(
                  key: labelFieldKey(widget.index, field),
                  controller: _fields[field],
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: _fieldDecoration(context, field),
                  onChanged: (String value) =>
                      _onFieldChanged(controller, field, value),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
