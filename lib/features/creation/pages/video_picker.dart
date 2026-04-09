import 'package:aurogram/shared/presentation/widgets/media/common_widgets.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/rendering.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:aurogram/shared/services/database_service.dart';
import 'package:aurogram/features/feed/data/datasources/firebase_post_repository.dart';
import 'package:aurogram/core/logging/app_logger.dart';
import 'package:aurogram/features/feed/data/datasources/post_db_service.dart';
import 'package:aurogram/features/spaces/presentation/pages/space_screen.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/core/theme/theme_helper.dart';
import 'package:aurogram/shared/presentation/widgets/loaders/skeleton_widgets.dart';
import 'package:aurogram/shared/presentation/widgets/media/drop_zone.dart';

// Conditional imports for mobile-only features
import 'dart:io' if (dart.library.html) 'package:aurogram/platform/io_stub.dart';
import 'package:aurogram/platform/file_helper.dart' as file_helper;
import 'package:get_thumbnail_video/index.dart'
    if (dart.library.html) 'package:aurogram/platform/video_thumbnail_stub.dart';
import 'package:get_thumbnail_video/video_thumbnail.dart'
    if (dart.library.html) 'package:aurogram/platform/video_thumbnail_stub.dart';
import 'package:path_provider/path_provider.dart'
    if (dart.library.html) 'package:aurogram/platform/path_provider_stub.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';
import 'package:aurogram/shared/presentation/widgets/feedback/snack_bar_service.dart';
import 'package:path/path.dart' as path
    if (dart.library.html) 'package:aurogram/platform/path_stub.dart';

class VideoPicker extends StatefulWidget {
  final String? space;
  final int? sourceItem;
  final String? videoPath;
  final String? thumbnailPath;
  final String? replyTo;
  final VoidCallback? onUploadStarted;
  final bool isProfilePost;

  const VideoPicker({
    super.key,
    this.space,
    this.videoPath,
    this.thumbnailPath,
    this.sourceItem,
    this.replyTo,
    this.onUploadStarted,
    this.isProfilePost = false,
  });

  @override
  VideoPickerState createState() => VideoPickerState();
}

class VideoPickerState extends State<VideoPicker> {
  // Mobile: File, Web: null (use _pickedXFile instead)
  File? mainVideo;
  // Cross-platform: XFile from image_picker
  XFile? _pickedXFile;
  // Video bytes for web uploads
  Uint8List? _videoBytes;

