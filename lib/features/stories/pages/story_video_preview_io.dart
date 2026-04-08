import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:aurogram/core/logging/app_logger.dart';

/// Mobile: write bytes to temp file and create video controller.
/// Returns (controller, fileToDelete). Caller must dispose controller and call deleteVideoPreviewFile(fileToDelete).
Future<(VideoPlayerController?, Object?)> createVideoControllerFromBytes(Uint8List bytes) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/story_preview_${DateTime.now().millisecondsSinceEpoch}.mp4');
  await file.writeAsBytes(bytes);
  final controller = VideoPlayerController.file(file);
  await controller.initialize();
  return (controller, file);
}

void deleteVideoPreviewFile(Object? file) {
  if (file is File) {
    try {
      file.deleteSync();
    } catch (_) {
      AppLogger.w('StoryVideoPreview: failed to delete temp preview file', category: LogCategory.general);
    }
  }
}
