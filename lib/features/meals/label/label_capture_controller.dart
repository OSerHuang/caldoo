/// State + pipeline for the nutrition-label capture flow.
///
/// The flow is deliberately staged so a label can never be saved unconfirmed:
///
/// `pick` -> [LabelCaptureController.pickPhoto] -> `ready` ->
/// [LabelCaptureController.parse] (task-14 client + task-16 `labelPhotoPrompt`
/// + task-15 `LabelParse`) -> `confirm` (the user reviews and edits every
/// GB 28050 field for **every** label in the photo) ->
/// [LabelCaptureController.save] -> `saved` (one [Food] with
/// `source: FoodSource.label` per confirmed label).
///
/// A photo may contain several 营养成分表, so the parsed result is a list of
/// [LabelDraft]s and the confirm screen renders one card per label. The user's
/// supplementary text ("一包 45 g；别名：小饼干") is sent to the model as a hint
/// and pre-filled into each label's notes; it is saved on the [Food] so it can
/// be searched later.
///
/// Blank-safety: every nutrient in [LabelDraft] is nullable and [save] maps a
/// blank straight to a `null` [Food] field — it never substitutes `0`. Energy
/// is converted exactly once, from the printed kJ to canonical kcal, via
/// [LabelDraft.energyKcal] (the single [kJToKcal] definition).
library;

import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import 'package:caldoo/ai/ai_client.dart';
import 'package:caldoo/ai/prompts/prompts.dart';
import 'package:caldoo/ai/schemas/label_parse.dart';
import 'package:caldoo/core/providers/app_providers.dart';
import 'package:caldoo/domain/models/food.dart';
import 'package:caldoo/domain/services/label_priority.dart'
    show parseFoodAliases, parseFoodServings;
import 'package:caldoo/features/meals/capture/image_codec.dart';
import 'package:caldoo/features/settings/settings_providers.dart'
    show aiClientProvider, aiSettingsConfigProvider;
// Reuse the one exhaustive AiError -> zh-CN message map (task 17) instead of
// duplicating the sealed-taxonomy switch here.
import 'package:caldoo/features/settings/ai_error_text.dart'
    show describeAiError;
import 'package:caldoo/l10n/app_strings.dart';

import 'label_draft.dart';

/// Where a label photo comes from.
///
/// Both lanes go through `image_picker` (the camera lane launches the system
/// camera), then commit to the same bounded codec path before recognition.
enum LabelPhotoLane {
  /// Take a new photo with the device camera.
  camera,

  /// Pick an existing image from the gallery.
  gallery,
}

/// Picks one photo from [lane] and returns its raw source bytes, or `null` on
/// cancel.
typedef LabelPhotoSource = Future<Uint8List?> Function(LabelPhotoLane lane);

/// Mints a fresh [Food.id] for a saved label.
typedef LabelIdGenerator = String Function();

/// Production photo lane. Never called under `flutter test` because tests
/// override [labelPhotoSourceProvider].
///
/// The camera lane uses `image_picker`'s system-camera intent, exactly like the
/// meal capture screen; it needs no CAMERA permission in our manifest and no
/// extra runtime grant.
Future<Uint8List?> _pick(ImageSource source) async {
  final XFile? picked = await ImagePicker().pickImage(source: source);
  return picked?.readAsBytes();
}

/// The photo source seam; tests override with a fake feeding fixture bytes.
final labelPhotoSourceProvider = Provider<LabelPhotoSource>(
  (ref) =>
      (LabelPhotoLane lane) => _pick(
        lane == LabelPhotoLane.camera
            ? ImageSource.camera
            : ImageSource.gallery,
      ),
);

/// The id seam; overridable so tests get deterministic [Food.id]s.
final labelIdGeneratorProvider = Provider<LabelIdGenerator>(
  (ref) =>
      () => const Uuid().v4(),
);

/// Where the capture flow is.
enum LabelStage {
  /// No photo picked yet.
  pick,

  /// A photo is picked and can be parsed.
  ready,

  /// The AI parse request is in flight.
  parsing,

  /// Parsed values are on screen awaiting confirmation/edits.
  confirm,

  /// The food(s) were saved.
  saved,

  /// The parse/save failed; [LabelCaptureState.error] explains why.
  failed,
}

/// Immutable label-capture view state.
class LabelCaptureState {
  const LabelCaptureState({
    this.stage = LabelStage.pick,
    this.photoBytes,
    this.extraNote = '',
    this.drafts = const <LabelDraft>[],
    this.error,
    this.saved = const <Food>[],
    this.editTarget,
  });

  final LabelStage stage;

