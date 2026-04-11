import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:aurogram/shared/services/media/media_compression_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:aurogram/features/spaces/domain/space_service.dart';
import 'package:aurogram/shared/models/space.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:aurogram/features/feed/presentation/widgets/post.dart';
import 'package:aurogram/shared/presentation/widgets/loaders/skeleton_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io';
import 'package:aurogram/core/logging/app_logger.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/core/theme/theme_helper.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';

class UploadProgressTracker extends StatelessWidget {
  final MediaCompressionService compressionService;
  final bool fullScreenMode;
  final VoidCallback? onAllComplete;
  final BuildContext context;

  const UploadProgressTracker({
    super.key,
    required this.compressionService,
    this.fullScreenMode = false,
    this.onAllComplete,
    required this.context,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _createProgressStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: PulsingDots(size: 10));
        }

        if (snapshot.hasError) {
          // Show error state
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 50,
                  color: AppTheme.errorColor,
                ),
                SizedBox(height: AppDimensions.spacingLg),
                Text(
                  'Error loading uploads',
                  style: ThemeHelper.subheadingStyle.copyWith(
                    color: AppTheme.textLightColor,
                  ),
                ),
                SizedBox(height: AppDimensions.spacingSm),
                Text(
                  snapshot.error.toString(),
                  style: ThemeHelper.bodyTextStyle.copyWith(
                    color: AppTheme.textSecondaryLightColor,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        final uploads = snapshot.data ?? [];

        if (uploads.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.cloud_upload_outlined,
                  size: 80,
                  color: AppTheme.textSecondaryLightColor,
                ),
                SizedBox(height: AppDimensions.spacingLg),
                Text(
                  'No uploads in progress',
                  style: ThemeHelper.subheadingStyle.copyWith(
                    color: AppTheme.textLightColor,
                  ),
                ),
                SizedBox(height: AppDimensions.spacingSm),
                Text(
                  'Your video uploads will appear here',
                  style: ThemeHelper.bodyTextStyle.copyWith(
                    color: AppTheme.textSecondaryLightColor,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: uploads.length,
          padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          itemBuilder: (context, index) {
            final progress = uploads[index];
            final spaceId = progress['space'];

            return _UploadCard(
              progress: progress,
              spaceId: spaceId,
            );
          },
        );
      },
    );
  }

