/// The share-sheet boundary of the backup feature (task 28).
///
/// This is the ONLY file that imports `share_plus`, keeping the platform call
/// out of the pure codec and the Drift service so both stay unit-testable.
library;

import 'dart:convert';

import 'package:share_plus/share_plus.dart';

/// The default file name offered in the share sheet.
const String backupFileName = 'data.json';

/// Shares [json] as an in-memory `application/json` file through the platform
/// share sheet.
///
/// Uses the `share_plus` 13.x API (`SharePlus.instance.share` +
/// `ShareParams`); `XFile.fromData` means no temporary file is written by the
/// app itself. Returns the platform [ShareResult] so a caller can react to
/// dismissal if it wants to.
Future<ShareResult> shareBackupJson(
  String json, {
  String fileName = backupFileName,
}) {
  return SharePlus.instance.share(
    ShareParams(
      files: <XFile>[
        XFile.fromData(utf8.encode(json), mimeType: 'application/json'),
      ],
      fileNameOverrides: <String>[fileName],
    ),
  );
}
