import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:aurogram/services/cache_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:aurogram/utils/dependency_injection.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:aurogram/utils/theme/header_style.dart';
import 'package:aurogram/utils/logging/app_logger.dart';

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
  final bool showNoteIcon; // whether to show note icon for text posts
  final bool
      limitTextPreview; // whether to limit text content (100 chars and remove line breaks)
  
  // Uploading state
  final bool uploading; // if true, show uploading indicator overlay
  
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
      this.showNoteIcon = false, // Note icon is no longer shown, keeping parameter for API compatibility
      this.limitTextPreview = true,
      this.uploading = false,
      this.audioUrl,
      this.durationInSeconds,
      Key? key})
      : super(key: key);

  @override
  _PreviewBoxState createState() => _PreviewBoxState();
}

class _PreviewBoxState extends State<PreviewBox>
    with AutomaticKeepAliveClientMixin {
  File? preview;
  File? authorPicture;
  bool isLoading = true;
  bool loadError = false;
  int _errorCount = 0;
  static const int _maxErrorRetries = 1; // cap retries to avoid loops
  static final Map<String, bool> _permanentFailures = {};
  static final Map<String, File> _inMemoryFiles = {};
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
            widget.postType != 'audio');
  }
  
  bool get _isAudioPost => widget.postType == 'audio';
  
  bool get _isUploading => widget.uploading;

  final CollectionReference usersCollection =
      FirebaseFirestore.instance.collection('users');
  final CollectionReference spacesCollection =
      FirebaseFirestore.instance.collection('spaces');

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
    if (preview == null && !loadError && widget.previewUrl.isNotEmpty) {
      final k = _stableKey;
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
        // Do not retry if we've already marked this URL as permanently failing
        if (_permanentFailures[_stableKey] == true) {
          if (mounted) {
            setState(() {
              isLoading = false;
              loadError = true;
            });
          }
          return;
        }
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
      if (mounted) {
        setState(() {
          loadError = true;
        });
      }
    }
  }

  Future<void> initializePreview() async {
    try {
      if (widget.author != null) {
        DocumentSnapshot authordocuments =
            await usersCollection.doc(widget.author).get();
        if (authordocuments.exists) {
          final cacheService = locator<CacheService>();
          final authorPicUrl = authordocuments['displayPicture'];
          if (authorPicUrl != null && authorPicUrl.toString().isNotEmpty) {
            authorPicture = await cacheService.getFile(authorPicUrl);
          }
        }
      }

      // Skip thumbnail loading for text posts
      if (!_isTextPost && widget.previewUrl.isNotEmpty) {
        final url = widget.previewUrl;
        
        // Handle local file paths (for uploading posts)
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

      // For uploading posts, don't mark as failure - thumbnail might still be processing
      // For text posts, we don't need to mark failure if no preview
      if (!_isTextPost && !_isUploading && preview == null && widget.previewUrl.isNotEmpty) {
        final key = _stableKey;
        if (key.isNotEmpty) {
          _permanentFailures[key] = true;
          final cb = widget.onPermanentFailure;
          if (cb != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) => cb(key));
          }
        }
      }

      if (mounted) {
        setState(() {
          isLoading = false;
        });
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
          loadError = !_isTextPost && !_isUploading; // Don't mark as error for text or uploading posts
        });
      }
      // Only mark permanent failure for non-text posts that aren't uploading
      if (!_isTextPost && !_isUploading) {
        final key = _stableKey;
        if (key.isNotEmpty) {
          _permanentFailures[key] = true;
          final cb = widget.onPermanentFailure;
          if (cb != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) => cb(key));
          }
        }
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
      if (!isLoading && (preview == null || loadError)) {
        return const SizedBox.shrink();
      }
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Use smaller border radius for compact mode (mini thumbnails in gram preview)
    // to avoid white corner artifacts from radius mismatch with parent container
    final double borderRadius = widget.compact ? 10.0 : AppHeaderStyle.cardBorderRadius;
    
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
              isLoading
                  ? (widget.hideWhileLoading
                      ? const SizedBox.shrink()
                      : _buildLoadingPlaceholder())
                  : _isAudioPost
                      ? _buildAudioPostContent()
                      : _isTextPost
                          ? _buildTextPostContent()
                          : (preview != null && !loadError)
                          ? SizedBox(
                              width: double.infinity,
                              height: double.infinity,
                              child: Image.file(
                                preview!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  AppLogger.w('Error loading preview image',
                                      category: LogCategory.ui,
                                      data: {'error': error.toString()});

                                  // If the error is related to missing file, try to reload
                                  final errorText = error.toString();
                                  final isMissingFile =
                                      error is FileSystemException ||
                                          errorText.contains('No such file');
                                  final isInvalidData =
                                      errorText.contains('Invalid image data');

                                  // For invalid/corrupt data, don't retry. Mark permanent and update after frame.
                                  if (isInvalidData) {
                                    final key = _stableKey;
                                    if (key.isNotEmpty) {
                                      _permanentFailures[key] = true;
                                      // Notify parent if provided
                                      final cb = widget.onPermanentFailure;
                                      if (cb != null) {
                                        WidgetsBinding.instance
                                            .addPostFrameCallback(
                                                (_) => cb(key));
                                      }
                                    }
                                    if (!_hasFinalizedError) {
                                      _hasFinalizedError = true;
                                      WidgetsBinding.instance
                                          .addPostFrameCallback((_) {
                                        if (mounted) {
                                          setState(() {
                                            loadError = true;
                                            preview = null;
                                          });
                                        }
                                      });
                                    }
                                  } else if (isMissingFile &&
                                      _errorCount < _maxErrorRetries) {
                                    _errorCount++;
                                    // Attempt to reload the image on the next frame (guarded)
                                    if (!_hasFinalizedError) {
                                      _hasFinalizedError = true;
                                      WidgetsBinding.instance
                                          .addPostFrameCallback((_) {
                                        if (mounted) {
                                          setState(() {
                                            loadError = true;
                                            preview = null;
                                          });
                                          if (widget.previewUrl.isNotEmpty) {
                                            _loadPreview(widget.previewUrl);
                                          }
                                        }
                                      });
                                    }
                                  } else {
                                    // Exceeded retries: mark as permanent failure and update after frame
                                    final key = _stableKey;
                                    if (key.isNotEmpty) {
                                      _permanentFailures[key] = true;
                                      final cb = widget.onPermanentFailure;
                                      if (cb != null) {
                                        WidgetsBinding.instance
                                            .addPostFrameCallback(
                                                (_) => cb(key));
                                      }
                                    }
                                    if (!_hasFinalizedError) {
                                      _hasFinalizedError = true;
                                      WidgetsBinding.instance
                                          .addPostFrameCallback((_) {
                                        if (mounted) {
                                          setState(() {
                                            loadError = true;
                                            preview = null;
                                          });
                                        }
                                      });
                                    }
                                  }

                                  return _buildErrorPlaceholder();
                                },
                                cacheWidth: 300,
                                cacheHeight: 300,
                              ),
                            )
                          : (widget.skipIfMissing
                              ? const SizedBox.shrink()
                              : _buildErrorPlaceholder()),
              if (authorPicture != null)
                Positioned(
                  top: widget.compact ? 4 : 6,
                  left: widget.compact ? 4 : 8,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.scaffoldLightColor,
                      boxShadow: widget.compact
                          ? []
                          : [
                              BoxShadow(
                                color: AppTheme.textLightColor
                                    .withValues(alpha: 0.2),
                                blurRadius: 2,
                                offset: Offset(0, 1),
                              ),
                            ],
                    ),
                    child: Material(
                      shape: CircleBorder(),
                      clipBehavior: Clip.antiAlias,
                      child: SizedBox(
                        width: widget.compact ? 12 : 22,
                        height: widget.compact ? 12 : 22,
                        child: Image.file(
                          authorPicture!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: AppTheme.primaryLightColor
                                  .withValues(alpha: 0.2),
                              child: Icon(
                                Icons.person,
                                color: AppTheme.textSecondaryLightColor,
                                size: widget.compact ? 10 : 20,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              if (widget.showPlayIcon && !isLoading && !_isUploading)
                Center(
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.85),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                ),
              // Uploading overlay - only show if we have a preview (thumbnail)
              // If no preview, the placeholder already shows uploading state
              if (_isUploading && preview != null && !loadError)
                _buildUploadingOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildTextPostContent() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Scale sizes based on compact mode
    final double padding = widget.compact ? 6.0 : 12.0;
    final double fontSize = widget.compact ? 7.5 : 12.0;

    // Match TextNotePlayer styling - warm cream background, primary text color
    // Light: warm cream (#FFFBE8), Dark: warm brown (#2A2520)
    final backgroundColor = isDark 
        ? const Color(0xFF2A2520) 
        : const Color(0xFFFFFBE8);

    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: backgroundColor,
      ),
      child: Text(
        widget.limitTextPreview ? _getPreviewText() : _getFullText(),
        style: TextStyle(
          fontSize: fontSize,
          color: AppTheme.primaryColor.withValues(alpha: 0.85),
          height: 1.35,
          fontWeight: FontWeight.w400,
        ),
        overflow: TextOverflow.fade,
        maxLines: widget.compact ? 8 : 12,
      ),
    );
  }

  /// Audio post preview - shows uploading indicator or voice icon
  Widget _buildAudioPostContent() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Match note preview colors: warm cream (light) / warm brown (dark)
    final backgroundColor = isDark 
        ? const Color(0xFF2A2520) 
        : const Color(0xFFFFFBE8);
    
    // Show uploading indicator if still uploading
    if (_isUploading) {
      return Container(
        color: backgroundColor,
        child: Center(
          child: _UploadingIndicator(
            compact: widget.compact,
            iconColor: AppTheme.primaryColor.withValues(alpha: 0.6),
            textColor: AppTheme.primaryColor.withValues(alpha: 0.7),
          ),
        ),
      );
    }
    
    // Show voice icon with duration after upload
    final iconSize = widget.compact ? 28.0 : 40.0;
    final durationFontSize = widget.compact ? 9.0 : 12.0;
    
    return Container(
      color: backgroundColor,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Voice icon in a circle
            Container(
              width: iconSize + 16,
              height: iconSize + 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primaryColor.withValues(alpha: 0.12),
              ),
              child: Icon(
                CupertinoIcons.waveform,
                color: AppTheme.primaryColor.withValues(alpha: 0.8),
                size: iconSize,
              ),
            ),
            
            // Duration display
            if (widget.durationInSeconds != null && widget.durationInSeconds! > 0) ...[
              SizedBox(height: widget.compact ? 4 : 8),
              Text(
                _formatAudioDuration(widget.durationInSeconds!),
                style: TextStyle(
                  fontSize: durationFontSize,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryColor.withValues(alpha: 0.7),
                ),
              ),
            ],
            
            // Title if available
            if (widget.title != null && widget.title!.isNotEmpty && !widget.compact) ...[
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  widget.title!,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.primaryColor.withValues(alpha: 0.6),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  String _formatAudioDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  String _getPreviewText() {
    String content = widget.content ?? '';
    if (content.trim().isEmpty) {
      return 'Empty note';
    }

    // Remove extra whitespace and newlines for preview
    content = content.replaceAll(RegExp(r'\s+'), ' ');

    // Show first 100 characters for preview
    if (content.length > 100) {
      return '${content.substring(0, 100)}...';
    }

    return content;
  }

  String _getFullText() {
    String content = widget.content ?? '';
    if (content.trim().isEmpty) {
      return 'Empty note';
    }

    return content.trim();
  }

  Widget _buildLoadingPlaceholder() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Match note preview colors: warm cream (light) / warm brown (dark)
    final backgroundColor = isDark 
        ? const Color(0xFF2A2520) 
        : const Color(0xFFFFFBE8);
    
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
      ),
    );
  }

  Widget _buildErrorPlaceholder() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // If uploading, show uploading placeholder instead of error
    if (_isUploading) {
      return _buildUploadingPlaceholder();
    }
    
    // Match note preview colors: warm cream (light) / warm brown (dark)
    final backgroundColor = isDark 
        ? const Color(0xFF2A2520) 
        : const Color(0xFFFFFBE8);
    
    // Compact mode: minimal icon
    if (widget.compact) {
      return Container(
        color: backgroundColor,
        child: Center(
          child: Icon(
            CupertinoIcons.photo,
            color: AppTheme.primaryColor.withValues(alpha: 0.4),
            size: 16,
          ),
        ),
      );
    }
    
    // Full size: show icon with text
    return Container(
      color: backgroundColor,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.photo,
              color: AppTheme.primaryColor.withValues(alpha: 0.5),
              size: 28,
            ),
            const SizedBox(height: 6),
            Text(
              'No preview',
              style: TextStyle(
                color: AppTheme.primaryColor.withValues(alpha: 0.5),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  /// Uploading placeholder - shown when post is uploading but thumbnail isn't ready yet
  Widget _buildUploadingPlaceholder() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final backgroundColor = isDark 
        ? const Color(0xFF2A2520) 
        : const Color(0xFFFFFBE8);
    
    return Container(
      color: backgroundColor,
      child: Center(
        child: _UploadingIndicator(
          compact: widget.compact,
          iconColor: AppTheme.primaryColor.withValues(alpha: 0.6),
          textColor: AppTheme.primaryColor.withValues(alpha: 0.7),
        ),
      ),
    );
  }
  
  /// Uploading overlay - shown on top of the thumbnail when uploading
  Widget _buildUploadingOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.45),
      child: Center(
        child: _UploadingIndicator(
          compact: widget.compact,
          iconColor: Colors.white.withValues(alpha: 0.95),
          textColor: Colors.white.withValues(alpha: 0.9),
        ),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}

