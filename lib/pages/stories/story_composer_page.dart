import 'dart:typed_data';
import 'package:aurogram/widgets/ui/common_widgets.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import 'story_video_preview_io.dart'
    if (dart.library.html) 'story_video_preview_stub.dart' as video_preview;
import 'package:aurogram/models/story.dart';
import 'package:aurogram/services/story_service.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:aurogram/utils/logging/app_logger.dart';
import 'package:aurogram/utils/theme/app_dimensions.dart';

/// Story composer: camera/gallery when opened from ring; or pre-filled image bytes from "Add to Story" share.
/// Shows a preview (Instagram-like) before posting; user taps "Share to story" to upload.
class StoryComposerPage extends StatefulWidget {
  /// If non-null, use these bytes as the story image (from card capture). Otherwise show camera/gallery picker.
  final Uint8List? initialImageBytes;

  /// For reshare: sourceType e.g. 'post', 'space', 'insight'
  final String? sourceType;

  /// For reshare: sourceId
  final String? sourceId;

  const StoryComposerPage({
    super.key,
    this.initialImageBytes,
    this.sourceType,
    this.sourceId,
  });

  @override
  State<StoryComposerPage> createState() => _StoryComposerPageState();
}

class _StoryComposerPageState extends State<StoryComposerPage>
    with SingleTickerProviderStateMixin {
  final StoryService _storyService = StoryService();
  final ImagePicker _picker = ImagePicker();

  /// Preview before post: set after pick/capture or when opening with initialImageBytes.
  Uint8List? _previewBytes;
  StoryMediaType? _previewMediaType;
  VideoPlayerController? _videoController;
  Object? _tempVideoFile;

  bool _posting = false;
  String? _error;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOut,
      ),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutCubic,
      ),
    );
    _animationController.forward();

    if (widget.initialImageBytes != null) {
      _previewBytes = widget.initialImageBytes;
      _previewMediaType = StoryMediaType.image;
      AppLogger.i('StoryComposer: opened with initial image bytes',
          category: LogCategory.general,
          data: {
            'bytesLength': widget.initialImageBytes!.length,
            'sourceType': widget.sourceType,
            'sourceId': widget.sourceId,
          });
    } else {
      AppLogger.i('StoryComposer: opened in picker mode (no initial bytes)',
          category: LogCategory.general);
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _videoController?.dispose();
    _videoController = null;
    video_preview.deleteVideoPreviewFile(_tempVideoFile);
    _tempVideoFile = null;
    super.dispose();
  }

  Future<void> _showPreviewForVideo(Uint8List bytes) async {
    try {
      final result = await video_preview.createVideoControllerFromBytes(bytes);
      if (!mounted) return;
      final controller = result.$1;
      final fileToDelete = result.$2;
      if (controller != null) {
        controller.play();
        controller.setLooping(true);
      }
      if (!mounted) return;
      setState(() {
        _tempVideoFile = fileToDelete;
        _videoController = controller;
        _previewBytes = bytes;
        _previewMediaType = StoryMediaType.video;
      });
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not load video');
    }
  }

  void _clearPreview() {
    _videoController?.dispose();
    _videoController = null;
    video_preview.deleteVideoPreviewFile(_tempVideoFile);
    _tempVideoFile = null;
    setState(() {
      _previewBytes = null;
      _previewMediaType = null;
      _error = null;
    });
  }

  Future<void> _postFromPreview() async {
    if (_previewBytes == null ||
        _previewMediaType == null ||
        FirebaseAuth.instance.currentUser == null) {
      return;
    }
    setState(() {
      _posting = true;
      _error = null;
    });
    final id = await _storyService.createStory(
      bytes: _previewBytes!,
      mediaType: _previewMediaType!,
      contentType: _previewMediaType == StoryMediaType.video
          ? 'video/mp4'
          : 'image/jpeg',
      sourceType: widget.sourceType,
      sourceId: widget.sourceId,
    );
    if (!mounted) return;
    setState(() => _posting = false);
    if (id != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 20),
              const SizedBox(width: AppDimensions.spacingMd),
              const Expanded(
                child: Text(
                  'Your story was posted',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: AppTheme.successColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          ),
          margin: const EdgeInsets.all(AppDimensions.paddingLg),
        ),
      );
      Navigator.of(context).pop(true);
    } else {
      setState(() => _error = 'Failed to post story');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white, size: 20),
              const SizedBox(width: AppDimensions.spacingMd),
              const Expanded(
                child: Text(
                  'Could not post story. Try again.',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          ),
          margin: const EdgeInsets.all(AppDimensions.paddingLg),
        ),
      );
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final XFile? file = await _picker.pickImage(
      source: source,
      maxWidth: 1080,
      imageQuality: 85,
    );
    if (file == null || !mounted) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    setState(() {
      _previewBytes = bytes;
      _previewMediaType = StoryMediaType.image;
      _error = null;
    });
  }

  Future<void> _pickVideo() async {
    final XFile? file = await _picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(seconds: 15),
    );
    if (file == null || !mounted) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    await _showPreviewForVideo(bytes);
  }

  Future<void> _recordVideo() async {
    final XFile? file = await _picker.pickVideo(
      source: ImageSource.camera,
      maxDuration: const Duration(seconds: 15),
    );
    if (file == null || !mounted) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    await _showPreviewForVideo(bytes);
  }

  Widget _buildImagePreview() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        return Center(
          child: InteractiveViewer(
            minScale: 0.5,
            maxScale: 4,
            child: Image.memory(
              _previewBytes!,
              width: w > 0 ? w : null,
              height: h > 0 ? h : null,
              fit: BoxFit.contain,
              errorBuilder: (_, e, __) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.broken_image,
                        size: 64, color: Colors.white.withValues(alpha: 0.7)),
                    const SizedBox(height: AppDimensions.spacingLg),
                    Text(
                      'Could not load image',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Preview screen (Instagram-like): full-screen media + "Cancel" and "Share to story"
    if (_previewBytes != null && _previewMediaType != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded,
                color: Colors.white, size: 20),
            onPressed: _posting
                ? null
                : () {
                    _clearPreview();
                    if (widget.initialImageBytes != null) {
                      Navigator.of(context).pop();
                    }
                  },
          ),
          actions: [
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppDimensions.paddingMd, vertical: AppDimensions.paddingSm),
                  decoration: BoxDecoration(
                    color: AppTheme.errorColor.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline,
                          color: Colors.white, size: 16),
                      const SizedBox(width: AppDimensions.spacingSmMd),
                      Text(
                        _error!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        body: SafeArea(
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                child: _previewMediaType == StoryMediaType.image
                    ? _buildImagePreview()
                    : _videoController != null &&
                            _videoController!.value.isInitialized
                        ? AspectRatio(
                            aspectRatio: _videoController!.value.aspectRatio,
                            child: VideoPlayer(_videoController!),
                          )
                        : Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.videocam_rounded,
                                    size: 64,
                                    color: Colors.white.withValues(alpha: 0.7)),
                                const SizedBox(height: AppDimensions.spacingLg),
                                Text(
                                  'Video selected',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.7),
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
              ),
              // Bottom action bar with gradient
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    20,
                    20,
                    MediaQuery.of(context).padding.bottom + 20,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.95),
                        Colors.black.withValues(alpha: 0.7),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _posting
                              ? null
                              : () {
                                  _clearPreview();
                                  if (widget.initialImageBytes != null) {
                                    Navigator.of(context).pop();
                                  }
                                },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.3),
                              width: 1.5,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                            ),
                          ),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppDimensions.spacingLg),
                      Expanded(
                        flex: 2,
                        child: FilledButton.icon(
                          onPressed: _posting ? null : _postFromPreview,
                          icon: _posting
                              ? const AppLoadingIndicator(
                                  size: 20,
                                  color: Colors.white,
                                )
                              : const Icon(Icons.send_rounded, size: 22),
                          label: Text(
                            _posting ? 'Posting...' : 'Share to story',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              letterSpacing: 0.3,
                            ),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Picker screen: modern, beautiful design
    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0A0E1A) : const Color(0xFFF8F9FA),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.arrow_back_ios_rounded,
                          color: isDark ? Colors.white : Colors.black87,
                          size: 22,
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const Spacer(),
                      Text(
                        'Add to Story',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : Colors.black87,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const Spacer(),
                      const SizedBox(width: 48), // Balance for close button
                    ],
                  ),
                ),
                const SizedBox(height: AppDimensions.spacingSm),
                // Description
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'Share a moment that disappears in 24 hours',
                    style: TextStyle(
                      fontSize: 15,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.7)
                          : Colors.black.withValues(alpha: 0.6),
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const Spacer(),
                // Action buttons
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingXxl),
                  child: Column(
                    children: [
                      _ModernPickButton(
                        icon: Icons.camera_alt_rounded,
                        label: 'Camera',
                        subtitle: 'Take a photo',
                        gradient: const LinearGradient(
                          colors: [
                            AppTheme.dangerRed, // Red
                            Color(0xFFC62828), // Darker red
                          ],
                        ),
                        onTap: () => _pickImage(ImageSource.camera),
                      ),
                      const SizedBox(height: AppDimensions.spacingLg),
                      _ModernPickButton(
                        icon: Icons.photo_library_rounded,
                        label: 'Gallery',
                        subtitle: 'Choose from photos',
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.accentColor,
                            AppTheme.accentColor.withValues(alpha: 0.8),
                          ],
                        ),
                        onTap: () => _pickImage(ImageSource.gallery),
                      ),
                      const SizedBox(height: AppDimensions.spacingLg),
                      _ModernPickButton(
                        icon: Icons.videocam_rounded,
                        label: 'Record Video',
                        subtitle: 'Record up to 15 seconds',
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.grassGreen,
                            AppTheme.grassGreen.withValues(alpha: 0.8),
                          ],
                        ),
                        onTap: _recordVideo,
                      ),
                      const SizedBox(height: AppDimensions.spacingLg),
                      _ModernPickButton(
                        icon: Icons.video_library_rounded,
                        label: 'Video from Gallery',
                        subtitle: 'Choose existing video',
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.skyBlue,
                            AppTheme.skyBlue.withValues(alpha: 0.8),
                          ],
                        ),
                        onTap: _pickVideo,
                      ),
                    ],
                  ),
                ),
                const Spacer(flex: 2),
                // Info card
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                  child: Container(
                    padding: const EdgeInsets.all(AppDimensions.paddingLg),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.1)
                            : Colors.black.withValues(alpha: 0.08),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          color: AppTheme.primaryColor,
                          size: 20,
                        ),
                        const SizedBox(width: AppDimensions.spacingMd),
                        Expanded(
                          child: Text(
                            'Stories disappear after 24 hours',
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.8)
                                  : Colors.black.withValues(alpha: 0.7),
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_error != null) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                    child: Container(
                      padding: const EdgeInsets.all(AppDimensions.paddingMdLg),
                      decoration: BoxDecoration(
                        color: AppTheme.errorColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                        border: Border.all(
                          color: AppTheme.errorColor.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.error_outline_rounded,
                            color: AppTheme.errorColor,
                            size: 20,
                          ),
                          const SizedBox(width: AppDimensions.spacingMd),
                          Expanded(
                            child: Text(
                              _error!,
                              style: TextStyle(
                                fontSize: 13,
                                color: AppTheme.errorColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ModernPickButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Gradient gradient;
  final VoidCallback onTap;

  const _ModernPickButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
        child: Container(
          padding: const EdgeInsets.all(AppDimensions.paddingXl),
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
            boxShadow: [
              BoxShadow(
                color: gradient.colors.first.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppDimensions.paddingMd),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: AppDimensions.spacingLg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: AppDimensions.spacingXs),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.white.withValues(alpha: 0.8),
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
