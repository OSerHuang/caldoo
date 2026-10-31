/// The AI review/edit screen (task 19): the only door from an AI estimate to
/// the database.
///
/// Every AI result is an [AiMealDraft]; nothing is persisted until the user has
/// seen and edited it here and tapped 保存. The screen renders one
/// [ReviewItemCard] per item, recomputes the meal totals live, refuses to save
/// an empty / unnamed meal, and only then calls
/// [MealRepository.saveMealWithItems].
///
/// The same form also **edits an already saved meal** (`/meal/:id/edit`, the
/// 餐食详情 page's 编辑 action): [MealReviewScreen.editing] switches the save
/// to [MealRepository.updateMealWithItems] and the banner copy. An edit
/// payload carries no capture inputs, so the AI-correction panel below never
/// renders and the background label link never fires — editing stays fully
/// local and offline.
///
/// The draft banner is always visible: ["AI 估算，可修改"] on the capture path,
/// the editing copy in edit mode. A malformed AI
/// draft (a [AiMealDraft.warning] with no items) shows the error banner over a
/// blank editable row instead of losing the meal.
///
/// When the capture inputs are known ([MealReviewScreen.photos] /
/// [MealReviewScreen.userText]), the screen also offers an **AI correction
/// panel**: the user explains what the recognition got wrong, and the AI
/// re-estimates the meal with the same photos, the estimate currently on screen
/// and the correction note. A revision replaces the whole draft, so it asks for
/// confirmation first when the user has already edited something; a failed
/// revision keeps the draft untouched and shows the reactive error. Saving a
/// meal never depends on any of this.
///
/// A **text-only** capture also runs a background label-link call that matches
/// the items against the saved-food library (`label_linker.dart`, see
/// `design/label-linking.md`). A validated match is auto-applied to untouched
/// rows (name, per-100 g nutrients, and a serving-count gram correction), with
/// an immediate 撤销 / 更换 path on the row; rows the user edited only get the
/// candidates as chips. A link failure is never fatal — the pre-link lexical
/// suggestions remain — and every late result is dropped if the draft has been
/// replaced or the screen is gone.
///
/// A **photo** capture deliberately never matches the library: a photographed
/// dish usually has no label behind it, and forcing a match would replace the
/// AI's kcal/macros with an unrelated saved food. Those rows show the AI
/// estimate only; the per-row 「选择已存食物」 button is still there for the user
/// to attach a label by hand.
library;

import 'dart:async' show Timer, unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:caldoo/ai/ai_client.dart' show AiError;
import 'package:caldoo/ai/schemas/label_link.dart'
    show LabelLinkResult, LabelMatch;
import 'package:caldoo/ai/schemas/meal_analysis.dart' show MealAnalysis;
import 'package:caldoo/core/providers/app_providers.dart';
import 'package:caldoo/core/units/display_units.dart';
import 'package:caldoo/domain/models/models.dart';
import 'package:caldoo/domain/services/label_linking.dart'
    show LabelApplyAction, LabelApplyDecision, decideLabelApply;
import 'package:caldoo/features/meals/capture/image_codec.dart'
    show PreparedPhoto;
import 'package:caldoo/features/meals/saved_foods/saved_food_picker.dart';
import 'package:caldoo/features/offline/offline_ui.dart';
import 'package:caldoo/l10n/app_format.dart';
import 'package:caldoo/l10n/app_strings.dart';

import 'label_linker.dart';
import 'linked_label_view.dart';
import 'meal_item_mapping.dart';
import 'meal_review_draft.dart';
import 'meal_revision.dart';
import 'review_item_card.dart';

/// The always-on reminder that the numbers are estimates the user may change.
const String reviewAiBannerText = S.reviewAiBannerConst;

/// Offline notice on the review screen: a revision needs the network, while
/// editing and saving stay local, so the screen states exactly that.
const String reviewOfflineNotice = S.reviewOfflineNoticeConst;

/// Key of the review screen's offline notice.
const Key reviewOfflineHintKey = Key('review_offline_hint');

/// Key of the AI-estimate banner.
const Key reviewAiBannerKey = Key('review_ai_banner');

