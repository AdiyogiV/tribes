import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:aurogram/utils/theme/app_dimensions.dart';

/// Helper class to provide consistent theme styling throughout the app
class ThemeHelper {
  // Responsive breakpoints
  static const double tabletBreakpoint = 600.0;
  static const double largeTabletBreakpoint = 900.0;
  static const double desktopBreakpoint = 1200.0;

  // Check if current screen is tablet or larger
  static bool isTablet(BuildContext context) {
    return MediaQuery.of(context).size.width >= tabletBreakpoint;
  }

  // Check if current screen is large tablet or larger
  static bool isLargeTablet(BuildContext context) {
    return MediaQuery.of(context).size.width >= largeTabletBreakpoint;
  }

  // Check if current screen is desktop or larger
  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= desktopBreakpoint;
  }

  /// Check if dark mode is active
  static bool isDarkMode(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark;
  }

  // Get responsive height factor based on screen size
  static double getResponsiveHeightFactor(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    if (screenWidth >= largeTabletBreakpoint) {
      return 0.5;
    } else if (screenWidth >= tabletBreakpoint) {
      return 0.6;
    }
    return 1.0;
  }

  // Get responsive padding based on screen size
  static double getResponsivePadding(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    if (screenWidth >= largeTabletBreakpoint) {
      return 6.0;
    } else if (screenWidth >= tabletBreakpoint) {
      return 5.0;
    }
    return 5.0;
  }

  // Get responsive spacing based on screen size
  static double getResponsiveSpacing(BuildContext context,
      {double baseSpacing = 8.0}) {
    final screenWidth = MediaQuery.of(context).size.width;

    if (screenWidth >= largeTabletBreakpoint) {
      return baseSpacing * 1.5;
    } else if (screenWidth >= tabletBreakpoint) {
      return baseSpacing * 1.25;
    }
    return baseSpacing;
  }

  // ============================================
  // BACKWARD COMPATIBLE STATIC GETTERS (Light Mode)
  // ============================================

  /// Get standard title text style (light mode default)
  static TextStyle get titleStyle => TextStyle(
        color: AppTheme.textLightColor,
        fontSize: 28,
        fontWeight: FontWeight.bold,
      );

  /// Get standard subtitle text style (light mode default)
  static TextStyle get subtitleStyle => TextStyle(
        color: AppTheme.textLightColor,
        fontSize: 24,
        fontWeight: FontWeight.w600,
      );

  /// Get standard heading text style (light mode default)
  static TextStyle get subheadingStyle => TextStyle(
        color: AppTheme.textLightColor,
        fontSize: 18,
        fontWeight: FontWeight.w500,
      );

  /// Get standard body text style (light mode default)
  static TextStyle get bodyTextStyle => TextStyle(
        color: AppTheme.textLightColor,
        fontSize: 16,
      );

  /// Get standard caption text style (light mode default)
  static TextStyle get captionStyle => TextStyle(
        color: AppTheme.textSecondaryLightColor,
        fontSize: 14,
      );

  /// Get standard hint text style (light mode default)
  static TextStyle get hintStyle => TextStyle(
        color: AppTheme.textSecondaryLightColor,
        fontSize: 16,
      );

  /// Get standard error text style
  static TextStyle get errorStyle => TextStyle(
        color: AppTheme.errorColor,
        fontSize: 14,
      );

  /// Get standard card decoration (light mode default)
  static BoxDecoration get cardDecoration => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      );

  /// Get standard text field decoration (light mode default)
  static InputDecoration getTextFieldDecoration({
    String? hintText,
    String? labelText,
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      labelText: labelText,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: const Color(0xFFF5F2ED),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        borderSide: const BorderSide(color: AppTheme.borderLightColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        borderSide: const BorderSide(color: AppTheme.borderLightColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        borderSide: const BorderSide(color: AppTheme.errorColor, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        borderSide: const BorderSide(color: AppTheme.errorColor, width: 2),
      ),
      hintStyle: hintStyle,
      labelStyle: TextStyle(color: AppTheme.textSecondaryLightColor),
    );
  }

  /// Alias for getTextFieldDecoration to maintain backward compatibility
  static InputDecoration inputDecoration({
    String? labelText, 
    String? hintText,
  }) {
    return getTextFieldDecoration(
      labelText: labelText,
      hintText: hintText,
    );
  }

  /// Alias for titleStyle to maintain backward compatibility
  static TextStyle get headingStyle => titleStyle;

  /// Get standard button style (light mode default)
  static ButtonStyle get primaryButtonStyle => ElevatedButton.styleFrom(
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      );

  /// Get standard outlined button style
  static ButtonStyle get outlinedButtonStyle => OutlinedButton.styleFrom(
        foregroundColor: AppTheme.primaryColor,
        side: BorderSide(color: AppTheme.primaryColor, width: 1.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      );

  /// Get standard text button style
  static ButtonStyle get textButtonStyle => TextButton.styleFrom(
        foregroundColor: AppTheme.primaryColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        ),
        padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingLg, vertical: AppDimensions.paddingSm),
      );

  /// Get standard floating action button theme
  static FloatingActionButtonThemeData get fabTheme =>
      FloatingActionButtonThemeData(
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusLg)),
      );

  /// Get standardized app bar theme (light mode default)
  static AppBarTheme get appBarTheme => AppBarTheme(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: AppTheme.primaryColor),
        titleTextStyle: TextStyle(
          color: AppTheme.textLightColor,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      );

  /// Get standardized header style for tab pages
  static TextStyle get headerStyle => TextStyle(
        color: AppTheme.primaryColor,
        fontSize: 22,
        fontWeight: FontWeight.w200,
        letterSpacing: 1.2,
      );

  /// Get standardized header gradient decoration (light mode default)
  static BoxDecoration get headerGradientDecoration => BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.scaffoldLightColor,
            AppTheme.scaffoldLightColor.withValues(alpha: 0.8)
          ],
          begin: const FractionalOffset(0.0, 0.0),
          end: const FractionalOffset(0.0, 1),
          stops: const [0.0, 1.0],
          tileMode: TileMode.mirror,
        ),
      );

  /// Get standardized pull-to-refresh header (light mode default)
  static ClassicHeader get refreshHeader => ClassicHeader(
        idleText: 'Pull down to refresh',
        releaseText: 'Release to refresh',
        refreshingText: 'Refreshing…',
        completeText: 'Refreshed',
        failedText: 'Refresh failed',
        spacing: 8.0,
        textStyle: TextStyle(
          color: AppTheme.textSecondaryLightColor,
          fontSize: 12,
        ),
        outerBuilder: (child) => Container(
          color: Colors.transparent,
          padding: const EdgeInsets.only(top: 8, bottom: 8),
          child: child,
        ),
      );

  /// Get standardized search field decoration (light mode default)
  static InputDecoration get searchFieldDecoration => InputDecoration(
        filled: true,
        fillColor: Colors.white,
        hintStyle: TextStyle(color: AppTheme.textSecondaryLightColor),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      );

  // ============================================
  // THEME-AWARE METHODS (for dark mode support)
  // ============================================

  /// Get title text style (theme-aware)
  static TextStyle titleStyleFor(BuildContext context) {
    final isDark = isDarkMode(context);
    return TextStyle(
      color: isDark ? AppTheme.textDarkColor : AppTheme.textLightColor,
      fontSize: 28,
      fontWeight: FontWeight.bold,
    );
  }

  /// Get body text style (theme-aware)
  static TextStyle bodyTextStyleFor(BuildContext context) {
    final isDark = isDarkMode(context);
    return TextStyle(
      color: isDark ? AppTheme.textDarkColor : AppTheme.textLightColor,
      fontSize: 16,
    );
  }

  /// Get caption text style (theme-aware)
  static TextStyle captionStyleFor(BuildContext context) {
    final isDark = isDarkMode(context);
    return TextStyle(
      color: isDark ? AppTheme.textSecondaryDarkColor : AppTheme.textSecondaryLightColor,
      fontSize: 14,
    );
  }

  /// Get card decoration (theme-aware)
  static BoxDecoration cardDecorationFor(BuildContext context) {
    final isDark = isDarkMode(context);
    return BoxDecoration(
      color: isDark ? AppTheme.cardDarkColor : AppTheme.cardLightColor,
      borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
      boxShadow: [
        BoxShadow(
          color: isDark 
              ? Colors.black.withValues(alpha: 0.3) 
              : Colors.black.withValues(alpha: 0.06),
          blurRadius: isDark ? 8 : 12,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  /// Get primary button style (theme-aware)
  static ButtonStyle primaryButtonStyleFor(BuildContext context) {
    final isDark = isDarkMode(context);
    return ElevatedButton.styleFrom(
      backgroundColor: AppTheme.primaryColor,
      foregroundColor: isDark ? const Color(0xFF1C1410) : Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
    );
  }

  /// Get pull-to-refresh header (theme-aware)
  static ClassicHeader refreshHeaderFor(BuildContext context) {
    final isDark = isDarkMode(context);
    return ClassicHeader(
      idleText: 'Pull down to refresh',
      releaseText: 'Release to refresh',
      refreshingText: 'Refreshing…',
      completeText: 'Refreshed',
      failedText: 'Refresh failed',
      spacing: 8.0,
      textStyle: TextStyle(
        color: isDark ? AppTheme.textSecondaryDarkColor : AppTheme.textSecondaryLightColor,
        fontSize: 12,
      ),
      outerBuilder: (child) => Container(
        color: Colors.transparent,
        padding: const EdgeInsets.only(top: 8, bottom: 8),
        child: child,
      ),
    );
  }

  // ============================================
  // FARM THEME SPECIFIC HELPERS
  // ============================================

  /// Get golden accent color for highlights
  static Color get goldenAccent => AppTheme.sunGold;
  
  /// Get grass green for success states
  static Color get freshGreen => AppTheme.grassGreen;
  
  /// Get barn red for alerts/errors
  static Color get alertRed => AppTheme.barnRed;

  /// Get farm-themed gradient
  static LinearGradient farmGradient(BuildContext context) {
    final isDark = isDarkMode(context);
    if (isDark) {
      return const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF2D2420),
          Color(0xFF1C1410),
        ],
      );
    }
    return const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color(0xFFFDF8F0),
        Color(0xFFFAF7F2),
      ],
    );
  }

  /// Get astro-themed decoration
  static BoxDecoration astroDecoration(BuildContext context) {
    final isDark = isDarkMode(context);
    final brown = AppTheme.astroBrown(isDark);
    return BoxDecoration(
      color: isDark 
          ? Colors.white.withValues(alpha: 0.05) 
          : Colors.white,
      borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      border: Border.all(
        color: brown.withValues(alpha: isDark ? 0.3 : 0.2),
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: isDark
              ? Colors.black.withValues(alpha: 0.2)
              : brown.withValues(alpha: 0.1),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }
}