  /// The picked photo's raw bytes, kept for the preview/thumbnail.
  final Uint8List? photoBytes;

  /// The user's supplementary text from the pick step.
  ///
  /// Sent to the model as a hint and pre-filled into every parsed label's
  /// notes. Empty when the user typed nothing.
  final String extraNote;

  /// One editable draft per label found in the photo (empty before parsing).
  final List<LabelDraft> drafts;

  /// Human-readable failure message (never contains an API key).
  final String? error;

  /// The persisted foods, once [LabelStage.saved] is reached.
  final List<Food> saved;

  /// The stored food being edited in place (the edit-nutrients flow), or
  /// `null` in the normal capture flow.
  ///
  /// Only [startEdit] sets it and only [reset] clears it, so [copyWith] never
  /// needs to null it out.
  final Food? editTarget;

  /// `true` while the parse request is in flight.
  bool get parsing => stage == LabelStage.parsing;

  /// `true` when the confirm form (with the parsed values) is on screen.
  bool get confirming => stage == LabelStage.confirm;

  /// `true` when the flow edits an existing food instead of capturing a new
  /// one: the screen trims the photo/AI/batch affordances accordingly.
  bool get editing => editTarget != null;

  /// `true` when at least one label draft is marked for saving.
  bool get hasIncludedDraft => drafts.any((LabelDraft draft) => draft.included);

  LabelCaptureState copyWith({
    LabelStage? stage,
    Uint8List? photoBytes,
    String? extraNote,
    List<LabelDraft>? drafts,
    String? error,
    List<Food>? saved,
    Food? editTarget,
  }) {
    return LabelCaptureState(
      stage: stage ?? this.stage,
      photoBytes: photoBytes ?? this.photoBytes,
      extraNote: extraNote ?? this.extraNote,
      drafts: drafts ?? this.drafts,
      error: error,
      saved: saved ?? this.saved,
      editTarget: editTarget ?? this.editTarget,
    );
  }
}

/// Drives pick -> parse -> confirm -> save.
class LabelCaptureController extends Notifier<LabelCaptureState> {
  @override
  LabelCaptureState build() => const LabelCaptureState();

  /// Clears the flow back to the first step ([LabelStage.pick]).
  ///
  /// The provider is intentionally **not** `autoDispose`: disposing mid-flight
  /// would throw when the notifier is used after an async AI parse completes,
  /// and the screen is re-entered by `context.push`, which recreates its
  /// `State` rather than the provider. So the screen resets the state
  /// explicitly on entry instead.
  void reset() {
    state = const LabelCaptureState();
  }

  /// Picks a photo from [lane] through the injected [labelPhotoSourceProvider].
  /// A cancel leaves the state untouched; a picked photo moves to
  /// [LabelStage.ready].
  ///
  /// The raw bytes are kept in state so the pick step can show a preview: the
  /// user must be able to confirm the right photo was selected before spending
  /// an AI call. A re-pick keeps the typed supplementary note.
  Future<void> pickPhoto(LabelPhotoLane lane) async {
    final Uint8List? raw = await ref.read(labelPhotoSourceProvider)(lane);
    if (raw == null) {
      return;
    }
    state = state.copyWith(
      stage: LabelStage.ready,
      photoBytes: raw,
      drafts: const <LabelDraft>[],
      error: null,
    );
  }

  /// Records the user's supplementary text (food name, package size, aliases).
  ///
  /// Only the text is stored here; it is read at [parse] time, so the user can
  /// keep editing it until the recognition starts.
  void setExtraNote(String note) {
    state = state.copyWith(extraNote: note, error: null);
  }

  /// Sends the picked photo through the AI client with the label prompt and
  /// maps the strict tool arguments with [LabelParse].
  ///
  /// The photo may contain one or more labels; every parsed item becomes a
  /// [LabelDraft], pre-filled with the model's food name/brand guess and the
  /// user's supplementary note.
  Future<void> parse() async {
    final Uint8List? bytes = state.photoBytes;
    if (bytes == null || state.parsing) {
      return;
    }
    state = state.copyWith(stage: LabelStage.parsing, error: null);
    final PreparedPhoto? prepared = prepare(bytes);
    if (prepared == null) {
      state = state.copyWith(
        stage: LabelStage.failed,
        error: S.instance.errorPhotoDecode,
      );
      return;
    }
    try {
      // Cold-start guard: read the client only after the saved config has
      // loaded, or the request would carry the user's key to the default
      // endpoint (same guard as saveAndTestConnection).
      await ref.read(aiSettingsConfigProvider.future);
      final AiClient client = ref.read(aiClientProvider);
      final String arguments = await client.completeWithTool(
        messages: labelPhotoPrompt(
          userNote: state.extraNote,
        ).toMessages(images: <AiImagePart>[AiImagePart(prepared.base64Data)]),
        toolName: labelParseToolName,
        parameters: labelParseToolParameters,
      );
      final LabelParse parse = LabelParse.fromToolArguments(arguments);
      final List<LabelDraft> drafts = <LabelDraft>[
        for (final LabelParseItem item in parse.labels)
          LabelDraft.fromParse(item, notes: state.extraNote.trim()),
      ];
      if (drafts.isEmpty) {
        // The schema guarantees at least one label; this is defense in depth.
        state = state.copyWith(
          stage: LabelStage.failed,
          error: S.instance.labelRecognizeFailed,
        );
        return;
      }
      state = state.copyWith(stage: LabelStage.confirm, drafts: drafts);
    } on AiError catch (error) {
      state = state.copyWith(
        stage: LabelStage.failed,
        error: describeAiError(error),
      );
    }
  }