/// Key of the degradation/error banner for a malformed draft.
const Key reviewWarningBannerKey = Key('review_warning_banner');

/// Key of the AI-correction panel.
const Key reviewRevisionCardKey = Key('review_revision_card');

/// Key of the AI-correction note field.
const Key reviewCorrectionFieldKey = Key('review_correction_field');

/// Key of the "让 AI 重新估算" button.
const Key reviewReviseButtonKey = Key('review_revise_button');

/// Key of the reactive error shown after a failed revision.
const Key reviewReviseErrorKey = Key('review_revise_error');

/// Key of the overwrite-confirmation dialog.
const Key reviewReviseDialogKey = Key('review_revise_dialog');

/// Key of the overwrite-confirmation "继续" action.
const Key reviewReviseConfirmKey = Key('review_revise_confirm');

/// Key of the overwrite-confirmation "取消" action.
const Key reviewReviseCancelKey = Key('review_revise_cancel');

/// Key of the "add item" button.
const Key reviewAddItemButtonKey = Key('review_add_item_button');

/// Key of the save button.
const Key reviewSaveButtonKey = Key('review_save_button');

/// Key of the live meal-total energy value.
const Key reviewTotalKcalKey = Key('review_total_kcal');

/// Key of the live meal-total carbohydrate value.
const Key reviewTotalCarbKey = Key('review_total_carb');

/// Key of the live meal-total protein value.
const Key reviewTotalProteinKey = Key('review_total_protein');

/// Key of the live meal-total fat value.
const Key reviewTotalFatKey = Key('review_total_fat');

/// Key of the live meal-total salt value.
const Key reviewTotalSaltKey = Key('review_total_salt');

/// Mints a fresh [MealItem.id] for a user-added blank row.
typedef ReviewIdGenerator = String Function();

/// The id seam; overridable so widget tests get deterministic ids.
final reviewIdGeneratorProvider = Provider<ReviewIdGenerator>(
  (ref) =>
      () => const Uuid().v4(),
);

/// Review and edit one AI meal before saving it.
class MealReviewScreen extends ConsumerStatefulWidget {
  const MealReviewScreen({
    super.key,
    required this.draft,
    required this.meal,
    this.editing = false,
    this.photos = const <PreparedPhoto>[],
    this.userText = '',
  });

  /// The AI draft to review; items may be empty when the analysis degraded.
  final AiMealDraft draft;

  /// The owning meal record (id / timestamp / type) the items are saved under.
  final Meal meal;

  /// Whether this screen edits an **already saved** meal
  /// (`/meal/:id/edit`): the rows are the stored values, the save goes through
  /// [MealRepository.updateMealWithItems] and the banner speaks of editing, not
  /// of an AI estimate. The AI-correction panel and the background label link
  /// never apply here (an edit carries no capture inputs, so both are already
  /// off — this flag only owns the copy and the save path).
  final bool editing;

  /// The bounded photos the draft was produced from (empty for text-only).
  ///
  /// Only used to re-run the AI with a correction; a review payload built by
  /// hand (deep links, tests) may carry none.
  final List<PreparedPhoto> photos;

  /// The text the user typed at capture time, or an empty string.
  final String userText;

  @override
  ConsumerState<MealReviewScreen> createState() => _MealReviewScreenState();
}

class _MealReviewScreenState extends ConsumerState<MealReviewScreen> {
  late MealReviewDraft _draft;

  final TextEditingController _correction = TextEditingController();

  String? _error;
  bool _saving = false;

  /// The non-fatal degradation notice shown above the rows.
  ///
  /// Seeded from the route payload, and cleared by a successful revision (the
  /// new draft is complete, so a stale "解析失败" banner would be a lie).
  String? _warning;

  /// A revision is in flight.
  bool _revising = false;

  /// The human-readable failure of the last revision, shown reactively.
  String? _revisionError;

  /// Whether the user changed anything since the draft was created/replaced.
  ///
  /// A revision overwrites the whole draft, so it only asks for confirmation
  /// when there is actually something to lose.
  bool _dirty = false;

