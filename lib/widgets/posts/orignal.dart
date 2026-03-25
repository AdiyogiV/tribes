import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:aurogram/widgets/mainPlayer.dart';
import 'package:aurogram/widgets/textNotePlayer.dart';
import 'package:aurogram/widgets/audioNotePlayer.dart';
import 'package:aurogram/utils/logging/app_logger.dart';

typedef OrignalCallback = void Function(String postId);

/// Original post widget - displays the post this is replying to (shown when swiping right)
class Orignal extends StatefulWidget {
  final String? post;
  final OrignalCallback? onReplySelected;

  const Orignal({
    this.post,
    this.onReplySelected,
    Key? key,
  }) : super(key: key);

  @override
  State<Orignal> createState() => _OrignalState();
}

class _OrignalState extends State<Orignal> {
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

  final CollectionReference postCollection =
      FirebaseFirestore.instance.collection('posts');

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
      final snapshot = await postCollection.doc(widget.post).get();
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
      AppLogger.e('Error fetching original', error: e, data: {'postId': widget.post});
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
    final base = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF0F0F0);
    
    return Container(
      height: 200,
      color: base,
    );
  }
}
