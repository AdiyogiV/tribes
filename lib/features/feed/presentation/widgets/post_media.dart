import 'package:flutter/material.dart';
import 'package:aurogram/shared/presentation/widgets/player/main_player.dart';
import 'package:aurogram/shared/presentation/widgets/player/text_note_player.dart';
import 'package:aurogram/shared/presentation/widgets/player/audio_note_player.dart';
import 'package:aurogram/shared/presentation/widgets/player/image_note_player.dart';
import 'package:aurogram/features/feed/presentation/widgets/post_data.dart';
import 'package:aurogram/services/batch_data_loader.dart';

// =============================================================================
// POST MEDIA BUILDER
// =============================================================================

/// Builds the appropriate media widget based on the post type.
///
/// Returns the correct player widget (TextNotePlayer, AudioNotePlayer,
/// ImageNotePlayer, or MainPlayer) for the given [displayData].
Widget buildPostMedia({
  required PostData displayData,
  required String? contentPostId,
  required String? displayAuthor,
  required bool isProfile,
  required Widget? contentAfterHeader,
  required UserData? displayUserData,
  required SpaceData? spaceData,
  double? imageAspectRatio,
  int? itemIndex,
  int? itemDepth,
  bool enableVideoAutoplay = false,
  bool prewarmVideo = false,
}) {
  // Header and toolbar are rendered outside, so suppress them in sub-players.
  const showHeader = false;
  const showToolbar = false;

  if (displayData.postType == 'text' &&
      displayData.content != null &&
      displayData.content!.isNotEmpty) {
    return TextNotePlayer(
      postId: contentPostId,
      space: displayData.space,
      author: displayAuthor,
      content: displayData.content!,
      title: displayData.title,
      link: displayData.link,
      timestamp: displayData.timestamp,
      isProfilePost: isProfile,
      contentAfterHeader: contentAfterHeader,
      showHeader: showHeader,
      showToolbar: showToolbar,
      userData: displayUserData,
      spaceData: spaceData,
      quotedPostData: displayData.quotedPostData,
      quotedPostId: displayData.quotedPostId,
    );
  } else if (displayData.postType == 'audio' &&
      displayData.audioUrl != null &&
      displayData.durationInSeconds != null) {
    return AudioNotePlayer(
      postId: contentPostId,
      space: displayData.space,
      author: displayAuthor,
      audioUrl: displayData.audioUrl!,
      durationInSeconds: displayData.durationInSeconds!,
      title: displayData.title,
      timestamp: displayData.timestamp,
      isProfilePost: isProfile,
      contentAfterHeader: contentAfterHeader,
      showHeader: showHeader,
      showToolbar: showToolbar,
      userData: displayUserData,
      spaceData: spaceData,
    );
  } else if (displayData.postType == 'image' &&
      displayData.video != null &&
      displayData.video!.isNotEmpty) {
    return ImageNotePlayer(
      postId: contentPostId,
      space: displayData.space,
      author: displayAuthor,
      imageUrl: displayData.video!,
      title: displayData.title,
      link: displayData.link,
      timestamp: displayData.timestamp,
      isProfilePost: isProfile,
      contentAfterHeader: contentAfterHeader,
      showHeader: showHeader,
      showToolbar: showToolbar,
      userData: displayUserData,
      spaceData: spaceData,
      aspectRatio: imageAspectRatio,
    );
  } else {
    return MainPlayer(
      postId: contentPostId,
      space: displayData.space,
      author: displayAuthor,
      videoUrl: displayData.video,
      uploading: displayData.uploading ?? false,
      title: displayData.title,
      link: displayData.link,
      thumbnail: displayData.thumbnail,
      pageIndex: itemIndex,
      pageDepth: itemDepth,
      isProfilePost: isProfile,
      timestamp: displayData.timestamp,
      enableVideoAutoplay: enableVideoAutoplay,
      prewarmVideo: prewarmVideo &&
          displayData.video != null &&
          displayData.video!.isNotEmpty,
      contentAfterHeader: contentAfterHeader,
      showHeader: showHeader,
      showToolbar: showToolbar,
      showCaption: false, // we render caption once in the parent
      userData: displayUserData,
      spaceData: spaceData,
    );
  }
}
