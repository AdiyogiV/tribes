import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:aurogram/core/theme/app_colors.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';
import 'package:aurogram/core/theme/app_typography.dart';

/// Material and Cupertino component theme overrides.
class ComponentThemes {
  ComponentThemes._();

  /// Build the full CupertinoThemeData.
  static CupertinoThemeData buildCupertinoTheme({required bool isDarkMode}) {
    return CupertinoThemeData(
      brightness: isDarkMode ? Brightness.dark : Brightness.light,
      primaryColor: AppColors.primaryColor,
      primaryContrastingColor: AppColors.accentColor,
      scaffoldBackgroundColor:
          isDarkMode ? AppColors.scaffoldDarkColor : AppColors.scaffoldLightColor,
      barBackgroundColor: isDarkMode
          ? const Color(0xFF0E1524) // Deep blue night bar
          : const Color(0xFFF0F8FC), // Light sky blue bar
      textTheme: CupertinoTextThemeData(
        primaryColor:
            isDarkMode ? AppColors.textDarkColor : AppColors.textLightColor,
        textStyle: TextStyle(
          color:
              isDarkMode ? AppColors.textDarkColor : AppColors.textLightColor,
          fontSize: 16.0,
          fontWeight: FontWeight.normal,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  /// Build the full Material ThemeData.
  static ThemeData buildMaterialTheme({required bool isDarkMode}) {
    final primaryClr =
        isDarkMode ? AppColors.primaryBrandColorDark : AppColors.primaryBrandColor;
    final bgColor =
        isDarkMode ? AppColors.scaffoldDarkColor : AppColors.scaffoldLightColor;
    final surfaceClr =
        isDarkMode ? AppColors.surfaceDarkColor : AppColors.surfaceLightColor;
    final textClr =
        isDarkMode ? AppColors.textDarkColor : AppColors.textLightColor;
    final textSecondaryClr = isDarkMode
        ? AppColors.textSecondaryDarkColor
        : AppColors.textSecondaryLightColor;

    return ThemeData(
      useMaterial3: true,
      brightness: isDarkMode ? Brightness.dark : Brightness.light,
      primaryColor: primaryClr,
      primaryColorLight: AppColors.primaryLightColor,
      primaryColorDark: AppColors.primaryDarkColor,
      scaffoldBackgroundColor: bgColor,

      // Color Scheme
      colorScheme: ColorScheme(
        primary: primaryClr,
        primaryContainer:
            isDarkMode ? const Color(0xFF1A2540) : const Color(0xFFD7CCC8),
        secondary: AppColors.accentColor,
        secondaryContainer:
            isDarkMode ? const Color(0xFF283520) : const Color(0xFFFFF3E0),
        tertiary: AppColors.grassGreen,
        tertiaryContainer:
            isDarkMode ? const Color(0xFF142515) : const Color(0xFFDCEDC8),
        surface: surfaceClr,
        error: AppColors.errorColor,
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
        color: isDarkMode ? AppColors.cardDarkColor : AppColors.cardLightColor,
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
        backgroundColor: AppColors.accentColor,
        foregroundColor: const Color(0xFF080C14),
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        ),
      ),

      // App Bar Theme
      appBarTheme: AppBarTheme(
        backgroundColor:
            isDarkMode ? AppColors.scaffoldDarkColor : Colors.white,
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
          color: isDarkMode ? AppColors.textDarkColor : primaryClr,
          size: 24,
        ),
        actionsIconTheme: IconThemeData(
          color: isDarkMode ? AppColors.textDarkColor : primaryClr,
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
      textTheme: AppTypography.buildTextTheme(textClr, textSecondaryClr),

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
            color: AppColors.errorColor,
            width: 1.5,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          borderSide: const BorderSide(
            color: AppColors.errorColor,
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
        padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.paddingMd,
            vertical: AppDimensions.paddingSm),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
        ),
      ),

      // Dialog Theme
      dialogTheme: DialogThemeData(
        backgroundColor:
            isDarkMode ? AppColors.cardDarkColor : AppColors.cardLightColor,
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
        backgroundColor:
            isDarkMode ? AppColors.cardDarkColor : AppColors.cardLightColor,
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
        actionTextColor: AppColors.accentColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        ),
      ),

      // List Tile Theme
      listTileTheme: ListTileThemeData(
        iconColor: primaryClr,
        textColor: textClr,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
        labelColor: isDarkMode ? Colors.white : AppColors.scaffoldDarkColor,
        unselectedLabelColor: textSecondaryClr,
        indicatorColor:
            isDarkMode ? Colors.white : AppColors.scaffoldDarkColor,
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
        color: isDarkMode ? AppColors.textDarkColor : AppColors.textLightColor,
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