  /// Background label-link results, keyed by review-row id.
  final Map<String, LinkedLabelView> _linkViews = <String, LinkedLabelView>{};

  /// `true` once the link call answered (even with no matches).
  ///
  /// A successful-but-empty answer suppresses the lexical fallback; a failure
  /// leaves it on, which is the pre-link behaviour.
  bool _linkCompleted = false;

  /// Guards against firing the link call twice for the same draft.
  bool _linkStarted = false;

  /// Bumped whenever the draft is replaced, so a result that arrives for an
  /// older draft is dropped instead of mutating rows it no longer describes.
  int _linkGeneration = 0;

  /// The catalogue the initial link call was rendered from.
  ///
  /// Re-links reuse it so `#food_index` keeps meaning the same food as the first
  /// answer; a mid-screen catalogue edit is picked up on the next draft.
  List<Food> _linkFoods = const <Food>[];

  /// Debounce timers for the per-row re-link after a name edit.
  final Map<String, Timer> _relinkTimers = <String, Timer>{};

  /// Whether this screen has capture inputs to re-estimate from.
  bool get _canRevise =>
      widget.photos.isNotEmpty || widget.userText.trim().isNotEmpty;

  /// Whether this capture may consult the saved-food library at all.
  ///
  /// Photo captures are prediction-only on purpose: a photo of a home-cooked
  /// dish rarely corresponds to a stored nutrition label, so a forced match
  /// replaces a perfectly usable estimate with an unrelated saved food (wrong
  /// name, wrong grams, wrong kcal). Only a text capture — where the user names
  /// a concrete product — is strong enough evidence to link. The manual
  /// 「选择已存食物」 button is unaffected: that match is the user's own choice.
  bool get _libraryMatchingEnabled => widget.photos.isEmpty;

  @override
  void initState() {
    super.initState();
    _warning = widget.draft.warning;
    _draft = MealReviewDraft(items: widget.draft.items);
    if (_draft.isEmpty) {
      // A malformed / empty draft still gets one editable row so the user can
      // fill the meal in rather than losing it.
      _draft.addBlankItem(ref.read(reviewIdGeneratorProvider)());
    }
    unawaited(_startLabelLink());
  }

  @override
  void dispose() {
    for (final Timer timer in _relinkTimers.values) {
      timer.cancel();
    }
    _relinkTimers.clear();
    _correction.dispose();
    super.dispose();
  }

  void _onChanged() {
    _dirty = true;
    setState(() {});
  }

  /// Removes [item] and marks the draft dirty (a revision would lose that too).
  void _removeItem(ReviewItem item) {
    _dirty = true;
    setState(() => _draft.removeAt(_draft.items.indexOf(item)));
  }

  /// Appends a blank row and marks the draft dirty.
  void _addItem() {
    _dirty = true;
    setState(() => _draft.addBlankItem(ref.read(reviewIdGeneratorProvider)()));
  }

  // ---------------------------------------------------------------------------
  // Label linking (analyze-then-link)
  // ---------------------------------------------------------------------------

  /// Runs the background link call once per draft.
  ///
  /// Best-effort by design: a failure (no key, offline, malformed answer) just
  /// leaves the rows with the AI estimate and the lexical fallback, so this
  /// never throws into the UI. The call needs capture input to be meaningful:
  /// a review payload built by hand (deep link, test) has nothing to match, and
  /// a photo capture is deliberately prediction-only (see
  /// [_libraryMatchingEnabled]) — neither reaches the library.
  Future<void> _startLabelLink() async {
    if (_linkStarted ||
        _draft.isEmpty ||
        !_canRevise ||
        !_libraryMatchingEnabled) {
      return;
    }
    _linkStarted = true;
    final int generation = _linkGeneration;
    final List<Food> foods;
    try {
      foods = await ref.read(foodRepositoryProvider).getAllFoods();
    } catch (_) {
      return;
    }
    if (!mounted || foods.isEmpty) {
      return;
    }
    _linkFoods = foods;
    final List<MealItem> snapshot = <MealItem>[
      for (final ReviewItem item in _draft.items) item.base,
    ];
    try {
      final LabelLinkResult result = await ref.read(labelLinkerProvider)(
        items: snapshot,
        foods: foods,
        userText: widget.userText,
      );
      if (!mounted || _saving || generation != _linkGeneration) {
        return;
      }
      _applyLinkResult(result, snapshot, foods);
    } on Object {
      // Never fatal: keep the AI estimate + the lexical fallback.
    }
  }

