import 'package:aurogram/core/theme/app_dimensions.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:aurogram/shared/models/story.dart';
import 'package:aurogram/features/stories/story_service.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/shared/presentation/widgets/avatars/user_avatar.dart';
import 'package:aurogram/shared/presentation/widgets/loaders/skeleton_widgets.dart';
import 'package:aurogram/shared/data/repositories/user_repository.dart';
import 'package:aurogram/core/di/injection.dart';

/// Horizontal strip of story avatars: "Your story" first, then users with active stories.
class StoryRing extends StatefulWidget {
  final VoidCallback onAddStory;
  final void Function(String userId) onViewUserStories;
  final bool forceRefresh;

  const StoryRing({
    super.key,
    required this.onAddStory,
    required this.onViewUserStories,
    this.forceRefresh = false,
  });

  @override
  State<StoryRing> createState() => _StoryRingState();
}

class _StoryRingState extends State<StoryRing> {
  final StoryService _storyService = StoryService();
  List<String> _userIds = [];
  Set<String> _viewedUserIds = {};
  /// Pre-fetched display names keyed by userId — eliminates N+1 Firestore reads.
  Map<String, String> _userNames = {};
  bool _loading = true;
  static const double _avatarSize = 84.0;
  static const double _ringWidth = 102.0;

  @override
  void initState() {
    super.initState();
    _load(forceRefresh: widget.forceRefresh);
  }

  Future<void> _load({bool forceRefresh = false}) async {
    final results = await Future.wait([
      _storyService.getUsersWithStories(forceRefresh: forceRefresh),
      _storyService.getViewedStoryUserIds(),
    ]);
    final userIds = results[0] as List<String>;
    final viewedIds = results[1] as Set<String>;

    // Batch-fetch ALL user names in one parallel call via UserRepository.
    // This replaces N individual Firestore reads with a single batched operation.
    final names = await _batchFetchUserNames(userIds);

    if (mounted) {
      setState(() {
        _userIds = userIds;
        _viewedUserIds = viewedIds;
        _userNames = names;
        _loading = false;
      });

      // Precache story images in background (non-blocking).
      _precacheStories();
    }
  }

  /// Fetch display names for all user IDs in one batch via UserRepository cache.
  Future<Map<String, String>> _batchFetchUserNames(List<String> userIds) async {
    if (userIds.isEmpty) return {};
    try {
      final userRepo = locator<UserRepository>();
      final docs = await userRepo.getUsers(userIds);
      final names = <String, String>{};
      for (final entry in docs.entries) {
        final data = entry.value.data();
        names[entry.key] = data?['name'] as String? ??
            data?['nickname'] as String? ??
            'Story';
      }
      return names;
    } catch (_) {
      return {};
    }
  }

  Future<void> _precacheStories() async {
    if (!mounted || _userIds.isEmpty) return;

    // Precache first 2 images per user concurrently — keeps startup fast
    // while ensuring the most likely-viewed stories are ready.
    final tasks = <Future>[];

    for (final userId in _userIds) {
      if (!mounted) break;

      tasks.add(Future(() async {
        try {
          final stories = await _storyService.getStoriesForUser(userId);
          var cached = 0;
          for (final story in stories) {
            if (!mounted || cached >= 2) break;
            if (story.mediaUrl.isEmpty ||
                story.mediaType != StoryMediaType.image) {
              continue;
            }
            try {
              await precacheImage(
                  CachedNetworkImageProvider(story.mediaUrl), context);
              cached++;
            } catch (_) {}
          }
        } catch (_) {}
      }));
    }

    await Future.wait(tasks);
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    if (_loading) {
      return const StoryRingSkeleton();
    }

    final otherIds = _userIds.where((id) => id != user.uid).toList();
    return SizedBox(
      height: _ringWidth + 20,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemCount: 1 + otherIds.length,
        itemBuilder: (context, index) {
          if (index == 0) {
            return _buildYourStoryItem(user.uid);
          }
          final uid = otherIds[index - 1];
          return _buildUserStoryItem(uid, _userNames[uid] ?? 'Story');
        },
      ),
    );
  }

  Widget _buildYourStoryItem(String currentUid) {
    final hasStories = _userIds.contains(currentUid);
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: GestureDetector(
        onTap: () {
          if (hasStories) {
            widget.onViewUserStories(currentUid);
          } else {
            widget.onAddStory();
          }
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _StoryRingAvatar(
              userId: currentUid,
              size: _avatarSize,
              hasUnviewed: false,
              isAdd: !hasStories,
              hasStories: hasStories,
            ),
            const SizedBox(height: AppDimensions.spacingXs),
            SizedBox(
              width: _ringWidth,
              height: 16,
              child: Center(
                child: Text(
                  'Your story',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w300,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.8),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserStoryItem(String userId, String displayName) {
    final hasUnviewed = !_viewedUserIds.contains(userId);
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: GestureDetector(
        onTap: () => widget.onViewUserStories(userId),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _StoryRingAvatar(
              userId: userId,
              size: _avatarSize,
              hasUnviewed: hasUnviewed,
              isAdd: false,
            ),
            const SizedBox(height: AppDimensions.spacingXs),
            SizedBox(
              width: _ringWidth,
              height: 16,
              child: Center(
                child: Text(
                  displayName,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w300,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.8),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StoryRingAvatar extends StatelessWidget {
  final String userId;
  final double size;
  final bool hasUnviewed;
  final bool isAdd;
  final bool hasStories;

  const _StoryRingAvatar({
    required this.userId,
    required this.size,
    required this.hasUnviewed,
    required this.isAdd,
    this.hasStories = true,
  });

  @override
  Widget build(BuildContext context) {
    // Calculate ring size - overall element size should be consistent
    final ringSize = size + 18.0; // Ring is larger than avatar (102px total)

    // Only show ring decoration when there's a story (like Instagram)
    final showRing = hasStories;

    if (!showRing && isAdd) {
      // When no story, show DP with plus button overlay (no ring) - Instagram style
      // Use ringSize to match overall element size
      return SizedBox(
        width: ringSize,
        height: ringSize,
        child: Stack(
          children: [
            // User's display picture - fills the entire space (ringSize to match overall size)
            UserAvatar(
              userId: userId,
              size: ringSize,
              loadFromFirestore: true,
            ),
            // Plus button overlay on bottom-right edge
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: ringSize * 0.35,
                height: ringSize * 0.35,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.primaryColor,
                  border: Border.all(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    width: 2.5,
                  ),
                ),
                child: Icon(
                  Icons.add,
                  size: ringSize * 0.2,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // When there's a story, show with ring decoration
    return Container(
      width: ringSize,
      height: ringSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: hasUnviewed
            ? LinearGradient(
                colors: [
                  AppTheme.primaryColor,
                  AppTheme.primaryColor.withValues(alpha: 0.6),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: hasUnviewed ? null : Colors.grey.withValues(alpha: 0.3),
      ),
      padding: const EdgeInsets.all(3),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Theme.of(context).scaffoldBackgroundColor,
        ),
        padding: const EdgeInsets.all(2),
        child: UserAvatar(
          userId: userId,
          size: size,
          loadFromFirestore: true,
        ),
      ),
    );
  }
}

