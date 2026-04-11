import 'dart:io'
    if (dart.library.html) 'package:aurogram/platform/io_stub.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:aurogram/shared/services/cache_service.dart';
import 'package:flutter/material.dart';
import 'package:aurogram/core/di/injection.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/core/theme/header_style.dart';
import 'package:aurogram/core/logging/app_logger.dart';
import 'package:aurogram/shared/data/repositories/user_repository.dart';

// Extracted sub-widgets
import 'parts/preview_box_parts.dart';

// Re-export so existing imports keep working
export 'parts/preview_box_parts.dart';

class PreviewBox extends StatefulWidget {
  final String previewUrl;
  final String? author;
  final String? username;
  final String? title;
  final bool showPlayIcon;
  final String? cacheKey;
  final void Function(String stableKey)? onPermanentFailure;
  final bool cacheOnly; // if true, don't fetch from network
  final bool
      skipIfMissing; // if true, call onPermanentFailure and render empty when not available
  final bool hideWhileLoading; // if true, render nothing while loading

  // New parameters for text posts
  final String? content; // text content for text posts
  final String? postType; // 'video', 'text', or 'audio'
  final bool compact; // compact mode for mini thumbnails
  final bool
      showAuthorPicture; // whether to show author DP (e.g. false for reply previews)
  final bool showNoteIcon; // whether to show note icon for text posts
  final bool
      limitTextPreview; // whether to limit text content (100 chars and remove line breaks)

  // Uploading state
  final bool uploading; // if true, show uploading indicator overlay

  // Repost badge (green icon on profile grid for reposted posts)
  final bool isRepost;

  // Audio post parameters
  final String? audioUrl; // URL for audio posts
  final int? durationInSeconds; // Duration for audio posts

  const PreviewBox(
      {this.username,
      this.author,
      required this.previewUrl,
      this.title,
      this.showPlayIcon = false,
      this.cacheKey,
      this.onPermanentFailure,
      this.cacheOnly = false,
      this.skipIfMissing = false,
      this.hideWhileLoading = false,
      this.content,
      this.postType,
      this.compact = false,
      this.showAuthorPicture = true,
      this.showNoteIcon =
          false, // Note icon is no longer shown, keeping parameter for API compatibility
      this.limitTextPreview = true,
      this.uploading = false,
      this.isRepost = false,
      this.audioUrl,
      this.durationInSeconds,
      super.key});

  @override
  _PreviewBoxState createState() => _PreviewBoxState();
}

