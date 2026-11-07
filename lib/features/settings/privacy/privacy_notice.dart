/// First-run privacy notice and the persisted "notice seen" flag.
///
/// The flag lives in the Drift `app_settings` key/value table (`notice_seen`),
/// so the "delete all local data" wipe — which clears the whole DB — resets it
/// automatically and the notice reappears on the next launch.
///
/// There is deliberately no account and no server call here: acknowledging the
/// notice is a purely local write.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:caldoo/core/providers/app_providers.dart';
import 'package:caldoo/core/ui/shell_insets.dart';
import 'package:caldoo/data/settings/app_settings_store.dart';
import 'package:caldoo/l10n/app_strings.dart';

/// Reads and writes the persisted "privacy notice seen" preference.
class PrivacyNoticeController {
  /// Creates the controller over the non-secret [AppSettingsStore].
  PrivacyNoticeController(this._store);

  /// `app_settings` key owned by this feature (the store deliberately does not
  /// define keys for its callers).
  static const String seenKey = 'notice_seen';

  final AppSettingsStore _store;

  /// Whether the user has already acknowledged the notice.
  Future<bool> hasSeen() => _store.readBool(seenKey);

  /// Persists the acknowledgement so the notice is not shown again.
  Future<void> markSeen() => _store.writeBool(seenKey, true);
}

/// The notice-seen flag, read from Drift; invalidate to re-read after a wipe.
final privacyNoticeSeenProvider = FutureProvider<bool>(
  (ref) => ref.watch(privacyNoticeControllerProvider).hasSeen(),
);

/// Wires [PrivacyNoticeController] to the Drift `app_settings` store.
final privacyNoticeControllerProvider = Provider<PrivacyNoticeController>(
  (ref) => PrivacyNoticeController(ref.watch(appSettingsStoreProvider)),
);

/// The standalone first-run notice.
///
/// States plainly that the user's photos/text are sent to the user's own
/// third-party AI provider with the user's own key — nothing else leaves the
/// device, and the developer never sees the key or the content.
class PrivacyNoticeScreen extends StatelessWidget {
  /// Creates the notice; [onAccept] is invoked once the user acknowledges it.
  const PrivacyNoticeScreen({required this.onAccept, super.key});

  /// Persists the acknowledgement (the gate then swaps to the app).
  final Future<void> Function() onAccept;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('privacy_notice_screen'),
      appBar: AppBar(title: Text(S.of(context).privacyTitle)),
      body: ListView(
        padding: withShellBottom(context, const EdgeInsets.all(16)),
        children: <Widget>[
          Text(
            S.of(context).privacyIntro,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          _Bullet(S.of(context).privacyBullet1),
          _Bullet(S.of(context).privacyBullet2),
          _Bullet(S.of(context).privacyBullet3),
          _Bullet(S.of(context).privacyBullet4),
          const SizedBox(height: 24),
          FilledButton(
            key: const Key('privacy_notice_accept'),
            onPressed: () async {
              await onAccept();
            },
            child: Text(S.of(context).privacyAccept),
          ),
        ],
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(S.of(context).bullet(text)),
    );
  }
}

/// Shows [child] unless the first-run notice has not yet been acknowledged.
///
/// While the flag is loading it shows a spinner; if reading the flag fails it
/// fails open (shows [child]) so a local prefs error can never brick startup.
class PrivacyNoticeGate extends ConsumerWidget {
  /// Creates the gate over the app's [child].
  const PrivacyNoticeGate({required this.child, super.key});

  /// The app content revealed once the notice is acknowledged.
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<bool> seen = ref.watch(privacyNoticeSeenProvider);
    return switch (seen) {
      AsyncData(:final value) =>
        value
            ? child
            : PrivacyNoticeScreen(
                onAccept: () async {
                  await ref.read(privacyNoticeControllerProvider).markSeen();
                  ref.invalidate(privacyNoticeSeenProvider);
                },
              ),
      AsyncError() => child,
      _ => const Scaffold(body: Center(child: CircularProgressIndicator())),
    };
  }
}
