import 'package:flutter/material.dart';

/// Responsive utility class for handling different screen sizes
/// Used for adapting layouts for web (desktop, tablet) vs mobile
class Responsive {
  Responsive._();

  // ============ Breakpoints ============

  /// Mobile breakpoint (phones)
  static const double mobileBreakpoint = 600;

  /// Tablet breakpoint (tablets, small laptops)
  static const double tabletBreakpoint = 1200;

  /// Desktop breakpoint (larger screens)
  static const double desktopBreakpoint = 1800;

  /// Minimum width for "wide" layout (sidebar + master-detail). Used so that
  /// iPad landscape and web desktop both get the same nested layout.
  static const double wideLayoutBreakpoint = 1024;

  // ============ Screen Type Detection ============

  /// Check if current screen is mobile-sized
  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width < mobileBreakpoint;
  }

  /// Check if current screen is tablet-sized
  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= mobileBreakpoint && width < tabletBreakpoint;
  }

  /// Check if current screen is desktop-sized
  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= tabletBreakpoint;
  }

  /// Check if current screen is large desktop
  static bool isLargeDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width >= desktopBreakpoint;
  }

  /// True when the window is wide enough for sidebar + nested master-detail
  /// (e.g. iPad landscape, desktop). Use this instead of kIsWeb && isDesktop
  /// so that iPad gets the same layout as web when horizontal.
  static bool isWideLayout(BuildContext context) {
    return MediaQuery.of(context).size.width >= wideLayoutBreakpoint;
  }

  // ============ Screen Size Getters ============

  /// Get the current screen width
  static double screenWidth(BuildContext context) {
    return MediaQuery.of(context).size.width;
  }

  /// Get the current screen height
  static double screenHeight(BuildContext context) {
    return MediaQuery.of(context).size.height;
  }

  // ============ Responsive Values ============

  /// Get a value based on screen size
  /// Returns [mobile] for phones, [tablet] for tablets, [desktop] for desktops
  static T value<T>({
    required BuildContext context,
    required T mobile,
    T? tablet,
    T? desktop,
  }) {
    if (isDesktop(context)) {
      return desktop ?? tablet ?? mobile;
    }
    if (isTablet(context)) {
      return tablet ?? mobile;
    }
    return mobile;
  }

  /// Get responsive padding based on screen size
  static EdgeInsets padding(BuildContext context) {
    return EdgeInsets.symmetric(
      horizontal: value(
        context: context,
        mobile: 16.0,
        tablet: 32.0,
        desktop: 64.0,
      ),
    );
  }

  /// Get responsive content max width for desktop
  static double contentMaxWidth(BuildContext context) {
    return value(
      context: context,
      mobile: double.infinity,
      tablet: 800.0,
      desktop: 1200.0,
    );
  }

  /// Get the number of columns for grid layouts
  static int gridColumns(BuildContext context) {
    return value(
      context: context,
      mobile: 2,
      tablet: 3,
      desktop: 4,
    );
  }

  // ============ Scrollbar-Friendly Layout Helpers ============

  /// Calculate horizontal padding to center content at a max width.
  /// Use [availableWidth] (from LayoutBuilder) for accurate padding when
  /// inside nested layouts like sidebars.
  ///
  /// Example with LayoutBuilder:
  /// ```dart
  /// LayoutBuilder(
  ///   builder: (context, constraints) {
  ///     final padding = Responsive.horizontalPaddingFor(constraints.maxWidth, 600);
  ///     return CustomScrollView(
  ///       slivers: [
  ///         SliverPadding(
  ///           padding: EdgeInsets.symmetric(horizontal: padding),
  ///           sliver: content,
  ///         ),
  ///       ],
  ///     );
  ///   },
  /// )
  /// ```
  static double horizontalPaddingFor(double availableWidth, double maxWidth) {
    if (availableWidth <= maxWidth) return 0;
    return (availableWidth - maxWidth) / 2;
  }

  /// Convenience method using MediaQuery - use only when not inside nested layouts.
  /// For pages inside ResponsiveShell with sidebar, use [horizontalPaddingFor] with LayoutBuilder.
  static double horizontalPadding(BuildContext context, double maxWidth) {
    final screenWidth = MediaQuery.of(context).size.width;
    return horizontalPaddingFor(screenWidth, maxWidth);
  }

  /// Get EdgeInsets for centering content at a max width.
  static EdgeInsets centeredPaddingFor(double availableWidth, double maxWidth) {
    return EdgeInsets.symmetric(
      horizontal: horizontalPaddingFor(availableWidth, maxWidth),
    );
  }
}

/// A responsive builder widget that rebuilds based on screen size
class ResponsiveBuilder extends StatelessWidget {
  final Widget Function(
          BuildContext context, bool isMobile, bool isTablet, bool isDesktop)
      builder;

  const ResponsiveBuilder({
    super.key,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < Responsive.mobileBreakpoint;
        final isDesktop = constraints.maxWidth >= Responsive.tabletBreakpoint;
        final isTablet = !isMobile && !isDesktop;

        return builder(context, isMobile, isTablet, isDesktop);
      },
    );
  }
}

/// A widget that shows different layouts for mobile, tablet, and desktop
class ResponsiveLayout extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget? desktop;

  const ResponsiveLayout({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      builder: (context, isMobile, isTablet, isDesktop) {
        if (isDesktop && desktop != null) {
          return desktop!;
        }
        if (isTablet && tablet != null) {
          return tablet!;
        }
        return mobile;
      },
    );
  }
}

/// A container that constrains content width on larger screens
class ResponsiveContainer extends StatelessWidget {
  final Widget child;
  final double? maxWidth;
  final EdgeInsetsGeometry? padding;

  const ResponsiveContainer({
    super.key,
    required this.child,
    this.maxWidth,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveMaxWidth = maxWidth ?? Responsive.contentMaxWidth(context);
    final effectivePadding = padding ?? Responsive.padding(context);

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: effectiveMaxWidth),
        child: Padding(
          padding: effectivePadding,
          child: child,
        ),
      ),
    );
  }
}
