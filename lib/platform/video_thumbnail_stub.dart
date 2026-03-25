/// Stub for video_thumbnail package on web
/// Native thumbnail generation is not supported on web

// Stub for ImageFormat enum
enum ImageFormat {
  JPEG,
  PNG,
  WEBP,
}

/// Stub for VideoThumbnail class
class VideoThumbnail {
  /// Generate thumbnail - not supported on web, returns null
  static Future<String?> thumbnailFile({
    required String video,
    ImageFormat imageFormat = ImageFormat.JPEG,
    int maxWidth = 128,
    int quality = 25,
    int timeMs = 0,
  }) async {
    // Thumbnail generation not supported on web
    return null;
  }

  /// Generate thumbnail data - not supported on web, returns null
  static Future<dynamic> thumbnailData({
    required String video,
    ImageFormat imageFormat = ImageFormat.JPEG,
    int maxWidth = 128,
    int quality = 25,
    int timeMs = 0,
  }) async {
    return null;
  }
}
