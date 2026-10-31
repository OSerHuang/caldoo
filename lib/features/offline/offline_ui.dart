/// App-wide offline / AI-unavailable UI (task 30).
///
/// One place for the three primitives every AI surface shares:
///
/// * [aiUnavailableMessage] — the draft-G7 notice shown next to a **proactively
///   disabled** AI action while the device has no network transport
///   ([isOfflineProvider], task 13);
/// * [AiOfflineNotice] — a keyed red notice that renders only while offline and
///   collapses to nothing otherwise, so `find.byKey(noticeKey)` is meaningful
///   (it matches only when the notice is actually on screen);
/// * [describeAiFailure] — the reactive message for a call that still failed
///   with an [AiError] (e.g. the network dropped mid-request), reusing the
///   single exhaustive taxonomy-to-zh-CN map already owned by the settings
///   screen.
///
/// The rule this file exists to encode (draft G7): being offline disables AI
/// actions **only**. Manual logging, manual label entry, summaries and
/// navigation are never blocked.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:caldoo/ai/ai_client.dart';
import 'package:caldoo/core/providers/app_providers.dart'
    show isOfflineProvider;
import 'package:caldoo/features/settings/ai_error_text.dart'
    show describeAiError;
import 'package:caldoo/l10n/app_strings.dart';

/// Draft-G7 notice shown wherever an AI action is unavailable offline.
const String aiUnavailableMessage = S.aiUnavailableMessageConst;

/// Reactive failure message for an [AiError]: the typed reason plus the two
/// always-available recoveries (retry, or fall back to manual entry).
String describeAiFailure(AiError error) =>
    S.instance.aiFailureRetry(describeAiError(error));

/// A keyed notice rendered only while [isOfflineProvider] is `true`.
///
/// [noticeKey] lands on the [Text], not on this widget, so a widget test that
/// finds by it proves the notice is genuinely displayed (an online build
/// renders [SizedBox.shrink] and the finder matches nothing).
class AiOfflineNotice extends ConsumerWidget {
  /// Creates the notice labelled by [noticeKey].
  const AiOfflineNotice({
    required this.noticeKey,
    this.text = aiUnavailableMessage,
    super.key,
  });

  /// Key placed on the visible [Text]; absent from the tree while online.
  final Key noticeKey;

  /// Notice copy; defaults to the shared G7 message.
  final String text;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(isOfflineProvider)) {
      return const SizedBox.shrink();
    }
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: colors.errorContainer.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: <Widget>[
            Icon(Icons.wifi_off, size: 18, color: colors.error),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                key: noticeKey,
                style: TextStyle(color: colors.error),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
