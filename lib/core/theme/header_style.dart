import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/core/theme/theme_helper.dart';
import 'package:aurogram/pages/helpers/flash.dart';
import 'package:aurogram/widgets/cosmic_dashboard.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';

/// Header background style options
enum HeaderBackgroundStyle {
  /// Semi-transparent toolbar - content subtly shows through (translucent)
  transparent,

  /// Legacy option - now maps to transparent
  gradient,
}

/// Opacity for the app header background (semi-transparent toolbar effect).
const double _headerBackgroundOpacity = 0.0;

/// Provides standardized header widgets and styles for consistent UI across the app
class AppHeaderStyle {
  // ============================================
  // LAYOUT CONSTANTS - Use these for consistent spacing across all tabs
  // ============================================

  /// Standard top padding between header and first content item
  static const double contentTopPadding = 16.0;

  /// Standard bottom padding to account for bottom navigation/toolbox
  static const double contentBottomPadding = 120.0;

  /// Standard horizontal padding for content cards
  static const double contentHorizontalPadding = 16.0;

  /// Standard vertical gap between cards/list items
  static const double cardVerticalGap = 10.0;

  // ============================================
  // FEED POST PADDING (Instagram-aligned)
  // ============================================
  /// Horizontal padding for all post content (caption, toolbar, text)
  static const double feedContentPaddingH = 16.0;

  /// Vertical gap between post sections (header→media, media→toolbar, etc.)
  static const double feedSectionGap = 8.0;

  /// Small gap (e.g. caption→time)
  static const double feedTightGap = 4.0;

  /// Vertical padding around the whole post
  static const double feedPostOuterV = 8.0;

  /// Gap between posts in feed
  static const double feedPostBottom = 8.0;

  /// Post header row vertical padding
  static const double feedHeaderVertical = 4.0;

  /// Standard SliverAppBar expanded height (without search field)
  static const double headerExpandedHeight = 72.0;

  /// Standard SliverAppBar collapsed height (without search field)
  static const double headerCollapsedHeight = 64.0;

  /// Standard toolbar height
  static const double headerToolbarHeight = 60.0;

  /// Standard icon size for header icons (consistent across all tabs)
  static const double headerIconSize = 28.0;

  // ============================================
  // CARD STYLING CONSTANTS
  // ============================================

  /// Standard card border radius (main content cards)
  static const double cardBorderRadius = 20.0;

  /// Border radius for post media content (images, videos)
  static const double postMediaBorderRadius = 10.0;

  /// Smaller border radius for notification tiles and smaller cards
  static const double cardBorderRadiusSmall = 12.0;

  /// Standard card internal horizontal padding
  static const double cardInternalPaddingH = 16.0;

  /// Standard card internal vertical padding
  static const double cardInternalPaddingV = 14.0;

  /// Standard card height for compact items (messages, grams)
  static const double cardCompactHeight = 70.0;

  /// Standard card height for regular items
  static const double cardRegularHeight = 104.0;

