/// Bottom-inset helpers for screens living under the glass navigation shell.
library;

import 'package:flutter/material.dart';

/// Returns [base] extended by the shell's injected bottom padding, so the
/// content tail clears the floating glass navigation bar: the shell's
/// `Scaffold.extendBody` injects the bar height as the body's bottom
/// [MediaQuery] padding, which fixed page paddings must add explicitly.
EdgeInsets withShellBottom(BuildContext context, EdgeInsets base) =>
    base + EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom);
