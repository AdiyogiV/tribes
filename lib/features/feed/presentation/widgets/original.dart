import 'package:flutter/material.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:aurogram/core/di/injection.dart';
import 'package:aurogram/features/feed/data/datasources/post_db_service.dart';
import 'package:aurogram/shared/presentation/widgets/player/main_player.dart';
import 'package:aurogram/shared/presentation/widgets/player/text_note_player.dart';
import 'package:aurogram/shared/presentation/widgets/player/audio_note_player.dart';
import 'package:aurogram/shared/presentation/widgets/player/image_note_player.dart';
import 'package:aurogram/core/logging/app_logger.dart';

typedef OriginalCallback = void Function(String postId);

/// Original post widget - displays the post this is replying to (shown when swiping right)
class Original extends StatefulWidget {
  final String? post;
  final OriginalCallback? onReplySelected;

  const Original({
    this.post,
    this.onReplySelected,
    super.key,
  });

  @override
  State<Original> createState() => _OriginalState();
}

class _OriginalState extends State<Original> {
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

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (widget.post == null) {
      if (mounted) setState(() => dataloaded = true);
      return;
    }

    try {
      final snapshot = await locator<PostDbService>().getPost(widget.post);
      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>?;
        if (data != null) {
          author = data['author'] as String?;
          video = data['video'] as String?;
          thumbnail = data['thumbnail'] as String?; // Load thumbnail
          title = data['title'] as String?;
          space = data['space'] as String?;
          timestamp = data['timestamp'] as Timestamp?;
          link = data['link'] as String?;
          content = data['content'] as String?;
          postType = data['postType'] as String? ?? 'video';
          audioUrl = data['audioUrl'] as String?;
          durationInSeconds = data['duration'] as int?;
        }
      }
    } catch (e) {
      AppLogger.e('Error fetching original',
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
        if (widget.onReplySelected != null && widget.post != null) {
          widget.onReplySelected!(widget.post!);
        }
      },
      child: _buildContent(),
    );
  }

  Widget _buildContent() {
    // Label is now handled by PostSwitcher for cleaner hierarchy
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
    );
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
