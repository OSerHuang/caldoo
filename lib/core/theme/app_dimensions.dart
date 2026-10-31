/// Design tokens for the visual language (spacing, radii, elevation).
///
/// The app aims for a modern "fitness-logger" look: generous whitespace,
/// large rounded cards, and flat surfaces separated by background contrast
/// rather than shadows. Keep every ad-hoc `BorderRadius.circular(...)`
/// aligned with a token from here.
library;

/// Spacing and radius tokens. Values are logical pixels.
abstract final class AppDim {
  // ---- radii ----

  /// Hero/dashboard cards.
  static const double radiusCard = 20;

  /// Secondary containers: tiles, list groups, dialogs, sheets.
  static const double radiusContainer = 16;

  /// Buttons and text fields.
  static const double radiusControl = 14;

  /// Small accents: badges, chips, progress bars.
  static const double radiusBadge = 999;

  // ---- spacing ----

  /// Outer page margin.
  static const double pagePadding = 16;

  /// Inner padding of a standard card.
  static const double cardPadding = 16;

  /// Inner padding of a hero/dashboard card.
  static const double heroPadding = 20;

  /// Standard gap between sibling widgets.
  static const double gap = 12;

  /// Tight gap inside a row/column cluster.
  static const double gapTight = 8;

  /// Wide gap between sections.
  static const double gapSection = 24;

  // ---- controls ----

  /// Minimum height of a primary button.
  static const double buttonHeight = 52;

  /// Stroke width of the hero calorie ring.
  static const double ringStroke = 14;
}
