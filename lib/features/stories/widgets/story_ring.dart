import 'package:aurogram/core/theme/app_dimensions.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:aurogram/shared/models/story.dart';
import 'package:aurogram/features/stories/story_service.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/shared/presentation/widgets/avatars/user_avatar.dart';
import 'package:aurogram/shared/presentation/widgets/loaders/skeleton_widgets.dart';

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
  bool _loading = true;
  bool _precaching = false;
  static const double _avatarSize = 84.0; // Increased size
  static const double _ringWidth =
      102.0; // Increased size (includes gradient border)

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
    if (mounted) {
      setState(() {
        _userIds = results[0] as List<String>;
        _viewedUserIds = results[1] as Set<String>;
        _loading = false;
        _precaching = true; // Start precaching indicator
      });

      // Precache stories for instant loading (Instagram-style)
      await _precacheStories();

      if (mounted) {
        setState(() {
          _precaching = false; // Precaching complete
        });
      }
    }
  }

  Future<void> _precacheStories() async {
    if (!mounted || _userIds.isEmpty) return;

    // Precache ALL users' stories aggressively for instant viewing
    final allPrecacheTasks = <Future>[];

    for (final userId in _userIds) {
      if (!mounted) break;

      final task = Future(() async {
        try {
          final stories = await _storyService.getStoriesForUser(userId);

          // Precache all images for this user - ensure FULL download
          for (final story in stories) {
            if (!mounted) break;
            if (story.mediaUrl.isEmpty ||
                story.mediaType != StoryMediaType.image) {
              continue;
            }

            try {
              // Use CachedNetworkImageProvider and precache
              final provider = CachedNetworkImageProvider(story.mediaUrl);
              await precacheImage(provider, context);

              // Small delay to ensure cache write completes
              await Future.delayed(const Duration(milliseconds: 10));
            } catch (e) {
              // Silent fail - continue with other images
            }
          }
        } catch (e) {
          // Silent fail for this user
        }
      });

      allPrecacheTasks.add(task);
    }

    // Wait for ALL users' stories to be FULLY cached
    await Future.wait(allPrecacheTasks);
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    if (_loading) {
      return const StoryRingSkeleton();
    }

    final otherIds = _userIds.where((id) => id != user.uid).toList();
    // Height: ring + spacing (4px) + text (16px) = exact content height, no extra padding
    return AnimatedOpacity(
      opacity: _precaching ? 0.5 : 1.0,
      duration: const Duration(milliseconds: 300),
      child: SizedBox(
        height: _ringWidth +
            20, // ring (102) + spacing (4) + text (16) = 122px, no extra padding
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          itemCount: 1 + otherIds.length,
          itemBuilder: (context, index) {
            if (index == 0) {
              return _buildYourStoryItem(user.uid);
            }
            return _buildUserStoryItem(otherIds[index - 1]);
          },
        ),
      ),
    );
  }

  Widget _buildYourStoryItem(String currentUid) {
    final hasStories = _userIds.contains(currentUid);
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: GestureDetector(
        onTap: () {
          // Don't allow opening stories while precaching
          if (_precaching) return;

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

  Widget _buildUserStoryItem(String userId) {
    final hasUnviewed = !_viewedUserIds.contains(userId);
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: GestureDetector(
        onTap: _precaching ? null : () => widget.onViewUserStories(userId),
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
                child: _UserNameLabel(userId: userId),
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

class _UserNameLabel extends StatelessWidget {
  final String userId;

  const _UserNameLabel({required this.userId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _loadUserData(userId),
      builder: (context, snapshot) {
        final name = snapshot.data?['name'] as String? ??
            snapshot.data?['nickname'] as String? ??
            'Story';
        return Text(
          name,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w300,
            color:
                Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        );
      },
    );
  }

  Future<Map<String, dynamic>?> _loadUserData(String uid) async {
    try {
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      return doc.data();
    } catch (_) {
      return null;
    }
  }
}
