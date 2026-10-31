/// Barrel for the versioned zh-CN AI prompt templates.
///
/// Modes: [mealPhotoPrompt] (photo -> meal items), [mealTextPrompt]
/// (free text -> meal items), [mealRevisionPrompt] (photos/text + the previous
/// estimate + a user correction -> corrected meal items), [labelPhotoPrompt]
/// (one photo with one or more GB 28050 nutrition labels -> per-label fields +
/// inferred food name) and [labelLinkPrompt] (analysed meal items + the saved-label index -> candidate
/// label indices; the second call of analyze-then-link).
/// The analysis prompts deliberately carry **no** saved-food data: matching is
/// the link call's job (see `design/label-linking.md`).
/// Each render carries the strict tool name it targets and its version.
library;

export 'label_link_prompt.dart';
export 'label_prompt.dart';
export 'meal_prompt.dart';
export 'prompt_template.dart';
