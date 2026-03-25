import 'dart:async';
import 'dart:io';
import 'package:aurogram/utils/logging/app_logger.dart';
import 'package:aurogram/utils/memory/memory_manager.dart';
import 'package:aurogram/utils/memory/cache_optimizer.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Manages in-memory and disk caches for the application
class CacheService {
  final MemoryManager memoryManager;

  // File cache manager for backward compatibility
  late final DefaultCacheManager _cacheManager;

  // In-memory caches with strong typing for better performance
  final Map<String, dynamic> _memoryCache = {};
  final Map<String, DateTime> _memoryCacheExpiry = {};

  // Categorized caches for better management
  final Map<String, Map<String, dynamic>> _categorizedCache = {};
  final Map<String, int> _categorySize = {};

  // Cache statistics
  int _cacheHits = 0;
  int _cacheMisses = 0;

  // Memory cache specifically for images with LRU tracking
  final Map<String, File> _imageCache = {};
  final Map<String, DateTime> _imageCacheExpiry = {};
  final List<String> _imageLRUList = []; // Track least recently used
  static const int _maxImageCacheSize = 35; // Maximum number of images to keep

  CacheService({required this.memoryManager}) {
    // Initialize cache manager for backward compatibility
    _cacheManager = DefaultCacheManager();

    // Register with memory manager for cleanup notifications
    memoryManager.registerCache(
        'main_cache', 500); // Rough estimate of size in KB

    // Register memory pressure callbacks
    memoryManager.addLowMemoryCallback(() {
      // Clear image memory cache when memory is low
      cleanupImageCache();

      // Also clear any non-essential cache categories
      _cleanNonEssentialCategories();
    });

    AppLogger.d('CacheService initialized with cache coordination',
        category: LogCategory.performance);
  }

  // Last cleanup timestamp to prevent excessive cleanup
  DateTime? _lastCleanup;
  static const Duration _minCleanupInterval = Duration(minutes: 2);

  /// Store value in memory cache with expiry time
  Future<void> set(String key, dynamic value,
      {Duration? expiry, String? category}) async {
    _memoryCache[key] = value;

    if (expiry != null) {
      _memoryCacheExpiry[key] = DateTime.now().add(expiry);
    }

    // Handle categorized caches
    if (category != null) {
      _categorizedCache[category] ??= {};
      _categorySize[category] ??= 0;

      // Check if we're adding a new item to the category
      if (!_categorizedCache[category]!.containsKey(key)) {
        _categorySize[category] = (_categorySize[category] ?? 0) + 1;
      }

      _categorizedCache[category]![key] = value;

      // Enforce category size limits
      _enforceCategoryLimit(category);
    }

    // Try to store on disk for persistent items
    if (!kIsWeb && expiry != null && expiry.inMinutes > 30) {
      try {
        await _writeToFile(key, value);
      } catch (e) {
        AppLogger.w('Failed to write cache to disk',
            category: LogCategory.performance,
            data: {'key': key, 'error': e.toString()});
      }
    }
  }

  /// Enforce size limits on categorized caches
  void _enforceCategoryLimit(String category) {
    final maxSize = CacheOptimizer.getMaxItemsForCategory(category);

    if ((_categorySize[category] ?? 0) > maxSize) {
      // We need to evict items
      final itemsToRemove = _categorySize[category]! - maxSize;

      if (itemsToRemove > 0 && _categorizedCache.containsKey(category)) {
        final keys =
            _categorizedCache[category]!.keys.take(itemsToRemove).toList();

        for (final key in keys) {
          _categorizedCache[category]!.remove(key);
          // Also remove from main cache if present
          _memoryCache.remove(key);
          _memoryCacheExpiry.remove(key);
        }

        _categorySize[category] = maxSize;

        AppLogger.d('Evicted $itemsToRemove items from $category cache',
            category: LogCategory.performance);
      }
    }
  }

  /// Clean non-essential cache categories under memory pressure
  void _cleanNonEssentialCategories() {
    // Define essential categories that should be preserved
    final essentialCategories = {'users', 'current_user'};

    // Clean non-essential categories
    for (final category in _categorizedCache.keys.toList()) {
      if (!essentialCategories.contains(category)) {
        _categorizedCache[category]?.clear();
        _categorySize[category] = 0;

        AppLogger.d('Cleared non-essential cache category: $category',
            category: LogCategory.performance);
      }
    }
  }

