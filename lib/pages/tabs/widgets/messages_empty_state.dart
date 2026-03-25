import 'package:flutter/material.dart';
import 'package:aurogram/utils/theme/app_theme.dart';

class MessagesEmptyState extends StatelessWidget {
  final bool isDark;
  final String title;
  final String subtitle;

  const MessagesEmptyState({
    super.key,
    required this.isDark,
    this.title = 'No messages yet',
    this.subtitle = 'Search for users or invite friends to start chatting',
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(
            Icons.chat_bubble_outline_rounded,
            size: 48,
            color: AppTheme.primaryColor.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: isDark ? AppTheme.textDarkColor : AppTheme.textLightColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 14,
              color: isDark
                  ? AppTheme.textSecondaryDarkColor
                  : AppTheme.textSecondaryLightColor,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
