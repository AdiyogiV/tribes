part of 'media_compression_service.dart';

/// Image compression, video compression (public API), thumbnail generation,
/// file helpers, adaptive quality selection, and temp file management.
extension MediaCompressorUtils on MediaCompressionService {
  // ── File helpers ──────────────────────────────────────────────────────────

  /// Check if file exists at path.
  Future<bool> fileExists(String filePath) async {
    try {
      final file = File(filePath);
      return await file.exists();
    } catch (e) {
      AppLogger.w('Error checking file existence',
          category: LogCategory.general,
          data: {'path': filePath, 'error': e.toString()});
      return false;
    }
  }

  /// Load image from path with fallback.
  Future<dynamic> loadImageFromPath(String filePath,
      {String? fallbackUrl}) async {
    try {
      if (await fileExists(filePath)) {
        return File(filePath);
      } else if (fallbackUrl != null) {
        return NetworkImage(fallbackUrl);
      } else {
        return AssetImage('assets/images/placeholder.png');
      }
    } catch (e) {
      AppLogger.w('Error loading image from path',
          category: LogCategory.general,
          data: {'path': filePath, 'error': e.toString()});
      return AssetImage('assets/images/placeholder.png');
    }
  }

  /// Get cached file from path safely.
  Future<File?> getCachedFile(String filePath) async {
    try {
      if (await fileExists(filePath)) {
        return File(filePath);
      }
      return null;
    } catch (e) {
      AppLogger.w('Error getting cached file',
          category: LogCategory.general,
          data: {'path': filePath, 'error': e.toString()});
      return null;
    }
  }

  // ── Thumbnail cache cleanup ───────────────────────────────────────────────

  /// Clean up old thumbnail cache files.
  Future<void> cleanupThumbnailCache() async {
    try {
      final cacheDir = await getTemporaryDirectory();
      final thumbnailDir = Directory('${cacheDir.path}/thumbnails');

      if (await thumbnailDir.exists()) {
        final files = await thumbnailDir.list().toList();

        files.sort((a, b) {
          if (a is File && b is File) {
            return b.lastModifiedSync().compareTo(a.lastModifiedSync());
          }
          return 0;
        });

        if (files.length > 100) {
          for (var i = 100; i < files.length; i++) {
            if (files[i] is File) {
              await (files[i] as File).delete();
            }
          }
        }
      }
    } catch (e) {
      AppLogger.w('Error cleaning up thumbnail cache',
          category: LogCategory.general, data: {'error': e.toString()});
    }
  }

  // ── Image compression ─────────────────────────────────────────────────────

  /// Compress an image with adaptive quality.
  Future<File?> compressImage(
    File imageFile, {
    int? targetWidth,
    int? targetHeight,
    int? quality,
    bool keepExif = false,
  }) async {
    try {
      if (!await imageFile.exists()) {
        AppLogger.e(
          'Cannot compress non-existent image file',
          category: LogCategory.media,
          data: {'path': imageFile.path},
        );
        return null;
      }

      final effectiveQuality = await _getOptimalImageQuality(quality);

      final dimensions = await _getImageDimensions(imageFile);
      final effectiveWidth = targetWidth ?? dimensions?.item1 ?? 1280;
      final effectiveHeight = targetHeight ?? dimensions?.item2 ?? 720;

      final maxDimension = max(effectiveWidth, effectiveHeight);
      final limitedWidth = effectiveWidth > 3000
          ? (effectiveWidth * 3000 / maxDimension).round()
          : effectiveWidth;
      final limitedHeight = effectiveHeight > 3000
          ? (effectiveHeight * 3000 / maxDimension).round()
          : effectiveHeight;

      final outputFile = await _createTempFile('.jpg');

      final image = img.decodeImage(imageFile.readAsBytesSync());
      if (image == null) {
        throw Exception('Could not decode image');
      }

      img.Image resizedImage = image;
      if (image.width > limitedWidth || image.height > limitedHeight) {
        resizedImage = img.copyResize(image,
            width: limitedWidth,
            height: limitedHeight,
            interpolation: img.Interpolation.linear);
      }

      final compressQuality = effectiveQuality * 100;
      final compressedBytes =
          img.encodeJpg(resizedImage, quality: compressQuality.round());
      await outputFile.writeAsBytes(compressedBytes);

      final originalSize = await imageFile.length();
      final compressedSize = await outputFile.length();
      final reduction = (1 - compressedSize / originalSize) * 100;

      AppLogger.d(
        'Image compressed successfully',
        category: LogCategory.media,
        data: {
          'originalSize': '${(originalSize / 1024).round()}KB',
          'compressedSize': '${(compressedSize / 1024).round()}KB',
          'reduction': '${reduction.round()}%',
          'quality': effectiveQuality,
        },
      );

      return outputFile;
    } catch (e, stack) {
      AppLogger.e(
        'Error compressing image',
        category: LogCategory.media,
        error: e,
        stackTrace: stack,
      );
      return null;
    }
  }

