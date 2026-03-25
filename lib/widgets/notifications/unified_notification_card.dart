import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:aurogram/utils/theme/app_theme.dart';

/// Shared card style for all notification tiles: full width, no border/radius/shadow.
/// Same as "started following you" tile: transparent when read, subtle tint when unread.
BoxDecoration notificationTileDecoration({required bool isRead}) {
  final primaryColor = AppTheme.primaryColor;
  return BoxDecoration(
    color: isRead ? Colors.transparent : primaryColor.withValues(alpha: 0.05),
  );
}

/// Full-width notification tile shell: same style as Follow tile (full width, simple background).
/// Use [content] for the main line(s). Optional [trailing] and [actions] for buttons or extras.
class NotificationTileCard extends StatelessWidget {
  final Widget leading;
  final Widget content;
  final String timestamp;
  final Widget? trailing;
  final bool isRead;
  final VoidCallback? onTap;
  final Widget? actions;

  const NotificationTileCard({
    super.key,
    required this.leading,
    required this.content,
    required this.timestamp,
    this.trailing,
    this.isRead = false,
    this.onTap,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = AppTheme.primaryColor;

    return Container(
      decoration: notificationTileDecoration(isRead: isRead),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    leading,
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          content,
                          const SizedBox(height: 4),
                          Text(
                            timestamp,
                            style: TextStyle(
                              fontSize: 12,
                              color: primaryColor.withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (trailing != null) ...[
                      const SizedBox(width: 8),
                      trailing!,
                    ],
                  ],
                ),
                if (actions != null) ...[
                  const SizedBox(height: 12),
                  actions!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Unified notification card layout: same padding, radius, and hierarchy for all types.
/// Uses card background + Follow-style row (leading, content, timestamp, trailing).
/// [title] and [subtitle] are used when [content] is null; otherwise [content] is shown.
class UnifiedNotificationCard extends StatelessWidget {
  final Widget leading;
  final String title;
  final String? subtitle;
  final Widget? content;
  final String timestamp;
  final Widget? trailing;
  final bool isRead;
  final VoidCallback? onTap;
  final Widget? actions;

  const UnifiedNotificationCard({
    super.key,
    required this.leading,
    required this.title,
    this.subtitle,
    this.content,
    required this.timestamp,
    this.trailing,
    this.isRead = false,
    this.onTap,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = AppTheme.textColor;
    final secondaryColor = AppTheme.textSecondaryColor;

    Widget mainContent = content ??
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: textColor,
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (subtitle != null && subtitle!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                subtitle!,
                style: TextStyle(
                  fontSize: 13,
                  color: secondaryColor,
                  height: 1.3,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        );

    return NotificationTileCard(
      leading: leading,
      content: mainContent,
      timestamp: timestamp,
      trailing: trailing,
      isRead: isRead,
      onTap: onTap,
      actions: actions,
    );
  }
}
