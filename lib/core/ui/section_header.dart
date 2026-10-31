/// A section title row with an optional trailing widget.
library;

import 'package:flutter/material.dart';

/// The header. [trailing] usually carries a small link-style action.
class SectionHeader extends StatelessWidget {
  /// Creates the header.
  const SectionHeader({required this.title, super.key, this.trailing});

  /// The section title.
  final String title;

  /// Optional trailing widget (right-aligned).
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const Spacer(),
        ?trailing,
      ],
    );
  }
}
