import 'package:flutter/material.dart';
import 'package:aurogram/shared/presentation/responsive/responsive.dart';

/// A responsive grid layout for cards that adapts column count based on screen size.
///
/// ```dart
/// CardGrid(
///   mobileColumns: 1,
///   tabletColumns: 2,
///   desktopColumns: 3,
///   spacing: 12,
///   children: [Card1(), Card2(), Card3()],
/// )
/// ```
class CardGrid extends StatelessWidget {
  /// The cards/widgets to display in the grid
  final List<Widget> children;

  /// Number of columns on mobile (< 600px). Default: 1
  final int mobileColumns;

  /// Number of columns on tablet (600-1200px). Default: 2
  final int tabletColumns;

  /// Number of columns on desktop (>= 1200px). Default: 3
  final int desktopColumns;

  /// Spacing between cards. Scales automatically on desktop.
  final double spacing;

  /// Vertical spacing between rows (defaults to [spacing] if not provided)
  final double? runSpacing;

  /// Cross axis alignment for items in a row
  final CrossAxisAlignment crossAxisAlignment;

  /// Whether children should expand to fill available width
  final bool expandChildren;

  const CardGrid({
    super.key,
    required this.children,
    this.mobileColumns = 1,
    this.tabletColumns = 2,
    this.desktopColumns = 3,
    this.spacing = 12.0,
    this.runSpacing,
    this.crossAxisAlignment = CrossAxisAlignment.start,
    this.expandChildren = true,
  });

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = _getColumns(constraints.maxWidth);
        final effectiveSpacing = _getEffectiveSpacing(constraints.maxWidth);
        final effectiveRunSpacing = runSpacing ?? effectiveSpacing;

        // For single column, just stack vertically
        if (columns == 1) {
          return Column(
            crossAxisAlignment: crossAxisAlignment,
            children: [
              for (int i = 0; i < children.length; i++) ...[
                if (i > 0) SizedBox(height: effectiveRunSpacing),
                expandChildren
                    ? SizedBox(width: double.infinity, child: children[i])
                    : children[i],
              ],
            ],
          );
        }

        // For multiple columns, use Wrap for flexible layout
        return Wrap(
          spacing: effectiveSpacing,
          runSpacing: effectiveRunSpacing,
          crossAxisAlignment: _wrapCrossAlignment,
          children: children.map((child) {
            // Calculate width for each child
            final itemWidth =
                (constraints.maxWidth - (effectiveSpacing * (columns - 1))) /
                    columns;

            return SizedBox(
              width: itemWidth,
              child: child,
            );
          }).toList(),
        );
      },
    );
  }

  int _getColumns(double width) {
    if (width >= Responsive.tabletBreakpoint) return desktopColumns;
    if (width >= Responsive.mobileBreakpoint) return tabletColumns;
    return mobileColumns;
  }

  double _getEffectiveSpacing(double width) {
    // Scale spacing on larger screens
    if (width >= Responsive.tabletBreakpoint) return spacing * 1.5;
    if (width >= Responsive.mobileBreakpoint) return spacing * 1.25;
    return spacing;
  }

  WrapCrossAlignment get _wrapCrossAlignment {
    switch (crossAxisAlignment) {
      case CrossAxisAlignment.start:
        return WrapCrossAlignment.start;
      case CrossAxisAlignment.end:
        return WrapCrossAlignment.end;
      case CrossAxisAlignment.center:
        return WrapCrossAlignment.center;
      default:
        return WrapCrossAlignment.start;
    }
  }
}

/// A responsive row that switches between horizontal and vertical layout
/// based on available width.
///
/// Useful for side-by-side cards that should stack on mobile.
///
/// ```dart
/// ResponsiveRow(
///   breakpoint: 600,
///   spacing: 12,
///   children: [Card1(), Card2()],
/// )
/// ```
class ResponsiveRow extends StatelessWidget {
  /// Widgets to display
  final List<Widget> children;

