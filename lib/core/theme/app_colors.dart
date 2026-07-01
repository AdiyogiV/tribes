import 'package:flutter/material.dart';

/// All color constants and dynamic color accessors for the app theme.
///
/// Light mode: Farm colors from logo (sun, cow, sky)
/// Dark mode: Deep purple-blue night sky theme
class AppColors {
  AppColors._();

  // ============================================
  // PRIMARY COLORS - Astrology Dark Brown Theme
  // ============================================

  /// Rich chocolate brown - main brand color (from cow outline)
  static const Color primaryBrandColor = Color(0xFF5A3D34); // Rich warm brown
  /// Softer golden for dark mode (less bright for comfort)
  static const Color primaryBrandColorDark =
      Color(0xFFFFFFFF); // White (dark-mode primary)
  /// Lighter brown shade
  static const Color primaryLightColor = Color(0xFF8D6E63); // Brown 400
  /// Deep espresso brown
  static const Color primaryDarkColor = Color(0xFF3E2723); // Brown 900

  /// Tracks current theme mode
  static bool isDarkModeFlag = false;

  /// Dynamic primary color based on theme
  static Color get primaryColor =>
      isDarkModeFlag ? primaryBrandColorDark : primaryBrandColor;

  // ============================================
  // FARM-INSPIRED ACCENT COLORS
  // ============================================

  /// Golden sun yellow - from logo sun
  static const Color sunGold = Color(0xFFF5C542);

  /// Warm honey amber
  static const Color honeyAmber = Color(0xFFE6A23C);

  /// Fresh grass green - from logo
  static const Color grassGreen = Color(0xFF7CB342);

  /// Deep forest green
  static const Color forestGreen = Color(0xFF558B2F);

  /// Barn red/terracotta - from logo barn
  static const Color barnRed = Color(0xFFD84315);

  /// Warm terracotta
  static const Color terracotta = Color(0xFFBF360C);

  /// Sky blue - from logo clouds
  static const Color skyBlue = Color(0xFF81D4FA);

  /// Peachy cream - from cow snout
  static const Color peachCream = Color(0xFFE8A88C);

  /// Fence wood brown
  static const Color woodBrown = Color(0xFF795548);

  /// Secondary accent colors (golden/amber - sun inspired)
  static const Color accentColor = Color(0xFFE6A23C); // Honey amber
  static const Color accentLightColor = Color(0xFFF5C542); // Sun gold
  static const Color accentDarkColor = Color(0xFFD48806); // Deep gold

  // ============================================
  // BACKGROUND COLORS - Sky Blue Theme
  // ============================================

  /// Light mode: Light sky blue (from logo sky/clouds)
  static const Color scaffoldLightColor = Color(0xFFE8F4FC);

  /// Dark mode: Dark grey background (not pure black). Cards/surfaces step up
  /// slightly so elevation reads.
  static const Color scaffoldDarkColor = Color(0xFF141414);

  /// Card backgrounds
  static const Color cardLightColor = Color(0xFFFFFFFF);
  static const Color cardDarkColor = Color(0xFF202020);

  /// Surface colors for elevated elements
  static const Color surfaceLightColor = Color(0xFFF5FAFD);
  static const Color surfaceDarkColor = Color(0xFF1A1A1A);

  // ============================================
  // TEXT COLORS
  // ============================================

  /// Primary text - dark mode gets warm tint
  static const Color textLightColor = Color(0xFF2D2016); // Warm dark brown
  static const Color textDarkColor = Color(0xFFF5F0E8); // Warm off-white
  /// Secondary text
  static const Color textSecondaryLightColor = Color(0xFF6D5D4D); // Muted brown
  static const Color textSecondaryDarkColor = Color(0xFFB8A99A); // Warm gray

  // ============================================
  // STANDARD OPACITY VALUES
  // ============================================

  /// Full emphasis - primary text, active icons (0.85)
  static const double opacityHigh = 0.85;

  /// Medium emphasis - secondary text, inactive icons (0.6)
  static const double opacityMedium = 0.6;

  /// Low emphasis - hints, disabled states (0.4)
  static const double opacityLow = 0.4;

  /// Subtle - borders, dividers (0.1-0.2)
  static const double opacitySubtle = 0.15;

  /// Get primaryColor with high opacity (0.85)
  static Color get primaryHigh => primaryColor.withValues(alpha: opacityHigh);

  /// Get primaryColor with medium opacity (0.6)
  static Color get primaryMedium =>
      primaryColor.withValues(alpha: opacityMedium);

  /// Get primaryColor with low opacity (0.4)
  static Color get primaryLow => primaryColor.withValues(alpha: opacityLow);

  // ============================================
  // STATUS COLORS - Farm Themed
  // ============================================

  /// Success: Fresh grass green
  static const Color successColor = Color(0xFF7CB342);

  /// Warning: Golden sun/harvest
  static const Color warningColor = Color(0xFFF5C542);

  /// Error: Barn red
  static const Color errorColor = Color(0xFFD84315);

  /// Info: Sky blue
  static const Color infoColor = Color(0xFF5D4037);

  // ============================================
  // ADDITIONAL PALETTE - Farm Pastels
  // ============================================

