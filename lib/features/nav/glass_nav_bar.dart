/// The floating frosted-glass bottom navigation bar.
///
/// A capsule that hovers over the branch content: `BackdropFilter` blurs
/// whatever scrolls beneath it, a translucent surface tint + hairline border
/// sell the glass, and the active destination sits in a primary pill that
/// pops (one-shot spring) whenever the selection moves. Render it as
/// `Scaffold.bottomNavigationBar` together with `extendBody: true`, so the
/// branch content actually passes under the glass.
library;

import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

/// One destination of [GlassNavBar].
@immutable
class GlassNavDestination {
  /// Creates a destination. [key] stays a stable widget-test hook.
  const GlassNavDestination({
    required this.key,
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  /// Stable key for widget tests and semantics.
  final Key key;

  /// Unselected glyph.
  final IconData icon;

  /// Selected glyph.
  final IconData selectedIcon;

  /// The visible label.
  final String label;
}

/// The glass bar itself.
class GlassNavBar extends StatelessWidget {
  /// Creates the bar.
  const GlassNavBar({
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
    super.key,
  });

  /// The three (or more) destinations, in display order.
  final List<GlassNavDestination> destinations;

  /// The active destination index.
  final int selectedIndex;

  /// Called with the tapped destination's index.
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final bool isLight = theme.brightness == Brightness.light;
    // The glass tint: a translucent surface, so the blur has something to
    // reveal. Hairline border is bright on light canvas, faint on dark.
    final Color glass = colors.surface.withValues(alpha: isLight ? 0.66 : 0.58);
    final Color border = isLight
        ? Colors.white.withValues(alpha: 0.72)
        : colors.onSurface.withValues(alpha: 0.08);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: isLight ? 0.14 : 0.42),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                height: 62,
                decoration: BoxDecoration(
                  color: glass,
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(color: border),
                ),
                child: Row(
                  children: <Widget>[
                    for (int i = 0; i < destinations.length; i++)
                      Expanded(
                        child: _Destination(
                          destination: destinations[i],
                          selected: i == selectedIndex,
                          isLight: isLight,
                          onTap: () => onDestinationSelected(i),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One tappable destination: an inline icon + label, wrapped in the primary
/// pill when selected.
class _Destination extends StatelessWidget {
  const _Destination({
    required this.destination,
    required this.selected,
    required this.isLight,
    required this.onTap,
  });

  final GlassNavDestination destination;
  final bool selected;
  final bool isLight;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final Color content = selected
        ? colors.onPrimaryContainer
        : colors.onSurfaceVariant;
    final IconData icon = selected
        ? destination.selectedIcon
        : destination.icon;

    return Tooltip(
      message: destination.label,
      child: Semantics(
        container: true,
        selected: selected,
        button: true,
        child: InkWell(
          key: destination.key,
          onTap: onTap,
          customBorder: const StadiumBorder(),
          child: _PopIn(
            key: ValueKey<bool>(selected),
            animate: selected,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: selected
                  ? BoxDecoration(
                      color: colors.primaryContainer,
                      shape: BoxShape.rectangle,
                      borderRadius: BorderRadius.circular(999),
                    )
                  : null,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(icon, size: 22, color: content),
                  const SizedBox(width: 6),
                  Text(
                    destination.label,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: content,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The pill's one-shot spring pop: plays whenever [animate] turns true
/// (fresh [key] remount), scales statically otherwise.
class _PopIn extends StatelessWidget {
  const _PopIn({required this.animate, required this.child, super.key});

  /// Whether the pop plays (the destination is the selected one).
  final bool animate;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!animate || MediaQuery.disableAnimationsOf(context)) {
      return child;
    }
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.86, end: 1),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutBack,
      builder: (BuildContext context, double t, Widget? _) =>
          Transform.scale(scale: t, child: child),
    );
  }
}