  /// Get standard card box shadow for light/dark mode
  static List<BoxShadow> cardBoxShadow(bool isDark) => [
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.12 : 0.06),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];

  /// Background color for headers (semi-transparent toolbar).
  static Color headerBackgroundColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return (isDark ? AppTheme.cardDarkColor : Colors.white)
        .withValues(alpha: _headerBackgroundOpacity);
  }

  /// Get standard card border for light/dark mode
  static Border cardBorder(bool isDark) => Border.all(
        color: isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.black.withValues(alpha: 0.06),
        width: 0.5,
      );

  /// Get standard card gradient colors for light/dark mode
  static List<Color> cardGradientColors(bool isDark, Color baseColor) => [
        baseColor.withValues(alpha: isDark ? 0.95 : 0.98),
        baseColor.withValues(alpha: isDark ? 0.90 : 0.94),
      ];

  // ============================================
  // UNIVERSAL HEADER CONTENT
  // ============================================

  /// Universal header content widget that all tabs should use for perfect consistency
  /// [leadingWidget] - Optional widget to show instead of app icon (e.g., back button)
  /// [isRefreshing] - When true, the title text will shimmer to indicate refresh in progress
  /// [enableLogoTap] - When true, tapping the logo opens the Cosmic Dashboard (default: true)
  static Widget buildUniversalHeaderContent({
    required String title,
    Widget? actionButton,
    Widget? leadingWidget,
    bool isRefreshing = false,
    bool enableLogoTap = true,
  }) {
    // Build the logo widget (no shimmer - stays normal)
    // Wrapped in Builder to get context for CosmicDashboard
    Widget logoWidget = Builder(
      builder: (context) {
        final logo = SizedBox(
          height: 56,
          child: Image.asset(
            'assets/images/icon_transparent.png',
            fit: BoxFit.contain,
          ),
        );

        if (!enableLogoTap) return logo;

        return GestureDetector(
          onTap: () => CosmicDashboard.show(context),
          behavior: HitTestBehavior.opaque,
          child: logo,
        );
      },
    );

    // Title - shimmer when refreshing, normal text otherwise
    Widget titleWidget = isRefreshing
        ? ShimmerText(
            text: title,
            fontSize: ThemeHelper.headerStyle.fontSize ?? 18,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          )
        : Text(
            title,
            style: ThemeHelper.headerStyle.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          );

    // Use LayoutBuilder to match tab bar spacing (spaceEvenly with 4 × 64px items)
    // This ensures header icons align vertically with tab bar and input toolbar icons.
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        // Tab bar uses spaceEvenly with 4 items of 64px each
        // gap = (totalWidth - 4*64) / 5
        final gap = (totalWidth - 4 * 64) / 5;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Left gap + icon area — aligned with first tab bar icon
            SizedBox(width: gap),
            SizedBox(
              width: 64,
              child: Center(
                child: leadingWidget ?? logoWidget,
              ),
            ),
            // Centered title
            Expanded(
              child: Center(
                child: titleWidget,
              ),
            ),
            // Right action area — aligned with last tab bar icon
            SizedBox(
              width: 64,
              child: Center(
                child: actionButton ?? const SizedBox.shrink(),
              ),
            ),
            SizedBox(width: gap),
          ],
        );
      },
    );
  }

  // ============================================
  // SLIVER APP BAR (for CustomScrollView)
  // ============================================

  /// Extra top padding for web to compensate for lack of system status bar.
  /// On mobile devices, the status bar provides natural spacing at the top.
  /// On web, there's no status bar, so we add this padding manually.
  static const double webTopPadding = 16.0;

  /// Creates a standard sliver app header - semi-transparent toolbar
  /// [isRefreshing] - When true, the logo will shimmer to indicate refresh in progress
  /// [pinned] - When true, the header stays fixed at the top and does not scroll away
  static SliverAppBar buildStandardHeader({
    required BuildContext context,
    required String title,
    Widget? actionButton,
    Widget? leadingWidget,
    bool showSearchField = true,
    VoidCallback? onSearchChanged,
    FocusNode? searchFocusNode,
    Function(String)? onSearch,
    HeaderBackgroundStyle backgroundStyle = HeaderBackgroundStyle.transparent,
    bool isRefreshing = false,
    bool pinned = false,
  }) {
    // On web, add extra top padding since there's no system status bar
    final double topPadding = kIsWeb ? webTopPadding : 0.0;
    return SliverAppBar(
      titleSpacing: 0,
      automaticallyImplyLeading: false,
      title: Padding(
        padding: EdgeInsets.only(top: topPadding),
        child: buildUniversalHeaderContent(
          title: title,
          actionButton: actionButton,
          leadingWidget: leadingWidget,
          isRefreshing: isRefreshing,
        ),
      ),
      // Semi-transparent toolbar (content shows through subtly)
      backgroundColor: Colors.transparent,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      forceMaterialTransparency: true,
      elevation: 0,
      // System UI styling
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Theme.of(context).brightness == Brightness.dark
            ? Brightness.light
            : Brightness.dark,
        statusBarBrightness: Theme.of(context).brightness,
      ),
      // Behavior
      pinned: pinned,
      floating: !pinned,
      stretch: true,
      expandedHeight:
          (showSearchField ? 110 : headerExpandedHeight) + topPadding,
      collapsedHeight:
          (showSearchField ? 88 : headerCollapsedHeight) + topPadding,
      toolbarHeight: headerToolbarHeight + topPadding,
      flexibleSpace: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: headerBackgroundColor(context),
              ),
            ),
          ),
          if (showSearchField)
            Padding(
              padding: EdgeInsets.only(top: topPadding + 4.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  const SizedBox(height: 62),
                  _buildSearchField(context, searchFocusNode, onSearch),
                ],
              ),
            ),
        ],
      ),
      iconTheme: IconThemeData(color: AppTheme.primaryColor),
    );
  }

  // ============================================
  // WIDE LAYOUT HEADER (sidebar-aligned, floating)
  // ============================================

  /// Sidebar header: padding 20 + row height 52 → vertical center of title = 20 + 26 = 46 from top (within safe area).
  static const double _wideLayoutSidebarTitleCenterFromTop = 46.0;

  /// Compact title row height (text-only; sidebar row is 52 for logo).
  static const double wideLayoutHeaderRowHeight = 32.0;
  static const double wideLayoutHeaderHorizontalPadding = 10.0;

  /// Legacy: used by embedded_chat_view for its header. Prefer buildWideLayoutHeaderSliver.
  static const double wideLayoutHeaderTitleTopPadding = 20.0;
  static const double wideLayoutHeaderBottomPadding = 4.0;

  /// Shared floating header for wide layout (iPad/desktop). Title row is vertically centered on sidebar title. Minimal space below.
  static SliverAppBar buildWideLayoutHeaderSliver(
    BuildContext context, {
    required String title,
    Widget? trailing,
  }) {
    final topInset = MediaQuery.of(context).padding.top;
    // Position title row so its center matches sidebar title center; toolbar ends right below row (no extra bottom padding).
    final titleRowTop = topInset +
        _wideLayoutSidebarTitleCenterFromTop -
        wideLayoutHeaderRowHeight / 2;
    final toolbarHeight = titleRowTop + wideLayoutHeaderRowHeight;

    return SliverAppBar(
      floating: true,
      snap: true,
      automaticallyImplyLeading: false,
      toolbarHeight: toolbarHeight,
      titleSpacing: 0,
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      forceMaterialTransparency: true,
      title: null,
      flexibleSpace: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: headerBackgroundColor(context),
              ),
            ),
          ),
          Positioned(
            top: titleRowTop,
            left: wideLayoutHeaderHorizontalPadding,
            right: wideLayoutHeaderHorizontalPadding,
            height: wideLayoutHeaderRowHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const Spacer(),
                if (trailing != null) trailing,
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================
  // REGULAR APP BAR (for Scaffold)
  // ============================================

  /// Creates a standard regular AppBar - semi-transparent toolbar
  /// [leadingWidget] - Optional widget for the leading slot (e.g. back button)
  /// [isRefreshing] - When true, the logo will shimmer to indicate refresh in progress
  static AppBar buildStandardAppBar({
    required BuildContext context,
    required String title,
    Widget? actionButton,
    Widget? leadingWidget,
    bool automaticallyImplyLeading = true,
    double toolbarHeight = 60,
    HeaderBackgroundStyle backgroundStyle = HeaderBackgroundStyle.transparent,
    bool isRefreshing = false,
  }) {
    // On web, add extra top padding since there's no system status bar
    final double topPadding = kIsWeb ? webTopPadding : 0.0;

    return AppBar(
      // Semi-transparent toolbar (content shows through subtly)
      backgroundColor: headerBackgroundColor(context),
      elevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      forceMaterialTransparency: false,
      shape: null,
      automaticallyImplyLeading: automaticallyImplyLeading,
      // Layout - add web top padding
      toolbarHeight: toolbarHeight + topPadding,
      titleSpacing: 0,
      // System UI styling
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Theme.of(context).brightness == Brightness.dark
            ? Brightness.light
            : Brightness.dark,
        statusBarBrightness: Theme.of(context).brightness,
      ),
      iconTheme: IconThemeData(color: AppTheme.primaryColor),
      title: Padding(
        padding: EdgeInsets.only(top: topPadding),
        child: buildUniversalHeaderContent(
          title: title,
          actionButton: actionButton,
          leadingWidget: leadingWidget,
          isRefreshing: isRefreshing,
        ),
      ),
    );
  }

  // ============================================
  // SEARCH FIELD
  // ============================================

  /// Creates a standard search field with glass-like styling
  static Widget _buildSearchField(
    BuildContext context,
    FocusNode? focusNode,
    Function(String)? onChanged,
  ) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color surface = Theme.of(context).colorScheme.surface;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Container(
        height: 38,
        decoration: BoxDecoration(
          color: isDark
              ? surface.withValues(alpha: 0.7)
              : Colors.white.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(AppDimensions.radiusXxl),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.2)
                  : Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: TextField(
          focusNode: focusNode,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: "Search",
            hintStyle: TextStyle(
              fontSize: 14,
              color: isDark
                  ? AppTheme.textSecondaryDarkColor
                  : AppTheme.textSecondaryLightColor,
            ),
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 4.0, right: 2.0),
              child: Icon(
                Icons.search,
                color: AppTheme.primaryColor,
                size: headerIconSize,
              ),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusXxl),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusXxl),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppDimensions.radiusXxl),
              borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
            ),
            filled: true,
            fillColor: isDark
                ? surface.withValues(alpha: 0.7)
                : Colors.white.withValues(alpha: 0.9),
          ),
          style: ThemeHelper.bodyTextStyle.copyWith(fontSize: 14),
        ),
      ),
    );
  }

  // ============================================
  // UTILITY WIDGETS
  // ============================================

  /// Creates a standard create button for adding new items
  static Widget buildCreateButton({
    required String label,
    required VoidCallback onPressed,
    bool simpleIcon = false,
  }) {
    if (simpleIcon) {
      return IconButton(
        icon: Icon(
          CupertinoIcons.plus,
          color: AppTheme.primaryColor,
          size: headerIconSize,
        ),
        onPressed: onPressed,
        tooltip: 'Add $label',
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
      );
    }

    return Container(
      height: 32,
      margin: const EdgeInsets.only(left: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.2),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: AppTheme.scaffoldLightColor,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          minimumSize: const Size(0, 32),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
          ),
        ),
        onPressed: onPressed,
        child: Text("+ $label"),
      ),
    );
  }

  /// Creates a standard refresh header for SmartRefresher
  static Widget get refreshHeader => ThemeHelper.refreshHeader;

  /// Creates a compact IconButton for headers without extra padding
  static Widget buildCompactIconButton({
    required IconData icon,
    required VoidCallback onPressed,
    String? tooltip,
    Color? color,
  }) {
    return IconButton(
      icon: Icon(icon,
          color: color ?? AppTheme.primaryColor, size: headerIconSize),
      onPressed: onPressed,
      tooltip: tooltip,
      padding: const EdgeInsets.all(AppDimensions.paddingSm),
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
    );
  }

  /// Creates a custom header container with specified content
  static Widget buildCustomHeader({
    required BuildContext context,
    required Widget content,
    double height = 60,
  }) {
    return Container(
      height: height,
      color: Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: content,
    );
  }

  /// A universal header bar with semi-transparent toolbar that can be dropped anywhere
  static PreferredSizeWidget buildUniversalHeaderBarPreferred({
    required BuildContext context,
    required String title,
    Widget? actionButton,
    double height = 60,
  }) {
    // On web, add extra top padding since there's no system status bar
    final double topPadding = kIsWeb ? webTopPadding : 0.0;
    final double effectiveHeight = height + topPadding;

    return PreferredSize(
      preferredSize: Size.fromHeight(effectiveHeight),
      child: Container(
        height: effectiveHeight,
        decoration: BoxDecoration(
          color: headerBackgroundColor(context),
        ),
        padding: EdgeInsets.only(top: topPadding, left: 16.0, right: 16.0),
        child: buildUniversalHeaderContent(
          title: title,
          actionButton: actionButton,
        ),
      ),
    );
  }
}
