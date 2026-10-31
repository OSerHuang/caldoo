/// Downscale + encode helpers for meal photos.
///
/// AI meal requests must never carry full-resolution originals: a real
/// 3-12 MP JPEG base64s to 15-45 MB and the provider rejects or times out.
/// Every picked photo goes through this pipeline **before** it is encoded:
/// the long edge is capped at [maxLongEdge] and the JPEG is re-encoded at
/// [jpegQuality], so three photos stay comfortably inside the request budget.
///
/// The pipeline works on both lanes the picker offers:
/// * real source images (JPEG/PNG bytes) are decoded and re-encoded, and
/// * test probes can feed it a raw `image` package frame too —
/// both commit to the same bounded output path.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as image;

/// `dart:convert` is referenced via its typedef slots so a test can observe
/// that the codec was invoked (it cannot catch `base64Encode` otherwise).
typedef Base64Encoder = String Function(List<int> bytes);

/// Hard limits, exported for tests and for the capture controller.
const int maxLongEdge = 1600;
const int jpegQuality = 80;

/// A prepared photo: bounded base64 plus the dimensions it was encoded at.
///
/// The controller forwards [base64Data] to `AiImagePart` (which adds the
/// `data:` prefix); [mimeType] is always `image/jpeg`.
@immutable
class PreparedPhoto {
  const PreparedPhoto({
    required this.base64Data,
    required this.width,
    required this.height,
    this.mimeType = 'image/jpeg',
  });

  final String base64Data;
  final int width;
  final int height;
  final String mimeType;

  /// Byte size of the base64 payload rounded to KiB (for manual QA).
  int get base64KiB => (base64Data.length + 1023) ~/ 1024;

  /// The decoded JPEG bytes, for rendering a thumbnail (`Image.memory`) or
  /// for tests that inspect the encoded image dimensions.
  Uint8List get bytes => base64Decode(base64Data);
}

/// Downscales [frame] on the long edge to [maxLongEdge] (never upscale) and
/// returns the JPEG (quality [jpegQuality]) base64 payload with the output
/// dimensions. Deterministic for a fixed input.
///
/// Works for a raw decoded frame (a test probe constructs one directly) and
/// for decoded image bytes via [prepare].
PreparedPhoto _encode(
  image.Image frame, {
  Base64Encoder encode = base64Encode,
}) {
  image.Image working = frame;
  final int long = working.width > working.height
      ? working.width
      : working.height;
  if (long > maxLongEdge) {
    working = image.copyResize(
      working,
      width: working.width == long ? maxLongEdge : null,
      height: working.height == long ? maxLongEdge : null,
    );
  }
  final Uint8List jpeg = image.encodeJpg(working, quality: jpegQuality);
  return PreparedPhoto(
    base64Data: encode(jpeg),
    width: working.width,
    height: working.height,
  );
}

/// Decodes source bytes (JPEG/PNG, ...) then re-encodes via [_encode]. The
/// caller must know the payload bounded path committed; a null decode is a
/// malformed photo and never reaches the AI request.
///
/// A malformed source can make the `image` decoders *throw* rather than return
/// null (e.g. a truncated file trips a decoder's bounds check). That is still
/// "not a usable photo", so it is normalized to `null` here: garbage input is
/// rejected, never propagated as an exception into the picker flow.
PreparedPhoto? prepare(
  Uint8List sourceBytes, {
  Base64Encoder encode = base64Encode,
}) {
  image.Image? decoded;
  try {
    decoded = image.decodeImage(sourceBytes);
  } on Object {
    return null;
  }
  if (decoded == null) {
    return null;
  }
  return _encode(decoded, encode: encode);
}

/// Test seam: encodes an already-decoded [image.Image] frame without the
/// image-byte lane (a synthetic 4000x3000 probe needs no JPEG round-trip).
///
/// Public because `CaptureController.addFrame` uses it: the controller owns
/// the same bounded path for both a picked byte payload and a probe frame.
PreparedPhoto prepareFrame(
  image.Image frame, {
  Base64Encoder encode = base64Encode,
}) => _encode(frame, encode: encode);