  static const Color pastelMint = Color(0xFFA5D6A7); // Light grass
  static const Color pastelLavender = Color(0xFFCE93D8); // Wildflower
  static const Color pastelPeach = Color(0xFFFFCC80); // Sunset peach
  static const Color pastelLilac = Color(0xFFB39DDB); // Evening sky

  // ============================================
  // COMMONLY USED COLORS - Extracted from codebase
  // ============================================

  /// Active/online green (Material Green 500) - calls, status indicators
  static const Color activeGreen = Color(0xFF4CAF50);

  /// Pure black - story backgrounds, pitch-black overlays
  static const Color pitchBlack = Color(0xFF000000);

  /// Cosmic purple - astrology accents, onboarding highlights
  static const Color cosmicPurple = Color(0xFF8B5CF6);

  /// Dark sheet/card background (iOS-style dark surface)
  static const Color sheetDarkColor = Color(0xFF1C1C1E);

  /// Danger/end-call red (Material Red 600)
  static const Color dangerRed = Color(0xFFE53935);

  /// Warm skeleton placeholder (light mode)
  static const Color skeletonLightColor = Color(0xFFF0EDE8);

  /// Dark gradient base - share cards, call screens
  static const Color darkGradientBase = Color(0xFF1A1A2E);

  /// Emerald green - creation dialogs, highlights
  static const Color emeraldGreen = Color(0xFF10B981);

  /// Warm cream - preview box light background
  static const Color previewLightColor = Color(0xFFFFFBE8);

  /// Gold - astrology accents, raj yogas
  static const Color goldColor = Color(0xFFFFD700);

  /// Pink accent - creation dialogs, astrology
  static const Color pinkAccent = Color(0xFFEC4899);

  /// Skeleton base (light mode)
  static const Color skeletonBaseLight = Color(0xFFE8E0D5);

  /// Warm dark brown - preview box dark background
  static const Color previewDarkColor = Color(0xFF2A2520);

  /// Dark gradient mid tone - share cards
  static const Color darkGradientMid = Color(0xFF0F1624);

  /// Light border/input color
  static const Color borderLightColor = Color(0xFFE0D8CC);

  /// Skeleton shimmer (light mode)
  static const Color skeletonShimmerLight = Color(0xFFD8CFC2);

  /// Near-black surface
  static const Color nearBlackColor = Color(0xFF1A1A1A);

  /// Aquamarine - life phase sync accent
  static const Color aquamarine = Color(0xFF7FFFD4);

  /// Amber accent - pitta dosha, onboarding
  static const Color amberAccent = Color(0xFFF59E0B);

  /// Rose pink - compatibility card accent
  static const Color rosePink = Color(0xFFF472B6);

  /// Lavender glow - ashtakoot card accent
  static const Color lavenderGlow = Color(0xFFE8B4F8);

  /// Soft violet - cosmic vibe card accent
  static const Color softViolet = Color(0xFFA78BFA);

  /// Indigo - creation dialogs, group call avatars
  static const Color indigoColor = Color(0xFF6366F1);

  /// Dark placeholder surface
  static const Color darkPlaceholder = Color(0xFF252525);

  /// Deepest dark gradient tone - share cards
  static const Color darkGradientDeep = Color(0xFF0A0E17);

  /// Light blue accent - life phase sync, compatibility
  static const Color lightBlueAccent = Color(0xFF64B5F6);

  /// Call screen background
  static const Color callBackground = Color(0xFF0D0D0D);

  /// Call gradient mid tone
  static const Color callGradientMid = Color(0xFF16213E);

  /// Dark elevated surface (dark mode cards, replies)
  static const Color darkElevatedSurface = Color(0xFF2A2A2A);

  // ============================================
  // ASTROLOGY SPECIFIC COLORS (using primary colors)
  // ============================================

  /// Astro brown - now uses primary color for consistency
  static Color astroBrown(bool isDark) =>
      isDark ? primaryBrandColorDark : primaryBrandColor;

  /// Astro brown light variant
  static Color astroBrownLight(bool isDark) => isDark
      ? primaryBrandColorDark.withValues(alpha: 0.3)
      : primaryBrandColor.withValues(alpha: 0.4);

  /// Astro brown background
  static Color astroBrownBackground(bool isDark) => isDark
      ? primaryBrandColorDark.withValues(alpha: 0.1)
      : primaryBrandColor.withValues(alpha: 0.08);

  // ============================================
  // DYNAMIC COLOR GETTERS
  // ============================================

  /// Get card color based on theme
  static Color get cardColor =>
      isDarkModeFlag ? cardDarkColor : cardLightColor;

  /// Get surface color based on theme
  static Color get surfaceColor =>
      isDarkModeFlag ? surfaceDarkColor : surfaceLightColor;

  /// Get text color based on theme
  static Color get textColor =>
      isDarkModeFlag ? textDarkColor : textLightColor;

  /// Get secondary text color based on theme
  static Color get textSecondaryColor =>
      isDarkModeFlag ? textSecondaryDarkColor : textSecondaryLightColor;

  /// Get scaffold color based on theme
  static Color get scaffoldColor =>
      isDarkModeFlag ? scaffoldDarkColor : scaffoldLightColor;
}
