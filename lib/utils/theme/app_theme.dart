import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:aurogram/utils/theme/app_dimensions.dart';

/// Theme configuration for the app - Farm & Astrology inspired
/// Light mode: Farm colors from logo (sun, cow, sky)
/// Dark mode: Deep purple-blue night sky theme
class AppTheme {
  /// Helper to create text style with system font
  static TextStyle _systemFont({
    required double fontSize,
    required FontWeight fontWeight,
    required Color color,
    double letterSpacing = 0.0,
  }) {
    return TextStyle(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
    );
  }

  // ============================================
  // HOLYCOW PAGE — CONFIGURABLE TEXT SIZE
  // Change this single value to resize all text on the HolyCow dashboard.
  // ============================================
  static const double holyCowTextSize = 15.0;

  // ============================================
  // PRIMARY COLORS - Astrology Dark Brown Theme
  // ============================================

  /// Rich chocolate brown - main brand color (from cow outline)
  static const Color _primaryBrandColor = Color(0xFF5A3D34); // Rich warm brown
  /// Softer golden for dark mode (less bright for comfort)
  static const Color _primaryBrandColorDark =
      Color(0xFFB8925E); // Soft muted gold
  /// Lighter brown shade
  static const Color primaryLightColor = Color(0xFF8D6E63); // Brown 400
  /// Deep espresso brown
  static const Color primaryDarkColor = Color(0xFF3E2723); // Brown 900

  /// Tracks current theme mode
  static bool _isDarkModeFlag = false;

  /// Dynamic primary color based on theme
  static Color get primaryColor =>
      _isDarkModeFlag ? _primaryBrandColorDark : _primaryBrandColor;

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

  /// Dark mode: Deep purple-blue night sky
  static const Color scaffoldDarkColor = Color(0xFF080C14);

  /// Card backgrounds
  static const Color cardLightColor = Color(0xFFFFFFFF);
  static const Color cardDarkColor = Color(0xFF121A2A);

  /// Surface colors for elevated elements
  static const Color surfaceLightColor = Color(0xFFF5FAFD);
  static const Color surfaceDarkColor = Color(0xFF0C1220);

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
  // Use these instead of magic numbers like 0.85, 0.6, etc.
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
  // STANDARD FONT SIZES
  // Use these for consistent typography
  // ============================================

  /// Extra small text - labels, timestamps (11px)
  static const double fontSizeXS = 11.0;

  /// Small text - captions, secondary info (12px)
  static const double fontSizeS = 12.0;

  /// Body text - regular content (13px)
  static const double fontSizeBody = 13.0;

  /// Medium text - emphasis, subtitles (14px)
  static const double fontSizeM = 14.0;

  /// Regular text - main content (15px)
  static const double fontSizeRegular = 15.0;

  /// Large text - primary content, inputs (16px)
  static const double fontSizeL = 16.0;

  /// Title text - card titles (18-20px)
  static const double fontSizeTitle = 20.0;

  /// Large title - section headers (22px)
  static const double fontSizeLargeTitle = 22.0;

  // ============================================
  // STANDARD ICON SIZES
  // ============================================

  /// Small icons in dense layouts (18-20px)
  static const double iconSizeS = 20.0;

  /// Regular icons (22-24px)
  static const double iconSizeM = 22.0;

  /// Large icons, action buttons (26-28px)
  static const double iconSizeL = 26.0;

  // ============================================
  // RESPONSIVE TYPOGRAPHY & SPACING
  // Use these for adaptive sizing on web vs mobile
  // ============================================

  /// Responsive card title size (14px mobile, 16px desktop)
  static double cardTitleSize(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= 1200 ? 16.0 : 14.0;
  }

  /// Responsive card body text size (13px mobile, 14px desktop)
  static double cardBodySize(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= 1200 ? 14.0 : 13.0;
  }

  /// Responsive hero/feature title size (20px mobile, 28px desktop)
  static double heroTitleSize(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= 1200 ? 28.0 : 20.0;
  }

  /// Responsive section header size (16px mobile, 20px desktop)
  static double sectionHeaderSize(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= 1200 ? 20.0 : 16.0;
  }