  // Create a stream that updates every second with the latest progress
  Stream<List<Map<String, dynamic>>> _createProgressStream() {
    // Create a stream controller
    final controller = StreamController<List<Map<String, dynamic>>>();

    // Track completed uploads to avoid duplicate navigation
    Map<String, bool> processedUploads = {};
    // Track stuck uploads
    Map<String, int> stuckProgressCounts = {};

    // Flag to prevent navigation right after app startup
    bool isColdStart = true;

    // Store last progress values to detect stuck uploads
    Map<String, int> lastProgressValues = {};

    // Map to track uploads that have been marked as failed
    Map<String, bool> markedAsFailed = {};

    // Initialize with first data
    compressionService.getUploadProgress().then((progress) {
      if (!controller.isClosed) {
        controller.add(progress);

        // Initialize last progress tracking
        for (var item in progress) {
          if (item['postId'] != null) {
            lastProgressValues[item['postId']] = item['progress'] ?? 0;

            // Mark any completed uploads as already processed at startup
            final status = item['status']?.toString() ?? '';
            if (status == 'completed') {
              processedUploads[item['postId']] = true;
              AppLogger.d(
                  'Marking already completed upload as processed at startup',
                  category: LogCategory.general,
                  data: {'postId': item['postId']});
            }
          }
        }

        // After 5 seconds, cold start period ends - speed up the startup time
        Future.delayed(Duration(seconds: 5), () {
          isColdStart = false;
          AppLogger.d('Cold start period ended, regular navigation enabled',
              category: LogCategory.general);
        });
      }
    });

    // TRULY EVENT-DRIVEN: Listen to MediaCompressionService progress stream (NO TIMERS!)
    StreamSubscription? progressSubscription;

    // Subscribe to real-time progress events from MediaCompressionService
    progressSubscription =
        compressionService.progressStream.listen((event) async {
      if (controller.isClosed) {
        progressSubscription?.cancel();
        return;
      }

      try {
        // Get current upload progress to build complete list
        final progress = await compressionService.getUploadProgress();

        // Process progress items to mark stuck uploads as failed
        List<Map<String, dynamic>> updatedProgress = [];
        for (var item in List<Map<String, dynamic>>.from(progress)) {
          final postId = item['postId'];

          // If an upload is already marked as failed, keep it marked
          if (postId != null &&
              markedAsFailed.containsKey(postId) &&
              markedAsFailed[postId] == true) {
            // Create a copy with failed status
            Map<String, dynamic> failedItem = Map<String, dynamic>.from(item);
            failedItem['status'] = 'failed';
            failedItem['error'] = 'Upload timed out or became stuck';
            updatedProgress.add(failedItem);
          } else {
            updatedProgress.add(item);
          }
        }

        controller.add(updatedProgress);

        // Check for newly completed uploads (but don't navigate)
        if (!isColdStart) {
          for (var item in updatedProgress) {
            final postId = item['postId'];
            final status = item['status']?.toString() ?? '';
            final currentProgress = item['progress'] ?? 0;

            // Skip if missing critical information
            if (postId == null) continue;

            // Detect stuck uploads
            if (lastProgressValues.containsKey(postId)) {
              final lastProgress = lastProgressValues[postId] ?? 0;

              // If progress hasn't changed for 10 consecutive checks (3 seconds with new 300ms interval)
              // and progress is not at 0% or 100%, consider it potentially stuck
              if (lastProgress == currentProgress &&
                  currentProgress > 0 &&
                  currentProgress < 100 &&
                  status != 'completed' &&
                  status != 'failed') {
                stuckProgressCounts[postId] =
                    (stuckProgressCounts[postId] ?? 0) + 1;

                // After 15 seconds of no progress change (50 checks with 300ms interval), mark as failed
                if (stuckProgressCounts[postId]! > 50) {
                  AppLogger.w('Upload stuck, marking as failed',
                      category: LogCategory.general,
                      data: {'postId': postId, 'progress': currentProgress});

                  // Mark as failed in our local tracking
                  markedAsFailed[postId] = true;

                  // Mark as processed to prevent future processing
                  processedUploads[postId] = true;

                  // Update this upload's status in the compression service
                  compressionService.updateUploadStatus(postId, 'failed',
                      error:
                          'Upload became stuck at $currentProgress% and timed out');
                }
              } else {
                // Reset counter if progress changes
                stuckProgressCounts[postId] = 0;
              }

              // Update last progress value
              lastProgressValues[postId] = currentProgress;
            } else {
              lastProgressValues[postId] = currentProgress;
            }

            // If this is a newly completed upload, just mark it as processed
            if (status == 'completed' &&
                !processedUploads.containsKey(postId)) {
              // Mark as processed to avoid duplicates
              processedUploads[postId] = true;

              AppLogger.d('Upload completed (no navigation)',
                  category: LogCategory.general, data: {'postId': postId});
            }
          }
        }

        // Check if all uploads are complete and call callback if needed
        bool allComplete = updatedProgress.isNotEmpty;
        for (var item in updatedProgress) {
          final status = item['status']?.toString() ?? '';
          if (status != 'completed' &&
              status != 'failed' &&
              status != 'cancelled') {
            allComplete = false;
            break;
          }
        }

        if (allComplete &&
            updatedProgress.isNotEmpty &&
            onAllComplete != null) {
          progressSubscription?.cancel();
          onAllComplete!();
        }
      } catch (e) {
        AppLogger.e('Error processing upload progress event',
            category: LogCategory.general, error: e);
      }
    }, onError: (e) {
      AppLogger.e('Error in upload progress stream',
          category: LogCategory.general, error: e);
    });

    // Return a stream that closes the controller when done
    return controller.stream.asBroadcastStream(
      onCancel: (_) {
        progressSubscription?.cancel();
        controller.close();
      },
    );
  }
}

