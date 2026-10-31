/// The platform boundary of the automatic backup.
///
/// This is the ONLY file that talks to the `caldoo/auto_backup`
/// MethodChannel (implemented in
/// `android/app/src/main/kotlin/com/caldoo/AutoBackupChannel.kt`).
///
/// The channel writes to the PUBLIC downloads area (`下载/卡嘟备份/`,
/// via `MediaStore` on Android 10+) rather than to the app's own directory,
/// because an uninstall deletes everything the app owns — including its
/// private files directory. A document in the public downloads area survives
/// the uninstall, which is exactly the failure mode this feature exists for.
///
/// Every method degrades gracefully when the channel is missing (widget tests,
/// desktop): [isAvailable] answers `false`, reads answer `null`, and listing
/// answers empty, so a missing plugin can never break the app or a test.
library;

import 'package:flutter/services.dart';

import 'auto_backup_data.dart';

/// The durable document store used by the automatic backup.
abstract interface class AutoBackupStorage {
  /// Whether this platform has a durable backup target at all.
  Future<bool> isAvailable();

  /// Writes [json] under [fileName], replacing an existing document of the
  /// same name when the platform allows it.
  Future<void> save(String fileName, String json);

  /// Lists the documents in the backup folder, newest first.
  Future<List<AutoBackupEntry>> list();

  /// Reads the document [fileName], or `null` when it does not exist (or is
  /// no longer readable, e.g. a copy from a previous install).
  Future<String?> read(String fileName);

  /// Deletes [fileName]. Missing documents are a no-op.
  Future<void> delete(String fileName);

  /// Opens the system file picker so the user can import a `data.json` that
  /// came from anywhere (another device, WeChat, an old install). Returns the
  /// file's text, or `null` when the user cancelled.
  Future<String?> pickJsonFile();
}

/// The Android implementation over the `AutoBackupChannel` MethodChannel.
class ChannelAutoBackupStorage implements AutoBackupStorage {
  /// Creates the storage; [channel] is a test seam.
  ChannelAutoBackupStorage({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(channelName);

  /// The channel name shared with `AutoBackupChannel.kt`.
  static const String channelName = 'caldoo/auto_backup';

  final MethodChannel _channel;

  @override
  Future<bool> isAvailable() async {
    try {
      return await _channel.invokeMethod<bool>('isAvailable') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<void> save(String fileName, String json) async {
    try {
      await _channel.invokeMethod<void>('save', <String, Object?>{
        'name': fileName,
        'json': json,
      });
    } on MissingPluginException catch (error) {
      throw AutoBackupUnavailableException(error.message);
    }
  }

  @override
  Future<List<AutoBackupEntry>> list() async {
    try {
      final List<Object?>? raw = await _channel.invokeListMethod<Object?>(
        'list',
      );
      if (raw == null) {
        return const <AutoBackupEntry>[];
      }
      return <AutoBackupEntry>[
        for (final Object? element in raw)
          if (element is Map<Object?, Object?>) _entryFromPlatform(element),
      ];
    } on MissingPluginException {
      return const <AutoBackupEntry>[];
    } on PlatformException {
      return const <AutoBackupEntry>[];
    }
  }

  @override
  Future<String?> read(String fileName) async {
    try {
      return await _channel.invokeMethod<String>('read', <String, Object?>{
        'name': fileName,
      });
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  @override
  Future<void> delete(String fileName) async {
    try {
      await _channel.invokeMethod<void>('delete', <String, Object?>{
        'name': fileName,
      });
    } on MissingPluginException {
      // Nothing to delete on a platform without the store.
    } on PlatformException {
      // A copy created by a previous install is not ours to delete; pruning
      // must never fail because of that.
    }
  }

  @override
  Future<String?> pickJsonFile() async {
    try {
      return await _channel.invokeMethod<String>('pickFile');
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  static AutoBackupEntry _entryFromPlatform(Map<Object?, Object?> raw) {
    final int millis = (raw['modifiedMillis'] as num?)?.toInt() ?? 0;
    final Object? size = raw['sizeBytes'];
    return AutoBackupEntry(
      fileName: raw['name'] as String? ?? '',
      sizeBytes: size is num ? size.toInt() : 0,
      savedAt: DateTime.fromMillisecondsSinceEpoch(millis),
    );
  }
}

/// Thrown when a durable backup target is missing in the current build.
class AutoBackupUnavailableException implements Exception {
  /// Creates the failure with the platform's [message] (may be null).
  const AutoBackupUnavailableException(this.message);

  /// The platform error message, when there is one.
  final String? message;

  @override
  String toString() => 'AutoBackupUnavailableException: $message';
}
