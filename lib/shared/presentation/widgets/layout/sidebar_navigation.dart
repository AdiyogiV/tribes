import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/shared/presentation/widgets/avatars/user_avatar.dart';
import 'package:aurogram/core/di/injection.dart';
import 'package:aurogram/features/auth/auth_service.dart';
import 'package:aurogram/pages/helpers/user_settings.dart';
import 'package:aurogram/widgets/cosmic_dashboard.dart';
import 'package:aurogram/features/auth/login.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';

/// Desktop sidebar navigation for web/tablet
/// Shows navigation items vertically with icons and labels
class SidebarNavigation extends StatefulWidget {
  final int selectedIndex;
  final bool isAuthenticated;
  final String? userId;
  final String? userName;
  final ValueChanged<int> onTap;
  final bool isCollapsed;
  final VoidCallback? onToggleCollapse;
  final int unreadMessages;
  final int unreadNotifications;

  /// Tab-specific action builder that receives isCollapsed to render appropriately
  final Widget Function(bool isCollapsed)? tabActionBuilder;

  const SidebarNavigation({
    super.key,
    required this.selectedIndex,
    required this.isAuthenticated,
    required this.onTap,
    this.userId,
    this.userName,
    this.isCollapsed = false,
    this.onToggleCollapse,
    this.unreadMessages = 0,
    this.unreadNotifications = 0,
    this.tabActionBuilder,
  });

  @override
  State<SidebarNavigation> createState() => _SidebarNavigationState();
}

