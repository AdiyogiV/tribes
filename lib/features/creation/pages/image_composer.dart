import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:aurogram/shared/services/database_service.dart';
import 'package:aurogram/shared/services/media/media_storage_service.dart';
import 'package:aurogram/features/feed/data/datasources/post_db_service.dart';
import 'package:aurogram/core/logging/app_logger.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/core/di/injection.dart';
import 'package:aurogram/shared/presentation/widgets/feedback/snack_bar_service.dart'
    show showCustomSnackBar;
import 'package:aurogram/shared/presentation/widgets/loaders/skeleton_widgets.dart';

import 'package:aurogram/core/theme/app_dimensions.dart';

// Conditional import for dart:io
import 'dart:io'
    if (dart.library.html) 'package:aurogram/platform/io_stub.dart';

class ImageComposer extends StatefulWidget {
  final String space;
  final String? replyTo;
  final bool isProfilePost;
  final int? sourceItem; // 0 for camera, 1 for gallery

  const ImageComposer({
    super.key,
    required this.space,
    this.replyTo,
    this.isProfilePost = false,
    this.sourceItem,
  });

  @override
  ImageComposerState createState() => ImageComposerState();
}

class ImageComposerState extends State<ImageComposer> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _linkController = TextEditingController();
  final PostDbService _postDbService = locator<PostDbService>();
  final MediaStorageService _storageService = MediaStorageService();
  final User? user = FirebaseAuth.instance.currentUser;

  XFile? _pickedImage;
  Uint8List? _imageBytes;
  File? _imageFile;
  bool _isLoading = false;
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  bool addToSpaceFeed = true;
  bool canAddToSpaceFeed = false;
  String? space;

  final picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _initializeSpaceFeedSettings();
    _pickImage();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _linkController.dispose();
    super.dispose();
  }

  Future<void> _initializeSpaceFeedSettings() async {
    space = widget.space;

    // For new posts (not replies), default to adding to space feed
    if (widget.replyTo == null) {
      addToSpaceFeed = true;
    }

    // Check if user has permission to post to space feed for replies
    if (space != null && widget.replyTo != null) {
      canAddToSpaceFeed =
          await DatabaseService().checkSpaceFeedPostingPermissions(space!);
    }

    if (mounted) setState(() {});
  }

  Future<void> _pickImage() async {
    setState(() => _isLoading = true);

    try {
      // Use camera if sourceItem is 0, otherwise use gallery
      final imageSource =
          widget.sourceItem == 0 ? ImageSource.camera : ImageSource.gallery;

      final XFile? image = await picker.pickImage(
        source: imageSource,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 85,
      );

      if (image != null) {
        _pickedImage = image;

        // Load bytes for preview
        if (kIsWeb) {
          _imageBytes = await image.readAsBytes();
        } else {
          _imageFile = File(image.path);
        }

        if (mounted) setState(() {});
      } else {
        // User cancelled, go back
        if (mounted) Navigator.of(context).pop();
      }
    } catch (e) {
      AppLogger.e('Error picking image', category: LogCategory.media, error: e);
      if (mounted) {
        showCustomSnackBar(
          context,
          message: 'Failed to pick image',
          backgroundColor: AppTheme.errorColor,
        );
        Navigator.of(context).pop();
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  bool _isValid() {
    return _pickedImage != null && !_isUploading;
  }

  Future<void> _handlePost() async {
    if (!_isValid() || user == null) return;

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
    });

    try {
      // Determine effective space (for profile posts, use user ID)
      String effectiveSpace =
          widget.isProfilePost ? user!.uid : space ?? widget.space;

      // Upload image to Firebase Storage
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = _pickedImage!.name.split('.').last.toLowerCase();
      final storagePath = 'images/${user!.uid}/$timestamp.$extension';

      String? imageUrl = await _storageService.uploadFromXFile(
        _pickedImage!,
        storagePath,
        onProgress: (progress) {
          if (mounted) {
            setState(() => _uploadProgress = progress);
          }
        },
      );

      if (imageUrl == null) {
        throw Exception('Failed to upload image');
      }

      // Create post document
      String? postId = await _postDbService.createImagePostDocument(
        space: effectiveSpace,
        imageUrl: imageUrl,
        title: _titleController.text.trim().isNotEmpty
            ? _titleController.text.trim()
            : null,
        replyTo: widget.replyTo,
        link: _linkController.text.trim().isNotEmpty
            ? _linkController.text.trim()
            : null,
        addToSpaceFeed: addToSpaceFeed,
        isProfilePost: widget.isProfilePost,
      );

      if (postId != null && mounted) {
        showCustomSnackBar(
          context,
          message: 'Image posted successfully!',
          backgroundColor: AppTheme.primaryColor,
        );
        Navigator.of(context).pop();
      } else {
        throw Exception('Failed to create post');
      }
    } catch (e) {
      AppLogger.e('Error posting image',
          category: LogCategory.general, error: e);
      if (mounted) {
        showCustomSnackBar(
          context,
          message: 'Failed to post image. Please try again.',
          backgroundColor: AppTheme.errorColor,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadProgress = 0.0;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        backgroundColor:
            isDark ? AppTheme.scaffoldDarkColor : AppTheme.scaffoldLightColor,
        middle:
            Text(widget.replyTo == null ? 'Post Image' : 'Reply with Image'),
        leading: CupertinoNavigationBarBackButton(
          onPressed: () => Navigator.of(context).pop(),
        ),
        trailing: _isUploading
            ? const PulsingDots(size: 6)
            : CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _isValid() ? _handlePost : null,
                child: Text(
                  'Post',
                  style: TextStyle(
                    color: _isValid()
                        ? AppTheme.primaryColor
                        : CupertinoColors.inactiveGray,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
      ),
      child: SafeArea(
        child: _isLoading
            ? Center(child: CupertinoActivityIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Image preview
                    if (_pickedImage != null) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                        child: Container(
                          width: double.infinity,
                          constraints: BoxConstraints(
                            maxHeight: 500,
                          ),
                          child: kIsWeb && _imageBytes != null
                              ? Image.memory(
                                  _imageBytes!,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                )
                              : !kIsWeb && _imageFile != null
                                  ? Image.file(
                                      _imageFile! as dynamic,
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                    )
                                  : Container(
                                      height: 200,
                                      color: Colors.grey[300],
                                    ),
                        ),
                      ),
                      const SizedBox(height: AppDimensions.spacingLg),

                      // Change image button
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CupertinoButton(
                            padding: EdgeInsets.zero,
                            onPressed: _isUploading ? null : _pickImage,
                            child: Text(
                              'Change Image',
                              style: TextStyle(
                                color: AppTheme.primaryColor,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppDimensions.spacingLg),
                    ],

                    // Title input
                    CupertinoTextField(
                      controller: _titleController,
                      placeholder: 'Title (optional)',
                      enabled: !_isUploading,
                      padding: const EdgeInsets.all(AppDimensions.paddingMd),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppTheme.primaryColor.withValues(alpha: 0.08)
                            : AppTheme.primaryLightColor
                                .withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                      ),
                      style: TextStyle(
                        color: isDark ? Colors.white : AppTheme.textLightColor,
                      ),
                      maxLength: 100,
                    ),
                    const SizedBox(height: AppDimensions.spacingMd),

                    // Link input
                    CupertinoTextField(
                      controller: _linkController,
                      placeholder: 'Add link (optional)',
                      enabled: !_isUploading,
                      padding: const EdgeInsets.all(AppDimensions.paddingMd),
                      keyboardType: TextInputType.url,
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppTheme.primaryColor.withValues(alpha: 0.08)
                            : AppTheme.primaryLightColor
                                .withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                      ),
                      style: TextStyle(
                        color: isDark ? Colors.white : AppTheme.textLightColor,
                      ),
                    ),
                    const SizedBox(height: AppDimensions.spacingLg),

                    // Space feed toggle (for replies only)
                    if (widget.replyTo != null && canAddToSpaceFeed) ...[
                      Row(
                        children: [
                          CupertinoSwitch(
                            value: addToSpaceFeed,
                            onChanged: _isUploading
                                ? null
                                : (value) =>
                                    setState(() => addToSpaceFeed = value),
                            activeTrackColor: AppTheme.primaryColor,
                          ),
                          const SizedBox(width: AppDimensions.spacingMd),
                          Expanded(
                            child: Text(
                              'Also add to space feed',
                              style: TextStyle(
                                color: isDark
                                    ? Colors.white
                                    : AppTheme.textLightColor,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppDimensions.spacingLg),
                    ],

                    // Upload progress
                    if (_isUploading) ...[
                      const SizedBox(height: AppDimensions.spacingLg),
                      Column(
                        children: [
                          LinearProgressIndicator(
                            value: _uploadProgress / 100,
                            backgroundColor: isDark
                                ? Colors.white.withValues(alpha: 0.1)
                                : AppTheme.primaryColor.withValues(alpha: 0.1),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppTheme.primaryColor,
                            ),
                          ),
                          const SizedBox(height: AppDimensions.spacingSm),
                          Text(
                            '${_uploadProgress.toStringAsFixed(0)}%',
                            style: TextStyle(
                              color: AppTheme.primaryColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}