  /// Get value from cache, returns null if not found or expired
  Future<dynamic> get(String key, {String? category}) async {
    // For categorized lookup
    if (category != null && _categorizedCache.containsKey(category)) {
      final value = _categorizedCache[category]![key];
      if (value != null) {
        _cacheHits++;
        return value;
      }
    }

    // Check if we have it in memory first
    if (_memoryCache.containsKey(key)) {
      // Check if expired
      if (_memoryCacheExpiry.containsKey(key) &&
          CacheOptimizer.shouldEvictBasedOnAge(_memoryCacheExpiry[key]!)) {
        // Expired, remove from cache
        _memoryCache.remove(key);
        _memoryCacheExpiry.remove(key);

        // Also remove from category if present
        if (category != null && _categorizedCache.containsKey(category)) {
          _categorizedCache[category]!.remove(key);
          if (_categorySize.containsKey(category)) {
            _categorySize[category] = (_categorySize[category] ?? 1) - 1;
          }
        }

        _cacheMisses++;
      } else {
        // Valid cache hit
        _cacheHits++;
        return _memoryCache[key];
      }
    }

    // If not in memory cache, try to load from disk (if not on web)
    if (!kIsWeb) {
      try {
        final value = await _readFromFile(key);
        if (value != null) {
          // Found on disk, store in memory for next time
          _memoryCache[key] = value;

          // Also store in category if specified
          if (category != null) {
            _categorizedCache[category] ??= {};
            _categorizedCache[category]![key] = value;
            _categorySize[category] = (_categorySize[category] ?? 0) + 1;
          }

          _cacheHits++;
          return value;
        }
      } catch (e) {
        // Ignore disk cache errors, treat as cache miss
      }
    }

    _cacheMisses++;
    return null;
  }

  /// Remove item from cache
  Future<void> remove(String key, {String? category}) async {
    _memoryCache.remove(key);
    _memoryCacheExpiry.remove(key);

    // Remove from category if specified
    if (category != null && _categorizedCache.containsKey(category)) {
      _categorizedCache[category]!.remove(key);
      if (_categorySize.containsKey(category)) {
        _categorySize[category] = (_categorySize[category] ?? 1) - 1;
      }
    }

    // Also remove from disk if possible
    if (!kIsWeb) {
      try {
        final cacheDir = await _getCacheDir();
        final file = File('${cacheDir.path}/$key');
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        // Ignore disk errors
      }
    }
  }

  /// Clear all cached items
  Future<void> clear() async {
    _memoryCache.clear();
    _memoryCacheExpiry.clear();
    _imageCache.clear();
    _imageCacheExpiry.clear();
    _imageLRUList.clear();
    _categorizedCache.clear();
    _categorySize.clear();

    // Clear disk cache too
    if (!kIsWeb) {
      try {
        final cacheDir = await _getCacheDir();
        if (await cacheDir.exists()) {
          await cacheDir.delete(recursive: true);
          await cacheDir.create();
        }
      } catch (e) {
        AppLogger.w('Failed to clear disk cache',
            category: LogCategory.performance, data: {'error': e.toString()});
      }
    }

    // Clear the flutter_cache_manager cache too
    try {
      await _cacheManager.emptyCache();
    } catch (e) {
      AppLogger.w('Failed to clear flutter_cache_manager cache',
          category: LogCategory.performance, data: {'error': e.toString()});
    }

    AppLogger.i('Cache cleared',
        category: LogCategory.performance,
        data: {'hits': _cacheHits, 'misses': _cacheMisses});

    // Reset statistics
    _cacheHits = 0;
    _cacheMisses = 0;
  }

  /// Clean up image cache using LRU algorithm
  void cleanupImageCache() {
    try {
      // If we're within limits, no need to clean
      if (_imageCache.length <= _maxImageCacheSize) return;

      // Remove oldest items first using LRU list
      final itemsToRemove = _imageCache.length - _maxImageCacheSize;

      if (itemsToRemove > 0 && _imageLRUList.isNotEmpty) {
        final keysToRemove = _imageLRUList.take(itemsToRemove).toList();

        for (final key in keysToRemove) {
          _imageCache.remove(key);
          _imageCacheExpiry.remove(key);
          _imageLRUList.remove(key);
        }

        AppLogger.d('Removed $itemsToRemove oldest images from cache',
            category: LogCategory.performance);
      } else {
        // Fallback: clear entire cache if LRU tracking is broken
        _imageCache.clear();
        _imageCacheExpiry.clear();
        _imageLRUList.clear();
      }

      // Do not clear disk cache here. Low-memory pertains to RAM; clearing
      // disk cache can invalidate file handles currently used by widgets.
      // We only clear in-memory structures here.
    } catch (e) {
      AppLogger.w('Error clearing image cache',
          category: LogCategory.performance, data: {'error': e.toString()});
    }
  }

