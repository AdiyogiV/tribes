import 'package:flutter/material.dart';
import 'package:aurogram/shared/models/chat_message.dart';

/// Namaste message tile - just the icon, no bubble
class NamasteMessageTile extends StatelessWidget {
  final ChatMessage message;
  final bool isOwnMessage;
  final bool isLastInGroup;
  final VoidCallback onShowTime;

  const NamasteMessageTile({
    super.key,
    required this.message,
    required this.isOwnMessage,
    this.isLastInGroup = true,
    required this.onShowTime,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(
        bottom: isLastInGroup ? 16 : 8,
        left: 4,
        right: 4,
      ),
      child: Column(
        crossAxisAlignment:
            isOwnMessage ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment:
                isOwnMessage ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: onShowTime,
                child: Image.asset(
                  'assets/icons/namaste.png',
                  width: 48,
                  height: 48,
                  errorBuilder: (_, __, ___) => const Text(
                    '🙏',
                    style: TextStyle(fontSize: 40),
                  ),
                ),
              ),
            ],
          ),
          // Time shown in swipe-left reveal strip (Instagram-style)
        ],
      ),
    );
  }
}
