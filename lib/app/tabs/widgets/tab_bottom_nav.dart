import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/shared/presentation/widgets/media/glass_container.dart';
import 'package:aurogram/shared/presentation/widgets/avatars/user_avatar.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';
import 'package:lottie/lottie.dart';

class TabBottomNav extends StatelessWidget {
  final int selectedIndex;
  final bool isAuthenticated;
  final String? userId;
  final ValueChanged<int> onTap;

  const TabBottomNav({
    super.key,
    required this.selectedIndex,
    required this.isAuthenticated,
    required this.onTap,
    this.userId,
  });

  // ── Layout constants (single source of truth) ──
  // Also consumed by HolyCow's collapsed cow button so it can align itself
  // with the profile (rightmost) tab. Keep these in sync with the build()
  // below: Padding(horizontal: horizontalPadding) → Row(spaceEvenly) of
  // [itemCount] items, each SizedBox(width: itemWidth).
  static const double itemWidth = 64;
  static const double horizontalPadding = 16;
  static const int itemCount = 4;

  /// Horizontal distance from the screen's right edge to the *center* of the
  /// nav item at [indexFromRight] (0 = rightmost / profile tab).
  ///
  /// Mirrors the `Row(spaceEvenly)` layout exactly: N items produce N+1 equal
  /// gaps. Deriving the cow's position from this instead of re-hardcoding the
  /// numbers means the cow can never silently drift if the nav layout changes.
  static double itemCenterFromRight(double screenWidth, int indexFromRight) {
    final innerWidth = screenWidth - 2 * horizontalPadding;
    final gap = (innerWidth - itemCount * itemWidth) / (itemCount + 1);
    return horizontalPadding +
        gap +
        itemWidth / 2 +
indexFromRight * (gap + itemWidth);
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color barBase = isDark ? AppTheme.cardDarkColor : Colors.white;
    final Color activeColor = AppTheme.primaryColor;
    final Color inactiveColor = isDark
        ? AppTheme.primaryColor.withValues(alpha: 0.6)
        : AppTheme.primaryColor.withValues(alpha: 0.5);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        child: GlassContainer(
          height: 70,
          padding: EdgeInsets.zero,
          baseColor: barBase,
          border: Border.all(color: Colors.transparent, width: 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // New Feed (HolyCow AI) - Default tab
              _NavItemWithLottie(
                assetPath: 'assets/animations/globe.json',
                isSelected: selectedIndex == 0,
                activeColor: activeColor,
                inactiveColor: inactiveColor,
                onTap: () => onTap(0),
              ),
              // Grams
              _NavItem(
                iconData: CupertinoIcons.square_grid_2x2,
                selectedIconData: CupertinoIcons.square_grid_2x2_fill,
                isSelected: selectedIndex == 1,
                activeColor: activeColor,
                inactiveColor: inactiveColor,
                onTap: () => onTap(1),
              ),
              // Messages (when logged in) / Login (when logged out)
              isAuthenticated
                  ? _NavItem(
                      iconData: CupertinoIcons.paperplane,
                      selectedIconData: CupertinoIcons.paperplane_fill,
                      isSelected: selectedIndex == 2,
                      activeColor: activeColor,
                      inactiveColor: inactiveColor,
                      onTap: () => onTap(2),
                    )
                  : _NavItem(
                      iconData: CupertinoIcons.lock_open,
                      selectedIconData: CupertinoIcons.lock_open,
                      isSelected: selectedIndex == 2,
                      activeColor: activeColor,
                      inactiveColor: inactiveColor,
                      onTap: () => onTap(2),
                    ),
              // Profile (when logged in) / Settings (when logged out)
              isAuthenticated
                  ? _NavItemWithUserAvatar(
                      userId: userId,
                      isSelected: selectedIndex == 3,
                      onTap: () => onTap(3),
                    )
                  : _NavItem(
                      iconData: CupertinoIcons.settings,
                      selectedIconData: CupertinoIcons.settings_solid,
                      isSelected: selectedIndex == 3,
                      activeColor: activeColor,
                      inactiveColor: inactiveColor,
                      onTap: () => onTap(3),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData iconData;
  final IconData? selectedIconData;
  final bool isSelected;
  final Color activeColor;
  final Color inactiveColor;
  final VoidCallback onTap;

  const _NavItem({
    required this.iconData,
    this.selectedIconData,
    required this.isSelected,
    required this.activeColor,
    required this.inactiveColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimensions.radiusMdLg),
      splashFactory: NoSplash.splashFactory,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
      focusColor: Colors.transparent,
      child: SizedBox(
        width: 64,
        height: 70,
        child: Stack(
          alignment: Alignment.center,
          children: [
            AnimatedOpacity(
              opacity: isSelected ? 1.0 : 0.9,
              duration: const Duration(milliseconds: 180),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, animation) =>
                    ScaleTransition(scale: animation, child: child),
                child: Icon(
                  isSelected && selectedIconData != null
                      ? selectedIconData!
                      : iconData,
                  key: ValueKey<bool>(isSelected),
                  color: isSelected ? activeColor : inactiveColor,
                  size: isSelected ? 32 : 24,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItemWithLottie extends StatefulWidget {
  final String assetPath;
  final bool isSelected;
  final Color activeColor;
  final Color inactiveColor;
  final VoidCallback onTap;

  const _NavItemWithLottie({
    required this.assetPath,
    required this.isSelected,
    required this.activeColor,
    required this.inactiveColor,
    required this.onTap,
  });

  @override
  State<_NavItemWithLottie> createState() => _NavItemWithLottieState();
}

class _NavItemWithLottieState extends State<_NavItemWithLottie>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
  }

  @override
  void didUpdateWidget(_NavItemWithLottie oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSelected && !oldWidget.isSelected) {
      _controller.repeat();
    } else if (!widget.isSelected && oldWidget.isSelected) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: widget.onTap,
      borderRadius: BorderRadius.circular(AppDimensions.radiusMdLg),
      splashFactory: NoSplash.splashFactory,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
      focusColor: Colors.transparent,
      child: SizedBox(
        width: 64,
        height: 70,
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: widget.isSelected ? 50 : 40,
            height: widget.isSelected ? 50 : 40,
            child: Lottie.asset(
              widget.assetPath,
              controller: _controller,
              fit: BoxFit.contain,
              onLoaded: (composition) {
                // 3x slower than original duration
                _controller.duration = composition.duration * 3;
                if (widget.isSelected) {
                  _controller.repeat();
                }
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItemWithUserAvatar extends StatelessWidget {
  final String? userId;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItemWithUserAvatar({
    required this.userId,
    required this.isSelected,
    required this.onTap,
  });

  Key get _avatarKey => ValueKey('nav_avatar_${userId}_$isSelected');

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimensions.radiusMdLg),
      splashFactory: NoSplash.splashFactory,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
      focusColor: Colors.transparent,
      child: SizedBox(
        width: 64,
        height: 70,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, animation) =>
              ScaleTransition(scale: animation, child: child),
          child: AnimatedOpacity(
            opacity: isSelected ? 1.0 : 0.9,
            duration: const Duration(milliseconds: 180),
            child: Container(
              key: ValueKey<bool>(isSelected),
              width: isSelected ? 36 : 28,
              height: isSelected ? 36 : 28,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(isSelected ? 18 : 14),
                border: Border.all(
                  color: isSelected
                      ? AppTheme.primaryColor
                      : AppTheme.primaryColor.withValues(alpha: 0.3),
                  width: isSelected ? 2.0 : 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: isSelected ? 3 : 2,
                    offset: Offset(0, isSelected ? 1 : 1),
                  ),
                ],
              ),
              child: UserAvatar(
                key: _avatarKey,
                userId: userId,
                size: isSelected ? 32 : 24,
                loadFromFirestore: true,
                borderRadius: BorderRadius.circular(isSelected ? 16 : 12),
                errorWidget: Icon(
                  isSelected
                      ? CupertinoIcons.person_fill
                      : CupertinoIcons.person,
                  color: AppTheme.primaryColor,
                  size: isSelected ? 20 : 18,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
