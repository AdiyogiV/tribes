import 'dart:io';

import 'package:aurogram/shared/services/cache_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:aurogram/core/di/injection.dart';
import 'package:aurogram/core/logging/app_logger.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:cached_network_image/cached_network_image.dart';

class GramPicture extends StatefulWidget {
  final String? spaceId; // Keep as spaceId - references Firestore field
  final String? displayPicture;
  final double size;
  final double borderRadius;

  const GramPicture(
      {super.key,
      this.spaceId,
      this.displayPicture,
      this.size = 70.0,
      this.borderRadius = 5.0});

  @override
  _GramPictureState createState() => _GramPictureState();
}

class _GramPictureState extends State<GramPicture>
    with AutomaticKeepAliveClientMixin {
  File? _picture;
  bool _isLoading = true;
  bool _hasError = false;
  // Error tracking
  int _errorCount = 0;
  static const int _maxErrorRetries = 2;

  // MEMORY LEAK FIX: Static map with size limit and cleanup to prevent infinite growth
  static final Map<String, DateTime> _permanentFailures = {};
  static const int _maxFailuresCacheSize = 50; // Limit to prevent memory leak
  static const Duration _failureCacheExpiry =
      Duration(hours: 1); // Clear old failures

  @override
  void initState() {
    super.initState();
    // On web, we use CachedNetworkImage directly, no need to load file
    if (!kIsWeb) {
      _loadImage();
    }
  }

  /// Clean up old failure entries to prevent memory leak
  static void _cleanupFailuresCache() {
    final now = DateTime.now();

    // Remove expired entries
    _permanentFailures.removeWhere(
        (url, timestamp) => now.difference(timestamp) > _failureCacheExpiry);

    // If still too many entries, remove oldest ones
    if (_permanentFailures.length > _maxFailuresCacheSize) {
      final sortedEntries = _permanentFailures.entries.toList()
        ..sort((a, b) => a.value.compareTo(b.value));

      // Keep only the newest entries
      final toKeep =
          sortedEntries.skip(_permanentFailures.length - _maxFailuresCacheSize);
      _permanentFailures.clear();
      _permanentFailures.addAll(Map.fromEntries(toKeep));
    }
  }

  /// Check if URL has permanently failed (with expiry)
  static bool _isUrlPermanentlyFailed(String url) {
    final failureTime = _permanentFailures[url];
    if (failureTime == null) return false;

    final now = DateTime.now();
    if (now.difference(failureTime) > _failureCacheExpiry) {
      // Expired failure, remove it
      _permanentFailures.remove(url);
      return false;
    }
    return true;
  }

  Future<void> _loadImage() async {
    // Skip loading if we've already had too many errors for this URL
    final String imageUrl = widget.displayPicture ?? '';
    if (imageUrl.isEmpty || _isUrlPermanentlyFailed(imageUrl)) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
      return;
    }

    if (_errorCount >= _maxErrorRetries) {
      // Mark this URL as permanently failed with timestamp and cleanup old entries
      _cleanupFailuresCache();
      _permanentFailures[imageUrl] = DateTime.now();
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
      return;
    }

    try {
      final cacheService = locator<CacheService>();

      // Try to get file with retry mechanism
      File? picture;
      int retryCount = 0;
      const maxRetries = 1; // Reduce max retries to avoid excessive loading

      while (retryCount <= maxRetries && picture == null) {
        try {
          picture = await cacheService.getFile(widget.displayPicture);

          // Verify the picture file is valid and readable
          if (picture != null) {
            try {
              await picture.length(); // This will throw if file is corrupted
            } catch (fileError) {
              AppLogger.e(
                'Error accessing gram picture file',
                category: LogCategory.general,
                error: fileError,
              );
              picture = null; // Reset to null to trigger retry or fallback
              _errorCount++; // Count this as an error
            }
          }
        } catch (loadError) {
          AppLogger.e(
            'Error loading gram picture (attempt ${retryCount + 1})',
            category: LogCategory.general,
            error: loadError,
          );

          _errorCount++; // Count this as an error

          // Only delay if we're going to retry
          if (retryCount < maxRetries) {
            await Future.delayed(Duration(milliseconds: 300));
          }
        }

        retryCount++;
      }

      if (mounted) {
        setState(() {
          _picture = picture;
          _isLoading = false;
          _hasError = picture == null;

          // If we've failed too many times, mark this URL as permanently failed
          if (_hasError && _errorCount >= _maxErrorRetries) {
            _cleanupFailuresCache();
            _permanentFailures[imageUrl] = DateTime.now();
          }
        });
      }
    } catch (e) {
      AppLogger.e(
        'Error loading gram picture',
        category: LogCategory.general,
        error: e,
      );

      _errorCount++; // Count this as an error

      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;

          // If we've failed too many times, mark this URL as permanently failed
          if (_errorCount >= _maxErrorRetries) {
            _cleanupFailuresCache();
            _permanentFailures[imageUrl] = DateTime.now();
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    // On web, use CachedNetworkImage directly since Image.file is not supported
    if (kIsWeb) {
      return _buildWebImage(context);
    }
    
    if (_isLoading) {
      final bool isDark = Theme.of(context).brightness == Brightness.dark;
      return Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDark ? AppTheme.darkPlaceholder : AppTheme.skeletonLightColor,
        ),
      );
    }

    if (_hasError || _picture == null) {
      return _buildPlaceholder(context);
    }

    // Skip ClipRRect if borderRadius is 0
    if (widget.borderRadius == 0) {
      return Image.file(
        _picture!,
        width: widget.size,
        height: widget.size,
        fit: BoxFit.cover,
        errorBuilder: _handleImageError,
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: Image.file(
        _picture!,
        width: widget.size,
        height: widget.size,
        fit: BoxFit.cover,
        errorBuilder: _handleImageError,
      ),
    );
  }
  
  /// Build image for web using CachedNetworkImage
  Widget _buildWebImage(BuildContext context) {
    final imageUrl = widget.displayPicture;
    
    if (imageUrl == null || imageUrl.isEmpty) {
      return _buildPlaceholder(context);
    }
    
    final imageWidget = CachedNetworkImage(
      imageUrl: imageUrl,
      width: widget.size,
      height: widget.size,
      fit: BoxFit.cover,
      placeholder: (context, url) {
        final bool isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDark ? AppTheme.darkPlaceholder : AppTheme.skeletonLightColor,
          ),
        );
      },
      errorWidget: (context, url, error) => _buildPlaceholder(context),
    );
    
    if (widget.borderRadius == 0) {
      return imageWidget;
    }
    
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: imageWidget,
    );
  }
  
  /// Build placeholder icon
  Widget _buildPlaceholder(BuildContext context) {
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Theme.of(context).scaffoldBackgroundColor,
      ),
      child: Center(
        child: Icon(
          CupertinoIcons.person_2_fill,
          size: widget.size * 0.45,
          color: AppTheme.primaryColor,
        ),
      ),
    );
  }

  // Extracted error handler to avoid code duplication
  Widget _handleImageError(
      BuildContext context, Object error, StackTrace? stackTrace) {
    AppLogger.e(
      'Error rendering gram image',
      category: LogCategory.general,
      error: error,
    );

    _errorCount++; // Count this as an error

    // Only attempt reload if we haven't exceeded the max retries
    // and the error is due to missing file
    if (_errorCount < _maxErrorRetries &&
        (error is FileSystemException ||
            error.toString().contains('No such file'))) {
      // Trigger reload on next frame
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _loadImage();
        }
      });
    } else {
      // Mark this URL as permanently failed if we've exceeded retries
      final String imageUrl = widget.displayPicture ?? '';
      if (imageUrl.isNotEmpty) {
        _cleanupFailuresCache();
        _permanentFailures[imageUrl] = DateTime.now();
      }
    }

    // Show a simple themed circular placeholder icon as fallback
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Theme.of(context).scaffoldBackgroundColor,
      ),
      child: Center(
        child: Icon(
          CupertinoIcons.person_2_fill,
          size: widget.size * 0.45,
          color: AppTheme.primaryColor,
        ),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
