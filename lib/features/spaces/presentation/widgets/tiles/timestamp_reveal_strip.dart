import 'package:aurogram/core/theme/app_dimensions.dart';
import 'package:flutter/material.dart';
import 'package:aurogram/shared/models/chat_message.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/shared/presentation/widgets/loaders/skeleton_widgets.dart';

/// Content for the left-side strip revealed when user swipes chat left (Instagram-style).
/// Shows time, "edited" if any, and status icon for own messages.
class TimestampRevealStrip extends StatelessWidget {
  final ChatMessage message;
  final bool isOwnMessage;
  final bool isLastInGroup;

  const TimestampRevealStrip({
    super.key,
    required this.message,
    required this.isOwnMessage,
    required this.isLastInGroup,
  });

  static String formatRevealTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);
    if (difference.inDays > 0) {
      return '${difference.inDays}d';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m';
    } else {
      return 'now';
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.primaryColor.withValues(alpha: 0.5);
    final isEdited = message.editedAt != null;
    final isRead = message.readBy.isNotEmpty &&
        message.readBy.any((userId) => userId != message.senderId);

    return Padding(
      padding: const EdgeInsets.only(left: 4, right: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (isEdited)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                'edited',
                style: TextStyle(
                  fontSize: 10,
                  color: color,
                  fontStyle: FontStyle.italic,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (isOwnMessage && isLastInGroup) ...[
                _buildStatusIcon(color, isRead),
                const SizedBox(width: AppDimensions.spacingXxs),
              ],
              Flexible(
                child: Text(
                  formatRevealTime(message.timestamp),
                  style: TextStyle(
                    fontSize: 11,
                    color: color,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIcon(Color color, bool isRead) {
    switch (message.status) {
      case MessageStatus.sending:
        return const SizedBox(
          width: 14,
          height: 14,
          child: MessageSendingIndicator(),
        );
      case MessageStatus.sent:
        return Icon(Icons.done, size: 14, color: color);
      case MessageStatus.delivered:
        return Icon(
          Icons.done_all,
          size: 14,
          color: isRead ? Colors.blue : color,
        );
    }
  }
}
