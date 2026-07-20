import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/core/di/injection.dart';
import 'package:aurogram/features/auth/auth_service.dart';
import 'package:aurogram/shared/presentation/widgets/avatars/user_avatar.dart';
import 'package:aurogram/shared/presentation/web/web_style.dart';

/// Floating glass navigation rail for the premium web shell.
///
/// Collapsed to a slim icon rail; expands to a labelled panel ON HOVER as an
/// overlay (it paints over the content, never shoves it — the shell reserves
/// only the collapsed width). Uses a SINGLE MouseRegion for the whole rail to
/// avoid the per-item `mouse_tracker` re-entrancy bug this codebase hit before.
///
/// Web-only. The mobile bottom nav is untouched.
class WebNavRail extends StatefulWidget {
  final int selectedIndex;
  final bool isAuthenticated;
  final String? userId;
  final ValueChanged<int> onTap;
  final int unreadMessages;

  /// Toggles light/dark. Rendered as the moon/sun control at the bottom.
  final VoidCallback? onToggleTheme;

  const WebNavRail({
    super.key,
    required this.selectedIndex,
    required this.isAuthenticated,
    required this.onTap,
    this.userId,
    this.unreadMessages = 0,
    this.onToggleTheme,
  });

  @override
  State<WebNavRail> createState() => _WebNavRailState();
}