  /// Width below which to switch to vertical layout
  final double breakpoint;

  /// Spacing between children
  final double spacing;

  /// Flex values for each child (must match children length)
  /// If null, children are equally sized
  final List<int>? flexValues;

  /// Cross axis alignment when horizontal
  final CrossAxisAlignment crossAxisAlignment;

  /// Main axis alignment when horizontal
  final MainAxisAlignment mainAxisAlignment;

  const ResponsiveRow({
    super.key,
    required this.children,
    this.breakpoint = 600,
    this.spacing = 12,
    this.flexValues,
    this.crossAxisAlignment = CrossAxisAlignment.start,
    this.mainAxisAlignment = MainAxisAlignment.start,
  }) : assert(flexValues == null || flexValues.length == children.length);

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isHorizontal = constraints.maxWidth >= breakpoint;
        final effectiveSpacing = isHorizontal &&
                constraints.maxWidth >= Responsive.tabletBreakpoint
            ? spacing * 1.5
            : spacing;

        if (!isHorizontal) {
          // Vertical stack
          return Column(
            crossAxisAlignment: crossAxisAlignment,
            children: [
              for (int i = 0; i < children.length; i++) ...[
                if (i > 0) SizedBox(height: effectiveSpacing),
                children[i],
              ],
            ],
          );
        }

        // Horizontal row with flex
        return Row(
          crossAxisAlignment: crossAxisAlignment,
          mainAxisAlignment: mainAxisAlignment,
          children: [
            for (int i = 0; i < children.length; i++) ...[
              if (i > 0) SizedBox(width: effectiveSpacing),
              if (flexValues != null)
                Expanded(flex: flexValues![i], child: children[i])
              else
                Expanded(child: children[i]),
            ],
          ],
        );
      },
    );
  }
}

/// A masonry-style grid that supports varying card heights.
///
/// Cards are arranged in columns with items stacking based on
/// available vertical space in each column.
class MasonryGrid extends StatelessWidget {
  final List<Widget> children;
  final int mobileColumns;
  final int tabletColumns;
  final int desktopColumns;
  final double spacing;
  final double runSpacing;

  const MasonryGrid({
    super.key,
    required this.children,
    this.mobileColumns = 1,
    this.tabletColumns = 2,
    this.desktopColumns = 3,
    this.spacing = 12.0,
    this.runSpacing = 12.0,
  });

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = _getColumns(constraints.maxWidth);
        final effectiveSpacing = _getEffectiveSpacing(constraints.maxWidth);

        // Single column - simple vertical list
        if (columns == 1) {
          return Column(
            children: [
              for (int i = 0; i < children.length; i++) ...[
                if (i > 0) SizedBox(height: runSpacing),
                children[i],
              ],
            ],
          );
        }

        // Multi-column masonry layout
        final columnWidth =
            (constraints.maxWidth - (effectiveSpacing * (columns - 1))) /
                columns;

        // Distribute children across columns
        final columnChildren = List.generate(columns, (_) => <Widget>[]);
        for (int i = 0; i < children.length; i++) {
          columnChildren[i % columns].add(children[i]);
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (int col = 0; col < columns; col++) ...[
              if (col > 0) SizedBox(width: effectiveSpacing),
              SizedBox(
                width: columnWidth,
                child: Column(
                  children: [
                    for (int i = 0; i < columnChildren[col].length; i++) ...[
                      if (i > 0) SizedBox(height: runSpacing),
                      columnChildren[col][i],
                    ],
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  int _getColumns(double width) {
    if (width >= Responsive.tabletBreakpoint) return desktopColumns;
    if (width >= Responsive.mobileBreakpoint) return tabletColumns;
    return mobileColumns;
  }

  double _getEffectiveSpacing(double width) {
    if (width >= Responsive.tabletBreakpoint) return spacing * 1.5;
    if (width >= Responsive.mobileBreakpoint) return spacing * 1.25;
    return spacing;
  }
}
