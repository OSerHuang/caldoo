/// In-memory [AutoBackupStorage] for tests and the golden render harness.
///
/// The production store is a MethodChannel to the public downloads folder; a
/// widget test cannot (and must not) touch it. This fake keeps the same
/// contract — newest-first listing, overwrite-by-name, delete — in memory.
library;

import 'dart:convert';

import 'package:caldoo/features/settings/backup/auto_backup_data.dart';
import 'package:caldoo/features/settings/backup/auto_backup_storage.dart';

/// One stored document in the fake folder.
typedef FakeDocument = ({String json, DateTime savedAt});

/// An in-memory stand-in for the durable backup folder.
class InMemoryAutoBackupStorage implements AutoBackupStorage {
  /// Creates the fake; [available] mirrors [AutoBackupStorage.isAvailable].
  InMemoryAutoBackupStorage({this.available = true, DateTime Function()? now})
    : _now = now ?? DateTime.now;

  /// Whether the fake platform can write.
  bool available;

  /// The documents by file name.
  final Map<String, FakeDocument> documents = <String, FakeDocument>{};

  /// Returned by the next [pickJsonFile] call (`null` = cancelled).
  String? pickedJson;

  /// How many documents were written (assertions use this).
  int writeCount = 0;

  /// How many documents were pruned/deleted (assertions use this).
  int deleteCount = 0;

  final DateTime Function() _now;

  /// Seeds a pre-existing document, e.g. a copy from an earlier launch.
  void seed(String fileName, String json, {required DateTime savedAt}) {
    documents[fileName] = (json: json, savedAt: savedAt);
  }

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<void> save(String fileName, String json) async {
    writeCount++;
    documents[fileName] = (json: json, savedAt: _now());
  }

  @override
  Future<List<AutoBackupEntry>> list() async {
    final List<AutoBackupEntry> entries =
        <AutoBackupEntry>[
          for (final MapEntry<String, FakeDocument> entry in documents.entries)
            AutoBackupEntry(
              fileName: entry.key,
              sizeBytes: utf8.encode(entry.value.json).length,
              savedAt: entry.value.savedAt,
            ),
        ]..sort(
          (AutoBackupEntry a, AutoBackupEntry b) =>
              b.savedAt.compareTo(a.savedAt),
        );
    return entries;
  }

  @override
  Future<String?> read(String fileName) async => documents[fileName]?.json;

  @override
  Future<void> delete(String fileName) async {
    deleteCount++;
    documents.remove(fileName);
  }

  @override
  Future<String?> pickJsonFile() async => pickedJson;
}
