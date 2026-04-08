import 'package:flutter/material.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';

/// Shared decoration helpers for astrology UI components
/// Ensures consistent styling across all astrology-related widgets
class AstrologyDecorations {
  /// Get astrology accent color based on theme
  static Color accentColor(bool isDark) => AppTheme.astroBrown(isDark);
  
  /// Get lighter accent color for backgrounds
  static Color accentLight(bool isDark) => AppTheme.astroBrownLight(isDark);
  
  /// Get subtle background tint
  static Color accentBackground(bool isDark) => AppTheme.astroBrownBackground(isDark);

  /// Standard card decoration used across astrology widgets
  /// Used for: insight cards, birth details, samvat cards, etc.
  static BoxDecoration cardDecoration(BuildContext context, {
    double borderRadius = 12,
    bool elevated = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return BoxDecoration(
      color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: isDark
            ? Colors.white.withValues(alpha: 0.1)
            : Colors.grey.withValues(alpha: 0.15),
        width: 1,
      ),
      boxShadow: elevated ? [
        BoxShadow(
          color: isDark
              ? Colors.black.withValues(alpha: 0.15)
              : Colors.black.withValues(alpha: 0.06),
          blurRadius: 12,
          offset: const Offset(0, 4),
          spreadRadius: 0,
        ),
      ] : [
        BoxShadow(
          color: isDark
              ? Colors.black.withValues(alpha: 0.1)
              : Colors.black.withValues(alpha: 0.04),
          blurRadius: 8,
          offset: const Offset(0, 2),
          spreadRadius: 0,
        ),
      ],
    );
  }

  /// Card decoration with accent border
  static BoxDecoration accentedCardDecoration(BuildContext context, {
    double borderRadius = 12,
    double borderOpacity = 0.3,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = accentColor(isDark);
    
    return BoxDecoration(
      color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: accent.withValues(alpha: borderOpacity),
        width: 1.5,
      ),
      boxShadow: [
        BoxShadow(
          color: isDark
              ? Colors.black.withValues(alpha: 0.1)
              : Colors.black.withValues(alpha: 0.04),
          blurRadius: 8,
          offset: const Offset(0, 2),
          spreadRadius: 0,
        ),
      ],
    );
  }

  /// Tappable/selectable card decoration
  static BoxDecoration selectableCardDecoration(BuildContext context, {
    bool isSelected = false,
    double borderRadius = 14,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = accentColor(isDark);
    
    return BoxDecoration(
      color: isSelected
          ? accent.withValues(alpha: 0.15)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: isSelected
            ? accent
            : Colors.grey.withValues(alpha: 0.3),
        width: isSelected ? 2 : 1,
      ),
    );
  }

  /// Info/hint card decoration with subtle background
  static BoxDecoration infoCardDecoration(BuildContext context, {
    double borderRadius = 16,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = accentColor(isDark);
    
    return BoxDecoration(
      color: accentBackground(isDark),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: accent.withValues(alpha: 0.3),
        width: 1.5,
      ),
    );
  }

  /// Section label text style (small caps, accented)
  static TextStyle sectionLabelStyle(bool isDark) {
    return TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      color: accentColor(isDark),
      letterSpacing: 0.8,
    );
  }

  /// Section header text style
  static TextStyle sectionHeaderStyle(bool isDark) {
    return TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.3,
      color: isDark ? AppTheme.textDarkColor : AppTheme.textLightColor,
    );
  }

  /// Body text style for insight content
  static TextStyle insightTextStyle(bool isDark, {double opacity = 0.9}) {
    return TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w500,
      height: 1.6,
      color: accentColor(isDark).withValues(alpha: opacity),
    );
  }

  /// Subtle divider
  static Widget divider(bool isDark, {double height = 1}) {
    final accent = accentColor(isDark);
    return Container(
      height: height,
      color: accent.withValues(alpha: 0.15),
    );
  }

  /// Circular icon container decoration
  static BoxDecoration iconContainerDecoration(bool isDark, {
    double opacity = 0.2,
    double borderRadius = 12,
    bool circular = false,
  }) {
    final accent = accentColor(isDark);
    return BoxDecoration(
      color: accent.withValues(alpha: opacity),
      borderRadius: circular ? null : BorderRadius.circular(borderRadius),
      shape: circular ? BoxShape.circle : BoxShape.rectangle,
    );
  }

  /// Standard padding values
  static const EdgeInsets cardPadding = EdgeInsets.all(AppDimensions.paddingLg);
  static const EdgeInsets cardPaddingCompact = EdgeInsets.all(AppDimensions.paddingMd);
  static const EdgeInsets horizontalPadding = EdgeInsets.symmetric(horizontal: AppDimensions.paddingLg);
  static const double cardBorderRadius = 12;
  static const double cardBorderRadiusLarge = 20;
}