  /// Writes [result] into the rows that are still untouched.
  void _applyLinkResult(
    LabelLinkResult result,
    List<MealItem> snapshot,
    List<Food> foods,
  ) {
    final Map<int, List<LabelMatch>> byItem = <int, List<LabelMatch>>{};
    for (final LabelMatch match in result.matches) {
      if (match.itemIndex < 0 || match.itemIndex >= snapshot.length) {
        continue;
      }
      if (match.foodIndex < 0 || match.foodIndex >= foods.length) {
        continue;
      }
      (byItem[match.itemIndex] ??= <LabelMatch>[]).add(match);
    }
    final Map<String, LinkedLabelView> views = <String, LinkedLabelView>{};
    var applied = false;
    for (final MapEntry<int, List<LabelMatch>> entry in byItem.entries) {
      final ReviewItem? row = _rowById(snapshot[entry.key].id);
      if (row == null) {
        continue;
      }
      // Keep the model's order, dedupe by food id and cap at three candidates.
      final List<Food> candidates = <Food>[];
      final List<LabelMatch> candidateMatches = <LabelMatch>[];
      for (final LabelMatch match in entry.value) {
        final Food food = foods[match.foodIndex];
        if (candidates.any((Food candidate) => candidate.id == food.id)) {
          continue;
        }
        candidates.add(food);
        candidateMatches.add(match);
        if (candidates.length == 3) {
          break;
        }
      }
      if (candidates.isEmpty) {
        continue;
      }
      final Food top = candidates.first;
      final LabelApplyDecision decision = decideLabelApply(
        item: snapshot[entry.key],
        food: top,
        match: candidateMatches.first,
        userEdited: row.userEdited,
        hasChosenFood: row.hasChosenFood,
        linkRejected: row.linkRejected,
      );
      if (decision.action == LabelApplyAction.autoApply &&
          !row.userEdited &&
          !row.hasChosenFood &&
          !row.linkRejected) {
        row.applyLinkedFood(top, name: top.name, grams: decision.grams);
        views[row.id] = LinkedLabelView(
          appliedFood: top,
          alternatives: candidates.skip(1).toList(growable: false),
          autoApplied: true,
        );
        applied = true;
      } else if (!row.hasChosenFood && !row.linkRejected) {
        // Edited rows (or implausible numbers) keep the candidates as chips.
        views[row.id] = LinkedLabelView(alternatives: candidates);
      }
    }
    setState(() {
      _linkCompleted = true;
      _linkViews.addAll(views);
      if (applied) {
        _dirty = true;
      }
    });
  }

  /// Schedules a debounced re-link for one row after its name changed.
  ///
  /// Only names that the user typed after the first answer can re-match; the
  /// call is text-only, reuses the first call's catalogue (so `food_index`
  /// stays stable) and deliberately **never auto-applies**: after a manual edit
  /// the user is the one who decides (design §5.1). A photo capture has no
  /// first answer and must stay prediction-only, so it never re-links either.
  void _onNameEdited(ReviewItem item) {
    if (!_libraryMatchingEnabled ||
        !_linkCompleted ||
        _linkFoods.isEmpty ||
        item.hasChosenFood) {
      return;
    }
    _relinkTimers[item.id]?.cancel();
    _relinkTimers[item.id] = Timer(const Duration(milliseconds: 700), () {
      _relinkTimers.remove(item.id);
      unawaited(_relinkItem(item));
    });
  }

