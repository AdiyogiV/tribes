import 'dart:io';
import 'package:aurogram/core/theme/app_theme.dart';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:aurogram/core/logging/app_logger.dart';
import 'package:aurogram/core/storage/memory_manager.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:async';

/// A utility class for optimizing image loading and display in the app
class ImageOptimizer {
  // Cache for optimized images to avoid repeated resizing
  static final Map<String, ImageProvider> _memoryCache = {};

  // In-memory cache for programmatically generated image data
  static final Map<String, Uint8List> _generatedImageCache = {};

  // Keep track of verified assets to avoid repeated checks
  static final Map<String, bool> _verifiedAssets = {};

  // Track which missing assets we've already logged to avoid log spam
  static final Set<String> _fallbackLogged = {};

  // Keep track of placeholder assets
  static final Map<String, String> _assetFallbacks = {
    'assets/images/logo.png': 'generated_placeholder',
    'assets/images/error.png': 'generated_placeholder',
    'assets/images/user.png': 'generated_placeholder',
    'assets/images/placeholder.png': 'generated_placeholder',
  };

  /// Initialize the image optimizer with memory management
  static void initialize(MemoryManager memoryManager) {
    // Register for low memory callbacks to clear cache when needed
    memoryManager.addLowMemoryCallback(() {
      clearCache();
    });

    // Verify critical assets on initialization and generate fallbacks
    _verifyCriticalAssets();
  }

  /// Verify that critical assets exist and set up fallbacks
  static void _verifyCriticalAssets() async {
    final criticalAssets = [
      'assets/images/logo.png',
      'assets/images/placeholder.png',
      'assets/images/error.png',
      'assets/images/user.png',
    ];

    // Check each asset and log issues
    for (String asset in criticalAssets) {
      bool exists = await assetExists(asset);
      _verifiedAssets[asset] = exists;

      if (!exists) {
        AppLogger.w('Missing critical asset: $asset',
            category: LogCategory.performance);
      }
    }

    // Ensure we have at least one placeholder image available
    // Generate it programmatically if needed
    if (!_verifiedAssets['assets/images/placeholder.png']!) {
      AppLogger.e('Missing placeholder asset: assets/images/placeholder.png',
          category: LogCategory.performance);

      // Generate a placeholder image programmatically
      await _generatePlaceholderImage();
    }
  }

  /// Generate a placeholder image programmatically if no placeholder exists
  static Future<void> _generatePlaceholderImage() async {
    try {
      // Generate a simpler placeholder to save memory
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      // Use a smaller size to conserve memory (200x200 -> 150x150)
      final size = Size(150, 150);

      // Draw background
      final bgPaint = Paint()..color = Colors.blue[100]!;
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

      // Draw a circle
      final circlePaint = Paint()
        ..color = Colors.blue[400]!
        ..style = PaintingStyle.fill;
      canvas.drawCircle(
          Offset(size.width / 2, size.height / 2), 40, circlePaint);

      // Add text (simplified - smaller font)
      final builder = ui.ParagraphBuilder(ui.ParagraphStyle(
        textAlign: TextAlign.center,
        fontSize: 18, // Smaller font size
      ))
        ..pushStyle(ui.TextStyle(color: Colors.white))
        ..addText('T');
      final paragraph = builder.build();
      paragraph.layout(ui.ParagraphConstraints(width: size.width));
      canvas.drawParagraph(
          paragraph,
          Offset(size.width / 2 - paragraph.width / 2,
              size.height / 2 - paragraph.height / 2));

      // Convert to image
      final picture = recorder.endRecording();
      final img =
          await picture.toImage(size.width.toInt(), size.height.toInt());
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
      final buffer = byteData!.buffer.asUint8List();

      // Cache the generated image
      _generatedImageCache['generated_placeholder'] = buffer;

      AppLogger.i('Successfully generated placeholder image programmatically',
          category: LogCategory.performance);
    } catch (e) {
      AppLogger.e('Failed to generate placeholder image',
          category: LogCategory.performance, error: e);

      // As a last resort, create a simple 1x1 transparent pixel
      _generatedImageCache['generated_placeholder'] = _createTransparentPixel();
    }
  }

