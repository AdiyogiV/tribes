import 'package:flutter/material.dart';
import 'package:aurogram/shared/presentation/responsive/responsive.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';

/// A responsive master-detail layout that shows:
/// - On desktop: Side-by-side panels (master list + detail view)
/// - On mobile: Single panel with navigation between views
///
/// Inspired by WhatsApp Web, Discord, and Slack layouts.
class MasterDetailLayout extends StatelessWidget {
  /// The master panel content (list/navigation)
  final Widget master;

  /// The detail panel content (selected item view)
  final Widget? detail;

  /// Empty state widget when no detail is selected
  final Widget? emptyState;

  /// Width of the master panel on desktop (default 320)
  final double masterWidth;

  /// Minimum width for the detail panel
  final double minDetailWidth;

  /// Whether to show a divider between panels
  final bool showDivider;

  /// Whether the master panel has a background
  final bool masterHasBackground;

  /// Optional header for the master panel
  final Widget? masterHeader;

  /// Optional header for the detail panel
  final Widget? detailHeader;

  const MasterDetailLayout({
    super.key,
    required this.master,
    this.detail,
    this.emptyState,
    this.masterWidth = 320,
    this.minDetailWidth = 400,
    this.showDivider = true,
    this.masterHasBackground = true,
    this.masterHeader,
    this.detailHeader,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Check if we have enough space for side-by-side layout
        final bool showSideBySide = constraints.maxWidth >= (masterWidth + minDetailWidth);

        if (showSideBySide) {
          return _buildDesktopLayout(context, constraints);
        } else {
          // On smaller screens, just show the master view
          // Detail navigation is handled by the parent via route push
          return master;
        }
      },
    );
  }

  Widget _buildDesktopLayout(BuildContext context, BoxConstraints constraints) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dividerColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.06);

    return Row(
      children: [
        // Master panel (fixed width)
        SizedBox(
          width: masterWidth,
          child: Column(
            children: [
              if (masterHeader != null) masterHeader!,
              Expanded(
                child: Container(
                  decoration: masterHasBackground
                      ? BoxDecoration(
                          color: isDark ? AppTheme.cardDarkColor : Colors.white,
                          border: showDivider
                              ? Border(
                                  right: BorderSide(color: dividerColor, width: 1),
                                )
                              : null,
                        )
                      : null,
                  child: master,
                ),
              ),
            ],
          ),
        ),

        // Detail panel (fills remaining space)
        Expanded(
          child: Column(
            children: [
              if (detailHeader != null) detailHeader!,
              Expanded(
                child: detail ?? emptyState ?? _buildDefaultEmptyState(context),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDefaultEmptyState(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline_rounded,
              size: 80,
              color: AppTheme.primaryColor.withValues(alpha: 0.3),
            ),
            const SizedBox(height: AppDimensions.spacingXxl),
            Text(
              'Select a conversation',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.5)
                    : Colors.black.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: AppDimensions.spacingSm),
            Text(
              'Choose from your existing conversations\nor start a new one',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.4)
                    : Colors.black.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A wrapper widget that handles the master-detail navigation logic
/// Automatically switches between inline detail and pushed routes based on screen size
class MasterDetailNavigator extends StatefulWidget {
  /// Builder for the master panel
  final Widget Function(BuildContext context, void Function(String? id) onSelect) masterBuilder;

  /// Builder for the detail panel given the selected ID
  final Widget Function(BuildContext context, String id) detailBuilder;

  /// Builder for the full-page detail route (used on mobile)
  final Widget Function(BuildContext context, String id) detailPageBuilder;

  /// Empty state widget when no detail is selected
  final Widget? emptyState;

  /// Width of the master panel
  final double masterWidth;

  /// Initial selected ID
  final String? initialSelectedId;

  const MasterDetailNavigator({
    super.key,
    required this.masterBuilder,
    required this.detailBuilder,
    required this.detailPageBuilder,
    this.emptyState,
    this.masterWidth = 320,
    this.initialSelectedId,
  });

  @override
  State<MasterDetailNavigator> createState() => _MasterDetailNavigatorState();
}

class _MasterDetailNavigatorState extends State<MasterDetailNavigator> {
  String? _selectedId;

  @override
  void initState() {
    super.initState();
    _selectedId = widget.initialSelectedId;
  }

  void _onSelect(String? id) {
    final isDesktop = Responsive.isDesktop(context);

    if (isDesktop) {
      // On desktop, update state to show detail inline
      setState(() => _selectedId = id);
    } else if (id != null) {
      // On mobile, push the detail page as a route
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => widget.detailPageBuilder(context, id),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MasterDetailLayout(
      masterWidth: widget.masterWidth,
      master: widget.masterBuilder(context, _onSelect),
      detail: _selectedId != null
          ? widget.detailBuilder(context, _selectedId!)
          : null,
      emptyState: widget.emptyState,
    );
  }
}

/// A panel container with optional header and consistent styling
class DetailPanel extends StatelessWidget {
  final Widget child;
  final Widget? header;
  final Color? backgroundColor;
  final EdgeInsetsGeometry? padding;

  const DetailPanel({
    super.key,
    required this.child,
    this.header,
    this.backgroundColor,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: backgroundColor ?? Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        children: [
          if (header != null) header!,
          Expanded(
            child: padding != null
                ? Padding(padding: padding!, child: child)
                : child,
          ),
        ],
      ),
    );
  }
}

/// A list panel with search functionality and consistent styling
class ListPanel extends StatelessWidget {
  final Widget child;
  final Widget? header;
  final Widget? searchBar;
  final Color? backgroundColor;

  const ListPanel({
    super.key,
    required this.child,
    this.header,
    this.searchBar,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      color: backgroundColor ?? (isDark ? AppTheme.cardDarkColor : Colors.white),
      child: Column(
        children: [
          if (header != null) header!,
          if (searchBar != null)
            Padding(
              padding: const EdgeInsets.all(AppDimensions.paddingMd),
              child: searchBar,
            ),
          Expanded(child: child),
        ],
      ),
    );
  }
}
