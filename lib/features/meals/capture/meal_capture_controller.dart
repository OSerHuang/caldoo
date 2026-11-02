/// State + submit pipeline for the meal capture screen.
///
/// The screen never calls `image_picker` directly (the plugin channel does not
/// exist under `flutter test`): it asks the controller to run a pick, and the
/// controller reads a [MealPhotoSource] from Riverpod. Production binds the two
/// lanes to `image_picker` (camera + gallery); tests override
/// [cameraPhotoSourceProvider] / [galleryPhotoSourceProvider] with fakes.
///
/// Every picked photo commits to the SAME bounded path ([prepare]) before it is
/// counted as "picked": the long edge is capped at [maxLongEdge] and the JPEG
/// re-encoded at [jpegQuality] (see `image_codec.dart`). A photo that fails to
/// decode never joins the selection and never reaches the AI request, so a
/// full-resolution original can never be base64'd into a request.
///
/// Submit builds the task-16 prompt (photo mode when any photo is picked, text
/// mode otherwise), sends it through the task-14 client, validates the strict
/// tool arguments against the task-15 schema, and returns a
/// [CaptureSubmission]: the [MealAnalysis] draft plus the exact bounded photos
/// and text it was produced from.
///
/// That submission travels through [reviewRouterProvider] to the review screen
/// (task 19). Carrying the inputs with the draft is what lets the review screen
/// ask the AI to correct a wrong estimate (the revision request resends the
/// same photos); the controller itself stays free of that concern.
///
/// The controller deliberately does NOT take a `BuildContext`: routing is the
/// screen's job, which keeps this class unit-testable without a widget tree.
library;

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as image;
import 'package:image_picker/image_picker.dart';

import 'package:caldoo/ai/ai_client.dart';
import 'package:caldoo/ai/prompts/prompts.dart';
import 'package:caldoo/ai/schemas/meal_analysis.dart'
    show MealAnalysis, mealAnalysisToolName, mealAnalysisToolParameters;
import 'package:caldoo/features/settings/settings_providers.dart'
    show aiClientProvider, aiSettingsConfigProvider;

import 'image_codec.dart';
import 'review_placeholder_screen.dart';

/// Route name used by the default router. Production replaces that default with
/// the real task-19 review route (see `app_router.dart`); tests and the fallback
/// push [MealReviewPlaceholderScreen] under this name.
const String reviewRoutePath = '/meals/review';

/// Hard cap: the task-16 photo prompt accepts 1..3 photos of one meal.
const int maxPhotos = 3;

/// Callback the screen injects; production pushes the review route and reports
/// whether the meal was saved, tests record the submission and return a canned
/// result.
///
/// The `true` result is what lets the screen clear the capture inputs once a
/// record is complete, so the next capture never starts with the previous
/// meal's photos and text.
typedef ReviewRouter = Future<bool?> Function(
  BuildContext context,
  CaptureSubmission submission,
);

/// Picks one photo and returns its raw source bytes, or `null` when the user
/// cancelled. Production binds this to `ImagePicker` without exposing the
/// plugin to the widget.
typedef MealPhotoSource = Future<Uint8List?> Function();

/// Which capture lane a pick came from. Both commit to the same bounded path;
/// the distinction only selects the `image_picker` source.
enum PhotoLane { camera, gallery }

/// One successful submit: the validated AI draft plus the inputs it came from.
///
/// The review screen needs the photos and the typed text to ask the AI to
/// correct a wrong estimate, so they travel with the draft instead of being
/// read back from this controller later (the controller may be reset by the
/// next capture while an earlier review screen is still open).
@immutable
class CaptureSubmission {
  const CaptureSubmission({
    required this.draft,
    required this.photos,
    required this.userText,
  });

  /// The validated AI result to review.
  final MealAnalysis draft;

  /// The bounded photos sent with the request, in pick order (empty for a
  /// text-only submit).
  final List<PreparedPhoto> photos;

  /// The trimmed text the user typed, or an empty string.
  final String userText;
}

/// Outcome of one submit attempt, surfaced by the screen.
enum CaptureOutcome { idle, submitted, failed }

/// Immutable view state.
class CaptureState {
  const CaptureState({
    this.photos = const <PreparedPhoto>[],
    this.submitting = false,
    this.outcome = CaptureOutcome.idle,
    this.error,
  });

  /// Already-downscaled photos, in pick order.
  final List<PreparedPhoto> photos;

  /// A submit is in flight.
  final bool submitting;

  /// Result of the last submit attempt.
  final CaptureOutcome outcome;

  /// The typed failure of the last submit, for the reactive error affordance.
  ///
  /// `null` while nothing has failed (or after a retry starts); cleared by
  /// [copyWith]'s `clearError` so a success/retry never leaves a stale banner.
  final AiError? error;

  /// Number of photos currently selected.
  int get photoCount => photos.length;

  /// Whether another photo may be added (the 1..3 cap).
  bool get canAddPhoto => photos.length < maxPhotos;

  CaptureState copyWith({
    List<PreparedPhoto>? photos,
    bool? submitting,
    CaptureOutcome? outcome,
    AiError? error,
    bool clearError = false,
  }) => CaptureState(
    photos: photos ?? this.photos,
    submitting: submitting ?? this.submitting,
    outcome: outcome ?? this.outcome,
    error: clearError ? null : (error ?? this.error),
  );
}

/// Owns capture state and the submit pipeline.
class CaptureController extends Notifier<CaptureState> {
  @override
  CaptureState build() => const CaptureState();

  /// Clears the flow back to an empty capture (no photos, no error, idle).
  ///
  /// The provider is intentionally **not** `autoDispose` (an async submit may
  /// still be running when the screen goes away), so its state outlives the
  /// screen. The screen calls this after a completed record and on re-entry,
  /// so a finished or abandoned capture cannot resurface its photos later.
  void reset() => state = const CaptureState();

