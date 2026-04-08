import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:aurogram/widgets/common/user_avatar.dart';
import 'package:aurogram/utils/theme/app_dimensions.dart';

/// Top bar showing the user avatar, username, and an optional delete button for own stories.
class StoryTopBar extends StatelessWidget {
  final String userId;
  final bool isOwnStory;
  final bool hasStories;
  final VoidCallback onDelete;

  const StoryTopBar({
    super.key,
    required this.userId,
    required this.isOwnStory,
    required this.hasStories,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          UserAvatar(
            userId: userId,
            size: 36,
            loadFromFirestore: true,
          ),
          const SizedBox(width: AppDimensions.spacingMd),
          Expanded(
            child: _UserNameText(userId: userId),
          ),
          if (isOwnStory && hasStories)
            GestureDetector(
              onTap: onDelete,
              child: Container(
                padding: const EdgeInsets.all(AppDimensions.paddingSm),
                child: const Icon(Icons.delete_outline,
                    color: Colors.white, size: 24),
              ),
            ),
        ],
      ),
    );
  }
}

class _UserNameText extends StatelessWidget {
  final String userId;

  const _UserNameText({required this.userId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() as Map<String, dynamic>?;
        final name =
            data?['name'] as String? ?? data?['nickname'] as String? ?? 'Story';
        return Text(
          name,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.0,
            shadows: [
              Shadow(
                color: Colors.black54,
                blurRadius: 2,
                offset: Offset(0, 1),
              ),
            ],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
      },
    );
  }
}