  /// Add image to cache with LRU tracking
  void cacheImage(String key, File image) {
    // Add to image cache
    _imageCache[key] = image;
    _imageCacheExpiry[key] = DateTime.now().add(const Duration(hours: 1));

    // Update LRU tracking
    _imageLRUList.remove(key); // Remove if exists
    _imageLRUList.add(key); // Add to end (most recently used)

    // Check if we need to clean up
    if (_imageCache.length > _maxImageCacheSize) {
      cleanupImageCache();
    }
  }

  /// Prune expired items from cache
  Future<void> pruneCache() async {
    // Rate limit cleanup
    if (_lastCleanup != null &&
        DateTime.now().difference(_lastCleanup!) < _minCleanupInterval) {
      return;
    }
    _lastCleanup = DateTime.now();

    final now = DateTime.now();
    final expiredKeys = _memoryCacheExpiry.entries
        .where((entry) => entry.value.isBefore(now))
        .map((entry) => entry.key)
        .toList();

    // Remove expired items
    for (final key in expiredKeys) {
      _memoryCache.remove(key);
      _memoryCacheExpiry.remove(key);

      // Also remove from any categories
      for (final category in _categorizedCache.keys) {
        if (_categorizedCache[category]!.containsKey(key)) {
          _categorizedCache[category]!.remove(key);
          if (_categorySize.containsKey(category)) {
            _categorySize[category] = (_categorySize[category] ?? 1) - 1;
          }
        }
      }
    }

    // Also prune image cache
    final expiredImageKeys = _imageCacheExpiry.entries
        .where((entry) => entry.value.isBefore(now))
        .map((entry) => entry.key)
        .toList();

    for (final key in expiredImageKeys) {
      _imageCache.remove(key);
      _imageCacheExpiry.remove(key);
      _imageLRUList.remove(key);
    }

    if (expiredKeys.isNotEmpty || expiredImageKeys.isNotEmpty) {
      AppLogger.d(
          'Cache cleanup: ${expiredKeys.length} items, ${expiredImageKeys.length} images',
          category: LogCategory.performance);
    }
  }

