import 'package:flutter/material.dart';

import 'package:aurogram/core/theme/app_colors.dart';

/// Font size constants, text style definitions, and responsive typography.
class AppTypography {
  AppTypography._();

  // ============================================
  // HOLYCOW PAGE — CONFIGURABLE TEXT SIZE
  // ============================================
  static const double holyCowTextSize = 15.0;

  // ============================================
  // STANDARD FONT SIZES
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
  // STANDARD TEXT STYLES
  // ============================================

  /// Helper to create text style with system font
  static TextStyle systemFont({
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

  /// Card title - bold, large text (e.g., "AURO SCORE", "STARS")
  static TextStyle get cardLabelStyle => TextStyle(
        fontSize: fontSizeXS,
        fontWeight: FontWeight.w800,
        color: AppColors.primaryColor,
        letterSpacing: 1.2,
      );

  /// Card value - large number display (e.g., score values)
  static TextStyle get cardValueStyle => TextStyle(
        fontSize: fontSizeLargeTitle,
        fontWeight: FontWeight.w600,
        color: AppColors.primaryColor,
      );

  /// List item title - primary text in list tiles
  static TextStyle get listTitleStyle => TextStyle(
        fontSize: fontSizeRegular,
        fontWeight: FontWeight.w600,
        color: AppColors.primaryColor,
      );

  /// List item subtitle - secondary text in list tiles
  static TextStyle get listSubtitleStyle => TextStyle(
        fontSize: fontSizeS,
        color: AppColors.primaryMedium,
      );

  /// Username/nickname style
  static TextStyle get usernameStyle => TextStyle(
        fontSize: fontSizeBody,
        fontWeight: FontWeight.w700,
        color: AppColors.primaryMedium,
      );

  /// Timestamp/meta info style
  static TextStyle get timestampStyle => TextStyle(
        fontSize: fontSizeS,
        fontWeight: FontWeight.w500,
        color: AppColors.primaryMedium,
      );

  /// Build the full Material TextTheme for a given text/secondary color.
  static TextTheme buildTextTheme(Color textClr, Color textSecondaryClr) {
    return TextTheme(
      displayLarge: systemFont(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: textClr,
        letterSpacing: -0.5,
      ),
      displayMedium: systemFont(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: textClr,
        letterSpacing: -0.3,
      ),
      displaySmall: systemFont(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: textClr,
        letterSpacing: -0.1,
      ),
      headlineLarge: systemFont(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: textClr,
        letterSpacing: 0.0,
      ),
      headlineMedium: systemFont(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: textClr,
        letterSpacing: 0.0,
      ),
      headlineSmall: systemFont(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: textClr,
        letterSpacing: 0.1,
      ),
      titleLarge: systemFont(
        fontSize: 18,
        fontWeight: FontWeight.w500,
        color: textClr,
        letterSpacing: 0.0,
      ),
      titleMedium: systemFont(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: textClr,
        letterSpacing: 0.1,
      ),
      titleSmall: systemFont(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: textClr,
        letterSpacing: 0.1,
      ),
      bodyLarge: systemFont(
        fontSize: 16,
        fontWeight: FontWeight.normal,
        color: textClr,
        letterSpacing: 0.15,
      ),
      bodyMedium: systemFont(
        fontSize: 14,
        fontWeight: FontWeight.normal,
        color: textClr,
        letterSpacing: 0.2,
      ),
      bodySmall: systemFont(
        fontSize: 12,
        fontWeight: FontWeight.normal,
        color: textSecondaryClr,
        letterSpacing: 0.4,
      ),
      labelLarge: systemFont(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: textClr,
        letterSpacing: 0.1,
      ),
      labelMedium: systemFont(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: textSecondaryClr,
        letterSpacing: 0.5,
      ),
      labelSmall: systemFont(
        fontSize: 10,
        fontWeight: FontWeight.w500,
        color: textSecondaryClr,
        letterSpacing: 0.5,
      ),
    );
  }
}
