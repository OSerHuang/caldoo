/// The trigger that makes the automatic backup actually automatic.
///
/// Mounted once under `MaterialApp.builder` (see `main.dart`), it runs one
/// capture shortly after the first frame and one whenever the app moves to the
/// background — the two moments that reliably bracket a session, without
/// asking any screen to cooperate.
///
/// It never blocks the UI and never throws: a missing platform channel (widget
/// tests, desktop), a locked database or any other failure is swallowed here,
/// because the safety net must not become a new crash source.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:caldoo/features/settings/backup/auto_backup_providers.dart';
import 'package:caldoo/features/settings/backup/auto_backup_service.dart';

/// Key used by widget tests to find the trigger.
const Key autoBackupLifecycleKey = Key('auto_backup_lifecycle');

/// Runs the automatic backup at launch and on background transitions.
class AutoBackupLifecycle extends ConsumerStatefulWidget {
  /// Creates the trigger around [child] (usually the app's route content).
  const AutoBackupLifecycle({super.key, required this.child});

  /// The wrapped subtree; this widget adds no visual layer.
  final Widget child;

  @override
  ConsumerState<AutoBackupLifecycle> createState() =>
      _AutoBackupLifecycleState();
}

class _AutoBackupLifecycleState extends ConsumerState<AutoBackupLifecycle>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // After the first frame: the database is lazy, and a capture during build
    // would open it on the critical path of the launch animation.
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _run();
    }
  }

  Future<void> _run() async {
    if (!mounted) {
      return;
    }
    if (!ref.read(autoBackupLifecycleEnabledProvider)) {
      return;
    }
    final AutoBackupService service;
    try {
      service = ref.read(autoBackupServiceProvider);
    } on Object {
      return;
    }
    try {
      await service.maybeRun();
    } on Object {
      // The safety net is best-effort by contract.
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
