import 'package:flutter/material.dart';
import 'package:aurogram/shared/models/chat_message.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';

/// Call message tile - shows call history
class CallMessageTile extends StatelessWidget {
  final ChatMessage message;
  final bool isLastInGroup;
  final String? currentUserId;
  final VoidCallback onShowTime;
  final VoidCallback? onCallback;

  const CallMessageTile({
    super.key,
    required this.message,
    this.isLastInGroup = true,
    this.currentUserId,
    required this.onShowTime,
    this.onCallback,
  });

  @override
  Widget build(BuildContext context) {
    final isOutgoing = message.senderId == currentUserId;
    final isVideo = message.callType == 'video';
    final status = message.callStatus ?? 'missed';
    final duration = message.callDuration ?? 0;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    IconData callIcon;
    Color statusColor;
    String statusText;

    switch (status) {
      case 'answered':
        callIcon = isVideo ? Icons.videocam_rounded : Icons.call_rounded;
        statusColor = AppTheme.activeGreen;
        statusText = _formatCallDuration(duration);
        break;
      case 'missed':
        callIcon = Icons.phone_missed_rounded;
        statusColor = AppTheme.dangerRed;
        statusText = isOutgoing ? 'No answer' : 'Missed';
        break;
      case 'rejected':
        callIcon = Icons.call_end_rounded;
        statusColor = AppTheme.dangerRed;
        statusText = 'Declined';
        break;
      case 'cancelled':
      default:
        callIcon = Icons.phone_disabled_rounded;
        statusColor = isDark ? Colors.grey[500]! : Colors.grey[600]!;
        statusText = 'Cancelled';
        break;
    }

    final bubbleColor = isOutgoing
        ? (isDark
            ? Colors.white.withValues(alpha: 0.08)
            : AppTheme.primaryColor.withValues(alpha: 0.15))
        : (isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.grey.withValues(alpha: 0.1));

    return Container(
      margin: EdgeInsets.only(
        bottom: isLastInGroup ? 12 : 4,
        left: 8,
        right: 8,
        top: 4,
      ),
      child: Row(
        mainAxisAlignment:
            isOutgoing ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Flexible(
            child: GestureDetector(
              onTap: onShowTime,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 240),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: bubbleColor,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(isOutgoing ? 16 : 4),
                    bottomRight: Radius.circular(isOutgoing ? 4 : 16),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppDimensions.paddingSm),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(callIcon, size: 18, color: statusColor),
                    ),
                    const SizedBox(width: AppDimensions.spacingMdSm),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isOutgoing
                                    ? Icons.call_made_rounded
                                    : Icons.call_received_rounded,
                                size: 12,
                                color: statusColor,
                              ),
                              const SizedBox(width: AppDimensions.spacingXs),
                              Flexible(
                                child: Text(
                                  isVideo ? 'Video call' : 'Voice call',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? Colors.white.withValues(alpha: 0.9)
                                        : Colors.grey[800],
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppDimensions.spacingXxs),
                          Text(
                            '$statusText • ${_formatMessageTime(message.timestamp)}',
                            style: TextStyle(
                              fontSize: 11,
                              color: status == 'missed' && !isOutgoing
                                  ? statusColor.withValues(alpha: 0.8)
                                  : (isDark
                                      ? Colors.white.withValues(alpha: 0.5)
                                      : Colors.grey[600]),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if ((status == 'missed' || status == 'rejected') &&
                        !isOutgoing &&
                        onCallback != null) ...[
                      const SizedBox(width: AppDimensions.spacingSm),
                      GestureDetector(
                        onTap: onCallback,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color:
                                AppTheme.primaryColor.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isVideo
                                ? Icons.videocam_rounded
                                : Icons.call_rounded,
                            size: 16,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatCallDuration(int seconds) {
    if (seconds <= 0) return 'Connected';
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    if (minutes >= 60) {
      final hours = minutes ~/ 60;
      final mins = minutes % 60;
      return '${hours}h ${mins}m ${secs}s';
    } else if (minutes > 0) {
      return '${minutes}m ${secs}s';
    } else {
      return '${secs}s';
    }
  }

  String _formatMessageTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'now';
    }
  }
}
