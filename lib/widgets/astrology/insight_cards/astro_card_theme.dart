import 'package:flutter/material.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:aurogram/utils/astrology/planet_utils.dart';
import 'package:aurogram/utils/theme/app_dimensions.dart';

/// Minimal theme for insight cards - matches astrology details page style
/// Now integrated with main AppTheme for consistency
class AstroCardTheme {
  final bool isDark;
  
  AstroCardTheme(this.isDark);
  
  // Core astrology brown colors
  Color get brown => AppTheme.astroBrown(isDark);
  Color get brownLight => brown.withValues(alpha: 0.7);
  Color get brownBody => brown.withValues(alpha: 0.85);
  
  // Card colors - from AppTheme
  Color get cardBackground => isDark 
      ? AppTheme.cardDarkColor 
      : AppTheme.cardLightColor;
  
  Color get cardBorder => isDark
      ? Colors.white.withValues(alpha: 0.1)
      : brown.withValues(alpha: 0.12);
  
  // Status colors - using farm-inspired colors
  Color get alertAmber => isDark 
      ? AppTheme.sunGold 
      : AppTheme.honeyAmber;
  Color get successGreen => isDark 
      ? const Color(0xFF81C784) 
      : AppTheme.grassGreen;
  Color get errorRed => AppTheme.barnRed;
  
  // Text color helpers
  Color get textPrimary => isDark 
      ? AppTheme.textDarkColor 
      : AppTheme.textLightColor;
  Color get textSecondary => isDark 
      ? AppTheme.textSecondaryDarkColor 
      : AppTheme.textSecondaryLightColor;
  
  // Standard card decoration - matches Material elevation 2, borderRadius 20
  BoxDecoration get cardDecoration => BoxDecoration(
    color: cardBackground,
    borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.2),
        blurRadius: 6,
        offset: const Offset(0, 2),
      ),
    ],
  );
  
  // Highlighted card decoration (for important insights)
  BoxDecoration get highlightedCardDecoration => BoxDecoration(
    color: cardBackground,
    borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
    border: Border.all(
      color: isDark 
          ? AppTheme.sunGold.withValues(alpha: 0.3) 
          : AppTheme.honeyAmber.withValues(alpha: 0.4),
      width: 1.5,
    ),
    boxShadow: [
      BoxShadow(
        color: isDark
            ? AppTheme.sunGold.withValues(alpha: 0.1)
            : AppTheme.honeyAmber.withValues(alpha: 0.15),
        blurRadius: 12,
        offset: const Offset(0, 4),
      ),
    ],
  );
  
  // Typography - aligned with birth details card styling
  TextStyle get labelStyle => TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: brown.withValues(alpha: 0.6),
  );
  
  TextStyle get titleStyle => TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    color: brown,
  );
  
  TextStyle get bodyStyle => TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    height: 1.5,
    color: brownBody,
  );
  
  TextStyle get valueStyle => TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w700,
    color: brown,
    height: 1.3,
  );
  
  TextStyle get smallStyle => TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: brownLight,
  );
  
  // Large title style for headers
  TextStyle get headerStyle => TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: brown,
  );
  
  // Spacing - matches birth details card
  EdgeInsets get cardPadding => const EdgeInsets.all(AppDimensions.paddingLg);
  double get titleContentSpacing => 12;
  
  // Planet symbols - delegated to PlanetUtils for single source of truth
  static String getSymbol(String planet) => PlanetUtils.getSymbol(planet);
  
  /// Builds rich text widget with markdown-style formatting:
  /// - **bold** renders in bold with brown color
  /// - _italic_ renders in italic
  Widget buildRichText(String text, {TextStyle? baseStyle}) {
    final style = baseStyle ?? bodyStyle;
    final List<TextSpan> spans = [];
    final RegExp pattern = RegExp(r'\*\*(.+?)\*\*|_(.+?)_|([^*_]+)');
    
    for (final match in pattern.allMatches(text)) {
      if (match.group(1) != null) {
        // **bold**
        spans.add(TextSpan(
          text: match.group(1),
          style: TextStyle(fontWeight: FontWeight.w700, color: brown),
        ));
      } else if (match.group(2) != null) {
        // _italic_
        spans.add(TextSpan(
          text: match.group(2),
          style: TextStyle(fontStyle: FontStyle.italic, color: brownBody),
        ));
      } else if (match.group(3) != null) {
        // Regular text
        spans.add(TextSpan(text: match.group(3)));
      }
    }
    
    return RichText(
      text: TextSpan(
        style: style,
        children: spans.isEmpty ? [TextSpan(text: text)] : spans,
      ),
    );
  }
  
  // Get planet-specific color - delegated to PlanetUtils for consistency
  Color getPlanetColor(String planet) => PlanetUtils.getColor(planet, isDark);
}

extension AstroCardThemeExtension on BuildContext {
  AstroCardTheme get astroCardTheme => 
      AstroCardTheme(Theme.of(this).brightness == Brightness.dark);
}