class _PreviewBoxState extends State<PreviewBox>
    with AutomaticKeepAliveClientMixin {
  // Use dynamic to handle both dart:io.File (mobile) and network URLs (web)
  dynamic preview;
  dynamic authorPicture;
  // Web-specific: store URL directly for NetworkImage
  String? _webPreviewUrl;
  String? _webAuthorPicUrl;
  bool isLoading = true;
  bool loadError = false;
  int _errorCount = 0;
  static const int _maxErrorRetries = 1; // cap retries to avoid loops
  static final Map<String, bool> _permanentFailures = {};
  static final Map<String, dynamic> _inMemoryFiles = {};
  bool _hasFinalizedError =
      false; // prevent setState during build and duplicate scheduling

  String get _stableKey {
    if (widget.cacheKey != null && widget.cacheKey!.isNotEmpty) {
      return widget.cacheKey!;
    }
    final url = widget.previewUrl;
    if (url.isEmpty) return '';
    // derive from last path segment without query
    return url.contains('/') ? url.split('/').last.split('?').first : url;
  }

  bool get _isTextPost {
    return widget.postType == 'text' ||
        (widget.content != null &&
            widget.content!.isNotEmpty &&
            widget.previewUrl.isEmpty &&
            widget.postType != 'audio' &&
            widget.postType != 'image');
  }

  bool get _isAudioPost => widget.postType == 'audio';

  bool get _isImagePost => widget.postType == 'image';

  bool get _isUploading => widget.uploading;

  /// Check if we have a valid preview (works for both web and mobile)
  bool get _hasValidPreview {
    if (kIsWeb) {
      return _webPreviewUrl != null && _webPreviewUrl!.isNotEmpty;
    }
    return preview != null;
  }

  /// Check if we have a valid author picture
  bool get _hasValidAuthorPic {
    if (kIsWeb) {
      return _webAuthorPicUrl != null && _webAuthorPicUrl!.isNotEmpty;
    }
    return authorPicture != null;
  }

  Widget _buildPreviewImage() => buildPreviewImage(
        isWeb: kIsWeb,
        webPreviewUrl: _webPreviewUrl,
        preview: preview,
        compact: widget.compact,
        isUploading: _isUploading,
        context: context,
      );

  Widget _buildAuthorPicImage() => buildAuthorPicImage(
        isWeb: kIsWeb,
        webAuthorPicUrl: _webAuthorPicUrl,
        authorPicture: authorPicture,
        compact: widget.compact,
      );

  UserRepository get _userRepo => locator<UserRepository>();

  @override
  void initState() {
    super.initState();
    // If this URL has already been marked as permanently failing, skip load
    if (_permanentFailures[_stableKey] == true) {
      isLoading = false;
      loadError = true;
      return;
    }
    // If we have a previously loaded file for this key, use it immediately
    final preKey = _stableKey;
    if (preKey.isNotEmpty && _inMemoryFiles.containsKey(preKey)) {
      preview = _inMemoryFiles[preKey];
      isLoading = false;
      loadError = false;
      return;
    }
    initializePreview();
  }

  @override
  void didUpdateWidget(covariant PreviewBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If parent rebuilds after cache prefetch, try to upgrade from cached file
    final hasValidPreview = kIsWeb ? _webPreviewUrl != null : preview != null;
    if (!hasValidPreview && !loadError && widget.previewUrl.isNotEmpty) {
      final k = _stableKey;

      // On web, just check if URL is valid
      if (kIsWeb) {
        if (widget.previewUrl.startsWith('http')) {
          setState(() {
            _webPreviewUrl = widget.previewUrl;
            isLoading = false;
          });
        }
        return;
      }

      // Mobile: check in-memory cache first
      if (k.isNotEmpty && _inMemoryFiles.containsKey(k)) {
        setState(() {
          preview = _inMemoryFiles[k];
          isLoading = false;
        });
        return;
      }
      final cacheService = locator<CacheService>();
      cacheService
          .getFileIfCached(widget.previewUrl, cacheKey: widget.cacheKey)
          .then((file) {
        if (!mounted) return;
        if (file != null) {
          setState(() {
            preview = file;
            isLoading = false;
          });
          final key = _stableKey;
          if (key.isNotEmpty) {
            _inMemoryFiles[key] = file;
          }
        }
      });
    }
  }

  Future<void> _loadPreview(String url) async {
    try {
      if (url.isNotEmpty) {
        if (_permanentFailures[_stableKey] == true) {
          if (mounted) setState(() { isLoading = false; loadError = true; });
          return;
        }

        // On web, just use network URL directly
        if (kIsWeb) {
          if (url.startsWith('http')) {
            if (mounted) {
              setState(() {
                _webPreviewUrl = url;
                loadError = false;
                _errorCount = 0;
                _hasFinalizedError = false;
              });
            }
          }
          return;
        }

        // Mobile: use cache service
        final cacheService = locator<CacheService>();
        // Force redownload from network
        final file = await cacheService.getFile(url,
            cacheKey: widget.cacheKey, forceDownload: true);

        if (mounted && file != null) {
          setState(() {
            preview = file;
            loadError = false;
            _errorCount = 0; // reset on success
            _hasFinalizedError = false; // allow future retries if needed
          });
          final key = _stableKey;
          if (key.isNotEmpty) {
            _inMemoryFiles[key] = file;
          }
        }
      }
    } catch (e) {
      AppLogger.w('Error reloading preview',
          category: LogCategory.ui, data: {'error': e.toString()});
      if (mounted) setState(() => loadError = true);
    }
  }

  Future<void> initializePreview() async {
    try {
      // On web, use URLs directly instead of file caching
      if (kIsWeb) {
        await _initializePreviewWeb();
        return;
      }

      if (widget.author != null) {
        final authorPicUrl = await _userRepo.getPhotoUrl(widget.author!);
        if (authorPicUrl != null && authorPicUrl.isNotEmpty) {
          final cacheService = locator<CacheService>();
          authorPicture = await cacheService.getFile(authorPicUrl);
        }
      }

      // Skip thumbnail loading for text posts
      if (!_isTextPost && widget.previewUrl.isNotEmpty) {
        final url = widget.previewUrl;

        // Handle local file paths (for uploading posts) - only on mobile
        if (!url.startsWith('http')) {
          final localPath = url.startsWith('file://') ? url.substring(7) : url;
          final localFile = File(localPath);
          if (localFile.existsSync()) {
            preview = localFile;
            if (mounted) {
              setState(() {
                isLoading = false;
              });
              final key = _stableKey;
              if (key.isNotEmpty) {
                _inMemoryFiles[key] = preview!;
              }
            }
            return; // Successfully loaded local file
          }
        }

        // Network URL - use cache service
        final cacheService = locator<CacheService>();
        // If cacheOnly, don't hit network
        if (widget.cacheOnly) {
          preview = await cacheService.getFileIfCached(
            url,
            cacheKey: widget.cacheKey,
          );
        } else {
          // Try cache first, then network
          preview = await cacheService.getFileIfCached(
            url,
            cacheKey: widget.cacheKey,
          );
          preview ??= await cacheService.getFile(
            url,
            cacheKey: widget.cacheKey,
          );
        }
      }

      if (!_isTextPost &&
          !_isUploading &&
          preview == null &&
          widget.previewUrl.isNotEmpty) {
        _markPermanentFailure();
      }

      if (mounted) {
        setState(() => isLoading = false);
        final key = _stableKey;
        if (key.isNotEmpty && preview != null) {
          _inMemoryFiles[key] = preview!;
        }
      }
    } catch (e) {
      AppLogger.e('Error loading preview',
          category: LogCategory.ui, data: {'error': e.toString()});
      if (mounted) {
        setState(() {
          isLoading = false;
          loadError = !_isTextPost && !_isUploading;
        });
      }
      if (!_isTextPost && !_isUploading) _markPermanentFailure();
    }
  }

  /// Web-specific initialization - use network images directly
  Future<void> _initializePreviewWeb() async {
    try {
      if (widget.author != null) {
        final authorPicUrl = await _userRepo.getPhotoUrl(widget.author!);
        if (authorPicUrl != null && authorPicUrl.isNotEmpty) {
          _webAuthorPicUrl = authorPicUrl;
        }
      }

      // Skip thumbnail loading for text posts
      // For image posts, the previewUrl IS the image itself
      if (!_isTextPost && widget.previewUrl.isNotEmpty) {
        final url = widget.previewUrl;
        // Accept any URL that looks like a network URL
        if (url.startsWith('http://') || url.startsWith('https://')) {
          _webPreviewUrl = url;
        } else if (url.contains('firebasestorage.googleapis.com') ||
            url.contains('storage.googleapis.com')) {
          // Firebase Storage URL without scheme - add https
          _webPreviewUrl = url.startsWith('//') ? 'https:$url' : 'https://$url';
        }
        // Log for debugging if URL doesn't match expected patterns
        if (_webPreviewUrl == null && url.isNotEmpty) {
          AppLogger.w('PreviewBox web: Unexpected URL format',
              category: LogCategory.ui,
              data: {
                'url': url.substring(0, url.length > 50 ? 50 : url.length),
                'postType': widget.postType ?? 'unknown'
              });
        }
      }

      if (!_isTextPost &&
          !_isUploading &&
          _webPreviewUrl == null &&
          widget.previewUrl.isNotEmpty) {
        _markPermanentFailure();
      }

      if (mounted) setState(() => isLoading = false);
    } catch (e) {
      AppLogger.e('Error loading preview (web)',
          category: LogCategory.ui, data: {'error': e.toString()});
      if (mounted) {
        setState(() {
          isLoading = false;
          loadError = !_isTextPost && !_isUploading;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    // If configured to skip when missing, render nothing in these cases
    if (widget.skipIfMissing) {
      if (isLoading && widget.hideWhileLoading) {
        return const SizedBox.shrink();
      }
      // On web, check _webPreviewUrl instead of preview
      final hasPreview = kIsWeb ? _webPreviewUrl != null : preview != null;
      if (!isLoading && (!hasPreview || loadError)) {
        return const SizedBox.shrink();
      }
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Use smaller border radius for compact mode (mini thumbnails in gram preview)
    // to avoid white corner artifacts from radius mismatch with parent container
    final double borderRadius =
        widget.compact ? 10.0 : AppHeaderStyle.cardBorderRadius;

    // Match profile cards (STATS, STARS, INSIGHTS) using Material elevation
    // In compact mode, skip elevation since parent already provides it
    return Material(
      elevation: widget.compact ? 0 : ((isLoading || loadError) ? 0 : 2),
      shadowColor: Colors.black.withValues(alpha: isDark ? 0.24 : 0.12),
      borderRadius: BorderRadius.circular(borderRadius),
      color: isDark ? AppTheme.cardDarkColor : AppTheme.cardLightColor,
      clipBehavior: Clip.antiAlias,
      child: AspectRatio(
        aspectRatio: 1,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            _buildMainContent(),
            if (widget.isRepost)
              PreviewBoxRepostBadge(compact: widget.compact),
            if (widget.showAuthorPicture && _hasValidAuthorPic)
              PreviewBoxAuthorPic(
                compact: widget.compact,
                authorPicImage: _buildAuthorPicImage(),
              ),
            if (widget.showPlayIcon && !isLoading && !_isUploading)
              const PreviewBoxPlayIcon(),
            // Uploading overlay - only show if we have a preview (thumbnail)
            // If no preview, the placeholder already shows uploading state
            if (_isUploading && _hasValidPreview && !loadError)
              _buildUploadingOverlay(),
          ],
        ),
      ),
    );
  }

  /// Selects and returns the primary content widget based on current state.
  Widget _buildMainContent() {
    if (isLoading) {
      return widget.hideWhileLoading
          ? const SizedBox.shrink()
          : _buildLoadingPlaceholder();
    }
    if (_isAudioPost) return _buildAudioPostContent();
    if (_isTextPost) return _buildTextPostContent();

    if ((_isImagePost || !_isImagePost) && _hasValidPreview && !loadError) {
      return SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: _buildPreviewImage(),
      );
    }

    if (preview != null && !loadError && !kIsWeb) {
      return SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: Image.file(
          preview!,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              _handleImageError(error),
          cacheWidth: 300,
          cacheHeight: 300,
        ),
      );
    }

    return widget.skipIfMissing
        ? const SizedBox.shrink()
        : _buildErrorPlaceholder();
  }

  /// Handles image load errors with retry / permanent-failure logic.
  Widget _handleImageError(Object error) {
    AppLogger.w('Error loading preview image',
        category: LogCategory.ui,
        data: {'error': error.toString()});

    final errorText = error.toString();
    final isMissingFile =
        error is FileSystemException || errorText.contains('No such file');
    final isInvalidData = errorText.contains('Invalid image data');

    if (isInvalidData) {
      _markPermanentFailure();
      _scheduleErrorState();
    } else if (isMissingFile && _errorCount < _maxErrorRetries) {
      _errorCount++;
      _scheduleErrorState(reload: true);
    } else {
      _markPermanentFailure();
      _scheduleErrorState();
    }

    return _buildErrorPlaceholder();
  }

  void _markPermanentFailure() {
    final key = _stableKey;
    if (key.isNotEmpty) {
      _permanentFailures[key] = true;
      final cb = widget.onPermanentFailure;
      if (cb != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => cb(key));
      }
    }
  }

  void _scheduleErrorState({bool reload = false}) {
    if (_hasFinalizedError) return;
    _hasFinalizedError = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        loadError = true;
        preview = null;
      });
      if (reload && widget.previewUrl.isNotEmpty) {
        _loadPreview(widget.previewUrl);
      }
    });
  }

  Widget _buildTextPostContent() {
    return PreviewBoxTextContent(
      content: widget.content,
      compact: widget.compact,
      limitTextPreview: widget.limitTextPreview,
    );
  }

  Widget _buildAudioPostContent() {
    return PreviewBoxAudioContent(
      compact: widget.compact,
      isUploading: _isUploading,
      durationInSeconds: widget.durationInSeconds,
      title: widget.title,
    );
  }

  Widget _buildLoadingPlaceholder() =>
      PreviewBoxPlaceholders.loading(context);

  Widget _buildErrorPlaceholder() => PreviewBoxPlaceholders.error(
        context,
        compact: widget.compact,
        isUploading: _isUploading,
      );

  Widget _buildUploadingOverlay() =>
      PreviewBoxPlaceholders.uploadingOverlay(compact: widget.compact);

  @override
  bool get wantKeepAlive => true;
}

