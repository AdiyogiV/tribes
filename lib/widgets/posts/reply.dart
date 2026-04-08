import 'package:flutter/material.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:aurogram/services/data/post_db_service.dart';
import 'package:aurogram/utils/dependency_injection.dart';
import 'package:aurogram/widgets/player/main_player.dart';
import 'package:aurogram/widgets/player/text_note_player.dart';
import 'package:aurogram/widgets/player/audio_note_player.dart';
import 'package:aurogram/widgets/player/image_note_player.dart';
import 'package:aurogram/utils/logging/app_logger.dart';
import 'package:aurogram/widgets/posts/reply_indicator.dart';
import 'package:aurogram/services/user_service.dart';

typedef ReplyCallback = void Function(String postId);

/// Reply widget - displays a reply to a post (shown when swiping left)
class Reply extends StatefulWidget {
  final String post;
  final ReplyCallback? onReplySelected;

  const Reply({
    required this.post,
    this.onReplySelected,
    super.key,
  });

  @override
  State<Reply> createState() => _ReplyState();
}

class _ReplyState extends State<Reply> {
  String? author;
  String? space;
  bool dataloaded = false;
  String? video;
  String? thumbnail; // Added thumbnail
  String? title;
  String? link;
  String? content;
  String? postType;
  String? audioUrl;
  int? durationInSeconds;
  Timestamp? timestamp;
  String? _replyTo; // Parent post ID if this is a reply
  String? _parentAuthorName; // Immediate parent author name
  int _parentChainCount = 0; // Total count of parents in the chain
  List<DocumentSnapshot>?
      _parentPostSnapshots; // Parent post documents (loaded by Reply, passed to ReplyIndicator)

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final snapshot = await locator<PostDbService>().getPost(widget.post);

      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>?;
        if (data != null) {
          // Check for replyTo BEFORE parsing to load parents in parallel
          final replyToId = data['replyTo'] as String?;

          // Load parent posts in parallel with parsing if this is a reply
          final parentPostsFuture = (replyToId != null && replyToId.isNotEmpty)
              ? _loadParentPostsData(replyToId)
              : Future.value(null);

          author = data['author'] as String?;
          video = data['video'] as String?;
          thumbnail = data['thumbnail'] as String?; // Load thumbnail
          title = data['title'] as String?;
          link = data['link'] as String?;
          content = data['content'] as String?;
          postType = data['postType'] as String? ?? 'video';
          space = data['space'] as String?;
          timestamp = data['timestamp'] as Timestamp?;
          audioUrl = data['audioUrl'] as String?;
          durationInSeconds = data['duration'] as int?;
          _replyTo = replyToId;

          // Wait for parent posts to finish loading (loaded in parallel with parsing)
          if (replyToId != null && replyToId.isNotEmpty) {
            await parentPostsFuture;
          }
        }
      } else {
        AppLogger.w('Reply not found', data: {'postId': widget.post});
      }
    } catch (e) {
      AppLogger.e('Error fetching reply',
          error: e, data: {'postId': widget.post});
    }

    if (mounted) {
      setState(() => dataloaded = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!dataloaded) {
      return _buildLoading();
    }

    // Simple content display - card styling handled by PostSwitcher
    return GestureDetector(
      onDoubleTap: () {
        if (widget.onReplySelected != null) {
          widget.onReplySelected!(widget.post);
        }
      },
      child: _buildContent(),
    );
  }

  Widget _buildContent() {
    // Label is now handled by PostSwitcher for cleaner hierarchy
    // Build reply indicator if this is a reply
    // Same pattern as PostReplies: Reply widget loads data, passes to ReplyIndicator
    final replyIndicator = _replyTo != null && _replyTo!.isNotEmpty
        ? ReplyIndicator(
            parentPostId: _replyTo!,
            parentAuthorName: _parentAuthorName,
            additionalParentsCount:
                _parentChainCount > 0 ? _parentChainCount : null,
            initialParentPosts:
                _parentPostSnapshots, // Pass loaded snapshots (like initialReplies)
          )
        : null;

    if (postType == 'text' && content != null && content!.isNotEmpty) {
      return TextNotePlayer(
        postId: widget.post,
        space: space,
        author: author,
        content: content!,
        title: title,
        link: link,
        timestamp: timestamp,
        hasContentBelow: widget.onReplySelected != null,
        contentAfterHeader: replyIndicator,
      );
    }

    if (postType == 'audio' && audioUrl != null && durationInSeconds != null) {
      return AudioNotePlayer(
        postId: widget.post,
        space: space,
        author: author,
        audioUrl: audioUrl!,
        durationInSeconds: durationInSeconds!,
        title: title,
        timestamp: timestamp,
        hasContentBelow: widget.onReplySelected != null,
        contentAfterHeader: replyIndicator,
      );
    }

    if (postType == 'image' && video != null && video!.isNotEmpty) {
      return ImageNotePlayer(
        postId: widget.post,
        space: space,
        author: author,
        imageUrl: video!,
        title: title,
        link: link,
        timestamp: timestamp,
        hasContentBelow: widget.onReplySelected != null,
        contentAfterHeader: replyIndicator,
      );
    }

    return MainPlayer(
      postId: widget.post,
      space: space,
      author: author,
      videoUrl: video,
      thumbnail: thumbnail,
      title: title,
      link: link,
      timestamp: timestamp,
      hasContentBelow: widget.onReplySelected != null,
      contentAfterHeader: replyIndicator,
    );
  }

  /// Load parent posts data - called with replyToId to start loading immediately
  Future<void> _loadParentPostsData(String replyToId) async {
    if (!mounted) return;

    try {
      final postDbService = locator<PostDbService>();

      // Load immediate parent first
      final parentSnapshot = await postDbService.getPost(replyToId);
      if (!mounted || !parentSnapshot.exists) return;

      final parentData = parentSnapshot.data() as Map<String, dynamic>?;
      final parentAuthorId = parentData?['author'] as String?;

      // Load author name (non-blocking, updates when ready)
      if (parentAuthorId != null) {
        final userService = locator<UserService>();
        userService.getUserDisplayName(parentAuthorId).then((name) {
          if (mounted) {
            setState(() {
              _parentAuthorName = name;
            });
          }
        }).catchError((_) {
          // Ignore errors
        });
      }

      // Build parent chain and load all parent posts
      final parentSnapshots = <DocumentSnapshot>[parentSnapshot];
      int chainCount = 0;
      String? currentParentId = parentData?['replyTo'] as String?;
      const maxChainDepth = 10; // Safety limit

      while (currentParentId != null &&
          currentParentId.isNotEmpty &&
          mounted &&
          chainCount < maxChainDepth) {
        chainCount++;
        try {
          final ancestorSnapshot = await postDbService.getPost(currentParentId);
          if (!ancestorSnapshot.exists) break;
          parentSnapshots.add(ancestorSnapshot);
          final ancestorData = ancestorSnapshot.data() as Map<String, dynamic>?;
          currentParentId = ancestorData?['replyTo'] as String?;
        } catch (e) {
          break;
        }
      }

      if (mounted) {
        setState(() {
          _parentChainCount = chainCount;
          // Store snapshots in order: oldest first, immediate parent last
          _parentPostSnapshots = parentSnapshots.reversed.toList();
        });
      }
    } catch (e) {
      AppLogger.w('Error loading parent posts in Reply',
          data: {'parentPostId': replyToId, 'error': e.toString()});
    }
  }

  /// Clean skeleton for loading - no spinner
  /// Card styling (border radius, shadows) handled by PostSwitcher
  Widget _buildLoading() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? AppTheme.darkElevatedSurface : const Color(0xFFF0F0F0);

    return Container(
      height: 200,
      color: base,
    );
  }
}
