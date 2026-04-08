import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:aurogram/utils/theme/app_dimensions.dart';

/// A context menu item
class ContextMenuItem {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool isDestructive;
  final bool enabled;

  const ContextMenuItem({
    required this.label,
    required this.icon,
    required this.onTap,
    this.isDestructive = false,
    this.enabled = true,
  });
}

/// A widget that shows a context menu on right-click (desktop) or long-press (mobile)
class ContextMenuWrapper extends StatelessWidget {
  final Widget child;
  final List<ContextMenuItem> items;
  final bool enabled;

  const ContextMenuWrapper({
    super.key,
    required this.child,
    required this.items,
    this.enabled = true,
  });

  void _showContextMenu(BuildContext context, Offset position) {
    if (items.isEmpty || !enabled) return;

    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;

    showMenu<void>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(position.dx, position.dy, 0, 0),
        Offset.zero & overlay.size,
      ),
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      ),
      color: isDark ? AppTheme.cardDarkColor : Colors.white,
      items: items
          .where((item) => item.enabled)
          .map((item) => PopupMenuItem<void>(
                onTap: () {
                  // Provide haptic feedback on mobile
                  if (!kIsWeb) {
                    HapticFeedback.lightImpact();
                  }
                  item.onTap();
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      item.icon,
                      size: 20,
                      color: item.isDestructive
                          ? AppTheme.errorColor
                          : (isDark ? Colors.white70 : Colors.black87),
                    ),
                    const SizedBox(width: AppDimensions.spacingMd),
                    Text(
                      item.label,
                      style: TextStyle(
                        fontSize: 14,
                        color: item.isDestructive
                            ? AppTheme.errorColor
                            : (isDark ? Colors.white : Colors.black87),
                      ),
                    ),
                  ],
                ),
              ))
          .toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!enabled || items.isEmpty) {
      return child;
    }

    // On web, use right-click
    if (kIsWeb) {
      return Listener(
        onPointerDown: (event) {
          // Check for right-click (button index 2)
          if (event.buttons == 2) {
            _showContextMenu(context, event.position);
          }
        },
        child: child,
      );
    }

    // On mobile, use long-press
    return GestureDetector(
      onLongPressStart: (details) {
        HapticFeedback.mediumImpact();
        _showContextMenu(context, details.globalPosition);
      },
      child: child,
    );
  }
}

/// Pre-built context menu items for common actions
class ContextMenuItems {
  ContextMenuItems._();

  static ContextMenuItem share({
    required VoidCallback onTap,
  }) {
    return ContextMenuItem(
      label: 'Share',
      icon: Icons.share_outlined,
      onTap: onTap,
    );
  }

  static ContextMenuItem copyLink({
    required VoidCallback onTap,
  }) {
    return ContextMenuItem(
      label: 'Copy Link',
      icon: Icons.link,
      onTap: onTap,
    );
  }

  static ContextMenuItem report({
    required VoidCallback onTap,
  }) {
    return ContextMenuItem(
      label: 'Report',
      icon: Icons.flag_outlined,
      onTap: onTap,
      isDestructive: true,
    );
  }

  static ContextMenuItem delete({
    required VoidCallback onTap,
  }) {
    return ContextMenuItem(
      label: 'Delete',
      icon: Icons.delete_outline,
      onTap: onTap,
      isDestructive: true,
    );
  }

  static ContextMenuItem repost({
    required VoidCallback onTap,
  }) {
    return ContextMenuItem(
      label: 'Repost',
      icon: Icons.repeat_rounded,
      onTap: onTap,
    );
  }

  static ContextMenuItem quote({
    required VoidCallback onTap,
  }) {
    return ContextMenuItem(
      label: 'Quote',
      icon: Icons.format_quote,
      onTap: onTap,
    );
  }

  static ContextMenuItem reply({
    required VoidCallback onTap,
  }) {
    return ContextMenuItem(
      label: 'Reply',
      icon: Icons.reply,
      onTap: onTap,
    );
  }

  static ContextMenuItem copy({
    required VoidCallback onTap,
  }) {
    return ContextMenuItem(
      label: 'Copy',
      icon: Icons.copy,
      onTap: onTap,
    );
  }

  static ContextMenuItem react({
    required VoidCallback onTap,
  }) {
    return ContextMenuItem(
      label: 'React',
      icon: Icons.emoji_emotions_outlined,
      onTap: onTap,
    );
  }

  static ContextMenuItem forward({
    required VoidCallback onTap,
  }) {
    return ContextMenuItem(
      label: 'Forward',
      icon: Icons.shortcut_rounded,
      onTap: onTap,
    );
  }

  static ContextMenuItem more({
    required VoidCallback onTap,
  }) {
    return ContextMenuItem(
      label: 'More',
      icon: Icons.more_horiz,
      onTap: onTap,
    );
  }

  static ContextMenuItem edit({
    required VoidCallback onTap,
  }) {
    return ContextMenuItem(
      label: 'Edit',
      icon: Icons.edit_outlined,
      onTap: onTap,
    );
  }

  static ContextMenuItem viewProfile({
    required VoidCallback onTap,
  }) {
    return ContextMenuItem(
      label: 'View Profile',
      icon: Icons.person_outline,
      onTap: onTap,
    );
  }

  static ContextMenuItem mute({
    required VoidCallback onTap,
    bool isMuted = false,
  }) {
    return ContextMenuItem(
      label: isMuted ? 'Unmute' : 'Mute',
      icon: isMuted
          ? Icons.notifications_active_outlined
          : Icons.notifications_off_outlined,
      onTap: onTap,
    );
  }

  static ContextMenuItem block({
    required VoidCallback onTap,
  }) {
    return ContextMenuItem(
      label: 'Block',
      icon: Icons.block,
      onTap: onTap,
      isDestructive: true,
    );
  }
}
