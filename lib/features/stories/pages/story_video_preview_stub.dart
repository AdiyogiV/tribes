import 'dart:typed_data';
import 'package:video_player/video_player.dart';

/// Web stub: video preview is not supported on web.
Future<(VideoPlayerController?, Object?)> createVideoControllerFromBytes(
    Uint8List bytes) async {
  return (null, null);
}

void deleteVideoPreviewFile(Object? file) {
  // No-op on web
}