class _UploadCard extends StatefulWidget {
  final Map<String, dynamic> progress;
  final String? spaceId;

  const _UploadCard({
    required this.progress,
    this.spaceId,
  });

  @override
  State<_UploadCard> createState() => _UploadCardState();
}

class _UploadCardState extends State<_UploadCard> {
  Space? space;
  bool isLoading = true;
  Map<String, dynamic>? replyData;
  bool loadingReplyData = false;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ARCHITECTURE FIX: Instance-based tracking instead of static (prevents memory leaks and architectural violations)
  int _noChangeCounter = 0;
  int _lastProgress = -1; // Initialize to -1 to detect first progress update
  DateTime? _lastUpdated;
  static const int _maxStuckChecks =
      10; // Consider upload stuck after this many checks with no progress
  static const Duration _stuckUploadTimeout =
      Duration(minutes: 5); // Mark as failed after this time with no progress

  @override
  void initState() {
    super.initState();
    _loadSpaceDetails();
    _fetchReplyToPost();
    _progressStream = _createProgressStream();
  }

  late Stream<Map<String, dynamic>?> _progressStream;

  Stream<Map<String, dynamic>?> _createProgressStream() {
    // Convert a periodic stream into a stream of upload progress data
    return Stream.periodic(const Duration(seconds: 2)).asyncMap((_) async {
      final prefs = await SharedPreferences.getInstance();
      Map<String, dynamic> progressMap = {};

      // Default to empty map if no data exists
      final String? progressData = prefs.getString('uploadProgress');
      if (progressData != null) {
        progressMap = json.decode(progressData) as Map<String, dynamic>;
      }

      final uploadData =
          progressMap[widget.progress['postId']] as Map<String, dynamic>?;

      // Check for stuck uploads
      if (uploadData != null) {
        final currentProgress = uploadData['progress'] as int? ?? 0;
        final currentStatus = uploadData['status'] as String? ?? '';

        // Skip completed or failed uploads
        if (currentStatus != 'completed' && currentStatus != 'failed') {
          // Initialize tracking for this upload instance if needed
          if (_lastProgress == -1) {
            _lastProgress = currentProgress;
            _noChangeCounter = 0;
            _lastUpdated = DateTime.now();
          } else {
            // Check if progress has changed
            if (_lastProgress == currentProgress) {
              _noChangeCounter++;

              // Check if upload has been stuck for too long
              final timeSinceUpdate =
                  DateTime.now().difference(_lastUpdated ?? DateTime.now());

              // If stuck for too long, mark as failed
              if (_noChangeCounter >= _maxStuckChecks ||
                  timeSinceUpdate > _stuckUploadTimeout) {
                AppLogger.w('Upload appears to be stuck - marking as failed',
                    category: LogCategory.general,
                    data: {
                      'postId': widget.progress['postId'],
                      'noChangeCount': _noChangeCounter,
                      'timeSinceUpdate': timeSinceUpdate.inSeconds,
                      'lastProgress': _lastProgress,
                      'currentProgress': currentProgress
                    });

                // Update the upload status to failed in the progress map
                uploadData['status'] = 'failed';
                uploadData['error'] = 'Upload stuck - no progress detected';
                uploadData['timestamp'] = DateTime.now().millisecondsSinceEpoch;
                await prefs.setString(
                    'uploadProgress', json.encode(progressMap));

                // Reset counters for this instance
                _lastProgress = -1;
                _noChangeCounter = 0;
                _lastUpdated = null;
              }
            } else {
              // Progress changed, reset stuck counter for this instance
              _lastProgress = currentProgress;
              _noChangeCounter = 0;
              _lastUpdated = DateTime.now();
            }
          }
        }
      }

      return uploadData;
    }).asBroadcastStream();
  }