  /// Responsive card padding (16px mobile, 24px desktop)
  static double cardPadding(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= 1200 ? 24.0 : 16.0;
  }

  /// Responsive section spacing (12px mobile, 20px desktop)
  static double sectionSpacing(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= 1200 ? 20.0 : 12.0;
  }

  /// Responsive page padding (16px mobile, 32px desktop)
  static double pagePadding(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= 1200 ? 32.0 : 16.0;
  }

  /// Responsive card corner radius (20px mobile, 24px desktop)
  static double cardRadius(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= 1200 ? 24.0 : 20.0;
  }

  /// Check if current context is desktop-sized (>= 1200px)
  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= 1200;
  }

  /// Check if current context is tablet-sized (600-1200px)
  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= 600 && width < 1200;
  }

  /// Check if current context is mobile-sized (< 600px)
  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < 600;
  }

  /// Get a responsive value based on screen size
  static T responsiveValue<T>(
    BuildContext context, {
    required T mobile,
    T? tablet,
    T? desktop,
  }) {
    final width = MediaQuery.of(context).size.width;
    if (width >= 1200) return desktop ?? tablet ?? mobile;
    if (width >= 600) return tablet ?? mobile;
    return mobile;
  }

  // ============================================
  // STANDARD TEXT STYLES
  // Pre-built styles for common use cases
  // ============================================

  /// Card title - bold, large text (e.g., "AURO SCORE", "STARS")
  static TextStyle get cardLabelStyle => TextStyle(
        fontSize: fontSizeXS,
        fontWeight: FontWeight.w800,
        color: primaryColor,
        letterSpacing: 1.2,
      );

  /// Card value - large number display (e.g., score values)
  static TextStyle get cardValueStyle => TextStyle(
        fontSize: fontSizeLargeTitle,
        fontWeight: FontWeight.w600,
        color: primaryColor,
      );

  /// List item title - primary text in list tiles
  static TextStyle get listTitleStyle => TextStyle(
        fontSize: fontSizeRegular,
        fontWeight: FontWeight.w600,
        color: primaryColor,
      );

  /// List item subtitle - secondary text in list tiles
  static TextStyle get listSubtitleStyle => TextStyle(
        fontSize: fontSizeS,
        color: primaryMedium,
      );

  /// Username/nickname style
  static TextStyle get usernameStyle => TextStyle(
        fontSize: fontSizeBody,
        fontWeight: FontWeight.w700,
        color: primaryMedium,
      );

  /// Timestamp/meta info style
  static TextStyle get timestampStyle => TextStyle(
        fontSize: fontSizeS,
        fontWeight: FontWeight.w500,
        color: primaryMedium,
      );

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
      isDark ? _primaryBrandColorDark : _primaryBrandColor;

  /// Astro brown light variant
  static Color astroBrownLight(bool isDark) => isDark
      ? _primaryBrandColorDark.withValues(alpha: 0.3)
      : _primaryBrandColor.withValues(alpha: 0.4);

  /// Astro brown background
  static Color astroBrownBackground(bool isDark) => isDark
      ? _primaryBrandColorDark.withValues(alpha: 0.1)
      : _primaryBrandColor.withValues(alpha: 0.08);

  // ============================================
  // DYNAMIC COLOR GETTERS
  // ============================================

  /// Get card color based on theme
  static Color get cardColor =>
      _isDarkModeFlag ? cardDarkColor : cardLightColor;

  /// Get surface color based on theme
  static Color get surfaceColor =>
      _isDarkModeFlag ? surfaceDarkColor : surfaceLightColor;

  /// Get text color based on theme
  static Color get textColor =>
      _isDarkModeFlag ? textDarkColor : textLightColor;

  /// Get secondary text color based on theme
  static Color get textSecondaryColor =>
      _isDarkModeFlag ? textSecondaryDarkColor : textSecondaryLightColor;

  /// Get scaffold color based on theme
  static Color get scaffoldColor =>
      _isDarkModeFlag ? scaffoldDarkColor : scaffoldLightColor;

  // ============================================
  // CUPERTINO THEME
  // ============================================

  static CupertinoThemeData getCupertinoTheme({bool isDarkMode = false}) {
    _isDarkModeFlag = isDarkMode;
    return CupertinoThemeData(
      brightness: isDarkMode ? Brightness.dark : Brightness.light,
      primaryColor: primaryColor,
      primaryContrastingColor: accentColor,
      scaffoldBackgroundColor:
          isDarkMode ? scaffoldDarkColor : scaffoldLightColor,
      barBackgroundColor: isDarkMode
          ? const Color(0xFF0E1524) // Deep blue night bar
          : const Color(0xFFF0F8FC), // Light sky blue bar
      textTheme: CupertinoTextThemeData(
        primaryColor: isDarkMode ? textDarkColor : textLightColor,
        textStyle: TextStyle(
          color: isDarkMode ? textDarkColor : textLightColor,
          fontSize: 16.0,
          fontWeight: FontWeight.normal,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  // ============================================
  // MATERIAL THEME
  // ============================================

  static ThemeData getMaterialTheme({bool isDarkMode = false}) {
    _isDarkModeFlag = isDarkMode;

    final primaryClr = isDarkMode ? _primaryBrandColorDark : _primaryBrandColor;
    final bgColor = isDarkMode ? scaffoldDarkColor : scaffoldLightColor;
    final surfaceClr = isDarkMode ? surfaceDarkColor : surfaceLightColor;
    final textClr = isDarkMode ? textDarkColor : textLightColor;
    final textSecondaryClr =
        isDarkMode ? textSecondaryDarkColor : textSecondaryLightColor;

    return ThemeData(
      useMaterial3: true,
      brightness: isDarkMode ? Brightness.dark : Brightness.light,
      primaryColor: primaryClr,
      primaryColorLight: primaryLightColor,
      primaryColorDark: primaryDarkColor,
      scaffoldBackgroundColor: bgColor,

      // Color Scheme
      colorScheme: ColorScheme(
        primary: primaryClr,
        primaryContainer:
            isDarkMode ? const Color(0xFF1A2540) : const Color(0xFFD7CCC8),
        secondary: accentColor,
        secondaryContainer:
            isDarkMode ? const Color(0xFF283520) : const Color(0xFFFFF3E0),
        tertiary: grassGreen,
        tertiaryContainer:
            isDarkMode ? const Color(0xFF142515) : const Color(0xFFDCEDC8),
        surface: surfaceClr,
        error: errorColor,
        errorContainer:
            isDarkMode ? const Color(0xFF2A1015) : const Color(0xFFFFCCBC),
        onPrimary: isDarkMode ? const Color(0xFF080C14) : Colors.white,
        onSecondary: isDarkMode ? const Color(0xFF080C14) : Colors.white,
        onTertiary: Colors.white,
        onSurface: textClr,
        onError: Colors.white,
        outline: isDarkMode
            ? Colors.white.withValues(alpha: 0.2)
            : Colors.black.withValues(alpha: 0.12),
        outlineVariant: isDarkMode
            ? Colors.white.withValues(alpha: 0.1)
            : Colors.black.withValues(alpha: 0.06),
        brightness: isDarkMode ? Brightness.dark : Brightness.light,
      ),

      // Card Theme
      cardTheme: CardThemeData(
        color: isDarkMode ? cardDarkColor : cardLightColor,
        elevation: isDarkMode ? 2 : 1,
        shadowColor: isDarkMode
            ? Colors.black.withValues(alpha: 0.4)
            : Colors.black.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        ),
      ),

      // Elevated Button Theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryClr,
          foregroundColor: isDarkMode ? const Color(0xFF080C14) : Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          ),
          elevation: 2,
          shadowColor: primaryClr.withValues(alpha: 0.4),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            letterSpacing: 0.5,
          ),
        ),
      ),

      // Text Button Theme
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryClr,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            letterSpacing: 0.5,
          ),
        ),
      ),

      // Outlined Button Theme
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryClr,
          side: BorderSide(color: primaryClr, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            letterSpacing: 0.5,
          ),
        ),
      ),

      // Floating Action Button Theme
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: accentColor,
        foregroundColor: const Color(0xFF080C14),
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        ),
      ),

      // App Bar Theme
      appBarTheme: AppBarTheme(
        backgroundColor: isDarkMode ? scaffoldDarkColor : Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: true,
        shadowColor: isDarkMode
            ? Colors.transparent
            : Colors.black.withValues(alpha: 0.06),
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness:
              isDarkMode ? Brightness.light : Brightness.dark,
          statusBarBrightness: isDarkMode ? Brightness.dark : Brightness.light,
          systemNavigationBarColor: bgColor,
          systemNavigationBarIconBrightness:
              isDarkMode ? Brightness.light : Brightness.dark,
        ),
        titleTextStyle: TextStyle(
          color: textClr,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
        ),
        iconTheme: IconThemeData(
          color: isDarkMode ? textDarkColor : primaryClr,
          size: 24,
        ),
        actionsIconTheme: IconThemeData(
          color: isDarkMode ? textDarkColor : primaryClr,
          size: 24,
        ),
        toolbarHeight: 56,
      ),

      // Bottom Navigation Bar Theme
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: isDarkMode ? const Color(0xFF0E1524) : Colors.white,
        selectedItemColor: primaryClr,
        unselectedItemColor: textSecondaryClr,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),

      // Navigation Bar Theme (Material 3)
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isDarkMode ? const Color(0xFF0E1524) : Colors.white,
        indicatorColor: primaryClr.withValues(alpha: 0.2),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: primaryClr);
          }
          return IconThemeData(color: textSecondaryClr);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(
              color: primaryClr,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            );
          }
          return TextStyle(
            color: textSecondaryClr,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          );
        }),
      ),

      // Text Theme
      textTheme: TextTheme(
        displayLarge: _systemFont(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: textClr,
          letterSpacing: -0.5,
        ),
        displayMedium: _systemFont(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: textClr,
          letterSpacing: -0.3,
        ),
        displaySmall: _systemFont(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: textClr,
          letterSpacing: -0.1,
        ),
        headlineLarge: _systemFont(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: textClr,
          letterSpacing: 0.0,
        ),
        headlineMedium: _systemFont(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textClr,
          letterSpacing: 0.0,
        ),
        headlineSmall: _systemFont(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: textClr,
          letterSpacing: 0.1,
        ),
        titleLarge: _systemFont(
          fontSize: 18,
          fontWeight: FontWeight.w500,
          color: textClr,
          letterSpacing: 0.0,
        ),
        titleMedium: _systemFont(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: textClr,
          letterSpacing: 0.1,
        ),
        titleSmall: _systemFont(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: textClr,
          letterSpacing: 0.1,
        ),
        bodyLarge: _systemFont(
          fontSize: 16,
          fontWeight: FontWeight.normal,
          color: textClr,
          letterSpacing: 0.15,
        ),
        bodyMedium: _systemFont(
          fontSize: 14,
          fontWeight: FontWeight.normal,
          color: textClr,
          letterSpacing: 0.2,
        ),
        bodySmall: _systemFont(
          fontSize: 12,
          fontWeight: FontWeight.normal,
          color: textSecondaryClr,
          letterSpacing: 0.4,
        ),
        labelLarge: _systemFont(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: textClr,
          letterSpacing: 0.1,
        ),
        labelMedium: _systemFont(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: textSecondaryClr,
          letterSpacing: 0.5,
        ),
        labelSmall: _systemFont(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: textSecondaryClr,
          letterSpacing: 0.5,
        ),
      ),

      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDarkMode
            ? Colors.white.withValues(alpha: 0.05)
            : const Color(0xFFF5F2ED),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          borderSide: BorderSide(
            color: isDarkMode
                ? Colors.white.withValues(alpha: 0.15)
                : const Color(0xFFE0D8CC),
            width: 1.0,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          borderSide: BorderSide(
            color: isDarkMode
                ? Colors.white.withValues(alpha: 0.15)
                : const Color(0xFFE0D8CC),
            width: 1.0,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          borderSide: BorderSide(
            color: primaryClr,
            width: 2.0,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          borderSide: const BorderSide(
            color: errorColor,
            width: 1.5,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          borderSide: const BorderSide(
            color: errorColor,
            width: 2.0,
          ),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        hintStyle: TextStyle(
          color: textSecondaryClr.withValues(alpha: 0.7),
          fontSize: 16,
        ),
        labelStyle: TextStyle(
          color: textSecondaryClr,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        floatingLabelStyle: TextStyle(
          color: primaryClr,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        prefixIconColor: textSecondaryClr,
        suffixIconColor: textSecondaryClr,
      ),

      // Chip Theme
      chipTheme: ChipThemeData(
        backgroundColor: isDarkMode
            ? Colors.white.withValues(alpha: 0.08)
            : const Color(0xFFF0EBE3),
        selectedColor: primaryClr.withValues(alpha: 0.2),
        disabledColor: isDarkMode
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.grey.shade200,
        labelStyle: TextStyle(
          color: textClr,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        secondaryLabelStyle: TextStyle(
          color: primaryClr,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingMd, vertical: AppDimensions.paddingSm),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
        ),
      ),

      // Dialog Theme
      dialogTheme: DialogThemeData(
        backgroundColor: isDarkMode ? cardDarkColor : cardLightColor,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
        ),
        titleTextStyle: TextStyle(
          color: textClr,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        contentTextStyle: TextStyle(
          color: textSecondaryClr,
          fontSize: 16,
        ),
      ),

      // Bottom Sheet Theme
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: isDarkMode ? cardDarkColor : cardLightColor,
        elevation: 8,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        dragHandleColor: isDarkMode
            ? Colors.white.withValues(alpha: 0.3)
            : Colors.black.withValues(alpha: 0.2),
        dragHandleSize: const Size(40, 4),
      ),

      // Snack Bar Theme
      snackBarTheme: SnackBarThemeData(
        backgroundColor:
            isDarkMode ? const Color(0xFF162035) : const Color(0xFF2D2016),
        contentTextStyle: const TextStyle(
          color: Color(0xFFF5F0E8),
          fontSize: 14,
        ),
        actionTextColor: accentColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        ),
      ),

      // List Tile Theme
      listTileTheme: ListTileThemeData(
        iconColor: primaryClr,
        textColor: textClr,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        ),
      ),

      // Switch Theme
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return primaryClr;
          }
          return isDarkMode ? Colors.grey.shade600 : Colors.grey.shade400;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return primaryClr.withValues(alpha: 0.4);
          }
          return isDarkMode
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.black.withValues(alpha: 0.1);
        }),
      ),

      // Checkbox Theme
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return primaryClr;
          }
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(
          isDarkMode ? const Color(0xFF080C14) : Colors.white,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusXs),
        ),
      ),

      // Radio Theme
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return primaryClr;
          }
          return textSecondaryClr;
        }),
      ),

      // Slider Theme
      sliderTheme: SliderThemeData(
        activeTrackColor: primaryClr,
        inactiveTrackColor: primaryClr.withValues(alpha: 0.2),
        thumbColor: primaryClr,
        overlayColor: primaryClr.withValues(alpha: 0.2),
      ),

      // Progress Indicator Theme
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: primaryClr,
        linearTrackColor: primaryClr.withValues(alpha: 0.2),
        circularTrackColor: primaryClr.withValues(alpha: 0.2),
      ),

      // Divider Theme
      dividerTheme: DividerThemeData(
        color: isDarkMode
            ? Colors.white.withValues(alpha: 0.1)
            : Colors.black.withValues(alpha: 0.06),
        thickness: 1,
        space: 0,
      ),

      // Tab Bar Theme
      tabBarTheme: TabBarThemeData(
        labelColor: isDarkMode ? Colors.white : scaffoldDarkColor,
        unselectedLabelColor: textSecondaryClr,
        indicatorColor: isDarkMode ? Colors.white : scaffoldDarkColor,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 14,
        ),
      ),

      // Icon Theme
      iconTheme: IconThemeData(
        color: isDarkMode ? textDarkColor : textLightColor,
        size: 24,
      ),

      // Primary Icon Theme
      primaryIconTheme: IconThemeData(
        color: primaryClr,
        size: 24,
      ),
    );
  }
}
