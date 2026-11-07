/// The app's light and dark [ThemeData].
///
/// Hand-tuned rather than seeded so the surfaces stay in the "modern fitness
/// logger" register: a cool grey (light) / near-black (dark) canvas with
/// elevated cards, a vivid green accent, flat shadows, and rounded filled
/// controls. Install both via `MaterialApp(theme: light, darkTheme: dark,
/// themeMode: ThemeMode.system)`.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_dimensions.dart';
import 'app_semantic_colors.dart';

/// The light theme.
final ThemeData lightTheme = _buildTheme(
  brightness: Brightness.light,
  scheme: const ColorScheme.light(
    primary: Color(0xFF16A34A),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFDCFCE7),
    onPrimaryContainer: Color(0xFF14532D),
    secondary: Color(0xFF0F766E),
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFFCCFBF1),
    onSecondaryContainer: Color(0xFF134E4A),
    tertiary: Color(0xFFB45309),
    onTertiary: Color(0xFFFFFFFF),
    tertiaryContainer: Color(0xFFFEF3C7),
    onTertiaryContainer: Color(0xFF78350F),
    error: Color(0xFFDC2626),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFFEE2E2),
    onErrorContainer: Color(0xFF7F1D1D),
    surface: Color(0xFFFFFFFF),
    onSurface: Color(0xFF111827),
    onSurfaceVariant: Color(0xFF6B7280),
    outline: Color(0xFFD1D5DB),
    outlineVariant: Color(0xFFE8EAED),
    surfaceContainerLowest: Color(0xFFFFFFFF),
    surfaceContainerLow: Color(0xFFFFFFFF),
    surfaceContainer: Color(0xFFF0F2F5),
    surfaceContainerHigh: Color(0xFFECEFF2),
    surfaceContainerHighest: Color(0xFFE5E8EC),
    inverseSurface: Color(0xFF1F2937),
    onInverseSurface: Color(0xFFF9FAFB),
    inversePrimary: Color(0xFF86EFAC),
  ),
  scaffold: const Color(0xFFF6F7F9),
  inputFill: const Color(0xFFEFF1F4),
);

/// The dark theme.
final ThemeData darkTheme = _buildTheme(
  brightness: Brightness.dark,
  scheme: const ColorScheme.dark(
    primary: Color(0xFF4ADE80),
    onPrimary: Color(0xFF052E16),
    primaryContainer: Color(0xFF166534),
    onPrimaryContainer: Color(0xFFDCFCE7),
    secondary: Color(0xFF2DD4BF),
    onSecondary: Color(0xFF042F2E),
    secondaryContainer: Color(0xFF115E59),
    onSecondaryContainer: Color(0xFFCCFBF1),
    tertiary: Color(0xFFFBBF24),
    onTertiary: Color(0xFF451A03),
    tertiaryContainer: Color(0xFF92400E),
    onTertiaryContainer: Color(0xFFFDE68A),
    error: Color(0xFFF87171),
    onError: Color(0xFF450A0A),
    errorContainer: Color(0xFF7F1D1D),
    onErrorContainer: Color(0xFFFECACA),
    surface: Color(0xFF16181D),
    onSurface: Color(0xFFF3F4F6),
    onSurfaceVariant: Color(0xFF9CA3AF),
    outline: Color(0xFF3A3F47),
    outlineVariant: Color(0xFF262A31),
    surfaceContainerLowest: Color(0xFF111318),
    surfaceContainerLow: Color(0xFF16181D),
    surfaceContainer: Color(0xFF1B1E24),
    surfaceContainerHigh: Color(0xFF21252C),
    surfaceContainerHighest: Color(0xFF272C33),
    inverseSurface: Color(0xFFF3F4F6),
    onInverseSurface: Color(0xFF111827),
    inversePrimary: Color(0xFF16A34A),
  ),
  scaffold: const Color(0xFF0E1013),
  inputFill: const Color(0xFF21252C),
);