  /// Seeds the confirm form directly with [drafts], without an AI round-trip.
  ///
  /// Used by tests to exercise partial/multiple labels. It never fabricates
  /// values: whatever is `null` in a draft stays blank.
  void seedDrafts(List<LabelDraft> drafts) {
    state = state.copyWith(
      stage: LabelStage.confirm,
      drafts: List<LabelDraft>.of(drafts),
      error: null,
    );
  }

  /// Seeds a single-draft confirm form directly (the manual-entry path/tests).
  void seedDraft(LabelDraft draft) => seedDrafts(<LabelDraft>[draft]);

  /// Opens a blank confirm form for manual entry, carrying the supplement text.
  ///
  /// This is the path that must keep working offline (draft G7).
  void startManualEntry() {
    seedDraft(LabelDraft(notes: state.extraNote.trim()));
  }

  /// Seeds the confirm form with the stored values of [food] for an in-place
  /// edit (the food detail page's 编辑数值 action).
  ///
  /// The save then replaces the same record ([FoodRepository.upsertFood] is a
  /// full-row replace): id, source, aliases, servings, status and basis
  /// survive from [food]; name / brand and the seven nutrients come from the
  /// form, and a blank field clears the stored value to SQL NULL (no fake
  /// zeros). The notes field is hidden in this mode — 备注 / 别名 / 份量 belong
  /// to the notes editor — so nothing re-parses prose into structured
  /// aliases here.
  void startEdit(Food food) {
    state = state.copyWith(
      stage: LabelStage.confirm,
      drafts: <LabelDraft>[LabelDraft.fromFood(food)],
      editTarget: food,
      error: null,
    );
  }

  /// Updates the [index]-th draft's display name.
  void updateName(int index, String name) =>
      _updateDraft(index, (LabelDraft draft) => draft.withName(name));

  /// Updates the [index]-th draft's brand.
  void updateBrand(int index, String brand) =>
      _updateDraft(index, (LabelDraft draft) => draft.withBrand(brand));

  /// Updates the [index]-th draft's notes (package size / aliases / remarks).
  void updateNotes(int index, String notes) =>
      _updateDraft(index, (LabelDraft draft) => draft.withNotes(notes));

  /// Marks the [index]-th draft as included in / excluded from the batch save.
  void setIncluded(int index, bool included) =>
      _updateDraft(index, (LabelDraft draft) => draft.withIncluded(included));

  /// Sets one edited [field] of the [index]-th draft from an already-canonical
  /// value (`null` clears it).
  ///
  /// The confirm card owns the text controllers and converts the typed text
  /// into the canonical unit before calling this: energy arrives in kJ (a typed
  /// 大卡 is multiplied out at the card, see [kcalInputToKJ]) and sodium arrives
  /// in mg (a typed 盐 gram via [saltGToSodiumMg]). Non-finite or negative
  /// values are ignored, exactly like unparseable text was before.
  void updateFieldValue(int index, LabelField field, double? value) {
    if (value != null && (!value.isFinite || value < 0)) {
      return;
    }
    _updateDraft(index, (LabelDraft draft) => draft.withValue(field, value));
  }

  void _updateDraft(int index, LabelDraft Function(LabelDraft) change) {
    if (index < 0 || index >= state.drafts.length) {
      return;
    }
    final List<LabelDraft> drafts = List<LabelDraft>.of(state.drafts);
    drafts[index] = change(drafts[index]);
    state = state.copyWith(drafts: drafts, error: null);
  }

