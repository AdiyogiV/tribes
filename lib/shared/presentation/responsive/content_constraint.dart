import 'package:flutter/material.dart';
import 'package:aurogram/utils/responsive.dart';

/// Max-width constraints for different content types
class ContentMaxWidth {
  ContentMaxWidth._();

  /// Dashboard layouts with multiple columns (1400px)
  static const double dashboard = 1400.0;

  /// Reading content like insights, descriptions (800px)
  static const double reading = 800.0;

  /// Form content like settings, profile editing (600px)
  static const double form = 600.0;

  /// Compact dialogs and modals (500px)
  static const double compact = 500.0;

  /// Wide layouts for charts and visualizations (1600px)
  static const double wide = 1600.0;
}

/// A widget that constrains content width on larger screens.
///
/// Prevents content from stretching too wide on desktop/ultrawide monitors
/// by centering content with a maximum width.
///
/// ```dart
/// ContentConstraint(
///   maxWidth: ContentMaxWidth.reading,
///   child: InsightCard(),
/// )
/// ```
class ContentConstraint extends StatelessWidget {
  /// The content to constrain
  final Widget child;

  /// Maximum width (default: 1400px for dashboards)
  final double maxWidth;

  /// Whether to center the content when constrained
  final bool center;

  /// Optional padding applied inside the constraint
  final EdgeInsetsGeometry? padding;

  /// Alignment when not filling full width
  final Alignment alignment;

  const ContentConstraint({
    super.key,
    required this.child,
    this.maxWidth = ContentMaxWidth.dashboard,
    this.center = true,
    this.padding,
    this.alignment = Alignment.topCenter,
  });

  /// Creates a constraint optimized for reading content (800px)
  const ContentConstraint.reading({
    super.key,
    required this.child,
    this.padding,
  })  : maxWidth = ContentMaxWidth.reading,
        center = true,
        alignment = Alignment.topCenter;

  /// Creates a constraint optimized for form content (600px)
  const ContentConstraint.form({
    super.key,
    required this.child,
    this.padding,
  })  : maxWidth = ContentMaxWidth.form,
        center = true,
        alignment = Alignment.topCenter;

  /// Creates a constraint optimized for dashboard layouts (1400px)
  const ContentConstraint.dashboard({
    super.key,
    required this.child,
    this.padding,
  })  : maxWidth = ContentMaxWidth.dashboard,
        center = true,
        alignment = Alignment.topCenter;

  /// Creates a constraint optimized for wide visualizations (1600px)
  const ContentConstraint.wide({
    super.key,
    required this.child,
    this.padding,
  })  : maxWidth = ContentMaxWidth.wide,
        center = true,
        alignment = Alignment.topCenter;

  @override
  Widget build(BuildContext context) {
    Widget content = child;

    if (padding != null) {
      content = Padding(padding: padding!, child: content);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // No constraint needed if already smaller than max
        if (constraints.maxWidth <= maxWidth) {
          return content;
        }

        // Apply max width constraint
        final constrained = ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: content,
        );

        return center
            ? Align(alignment: alignment, child: constrained)
            : constrained;
      },
    );
  }
}

/// A scrollable content area with automatic max-width constraints.
///
/// Combines SingleChildScrollView with ContentConstraint for common
/// page content patterns.
///
/// ```dart
/// ConstrainedScrollView(
///   maxWidth: ContentMaxWidth.reading,
///   child: Column(children: [...]),
/// )
/// ```
class ConstrainedScrollView extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;
  final ScrollController? controller;
  final ScrollPhysics? physics;
  final Axis scrollDirection;

  const ConstrainedScrollView({
    super.key,
    required this.child,
    this.maxWidth = ContentMaxWidth.dashboard,
    this.padding,
    this.controller,
    this.physics,
    this.scrollDirection = Axis.vertical,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: controller,
      physics: physics,
      scrollDirection: scrollDirection,
      child: ContentConstraint(
        maxWidth: maxWidth,
        padding: padding,
        child: child,
      ),
    );
  }
}

/// A sliver version of content constraint for use in CustomScrollView.
///
/// ```dart
/// CustomScrollView(
///   slivers: [
///     SliverContentConstraint(
///       maxWidth: ContentMaxWidth.reading,
///       sliver: SliverList(...),
///     ),
///   ],
/// )
/// ```
class SliverContentConstraint extends StatelessWidget {
  final Widget sliver;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;

  const SliverContentConstraint({
    super.key,
    required this.sliver,
    this.maxWidth = ContentMaxWidth.dashboard,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.crossAxisExtent;

        // No constraint needed
        if (availableWidth <= maxWidth) {
          if (padding != null) {
            return SliverPadding(padding: padding!, sliver: sliver);
          }
          return sliver;
        }

        // Calculate horizontal padding to center content
        final horizontalPadding = (availableWidth - maxWidth) / 2;
        final effectivePadding = padding != null
            ? EdgeInsets.only(
                left: horizontalPadding + (padding as EdgeInsets).left,
                right: horizontalPadding + (padding as EdgeInsets).right,
                top: (padding as EdgeInsets).top,
                bottom: (padding as EdgeInsets).bottom,
              )
            : EdgeInsets.symmetric(horizontal: horizontalPadding);

        return SliverPadding(
          padding: effectivePadding,
          sliver: sliver,
        );
      },
    );
  }
}

/// Responsive horizontal padding that increases on larger screens.
///
/// Use for consistent edge padding that adapts to screen size.
class ResponsivePadding extends StatelessWidget {
  final Widget child;
  final double mobilePadding;
  final double tabletPadding;
  final double desktopPadding;
  final bool horizontal;
  final bool vertical;

  const ResponsivePadding({
    super.key,
    required this.child,
    this.mobilePadding = 16.0,
    this.tabletPadding = 24.0,
    this.desktopPadding = 32.0,
    this.horizontal = true,
    this.vertical = false,
  });

  /// Horizontal-only responsive padding
  const ResponsivePadding.horizontal({
    super.key,
    required this.child,
    this.mobilePadding = 16.0,
    this.tabletPadding = 24.0,
    this.desktopPadding = 32.0,
  })  : horizontal = true,
        vertical = false;

  /// Vertical-only responsive padding
  const ResponsivePadding.vertical({
    super.key,
    required this.child,
    this.mobilePadding = 12.0,
    this.tabletPadding = 16.0,
    this.desktopPadding = 24.0,
  })  : horizontal = false,
        vertical = true;

  /// All-sides responsive padding
  const ResponsivePadding.all({
    super.key,
    required this.child,
    this.mobilePadding = 16.0,
    this.tabletPadding = 24.0,
    this.desktopPadding = 32.0,
  })  : horizontal = true,
        vertical = true;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final padding = Responsive.value(
          context: context,
          mobile: mobilePadding,
          tablet: tabletPadding,
          desktop: desktopPadding,
        );

        return Padding(
          padding: EdgeInsets.only(
            left: horizontal ? padding : 0,
            right: horizontal ? padding : 0,
            top: vertical ? padding : 0,
            bottom: vertical ? padding : 0,
          ),
          child: child,
        );
      },
    );
  }
}
