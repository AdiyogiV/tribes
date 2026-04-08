import 'package:flutter/material.dart';
import 'package:aurogram/models/chat_message.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:aurogram/utils/theme/app_dimensions.dart';

/// Inline reply preview shown inside the input area
class InlineReplyPreview extends StatelessWidget {
  final ChatMessage replyingTo;
  final bool isDark;
  final VoidCallback onCancel;

  const InlineReplyPreview({
    super.key,
    required this.replyingTo,
    required this.isDark,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 10, bottom: 6),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: AppTheme.primaryColor.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Accent line
          Container(
            width: 3,
            height: 28,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: AppDimensions.spacingMdSm),
          // Reply content
          Expanded(
            child: RichText(
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              text: TextSpan(
                children: [
                  TextSpan(
                    text: replyingTo.senderName,
                    style: TextStyle(
                      color: AppTheme.primaryColor.withValues(alpha: 0.85),
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  const TextSpan(
                    text: '  ',
                    style: TextStyle(fontSize: 13),
                  ),
                  TextSpan(
                    text: replyingTo.content,
                    style: TextStyle(
                      color: AppTheme.primaryColor.withValues(alpha: 0.5),
                      fontWeight: FontWeight.w400,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Close button
          GestureDetector(
            onTap: onCancel,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Icon(
                Icons.close_rounded,
                color: AppTheme.primaryColor.withValues(alpha: 0.4),
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