  /// Create a 1x1 transparent pixel as absolute fallback
  static Uint8List _createTransparentPixel() {
    // Simple 1x1 transparent PNG
    return Uint8List.fromList([
      0x89,
      0x50,
      0x4E,
      0x47,
      0x0D,
      0x0A,
      0x1A,
      0x0A,
      0x00,
      0x00,
      0x00,
      0x0D,
      0x49,
      0x48,
      0x44,
      0x52,
      0x00,
      0x00,
      0x00,
      0x01,
      0x00,
      0x00,
      0x00,
      0x01,
      0x08,
      0x06,
      0x00,
      0x00,
      0x00,
      0x1F,
      0x15,
      0xC4,
      0x89,
      0x00,
      0x00,
      0x00,
      0x0A,
      0x49,
      0x44,
      0x41,
      0x54,
      0x78,
      0x9C,
      0x63,
      0x00,
      0x01,
      0x00,
      0x00,
      0x05,
      0x00,
      0x01,
      0x0D,
      0x0A,
      0x2D,
      0xB4,
      0x00,
      0x00,
      0x00,
      0x00,
      0x49,
      0x45,
      0x4E,
      0x44,
      0xAE,
      0x42,
      0x60,
      0x82
    ]);
  }

  /// Clear the optimized image cache
  static void clearCache() {
    _memoryCache.clear();
    AppLogger.d('Cleared image optimizer cache',
        category: LogCategory.performance);
  }

  /// Load an optimized network image using cached files
  static Future<ImageProvider> loadOptimizedNetworkImage(
    String url, {
    int? maxWidth,
    int? maxHeight,
    bool cacheResult = true,
  }) async {
    // Check cache first for instant returns
    if (cacheResult && _memoryCache.containsKey(url)) {
      return _memoryCache[url]!;
    }

    if (url.isEmpty) {
      return AssetImage('assets/images/user.png');
    }

    try {
      // Try to get from cache manager first
      final cacheManager = DefaultCacheManager();
      final fileInfo = await cacheManager.getFileFromCache(url);
      File? file;

      if (fileInfo != null) {
        file = fileInfo.file;
        // Verify file actually exists
        try {
          await file.length(); // This will throw if file doesn't exist
        } catch (e) {
          // File doesn't exist anymore, force re-download
          AppLogger.w(
            'Cached file no longer exists, re-downloading',
            category: LogCategory.performance,
            data: {'url': url, 'error': e.toString()},
          );
          file = null;
        }
      }

      if (file == null) {
        // Download if not cached or if cached file is missing
        try {
          file = await cacheManager.getSingleFile(url);
        } catch (downloadError) {
          AppLogger.w(
            'Error downloading image, fallback to network image',
            category: LogCategory.performance,
            data: {'url': url, 'error': downloadError.toString()},
          );
          // Fallback to network image
          final networkImage = NetworkImage(url);
          if (cacheResult) {
            _memoryCache[url] = networkImage;
          }
          return networkImage;
        }
      }

      // Simply use the file image directly with no resize processing
      // This avoids the image decoder registry errors
      final imageProvider = FileImage(file);

      // Cache the result for future fast access
      if (cacheResult) {
        _memoryCache[url] = imageProvider;
      }

      return imageProvider;
    } catch (e) {
      AppLogger.w(
        'Error loading network image',
        category: LogCategory.performance,
        data: {'url': url, 'error': e.toString()},
      );
      // Return a placeholder on error
      return AssetImage('assets/images/user.png');
    }
  }

  /// Preload and cache important images to avoid janky UI
  static Future<void> preloadImportantImages(List<String> urls) async {
    if (urls.isEmpty) return;

    // Load images in parallel for better performance
    final futures = urls.map((url) async {
      try {
        final cacheManager = DefaultCacheManager();
        await cacheManager.getSingleFile(url);
      } catch (e) {
        // Silently ignore preload errors
      }
    }).toList();

    await Future.wait(futures);
    AppLogger.d('Preloaded ${urls.length} images',
        category: LogCategory.performance);
  }

  /// Preload asset images to ensure they're available when needed
  static Future<void> preloadAssetImages(List<String> assetPaths) async {
    if (assetPaths.isEmpty) return;

    // Limit the number of concurrent asset loads to prevent memory spikes
    const int maxConcurrentLoads = 3;
    int successCount = 0;
    List<String> failedAssets = [];

    // Process assets in smaller batches to reduce memory pressure
    for (int i = 0; i < assetPaths.length; i += maxConcurrentLoads) {
      final int end = (i + maxConcurrentLoads < assetPaths.length)
          ? i + maxConcurrentLoads
          : assetPaths.length;

      final batch = assetPaths.sublist(i, end);

      // Process this batch in parallel
      final results = await Future.wait(batch.map((assetPath) async {
        try {
          // Just load the asset but don't decode - we'll decode on demand
          await rootBundle.load(assetPath);
          return true;
        } catch (e) {
          failedAssets.add(assetPath);
          return false;
        }
      }));

      successCount += results.where((result) => result).length;

      // Add a small delay between batches to allow other operations
      if (end < assetPaths.length) {
        await Future.delayed(Duration(milliseconds: 5));
      }
    }

    if (failedAssets.isEmpty) {
      AppLogger.d('Successfully preloaded $successCount asset images',
          category: LogCategory.performance);
    } else {
      AppLogger.w('Failed to preload some assets',
          category: LogCategory.performance,
          data: {'failed': failedAssets, 'successful': successCount});
    }
  }

