import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/rendering.dart';
import 'package:get_thumbnail_video/index.dart';
import 'package:get_thumbnail_video/video_thumbnail.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:aurogram/services/database_service.dart';
import 'package:aurogram/utils/repository/firebase_post_repository.dart';
import 'package:aurogram/utils/logging/app_logger.dart';
import 'package:aurogram/services/data/post_db_service.dart';
import 'package:path/path.dart' as path;
import 'package:aurogram/pages/spaces/spaceScreen.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:aurogram/utils/theme/theme_helper.dart';
import 'package:aurogram/widgets/ui/skeleton_widgets.dart';

class VideoPicker extends StatefulWidget {
  final String? space;
  final int? sourceItem;
  final String? videoPath;
  final String? thumbnailPath;
  final String? replyTo;
  final VoidCallback? onUploadStarted;
  final bool isProfilePost;

  const VideoPicker({
    Key? key,
    this.space,
    this.videoPath,
    this.thumbnailPath,
    this.sourceItem,
    this.replyTo,
    this.onUploadStarted,
    this.isProfilePost = false,
  }) : super(key: key);

  @override
  VideoPickerState createState() => VideoPickerState();
}

class VideoPickerState extends State<VideoPicker> {
  File? mainVideo;
  VideoPlayerController? _controller;
  final User? user = FirebaseAuth.instance.currentUser;
  bool isPlaying = false;
  String? space;
  String? title;
  String? link; // New field for storing the link
  String? thumbnailPath;
  int status = -1;
  bool addToSpaceFeed = false;
  bool canAddToSpaceFeed = false;
  final ScrollController _scrollController = ScrollController();
  final _infoKey = GlobalKey();
  final _linkKey = GlobalKey(); // New key for link field
  final FocusNode _infoFocusNode = FocusNode();
  final FocusNode _linkFocusNode = FocusNode(); // New focus node for link field
  final picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    if (widget.videoPath == null) {
      getItem();
    } else {
      setItem(File(widget.videoPath!));

      // If a thumbnailPath was provided, use it
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
      preferredCameraDevice: CameraDevice.front, // Default to front camera
    );
    if (pickedFile == null) {
      if (mounted) Navigator.pop(context);
    } else {
      setItem(File(pickedFile.path));
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

  void setItem(File file) {
    // Dispose of previous controller if it exists
    _controller?.dispose();

    // Create and initialize the new controller with better buffering
    _controller = VideoPlayerController.file(file)
      ..setLooping(true) // Enable looping for better UX
      ..setVolume(1.0) // Ensure audio is enabled
      ..initialize().then((_) {
        if (mounted) {
          setState(() {
            mainVideo = file;
            // Preload video to reduce stuttering during playback
            _controller?.play();
            _controller?.pause();
          });
        }
      }).catchError((error) async {
        AppLogger.e(
          'Error initializing video',
          error: error,
        );
        // Retry init briefly in case file was finalizing
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
        } catch (_) {}

        // Show user-friendly error if video can't be loaded
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not load video. Please try again.')),
          );
        }
      });

    // Start creating thumbnail
    createThumbnail(file);
  }

  Future<void> createThumbnail(File videoFile) async {
    try {
      // Generate thumbnail in a temporary location using optimized settings
      dynamic thumbnailResult = await VideoThumbnail.thumbnailFile(
        video: videoFile.path,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 512, // Better quality thumbnail with reasonable size
        quality: 95, // Higher quality for better preview
        timeMs: 1000, // Take thumbnail at 1 second mark for better preview
      );

      // Handle different return types
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

      // Get a permanent directory for storing the thumbnail
      final Directory appDocDir = await getApplicationDocumentsDirectory();
      final String permanentDir =
          path.join(appDocDir.path, 'PermanentThumbnails');
      await Directory(permanentDir).create(recursive: true);

      // Generate a unique filename with timestamp and video hash to avoid collisions
      final String videoHash = videoFile.path.hashCode.toString();
      String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      String permanentThumbnailPath =
          path.join(permanentDir, 'thumb_${timestamp}_$videoHash.jpg');

      final File permanentThumbnailFile =
          await File(thumbnailFilePath).copy(permanentThumbnailPath);

      if (mounted) {
        setState(() {
          thumbnailPath =
              permanentThumbnailFile.path; // Update to permanent path
        });
      }

      AppLogger.d('Thumbnail saved to permanent location',
          category: LogCategory.media, data: {'path': permanentThumbnailPath});
    } catch (e) {
      AppLogger.e('Error saving thumbnail to permanent location',
          category: LogCategory.media, data: {'error': e.toString()});
      // Fallback to a simpler method if the first one fails
      try {
        dynamic fallbackResult = await VideoThumbnail.thumbnailFile(
          video: videoFile.path,
          imageFormat: ImageFormat.JPEG,
          maxWidth: 128,
          quality: 25,
        );

        // Handle different return types for fallback
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
        // Let the upload continue without a thumbnail
      }
    }
  }

  Future<String?> addToDatabase() async {
    if (mounted) {
      setState(() {
        status = 0;
      });
    }
    if (thumbnailPath == null ||
        (thumbnailPath != null && !File(thumbnailPath!).existsSync())) {
      await createThumbnail(mainVideo!);
    }

    // Notify that upload has started if callback is provided
    widget.onUploadStarted?.call();

    // Use the repository which handles authentication properly
    final repository = FirebasePostRepository();
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

  @override
  Widget build(BuildContext context) {
    final bool ready = _controller != null && _controller!.value.isInitialized;
    final Widget preview =
        ready ? _videoPreviewWidget() : _placeholderPreviewWidget();

    return Scaffold(
      backgroundColor: CupertinoTheme.of(context).scaffoldBackgroundColor,
      floatingActionButton: _buildFab(),
      resizeToAvoidBottomInset: true,
      body: _buildBodyWithPreview(preview),
    );
  }

  Widget _buildFab() {
    final bool controllerReady =
        _controller != null && _controller!.value.isInitialized;
    final bool thumbnailReady =
        thumbnailPath != null && File(thumbnailPath!).existsSync();
    final bool canPost = controllerReady && thumbnailReady;

    return FloatingActionButton.extended(
      onPressed: canPost ? _handleFabPress : null,
      backgroundColor: CupertinoTheme.of(context).primaryColor,
      label: _postButton(),
    );
  }

  void _handleFabPress() async {
    if (status.isInactiveOrError) {
      try {
        // Check authentication before proceeding
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) {
          // User is not authenticated, show error and navigate back
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('You need to be signed in to post videos.'),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.fixed,
              ),
            );
            // Navigate back
            Navigator.of(context).pop();
          }
          return;
        }

        // User is authenticated, proceed with post
        String? post = await addToDatabase();
        if (mounted && post != null) {
          // Ensure the post document is readable before navigating (handles propagation delays)
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
              // Small grace period; navigate anyway so UI can retry
              await Future.delayed(const Duration(milliseconds: 50));
            }
          } catch (_) {}

          // For profile posts, navigate back to root - user will see the post on their profile
          // Background upload will continue and profile will update when upload completes
          if (widget.isProfilePost) {
            Navigator.of(context).popUntil((route) => route.isFirst);
            // Show success message - the post will appear on profile with uploading indicator
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text('Video uploading to your profile...'),
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

          // For space posts, navigate to the space with the new post focused
          String? targetSpaceId = space;
          if (targetSpaceId == null || targetSpaceId.isEmpty) {
            try {
              targetSpaceId = await PostDbService().getPostSpace(post);
            } catch (_) {}
          }

          // Return to root and navigate to the space with the new post focused
          Navigator.of(context).popUntil((route) => route.isFirst);
          if (targetSpaceId != null && targetSpaceId.isNotEmpty) {
            Navigator.of(context, rootNavigator: true).push(
              MaterialPageRoute(
                builder: (context) =>
                    SpaceScreen(rid: targetSpaceId!, postId: post),
              ),
            );
          }
        } else if (mounted) {
          // Post creation failed
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to create post. Please try again.'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.fixed,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          // Show error message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: ${e.toString()}'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.fixed,
            ),
          );
        }
        AppLogger.e('Error adding post',
            category: LogCategory.general, data: {'error': e.toString()});
      }
    }
  }

  Widget _buildBodyWithPreview(Widget preview) {
    return CupertinoPageScaffold(
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
    );
  }

  Widget _placeholderPreviewWidget() {
    final size = MediaQuery.of(context).size;
    final maxH = size.height * 0.6;
    const double aspect = 9 / 16; // reasonable default while initializing
    final availableW = size.width - 20;
    final naturalHeightAtFullWidth = availableW / aspect;
    final containerH =
        naturalHeightAtFullWidth <= maxH ? naturalHeightAtFullWidth : maxH;
    final materialW =
        naturalHeightAtFullWidth <= maxH ? availableW : maxH * aspect;

    final bool hasThumb =
        thumbnailPath != null && File(thumbnailPath!).existsSync();

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
                    child: hasThumb
                        ? Image.file(
                            File(thumbnailPath!),
                            fit: BoxFit.cover,
                          )
                        : Container(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? const Color(0xFF252525)
                                    : const Color(0xFFF0EDE8),
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
    final aspect = _controller!.value.aspectRatio; // width / height
    final availableW = size.width - 20; // match recorder padding
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
                          padding: EdgeInsets.all(20),
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
