import 'package:flutter/material.dart';

/// Responsive layout helpers, breakpoint utilities, and spacing functions.
class AppDecorations {
  AppDecorations._();

  // ============================================
  // RESPONSIVE TYPOGRAPHY & SPACING
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
}