  /// Check if asset exists before attempting to use it
  static Future<bool> assetExists(String assetPath) async {
    // Check cache first
    if (_verifiedAssets.containsKey(assetPath)) {
      return _verifiedAssets[assetPath]!;
    }

    try {
      await rootBundle.load(assetPath);
      _verifiedAssets[assetPath] = true;
      return true;
    } catch (e) {
      _verifiedAssets[assetPath] = false;
      return false;
    }
  }

  /// Get a fallback asset path for a missing asset
  static String getFallbackAssetPath(String originalAsset) {
    if (_assetFallbacks.containsKey(originalAsset)) {
      final fallback = _assetFallbacks[originalAsset]!;
      // Check if it's a generated placeholder
      if (fallback.startsWith('generated_') &&
          _generatedImageCache.containsKey(fallback)) {
        return fallback;
      }

      // Check if the fallback asset exists
      if (_verifiedAssets.containsKey(fallback) && _verifiedAssets[fallback]!) {
        return fallback;
      }
    }

    // Default to the generated placeholder
    if (_generatedImageCache.containsKey('generated_placeholder')) {
      return 'generated_placeholder';
    }

    // At this point we have no fallbacks, so return the original and let it fail
    return originalAsset;
  }

  /// Build an optimized image which handles both asset and generated images
  static Future<Widget> buildOptimizedAssetImage({
    required String assetPath,
    String? fallbackAssetPath,
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    BorderRadius? borderRadius,
  }) async {
    // First check if the asset exists
    final exists = await assetExists(assetPath);

    // Use provided fallback, or get a default fallback if not provided
    final effectiveAssetPath = exists
        ? assetPath
        : (fallbackAssetPath ?? getFallbackAssetPath(assetPath));

    // Only log first time we use a fallback for this asset
    if (!exists && !_fallbackLogged.contains(assetPath)) {
      AppLogger.w('Using fallback for missing asset',
          category: LogCategory.performance,
          data: {'original': assetPath, 'fallback': effectiveAssetPath});

      // Add to logged set to avoid duplicate logs
      _fallbackLogged.add(assetPath);
    }

    Widget imageWidget;

    // Performance optimization: calculate render dimensions to save memory
    final int? cacheWidth = width != null ? (width * 1.5).ceil() : null;
    final int? cacheHeight = height != null ? (height * 1.5).ceil() : null;

    // Check if it's a generated placeholder
    if (effectiveAssetPath.startsWith('generated_') &&
        _generatedImageCache.containsKey(effectiveAssetPath)) {
      // Use memory image
      final buffer = _generatedImageCache[effectiveAssetPath]!;
      imageWidget = Image.memory(
        buffer,
        width: width,
        height: height,
        fit: fit,
        cacheWidth: cacheWidth,
        cacheHeight: cacheHeight,
        errorBuilder: (context, error, stackTrace) {
          return _buildErrorWidget(width, height);
        },
      );
    } else {
      // Try to use asset image
      try {
        imageWidget = Image.asset(
          effectiveAssetPath,
          width: width,
          height: height,
          fit: fit,
          cacheWidth: cacheWidth,
          cacheHeight: cacheHeight,
          errorBuilder: (context, error, stackTrace) {
            // If asset fails, use generated placeholder
            if (_generatedImageCache.containsKey('generated_placeholder')) {
              return Image.memory(
                _generatedImageCache['generated_placeholder']!,
                width: width,
                height: height,
                fit: fit,
                cacheWidth: cacheWidth,
                cacheHeight: cacheHeight,
              );
            }
            return _buildErrorWidget(width, height);
          },
        );
      } catch (e) {
        // Final fallback - show error widget
        imageWidget = _buildErrorWidget(width, height);
      }
    }

    if (borderRadius != null) {
      imageWidget = ClipRRect(
        borderRadius: borderRadius,
        child: imageWidget,
      );
    }

    return imageWidget;
  }