  // Fetch the post this upload is replying to, if any
  void _fetchReplyToPost() async {
    if (!mounted) return;

    final postId = widget.progress['postId'];
    if (postId == null) return;

    setState(() {
      loadingReplyData = true;
    });

    try {
      // Get post document to check if it's a reply
      final postDoc = await _firestore.collection('posts').doc(postId).get();

      if (!postDoc.exists) {
        if (mounted) {
          setState(() {
            loadingReplyData = false;
          });
        }
        return;
      }

      // Check if this post is a reply to another post
      final Map<String, dynamic>? postData =
          postDoc.data();
      final String? replyToPostId = postData?['replyTo'] as String?;

      if (replyToPostId == null || replyToPostId.isEmpty) {
        if (mounted) {
          setState(() {
            loadingReplyData = false;
          });
        }
        return;
      }

      // Fetch the original post that was replied to
      final originalDoc =
          await _firestore.collection('posts').doc(replyToPostId).get();

      if (!originalDoc.exists) {
        if (mounted) {
          setState(() {
            loadingReplyData = false;
          });
        }
        return;
      }

      // Get author details of the original post
      final Map<String, dynamic>? originalData =
          originalDoc.data();
      final String? authorId = originalData?['author'] as String?;
      String authorName = 'Unknown User';
      String? authorDp;

      if (authorId != null && authorId.isNotEmpty) {
        final authorDoc =
            await _firestore.collection('users').doc(authorId).get();
        if (authorDoc.exists) {
          authorName = authorDoc.get('name') as String? ?? 'Unknown User';
          authorDp = authorDoc.get('displayPicture') as String?;
        }
      }

      // Extract content and image from original post
      final String originalContent = originalData?['title'] as String? ?? '';
      final String? originalImage = originalData?['thumbnail'] as String?;

      // Build reply data
      final replyInfo = {
        'replyTo': replyToPostId,
        'replyToAuthorName': authorName,
        'replyToAuthorId': authorId,
        'replyToAuthorDp': authorDp,
        'replyToContent': originalContent,
        'replyToImageUrl': originalImage,
      };

      if (mounted) {
        setState(() {
          replyData = replyInfo;
          loadingReplyData = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          loadingReplyData = false;
        });
      }
    }
  }