/// Animated three dots indicator for uploading posts
class _UploadingIndicator extends StatefulWidget {
  final bool compact;
  final Color iconColor;
  final Color textColor;

  const _UploadingIndicator({
    required this.compact,
    required this.iconColor,
    required this.textColor,
  });

  @override
  State<_UploadingIndicator> createState() => _UploadingIndicatorState();
}

class _UploadingIndicatorState extends State<_UploadingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dotSize = widget.compact ? 6.0 : 8.0;
    final dotSpacing = widget.compact ? 4.0 : 6.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Animated three dots
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            return AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                // Stagger the animation for each dot
                final delay = index * 0.2;
                final progress = (_controller.value + delay) % 1.0;
                // Create a smooth pulse: fade in then out
                final opacity = progress < 0.5
                    ? 0.3 + (progress * 2 * 0.7)  // 0.3 to 1.0
                    : 1.0 - ((progress - 0.5) * 2 * 0.7);  // 1.0 to 0.3

                return Padding(
                  padding: EdgeInsets.symmetric(horizontal: dotSpacing / 2),
                  child: Opacity(
                    opacity: opacity,
                    child: Container(
                      width: dotSize,
                      height: dotSize,
                      decoration: BoxDecoration(
                        color: widget.iconColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                );
              },
            );
          }),
        ),
        // Static text (no animation)
        if (!widget.compact) ...[
          const SizedBox(height: 8),
          Text(
            'Uploading',
            style: TextStyle(
              color: widget.textColor,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
}
