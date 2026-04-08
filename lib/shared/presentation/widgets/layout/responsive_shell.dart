import 'package:flutter/material.dart';
import 'package:aurogram/shared/presentation/responsive/responsive.dart';
import 'package:aurogram/shared/presentation/widgets/layout/sidebar_navigation.dart';

/// A responsive shell that switches between mobile and wide layouts by width.
/// - Narrow (e.g. phone, or iPad portrait): Bottom navigation.
/// - Wide (e.g. desktop, or iPad landscape >= 1024px): Sidebar navigation.
class ResponsiveShell extends StatefulWidget {
  /// The currently selected tab index
  final int selectedIndex;

  /// Whether the user is authenticated
  final bool isAuthenticated;

  /// The current user's ID (for avatar display)
  final String? userId;

  /// Callback when a tab is selected
  final ValueChanged<int> onTabChanged;

  /// The main content to display (usually IndexedStack of tabs)
  final Widget child;

  /// Builder for mobile layout (wraps child with bottom nav)
  final Widget Function(Widget child) mobileBuilder;

  /// Tab-specific action builder that receives isCollapsed to render appropriately
  final Widget Function(bool isCollapsed)? tabActionBuilder;

  const ResponsiveShell({
    super.key,
    required this.selectedIndex,
    required this.isAuthenticated,
    required this.onTabChanged,
    required this.child,
    required this.mobileBuilder,
    this.userId,
    this.tabActionBuilder,
  });

  @override
  State<ResponsiveShell> createState() => _ResponsiveShellState();
}

class _ResponsiveShellState extends State<ResponsiveShell> {
  bool _isSidebarCollapsed = false;

  @override
  Widget build(BuildContext context) {
    // Use width-based layout on all platforms (web, iOS, Android). When the
    // window is wide enough (e.g. iPad horizontal, desktop), show the wide
    // layout with sidebar; otherwise show mobile layout with bottom nav.
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool showSidebar =
            constraints.maxWidth >= Responsive.wideLayoutBreakpoint;
        final bool collapseForMedium = constraints.maxWidth < 1400 &&
            constraints.maxWidth >= Responsive.wideLayoutBreakpoint;

        if (showSidebar) {
          return _buildDesktopLayout(
            context,
            forceCollapsed: collapseForMedium,
          );
        } else {
          return widget.mobileBuilder(widget.child);
        }
      },
    );
  }

  Widget _buildDesktopLayout(BuildContext context,
      {bool forceCollapsed = false}) {
    // When forceCollapsed due to medium screen, start collapsed but allow user to toggle
    // - Medium screens (forceCollapsed): default collapsed, user toggle expands it
    // - Large screens (!forceCollapsed): default expanded, user toggle collapses it
    final bool isCollapsed = forceCollapsed
        ? !_isSidebarCollapsed // Inverted: toggle=true means expanded
        : _isSidebarCollapsed; // Normal: toggle=true means collapsed

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Row(
        children: [
          // Sidebar navigation
          SidebarNavigation(
            selectedIndex: widget.selectedIndex,
            isAuthenticated: widget.isAuthenticated,
            userId: widget.userId,
            onTap: widget.onTabChanged,
            isCollapsed: isCollapsed,
            // Always allow toggle - user should be able to expand/collapse regardless of screen size
            onToggleCollapse: () =>
                setState(() => _isSidebarCollapsed = !_isSidebarCollapsed),
            tabActionBuilder: widget.tabActionBuilder,
          ),

          // Main content area
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
              ),
              child: widget.child,
            ),
          ),
        ],
      ),
    );
  }
}

/// Extension widget for applying responsive content constraints
/// Wraps content in a centered container with max-width on desktop
class ResponsiveContent extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;

  const ResponsiveContent({
    super.key,
    required this.child,
    this.maxWidth = 700,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isDesktop =
            constraints.maxWidth >= Responsive.tabletBreakpoint;

        if (!isDesktop) {
          return padding != null
              ? Padding(padding: padding!, child: child)
              : child;
        }

        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: padding != null
                ? Padding(padding: padding!, child: child)
                : child,
          ),
        );
      },
    );
  }
}

/// A wrapper that provides different layouts for mobile/tablet/desktop
class AdaptiveLayout extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget? desktop;

  const AdaptiveLayout({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= Responsive.tabletBreakpoint) {
          return desktop ?? tablet ?? mobile;
        }
        if (constraints.maxWidth >= Responsive.mobileBreakpoint) {
          return tablet ?? mobile;
        }
        return mobile;
      },
    );
  }
}
