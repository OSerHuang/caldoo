/// Meal capture screen: photos (camera / gallery, 1..3) and/or free Chinese
/// text (typed or dictated with the keyboard's own microphone), then a submit
/// that runs the AI analysis and routes to review — or, alternatively, a
/// 从模版记录 entry that fills the review form straight from a saved meal
/// template (no AI call at all).
///
/// Layout follows the settings screen conventions (Material 3 defaults, a
/// 16 px page padding, `Key`s on every interactive widget so widget tests do
/// not depend on copy). The screen is a plain widget: it renders with no
/// network, and only the AI submit action is gated on connectivity (draft G7),
/// so manual entry and navigation always work offline.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:caldoo/core/providers/app_providers.dart'
    show isOfflineProvider;
import 'package:caldoo/core/ui/shell_insets.dart';
import 'package:caldoo/domain/models/models.dart';
import 'package:caldoo/features/meals/templates/template_apply.dart'
    show templateReviewRouterProvider;
import 'package:caldoo/features/meals/templates/template_picker_screen.dart';
import 'package:caldoo/features/offline/offline_ui.dart';
import 'package:caldoo/l10n/app_strings.dart';

import 'image_codec.dart';
import 'meal_capture_controller.dart';

/// Key of the G7 offline notice on this screen.
const Key captureOfflineHintKey = Key('capture_offline_hint');

/// Key of the reactive AI-failure message.
const Key captureErrorKey = Key('capture_error');

/// Key of the retry action shown after a failed AI call.
const Key captureRetryButtonKey = Key('capture_retry_button');

/// Key of the voice entry under the description field.
const Key captureVoiceButtonKey = Key('capture_voice_button');

/// Key of the hint line beside the voice entry.
const Key captureVoiceHintKey = Key('capture_voice_hint');

/// Key of the 从模版记录 entry.
const Key captureTemplateButtonKey = Key('capture_template_button');

/// Capture photos and/or free text for one meal.
class MealCaptureScreen extends ConsumerStatefulWidget {
  const MealCaptureScreen({super.key});

  @override
  ConsumerState<MealCaptureScreen> createState() => _MealCaptureScreenState();
}