  Future<void> _relinkItem(ReviewItem item) async {
    if (!mounted ||
        !_libraryMatchingEnabled ||
        item.hasChosenFood ||
        item.hasBlankName) {
      return;
    }
    final int generation = _linkGeneration;
    // Probe with the *current* name/grams: the link prompt only needs what the
    // user sees now, and the row keeps its identity for the result lookup.
    final MealItem probe = item.base.copyWith(
      name: item.name,
      grams: item.grams,
    );
    try {
      final LabelLinkResult result = await ref.read(labelLinkerProvider)(
        items: <MealItem>[probe],
        foods: _linkFoods,
        userText: widget.userText,
      );
      if (!mounted || generation != _linkGeneration) {
        return;
      }
      final List<Food> candidates = <Food>[];
      for (final LabelMatch match in result.matches) {
        if (match.itemIndex != 0) {
          continue;
        }
        if (match.foodIndex < 0 || match.foodIndex >= _linkFoods.length) {
          continue;
        }
        final Food food = _linkFoods[match.foodIndex];
        if (candidates.any((Food candidate) => candidate.id == food.id)) {
          continue;
        }
        candidates.add(food);
        if (candidates.length == 3) {
          break;
        }
      }
      setState(() {
        if (candidates.isEmpty) {
          // The corrected name matches nothing: drop stale candidates.
          _linkViews.remove(item.id);
        } else {
          _linkViews[item.id] = LinkedLabelView(alternatives: candidates);
        }
      });
    } on Object {
      // A failed re-link keeps the previous candidates; the row is untouched.
    }
  }

  ReviewItem? _rowById(String id) {
    for (final ReviewItem item in _draft.items) {
      if (item.id == id) {
        return item;
      }
    }
    return null;
  }

  /// Undoes an auto-applied match and returns the row to the AI estimate.
  void _undoLink(ReviewItem item) {
    if (!_linkViews.containsKey(item.id)) {
      return;
    }
    setState(() {
      item.undoLinkedFood();
      _linkViews.remove(item.id);
      _dirty = true;
    });
  }

  /// Opens the saved-food picker to replace the matched label (更换).
  Future<void> _changeLink(ReviewItem item) async {
    final Food? food = await SavedFoodPicker.push(context);
    if (food == null || !mounted) {
      return;
    }
    setState(() {
      item.chooseFood(food);
      // 更换 is a re-pick of the label, so the row name follows it just like an
      // auto-apply does; the manual adopted-food block then takes over.
      item.editName(food.name);
      _linkViews.remove(item.id);
      _dirty = true;
    });
  }

  /// Adopts one of the link's alternative candidates.
  void _applyLinkCandidate(ReviewItem item, Food food) {
    setState(() {
      item.adoptLinkedCandidate(food);
      final LinkedLabelView? view = _linkViews[item.id];
      if (view != null) {
        _linkViews[item.id] = view.withApplied(food);
      }
      _dirty = true;
    });
  }

