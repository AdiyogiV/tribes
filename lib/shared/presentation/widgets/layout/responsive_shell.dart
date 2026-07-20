import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:aurogram/shared/presentation/responsive/responsive.dart';
import 'package:aurogram/shared/providers/theme_provider.dart';
import 'package:aurogram/shared/presentation/web/web_style.dart';
import 'package:aurogram/shared/presentation/web/web_nav_rail.dart';
import 'package:aurogram/shared/presentation/web/ambient_background.dart';

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
  @override
  Widget build(BuildContext context) {
    // Use width-based layout on all platforms (web, iOS, Android). When the
    // window is wide enough (e.g. iPad horizontal, desktop), show the wide
    // layout with the floating glass rail; otherwise show mobile layout with
    // bottom nav. Mobile path is untouched by the web redesign.
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool showSidebar =
            constraints.maxWidth >= Responsive.wideLayoutBreakpoint;

        if (showSidebar) {
          return _buildDesktopLayout(context);
        } else {
          return widget.mobileBuilder(widget.child);
        }
      },
    );
  }

  Widget _buildDesktopLayout(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AmbientBackground(
        child: Stack(
          children: [
            // Main content — reserve only the collapsed rail width on the left
            // so the rail's hover-expand overlays content instead of shoving it.
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.only(left: WebStyle.railWidth + 8),
                child: widget.child,
              ),
            ),

            // Floating glass rail overlays on the left edge.
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: WebNavRail(
                selectedIndex: widget.selectedIndex,
                isAuthenticated: widget.isAuthenticated,
                userId: widget.userId,
                onTap: widget.onTabChanged,
                onToggleTheme: () =>
                    context.read<ThemeProvider>().temporaryToggle(),
              ),
            ),
          ],
        ),
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
