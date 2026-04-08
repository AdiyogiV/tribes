import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:aurogram/services/chat/space_chat_service.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:aurogram/widgets/ui/common_widgets.dart';
import 'package:aurogram/widgets/ui/skeleton_widgets.dart';
import 'package:aurogram/utils/theme/app_dimensions.dart';

/// Typing indicator bubble shown when other users are typing.
class ChatTypingIndicator extends StatelessWidget {
  final List<TypingUser> typingUsers;

  const ChatTypingIndicator({super.key, required this.typingUsers});

  @override
  Widget build(BuildContext context) {
    if (typingUsers.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(left: 4, right: 4, bottom: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingMd, vertical: AppDimensions.paddingSm),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTypingDots(),
                const SizedBox(width: AppDimensions.spacingSm),
                Text(
                  typingUsers.length == 1
                      ? '${typingUsers.first.userName.trim().isEmpty ? 'Someone' : typingUsers.first.userName} is typing'
                      : '${typingUsers.length} people are typing',
                  style: TextStyle(
                    color: AppTheme.primaryColor.withValues(alpha: 0.6),
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingDots() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
          3,
          (index) => AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                margin: const EdgeInsets.only(right: 2),
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
              )),
    );
  }
}

/// Empty state shown when there are no messages in the conversation.
class ChatEmptyState extends StatelessWidget {
  const ChatEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return EmptyStateWidget(
      icon: CupertinoIcons.chat_bubble_2,
      iconSize: 48,
      iconColor: AppTheme.primaryColor.withValues(alpha: 0.5),
      title: 'No messages yet',
      subtitle: 'Start the conversation!',
      padding: const EdgeInsets.only(bottom: 100, left: 32, right: 32),
    );
  }
}

/// Banner shown when offline.
class ChatConnectionBanner extends StatelessWidget {
  const ChatConnectionBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: AppDimensions.paddingSm),
      color: Colors.orange[100],
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wifi_off, size: 16, color: Colors.orange[700]),
          const SizedBox(width: AppDimensions.spacingSm),
          Text('No internet connection',
              style: TextStyle(
                  color: Colors.orange[700],
                  fontSize: 12,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

/// Skeleton loading state for the chat.
class ChatSkeleton extends StatelessWidget {
  const ChatSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
      reverse: true,
      physics: const NeverScrollableScrollPhysics(),
      children: const [
        SkeletonChatMessage(isUser: true, lineCount: 1),
        SkeletonChatMessage(lineCount: 3),
        SkeletonChatMessage(isUser: true, lineCount: 2),
        SkeletonChatMessage(lineCount: 2),
        SkeletonChatMessage(lineCount: 1),
        SkeletonChatMessage(isUser: true, lineCount: 3),
        SkeletonChatMessage(lineCount: 2),
        SkeletonChatMessage(isUser: true, lineCount: 1),
      ],
    );
  }
}

/// Instagram-style message request banner with accept/decline buttons.
class ChatRequestBanner extends StatelessWidget {
  final bool isDark;
  final String? displayName;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const ChatRequestBanner({
    super.key,
    required this.isDark,
    required this.displayName,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardDarkColor : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.06),
            width: 1,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Center(
              child: Text(
                '${displayName ?? "This person"} wants to send you a message',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: AppTheme.primaryColor.withValues(alpha: 0.8),
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onDecline,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: AppTheme.errorColor,
                        width: 1,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: Text(
                      'Delete',
                      style: TextStyle(
                        color: AppTheme.errorColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppDimensions.spacingSm),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onAccept,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Accept',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