class _WebNavRailState extends State<WebNavRail> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final width = _expanded ? WebStyle.railExpandedWidth : WebStyle.railWidth;

    return MouseRegion(
      onEnter: (_) => setState(() => _expanded = true),
      onExit: (_) => setState(() => _expanded = false),
      child: AnimatedContainer(
        duration: WebStyle.expand,
        curve: WebStyle.ease,
        width: width,
        margin: const EdgeInsets.symmetric(vertical: 16),
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          color: WebStyle.glassFillRaised(isDark),
          borderRadius: const BorderRadius.only(
            topRight: Radius.circular(28),
            bottomRight: Radius.circular(28),
          ),
          border: Border.all(color: WebStyle.glassBorder(isDark), width: 1),
          boxShadow: WebStyle.tileShadow(isDark),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLogo(isDark),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                children: [
                  _item(isDark,
                      index: 0,
                      icon: Icons.public_outlined,
                      selectedIcon: Icons.public,
                      label: 'Dashboard',
                      lottieAsset: 'assets/animations/globe.json'),
                  _item(isDark,
                      index: 1,
                      icon: Icons.grid_view_outlined,
                      selectedIcon: Icons.grid_view,
                      label: 'Grams'),
                  if (widget.isAuthenticated) ...[
                    _item(isDark,
                        index: 2,
                        icon: Icons.send_outlined,
                        selectedIcon: Icons.send,
                        label: 'Messages',
                        badge: widget.unreadMessages),
                    _item(isDark,
                        index: 3,
                        icon: Icons.person_outline,
                        selectedIcon: Icons.person,
                        label: 'Profile',
                        showAvatar: true),
                  ],
                ],
              ),
            ),
            _buildBottom(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildLogo(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 12, 8),
      child: Row(
        mainAxisAlignment:
            _expanded ? MainAxisAlignment.start : MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 38,
            height: 38,
            child: Image.asset(
              'assets/images/icon_transparent.png',
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Icon(Icons.auto_awesome,
                  color: WebStyle.accent(isDark), size: 28),
            ),
          ),
          if (_expanded) ...[
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'aurogram',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                  color: WebStyle.textPrimary(isDark),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _item(
    bool isDark, {
    required int index,
    required IconData icon,
    required IconData selectedIcon,
    required String label,
    String? asset,
    String? lottieAsset,
    int badge = 0,
    bool showAvatar = false,
  }) {
    final selected = widget.selectedIndex == index;
    final accent = WebStyle.accent(isDark);
    final activeColor = WebStyle.textPrimary(isDark);
    final inactiveColor = WebStyle.textSecondary(isDark);

    Widget leading;
    if (showAvatar && widget.userId != null) {
      leading = Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? accent : inactiveColor.withValues(alpha: 0.4),
            width: selected ? 2 : 1.5,
          ),
        ),
        child: ClipOval(
          child: UserAvatar(
            userId: widget.userId,
            size: 26,
            loadFromFirestore: true,
          ),
        ),
      );
    } else if (lottieAsset != null) {
      leading = SizedBox(
        width: 28,
        height: 28,
        child: Opacity(
          opacity: selected ? 1.0 : 0.6,
          child: Lottie.asset(
            lottieAsset,
            width: 28,
            height: 28,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Icon(
              selected ? selectedIcon : icon,
              color: selected ? accent : inactiveColor,
              size: 26,
            ),
          ),
        ),
      );
    } else if (asset != null) {
      leading = SizedBox(
        width: 28,
        height: 28,
        child: Image.asset(
          asset,
          fit: BoxFit.contain,
          opacity: AlwaysStoppedAnimation(selected ? 1.0 : 0.65),
          errorBuilder: (_, __, ___) => Icon(
            selected ? selectedIcon : icon,
            color: selected ? accent : inactiveColor,
            size: 26,
          ),
        ),
      );
    } else {
      leading = Icon(
        selected ? selectedIcon : icon,
        color: selected ? accent : inactiveColor,
        size: 26,
      );
    }

    // Badge overlay
    if (badge > 0) {
      leading = Stack(
        clipBehavior: Clip.none,
        children: [
          leading,
          Positioned(
            right: -6,
            top: -4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              constraints: const BoxConstraints(minWidth: 18, minHeight: 16),
              decoration: BoxDecoration(
                color: AppTheme.errorColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                badge > 99 ? '99+' : '$badge',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      );
    }

    Widget row = AnimatedContainer(
      duration: WebStyle.hover,
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: selected
            ? accent.withValues(alpha: isDark ? 0.16 : 0.10)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        border: selected
            ? Border.all(color: accent.withValues(alpha: 0.30), width: 1)
            : null,
      ),
      child: Row(
        mainAxisAlignment:
            _expanded ? MainAxisAlignment.start : MainAxisAlignment.center,
        children: [
          leading,
          if (_expanded) ...[
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15.5,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected ? activeColor : inactiveColor,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ],
        ],
      ),
    );

    if (!_expanded && kIsWeb) {
      row = Tooltip(message: label, preferBelow: false, child: row);
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => widget.onTap(index),
      child: row,
    );
  }

  Widget _buildBottom(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 1,
            margin: const EdgeInsets.only(bottom: 10),
            color: WebStyle.glassBorder(isDark),
          ),
          if (widget.onToggleTheme != null)
            _bottomButton(isDark,
                icon: isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                label: isDark ? 'Light mode' : 'Dark mode',
                onTap: widget.onToggleTheme!),
          _bottomButton(isDark,
              icon: Icons.settings_outlined,
              label: 'Settings',
              onTap: () => context.push('/settings')),
          if (!widget.isAuthenticated)
            _bottomButton(isDark,
                icon: Icons.login,
                label: 'Sign in',
                accent: true,
                onTap: () => context.push('/login'))
          else
            _bottomButton(isDark,
                icon: Icons.logout,
                label: 'Log out',
                destructive: true,
                onTap: () => locator<AuthService>().signOut()),
        ],
      ),
    );
  }

  Widget _bottomButton(
    bool isDark, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool destructive = false,
    bool accent = false,
  }) {
    final color = destructive
        ? AppTheme.errorColor
        : accent
            ? WebStyle.accent(isDark)
            : WebStyle.textSecondary(isDark);

    Widget row = Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: accent
            ? WebStyle.accent(isDark).withValues(alpha: isDark ? 0.14 : 0.10)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment:
            _expanded ? MainAxisAlignment.start : MainAxisAlignment.center,
        children: [
          Icon(icon, size: 22, color: color),
          if (_expanded) ...[
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 14, color: color),
              ),
            ),
          ],
        ],
      ),
    );

    if (!_expanded && kIsWeb) {
      row = Tooltip(message: label, preferBelow: false, child: row);
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: row,
    );
  }
}