  MealPhotoSource _sourceFor(PhotoLane lane) => ref.read(
    lane == PhotoLane.camera
        ? cameraPhotoSourceProvider
        : galleryPhotoSourceProvider,
  );

  /// Picks one photo through [lane] and appends its **prepared** form.
  ///
  /// Capped at [maxPhotos]; a cancelled pick or an undecodable source is
  /// rejected, not added. The cap is re-checked after the await so two rapid
  /// taps cannot both pass the first guard.
  Future<void> addPhoto(PhotoLane lane) async {
    if (!state.canAddPhoto) {
      return;
    }
    final Uint8List? raw = await _sourceFor(lane)();
    if (raw == null || !state.canAddPhoto) {
      return;
    }
    final PreparedPhoto? prepared = prepare(raw);
    if (prepared == null) {
      return;
    }
    state = state.copyWith(photos: <PreparedPhoto>[...state.photos, prepared]);
  }

  /// Test seam: feeds a raw `image` package frame through the same bounded
  /// path (no image-byte round trip needed to probe the 4000x3000 case).
  void addFrame(image.Image frame) {
    if (!state.canAddPhoto) {
      return;
    }
    state = state.copyWith(
      photos: <PreparedPhoto>[...state.photos, prepareFrame(frame)],
    );
  }

  /// Removes the photo at [index]; out-of-range indices are ignored.
  void removePhotoAt(int index) {
    if (index < 0 || index >= state.photos.length) {
      return;
    }
    final List<PreparedPhoto> remaining = <PreparedPhoto>[...state.photos]
      ..removeAt(index);
    state = state.copyWith(photos: remaining);
  }

  /// Builds the task-16 prompt from the photo count + free text, sends it
  /// through [aiClientProvider] (task 14 client) and validates the strict tool
  /// arguments (task 15 schema).
  ///
  /// The prompt is self-contained: the analysis call carries no saved-food
  /// library data (label matching is a separate link call).
  ///
  /// Returns the validated [CaptureSubmission] on success, or `null` when the
  /// input is empty (blocked) or the call fails. The screen owns routing; a
  /// `null` return means "do not navigate". Saving never depends on this call
  /// (draft G7) — manual entry stays reachable regardless.
  Future<CaptureSubmission?> submit(String text) async {
    final String trimmed = text.trim();
    if (state.photos.isEmpty && trimmed.isEmpty) {
      return null;
    }
    if (state.submitting) {
      return null;
    }
    final List<PreparedPhoto> photos = List<PreparedPhoto>.unmodifiable(
      state.photos,
    );
    state = state.copyWith(
      submitting: true,
      outcome: CaptureOutcome.idle,
      clearError: true,
    );
    // On a cold start the config FutureProvider may still be loading; reading
    // the client before it settles would silently fall back to the default
    // endpoint and send the user's key there. Same guard as
    // saveAndTestConnection.
    await ref.read(aiSettingsConfigProvider.future);
    final AiClient client = ref.read(aiClientProvider);
    try {
      final PromptTemplate prompt = photos.isNotEmpty
          ? mealPhotoPrompt(
              photoCount: photos.length,
              userText: trimmed.isEmpty ? null : trimmed,
            )
          : mealTextPrompt(userText: trimmed);
      final String arguments = await client.completeWithTool(
        messages: prompt.toMessages(
          images: <AiImagePart>[
            for (final PreparedPhoto photo in photos)
              AiImagePart(photo.base64Data, mimeType: photo.mimeType),
          ],
        ),
        toolName: mealAnalysisToolName,
        parameters: mealAnalysisToolParameters,
        // A transient phone-network blip should not cost the user the whole
        // analysis; one automatic retry, then the normal error path.
        retryNetworkErrors: true,
      );
      final MealAnalysis draft = MealAnalysis.fromToolArguments(arguments);
      state = state.copyWith(
        outcome: CaptureOutcome.submitted,
        submitting: false,
      );
      return CaptureSubmission(draft: draft, photos: photos, userText: trimmed);
    } on AiError catch (error) {
      state = state.copyWith(
        outcome: CaptureOutcome.failed,
        submitting: false,
        error: error,
      );
      return null;
    }
  }
}

/// Production camera lane: `image_picker` launches the system camera and
/// returns one photo. Using `image_picker` for both lanes avoids a heavyweight
/// `camera` preview controller while still capturing from the device camera.
final cameraPhotoSourceProvider = Provider<MealPhotoSource>(
  (ref) =>
      () => _pick(ImageSource.camera),
);

/// Production gallery lane: `image_picker` returns one photo from the library.
final galleryPhotoSourceProvider = Provider<MealPhotoSource>(
  (ref) =>
      () => _pick(ImageSource.gallery),
);

/// Default router: pushes the task-19 placeholder under [reviewRoutePath].
/// Tests override this to record the draft.
final reviewRouterProvider = Provider<ReviewRouter>(
  (ref) => _pushReviewPlaceholder,
);

/// The capture controller.
final captureControllerProvider =
    NotifierProvider<CaptureController, CaptureState>(CaptureController.new);

Future<Uint8List?> _pick(ImageSource source) async {
  final XFile? picked = await ImagePicker().pickImage(source: source);
  if (picked == null) {
    return null;
  }
  return picked.readAsBytes();
}

Future<bool?> _pushReviewPlaceholder(
  BuildContext context,
  CaptureSubmission submission,
) {
  return Navigator.of(context).push<bool>(
    MaterialPageRoute<bool>(
      settings: const RouteSettings(name: reviewRoutePath),
      builder: (_) => MealReviewPlaceholderScreen(draft: submission.draft),
    ),
  );
}