ThemeData _buildTheme({
  required Brightness brightness,
  required ColorScheme scheme,
  required Color scaffold,
  required Color inputFill,
}) {
  final bool isLight = brightness == Brightness.light;

  final TextTheme textTheme =
      (isLight
              ? Typography.material2021().black
              : Typography.material2021().white)
          .apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface)
          .copyWith(
            // Big numeric displays: heavy, tight, tabular.
            displaySmall: TextStyle(
              fontSize: 44,
              fontWeight: FontWeight.w700,
              letterSpacing: -1,
              fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
              color: scheme.onSurface,
            ),
            headlineSmall: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
              color: scheme.onSurface,
            ),
            titleLarge: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
            ),
            titleMedium: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
            ),
            bodyLarge: TextStyle(fontSize: 16, color: scheme.onSurface),
            bodyMedium: TextStyle(
              fontSize: 14,
              height: 1.35,
              color: scheme.onSurface,
            ),
            bodySmall: TextStyle(
              fontSize: 12.5,
              color: scheme.onSurfaceVariant,
            ),
            labelLarge: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
            ),
            labelMedium: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: scheme.onSurfaceVariant,
            ),
            // Stamped AFTER copyWith: the styles above are used verbatim as
            // DefaultTextStyles by AppBar/buttons (no bodyMedium merge), so every
            // style must carry the app face itself.
          )
          .apply(fontFamily: 'MiSans');

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: scaffold,
    fontFamily: 'MiSans',
    textTheme: textTheme,
    extensions: <ThemeExtension<dynamic>>[
      isLight ? AppSemantics.light : AppSemantics.dark,
    ],
    splashFactory: InkSparkle.splashFactory,
    appBarTheme: AppBarTheme(
      backgroundColor: scaffold,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: textTheme.titleLarge,
      systemOverlayStyle: isLight
          ? SystemUiOverlayStyle.dark
          : SystemUiOverlayStyle.light,
    ),
    cardTheme: CardThemeData(
      color: scheme.surfaceContainerLow,
      elevation: 0,
      margin: EdgeInsets.zero,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, AppDim.buttonHeight),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDim.radiusControl),
        ),
        textStyle: textTheme.labelLarge,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, AppDim.buttonHeight),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        foregroundColor: scheme.onSurface,
        side: BorderSide(color: scheme.outline),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDim.radiusControl),
        ),
        textStyle: textTheme.labelLarge,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDim.radiusControl),
        ),
        textStyle: textTheme.labelLarge,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: inputFill,
      hintStyle: TextStyle(color: scheme.onSurfaceVariant),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: _inputBorder(Colors.transparent),
      enabledBorder: _inputBorder(Colors.transparent),
      focusedBorder: _inputBorder(scheme.primary, width: 1.6),
      errorBorder: _inputBorder(scheme.error),
      focusedErrorBorder: _inputBorder(scheme.error, width: 1.6),
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant,
      thickness: 1,
      space: 1,
    ),
    listTileTheme: ListTileThemeData(
      iconColor: scheme.onSurfaceVariant,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDim.radiusContainer),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: scheme.surfaceContainerHigh,
      side: BorderSide.none,
      shape: const StadiumBorder(),
      labelStyle: textTheme.labelMedium,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: scheme.inverseSurface,
      contentTextStyle: textTheme.bodyMedium!.copyWith(
        color: scheme.onInverseSurface,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDim.radiusContainer),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDim.radiusCard),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: scheme.primary,
      linearTrackColor: scheme.surfaceContainerHigh,
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        side: WidgetStatePropertyAll<BorderSide>(
          BorderSide(color: scheme.outline),
        ),
        shape: WidgetStatePropertyAll<OutlinedBorder>(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDim.radiusControl),
          ),
        ),
        textStyle: WidgetStatePropertyAll<TextStyle>(textTheme.labelLarge!),
      ),
    ),
  );
}

OutlineInputBorder _inputBorder(Color color, {double width = 1}) =>
    OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppDim.radiusControl),
      borderSide: BorderSide(color: color, width: width),
    );
