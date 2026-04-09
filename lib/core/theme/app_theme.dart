import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:aurogram/core/theme/app_colors.dart';
import 'package:aurogram/core/theme/app_decorations.dart';
import 'package:aurogram/core/theme/app_typography.dart';
import 'package:aurogram/core/theme/component_themes.dart';

/// Thin facade that re-exports the full theme API via the original `AppTheme`
/// class name. All implementation lives in focused modules:
///   - [AppColors] — color constants and dynamic color getters
///   - [AppTypography] — font sizes and text style definitions
///   - [AppDecorations] — responsive helpers, breakpoints
///   - [ComponentThemes] — Material / Cupertino component overrides
class AppTheme {
  AppTheme._();

  // ------------------------------------------------------------------
  // Colors — delegated to AppColors
  // ------------------------------------------------------------------
  static Color get primaryColor => AppColors.primaryColor;
  static const Color primaryLightColor = AppColors.primaryLightColor;
  static const Color primaryDarkColor = AppColors.primaryDarkColor;

  static const Color sunGold = AppColors.sunGold;
  static const Color honeyAmber = AppColors.honeyAmber;
  static const Color grassGreen = AppColors.grassGreen;
  static const Color forestGreen = AppColors.forestGreen;
  static const Color barnRed = AppColors.barnRed;
  static const Color terracotta = AppColors.terracotta;
  static const Color skyBlue = AppColors.skyBlue;
  static const Color peachCream = AppColors.peachCream;
  static const Color woodBrown = AppColors.woodBrown;
  static const Color accentColor = AppColors.accentColor;
  static const Color accentLightColor = AppColors.accentLightColor;
  static const Color accentDarkColor = AppColors.accentDarkColor;

  static const Color scaffoldLightColor = AppColors.scaffoldLightColor;
  static const Color scaffoldDarkColor = AppColors.scaffoldDarkColor;
  static const Color cardLightColor = AppColors.cardLightColor;
  static const Color cardDarkColor = AppColors.cardDarkColor;
  static const Color surfaceLightColor = AppColors.surfaceLightColor;
  static const Color surfaceDarkColor = AppColors.surfaceDarkColor;

  static const Color textLightColor = AppColors.textLightColor;
  static const Color textDarkColor = AppColors.textDarkColor;
  static const Color textSecondaryLightColor = AppColors.textSecondaryLightColor;
  static const Color textSecondaryDarkColor = AppColors.textSecondaryDarkColor;

  static const double opacityHigh = AppColors.opacityHigh;
  static const double opacityMedium = AppColors.opacityMedium;
  static const double opacityLow = AppColors.opacityLow;
  static const double opacitySubtle = AppColors.opacitySubtle;
  static Color get primaryHigh => AppColors.primaryHigh;
  static Color get primaryMedium => AppColors.primaryMedium;
  static Color get primaryLow => AppColors.primaryLow;

  static const Color successColor = AppColors.successColor;
  static const Color warningColor = AppColors.warningColor;
  static const Color errorColor = AppColors.errorColor;
  static const Color infoColor = AppColors.infoColor;

  static const Color pastelMint = AppColors.pastelMint;
  static const Color pastelLavender = AppColors.pastelLavender;
  static const Color pastelPeach = AppColors.pastelPeach;
  static const Color pastelLilac = AppColors.pastelLilac;

  static const Color activeGreen = AppColors.activeGreen;
  static const Color pitchBlack = AppColors.pitchBlack;
  static const Color cosmicPurple = AppColors.cosmicPurple;
  static const Color sheetDarkColor = AppColors.sheetDarkColor;
  static const Color dangerRed = AppColors.dangerRed;
  static const Color skeletonLightColor = AppColors.skeletonLightColor;
  static const Color darkGradientBase = AppColors.darkGradientBase;
  static const Color emeraldGreen = AppColors.emeraldGreen;
  static const Color previewLightColor = AppColors.previewLightColor;
  static const Color goldColor = AppColors.goldColor;
  static const Color pinkAccent = AppColors.pinkAccent;
  static const Color skeletonBaseLight = AppColors.skeletonBaseLight;
  static const Color previewDarkColor = AppColors.previewDarkColor;
  static const Color darkGradientMid = AppColors.darkGradientMid;
  static const Color borderLightColor = AppColors.borderLightColor;
  static const Color skeletonShimmerLight = AppColors.skeletonShimmerLight;
  static const Color nearBlackColor = AppColors.nearBlackColor;
  static const Color aquamarine = AppColors.aquamarine;
  static const Color amberAccent = AppColors.amberAccent;
  static const Color rosePink = AppColors.rosePink;
  static const Color lavenderGlow = AppColors.lavenderGlow;
  static const Color softViolet = AppColors.softViolet;
  static const Color indigoColor = AppColors.indigoColor;
  static const Color darkPlaceholder = AppColors.darkPlaceholder;
  static const Color darkGradientDeep = AppColors.darkGradientDeep;
  static const Color lightBlueAccent = AppColors.lightBlueAccent;
  static const Color callBackground = AppColors.callBackground;
  static const Color callGradientMid = AppColors.callGradientMid;
  static const Color darkElevatedSurface = AppColors.darkElevatedSurface;

