/// Edit everything about a saved food except its nutrient values.
///
/// The editor owns the whole identity surface: name, brand, aliases, servings,
/// active/archived status and the per-100 basis. It is reached from the detail
/// page's 编辑 action; the free-text 补充说明 field is retired (the v9 data
/// migration folds its prose into the structured fields and drops it).
///
/// Saving is one write through [Food.withIdentity] + [Food.withSupplement]:
/// a blank name is rejected, a cleared brand persists as NULL, and empty
/// alias / serving lists really clear the stored values. Nutrient numbers stay
/// read-only, so this flow can never corrupt an authoritative label.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:caldoo/core/providers/app_providers.dart'
    show foodRepositoryProvider;
import 'package:caldoo/core/theme/app_dimensions.dart';
import 'package:caldoo/core/ui/app_card.dart';
import 'package:caldoo/core/ui/shell_insets.dart';
import 'package:caldoo/domain/models/models.dart';
import 'package:caldoo/domain/services/label_priority.dart'
    show foodAliases, foodServings, parseFoodServings;
import 'package:caldoo/l10n/app_strings.dart';

import 'food_supplement_format.dart';

/// Key of the editor scaffold.
const Key savedFoodNotesScreenKey = Key('saved_food_notes_screen');

/// Key of the name field.
const Key savedFoodNotesNameFieldKey = Key('saved_food_notes_name_field');

/// Key of the brand field.
const Key savedFoodNotesBrandFieldKey = Key('saved_food_notes_brand_field');

/// Key of the alias input.
const Key savedFoodNotesAliasesFieldKey = Key('saved_food_notes_aliases_field');

/// Key of the servings input.
const Key savedFoodNotesServingsFieldKey = Key(
  'saved_food_notes_servings_field',
);

/// Key of the active/archived switch.
const Key savedFoodNotesStatusSwitchKey = Key('saved_food_notes_status_switch');

/// Key of the status text under the switch.
const Key savedFoodNotesStatusTextKey = Key('saved_food_notes_status_text');

/// Key of the per-100 basis selector.
const Key savedFoodNotesBasisSelectorKey = Key(
  'saved_food_notes_basis_selector',
);

/// Key of the 保存 action.
const Key savedFoodNotesSaveButtonKey = Key('saved_food_notes_save_button');

/// Key of the reactive validation / save-failure message.
const Key savedFoodNotesErrorKey = Key('saved_food_notes_error');

/// Maximum number of aliases persisted by the editor.
const int _maxAliases = 10;

/// Maximum length (UTF-16 code units) of one persisted alias.
const int _maxAliasLength = 30;

/// The punctuation users type between aliases (the canonical one is `、`).
final RegExp _aliasSeparator = RegExp(r'[、,，;；/／|｜\n\r]+');

/// Splits the alias field into the normalised, storable alias list.
///
/// Separators are `、 , ， ; ； / |` and newlines (the set users actually
/// type); every alias is trimmed, blanks are dropped, exact duplicates removed
/// (order preserved), each alias is capped at [_maxAliasLength] characters and
/// at most [_maxAliases] aliases are kept.
List<String> _normaliseAliases(String raw) {
  final List<String> aliases = <String>[];
  for (final String segment in raw.split(_aliasSeparator)) {
    final String alias = segment.trim();
    if (alias.isEmpty) {
      continue;
    }
    final String capped = alias.length > _maxAliasLength
        ? alias.substring(0, _maxAliasLength)
        : alias;
    if (!aliases.contains(capped)) {
      aliases.add(capped);
    }
    if (aliases.length == _maxAliases) {
      break;
    }
  }
  return aliases;
}

/// Parses the servings field into at most three [FoodServing]s.
///
/// `、` is the editor's own display separator, but `parseFoodServings` only
/// splits on `；;，,｜|` and newlines, so it is normalised to `；` first: saving
/// the untouched prefill must never invent a bogus serving. Anything that does
/// not read as `<label> <amount> <g|ml>` is silently dropped by the parser.
List<FoodServing> _parseServings(String raw) {
  final String text = raw.trim();
  if (text.isEmpty) {
    return const <FoodServing>[];
  }
  return parseFoodServings(text.replaceAll('、', '；'));
}

/// The full editor for one saved food.
class SavedFoodNotesScreen extends ConsumerStatefulWidget {
  /// Creates the editor for [food].
  const SavedFoodNotesScreen({required this.food, super.key});

  /// The saved food being edited.
  final Food food;

  /// Pushes the editor and returns the saved food (or `null` on back).
  static Future<Food?> push(BuildContext context, Food food) {
    return Navigator.of(context).push<Food>(
      MaterialPageRoute<Food>(
        builder: (BuildContext context) => SavedFoodNotesScreen(food: food),
      ),
    );
  }

  @override
  ConsumerState<SavedFoodNotesScreen> createState() =>
      _SavedFoodNotesScreenState();
}

class _SavedFoodNotesScreenState extends ConsumerState<SavedFoodNotesScreen> {
  late final TextEditingController _name = TextEditingController(
    text: widget.food.name,
  );

  late final TextEditingController _brand = TextEditingController(
    text: widget.food.brand ?? '',
  );

  // Prefill from the *effective* aliases/servings: structured fields win, and a
  // legacy food's prose (not yet migrated) is parsed as the fallback, so the
  // editor never shows an empty field for an alias already visible elsewhere.
  late final TextEditingController _aliases = TextEditingController(
    text: foodAliases(widget.food).join('、'),
  );