  /// Asks the AI to re-estimate the meal from the same photos + the note.
  ///
  /// Returns silently when there is nothing to send (blank note / already
  /// running). A user edit triggers the overwrite confirmation first. On
  /// success the whole draft is replaced (fresh ids); on failure the draft is
  /// untouched and [_revisionError] drives the reactive retry message. The
  /// in-flight flag is always cleared, so a failed call can never leave the
  /// screen stuck behind a spinner or block saving.
  Future<void> _revise() async {
    final String note = _correction.text.trim();
    if (note.isEmpty || _revising || _saving) {
      return;
    }
    if (_dirty) {
      final bool? overwrite = await _confirmOverwrite();
      if (overwrite != true || !mounted) {
        return;
      }
    }
    setState(() {
      _revising = true;
      _revisionError = null;
    });
    try {
      final MealAnalysis revised = await ref.read(mealReviserProvider)(
        photos: widget.photos,
        userText: widget.userText,
        correctionNote: note,
        currentItems: _draft.effectiveItems,
      );
      if (!mounted || _saving) {
        // Saving always wins (draft G7): once the user committed the meal, a
        // late revision result is dropped instead of rewriting the draft.
        return;
      }
      final List<MealItem> items = mealItemsFromAnalysis(
        revised,
        idGenerator: ref.read(reviewIdGeneratorProvider),
      );
      setState(() {
        _draft = MealReviewDraft(items: items);
        _dirty = false;
        _error = null;
        _warning = null;
        // A fresh draft needs a fresh link result: the old rows are gone.
        _linkViews.clear();
        _linkCompleted = false;
        _linkStarted = false;
        _linkFoods = const <Food>[];
        for (final Timer timer in _relinkTimers.values) {
          timer.cancel();
        }
        _relinkTimers.clear();
        _linkGeneration++;
        // Keep anything typed while the call was in flight.
        if (_correction.text.trim() == note) {
          _correction.clear();
        }
      });
      unawaited(_startLabelLink());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.of(context).reviewReviseSuccess)),
      );
    } on AiError catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _revisionError = describeAiFailure(error));
    } on Object {
      // Never leave the screen stuck: any non-AI failure (e.g. a prompt
      // precondition or provider error) surfaces as a generic retry message.
      if (!mounted) {
        return;
      }
      setState(() => _revisionError = S.instance.reviewReviseFailed);
    } finally {
      if (mounted) {
        setState(() => _revising = false);
      }
    }
  }

  Future<bool?> _confirmOverwrite() {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        key: reviewReviseDialogKey,
        title: Text(S.of(dialogContext).reviewReviseOverwriteTitle),
        content: Text(S.of(dialogContext).reviewReviseOverwriteBody),
        actions: <Widget>[
          TextButton(
            key: reviewReviseCancelKey,
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(S.of(dialogContext).reviewReviseOverwriteCancel),
          ),
          FilledButton(
            key: reviewReviseConfirmKey,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(S.of(dialogContext).reviewReviseOverwriteConfirm),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (_saving) {
      return;
    }
    if (_draft.isEmpty) {
      setState(() => _error = S.instance.errorNeedAtLeastOneItem);
      return;
    }
    if (_draft.hasBlankName) {
      setState(() => _error = S.instance.errorFoodNameRequired);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (widget.editing) {
        // An edit of an already saved meal: the complete record replaces the
        // stored rows (a removed row must not survive).
        await ref
            .read(mealRepositoryProvider)
            .updateMealWithItems(widget.meal, _draft.effectiveItems);
      } else {
        await ref
            .read(mealRepositoryProvider)
            .saveMealWithItems(widget.meal, _draft.effectiveItems);
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _saving = false;
        _error = S.instance.errorSaveFailed;
      });
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() => _saving = false);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(S.of(context).savedSnack)));
    // `true` tells the capture screen the record is complete, so it can
    // clear the photos/text it still holds.
    await Navigator.of(context).maybePop(true);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    // Only the read-only 本餐合计 totals follow the display preference; the
    // editable item fields above stay canonical kcal / salt g on purpose.
    final DisplayUnits units = DisplayUnits.of(context);
    final bool offline = ref.watch(isOfflineProvider);
    return Scaffold(
      appBar: AppBar(title: Text(S.of(context).reviewTitle)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const AiOfflineNotice(
              noticeKey: reviewOfflineHintKey,
              text: reviewOfflineNotice,
            ),
            Container(
              key: reviewAiBannerKey,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                // An edit of a saved meal shows its stored values, so the
                // banner must not claim they are an AI estimate.
                widget.editing
                    ? S.of(context).reviewEditBanner
                    : reviewAiBannerText,
                style: TextStyle(color: theme.colorScheme.onPrimaryContainer),
              ),
            ),
            if (_warning != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                _warning!,
                key: reviewWarningBannerKey,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ],
            if (_canRevise) ...<Widget>[
              const SizedBox(height: 8),
              _buildRevisionPanel(context, offline: offline),
            ],
            const SizedBox(height: 8),
            // Editing is frozen while a revision is in flight: its whole
            // purpose is to replace this draft, so silently swallowing edits
            // made during the call would be worse than briefly blocking them.
            AbsorbPointer(
              absorbing: _revising,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  for (final ReviewItem item in _draft.items)
                    ReviewItemCard(
                      key: ValueKey<String>(item.id),
                      reviewItem: item,
                      onChanged: _onChanged,
                      onRemove: () => _removeItem(item),
                      linkView: _linkViews[item.id],
                      linkCompleted: _linkCompleted,
                      libraryMatchingEnabled: _libraryMatchingEnabled,
                      onUndoLink: () => _undoLink(item),
                      onChangeLink: () => _changeLink(item),
                      onApplyLinkCandidate: (Food food) =>
                          _applyLinkCandidate(item, food),
                      onNameEdited: () => _onNameEdited(item),
                    ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      key: reviewAddItemButtonKey,
                      onPressed: _addItem,
                      icon: const Icon(Icons.add),
                      label: Text(S.of(context).addFood),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 32),
            Card(
              color: theme.colorScheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      S.of(context).mealTotalsThis,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    _TotalRow(
                      label: S.of(context).labelEnergy,
                      unit: units.energyUnit,
                      valueKey: reviewTotalKcalKey,
                      value: units.energyValue(_draft.totalKcal),
                    ),
                    _TotalRow(
                      label: S.of(context).labelCarb,
                      unit: S.of(context).unitG,
                      valueKey: reviewTotalCarbKey,
                      value: _draft.totalCarbG,
                    ),
                    _TotalRow(
                      label: S.of(context).labelProtein,
                      unit: S.of(context).unitG,
                      valueKey: reviewTotalProteinKey,
                      value: _draft.totalProteinG,
                    ),
                    _TotalRow(
                      label: S.of(context).labelFat,
                      unit: S.of(context).unitG,
                      valueKey: reviewTotalFatKey,
                      value: _draft.totalFatG,
                    ),
                    _TotalRow(
                      label: units.saltLabel,
                      unit: units.saltUnit,
                      valueKey: reviewTotalSaltKey,
                      value: units.saltValueFromSaltG(_draft.totalSaltG),
                    ),
                  ],
                ),
              ),
            ),
            if (_error != null) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                _error!,
                key: const Key('review_error'),
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              key: reviewSaveButtonKey,
              // Saving never waits on the AI (draft G7): a save during a
              // revision wins and the late revision result is dropped.
              onPressed: _draft.canSave && !_saving ? _save : null,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(S.of(context).save),
            ),
          ],
        ),
      ),
    );
  }

  /// The AI-correction panel: note field + "让 AI 重新估算".
  ///
  /// The button is enabled only with a non-blank note and while online, and is
  /// disabled (with a spinner) during a call, so a double tap cannot send two
  /// revisions. A failure is shown under the button and keeps the draft.
  Widget _buildRevisionPanel(BuildContext context, {required bool offline}) {
    final ThemeData theme = Theme.of(context);
    return Card(
      key: reviewRevisionCardKey,
      color: theme.colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              S.of(context).reviewCorrectionTitle,
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            TextField(
              key: reviewCorrectionFieldKey,
              controller: _correction,
              enabled: !_revising,
              minLines: 1,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: S.of(context).reviewCorrectionLabel,
                hintText: S.of(context).reviewCorrectionHint,
                helperText: S.of(context).reviewCorrectionHelp,
                helperMaxLines: 2,
                prefixIcon: const Icon(Icons.edit_note),
              ),
            ),
            const SizedBox(height: 8),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _correction,
              builder: (BuildContext context, TextEditingValue value, _) {
                final bool canRevise =
                    value.text.trim().isNotEmpty &&
                    !offline &&
                    !_revising &&
                    !_saving;
                return FilledButton.tonalIcon(
                  key: reviewReviseButtonKey,
                  onPressed: canRevise ? _revise : null,
                  icon: _revising
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.auto_fix_high),
                  label: Text(S.of(context).reviewReviseButton),
                );
              },
            ),
            if (_revisionError != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                _revisionError!,
                key: reviewReviseErrorKey,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// One live meal-total line.
class _TotalRow extends StatelessWidget {
  const _TotalRow({
    required this.label,
    required this.unit,
    required this.valueKey,
    required this.value,
  });

  final String label;
  final String unit;
  final Key valueKey;

  /// Energy arrives as `int`, macros as `double`; [AppFormat.number] renders
  /// both without a trailing `.0`.
  final num value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: <Widget>[
          SizedBox(width: 48, child: Text(label)),
          Text(AppFormat.number(value), key: valueKey),
          const SizedBox(width: 4),
          Text(unit),
        ],
      ),
    );
  }
}
