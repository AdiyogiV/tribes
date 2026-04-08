import 'package:flutter/material.dart';
import 'package:aurogram/utils/responsive.dart';

/// Layout modes for DashboardShell
enum DashboardLayoutMode {
  /// Hero content on left/center, sidebar panel on right
  /// Desktop: Side by side | Mobile: Vertical stack
  heroWithSidebar,

  /// Multi-column grid layout
  /// Desktop: 2-3 columns | Mobile: Single column
  multiColumn,

  /// Two equal panels side by side, content below
  /// Desktop: Split top, full-width bottom | Mobile: Vertical stack
  splitView,
}

/// A responsive dashboard layout shell that adapts to screen sizes.
///
/// Provides three layout modes:
/// - [DashboardLayoutMode.heroWithSidebar]: Hero content + sidebar (Cosmic Dashboard)
/// - [DashboardLayoutMode.multiColumn]: Grid of cards (Daily Insights)
/// - [DashboardLayoutMode.splitView]: Two panels + bottom content (Ayurveda)
///
/// ```dart
/// DashboardShell(
///   mode: DashboardLayoutMode.heroWithSidebar,
///   heroContent: KundaliChart(),
///   sidebarContent: [InfoCard1(), InfoCard2()],
/// )
/// ```
class DashboardShell extends StatelessWidget {
  /// Layout mode determining arrangement
  final DashboardLayoutMode mode;

  /// Main/hero content (used in heroWithSidebar and multiColumn modes)
  final Widget? heroContent;

  /// Sidebar widgets (used in heroWithSidebar mode)
  final List<Widget> sidebarContent;

  /// Left panel content (used in splitView mode)
  final Widget? leftPanel;

  /// Right panel content (used in splitView mode)
  final Widget? rightPanel;

  /// Bottom content spanning full width (used in splitView mode)
  final Widget? bottomContent;

  /// Grid children (used in multiColumn mode)
  final List<Widget> gridChildren;

  /// Spacing between elements
  final double spacing;

  /// Sidebar width on desktop (heroWithSidebar mode)
  final double sidebarWidth;

  /// Breakpoint for switching to mobile layout
  final double mobileBreakpoint;

  /// Optional header widget shown above all content
  final Widget? header;

  /// Optional padding around the entire shell
  final EdgeInsetsGeometry? padding;

  /// Maximum content width (centers on ultra-wide screens)
  final double? maxContentWidth;

  /// Number of columns for multiColumn mode on desktop
  final int desktopColumns;

