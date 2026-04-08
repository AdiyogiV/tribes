import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// Check if running on iOS
bool get isIOS => Platform.isIOS;

/// Get cache file path for a URL
Future<String?> getCacheFilePath(String url) async {
  try {
    final cacheDir = await getTemporaryDirectory();
    final filename = 'voice_${url.hashCode.abs()}.m4a';
    return '${cacheDir.path}/voice_cache/$filename';
  } catch (_) {
    return null;
  }
}

/// Check if cache file exists
Future<bool> cacheFileExists(String cachePath) async {
  try {
    return File(cachePath).existsSync();
  } catch (_) {
    return false;
  }
}

/// Create cache directory if it doesn't exist
Future<void> ensureCacheDirectory(String cachePath) async {
  try {
    final file = File(cachePath);
    await file.parent.create(recursive: true);
  } catch (_) {
    // Ignore errors
  }
}
