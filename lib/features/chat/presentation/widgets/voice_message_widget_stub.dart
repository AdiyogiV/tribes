/// Web stub - no file caching on web
/// Audio playback uses direct URLs with just_audio
library;

/// Check if running on iOS (always false on web)
bool get isIOS => false;

/// Get cache file path - not supported on web
Future<String?> getCacheFilePath(String url) async => null;

/// Check if cache file exists - always false on web
Future<bool> cacheFileExists(String cachePath) async => false;

/// Create cache directory - no-op on web
Future<void> ensureCacheDirectory(String cachePath) async {}