  late final TextEditingController _servings = TextEditingController(
    text: formatFoodServings(foodServings(widget.food)),
  );

  /// `true` while the food is still offered (the archive switch is on).
  late bool _active = widget.food.status == FoodStatus.active;

  /// The per-100 basis the stored numbers are read on.
  late MeasureBasis _basis = widget.food.basis;

  bool _saving = false;

  /// Reactive validation / save failure shown above the save button.
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _brand.dispose();
    _aliases.dispose();
    _servings.dispose();
    super.dispose();
  }

  /// Clears a stale validation / save error as soon as the user edits.
  void _clearError() {
    if (_error != null) {
      setState(() => _error = null);
    }
  }

  /// Persists the whole food (identity + structured supplement) and pops with
  /// the update.
  Future<void> _save() async {
    if (_saving) {
      return;
    }
    final String name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = S.instance.foodNameRequired);
      return;
    }
    final String brand = _brand.text.trim();
    setState(() {
      _saving = true;
      _error = null;
    });
    final Food updated = widget.food
        .withIdentity(name: name, brand: brand.isEmpty ? null : brand)
        .withSupplement(
          notes: null,
          aliases: _normaliseAliases(_aliases.text),
          servings: _parseServings(_servings.text),
          status: _active ? FoodStatus.active : FoodStatus.archived,
          basis: _basis,
        );
    try {
      await ref.read(foodRepositoryProvider).upsertFood(updated);
    } on Object {
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(S.of(context).foodSupplementSaved)));
    Navigator.of(context).pop(updated);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool busy = _saving;
    return Scaffold(
      key: savedFoodNotesScreenKey,
      appBar: AppBar(title: Text(S.of(context).foodEditTitle)),
      body: ListView(
        padding: withShellBottom(
          context,
          const EdgeInsets.all(AppDim.pagePadding),
        ),
        children: <Widget>[
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  S.of(context).foodInfoTitle,
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: AppDim.gapTight),
                TextField(
                  key: savedFoodNotesNameFieldKey,
                  controller: _name,
                  enabled: !busy,
                  maxLines: 1,
                  textInputAction: TextInputAction.next,
                  onChanged: (_) => _clearError(),
                  decoration: InputDecoration(
                    labelText: S.of(context).foodNameFieldLabel,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: AppDim.gapTight),
                TextField(
                  key: savedFoodNotesBrandFieldKey,
                  controller: _brand,
                  enabled: !busy,
                  maxLines: 1,
                  textInputAction: TextInputAction.next,
                  onChanged: (_) => _clearError(),
                  decoration: InputDecoration(
                    labelText: S.of(context).foodBrandFieldLabel,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDim.gap),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                TextField(
                  key: savedFoodNotesAliasesFieldKey,
                  controller: _aliases,
                  enabled: !busy,
                  maxLines: 1,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: S.of(context).foodAliasesLabel,
                    hintText: S.of(context).foodAliasesHint,
                    helperText: S.of(context).foodAliasesHelp,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: AppDim.gap),
                TextField(
                  key: savedFoodNotesServingsFieldKey,
                  controller: _servings,
                  enabled: !busy,
                  maxLines: 1,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: S.of(context).foodServingsLabel,
                    hintText: S.of(context).foodServingsHint,
                    helperText: S.of(context).foodServingsHelp,
                    helperMaxLines: 2,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDim.gap),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SwitchListTile(
                  key: savedFoodNotesStatusSwitchKey,
                  contentPadding: EdgeInsets.zero,
                  value: _active,
                  onChanged: busy
                      ? null
                      : (bool value) => setState(() => _active = value),
                  title: Text(S.of(context).foodStatusLabel),
                  subtitle: Text(
                    _active
                        ? S.of(context).foodStatusActive
                        : S.of(context).foodStatusArchived,
                    key: savedFoodNotesStatusTextKey,
                  ),
                ),
                const SizedBox(height: AppDim.gapTight),
                Text(
                  S.of(context).foodBasisLabel,
                  style: theme.textTheme.labelLarge,
                ),
                const SizedBox(height: AppDim.gapTight),
                SegmentedButton<MeasureBasis>(
                  key: savedFoodNotesBasisSelectorKey,
                  segments: <ButtonSegment<MeasureBasis>>[
                    ButtonSegment<MeasureBasis>(
                      value: MeasureBasis.per100g,
                      label: Text(S.of(context).foodBasisPer100g),
                    ),
                    ButtonSegment<MeasureBasis>(
                      value: MeasureBasis.per100ml,
                      label: Text(S.of(context).foodBasisPer100ml),
                    ),
                  ],
                  selected: <MeasureBasis>{_basis},
                  showSelectedIcon: false,
                  onSelectionChanged: busy
                      ? null
                      : (Set<MeasureBasis> selection) =>
                            setState(() => _basis = selection.first),
                ),
              ],
            ),
          ),
          if (_error != null) ...<Widget>[
            const SizedBox(height: AppDim.gapTight),
            Text(
              _error!,
              key: savedFoodNotesErrorKey,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ],
          const SizedBox(height: AppDim.gap),
          FilledButton(
            key: savedFoodNotesSaveButtonKey,
            onPressed: busy ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(S.of(context).foodSupplementSave),
          ),
        ],
      ),
    );
  }
}
