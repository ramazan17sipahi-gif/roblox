import 'package:flutter/material.dart';

/// Design System Color Palette.
///
/// Surface/text tokens adapt to the current theme via [bindToTheme]
/// (called from MaterialApp.builder). Brand accents stay fixed.
class AppColors {
  AppColors._();

  static Brightness _brightness = Brightness.light;

  /// Call from [MaterialApp.builder] so adaptive getters match the active theme.
  static void bindToTheme(BuildContext context) {
    _brightness = Theme.of(context).brightness;
  }

  static bool get isDark => _brightness == Brightness.dark;

  // Core Brand Colors (fixed)
  static const Color primary = Color(0xFF9F3B00);
  static const Color primaryContainer = Color(0xFFFF793A);
  static const Color onPrimary = Color(0xFFFFEFEA);

  // Light surfaces
  static const Color lightBackground = Color(0xFFF6F6F3);
  static const Color lightSurface = Color(0xFFF7F7F4);
  static const Color lightSurfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color lightSurfaceContainerLow = Color(0xFFF0F1EE);
  static const Color lightSurfaceContainerHigh = Color(0xFFE2E3DF);
  static const Color lightOnBackground = Color(0xFF2D2F2D);
  static const Color lightOutlineVariant = Color(0xFFACADAB);
  static const Color lightTextMediumEmphasis = Color(0xFF5A5C5A);
  static const Color lightBorderSubtle = Color(0xFFDCDDDA);

  // Dark surfaces
  static const Color darkBackground = Color(0xFF121412);
  static const Color darkSurface = Color(0xFF1A1B1A);
  static const Color darkSurfaceContainerLowest = Color(0xFF232522);
  static const Color darkSurfaceContainerLow = Color(0xFF2D2F2D);
  static const Color darkSurfaceContainerHigh = Color(0xFF3A3C3A);
  static const Color darkOnBackground = Color(0xFFF2F2EF);
  static const Color darkOutlineVariant = Color(0xFF8E908D);
  static const Color darkBorder = Color(0xFF3A3C3A);
  static const Color darkTextMediumEmphasis = Color(0xFFB0B2B0);
  static const Color darkBorderSubtle = Color(0xFF3A3C3A);

  // Adaptive surfaces & typography
  static Color get background =>
      isDark ? darkBackground : lightBackground;
  static Color get surface => isDark ? darkSurface : lightSurface;
  static Color get surfaceContainerLowest =>
      isDark ? darkSurfaceContainerLowest : lightSurfaceContainerLowest;
  static Color get surfaceContainerLow =>
      isDark ? darkSurfaceContainerLow : lightSurfaceContainerLow;
  static Color get surfaceContainerHigh =>
      isDark ? darkSurfaceContainerHigh : lightSurfaceContainerHigh;
  static Color get onBackground =>
      isDark ? darkOnBackground : lightOnBackground;
  static Color get onSurface => onBackground;
  static Color get outlineVariant =>
      isDark ? darkOutlineVariant : lightOutlineVariant;

  // States (fixed)
  static const Color error = Color(0xFFB31B25);
  static const Color success = Color(0xFF06693F);
  static const Color warning = Color(0xFFF86513);

  // Aliases
  static const Color primaryLight = primaryContainer;
  static const Color secondary = Color(0xFF5C5B5B);
  static Color get surfaceMuted => surfaceContainerLow;
  static Color get textHighEmphasis => onBackground;
  static Color get textMediumEmphasis =>
      isDark ? darkTextMediumEmphasis : lightTextMediumEmphasis;
  static Color get textLowEmphasis => outlineVariant;
  static Color get border => surfaceContainerHigh;
  static Color get borderSubtle =>
      isDark ? darkBorderSubtle : lightBorderSubtle;

  // Gradients
  static const LinearGradient actionGradient = LinearGradient(
    colors: [Color(0xFFFF793A), Color(0xFF9F3B00)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
