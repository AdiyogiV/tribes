import 'package:flutter/material.dart';
import 'package:aurogram/services/story_service.dart';
import 'package:aurogram/pages/stories/story_composer_page.dart';
import 'package:aurogram/pages/stories/story_viewer_page.dart';
import 'package:aurogram/widgets/stories/story_ring.dart';
import 'package:aurogram/utils/theme/app_theme.dart';

/// Story ring sliver for the feed page.
/// Shows the horizontally-scrollable story ring row and the divider below it.
class FeedStoryRow extends StatelessWidget {
  final int storyRingRefreshKey;
  final bool storyRingForceRefresh;

  /// Called after a story is composed or viewed so the parent can bump the key.
  final void Function(int newKey, bool newForce) onStoryRefresh;

  const FeedStoryRow({
    super.key,
    required this.storyRingRefreshKey,
    required this.storyRingForceRefresh,
    required this.onStoryRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      key: ValueKey(storyRingRefreshKey),
      child: Transform.translate(
        offset: const Offset(0, -12),
        child: StoryRing(
          forceRefresh: storyRingForceRefresh,
          onAddStory: () async {
            final result = await Navigator.of(context).push<bool>(
              MaterialPageRoute(
                builder: (_) => const StoryComposerPage(),
              ),
            );
            if (result == true && context.mounted) {
              onStoryRefresh(storyRingRefreshKey + 1, false);
            }
          },
          onViewUserStories: (userId) async {
            final storyService = StoryService();
            final userIds = await storyService.getUsersWithStories();
            final idx = userIds.indexOf(userId);
            if (!context.mounted) return;
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => StoryViewerPage(
                  userIds: userIds,
                  initialUserIndex: idx >= 0 ? idx : 0,
                ),
              ),
            );
            if (context.mounted) {
              onStoryRefresh(storyRingRefreshKey + 1, false);
            }
          },
        ),
      ),
    );
  }
}

/// Divider shown after the story row.
class FeedStoryDivider extends StatelessWidget {
  const FeedStoryDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Divider(
          height: 1,
          thickness: 0.33,
          color: AppTheme.primaryColor.withValues(alpha: 0.12),
        ),
      ),
    );
  }
}