  Future<void> _loadSpaceDetails() async {
    if (widget.spaceId == null || widget.spaceId!.isEmpty) {
      setState(() {
        isLoading = false;
      });
      return;
    }

    try {
      final spaceService = SpaceService();
      final spaceDetails = await spaceService.getSpace(widget.spaceId!);

      if (mounted) {
        setState(() {
          space = spaceDetails;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // For failed uploads, get the data directly from widget.progress to prevent blinking
    final status = widget.progress['status'] as String? ?? '';

    // Special handling for failed uploads - don't use StreamBuilder to avoid blinking
    if (status == 'failed') {
      final errorMsg = widget.progress['error'] as String? ?? 'Upload failed';
      final thumbnailUrl = widget.progress['thumbnailPath'] as String?;
      final postId = widget.progress['postId'] as String? ?? '';

      // Display error state without any navigation or callbacks
      return _buildErrorCard(postId, widget.spaceId, errorMsg, thumbnailUrl);
    }

    // For other uploads (in progress, completed), use the StreamBuilder to enable updates
    return StreamBuilder<Map<String, dynamic>?>(
      stream: _progressStream,
      initialData: widget.progress,
      builder: (context, snapshot) {
        // If there's no data, show the card with the current progress
        if (!snapshot.hasData || snapshot.data == null) {
          final percentComplete = widget.progress['progress'] as int? ?? 0;
          return _buildUploadCard(widget.progress, percentComplete, status);
        }

        // Use the data from the stream
        final progress = snapshot.data!;
        final updatedStatus = progress['status'] as String? ?? status;
        final percentComplete = progress['progress'] as int? ?? 0;

        // Just show the card with updated status - no navigation
        return _buildUploadCard(progress, percentComplete, updatedStatus);
      },
    );
  }

  // Navigate to post page within its space
  void _navigateToPost(String postId) {
    if (postId.isEmpty) return;

    // Get space ID from the progress object
    final spaceId = widget.spaceId;

    if (spaceId != null && spaceId.isNotEmpty) {
      // Navigate to the space screen with the post ID to show that specific post
      context.push('/space/$spaceId', extra: postId);
    } else {
      // Fallback if space ID is not available - navigate to post directly
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => Scaffold(
            appBar: AppBar(
              title: Text('Post'),
              backgroundColor: CupertinoTheme.of(context).barBackgroundColor,
              leading: IconButton(
                icon: Icon(Icons.arrow_back_ios),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            body: Post(post: postId),
          ),
        ),
      );
    }
  }


  String _formatTime(dynamic time) {
    if (time == null) return 'Unknown time';
    try {
      final DateTime dateTime = time is DateTime
          ? time
          : time is String
              ? DateTime.parse(time)
              : DateTime.fromMillisecondsSinceEpoch(time is int ? time : 0);

      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inSeconds < 60) {
        return 'just now';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes}m ago';
      } else if (difference.inHours < 24) {
        return '${difference.inHours}h ago';
      } else {
        return '${difference.inDays}d ago';
      }
    } catch (_) {
      AppLogger.w('Time format error',
          category: LogCategory.general, data: {'time': time});
      return 'Unknown date';
    }
  }


  Widget _buildErrorCard(
      String? postId, String? spaceId, String errorMsg, String? thumbnailUrl) {
    return Card(
      margin: EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        side: BorderSide(color: AppTheme.errorColor.withValues(alpha: 0.5), width: 1),
      ),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Thumbnail with error overlay
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                    color: AppTheme.scaffoldLightColor,
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Thumbnail
                      if (thumbnailUrl != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                          child: thumbnailUrl.startsWith('http')
                              ? CachedNetworkImage(
                                  imageUrl: thumbnailUrl,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => ShimmerImagePlaceholder(
                                    borderRadius: 8,
                                  ),
                                  errorWidget: (context, url, error) => Icon(
                                    Icons.image_not_supported,
                                    color: AppTheme.textSecondaryLightColor,
                                  ),
                                )
                              : kIsWeb
                                  // Web can't use Image.file for local paths
                                  ? Icon(
                                      Icons.image_not_supported,
                                      color: AppTheme.textSecondaryLightColor,
                                    )
                                  : Image.file(
                                      File(thumbnailUrl.startsWith('file://')
                                          ? thumbnailUrl.substring(7)
                                          : thumbnailUrl),
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) =>
                                          Icon(
                                        Icons.image_not_supported,
                                        color: AppTheme.textSecondaryLightColor,
                                      ),
                                    ),
                        ),

                      // Error icon overlay
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                          color: AppTheme.textLightColor.withValues(alpha: 0.5),
                        ),
                        child: Center(
                          child: Icon(
                            Icons.error_outline,
                            color: AppTheme.errorColor,
                            size: 32,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: AppDimensions.spacingLg),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Upload Failed',
                        style: ThemeHelper.subheadingStyle.copyWith(
                          color: AppTheme.errorColor,
                        ),
                      ),
                      SizedBox(height: AppDimensions.spacingXs),
                      Text(
                        errorMsg,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[800],
                        ),
                      ),
                      SizedBox(height: AppDimensions.spacingSm),
                      if (space != null)
                        Text(
                          'Gram: ${space!.name}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),

            // Retry/Delete buttons
            SizedBox(height: AppDimensions.spacingLg),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  icon: Icon(Icons.delete_outline, size: 20),
                  label: Text('Delete'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey[700],
                  ),
                  onPressed: () {
                    // Handle delete logic here
                    if (postId != null && postId.isNotEmpty) {
                      MediaCompressionService().removeProgressEntry(postId);
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadCard(
      Map<String, dynamic> progress, int percentComplete, String? status) {
    final thumbnailUrl = progress['thumbnailPath'] as String?;
    final title = progress['title'] as String? ?? 'Untitled';
    final time = progress['addedTimestamp'] as int?;
    final postId = progress['postId'] as String? ?? '';

    final formattedTime = time != null ? _formatTime(time) : '';

    return Card(
      margin: EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      ),
      elevation: 2,
      child: InkWell(
        // Make completed uploads clickable to navigate to the post
        onTap: status == 'completed' ? () => _navigateToPost(postId) : null,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Thumbnail
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                      color: AppTheme.scaffoldLightColor,
                    ),
                    child: thumbnailUrl != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                            child: thumbnailUrl.startsWith('http')
                                ? CachedNetworkImage(
                                    imageUrl: thumbnailUrl,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => ShimmerImagePlaceholder(
                                      borderRadius: 8,
                                    ),
                                    errorWidget: (context, url, error) => Icon(
                                      Icons.image_not_supported,
                                      color: AppTheme.textSecondaryLightColor,
                                    ),
                                  )
                                : kIsWeb
                                    // Web can't use Image.file for local paths
                                    ? Icon(
                                        Icons.image_not_supported,
                                        color: AppTheme.textSecondaryLightColor,
                                      )
                                    : Image.file(
                                        File(thumbnailUrl.startsWith('file://')
                                            ? thumbnailUrl.substring(7)
                                            : thumbnailUrl),
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) => Icon(
                                          Icons.image_not_supported,
                                          color: AppTheme.textSecondaryLightColor,
                                        ),
                                      ),
                          )
                        : Icon(
                            Icons.image_not_supported,
                            color: AppTheme.textSecondaryLightColor,
                          ),
                  ),
                  SizedBox(width: AppDimensions.spacingLg),

                  // Content and progress
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: ThemeHelper.bodyTextStyle.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: AppDimensions.spacingXs),
                        if (space != null)
                          Text(
                            'Gram: ${space!.name}',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppTheme.textSecondaryLightColor,
                            ),
                          ),
                        SizedBox(height: AppDimensions.spacingXs),
                        Text(
                          formattedTime,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondaryLightColor,
                          ),
                        ),
                        SizedBox(height: AppDimensions.spacingSm),

                        // Upload status text
                        Text(
                          _getStatusText(status, percentComplete),
                          style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.textLightColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),

                        // Progress bar
                        SizedBox(height: AppDimensions.spacingSm),
                        LinearProgressIndicator(
                          value: percentComplete / 100,
                          backgroundColor: AppTheme.scaffoldLightColor,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            status == 'failed'
                                ? AppTheme.errorColor
                                : status == 'completed'
                                    ? AppTheme.successColor
                                    : AppTheme.primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Action buttons
              SizedBox(height: AppDimensions.spacingLg),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (status == 'completed')
                    TextButton.icon(
                      icon: Icon(Icons.visibility, size: 20),
                      label: Text('View Post'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.primaryColor,
                      ),
                      onPressed: () => _navigateToPost(postId),
                    )
                  else if (status != 'failed' && status != 'cancelled')
                    TextButton.icon(
                      icon: Icon(Icons.delete_outline, size: 20),
                      label: Text('Cancel'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.textSecondaryLightColor,
                      ),
                      onPressed: () {
                        final postId = progress['postId'] as String?;
                        if (postId != null) {
                          MediaCompressionService().cancelUpload(postId);
                        }
                      },
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getStatusText(String? status, int percentComplete) {
    switch (status) {
      case 'queued':
        return 'Queued for processing';
      case 'compressing':
        return 'Compressing video ($percentComplete%)';
      case 'uploading_thumbnail':
        return 'Uploading thumbnail ($percentComplete%)';
      case 'uploading_video':
        return 'Uploading video ($percentComplete%)';
      case 'finalizing':
        return 'Finalizing upload ($percentComplete%)';
      case 'completed':
        return 'Upload completed';
      case 'failed':
        return 'Upload failed';
      case 'cancelled':
        return 'Upload cancelled';
      default:
        return 'Processing ($percentComplete%)';
    }
  }
}
