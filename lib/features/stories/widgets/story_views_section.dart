import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:aurogram/shared/presentation/widgets/media/common_widgets.dart';
import 'package:aurogram/features/stories/story_service.dart';
import 'package:aurogram/shared/presentation/widgets/avatars/user_avatar.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';

/// Bottom "views" section shown to the story owner, with a tap-to-expand viewers list.
class StoryViewsSection extends StatelessWidget {
  final String userId;
  final String storyId;
  final StoryService storyService;

  const StoryViewsSection({
    super.key,
    required this.userId,
    required this.storyId,
    required this.storyService,
  });

  Future<void> _showViewersList(BuildContext context) async {
    final viewers = await storyService.getStoryViewers(
      userId: userId,
      storyId: storyId,
      limit: 100,
    );

    if (!context.mounted) return;
    if (viewers.isEmpty) return;

    AppBottomSheet.show(
      context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingLg, vertical: AppDimensions.paddingMd),
            child: Row(
              children: [
                const Text(
                  'Views',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  '${viewers.length}',
                  style: TextStyle(color: Colors.grey[400], fontSize: 16),
                ),
              ],
            ),
          ),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: viewers.length,
              itemBuilder: (context, index) {
                final viewerId = viewers[index];
                return ListTile(
                  leading: UserAvatar(
                    userId: viewerId,
                    size: 40,
                    loadFromFirestore: true,
                  ),
                  title: _ViewerNameText(userId: viewerId),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                );
              },
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<int>(
      future: storyService.getStoryViewCount(
        userId: userId,
        storyId: storyId,
      ),
      builder: (context, snapshot) {
        final viewCount = snapshot.data ?? 0;
        if (viewCount == 0) return const SizedBox.shrink();

        return GestureDetector(
          onTap: () => _showViewersList(context),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: AppDimensions.paddingLg, vertical: AppDimensions.paddingMd),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.7),
                  Colors.black.withValues(alpha: 0.3),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.remove_red_eye, color: Colors.white, size: 18),
                const SizedBox(width: AppDimensions.spacingSm),
                Text(
                  viewCount == 1 ? '1 view' : '$viewCount views',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ViewerNameText extends StatelessWidget {
  final String userId;

  const _ViewerNameText({required this.userId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() as Map<String, dynamic>?;
        final name =
            data?['name'] as String? ?? data?['nickname'] as String? ?? 'User';
        return Text(
          name,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
      },
    );
  }
}
