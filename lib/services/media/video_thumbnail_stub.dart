import 'dart:typed_data';

/// Stub implementation for non-web platforms
/// This file is used on mobile where native thumbnail generation is used
class VideoThumbnailWeb {
  static Future<Uint8List?> generateThumbnail(String videoSource) async {
    // Not used on mobile - use native get_thumbnail_video package instead
    return null;
  }

  static Future<Uint8List?> generateThumbnailFromFile(dynamic xFile) async {
    // Not used on mobile - use native get_thumbnail_video package instead
    return null;
  }
}
