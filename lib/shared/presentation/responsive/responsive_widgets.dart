/// Responsive design system widgets for web-optimized layouts.
///
/// This library provides a set of responsive components that adapt
/// their styling and layout based on screen size, enabling beautiful
/// web experiences while maintaining mobile-first design.
///
/// ## Core Components
///
/// - [ResponsiveCard] - Adaptive card with size variants
/// - [CardGrid] - Responsive grid layout for cards
/// - [ResponsiveRow] - Row that stacks on mobile
/// - [MasonryGrid] - Variable-height card grid
///
/// ## Layout Templates
///
/// - [DashboardShell] - Full-page layout with multiple modes
/// - [DashboardContent] - Scrollable content area
/// - [DashboardSection] - Section with optional title
///
/// ## Constraints & Spacing
///
/// - [ContentConstraint] - Max-width wrapper
/// - [ConstrainedScrollView] - Scrollable with max-width
/// - [SliverContentConstraint] - Sliver version for CustomScrollView
/// - [ResponsivePadding] - Adaptive padding
///
/// ## Usage Example
///
/// ```dart
/// import 'package:aurogram/shared/presentation/responsive/responsive_widgets.dart';
///
/// // Simple responsive card
/// ResponsiveCard(
///   size: ResponsiveCardSize.standard,
///   child: MyContent(),
/// )
///
/// // Dashboard with hero + sidebar
/// DashboardShell(
///   mode: DashboardLayoutMode.heroWithSidebar,
///   heroContent: MainChart(),
///   sidebarContent: [InfoCard1(), InfoCard2()],
/// )
///
/// // Constrained reading content
/// ContentConstraint.reading(
///   child: InsightsList(),
/// )
/// ```
library;

// Card components
export 'responsive_card.dart';

// Grid layouts
export 'card_grid.dart';

// Dashboard templates
export 'dashboard_shell.dart';

// Content constraints
export 'content_constraint.dart';