  VideoPlayerController? _controller;
  final User? user = FirebaseAuth.instance.currentUser;
  bool isPlaying = false;
  String? space;
  String? title;
  String? link;
  String? thumbnailPath;
  // Thumbnail bytes for web
  Uint8List? _thumbnailBytes;
  int status = -1;
  bool addToSpaceFeed = false;
  bool canAddToSpaceFeed = false;
  final ScrollController _scrollController = ScrollController();
  final _infoKey = GlobalKey();
  final _linkKey = GlobalKey();
  final FocusNode _infoFocusNode = FocusNode();
  final FocusNode _linkFocusNode = FocusNode();
  final picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    if (widget.videoPath == null) {
      getItem();
    } else {
      if (kIsWeb) {
        // On web, we shouldn't receive a videoPath
        AppLogger.w('VideoPicker: videoPath provided on web, ignoring',
            category: LogCategory.media);
      } else {
        setItem(File(widget.videoPath!));
      }

      if (widget.thumbnailPath != null) {
        setState(() {
          thumbnailPath = widget.thumbnailPath;
        });
      }
    }
    getInfo();
    _infoFocusNode.addListener(_scrollToField);
    _linkFocusNode.addListener(_scrollToField);
  }

  @override
  void dispose() {
    _infoFocusNode.removeListener(_scrollToField);
    _linkFocusNode.removeListener(_scrollToField);
    _infoFocusNode.dispose();
    _linkFocusNode.dispose();
    _controller?.dispose();
    super.dispose();
  }

  void _scrollToField() {
    final FocusNode focusNode =
        FocusManager.instance.primaryFocus ?? FocusNode();
    if (focusNode == _infoFocusNode || focusNode == _linkFocusNode) {
      final GlobalKey key = focusNode == _infoFocusNode ? _infoKey : _linkKey;
      final RenderObject? renderObject = key.currentContext?.findRenderObject();
      if (renderObject != null && renderObject is RenderBox) {
        final RenderAbstractViewport viewport =
            RenderAbstractViewport.of(renderObject);
        final RevealedOffset target =
            viewport.getOffsetToReveal(renderObject, 0);

        _scrollController.animateTo(
          target.offset,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  Future<void> getItem() async {
    final XFile? pickedFile = await picker.pickVideo(
      source: widget.sourceItem == 1 ? ImageSource.gallery : ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
    );
    if (pickedFile == null) {
      if (mounted) Navigator.pop(context);
    } else {
      _pickedXFile = pickedFile;

      if (kIsWeb) {
        // On web, use the XFile directly
        await _initializeForWeb(pickedFile);
      } else {
        // On mobile, convert to File
        setItem(File(pickedFile.path));
      }
    }
  }

  /// Initialize video for web - load bytes and create network-based controller
  Future<void> _initializeForWeb(XFile xFile) async {
    try {
      // Read video bytes for later upload
      _videoBytes = await xFile.readAsBytes();

      // Dispose of previous controller if it exists
      _controller?.dispose();

      // On web, XFile.path is a blob URL that works with networkUrl
      _controller = VideoPlayerController.networkUrl(Uri.parse(xFile.path))
        ..setLooping(true)
        ..setVolume(1.0)
        ..initialize().then((_) {
          if (mounted) {
            setState(() {
              // No mainVideo on web, but mark as ready
              _controller?.play();
              _controller?.pause();
            });
          }
        }).catchError((error) {
          AppLogger.e('Error initializing video on web',
              category: LogCategory.media, error: error);
          if (mounted) {
            showCustomSnackBar(context, message: 'Could not load video. Please try again.');
          }
        });

      // On web, we skip native thumbnail generation
      // The video player will show the first frame
      AppLogger.d('Web video initialized, bytes loaded: ${_videoBytes?.length}',
          category: LogCategory.media);
    } catch (e) {
      AppLogger.e('Error initializing web video',
          category: LogCategory.media, error: e);
      if (mounted) {
        showCustomSnackBar(context, message: 'Could not load video. Please try again.');
        Navigator.pop(context);
      }
    }
  }

  Future<void> getInfo() async {
    space = widget.space;
    if (space == null && widget.replyTo != null) {
      space = await PostDbService().getPostSpace(widget.replyTo!);
    }
    if (widget.replyTo == null) addToSpaceFeed = true;
    if (space != null && widget.replyTo != null) {
      canAddToSpaceFeed =
          await DatabaseService().checkSpaceFeedPostingPermissions(space!);
    }
    if (mounted) setState(() {});
  }

  void setItem(dynamic file) {
    // This method is only called on mobile
    if (kIsWeb) return;

    // Dispose of previous controller if it exists
    _controller?.dispose();

    // Create and initialize the new controller with better buffering
    _controller = VideoPlayerController.file(file_helper.createIOFile(file.path))
      ..setLooping(true)
      ..setVolume(1.0)
      ..initialize().then((_) {
        if (mounted) {
          setState(() {
            mainVideo = file;
            _controller?.play();
            _controller?.pause();
          });
        }
      }).catchError((error) async {
        AppLogger.e('Error initializing video',
            category: LogCategory.media, error: error);
        try {
          await Future.delayed(const Duration(milliseconds: 150));
          await _controller?.initialize();
          if (mounted && _controller!.value.isInitialized) {
            setState(() {
              mainVideo = file;
              _controller?.play();
              _controller?.pause();
            });
            return;
          }
        } catch (_) {
          AppLogger.w('VideoPicker: failed to load selected video', category: LogCategory.general);
        }

        if (mounted) {
          showCustomSnackBar(context, message: 'Could not load video. Please try again.');
        }
      });

    // Start creating thumbnail (mobile only)
    createThumbnail(file);
  }

  Future<void> createThumbnail(File videoFile) async {
    // Thumbnail generation only works on mobile
    if (kIsWeb) return;

    try {
      dynamic thumbnailResult = await VideoThumbnail.thumbnailFile(
        video: videoFile.path,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 512,
        quality: 95,
        timeMs: 1000,
      );

      String? thumbnailFilePath;
      if (thumbnailResult is String) {
        thumbnailFilePath = thumbnailResult;
      } else if (thumbnailResult is XFile) {
        thumbnailFilePath = thumbnailResult.path;
      } else if (thumbnailResult != null) {
        thumbnailFilePath = thumbnailResult.toString();
      }

      if (thumbnailFilePath == null) {
        throw Exception('Failed to generate thumbnail');
      }

      final Directory appDocDir = await getApplicationDocumentsDirectory();
      final String permanentDir =
          path.join(appDocDir.path, 'PermanentThumbnails');
      await file_helper.createDirectory(permanentDir, recursive: true);

      final String videoHash = videoFile.path.hashCode.toString();
      String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      String permanentThumbnailPath =
          path.join(permanentDir, 'thumb_${timestamp}_$videoHash.jpg');

      await file_helper.copyFile(thumbnailFilePath, permanentThumbnailPath);

      if (mounted) {
        setState(() {
          thumbnailPath = permanentThumbnailPath;
        });
      }

      AppLogger.d('Thumbnail saved to permanent location',
          category: LogCategory.media, data: {'path': permanentThumbnailPath});
    } catch (e) {
      AppLogger.e('Error saving thumbnail to permanent location',
          category: LogCategory.media, data: {'error': e.toString()});
      try {
        dynamic fallbackResult = await VideoThumbnail.thumbnailFile(
          video: videoFile.path,
          imageFormat: ImageFormat.JPEG,
          maxWidth: 128,
          quality: 25,
        );

        String? fallbackThumbnailPath;
        if (fallbackResult is String) {
          fallbackThumbnailPath = fallbackResult;
        } else if (fallbackResult is XFile) {
          fallbackThumbnailPath = fallbackResult.path;
        } else if (fallbackResult != null) {
          fallbackThumbnailPath = fallbackResult.toString();
        }

        if (fallbackThumbnailPath != null && mounted) {
          setState(() {
            thumbnailPath = fallbackThumbnailPath;
          });
        }
      } catch (fallbackError) {
        AppLogger.e('Fallback thumbnail generation also failed',
            category: LogCategory.media,
            data: {'error': fallbackError.toString()});
      }
    }
  }

  Future<String?> addToDatabase() async {
    if (mounted) {
      setState(() {
        status = 0;
      });
    }

    widget.onUploadStarted?.call();

    final repository = FirebasePostRepository();

    if (kIsWeb) {
      // Web: upload using bytes
      if (_videoBytes == null) {
        AppLogger.e('Video bytes not available for web upload',
            category: LogCategory.media);
        return null;
      }

      return await repository.addSpacePostFromBytes(
        space ?? '',
        _videoBytes!,
        _thumbnailBytes, // May be null on web, that's OK
        title,
        widget.replyTo,
        addToSpaceFeed,
        link,
        isProfilePost: widget.isProfilePost,
        videoExtension: _getVideoExtension(),
      );
    } else {
      // Mobile: check thumbnail exists
      if (thumbnailPath == null ||
          (thumbnailPath != null && !File(thumbnailPath!).existsSync())) {
        await createThumbnail(mainVideo!);
      }

      return await repository.addSpacePost(
        space ?? '',
        mainVideo!.path,
        thumbnailPath ?? '',
        title,
        widget.replyTo,
        addToSpaceFeed,
        link,
        isProfilePost: widget.isProfilePost,
      );
    }
  }

  String _getVideoExtension() {
    if (_pickedXFile == null) return 'mp4';
    final name = _pickedXFile!.name.toLowerCase();
    if (name.endsWith('.mov')) return 'mov';
    if (name.endsWith('.webm')) return 'webm';
    if (name.endsWith('.avi')) return 'avi';
    return 'mp4';
  }

  /// Check if video is ready for preview
  bool get _isVideoReady {
    if (kIsWeb) {
      return _controller != null && _controller!.value.isInitialized;
    }
    return _controller != null &&
        _controller!.value.isInitialized &&
        mainVideo != null;
  }

  /// Check if ready to post
  bool get _canPost {
    if (kIsWeb) {
      // On web, we need video bytes and initialized controller
      return _videoBytes != null &&
          _controller != null &&
          _controller!.value.isInitialized;
    }
    // On mobile, need controller, video file, and thumbnail
    return _controller != null &&
        _controller!.value.isInitialized &&
        mainVideo != null &&
        thumbnailPath != null &&
        File(thumbnailPath!).existsSync();
  }

  @override
  Widget build(BuildContext context) {
    final Widget preview =
        _isVideoReady ? _videoPreviewWidget() : _placeholderPreviewWidget();

    return Scaffold(
      backgroundColor: CupertinoTheme.of(context).scaffoldBackgroundColor,
      floatingActionButton: _buildFab(),
      resizeToAvoidBottomInset: true,
      body: _buildBodyWithPreview(preview),
    );
  }

  Widget _buildFab() {
    return FloatingActionButton.extended(
      onPressed: _canPost ? _handleFabPress : null,
      backgroundColor: CupertinoTheme.of(context).primaryColor,
      label: _postButton(),
    );
  }

  void _handleFabPress() async {
    if (status.isInactiveOrError) {
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) {
          if (mounted) {
            showCustomSnackBar(context, message: 'You need to be signed in to post videos.', backgroundColor: Colors.red, behavior: SnackBarBehavior.fixed);
            Navigator.of(context).pop();
          }
          return;
        }

        String? post = await addToDatabase();
        if (mounted && post != null) {
          try {
            final postDb = PostDbService();
            bool exists = false;
            for (int i = 0; i < 6; i++) {
              final snap = await postDb.getPost(post);
              if (snap.exists) {
                exists = true;
                break;
              }
              await Future.delayed(const Duration(milliseconds: 150));
            }
            if (!exists) {
              await Future.delayed(const Duration(milliseconds: 50));
            }
          } catch (_) {
            AppLogger.w('VideoPicker: post existence check failed', category: LogCategory.general);
          }

          if (widget.isProfilePost) {
            if (!mounted) return;
            Navigator.of(context).popUntil((route) => route.isFirst);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      AppLoadingIndicator(
                        size: 16,
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                      const SizedBox(width: AppDimensions.spacingMd),
                      Text(kIsWeb
                          ? 'Video uploaded to your profile!'
                          : 'Video uploading to your profile...'),
                    ],
                  ),
                  backgroundColor: AppTheme.primaryColor,
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 3),
                ),
              );
            }
            return;
          }

          String? targetSpaceId = space;
          if (targetSpaceId == null || targetSpaceId.isEmpty) {
            try {
              targetSpaceId = await PostDbService().getPostSpace(post);
            } catch (_) {
              AppLogger.w('VideoPicker: failed to get post space', category: LogCategory.general);
            }
          }

          if (!mounted) return;
          Navigator.of(context).popUntil((route) => route.isFirst);
          if (targetSpaceId != null && targetSpaceId.isNotEmpty) {
            if (!mounted) return;
            Navigator.of(context, rootNavigator: true).push(
              MaterialPageRoute(
                builder: (context) =>
                    SpaceScreen(rid: targetSpaceId!, postId: post),
              ),
            );
          }
        } else if (mounted) {
          showCustomSnackBar(context, message: 'Failed to create post. Please try again.', backgroundColor: Colors.red, behavior: SnackBarBehavior.fixed);
        }
      } catch (e) {
        if (mounted) {
          showCustomSnackBar(context, message: 'Error: ${e.toString()}', backgroundColor: Colors.red, behavior: SnackBarBehavior.fixed);
        }
        AppLogger.e('Error adding post',
            category: LogCategory.general, data: {'error': e.toString()});
      }
    }
  }

  Widget _buildBodyWithPreview(Widget preview) {
    return DropZone(
      enabled: kIsWeb && !_isVideoReady, // Only show drop zone on web when no video
      onFileDrop: _handleFileDrop,
      acceptedMimeTypes: const ['video/*'],
      child: CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(middle: Container()),
        child: SingleChildScrollView(
          controller: _scrollController,
          child: Column(
            children: [
              preview,
              _buildSpaceFeedSwitch(),
              _getInfoField(),
              _getLinkField(),
              Container(height: 300),
            ],
          ),
        ),
      ),
    );
  }
  
  void _handleFileDrop(Uint8List bytes, String fileName) {
    if (!kIsWeb || bytes.isEmpty) return;
    
    // Store the bytes and initialize video
    _videoBytes = bytes;
    _pickedXFile = XFile.fromData(
      bytes,
      name: fileName,
      mimeType: 'video/mp4', // Default mime type
    );
    
    // Create blob URL and initialize controller
    _initializeFromDroppedBytes(bytes, fileName);
  }
  
  Future<void> _initializeFromDroppedBytes(Uint8List bytes, String fileName) async {
    try {
      // Dispose previous controller
      _controller?.dispose();
      
      // Use the XFile approach for web playback
      if (_pickedXFile != null) {
        _controller = VideoPlayerController.networkUrl(
          Uri.parse(_pickedXFile!.path),
        )
          ..setLooping(true)
          ..setVolume(1.0)
          ..initialize().then((_) {
            if (mounted) {
              setState(() {
                _controller?.play();
                _controller?.pause();
              });
            }
          }).catchError((error) {
            AppLogger.e('Error initializing dropped video',
                category: LogCategory.media, error: error);
            if (mounted) {
              showCustomSnackBar(context, message: 'Could not load video. Please try again.');
            }
          });
      }
      
      AppLogger.d('Dropped video initialized, bytes: ${_videoBytes?.length}',
          category: LogCategory.media);
    } catch (e) {
      AppLogger.e('Error initializing dropped video',
          category: LogCategory.media, error: e);
    }
  }

  Widget _placeholderPreviewWidget() {
    final size = MediaQuery.of(context).size;
    final maxH = size.height * 0.6;
    const double aspect = 9 / 16;
    final availableW = size.width - 20;
    final naturalHeightAtFullWidth = availableW / aspect;
    final containerH =
        naturalHeightAtFullWidth <= maxH ? naturalHeightAtFullWidth : maxH;
    final materialW =
        naturalHeightAtFullWidth <= maxH ? availableW : maxH * aspect;

    final bool hasThumb =
        !kIsWeb && thumbnailPath != null && File(thumbnailPath!).existsSync();

    return SizedBox(
      width: size.width,
      height: maxH,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 10.0, vertical: 10.0),
        child: Center(
          child: SizedBox(
            width: materialW,
            height: containerH,
            child: Material(
              elevation: 5,
              borderRadius: BorderRadius.circular(18),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.passthrough,
                children: [
                  AspectRatio(
                    aspectRatio: aspect,
                    child: hasThumb && !kIsWeb
                        ? Image.file(
                            file_helper.createIOFile(thumbnailPath!),
                            fit: BoxFit.cover,
                          )
                        : Container(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? AppTheme.darkPlaceholder
                                    : AppTheme.skeletonLightColor,
                            child: const AppLoadingIndicator(),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _getInfoField() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 10.0),
      child: CupertinoTextField(
        key: _infoKey,
        focusNode: _infoFocusNode,
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        prefix: Padding(
          padding: const EdgeInsets.only(left: 8.0),
          child: Icon(
            CupertinoIcons.info,
            size: 22,
            color: AppTheme.primaryLightColor,
          ),
        ),
        placeholder: "Add information about the post (optional)",
        placeholderStyle: TextStyle(
          color: AppTheme.textSecondaryLightColor,
          fontWeight: FontWeight.w400,
          fontSize: 16,
        ),
        style: TextStyle(
          color: AppTheme.textLightColor,
          fontSize: 16,
        ),
        minLines: 2,
        decoration: BoxDecoration(
          color: AppTheme.scaffoldLightColor,
          borderRadius: BorderRadius.circular(12.0),
          border: Border.all(
            color: _infoFocusNode.hasFocus
                ? AppTheme.primaryColor
                : AppTheme.primaryLightColor,
            width: 1.0,
          ),
        ),
        onChanged: (value) => {if (mounted) setState(() => title = value)},
        clearButtonMode: OverlayVisibilityMode.editing,
        keyboardType: TextInputType.multiline,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => FocusScope.of(context).unfocus(),
        maxLines: null,
      ),
    );
  }

  Widget _getLinkField() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 10.0),
      child: CupertinoTextField(
        key: _linkKey,
        focusNode: _linkFocusNode,
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        prefix: Padding(
          padding: const EdgeInsets.only(left: 8.0),
          child: Icon(
            CupertinoIcons.link,
            size: 22,
            color: AppTheme.primaryLightColor,
          ),
        ),
        placeholder: "Add a link in the post (optional)",
        placeholderStyle: TextStyle(
          color: AppTheme.textSecondaryLightColor,
          fontWeight: FontWeight.w400,
          fontSize: 16,
        ),
        style: TextStyle(
          color: AppTheme.textLightColor,
          fontSize: 16,
        ),
        decoration: BoxDecoration(
          color: AppTheme.scaffoldLightColor,
          borderRadius: BorderRadius.circular(12.0),
          border: Border.all(
            color: _linkFocusNode.hasFocus
                ? AppTheme.primaryColor
                : AppTheme.primaryLightColor,
            width: 1.0,
          ),
        ),
        onChanged: (value) => {if (mounted) setState(() => link = value)},
        clearButtonMode: OverlayVisibilityMode.editing,
        keyboardType: TextInputType.url,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => FocusScope.of(context).unfocus(),
      ),
    );
  }

  Widget _videoPreviewWidget() {
    final size = MediaQuery.of(context).size;
    final maxH = size.height * 0.6;
    final aspect = _controller!.value.aspectRatio;
    final availableW = size.width - 20;
    final naturalHeightAtFullWidth = availableW / aspect;
    final containerH =
        naturalHeightAtFullWidth <= maxH ? naturalHeightAtFullWidth : maxH;
    final materialW =
        naturalHeightAtFullWidth <= maxH ? availableW : maxH * aspect;

    return SizedBox(
      width: size.width,
      height: maxH,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 10.0, vertical: 10.0),
        child: Center(
          child: SizedBox(
            width: materialW,
            height: containerH,
            child: Material(
              elevation: 5,
              borderRadius: BorderRadius.circular(18),
              clipBehavior: Clip.antiAlias,
              child: GestureDetector(
                onTap: _togglePlay,
                child: Stack(
                  fit: StackFit.passthrough,
                  children: [
                    AspectRatio(
                      aspectRatio: aspect,
                      child: VideoPlayer(
                        _controller!,
                        key: UniqueKey(),
                      ),
                    ),
                    if (!isPlaying)
                      Center(
                        child: Container(
                          padding: EdgeInsets.all(AppDimensions.paddingXl),
                          decoration: BoxDecoration(
                            color:
                                AppTheme.textLightColor.withValues(alpha: 0.5),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            CupertinoIcons.play_fill,
                            color: AppTheme.scaffoldLightColor,
                            size: 50,
                          ),
                        ),
                      ),
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: VideoProgressIndicator(
                        _controller!,
                        allowScrubbing: true,
                        padding: EdgeInsets.zero,
                        colors: VideoProgressColors(
                            playedColor: AppTheme.primaryColor),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSpaceFeedSwitch() {
    return canAddToSpaceFeed
        ? Card(
            margin:
                const EdgeInsets.symmetric(horizontal: 10.0, vertical: 10.0),
            elevation: 0.5,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.0),
              side: BorderSide(color: AppTheme.primaryLightColor, width: 1),
            ),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
              child: Row(
                children: [
                  Icon(Icons.feed, color: AppTheme.primaryColor, size: 18),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10.0),
                      child: Text(
                        "Add post to group's feed",
                        style: ThemeHelper.bodyTextStyle,
                      ),
                    ),
                  ),
                  CupertinoSwitch(
                    value: addToSpaceFeed,
                    activeTrackColor: AppTheme.primaryColor,
                    onChanged: (value) =>
                        {if (mounted) setState(() => addToSpaceFeed = value)},
                  ),
                ],
              ),
            ),
          )
        : const SizedBox.shrink();
  }

  Widget _postButton() {
    switch (status) {
      case -1:
        return Padding(
          padding: EdgeInsets.all(8.0),
          child: Text(
            "Post",
            style: TextStyle(fontSize: 15, color: AppTheme.scaffoldLightColor),
          ),
        );
      case 0:
        return PulsingDots(color: AppTheme.scaffoldLightColor, size: 6);
      case 1:
        return Icon(CupertinoIcons.check_mark, color: AppTheme.successColor);
      case 2:
        return Text(
          "Try Again",
          style: TextStyle(fontSize: 15, color: AppTheme.errorColor),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  void _togglePlay() {
    if (mounted) {
      setState(() {
        if (isPlaying) {
          _controller?.pause();
        } else {
          _controller?.play();
        }
        isPlaying = !isPlaying;
      });
    }
  }
}

extension on int {
  bool get isInactiveOrError => this == -1 || this == 2;
}