class _SidebarNavigationState extends State<SidebarNavigation>
    with SingleTickerProviderStateMixin {
  // Removed _hoveredIndex from parent state - each nav item manages its own hover state

  // Animation controller to track the collapse/expand animation progress
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
      value: widget.isCollapsed ? 0.0 : 1.0,
    );
  }

  @override
  void didUpdateWidget(SidebarNavigation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isCollapsed != widget.isCollapsed) {
      if (widget.isCollapsed) {
        _animationController.reverse();
      } else {
        _animationController.forward();
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final double sidebarWidth = widget.isCollapsed ? 88 : 280;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      width: sidebarWidth,
      height: double.infinity,
      clipBehavior: Clip.hardEdge, // Clip overflow during animation transition
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDarkColor : Colors.white,
        border: Border(
          right: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.06),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // App branding/logo
            _buildHeader(isDark),

            const SizedBox(height: AppDimensions.spacingLg),

            // Navigation items
            Expanded(
              child: ListView(
                padding: EdgeInsets.symmetric(
                    horizontal: widget.isCollapsed ? 12 : 16),
                children: [
                  _buildNavItem(
                    index: 0,
                    icon: Icons.explore_outlined,
                    selectedIcon: Icons.explore,
                    label: 'Discover',
                    isDark: isDark,
                  ),
                  _buildNavItem(
                    index: 1,
                    icon: Icons.grid_view_outlined,
                    selectedIcon: Icons.grid_view,
                    label: 'Grams',
                    isDark: isDark,
                  ),
                  _buildNavItem(
                    index: 2,
                    icon: Icons.chat_bubble_outline,
                    selectedIcon: Icons.chat_bubble,
                    label: 'HolyCow',
                    isDark: isDark,
                    useCustomIcon: true,
                  ),
                  // Messages and Profile only when signed in
                  if (widget.isAuthenticated) ...[
                    _buildNavItem(
                      index: 3,
                      icon: Icons.send_outlined,
                      selectedIcon: Icons.send,
                      label: 'Messages',
                      isDark: isDark,
                      badgeCount: widget.unreadMessages,
                    ),
                    _buildNavItem(
                      index: 4,
                      icon: Icons.person_outline,
                      selectedIcon: Icons.person,
                      label: 'Profile',
                      isDark: isDark,
                      showUserAvatar: true,
                    ),
                  ],
                ],
              ),
            ),

            // Bottom section - collapse toggle
            _buildBottomSection(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    final iconSize = widget.isCollapsed ? 44.0 : 52.0;

    // Logo widget - tappable to open Cosmic Dashboard
    Widget logoWidget = GestureDetector(
      onTap: () => CosmicDashboard.show(context),
      child: Container(
        width: iconSize,
        height: iconSize,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          child: Image.asset(
            'assets/images/icon_transparent.png',
            width: iconSize,
            height: iconSize,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Icon(
              Icons.auto_awesome,
              color: AppTheme.primaryColor,
              size: widget.isCollapsed ? 28 : 32,
            ),
          ),
        ),
      ),
    );
    // Show tooltip on web (useful for mouse hover)
    if (kIsWeb) {
      logoWidget = Tooltip(
        message: 'Open Cosmic Dashboard',
        child: logoWidget,
      );
    }

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, _) {
        final isFullyExpanded = _animationController.value == 1.0;

        return Padding(
          padding: EdgeInsets.symmetric(
            horizontal: widget.isCollapsed ? 16 : 20,
            vertical: 20,
          ),
          child: Column(
            crossAxisAlignment: widget.isCollapsed
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.start,
            children: [
              // Logo and title row
              Row(
                mainAxisAlignment: widget.isCollapsed
                    ? MainAxisAlignment.center
                    : MainAxisAlignment.start,
                children: [
                  logoWidget,
                  // Title - only show when fully expanded
                  if (!widget.isCollapsed && isFullyExpanded) ...[
                    const SizedBox(width: AppDimensions.spacingMdLg),
                    Expanded(
                      child: Text(
                        'Aurogram',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primaryColor,
                          letterSpacing: -0.5,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ],
              ),
              // Tab-specific action button (when provided)
              if (widget.tabActionBuilder != null) ...[
                const SizedBox(height: AppDimensions.spacingLg),
                widget.tabActionBuilder!(widget.isCollapsed),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required IconData selectedIcon,
    required String label,
    required bool isDark,
    bool useCustomIcon = false,
    bool showUserAvatar = false,
    int badgeCount = 0,
  }) {
    return _SidebarNavItem(
      index: index,
      icon: icon,
      selectedIcon: selectedIcon,
      label: label,
      isDark: isDark,
      isSelected: widget.selectedIndex == index,
      isCollapsed: widget.isCollapsed,
      expandAnimation: _animationController,
      useCustomIcon: useCustomIcon,
      showUserAvatar: showUserAvatar,
      badgeCount: badgeCount,
      userId: widget.userId,
      onTap: () => widget.onTap(index),
      buildUserAvatar: _buildUserAvatar,
      buildAiIcon: _buildAiIcon,
    );
  }

  Widget _buildUserAvatar(bool isSelected) {
    final size = widget.isCollapsed ? 28.0 : 32.0;
    // Theme-aware active color: black for light theme, white for dark theme
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color activeColor = isDark ? Colors.white : Colors.black;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size / 2),
        border: Border.all(
          color: isSelected ? activeColor : activeColor.withValues(alpha: 0.3),
          width: isSelected ? 2.0 : 1.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size / 2 - 2),
        child: UserAvatar(
          userId: widget.userId,
          size: size - 4,
          loadFromFirestore: true,
        ),
      ),
    );
  }

  Widget _buildAiIcon(bool isSelected, Color activeColor, Color inactiveColor) {
    final size = widget.isCollapsed ? 28.0 : 32.0;
    return SizedBox(
      width: size,
      height: size,
      child: Image.asset(
        'assets/images/cow1.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
        opacity: AlwaysStoppedAnimation(isSelected ? 1.0 : 0.6),
        errorBuilder: (_, __, ___) => Icon(
          isSelected ? Icons.chat_bubble : Icons.chat_bubble_outline,
          color: isSelected ? activeColor : inactiveColor,
          size: widget.isCollapsed ? 26 : 28,
        ),
      ),
    );
  }

  Widget _buildBottomSection(bool isDark) {
    return Padding(
      padding: EdgeInsets.all(widget.isCollapsed ? 12 : 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Divider
          Container(
            height: 1,
            margin: const EdgeInsets.only(bottom: AppDimensions.paddingMd),
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.06),
          ),

          // Settings button
          _buildBottomButton(
            isDark: isDark,
            icon: Icons.settings_outlined,
            label: 'Settings',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (context) => const UserSettingsPage()),
              );
            },
          ),

          SizedBox(height: widget.isCollapsed ? 6 : 8),

          // Sign In (when signed out) – show on all platforms when sidebar is visible (web + iPad wide)
          ...(!widget.isAuthenticated
              ? [
                  _buildBottomButton(
                    isDark: isDark,
                    icon: Icons.login,
                    label: 'Sign In',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (context) => const LoginPage()),
                      );
                    },
                    isPrimary: true,
                  ),
                ]
              : []),

          // Log Out (when signed in)
          ...(widget.isAuthenticated
              ? [
                  _buildBottomButton(
                    isDark: isDark,
                    icon: Icons.logout,
                    label: 'Log Out',
                    onTap: () async {
                      await locator<AuthService>().signOut();
                    },
                    isDestructive: true,
                  ),
                ]
              : []),

          SizedBox(height: widget.isCollapsed ? 6 : 8),

          // Collapse toggle button
          if (widget.onToggleCollapse != null)
            _buildBottomButton(
              isDark: isDark,
              icon: widget.isCollapsed ? Icons.menu_open : Icons.menu,
              label: 'Collapse',
              onTap: widget.onToggleCollapse!,
            ),
        ],
      ),
    );
  }

  Widget _buildBottomButton({
    required bool isDark,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isDestructive = false,
    bool isPrimary = false,
  }) {
    final color = isDestructive
        ? AppTheme.errorColor
        : isPrimary
            ? AppTheme.primaryColor
            : (isDark
                ? Colors.white.withValues(alpha: 0.6)
                : Colors.black.withValues(alpha: 0.5));

    Widget button = AnimatedBuilder(
      animation: _animationController,
      builder: (context, _) {
        final isFullyExpanded = _animationController.value == 1.0;

        return Container(
          padding: EdgeInsets.all(widget.isCollapsed ? 12 : 12),
          decoration: BoxDecoration(
            color: isPrimary
                ? AppTheme.primaryColor.withValues(alpha: isDark ? 0.15 : 0.1)
                : (isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.black.withValues(alpha: 0.03)),
            borderRadius: BorderRadius.circular(AppDimensions.radiusMdSm),
          ),
          child: Row(
            mainAxisAlignment: widget.isCollapsed
                ? MainAxisAlignment.center
                : MainAxisAlignment.start,
            mainAxisSize:
                widget.isCollapsed ? MainAxisSize.min : MainAxisSize.max,
            children: [
              Icon(
                icon,
                size: widget.isCollapsed ? 24 : 22,
                color: color,
              ),
              // Label - only show when fully expanded
              if (!widget.isCollapsed && isFullyExpanded) ...[
                const SizedBox(width: AppDimensions.spacingMd),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      color: color,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );

    // Show tooltip when collapsed on web (useful for mouse hover)
    if (widget.isCollapsed && kIsWeb) {
      button = Tooltip(
        message: label,
        child: button,
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: button,
    );
  }
}

/// Self-contained navigation item that manages its own hover state
/// This prevents the entire sidebar from rebuilding when hover state changes
class _SidebarNavItem extends StatefulWidget {
  final int index;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool isDark;
  final bool isSelected;
  final bool isCollapsed;
  final Animation<double> expandAnimation;
  final bool useCustomIcon;
  final bool showUserAvatar;
  final int badgeCount;
  final String? userId;
  final VoidCallback onTap;
  final Widget Function(bool isSelected) buildUserAvatar;
  final Widget Function(bool isSelected, Color activeColor, Color inactiveColor)
      buildAiIcon;

  const _SidebarNavItem({
    required this.index,
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.isDark,
    required this.isSelected,
    required this.isCollapsed,
    required this.expandAnimation,
    required this.useCustomIcon,
    required this.showUserAvatar,
    required this.badgeCount,
    required this.userId,
    required this.onTap,
    required this.buildUserAvatar,
    required this.buildAiIcon,
  });

  @override
  State<_SidebarNavItem> createState() => _SidebarNavItemState();
}

class _SidebarNavItemState extends State<_SidebarNavItem> {
  // Hover effects disabled to avoid mouse_tracker re-entrancy on web.
  static const bool _disableHover = true;
  final bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    // Theme-aware active color: black for light theme, white for dark theme
    final Color activeColor = widget.isDark ? Colors.white : Colors.black;
    final Color inactiveColor = widget.isDark
        ? Colors.white.withValues(alpha: 0.6)
        : Colors.black.withValues(alpha: 0.5);

    Widget navContent = AnimatedBuilder(
      animation: widget.expandAnimation,
      builder: (context, _) {
        final isFullyExpanded = widget.expandAnimation.value == 1.0;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: EdgeInsets.symmetric(
            horizontal: widget.isCollapsed ? 14 : 16,
            vertical: widget.isCollapsed ? 12 : 14,
          ),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? activeColor.withValues(alpha: widget.isDark ? 0.2 : 0.1)
                : (_disableHover
                    ? Colors.transparent
                    : (_isHovered
                        ? (widget.isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.black.withValues(alpha: 0.03))
                        : Colors.transparent)),
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            border: widget.isSelected
                ? Border.all(
                    color: activeColor.withValues(alpha: 0.3),
                    width: 1,
                  )
                : null,
          ),
          child: Row(
            mainAxisAlignment: widget.isCollapsed
                ? MainAxisAlignment.center
                : MainAxisAlignment.start,
            children: [
              // Icon or avatar with badge
              Stack(
                clipBehavior: Clip.none,
                children: [
                  if (widget.showUserAvatar && widget.userId != null)
                    widget.buildUserAvatar(widget.isSelected)
                  else if (widget.useCustomIcon && widget.index == 2)
                    widget.buildAiIcon(
                        widget.isSelected, activeColor, inactiveColor)
                  else
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 150),
                      child: Icon(
                        widget.isSelected ? widget.selectedIcon : widget.icon,
                        key: ValueKey(widget.isSelected),
                        color: widget.isSelected ? activeColor : inactiveColor,
                        size: widget.isCollapsed ? 26 : 28,
                      ),
                    ),
                  // Badge
                  if (widget.badgeCount > 0)
                    Positioned(
                      right: -6,
                      top: -4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.errorColor,
                          borderRadius: BorderRadius.circular(AppDimensions.radiusMdSm),
                        ),
                        constraints:
                            const BoxConstraints(minWidth: 18, minHeight: 16),
                        child: Text(
                          widget.badgeCount > 99
                              ? '99+'
                              : widget.badgeCount.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),

              // Label and badge count - only show when fully expanded (not during transition)
              if (!widget.isCollapsed && isFullyExpanded) ...[
                const SizedBox(width: AppDimensions.spacingMdLg),
                Expanded(
                  child: Text(
                    widget.label,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight:
                          widget.isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: widget.isSelected ? activeColor : inactiveColor,
                      letterSpacing: -0.2,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (widget.badgeCount > 0)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.errorColor,
                      borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                    ),
                    child: Text(
                      widget.badgeCount > 99
                          ? '99+'
                          : widget.badgeCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ],
          ),
        );
      },
    );

    // Wrap with Tooltip when collapsed on web (useful for mouse hover)
    if (widget.isCollapsed && kIsWeb) {
      navContent = Tooltip(
        message: widget.label,
        preferBelow: false,
        verticalOffset: 0,
        decoration: BoxDecoration(
          color: widget.isDark ? Colors.grey[800] : Colors.grey[700],
          borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
        ),
        textStyle: const TextStyle(
          color: Colors.white,
          fontSize: 13,
        ),
        child: navContent,
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: navContent,
      ),
    );
  }
}