class _MealCaptureScreenState extends ConsumerState<MealCaptureScreen> {
  final TextEditingController _text = TextEditingController();
  final FocusNode _textFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    // The controller is a non-autoDispose provider that outlives this screen,
    // so photos left by an abandoned capture would be shown again when the
    // user re-opens 拍餐. Riverpod forbids modifying a provider while the tree
    // is building, so the reset is deferred by one microtask (it runs before
    // the user can interact).
    Future<void>.microtask(() {
      if (mounted) {
        ref.read(captureControllerProvider.notifier).reset();
      }
    });
  }

  @override
  void dispose() {
    _textFocus.dispose();
    _text.dispose();
    super.dispose();
  }

  /// Hands voice input to the keyboard's own microphone.
  ///
  /// Android's `SpeechRecognizer` is not usable on ROMs without a
  /// third-party-capable recogniser (vivo/Huawei without Google services accept
  /// the call and return no words), and no in-app API can press the IME's
  /// microphone key. Focusing the field opens the keyboard exactly where that
  /// key lives, and whatever the IME transcribes lands in this field as if
  /// typed — so the rest of the flow is unchanged.
  void _useKeyboardVoice() {
    _textFocus.requestFocus();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(S.of(context).voiceKeyboardHint)));
  }

  Future<void> _add(PhotoLane lane) =>
      ref.read(captureControllerProvider.notifier).addPhoto(lane);

  Future<void> _submit() async {
    final CaptureSubmission? submission = await ref
        .read(captureControllerProvider.notifier)
        .submit(_text.text);
    if (submission == null || !mounted) {
      return;
    }
    final bool? saved = await ref.read(reviewRouterProvider)(
      context,
      submission,
    );
    if (saved == true && mounted) {
      // The record is complete: start the next capture from a clean slate.
      // A cancelled review (`false`/`null`) keeps the inputs so the user can
      // retry or correct the same photos.
      _text.clear();
      ref.read(captureControllerProvider.notifier).reset();
    }
  }

  /// The 从模版记录 entry: pick a template, then route into the review form
  /// with the template-filled draft (no AI call at all).
  ///
  /// The routing is a provider seam like [reviewRouterProvider], so tests
  /// record the template instead of navigating. A cancelled pick or a
  /// dismissed review leaves the capture inputs untouched; a completed record
  /// clears them, exactly like the AI path.
  Future<void> _useTemplate() async {
    final MealTemplate? template = await MealTemplatePicker.push(context);
    if (template == null || !mounted) {
      return;
    }
    final bool? saved = await ref.read(templateReviewRouterProvider)(
      context,
      template,
    );
    if (saved == true && mounted) {
      _text.clear();
      ref.read(captureControllerProvider.notifier).reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    final CaptureState state = ref.watch(captureControllerProvider);
    final bool offline = ref.watch(isOfflineProvider);
    return Scaffold(
      appBar: AppBar(title: Text(S.of(context).captureMealTitle)),
      body: ListView(
        padding: withShellBottom(context, const EdgeInsets.all(16)),
        children: <Widget>[
          TextField(
            key: const Key('capture_text_field'),
            controller: _text,
            focusNode: _textFocus,
            maxLines: 3,
            minLines: 2,
            textInputAction: TextInputAction.newline,
            decoration: InputDecoration(
              labelText: S.of(context).labelDescription,
              hintText: S.of(context).hintDescription,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              OutlinedButton.icon(
                key: captureVoiceButtonKey,
                onPressed: _useKeyboardVoice,
                icon: const Icon(Icons.mic_none),
                label: Text(S.of(context).voiceInputAction),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  S.of(context).voiceInputHint,
                  key: captureVoiceHintKey,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('capture_camera_button'),
                  onPressed: state.canAddPhoto
                      ? () => _add(PhotoLane.camera)
                      : null,
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: Text(S.of(context).capturePhoto),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('capture_gallery_button'),
                  onPressed: state.canAddPhoto
                      ? () => _add(PhotoLane.gallery)
                      : null,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: Text(S.of(context).captureGallery),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            S.of(context).capturePhotoCountHint(state.photoCount, maxPhotos),
            key: const Key('capture_photo_count'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (state.photos.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: <Widget>[
                for (int i = 0; i < state.photos.length; i++)
                  _Thumbnail(
                    key: Key('capture_thumb_$i'),
                    photo: state.photos[i],
                    removeKey: Key('capture_remove_$i'),
                    onRemove: () => ref
                        .read(captureControllerProvider.notifier)
                        .removePhotoAt(i),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 24),
          const AiOfflineNotice(noticeKey: captureOfflineHintKey),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _text,
            builder: (BuildContext context, TextEditingValue value, _) {
              final bool hasText = value.text.trim().isNotEmpty;
              final bool hasContent = state.photos.isNotEmpty || hasText;
              final bool canSubmit =
                  hasContent && !offline && !state.submitting;
              return FilledButton(
                key: const Key('capture_submit_button'),
                onPressed: canSubmit ? _submit : null,
                child: state.submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(S.of(context).startRecognition),
              );
            },
          ),
          if (state.error != null) ...<Widget>[
            const SizedBox(height: 12),
            Text(
              describeAiFailure(state.error!),
              key: captureErrorKey,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: captureRetryButtonKey,
                onPressed: state.submitting ? null : _submit,
                icon: const Icon(Icons.refresh),
                label: Text(S.of(context).retry),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            S.of(context).capturePrivacyHint,
            key: const Key('capture_privacy_hint'),
            textAlign: TextAlign.center,
          ),
          // The template lane is the alternative path, so it sits BELOW the
          // primary CTA at the very bottom of the form: the AI-identify flow
          // keeps its above-the-fold position (and every test surface that
          // taps the submit button keeps its viewport geometry).
          const SizedBox(height: 16),
          OutlinedButton.icon(
            key: captureTemplateButtonKey,
            onPressed: _useTemplate,
            icon: const Icon(Icons.bookmark_border),
            label: Text(S.of(context).captureUseTemplate),
          ),
        ],
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({
    super.key,
    required this.photo,
    required this.removeKey,
    required this.onRemove,
  });

  final PreparedPhoto photo;
  final Key removeKey;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Image.memory(
            photo.bytes,
            width: 96,
            height: 96,
            fit: BoxFit.cover,
            gaplessPlayback: true,
          ),
        ),
        Positioned(
          top: -8,
          right: -8,
          child: IconButton(
            key: removeKey,
            onPressed: onRemove,
            iconSize: 20,
            tooltip: S.of(context).remove,
            icon: const CircleAvatar(
              radius: 12,
              child: Icon(Icons.close, size: 14),
            ),
          ),
        ),
      ],
    );
  }
}
