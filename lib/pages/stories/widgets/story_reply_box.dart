import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:aurogram/utils/theme/app_dimensions.dart';

/// Instagram-style reply input bar shown at the bottom of the story viewer
/// for stories that don't belong to the current user.
class StoryReplyBox extends StatelessWidget {
  final TextEditingController replyController;
  final FocusNode replyFocusNode;
  final VoidCallback onSend;

  const StoryReplyBox({
    super.key,
    required this.replyController,
    required this.replyFocusNode,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(
        left: 16,
        right: 16,
        top: 8,
        bottom: 12,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 100),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: TextField(
                controller: replyController,
                focusNode: replyFocusNode,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                ),
                maxLines: null,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: InputDecoration(
                  hintText: 'Send message',
                  hintStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 15,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppDimensions.spacingSm),
          // Send button - listen to controller changes via ValueListenableBuilder
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: replyController,
            builder: (context, value, _) {
              return GestureDetector(
                onTap: onSend,
                child: Padding(
                  padding: const EdgeInsets.all(AppDimensions.paddingXs),
                  child: Icon(
                    CupertinoIcons.paperplane,
                    color: value.text.trim().isEmpty
                        ? Colors.white.withValues(alpha: 0.4)
                        : Colors.white,
                    size: 22,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