  // ── Video compression (public API) ────────────────────────────────────────

  /// Compress a video with adaptive quality.
  Future<MediaInfo?> compressVideo(
    File videoFile, {
    int? targetQuality,
    bool removeAudio = false,
  }) async {
    try {
      if (!await videoFile.exists()) {
        AppLogger.e(
          'Cannot compress non-existent video file',
          category: LogCategory.media,
          data: {'path': videoFile.path},
        );
        return null;
      }

      final VideoQuality quality = await _getOptimalVideoQuality(targetQuality);

      if (kDebugMode) {
        VideoCompress.compressProgress$.subscribe((progress) {
          AppLogger.d(
            'Video compression progress: $progress%',
            category: LogCategory.media,
          );
        });
      }

      final result = await VideoCompress.compressVideo(
        videoFile.path,
        quality: quality,
        deleteOrigin: false,
        includeAudio: !removeAudio,
      );

      if (result == null || result.file == null) {
        AppLogger.e(
          'Video compression failed',
          category: LogCategory.media,
          data: {'path': videoFile.path},
        );
        return null;
      }

      final originalSize = await videoFile.length();
      final compressedSize = await result.file!.length();
      final reduction = (1 - compressedSize / originalSize) * 100;

      AppLogger.d(
        'Video compressed successfully',
        category: LogCategory.media,
        data: {
          'originalSize':
              '${(originalSize / 1024 / 1024).toStringAsFixed(2)}MB',
          'compressedSize':
              '${(compressedSize / 1024 / 1024).toStringAsFixed(2)}MB',
          'reduction': '${reduction.round()}%',
          'quality': quality.toString(),
        },
      );

      return result;
    } catch (e, stack) {
      AppLogger.e(
        'Error compressing video',
        category: LogCategory.media,
        error: e,
        stackTrace: stack,
      );
      return null;
    }
  }

  // ── Thumbnail generation ──────────────────────────────────────────────────

  /// Generate a thumbnail for a video.
  Future<File?> generateVideoThumbnail(File videoFile,
      {int? maxWidth}) async {
    try {
      if (!await videoFile.exists()) {
        AppLogger.e(
          'Cannot generate thumbnail for non-existent video file',
          category: LogCategory.media,
          data: {'path': videoFile.path},
        );
        return null;
      }

      final quality = await _getOptimalImageQuality(null);

      final thumbnailData = await VideoCompress.getByteThumbnail(
        videoFile.path,
        quality: quality,
        position: -1,
      );

      if (thumbnailData == null) {
        AppLogger.e(
          'Failed to generate video thumbnail',
          category: LogCategory.media,
          data: {'path': videoFile.path},
        );
        return null;
      }

      final thumbFile = await _createTempFile('.jpg');
      await thumbFile.writeAsBytes(thumbnailData);

      AppLogger.d(
        'Video thumbnail generated successfully',
        category: LogCategory.media,
        data: {
          'path': thumbFile.path,
          'size': '${(thumbnailData.length / 1024).round()}KB',
        },
      );

      return thumbFile;
    } catch (e, stack) {
      AppLogger.e(
        'Error generating video thumbnail',
        category: LogCategory.media,
        error: e,
        stackTrace: stack,
      );
      return null;
    }
  }