  static Color astroBrown(bool isDark) => AppColors.astroBrown(isDark);
  static Color astroBrownLight(bool isDark) => AppColors.astroBrownLight(isDark);
  static Color astroBrownBackground(bool isDark) =>
      AppColors.astroBrownBackground(isDark);

  static Color get cardColor => AppColors.cardColor;
  static Color get surfaceColor => AppColors.surfaceColor;
  static Color get textColor => AppColors.textColor;
  static Color get textSecondaryColor => AppColors.textSecondaryColor;
  static Color get scaffoldColor => AppColors.scaffoldColor;

  // ------------------------------------------------------------------
  // Typography — delegated to AppTypography
  // ------------------------------------------------------------------
  static const double holyCowTextSize = AppTypography.holyCowTextSize;

  static const double fontSizeXS = AppTypography.fontSizeXS;
  static const double fontSizeS = AppTypography.fontSizeS;
  static const double fontSizeBody = AppTypography.fontSizeBody;
  static const double fontSizeM = AppTypography.fontSizeM;
  static const double fontSizeRegular = AppTypography.fontSizeRegular;
  static const double fontSizeL = AppTypography.fontSizeL;
  static const double fontSizeTitle = AppTypography.fontSizeTitle;
  static const double fontSizeLargeTitle = AppTypography.fontSizeLargeTitle;

  static const double iconSizeS = AppTypography.iconSizeS;
  static const double iconSizeM = AppTypography.iconSizeM;
  static const double iconSizeL = AppTypography.iconSizeL;

  static TextStyle get cardLabelStyle => AppTypography.cardLabelStyle;
  static TextStyle get cardValueStyle => AppTypography.cardValueStyle;
  static TextStyle get listTitleStyle => AppTypography.listTitleStyle;
  static TextStyle get listSubtitleStyle => AppTypography.listSubtitleStyle;
  static TextStyle get usernameStyle => AppTypography.usernameStyle;
  static TextStyle get timestampStyle => AppTypography.timestampStyle;

  // ------------------------------------------------------------------
  // Responsive / Decorations — delegated to AppDecorations
  // ------------------------------------------------------------------
  static double cardTitleSize(BuildContext context) =>
      AppDecorations.cardTitleSize(context);
  static double cardBodySize(BuildContext context) =>
      AppDecorations.cardBodySize(context);
  static double heroTitleSize(BuildContext context) =>
      AppDecorations.heroTitleSize(context);
  static double sectionHeaderSize(BuildContext context) =>
      AppDecorations.sectionHeaderSize(context);
  static double cardPadding(BuildContext context) =>
      AppDecorations.cardPadding(context);
  static double sectionSpacing(BuildContext context) =>
      AppDecorations.sectionSpacing(context);
  static double pagePadding(BuildContext context) =>
      AppDecorations.pagePadding(context);
  static double cardRadius(BuildContext context) =>
      AppDecorations.cardRadius(context);
  static bool isDesktop(BuildContext context) =>
      AppDecorations.isDesktop(context);
  static bool isTablet(BuildContext context) =>
      AppDecorations.isTablet(context);
  static bool isMobile(BuildContext context) =>
      AppDecorations.isMobile(context);
  static T responsiveValue<T>(
    BuildContext context, {
    required T mobile,
    T? tablet,
    T? desktop,
  }) =>
      AppDecorations.responsiveValue(context,
          mobile: mobile, tablet: tablet, desktop: desktop);

  // ------------------------------------------------------------------
  // Theme builders — delegated to ComponentThemes
  // ------------------------------------------------------------------
  static CupertinoThemeData getCupertinoTheme({bool isDarkMode = false}) {
    AppColors.isDarkModeFlag = isDarkMode;
    return ComponentThemes.buildCupertinoTheme(isDarkMode: isDarkMode);
  }

  static ThemeData getMaterialTheme({bool isDarkMode = false}) {
    AppColors.isDarkModeFlag = isDarkMode;
    return ComponentThemes.buildMaterialTheme(isDarkMode: isDarkMode);
  }
}
