import 'package:flutter/material.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:aurogram/models/chat_message.dart';
import 'package:aurogram/utils/theme/app_dimensions.dart';

/// Group call message tile - centered display
class GroupCallMessageTile extends StatelessWidget {
  final ChatMessage message;
  final bool isLastInGroup;
  final VoidCallback onShowTime;

  const GroupCallMessageTile({
    super.key,
    required this.message,
    this.isLastInGroup = true,
    required this.onShowTime,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final content = message.content;

    return Container(
      margin: EdgeInsets.only(
        bottom: isLastInGroup ? 16 : 6,
        left: 16,
        right: 16,
        top: 6,
      ),
      child: Center(
        child: GestureDetector(
          onTap: onShowTime,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isDark
                  ? AppTheme.activeGreen.withValues(alpha: 0.15)
                  : AppTheme.activeGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
              border: Border.all(
                color: AppTheme.activeGreen.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppTheme.activeGreen.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.groups_rounded,
                    size: 16,
                    color: AppTheme.activeGreen,
                  ),
                ),
                const SizedBox(width: AppDimensions.spacingMdSm),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      content,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: AppDimensions.spacingXxs),
                    Text(
                      'Started by ${message.senderName}',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.6)
                            : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
