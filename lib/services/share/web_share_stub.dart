/// Stub for Web Share API on non-web platforms
class WebShareHelper {
  /// Check if Web Share API is available
  static bool get isAvailable => false;

  /// Share content using Web Share API
  /// Returns true if share was successful, false otherwise
  static Future<bool> share({
    required String text,
    required String url,
    String? title,
  }) async {
    // Not available on non-web platforms
    return false;
  }
}