  /// Get the cache directory for persistent storage
  Future<Directory> _getCacheDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final cacheDir = Directory('${appDir.path}/app_cache');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    return cacheDir;
  }

  /// Write data to disk cache
  Future<void> _writeToFile(String key, dynamic value) async {
    if (value == null) return;

    final cacheDir = await _getCacheDir();
    final file = File('${cacheDir.path}/$key');

    // Different handling based on value type
    if (value is String) {
      await file.writeAsString(value);
    } else if (value is Map || value is List) {
      // Convert to JSON string first
      final jsonStr = value.toString();
      await file.writeAsString(jsonStr);
    } else {
      throw UnsupportedError('Cannot cache value of type ${value.runtimeType}');
    }
  }

  /// Read data from disk cache
  Future<dynamic> _readFromFile(String key) async {
    final cacheDir = await _getCacheDir();
    final file = File('${cacheDir.path}/$key');

    if (!await file.exists()) return null;

    // Read as string, caller needs to handle parsing
    return await file.readAsString();
  }

  /// Get cache statistics
  Map<String, dynamic> getStats() {
    return {
      'memory_items': _memoryCache.length,
      'hits': _cacheHits,
      'misses': _cacheMisses,
      'hit_ratio': _cacheHits + _cacheMisses > 0
          ? _cacheHits / (_cacheHits + _cacheMisses)
          : 0,
    };
  }

  /// Dispose cache resources
  void dispose() {
    // No need to cancel timer - unified coordinator handles this
    memoryManager.unregisterCache('main_cache');
    _memoryCache.clear();
    _memoryCacheExpiry.clear();
    _imageCacheExpiry.clear();
    _imageCache.clear();
    _imageLRUList.clear();
    _categorizedCache.clear();
    _categorySize.clear();

    AppLogger.d('CacheService disposed successfully',
        category: LogCategory.performance);
  }

  // Legacy methods for backward compatibility

  /// Get file from cache
  Future<File?> getFile(String? url,
      {String? cacheKey, bool forceDownload = false}) async {
    if (url == null || url.isEmpty) return null;

    // Create a stable cacheKey if not provided
    final effectiveCacheKey = cacheKey ?? url; // use full URL for uniqueness

    // Handle local file paths directly
    if (url.startsWith('/') || url.startsWith('file:')) {
      try {
        final file = File(url.startsWith('file:') ? url.substring(5) : url);
        if (await file.exists()) {
          return file;
        }
        AppLogger.w('Local file does not exist',
            category: LogCategory.performance, data: {'path': url});
        return null;
      } catch (e) {
        AppLogger.w('Error accessing local file',
            category: LogCategory.performance,
            data: {'path': url, 'error': e.toString()});
        return null;
      }
    }

    try {
      // Check if we have a stable version in memory cache first (unless forced redownload)
      if (!forceDownload && _imageCache.containsKey(effectiveCacheKey)) {
        final cachedFile = _imageCache[effectiveCacheKey]!;
        if (await cachedFile.exists()) {
          // Validate header to avoid passing corrupt files
          final isValid = await _isValidImageFile(cachedFile);
          if (!isValid) {
            _imageCache.remove(effectiveCacheKey);
            _imageCacheExpiry.remove(effectiveCacheKey);
            try {
              await cachedFile.delete();
            } catch (_) {}
          } else {
            // Refresh expiry time
            _imageCacheExpiry[effectiveCacheKey] =
                DateTime.now().add(Duration(days: 7));
            return cachedFile;
          }
        }
      }

      // First check if file exists in cache (unless forced redownload)
      if (!forceDownload) {
        final fileInfo =
            await _cacheManager.getFileFromCache(effectiveCacheKey);
        if (fileInfo != null) {
          // Verify file actually exists
          try {
            if (await fileInfo.file.exists()) {
              // Validate header to ensure it's an actual image
              final isValid = await _isValidImageFile(fileInfo.file);
              if (!isValid) {
                // Delete corrupted file to allow future re-downloads
                try {
                  await fileInfo.file.delete();
                } catch (_) {}
              } else {
                // Store in memory cache for faster access next time
                _imageCache[effectiveCacheKey] = fileInfo.file;
                _imageCacheExpiry[effectiveCacheKey] =
                    DateTime.now().add(Duration(days: 7));

                // Check if memory cache is getting too large
                if (_imageCache.length > _maxImageCacheSize) {
                  // Remove oldest items
                  final oldestKeys = _imageCacheExpiry.entries.toList()
                    ..sort((a, b) => a.value.compareTo(b.value));

                  if (oldestKeys.isNotEmpty) {
                    final keyToRemove = oldestKeys.first.key;
                    _imageCache.remove(keyToRemove);
                    _imageCacheExpiry.remove(keyToRemove);
                  }
                }

                return fileInfo.file;
              }
            }
          } catch (fileError) {
            AppLogger.w('Cached file exists but cannot be accessed',
                category: LogCategory.performance,
                data: {'url': url, 'error': fileError.toString()});
            // Continue to download since file access failed
          }
        }
      }

      // If not in cache or file couldn't be accessed, download it
      try {
        // Use the stable key for downloading and caching
        final file =
            await _cacheManager.downloadFile(url, key: effectiveCacheKey);

        // Verify downloaded file exists and is readable
        if (await file.file.exists()) {
          try {
            // Test if file can be read - this catches invalid files
            await file.file.length();

            // Additional validation: ensure file appears to be a valid image
            final isValid = await _isValidImageFile(file.file);
            if (!isValid) {
              // Delete invalid file so future attempts can re-download
              try {
                await file.file.delete();
              } catch (_) {}
              return null;
            }

            // Store in memory cache
            _imageCache[effectiveCacheKey] = file.file;
            _imageCacheExpiry[effectiveCacheKey] =
                DateTime.now().add(Duration(days: 7));

            return file.file;
          } catch (readError) {
            AppLogger.w('Downloaded file exists but cannot be read',
                category: LogCategory.performance,
                data: {'url': url, 'error': readError.toString()});

            // Delete corrupted file to allow future re-downloads
            try {
              await file.file.delete();
            } catch (_) {}

            return null;
          }
        }
        return null;
      } catch (downloadError) {
        // Fallback to old method if downloadFile failed (for backward compatibility)
        try {
          final file = await _cacheManager.getSingleFile(url);
          if (await file.exists()) {
            // Validate before caching
            final isValid = await _isValidImageFile(file);
            if (!isValid) {
              try {
                await file.delete();
              } catch (_) {}
            } else {
              // Store in our cache for next time
              _imageCache[effectiveCacheKey] = file;
              _imageCacheExpiry[effectiveCacheKey] =
                  DateTime.now().add(Duration(days: 7));
              return file;
            }
          }
        } catch (_) {
          // Ignore errors from fallback
        }

        AppLogger.w('Error downloading file',
            category: LogCategory.performance,
            data: {'url': url, 'error': downloadError.toString()});
        return null;
      }
    } catch (e) {
      AppLogger.w('Error getting file from cache',
          category: LogCategory.performance,
          data: {'url': url, 'error': e.toString()});
      return null;
    }
  }

  /// Get file only if already cached (memory or disk); never downloads.
  Future<File?> getFileIfCached(String? url, {String? cacheKey}) async {
    if (url == null || url.isEmpty) return null;

    // Create a stable cacheKey if not provided
    final effectiveCacheKey = cacheKey ?? url; // use full URL for uniqueness

    // Check memory cache first
    if (_imageCache.containsKey(effectiveCacheKey)) {
      final cachedFile = _imageCache[effectiveCacheKey]!;
      try {
        if (await cachedFile.exists()) {
          final isValid = await _isValidImageFile(cachedFile);
          if (!isValid) {
            _imageCache.remove(effectiveCacheKey);
            _imageCacheExpiry.remove(effectiveCacheKey);
          } else {
            // Refresh expiry time
            _imageCacheExpiry[effectiveCacheKey] =
                DateTime.now().add(Duration(days: 7));
            return cachedFile;
          }
        }
      } catch (_) {}
    }

    // Check disk cache
    try {
      final fileInfo = await _cacheManager.getFileFromCache(effectiveCacheKey);
      if (fileInfo != null) {
        try {
          if (await fileInfo.file.exists()) {
            final isValid = await _isValidImageFile(fileInfo.file);
            if (!isValid) {
              try {
                await fileInfo.file.delete();
              } catch (_) {}
            } else {
              // Store in memory cache for faster access next time
              _imageCache[effectiveCacheKey] = fileInfo.file;
              _imageCacheExpiry[effectiveCacheKey] =
                  DateTime.now().add(Duration(days: 7));
              return fileInfo.file;
            }
          }
        } catch (_) {}
      }
    } catch (_) {}

    return null;
  }

  /// Quick magic-bytes validation to avoid decoding non-image files
  Future<bool> _isValidImageFile(File file) async {
    try {
      final RandomAccessFile raf = await file.open(mode: FileMode.read);
      final int length = await file.length();
      final int toRead = length >= 12 ? 12 : length;
      if (toRead == 0) {
        await raf.close();
        return false;
      }
      final Uint8List header = await raf.read(toRead);
      await raf.close();

      // JPEG: FF D8
      if (header.length >= 2 && header[0] == 0xFF && header[1] == 0xD8) {
        return true;
      }
      // PNG: 89 50 4E 47
      if (header.length >= 4 &&
          header[0] == 0x89 &&
          header[1] == 0x50 &&
          header[2] == 0x4E &&
          header[3] == 0x47) {
        return true;
      }
      // WEBP: RIFF....WEBP
      if (header.length >= 12) {
        final bool isRiff = header[0] == 0x52 && // R
            header[1] == 0x49 && // I
            header[2] == 0x46 && // F
            header[3] == 0x46; // F
        final bool isWebp = header[8] == 0x57 && // W
            header[9] == 0x45 && // E
            header[10] == 0x42 && // B
            header[11] == 0x50; // P
        if (isRiff && isWebp) return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Get file from cache with better error handling
  Future<FileInfo?> getFilefromCache(String url) async {
    if (url.isEmpty) return null;

    try {
      final fileInfo = await _cacheManager.getFileFromCache(url);
      if (fileInfo != null && await fileInfo.file.exists()) {
        return fileInfo;
      }

      // If not in cache, download it
      final file = await _cacheManager.getSingleFile(url);
      return FileInfo(file, FileSource.Cache, DateTime.now(), url);
    } catch (e) {
      AppLogger.w('Error getting file info from cache',
          category: LogCategory.performance,
          data: {'url': url, 'error': e.toString()});
      return null;
    }
  }

  /// Download file to cache
  Future<bool> downloadFile(String url) async {
    if (url.isEmpty) return false;

    try {
      await _cacheManager.getSingleFile(url);
      return true;
    } catch (e) {
      AppLogger.w('Error downloading file',
          category: LogCategory.performance,
          data: {'url': url, 'error': e.toString()});
      return false;
    }
  }

  /// Clear cache (legacy method)
  Future<void> clearCache() async {
    try {
      await _cacheManager.emptyCache();
      AppLogger.i('Cache cleared successfully',
          category: LogCategory.performance);
    } catch (e) {
      AppLogger.w('Error clearing cache',
          category: LogCategory.performance, data: {'error': e.toString()});
    }
  }
}