  /// Generate a widget for displaying an optimized image
  static Widget buildOptimizedImage({
    required String url,
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    Widget? placeholder,
    Widget? errorWidget,
    BorderRadius? borderRadius,
  }) {
    // Add a key based on the URL to help Flutter identify and reuse the widget
    final imageKey = ValueKey('optimized_image_$url');

    // For very small images or avatars (likely profile pictures), use more aggressive caching
    final bool isLikelyAvatar =
        (width != null && width <= 80) || (height != null && height <= 80);

    if (isLikelyAvatar) {
      // For avatars, use CachedNetworkImage with memory caching prioritized
      return _buildCachedImageForAvatar(
        url: url,
        width: width,
        height: height,
        fit: fit,
        placeholder: placeholder,
        errorWidget: errorWidget,
        borderRadius: borderRadius,
        imageKey: imageKey,
      );
    }

    return FutureBuilder<ImageProvider>(
      key: imageKey,
      future: loadOptimizedNetworkImage(
        url,
        maxWidth: width?.toInt(),
        maxHeight: height?.toInt(),
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return placeholder ?? _buildDefaultPlaceholder(width, height);
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return errorWidget ?? _buildErrorWidget(width, height);
        }

        final Widget image = Image(
          image: snapshot.data!,
          width: width,
          height: height,
          fit: fit,
          // Set gapless playback to true to avoid flicker during image reload
          gaplessPlayback: true,
          errorBuilder: (context, error, stackTrace) {
            return errorWidget ?? _buildErrorWidget(width, height);
          },
        );

        if (borderRadius != null) {
          return ClipRRect(
            borderRadius: borderRadius,
            child: image,
          );
        }

        return image;
      },
    );
  }

  /// Build a cached image optimized specifically for avatars
  static Widget _buildCachedImageForAvatar({
    required String url,
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    Widget? placeholder,
    Widget? errorWidget,
    BorderRadius? borderRadius,
    Key? imageKey,
  }) {
    // Use CachedNetworkImage with specific settings for avatar images
    Widget imageWidget = CachedNetworkImage(
      key: imageKey,
      imageUrl: url,
      width: width,
      height: height,
      fit: fit,
      fadeInDuration: const Duration(milliseconds: 100),
      fadeOutDuration: const Duration(milliseconds: 100),
      placeholderFadeInDuration: const Duration(milliseconds: 100),
      memCacheWidth:
          width != null ? (width * 2).toInt() : null, // For high-res displays
      memCacheHeight: height != null ? (height * 2).toInt() : null,

      // Set very long cache duration for avatars
      maxWidthDiskCache: width != null ? (width * 2).toInt() : 200,
      maxHeightDiskCache: height != null ? (height * 2).toInt() : 200,

      // Avatar-specific settings
      cacheKey: 'avatar_$url', // Specific cache key for avatars

      placeholder: (context, url) =>
          placeholder ?? _buildDefaultPlaceholder(width, height),
      errorWidget: (context, url, error) =>
          errorWidget ?? _buildErrorWidget(width, height),
    );

    if (borderRadius != null) {
      imageWidget = ClipRRect(
        borderRadius: borderRadius,
        child: imageWidget,
      );
    }

    return imageWidget;
  }

  /// Build a default placeholder widget (simple skeleton)
  static Widget _buildDefaultPlaceholder(double? width, double? height) {
    return Container(
      width: width,
      height: height,
      color: AppTheme.skeletonLightColor, // Warm skeleton color
    );
  }

  /// Build a default error widget
  static Widget _buildErrorWidget(double? width, double? height) {
    return Container(
      width: width,
      height: height,
      color: Colors.grey[200],
      child: Center(
        child: Icon(
          Icons.image_not_supported_outlined,
          color: Colors.grey[400],
          size: (width ?? 100) / 3,
        ),
      ),
    );
  }

  /// Get image aspect ratio from URL (non-blocking, cached)
  /// Returns default 16/9 if unable to determine
  static final Map<String, double> _aspectRatioCache = {};

  static Future<double> getImageAspectRatio(String imageUrl) async {
    if (imageUrl.isEmpty) return 16 / 9;

    // Check cache first
    if (_aspectRatioCache.containsKey(imageUrl)) {
      return _aspectRatioCache[imageUrl]!;
    }

    try {
      final imageProvider = CachedNetworkImageProvider(imageUrl);
      final completer = Completer<double>();
      final stream = imageProvider.resolve(const ImageConfiguration());
      late ImageStreamListener listener;

      void onImage(ImageInfo info, bool _) {
        if (!completer.isCompleted) {
          final aspectRatio = info.image.width / info.image.height;
          _aspectRatioCache[imageUrl] = aspectRatio;
          completer.complete(aspectRatio);
          info.dispose();
          try {
            stream.removeListener(listener);
          } catch (_) {
            // Ignore if already removed
          }
        }
      }

      listener = ImageStreamListener(onImage, onChunk: null, onError: null);
      stream.addListener(listener);

      // Timeout after 5 seconds
      Future.delayed(const Duration(seconds: 5), () {
        if (!completer.isCompleted) {
          completer.completeError('Timeout');
          try {
            stream.removeListener(listener);
          } catch (_) {
            // Ignore if already removed
          }
        }
      });

      final aspectRatio = await completer.future;
      return aspectRatio;
    } catch (e) {
      // Return default on error
      return 16 / 9;
    }
  }
}