  const DashboardShell({
    super.key,
    required this.mode,
    this.heroContent,
    this.sidebarContent = const [],
    this.leftPanel,
    this.rightPanel,
    this.bottomContent,
    this.gridChildren = const [],
    this.spacing = 16.0,
    this.sidebarWidth = 380.0,
    this.mobileBreakpoint = 900.0,
    this.header,
    this.padding,
    this.maxContentWidth = 1400.0,
    this.desktopColumns = 2,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= mobileBreakpoint;
        final effectiveSpacing = isDesktop ? spacing * 1.5 : spacing;
        final effectivePadding = padding ??
            EdgeInsets.all(isDesktop ? 24.0 : 16.0);

        Widget content;
        switch (mode) {
          case DashboardLayoutMode.heroWithSidebar:
            content = _buildHeroWithSidebar(
              context,
              constraints,
              isDesktop,
              effectiveSpacing,
            );
          case DashboardLayoutMode.multiColumn:
            content = _buildMultiColumn(
              context,
              constraints,
              isDesktop,
              effectiveSpacing,
            );
          case DashboardLayoutMode.splitView:
            content = _buildSplitView(
              context,
              constraints,
              isDesktop,
              effectiveSpacing,
            );
        }

        // Apply max width constraint
        if (maxContentWidth != null && constraints.maxWidth > maxContentWidth!) {
          content = Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxContentWidth!),
              child: content,
            ),
          );
        }

        return Padding(
          padding: effectivePadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (header != null) ...[
                header!,
                SizedBox(height: effectiveSpacing),
              ],
              Expanded(child: content),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeroWithSidebar(
    BuildContext context,
    BoxConstraints constraints,
    bool isDesktop,
    double spacing,
  ) {
    if (!isDesktop || sidebarContent.isEmpty) {
      // Mobile: Vertical stack
      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (heroContent != null) heroContent!,
            if (heroContent != null && sidebarContent.isNotEmpty)
              SizedBox(height: spacing),
            ...sidebarContent.expand((widget) => [
              widget,
              SizedBox(height: spacing),
            ]).take(sidebarContent.length * 2 - 1),
          ],
        ),
      );
    }

    // Desktop: Side by side
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Hero content takes remaining space
        Expanded(
          child: heroContent ?? const SizedBox.shrink(),
        ),
        SizedBox(width: spacing),
        // Fixed-width sidebar
        SizedBox(
          width: sidebarWidth,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ...sidebarContent.expand((widget) => [
                  widget,
                  SizedBox(height: spacing),
                ]).take(sidebarContent.length * 2 - 1),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMultiColumn(
    BuildContext context,
    BoxConstraints constraints,
    bool isDesktop,
    double spacing,
  ) {
    if (gridChildren.isEmpty) return const SizedBox.shrink();

    final columns = isDesktop ? desktopColumns : 1;

    if (columns == 1) {
      // Single column
      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ...gridChildren.expand((widget) => [
              widget,
              SizedBox(height: spacing),
            ]).take(gridChildren.length * 2 - 1),
          ],
        ),
      );
    }

    // Multi-column grid
    final itemWidth =
        (constraints.maxWidth - (spacing * (columns - 1)) - 48) / columns;

    return SingleChildScrollView(
      child: Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: gridChildren.map((child) {
          return SizedBox(
            width: itemWidth,
            child: child,
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSplitView(
    BuildContext context,
    BoxConstraints constraints,
    bool isDesktop,
    double spacing,
  ) {
    if (!isDesktop) {
      // Mobile: Vertical stack
      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (leftPanel != null) leftPanel!,
            if (leftPanel != null && rightPanel != null)
              SizedBox(height: spacing),
            if (rightPanel != null) rightPanel!,
            if ((leftPanel != null || rightPanel != null) &&
                bottomContent != null)
              SizedBox(height: spacing),
            if (bottomContent != null) bottomContent!,
          ],
        ),
      );
    }

    // Desktop: Split top, full bottom
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top row: Two equal panels
          if (leftPanel != null || rightPanel != null)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (leftPanel != null)
                  Expanded(child: leftPanel!)
                else
                  const Expanded(child: SizedBox.shrink()),
                SizedBox(width: spacing),
                if (rightPanel != null)
                  Expanded(child: rightPanel!)
                else
                  const Expanded(child: SizedBox.shrink()),
              ],
            ),
          // Bottom content
          if (bottomContent != null) ...[
            SizedBox(height: spacing),
            bottomContent!,
          ],
        ],
      ),
    );
  }
}

/// A scrollable dashboard content area with responsive padding.
///
/// Use inside DashboardShell for scrollable content areas, or standalone
/// for simpler layouts.
class DashboardContent extends StatelessWidget {
  final Widget child;
  final double? maxWidth;
  final EdgeInsetsGeometry? padding;

  const DashboardContent({
    super.key,
    required this.child,
    this.maxWidth = 1400.0,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= Responsive.tabletBreakpoint;
        final effectivePadding = padding ??
            EdgeInsets.symmetric(
              horizontal: isDesktop ? 32.0 : 16.0,
              vertical: isDesktop ? 24.0 : 16.0,
            );

        Widget content = Padding(
          padding: effectivePadding,
          child: child,
        );

        if (maxWidth != null && constraints.maxWidth > maxWidth!) {
          content = Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth!),
              child: content,
            ),
          );
        }

        return content;
      },
    );
  }
}

/// A responsive section divider with optional title.
class DashboardSection extends StatelessWidget {
  final String? title;
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const DashboardSection({
    super.key,
    this.title,
    required this.child,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final isDesktop = Responsive.isDesktop(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor =
        isDark ? const Color(0xFFE8B86D) : const Color(0xFF5A3D34);

    return Padding(
      padding: padding ?? EdgeInsets.symmetric(vertical: isDesktop ? 16.0 : 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(
              title!,
              style: TextStyle(
                fontSize: isDesktop ? 18.0 : 16.0,
                fontWeight: FontWeight.w600,
                color: titleColor,
              ),
            ),
            SizedBox(height: isDesktop ? 16.0 : 12.0),
          ],
          child,
        ],
      ),
    );
  }
}
