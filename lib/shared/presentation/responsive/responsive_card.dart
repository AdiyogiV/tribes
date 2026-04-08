import 'package:flutter/material.dart';
import 'package:aurogram/shared/presentation/responsive/responsive.dart';

/// Size variants for responsive cards
enum ResponsiveCardSize {
  /// Small info cards (Dasha, Core Triad items) - minimal padding
  compact,

  /// Regular cards (Birth Details, Insight cards) - standard padding
  standard,

  /// Takes more space on web (Kundali Chart) - larger padding on desktop
  expanded,

  /// Featured content, larger on all screens - prominent styling
  hero,
}

/// A unified responsive card component that adapts styling based on screen size.
///
/// Replaces inline Material wrappers and provides consistent card styling
/// across the app with proper responsive behavior.
///
/// ```dart
/// ResponsiveCard(
///   size: ResponsiveCardSize.standard,
///   child: MyContent(),
/// )
/// ```
class ResponsiveCard extends StatelessWidget {
  /// The card content
  final Widget child;

  /// Size variant affecting padding and styling
  final ResponsiveCardSize size;

  /// Whether to show elevated shadow (default: true)
  final bool elevated;

  /// Optional tap callback
  final VoidCallback? onTap;

  /// Optional custom border radius (overrides responsive default)
  final BorderRadius? borderRadius;

  /// Optional accent color for subtle border or tint
  final Color? accentColor;

  const ResponsiveCard({
    super.key,
    required this.child,
    this.size = ResponsiveCardSize.standard,
    this.elevated = true,
    this.onTap,
    this.borderRadius,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= Responsive.tabletBreakpoint ||
            MediaQuery.of(context).size.width >= Responsive.tabletBreakpoint;

        // Responsive values based on screen size
        final padding = _getPadding(isDesktop);
        final radius = borderRadius ?? _getBorderRadius(isDesktop);
        final elevation = elevated ? _getElevation(isDesktop) : 0.0;

        // Card color
        final Color cardColor =
            isDark ? Theme.of(context).colorScheme.surface : Colors.white;

        // Shadow color
        final shadowColor = isDark
            ? Colors.black.withValues(alpha: 0.4)
            : Colors.black.withValues(alpha: 0.15);

        Widget card = Material(
          color: cardColor,
          elevation: elevation,
          shadowColor: shadowColor,
          borderRadius: radius,
          child: Container(
            padding: padding,
            decoration: accentColor != null
                ? BoxDecoration(
                    borderRadius: radius,
                    border: Border.all(
                      color: accentColor!.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  )
                : null,
            child: child,
          ),
        );

        if (onTap != null) {
          card = Material(
            color: cardColor,
            elevation: elevation,
            shadowColor: shadowColor,
            borderRadius: radius,
            child: InkWell(
              onTap: onTap,
              borderRadius: radius,
              child: Container(
                padding: padding,
                decoration: accentColor != null
                    ? BoxDecoration(
                        borderRadius: radius,
                        border: Border.all(
                          color: accentColor!.withValues(alpha: 0.2),
                          width: 1,
                        ),
                      )
                    : null,
                child: child,
              ),
            ),
          );
        }

        return card;
      },
    );
  }

  EdgeInsets _getPadding(bool isDesktop) {
    switch (size) {
      case ResponsiveCardSize.compact:
        return EdgeInsets.all(isDesktop ? 14.0 : 12.0);
      case ResponsiveCardSize.standard:
        return EdgeInsets.all(isDesktop ? 24.0 : 16.0);
      case ResponsiveCardSize.expanded:
        return EdgeInsets.all(isDesktop ? 32.0 : 16.0);
      case ResponsiveCardSize.hero:
        return EdgeInsets.all(isDesktop ? 32.0 : 20.0);
    }
  }

  BorderRadius _getBorderRadius(bool isDesktop) {
    switch (size) {
      case ResponsiveCardSize.compact:
        return BorderRadius.circular(isDesktop ? 18.0 : 16.0);
      case ResponsiveCardSize.standard:
        return BorderRadius.circular(isDesktop ? 24.0 : 20.0);
      case ResponsiveCardSize.expanded:
        return BorderRadius.circular(isDesktop ? 28.0 : 20.0);
      case ResponsiveCardSize.hero:
        return BorderRadius.circular(isDesktop ? 28.0 : 24.0);
    }
  }

  double _getElevation(bool isDesktop) {
    switch (size) {
      case ResponsiveCardSize.compact:
        return isDesktop ? 2.0 : 1.0;
      case ResponsiveCardSize.standard:
        return isDesktop ? 4.0 : 2.0;
      case ResponsiveCardSize.expanded:
        return isDesktop ? 6.0 : 2.0;
      case ResponsiveCardSize.hero:
        return isDesktop ? 8.0 : 4.0;
    }
  }
}

/// A simple card header with title and optional trailing widget
class ResponsiveCardHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final Color? titleColor;

  const ResponsiveCardHeader({
    super.key,
    required this.title,
    this.trailing,
    this.titleColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDesktop = Responsive.isDesktop(context);

    final color = titleColor ??
        (isDark ? const Color(0xFFE8B86D) : const Color(0xFF5A3D34));

    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: isDesktop ? 16.0 : 14.0,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}
