import 'package:flutter/material.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';

void showCustomSnackBar(
  BuildContext context, {
  required String message,
  SnackBarAction? action,
  Color? backgroundColor,
  Duration duration = const Duration(seconds: 4),
  SnackBarBehavior behavior = SnackBarBehavior.fixed,
  EdgeInsets? margin,
}) {
  // Always use fixed behavior to prevent off-screen issues
  const SnackBarBehavior effectiveBehavior = SnackBarBehavior.fixed;

  // Only apply margin if explicitly requested
  final EdgeInsets? effectiveMargin = margin;

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        message,
        style: TextStyle(
          fontSize: 16,
          color: AppTheme.textDarkColor,
        ),
      ),
      backgroundColor: backgroundColor ?? AppTheme.primaryColor,
      duration: duration,
      behavior: effectiveBehavior,
      margin: effectiveMargin,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      ),
      action: action,
    ),
  );
}