  // ── Temp file management ──────────────────────────────────────────────────

  /// Create a temporary file with specified extension.
  Future<File> _createTempFile(String extension) async {
    _tempDir ??= await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = Random().nextInt(10000);
    return File('${_tempDir!.path}/media_${timestamp}_$random$extension');
  }

  /// Clean up temporary files.
  Future<void> cleanupTempFiles() async {
    try {
      _tempDir ??= await getTemporaryDirectory();

      final tempFiles = _tempDir!.listSync().where((entity) =>
          entity is File &&
          entity.path.contains('media_') &&
          (entity.path.endsWith('.jpg') || entity.path.endsWith('.mp4')));

      int deletedCount = 0;
      for (final file in tempFiles) {
        try {
          await (file as File).delete();
          deletedCount++;
        } catch (_) {
          // Ignore individual file deletion errors
        }
      }

      AppLogger.d(
        'Cleaned up $deletedCount temporary media files',
        category: LogCategory.media,
      );
    } catch (e) {
      AppLogger.w(
        'Error cleaning up temporary files',
        category: LogCategory.media,
        data: {'error': e.toString()},
      );
    }
  }

  // ── Adaptive quality helpers ──────────────────────────────────────────────

  /// Get image dimensions.
  Future<Tuple2<int, int>?> _getImageDimensions(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final dimensions = await compute(_decodeImageDimensions, bytes);
      return dimensions;
    } catch (e) {
      AppLogger.w(
        'Could not determine image dimensions',
        category: LogCategory.media,
        data: {'error': e.toString()},
      );
      return null;
    }
  }

  /// Determine optimal image quality based on network conditions.
  Future<int> _getOptimalImageQuality(int? requestedQuality) async {
    if (requestedQuality != null) {
      return requestedQuality.clamp(
          MediaCompressionService._minImageQuality.toInt(), MediaCompressionService._maxImageQuality.toInt());
    }

    if (!_adaptiveCompressionEnabled) {
      return MediaCompressionService._defaultImageQuality;
    }

    try {
      if (locator.isRegistered<NetworkOptimizer>()) {
        final networkOptimizer = locator<NetworkOptimizer>();
        final qualityFactor = networkOptimizer.getOptimalImageQuality();

        final range = MediaCompressionService._maxImageQuality - MediaCompressionService._minImageQuality;
        final quality = (MediaCompressionService._minImageQuality + (range * qualityFactor)).round();

        return quality;
      }
    } catch (e) {
      // Ignore errors and use default
    }

    return MediaCompressionService._defaultImageQuality;
  }

  /// Determine optimal video quality based on network conditions.
  Future<VideoQuality> _getOptimalVideoQuality(int? targetQuality) async {
    if (targetQuality != null) {
      return _getVideoQualityFromResolution(targetQuality);
    }

    if (!_adaptiveCompressionEnabled) {
      return _getVideoQualityFromResolution(MediaCompressionService._defaultVideoQuality);
    }

    try {
      if (locator.isRegistered<NetworkOptimizer>()) {
        final networkOptimizer = locator<NetworkOptimizer>();
        final qualityString = networkOptimizer.getOptimalVideoQuality();

        switch (qualityString) {
          case 'low':
            return VideoQuality.LowQuality;
          case 'medium':
            return VideoQuality.MediumQuality;
          case 'high':
            return VideoQuality.HighestQuality;
          default:
            return VideoQuality.MediumQuality;
        }
      }
    } catch (e) {
      // Ignore errors and use default
    }

    return _getVideoQualityFromResolution(MediaCompressionService._defaultVideoQuality);
  }

  /// Convert resolution to VideoQuality enum.
  VideoQuality _getVideoQualityFromResolution(int resolution) {
    if (resolution <= 480) {
      return VideoQuality.LowQuality;
    } else if (resolution <= 720) {
      return VideoQuality.MediumQuality;
    } else {
      return VideoQuality.HighestQuality;
    }
  }
}