  /// Validates and persists the included drafts.
  ///
  /// In the capture flow every included draft becomes a `source: label` [Food]
  /// with a fresh id; in the edit flow ([startEdit]) the single draft replaces
  /// the stored record in place (same id and source; aliases / servings /
  /// status / basis survive; a blank nutrient clears the stored value).
  ///
  /// Returns `true` on success. A blank name on an included label is a
  /// validation error (the plan forbids saving a label without user
  /// confirmation; a name is the minimum human-facing confirmation). Blank
  /// nutrients stay `null`; blank brand/notes stay `null` too.
  Future<bool> save() async {
    if (!state.confirming) {
      return false;
    }
    final List<LabelDraft> included = <LabelDraft>[
      for (final LabelDraft draft in state.drafts)
        if (draft.included) draft,
    ];
    if (included.isEmpty) {
      state = state.copyWith(error: S.instance.errorLabelSelectAtLeastOne);
      return false;
    }
    for (int i = 0; i < included.length; i++) {
      if (included[i].name.trim().isEmpty) {
        state = state.copyWith(
          error: included.length == 1
              ? S.instance.errorLabelFoodNameRequired
              : S.instance.errorLabelFoodNameRequiredAt(i + 1),
        );
        return false;
      }
    }
    final Food? target = state.editTarget;
    final List<Food> foods = <Food>[
      if (target != null)
        _foodFromEditDraft(included.first, target)
      else
        for (final LabelDraft draft in included)
          _foodFromDraft(draft, ref.read(labelIdGeneratorProvider)()),
    ];
    try {
      for (final Food food in foods) {
        await ref.read(foodRepositoryProvider).upsertFood(food);
      }
    } catch (_) {
      state = state.copyWith(error: S.instance.errorSaveFailed);
      return false;
    }
    state = state.copyWith(stage: LabelStage.saved, saved: foods, error: null);
    return true;
  }

  /// Builds the saved [Food] for one confirmed draft.
  ///
  /// The free-text supplement typed on the pick step is parsed once into the
  /// structured selection surface ([Food.aliases] / [Food.servings]), so the
  /// label-link index never has to re-parse prose for a freshly captured label;
  /// the original text is still stored in [Food.notes] for the user.
  Food _foodFromDraft(LabelDraft draft, String id) {
    final String? notes = _blankToNull(draft.notes);
    return Food(
      id: id,
      name: draft.name.trim(),
      brand: _blankToNull(draft.brand),
      // The typed text is a transient hint: it becomes structured aliases /
      // servings and is not stored as a 备注 (that field is retired).
      aliases: _mergeAliases(draft.aliases, parseFoodAliases(notes)),
      servings: parseFoodServings(notes),
      source: FoodSource.label,
      kcal: draft.energyKcal,
      carbG: draft.carbohydrateG,
      proteinG: draft.proteinG,
      fatG: draft.fatG,
      sugarG: draft.sugarG,
      saturatedFatG: draft.saturatedFatG,
      sodiumMg: draft.sodiumMg,
    );
  }

  /// Builds the replacement [Food] for an edit: identity and the seven
  /// nutrients come from the form, everything the form does not own (id,
  /// source, aliases, servings, status, basis, notes, barcode) survives from
  /// [original], and a blank nutrient clears its stored value.
  Food _foodFromEditDraft(LabelDraft draft, Food original) {
    return Food(
      id: original.id,
      name: draft.name.trim(),
      brand: _blankToNull(draft.brand),
      barcode: original.barcode,
      aliases: original.aliases,
      servings: original.servings,
      status: original.status,
      basis: original.basis,
      notes: original.notes,
      source: original.source,
      kcal: draft.energyKcal,
      carbG: draft.carbohydrateG,
      proteinG: draft.proteinG,
      fatG: draft.fatG,
      sugarG: draft.sugarG,
      saturatedFatG: draft.saturatedFatG,
      sodiumMg: draft.sodiumMg,
    );
  }

  /// Merges the model's aliases with the ones parsed from the user's note:
  /// blanks dropped, duplicates collapsed (the model's alias wins), order kept.
  static List<String> _mergeAliases(
    List<String> parsed,
    List<String> fromNote,
  ) {
    final List<String> merged = <String>[];
    for (final String alias in <String>[...parsed, ...fromNote]) {
      final String trimmed = alias.trim();
      if (trimmed.isNotEmpty && !merged.contains(trimmed)) {
        merged.add(trimmed);
      }
    }
    return merged;
  }

  /// Trims [value] and maps a blank to `null` (blank never becomes `''`).
  static String? _blankToNull(String value) {
    final String trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}

/// The label-capture controller.
final labelCaptureControllerProvider =
    NotifierProvider<LabelCaptureController, LabelCaptureState>(
      LabelCaptureController.new,
    );
