import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:convert';
// import 'package:ffmpeg_kit_flutter_min_gpl/ffmpeg_kit.dart';
// import 'package:ffmpeg_kit_flutter_min_gpl/return_code.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as path;
import 'package:aurogram/services/media/media_storage_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:aurogram/services/data/post_db_service.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:video_compress/video_compress.dart';
import 'package:aurogram/utils/logging/app_logger.dart';
import 'package:aurogram/utils/network/network_optimizer.dart';
import 'package:aurogram/utils/dependency_injection.dart';
import 'package:image/image.dart' as img;

// Compression quality profiles
enum CompressionQuality {
  high, // Higher quality, larger file
  balanced, // Default option
  low // Lower quality, smaller file
}

// Video resolution options
enum VideoResolution {
  original, // Keep original resolution
  p720, // 720p
  p480, // 480p
  p360 // 360p - smallest file size
}

// Network requirements for upload
enum NetworkRequirement {
  wifiOnly, // Upload only on WiFi
  preferWifi, // Prefer WiFi but allow cellular with user permission
  any // Upload on any connection
}

// EVENT CLASSES for reactive architecture
class UploadProgressEvent {
  final String postId;
  final String status;
  final int progress;
  final String? phase;
  final DateTime timestamp;
  final String? error;

  UploadProgressEvent({
    required this.postId,
    required this.status,
    required this.progress,
    this.phase,
    required this.timestamp,
    this.error,
  });
}

class UploadCompletionEvent {
  final String postId;
  final bool success;
  final String? error;
  final DateTime timestamp;
  final Map<String, dynamic>? uploadData;

  UploadCompletionEvent({
    required this.postId,
    required this.success,
    this.error,
    required this.timestamp,
    this.uploadData,
  });
}

/// Service responsible for handling media compression operations
class MediaCompressionService {
  static const String COMPRESSION_QUEUE_KEY = 'compression_queue';
  static const String COMPRESSION_PROGRESS_KEY = 'compression_progress';
  static const int MAX_QUEUE_SIZE =
      15; // Increased from 7 to allow more queued videos
  static bool _isProcessingQueue = false;
  static bool _shouldProcessAgain = false;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final PostDbService _postDbService = PostDbService();
  final MediaStorageService _storageService = MediaStorageService();

  // EVENT-DRIVEN ARCHITECTURE: Stream controllers for real-time updates
  final _progressController = StreamController<UploadProgressEvent>.broadcast();
  final _completionController =
      StreamController<UploadCompletionEvent>.broadcast();

  // Expose streams for reactive listening
  Stream<UploadProgressEvent> get progressStream => _progressController.stream;
  Stream<UploadCompletionEvent> get completionStream =>
      _completionController.stream;

  // Default quality settings
  static const int _defaultImageQuality = 80;
  static const int _defaultVideoQuality = 720;

  // Compression constants
  static const double _minImageQuality = 50.0;
  static const double _maxImageQuality = 95.0;

  // Cached temp directory to avoid repeated lookups
  Directory? _tempDir;

  // Flag to enable adaptive compression based on network quality
  bool _adaptiveCompressionEnabled = true;

  /// Enable/disable adaptive compression
  set adaptiveCompression(bool value) {
    _adaptiveCompressionEnabled = value;
  }

  /// Adds a post to the compression queue for background processing
  ///
  /// This method queues a video for compression and upload to Firebase Storage.
  /// Parameters:
  /// - post: The post ID to associate with the uploaded media
  /// - videoPath: Local path to the video file to be compressed
  /// - thumbnailPath: Local path to the thumbnail image
  /// - fetchedSpace: ID of the space where the post will be shared
  /// - title: Optional title for the post
  /// - replyTo: Optional post ID that this post is replying to
  /// - replyToUid: Optional user ID of the author of the post being replied to
  /// - addToSpaceFeed: Whether to add this post to the space feed after upload
  /// - link: Optional URL to associate with the post
  /// - userId: User ID of the post author (defaults to current user if null)
  /// - quality: Compression quality setting to use (balanced by default)
  /// - resolution: Target resolution for compression (720p by default)
  /// - networkRequirement: Network conditions for upload (prefer WiFi by default)
  /// - isProfilePost: If true, creates a profile post with contextType: 'profile'
  Future<void> addToCompressionQueue(
      String post,
      String videoPath,
      String thumbnailPath,
      String fetchedSpace,
      String? title,
      String? replyTo,
      String? replyToUid,
      bool addToSpaceFeed,
      String? link,
      String? userId,
      {CompressionQuality quality = CompressionQuality.balanced,
      VideoResolution resolution = VideoResolution.p720,
      NetworkRequirement networkRequirement =
          NetworkRequirement.preferWifi,
      bool isProfilePost = false}) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      List<String> queue = prefs.getStringList(COMPRESSION_QUEUE_KEY) ?? [];

      // Check if queue size exceeds the limit
      if (queue.length >= MAX_QUEUE_SIZE) {
        AppLogger.w('Compression queue full, removing oldest item',
            category: LogCategory.general,
            data: {'queueSize': queue.length, 'maxSize': MAX_QUEUE_SIZE});
        queue.removeAt(0);
      }

      // Get video duration and size for progress tracking
      File videoFile = File(videoPath);
      final videoSizeBytes = await videoFile.length();

      Map<String, dynamic> compressionInfo = {
        'post': post,
        'videoPath': videoPath,
        'thumbnailPath': thumbnailPath,
        'fetchedSpace': fetchedSpace,
        'title': title,
        'replyTo': replyTo,
        'replyToUid': replyToUid,
        'addToSpaceFeed': addToSpaceFeed,
        'link': link,
        'userId': userId,
        'isProfilePost': isProfilePost,
        'attempts': 0,
        'addedTimestamp': DateTime.now().millisecondsSinceEpoch,
        'quality': quality.index,
        'resolution': resolution.index,
        'networkRequirement': networkRequirement.index,
        'videoSizeBytes': videoSizeBytes,
        'status': 'queued',
        'progress': 0, // From 0 to 100 percent
      };

      queue.add(jsonEncode(compressionInfo));
      await prefs.setStringList(COMPRESSION_QUEUE_KEY, queue);

      // Store initial progress information
      Map<String, dynamic> progressMap = _getProgressMap(prefs);
      progressMap[post] = {
        'status': 'queued',
        'progress': 0,
        'addedTimestamp': DateTime.now().millisecondsSinceEpoch,
        'title': title ?? 'Untitled Post',
        'thumbnailPath': thumbnailPath,
        'space': fetchedSpace,
      };
      await _saveProgressMap(prefs, progressMap);

      AppLogger.d('Post added to compression queue',
          category: LogCategory.general,
          data: {
            'postId': post,
            'queueSize': queue.length,
            'videoSize': videoSizeBytes
          });
    } catch (e) {
      AppLogger.e('Error adding post to compression queue',
          category: LogCategory.general, error: e, data: {'postId': post});
      FirebaseCrashlytics.instance.recordError(e, StackTrace.current,
          reason: 'Error adding to compression queue');
    }
  }

  /// Get a map of all compression progress information
  Map<String, dynamic> _getProgressMap(SharedPreferences prefs) {
    String progressJson = prefs.getString(COMPRESSION_PROGRESS_KEY) ?? '{}';
    try {
      return Map<String, dynamic>.from(jsonDecode(progressJson));
    } catch (e) {
      AppLogger.w(
          'Error parsing compression progress JSON, resetting progress map',
          category: LogCategory.general,
          data: {'error': e.toString()});
      return {};
    }
  }

  /// Save the progress map to shared preferences
  Future<void> _saveProgressMap(
      SharedPreferences prefs, Map<String, dynamic> progressMap) async {
    try {
      await prefs.setString(COMPRESSION_PROGRESS_KEY, jsonEncode(progressMap));
    } catch (e) {
      if (kDebugMode) {
        AppLogger.e('', category: LogCategory.general);
      }
    }
  }

  /// Get all upload progress information for UI display
  Future<List<Map<String, dynamic>>> getUploadProgress() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      Map<String, dynamic> progressMap = _getProgressMap(prefs);
      bool hasUpdates = false;

      List<Map<String, dynamic>> result = [];
      for (String postId in progressMap.keys) {
        var data = Map<String, dynamic>.from(progressMap[postId]);

        // Check and fix thumbnail paths
        String? thumbnailPath = data['thumbnailPath'] as String?;
        if (thumbnailPath != null && thumbnailPath.isNotEmpty) {
          // If it's a local file path but not a network URL
          if (!thumbnailPath.startsWith('http')) {
            String effectivePath = thumbnailPath;

            // Handle file:// prefix
            if (thumbnailPath.startsWith('file://')) {
              effectivePath = thumbnailPath.substring(7);
            }

            // Check if the file exists locally
            bool fileExists = false;
            try {
              if (effectivePath.startsWith('/')) {
                fileExists = await File(effectivePath).exists();
              }
            } catch (e) {
              if (kDebugMode) {
                AppLogger.e('', category: LogCategory.general);
              }
            }

            // If file doesn't exist, try to get URL from Firebase Storage
            if (!fileExists) {
              // Try to get the download URL from storage
              String? storageUrl = await _tryGetStorageUrl(postId);
              if (storageUrl != null) {
                // Update in memory and mark for persistence
                thumbnailPath = storageUrl;
                data['thumbnailPath'] = storageUrl;
                progressMap[postId]['thumbnailPath'] = storageUrl;
                hasUpdates = true;
                AppLogger.i('Updated thumbnail path to storage URL',
                    category: LogCategory.general, data: {'postId': postId});
              } else if (thumbnailPath.startsWith('/') ||
                  thumbnailPath.startsWith('file://')) {
                // Ensure file:// prefix for local paths
                if (!thumbnailPath.startsWith('file:') &&
                    thumbnailPath.startsWith('/')) {
                  thumbnailPath = 'file://$thumbnailPath';
                  data['thumbnailPath'] = thumbnailPath;
                }
              }
            } else {
              // Ensure file:// prefix for existing local paths
              if (!thumbnailPath.startsWith('file:') &&
                  thumbnailPath.startsWith('/')) {
                thumbnailPath = 'file://$thumbnailPath';
                data['thumbnailPath'] = thumbnailPath;
              }
            }
          }
        }

        result.add({
          'postId': postId,
          ...data,
        });
      }

      // Save updates to preferences if needed
      if (hasUpdates) {
        await _saveProgressMap(prefs, progressMap);
      }

      // Sort by timestamp (newest first)
      result.sort((a, b) =>
          (b['addedTimestamp'] ?? 0).compareTo(a['addedTimestamp'] ?? 0));

      return result;
    } catch (e) {
      if (kDebugMode) {
        AppLogger.e('', category: LogCategory.general);
      }
      return [];
    }
  }

  /// Try to get the storage URL for a post's thumbnail
  Future<String?> _tryGetStorageUrl(String postId) async {
    try {
      // First check if we can get the URL from Firestore
      final doc = await _firestore.collection('posts').doc(postId).get();
      if (doc.exists && doc.data() != null) {
        final thumbnailUrl = doc.data()?['thumbnail'] as String?;
        if (thumbnailUrl != null && thumbnailUrl.startsWith('http')) {
          return thumbnailUrl;
        }
      }

      // If not in Firestore, try to generate the URL from storage path
      try {
        final ref =
            FirebaseStorage.instance.ref().child('posts/$postId/thumbnail.jpg');
        return await ref.getDownloadURL();
      } catch (e) {
        if (kDebugMode) {
          AppLogger.e('', category: LogCategory.general);
        }
        return null;
      }
    } catch (e) {
      if (kDebugMode) {
        AppLogger.e('', category: LogCategory.general);
      }
      return null;
    }
  }

  /// Get progress for a specific post
  Future<Map<String, dynamic>?> getPostProgress(String postId) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      Map<String, dynamic> progressMap = _getProgressMap(prefs);
      if (progressMap.containsKey(postId)) {
        return {
          'postId': postId,
          ...Map<String, dynamic>.from(progressMap[postId]),
        };
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        AppLogger.e('', category: LogCategory.general);
      }
      return null;
    }
  }

  /// Updates progress for a specific post
  Future<void> _updateProgress(
      String postId, String status, int progress) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      Map<String, dynamic> progressMap = _getProgressMap(prefs);

      if (progressMap.containsKey(postId)) {
        // Only update if progress is increasing or status changes
        final currentProgress = progressMap[postId]['progress'] ?? 0;
        final currentStatus = progressMap[postId]['status'];

        // Always update if status changes or progress increases
        if (status != currentStatus || progress > currentProgress) {
          progressMap[postId]['status'] = status;
          progressMap[postId]['progress'] = progress;
          progressMap[postId]['lastUpdated'] =
              DateTime.now().millisecondsSinceEpoch;

          await _saveProgressMap(prefs, progressMap);

          // EVENT-DRIVEN: Emit progress event for real-time updates
          final progressEvent = UploadProgressEvent(
            postId: postId,
            status: status,
            progress: progress,
            timestamp: DateTime.now(),
          );
          _progressController.add(progressEvent);

          // If completed or failed, emit completion event
          if (status == 'completed' ||
              status == 'failed' ||
              status.contains('failed')) {
            final completionEvent = UploadCompletionEvent(
              postId: postId,
              success: status == 'completed',
              error: status.contains('failed') ? status : null,
              timestamp: DateTime.now(),
              uploadData: Map<String, dynamic>.from(progressMap[postId]),
            );
            _completionController.add(completionEvent);
          }

          if (kDebugMode) {
            AppLogger.i('Progress event emitted',
                category: LogCategory.general,
                data: {
                  'postId': postId,
                  'status': status,
                  'progress': progress
                });
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        AppLogger.e('', category: LogCategory.general);
      }
    }
  }

  /// Remove progress entry for completed upload
  Future<void> _clearProgressEntry(String postId, {bool success = true}) async {
    try {
      // First update the progress and status directly
      await _updateProgress(
          postId, success ? 'completed' : 'failed', success ? 100 : 0);

      // Then update additional metadata
      SharedPreferences prefs = await SharedPreferences.getInstance();
      Map<String, dynamic> progressMap = _getProgressMap(prefs);

      if (progressMap.containsKey(postId)) {
        // Keep in list with completed status for 1 hour before removing
        progressMap[postId]['status'] = success ? 'completed' : 'failed';
        progressMap[postId]['progress'] = success ? 100 : 0;
        progressMap[postId]['completedTimestamp'] =
            DateTime.now().millisecondsSinceEpoch;

        await _saveProgressMap(prefs, progressMap);

        AppLogger.i('Progress entry marked',
            category: LogCategory.general,
            data: {
              'status': success ? 'completed' : 'failed',
              'postId': postId
            });

        // Schedule cleanup of old completed items
        cleanupOldCompletedUploads();
      }
    } catch (e) {
      if (kDebugMode) {
        AppLogger.e('', category: LogCategory.general);
      }
    }
  }

  /// Clean up old completed uploads from progress tracking
  Future<void> cleanupOldCompletedUploads() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      Map<String, dynamic> progressMap = _getProgressMap(prefs);

      final now = DateTime.now().millisecondsSinceEpoch;
      const oneHourInMs = 60 * 60 * 1000;

      // Remove entries completed more than an hour ago
      progressMap.removeWhere((postId, data) {
        final isCompleted =
            data['status'] == 'completed' || data['status'] == 'failed';
        final completedTime = data['completedTimestamp'] ?? 0;
        return isCompleted && (now - completedTime > oneHourInMs);
      });

      await _saveProgressMap(prefs, progressMap);
    } catch (e) {
      // Silently handle cleanup errors
    }
  }

  /// Remove a specific progress entry by postId
  Future<void> removeProgressEntry(String postId) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      Map<String, dynamic> progressMap = _getProgressMap(prefs);

      if (progressMap.containsKey(postId)) {
        progressMap.remove(postId);
        await _saveProgressMap(prefs, progressMap);
      }
    } catch (e) {
      FirebaseCrashlytics.instance.recordError(e, StackTrace.current,
          reason: 'Error removing progress entry');
    }
  }

  /// Processes the video compression queue
  void processCompressionQueue() async {
    AppLogger.d('Processing compression queue started',
        category: LogCategory.general,
        data: {'isProcessing': _isProcessingQueue});

    if (_isProcessingQueue) {
      _shouldProcessAgain = true;
      AppLogger.d('Queue already processing, marking for retry',
          category: LogCategory.general);
      return;
    }

    _isProcessingQueue = true;
    _shouldProcessAgain = false;

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      List<String> queue = prefs.getStringList(COMPRESSION_QUEUE_KEY) ?? [];

      AppLogger.d('Compression queue status',
          category: LogCategory.general, data: {'queueLength': queue.length});

      if (queue.isEmpty) {
        AppLogger.d('Compression queue is empty, stopping processing',
            category: LogCategory.general);
        _isProcessingQueue = false;
        return;
      }

      String nextItem = queue.removeAt(0);
      await prefs.setStringList(COMPRESSION_QUEUE_KEY, queue);

      Map<String, dynamic> item = jsonDecode(nextItem);

      AppLogger.d('Starting compression for next queue item',
          category: LogCategory.general,
          data: {
            'postId': item['post'],
            'remainingQueue': queue.length,
            'attempts': item['attempts'] ?? 0,
            'videoPath': item['videoPath']
          });

      await _compressAndUploadVideo(
        item['post'],
        item['videoPath'],
        item['thumbnailPath'],
        item['fetchedSpace'],
        item['title'],
        item['replyTo'],
        item['replyToUid'],
        item['addToSpaceFeed'] ?? false,
        item['link'],
        item['attempts'] ?? 0,
        item['userId'],
        quality: CompressionQuality
            .values[item['quality'] ?? CompressionQuality.balanced.index],
        resolution: VideoResolution
            .values[item['resolution'] ?? VideoResolution.p720.index],
        networkRequirement: NetworkRequirement.values[
            item['networkRequirement'] ?? NetworkRequirement.preferWifi.index],
        isProfilePost: item['isProfilePost'] ?? false,
      );
    } catch (e) {
      AppLogger.e('Error processing compression queue',
          category: LogCategory.general, error: e);
      FirebaseCrashlytics.instance.recordError(e, StackTrace.current,
          reason: 'Error processing compression queue');
    } finally {
      _isProcessingQueue = false;
      if (_shouldProcessAgain) {
        processCompressionQueue();
      }
    }
  }

  /// Compresses and uploads a video
  Future<void> _compressAndUploadVideo(
      String post,
      String videoPath,
      String thumbnailPath,
      String fetchedSpace,
      String? title,
      String? replyTo,
      String? replyToUid,
      bool addToSpaceFeed,
      String? link,
      int attempts,
      String? userId,
      {CompressionQuality quality = CompressionQuality.balanced,
      VideoResolution resolution = VideoResolution.p720,
      NetworkRequirement networkRequirement =
          NetworkRequirement.preferWifi,
      bool isProfilePost = false}) async {
    // Keep track of all timers to cancel them when needed
    List<Timer> progressTimers = [];
    // Set a flag to track if progress is moving forward
    bool isProcessing = true;
    // Current progress value
    int currentProgress = 0;

    try {
      // Update status to compressing - starting progress
      await _updateProgress(post, 'compressing', 10);
      currentProgress = 10;

      // Intermediate progress updates during compression - using non-overlapping timers
      void scheduleProgressUpdate(
          String phase, int progress, int delaySeconds) {
        if (progress <= currentProgress) return; // Skip if going backwards

        progressTimers.add(Timer(Duration(seconds: delaySeconds), () async {
          // Only update if we're still processing and this is a forward progress
          if (isProcessing && progress > currentProgress) {
            await _updateProgress(post, phase, progress);
            currentProgress = progress;
          }
        }));
      }

      // Schedule compression progress updates
      scheduleProgressUpdate('compressing', 15, 2);
      scheduleProgressUpdate('compressing', 20, 5);
      scheduleProgressUpdate('compressing', 25, 10);

      // 1. Compress video with the selected quality and resolution
      String? compressedVideoPath = await _compressVideo(videoPath, post,
          quality: quality, resolution: resolution);

      if (compressedVideoPath == null) {
        // Cancel all pending timers
        isProcessing = false;
        for (var timer in progressTimers) {
          timer.cancel();
        }

        await _updateProgress(post, 'compression_failed', 0);
        _handleFailedCompression(post, videoPath, thumbnailPath, fetchedSpace,
            title, replyTo, replyToUid, addToSpaceFeed, link, attempts, userId, isProfilePost: isProfilePost);
        return;
      }

      // Update progress to indicate compression complete - only if it's more than current
      if (30 > currentProgress) {
        await _updateProgress(post, 'uploading_thumbnail', 30);
        currentProgress = 30;
      }

      // Intermediate progress updates during thumbnail upload - only if moving forward
      if (35 > currentProgress) {
        progressTimers.add(Timer(Duration(seconds: 1), () async {
          if (isProcessing && 35 > currentProgress) {
            await _updateProgress(post, 'uploading_thumbnail', 35);
            currentProgress = 35;
          }
        }));
      }

      // 2. Upload thumbnail
      AppLogger.d('Starting thumbnail upload',
          category: LogCategory.general,
          data: {'postId': post, 'thumbnailPath': thumbnailPath});

      String? thumbnail = await _storageService.uploadToStorage(
          thumbnailPath, 'posts/$post/thumbnail.jpg');
      if (thumbnail == null) {
        // Cancel all pending timers
        isProcessing = false;
        for (var timer in progressTimers) {
          timer.cancel();
        }

        // Don't go backwards in progress
        if (currentProgress < 30) {
          await _updateProgress(post, 'thumbnail_upload_failed', 30);
        } else {
          await _updateProgress(
              post, 'thumbnail_upload_failed', currentProgress);
        }

        AppLogger.e('Thumbnail upload failed',
            category: LogCategory.general,
            data: {'postId': post, 'thumbnailPath': thumbnailPath});

        _handleFailedCompression(post, videoPath, thumbnailPath, fetchedSpace,
            title, replyTo, replyToUid, addToSpaceFeed, link, attempts, userId, isProfilePost: isProfilePost);
        return;
      }

      // As soon as the thumbnail is uploaded, update the post document so UI can show it immediately
      try {
        await _postDbService.updatePostThumbnail(post, thumbnail);
      } catch (_) {}

      // Update progress to video upload - only if it's more than current progress
      if (50 > currentProgress) {
        await _updateProgress(post, 'uploading_video', 50);
        currentProgress = 50;
      }

      // 3. Upload compressed video with progress tracking
      AppLogger.d('Starting video upload',
          category: LogCategory.general,
          data: {'postId': post, 'compressedVideoPath': compressedVideoPath});

      // Schedule video upload progress updates
      if (60 > currentProgress) {
        progressTimers.add(Timer(Duration(seconds: 2), () async {
          if (isProcessing && 60 > currentProgress) {
            await _updateProgress(post, 'uploading_video', 60);
            currentProgress = 60;
          }
        }));
      }

      if (70 > currentProgress) {
        progressTimers.add(Timer(Duration(seconds: 5), () async {
          if (isProcessing && 70 > currentProgress) {
            await _updateProgress(post, 'uploading_video', 70);
            currentProgress = 70;
          }
        }));
      }

      // Upload video with progress reporting
      String? video = await _storageService
          .uploadToStorage(compressedVideoPath, 'posts/$post/video.mp4',
              onProgress: (progressPercent) {
        // progressPercent is in [0,100]
        double safePercent = progressPercent;
        if (safePercent.isNaN || !safePercent.isFinite) {
          safePercent = 0.0;
        }
        if (safePercent < 0.0) safePercent = 0.0;
        if (safePercent > 100.0) safePercent = 100.0;

        // Calculate total progress (50% start + up to 30% for video upload)
        final int totalProgress = 50 + ((safePercent / 100.0) * 30.0).round();
        if (totalProgress > currentProgress) {
          _updateProgress(post, 'uploading_video', totalProgress);
          currentProgress = totalProgress;
        }
      });

      if (video == null) {
        // Cancel all pending timers
        isProcessing = false;
        for (var timer in progressTimers) {
          timer.cancel();
        }

        await _updateProgress(post, 'video_upload_failed', currentProgress);

        AppLogger.e('Video upload failed',
            category: LogCategory.general,
            data: {'postId': post, 'compressedVideoPath': compressedVideoPath});

        _handleFailedCompression(post, videoPath, thumbnailPath, fetchedSpace,
            title, replyTo, replyToUid, addToSpaceFeed, link, attempts, userId, isProfilePost: isProfilePost);
        return;
      }

      // 4. Update progress to finalizing
      if (90 > currentProgress) {
        await _updateProgress(post, 'finalizing', 90);
        currentProgress = 90;
      }

      // 5. Create or update post in Firestore
      if (95 > currentProgress) {
        progressTimers.add(Timer(Duration(seconds: 1), () async {
          if (isProcessing && 95 > currentProgress) {
            await _updateProgress(post, 'finalizing', 95);
            currentProgress = 95;
          }
        }));
      }

      // Use provided user ID or current user
      final actualUserId = userId ?? FirebaseAuth.instance.currentUser?.uid;
      if (actualUserId == null) {
        throw Exception('No user ID available for post');
      }

      AppLogger.d('🔥 CALLING updatePostWithMedia - CRITICAL STEP',
          category: LogCategory.general,
          data: {
            'postId': post,
            'videoUrl': video,
            'thumbnailUrl': thumbnail,
            'userId': actualUserId
          });

      bool updateSuccess =
          await _postDbService.updatePostWithMedia(post, video, thumbnail);

      AppLogger.w(
          updateSuccess
              ? '✅ updatePostWithMedia SUCCESS'
              : '❌ updatePostWithMedia FAILED',
          category: LogCategory.general,
          data: {'postId': post, 'success': updateSuccess});

      // Add to appropriate feed
      if (isProfilePost) {
        // For profile posts, add to user's profile posts collection
        await _postDbService.addVideoToUserPosts(
            post, title, thumbnail, video, replyTo, link);
      } else if (addToSpaceFeed) {
        // For space posts, add to space feed
        await _postDbService.addToSpaceFeed(
            fetchedSpace, post, title, thumbnail, video, replyTo, link);
      }

      // 6. Handle replies if necessary
      if (replyTo != null) {
        await _postDbService.addPostReply(
            fetchedSpace, post, title, thumbnail, video, replyTo, link);

        // Add user reply notification if reply to a user's post
        if (replyToUid != null && userId != null && replyToUid != userId) {
          await _postDbService.addUserReply(
              replyToUid, fetchedSpace, post, title, thumbnail, video, link);
        }
      }

      AppLogger.d('Post upload and processing completed successfully',
          category: LogCategory.general,
          data: {'postId': post, 'videoUrl': video, 'thumbnailUrl': thumbnail});

      // Cancel all pending timers first
      isProcessing = false;
      for (var timer in progressTimers) {
        timer.cancel();
      }
      progressTimers.clear();

      // Mark as complete in progress tracker - ensure this is always 100%
      await _updateProgress(post, 'completed', 100);

      // Store the completion info but don't trigger navigation
      // Update status record to indicate completion so UI can show correctly
      SharedPreferences prefs = await SharedPreferences.getInstance();
      Map<String, dynamic> progressMap = _getProgressMap(prefs);

      if (progressMap.containsKey(post)) {
        progressMap[post]['status'] = 'completed';
        progressMap[post]['progress'] = 100;
        progressMap[post]['completedTimestamp'] =
            DateTime.now().millisecondsSinceEpoch;
        progressMap[post]['spaceId'] = fetchedSpace;

        // Do not call markUploadAsComplete or any navigation triggers
        await _saveProgressMap(prefs, progressMap);

        if (kDebugMode) {
          AppLogger.d('', category: LogCategory.general);
        }
      }

      // 7. Clean up local files
      try {
        // Delete original video file
        final videoFile = File(videoPath);
        if (await videoFile.exists()) {
          await videoFile.delete();
        }

        // Delete thumbnail file
        final thumbnailFile = File(thumbnailPath);
        if (await thumbnailFile.exists()) {
          await thumbnailFile.delete();
        }

        // Delete compressed video file
        final compressedVideoFile = File(compressedVideoPath);
        if (await compressedVideoFile.exists()) {
          await compressedVideoFile.delete();
        }
      } catch (e) {
        if (kDebugMode) {
          AppLogger.e('', category: LogCategory.general);
        }
        // Don't let file deletion errors stop the process
        // The files will be cleaned up by the system eventually
      }

      // 8. Process next item in queue
      processCompressionQueue();
    } catch (e) {
      // Cancel all pending timers in case of error
      isProcessing = false;
      for (var timer in progressTimers) {
        timer.cancel();
      }

      await _updateProgress(post, 'failed', 0);
      if (kDebugMode) {
        AppLogger.e('', category: LogCategory.general);
      }
      FirebaseCrashlytics.instance.recordError(e, StackTrace.current);
      _handleFailedCompression(post, videoPath, thumbnailPath, fetchedSpace,
          title, replyTo, replyToUid, addToSpaceFeed, link, attempts, userId);
    }
  }

  /// Compresses a video file with the specified quality and resolution
  Future<String?> _compressVideo(String videoPath, String postId,
      {CompressionQuality quality = CompressionQuality.balanced,
      VideoResolution resolution = VideoResolution.p720}) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final outputPath = path.join(tempDir.path, 'compressed_$postId.mp4');

      // Note: Resolution and quality settings could be implemented here if needed

      // Note: CRF (Constant Rate Factor) settings could be implemented here if needed

      // TEMPORARY: FFmpeg functionality disabled due to package discontinuation
      // Use video_compress package as fallback for basic compression
      try {
        final info = await VideoCompress.compressVideo(
          videoPath,
          quality: VideoQuality.MediumQuality,
          deleteOrigin: false,
        );

        if (info != null && info.path != null) {
          // Copy compressed video to our output path
          final compressedFile = File(info.path!);
          await compressedFile.copy(outputPath);
          await compressedFile.delete(); // Clean up temp file

          AppLogger.i('Video compressed successfully using video_compress',
              category: LogCategory.general, data: {'outputPath': outputPath});
          return outputPath;
        } else {
          return null;
        }
      } catch (e) {
        return null;
      }
    } catch (e) {
      FirebaseCrashlytics.instance.recordError(e, StackTrace.current);
      return null;
    }
  }

  /// Cancels a pending upload
  Future<bool> cancelUpload(String postId) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();

      // Remove from queue if still pending
      List<String> queue = prefs.getStringList(COMPRESSION_QUEUE_KEY) ?? [];
      bool wasInQueue = false;

      queue = queue.where((item) {
        try {
          Map<String, dynamic> data = jsonDecode(item);
          if (data['post'] == postId) {
            wasInQueue = true;
            return false; // Remove this item
          }
          return true; // Keep all other items
        } catch (e) {
          return true; // Keep items that can't be parsed
        }
      }).toList();

      // Save updated queue
      await prefs.setStringList(COMPRESSION_QUEUE_KEY, queue);

      // Update progress status
      await _updateProgress(postId, 'cancelled', 0);

      // Clean up any database entries
      try {
        await _firestore.collection('posts').doc(postId).delete();
      } catch (e) {
        if (kDebugMode) {
          AppLogger.e('', category: LogCategory.general);
        }
      }

      return wasInQueue;
    } catch (e) {
      if (kDebugMode) {
        AppLogger.e('', category: LogCategory.general);
      }
      return false;
    }
  }

  /// Handles failed compression attempts
  Future<void> _handleFailedCompression(
    String post,
    String videoPath,
    String thumbnailPath,
    String fetchedSpace,
    String? title,
    String? replyTo,
    String? replyToUid,
    bool addToSpaceFeed,
    String? link,
    int attempts,
    String? userId, {
    bool isProfilePost = false,
  }) async {
    try {
      if (attempts < 3) {
        // Increment attempts counter
        int newAttempts = attempts + 1;

        // Requeue for another attempt with incremented attempts count
        await addToCompressionQueue(
          post,
          videoPath,
          thumbnailPath,
          fetchedSpace,
          title,
          replyTo,
          replyToUid,
          addToSpaceFeed,
          link,
          userId,
          isProfilePost: isProfilePost,
        );

        // Update queue item with incremented attempts
        SharedPreferences prefs = await SharedPreferences.getInstance();
        List<String> queue = prefs.getStringList(COMPRESSION_QUEUE_KEY) ?? [];

        for (int i = 0; i < queue.length; i++) {
          try {
            Map<String, dynamic> item = jsonDecode(queue[i]);
            if (item['post'] == post) {
              item['attempts'] = newAttempts;
              queue[i] = jsonEncode(item);
              break;
            }
          } catch (e) {
            // Skip items that can't be parsed
          }
        }

        await prefs.setStringList(COMPRESSION_QUEUE_KEY, queue);
      } else {
        // Failed too many times, clean up
        AppLogger.e('Compression failed after maximum attempts',
            category: LogCategory.general,
            data: {'postId': post, 'attempts': attempts});

        // Mark post as failed in Firestore
        await _postDbService.updatePostStatus(post, false);

        // Mark as failed in progress tracker
        await _clearProgressEntry(post, success: false);

        // Delete local files
        try {
          await File(videoPath).delete();
          await File(thumbnailPath).delete();
        } catch (e) {
          AppLogger.w('Error deleting local files after compression failure',
              category: LogCategory.general,
              data: {
                'error': e.toString(),
                'videoPath': videoPath,
                'thumbnailPath': thumbnailPath
              });
        }
      }
    } catch (e) {
      AppLogger.e('Error handling failed compression',
          category: LogCategory.general, error: e, data: {'postId': post});
      FirebaseCrashlytics.instance.recordError(e, StackTrace.current);
    }
  }

  /// Clears the compression queue
  Future<void> clearCompressionQueue() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(COMPRESSION_QUEUE_KEY, []);
      if (kDebugMode) {
        AppLogger.d('', category: LogCategory.general);
      }
    } catch (e) {
      if (kDebugMode) {
        AppLogger.e('', category: LogCategory.general);
      }
      FirebaseCrashlytics.instance.recordError(e, StackTrace.current,
          reason: 'Error clearing compression queue');
    }
  }

  /// Gets the size of the compression queue
  Future<int> getCompressionQueueSize() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      List<String> queue = prefs.getStringList(COMPRESSION_QUEUE_KEY) ?? [];
      return queue.length;
    } catch (e) {
      if (kDebugMode) {
        AppLogger.e('', category: LogCategory.general);
      }
      FirebaseCrashlytics.instance.recordError(e, StackTrace.current,
          reason: 'Error getting compression queue size');
      return 0;
    }
  }

  /// Migrate and clean up existing upload entries
  Future<void> migrateAndCleanupUploads() async {
    try {
      if (kDebugMode) {
        AppLogger.d('', category: LogCategory.general);
      }
      SharedPreferences prefs = await SharedPreferences.getInstance();
      Map<String, dynamic> progressMap = _getProgressMap(prefs);
      bool hasUpdates = false;

      // 1. Identify entries to process
      List<String> postsToRemove = [];
      List<Future> migrationTasks = [];

      if (kDebugMode) {
        AppLogger.d('', category: LogCategory.general);
      }

      for (String postId in progressMap.keys) {
        final entry = progressMap[postId];
        final status = entry['status'] as String?;

        // Check for very old entries that should be removed
        final timestamp = entry['addedTimestamp'] as int?;
        if (timestamp != null) {
          final daysOld = (DateTime.now().millisecondsSinceEpoch - timestamp) /
              (1000 * 60 * 60 * 24);
          // Remove entries older than 7 days
          if (daysOld > 7) {
            postsToRemove.add(postId);
            continue;
          }
        }

        // Skip entries that already have http URLs
        final thumbnailPath = entry['thumbnailPath'] as String?;
        if (thumbnailPath != null && thumbnailPath.startsWith('http')) {
          continue;
        }

        // For completed posts, try to get the storage URL
        if (status == 'completed') {
          migrationTasks.add(() async {
            final url = await _tryGetStorageUrl(postId);
            if (url != null) {
              progressMap[postId]['thumbnailPath'] = url;
              hasUpdates = true;
              if (kDebugMode) {
                AppLogger.d('', category: LogCategory.general);
              }
            } else {
              // If we can't get the URL for a completed post, it might be invalid
              // Mark for removal if it's older than 1 day
              final completedTimestamp = entry['completedTimestamp'] as int?;
              if (completedTimestamp != null) {
                final hoursOld = (DateTime.now().millisecondsSinceEpoch -
                        completedTimestamp) /
                    (1000 * 60 * 60);
                if (hoursOld > 24) {
                  postsToRemove.add(postId);
                }
              }
            }
          }());
        }

        // Check if local thumbnail files exist
        if (thumbnailPath != null &&
            (thumbnailPath.startsWith('/') ||
                thumbnailPath.startsWith('file://'))) {
          String effectivePath = thumbnailPath;
          if (thumbnailPath.startsWith('file://')) {
            effectivePath = thumbnailPath.substring(7);
          }

          migrationTasks.add(() async {
            bool exists = false;
            try {
              exists = await File(effectivePath).exists();
            } catch (e) {
              if (kDebugMode) {
                AppLogger.e('', category: LogCategory.general);
              }
            }

            if (!exists) {
              // Try to get a new URL from storage
              final url = await _tryGetStorageUrl(postId);
              if (url != null) {
                progressMap[postId]['thumbnailPath'] = url;
                hasUpdates = true;
                if (kDebugMode) {
                  AppLogger.i('', category: LogCategory.general);
                }
              } else if (status != 'completed' &&
                  status != 'failed' &&
                  status != 'cancelled') {
                // For active posts with missing files and no storage URL, mark as failed
                progressMap[postId]['status'] = 'failed';
                progressMap[postId]['progress'] = 0;
                hasUpdates = true;
                AppLogger.e('Marked post with missing thumbnail as failed',
                    category: LogCategory.general, data: {'postId': postId});
              }
            }
          }());
        }
      }

      // 2. Await all migration tasks
      await Future.wait(migrationTasks);

      // 3. Remove stale entries
      for (final postId in postsToRemove) {
        progressMap.remove(postId);
        if (kDebugMode) {
          AppLogger.d('', category: LogCategory.general);
        }
      }

      // 4. Save updates
      if (hasUpdates || postsToRemove.isNotEmpty) {
        await _saveProgressMap(prefs, progressMap);
        AppLogger.i('Migration completed',
            category: LogCategory.general,
            data: {
              'saved': progressMap.length,
              'removed': postsToRemove.length
            });
      } else {
        if (kDebugMode) {
          AppLogger.d('', category: LogCategory.general);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        AppLogger.e('', category: LogCategory.general);
      }
      FirebaseCrashlytics.instance.recordError(e, StackTrace.current,
          reason: 'Error during upload entry migration');
    }
  }

  /// Check if file exists at path
  Future<bool> fileExists(String path) async {
    try {
      final file = File(path);
      return await file.exists();
    } catch (e) {
      if (kDebugMode) {
        AppLogger.e('', category: LogCategory.general);
      }
      return false;
    }
  }

  /// Load image from path with fallback
  Future<dynamic> loadImageFromPath(String path, {String? fallbackUrl}) async {
    try {
      if (await fileExists(path)) {
        return File(path);
      } else if (fallbackUrl != null) {
        // If local file doesn't exist, use network image
        return NetworkImage(fallbackUrl);
      } else {
        // If no fallback provided, return a placeholder
        return AssetImage('assets/images/placeholder.png');
      }
    } catch (e) {
      if (kDebugMode) {
        AppLogger.e('', category: LogCategory.general);
      }
      return AssetImage('assets/images/placeholder.png');
    }
  }

  /// Get cached file from path safely
  Future<File?> getCachedFile(String path) async {
    try {
      if (await fileExists(path)) {
        return File(path);
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        AppLogger.e('', category: LogCategory.general);
      }
      return null;
    }
  }

  /// Clean up old thumbnail cache files
  Future<void> cleanupThumbnailCache() async {
    try {
      final cacheDir = await getTemporaryDirectory();
      final thumbnailDir = Directory('${cacheDir.path}/thumbnails');

      if (await thumbnailDir.exists()) {
        // Get all files in the thumbnail directory
        final files = await thumbnailDir.list().toList();

        // Sort by last modified time
        files.sort((a, b) {
          if (a is File && b is File) {
            return b.lastModifiedSync().compareTo(a.lastModifiedSync());
          }
          return 0;
        });

        // Keep the most recent 100 files, delete the rest
        if (files.length > 100) {
          for (var i = 100; i < files.length; i++) {
            if (files[i] is File) {
              await (files[i] as File).delete();
            }
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        AppLogger.e('', category: LogCategory.general);
      }
    }
  }

  /// Update a post's URL after upload completion
  Future<void> updatePostUrlInProgress(String postId, String? spaceId) async {
    try {
      // Get the document reference for the post
      final postRef = _firestore.collection('posts').doc(postId);
      final postDoc = await postRef.get();

      if (!postDoc.exists || postDoc.data() == null) {
        if (kDebugMode) {
          AppLogger.d('', category: LogCategory.general);
        }
        return;
      }

      SharedPreferences prefs = await SharedPreferences.getInstance();
      Map<String, dynamic> progressMap = _getProgressMap(prefs);

      if (progressMap.containsKey(postId)) {
        // Update the progress entry with the post URL
        progressMap[postId]['postUrl'] = postId;
        progressMap[postId]['spaceId'] = spaceId;
        progressMap[postId]['completedTimestamp'] =
            DateTime.now().millisecondsSinceEpoch;

        // Save the updated progress map
        await _saveProgressMap(prefs, progressMap);
        if (kDebugMode) {
          AppLogger.i('', category: LogCategory.general);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        AppLogger.e('', category: LogCategory.general);
      }
    }
  }

  /// Mark upload as complete and properly set navigation info
  Future<void> markUploadAsComplete(String postId, String? spaceId) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      Map<String, dynamic> progressMap = _getProgressMap(prefs);

      if (progressMap.containsKey(postId)) {
        // First update post URL for navigation
        await updatePostUrlInProgress(postId, spaceId);

        // Then update status and store completion timestamp
        progressMap[postId]['status'] = 'completed';
        progressMap[postId]['progress'] = 100;
        progressMap[postId]['completedTimestamp'] =
            DateTime.now().millisecondsSinceEpoch;
        progressMap[postId]['spaceId'] = spaceId;

        // Save the updated progress map
        await _saveProgressMap(prefs, progressMap);
        if (kDebugMode) {
          AppLogger.d('', category: LogCategory.general);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        AppLogger.e('', category: LogCategory.general);
      }
    }
  }

  /// Manually update the status of an upload
  ///
  /// This allows marking uploads as failed or completed from external components
  /// Parameters:
  /// - postId: The ID of the post/upload to update
  /// - status: The new status value (e.g., 'failed', 'completed', 'cancelled')
  /// - error: Optional error message to include
  Future<void> updateUploadStatus(String postId, String status,
      {String? error}) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      Map<String, dynamic> progressMap = _getProgressMap(prefs);

      // If this post ID exists in our progress tracking
      if (progressMap.containsKey(postId)) {
        var data = Map<String, dynamic>.from(progressMap[postId]);

        // Update the status
        data['status'] = status;

        // Add error message if provided
        if (error != null && error.isNotEmpty) {
          data['error'] = error;
        }

        // If marking as failed or completed, add timestamp
        if (status == 'failed' || status == 'completed') {
          data['completedTimestamp'] = DateTime.now().millisecondsSinceEpoch;
        }

        // Save the updated data
        progressMap[postId] = data;
        await _saveProgressMap(prefs, progressMap);

        if (kDebugMode) {
          AppLogger.i('', category: LogCategory.general);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        AppLogger.e('', category: LogCategory.general);
      }
      FirebaseCrashlytics.instance.recordError(e, StackTrace.current,
          reason: 'Error updating upload status');
    }
  }

  /// Compress an image with adaptive quality
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

      // Determine optimal quality based on network conditions
      final effectiveQuality = await _getOptimalImageQuality(quality);

      // Get image dimensions for intelligent resizing
      final dimensions = await _getImageDimensions(imageFile);
      final effectiveWidth = targetWidth ?? dimensions?.item1 ?? 1280;
      final effectiveHeight = targetHeight ?? dimensions?.item2 ?? 720;

      // Limit max dimensions to save memory
      final maxDimension = max(effectiveWidth, effectiveHeight);
      final limitedWidth = effectiveWidth > 3000
          ? (effectiveWidth * 3000 / maxDimension).round()
          : effectiveWidth;
      final limitedHeight = effectiveHeight > 3000
          ? (effectiveHeight * 3000 / maxDimension).round()
          : effectiveHeight;

      // Create temp file for output
      final outputFile = await _createTempFile('.jpg');

      // Compress the image
      final image = img.decodeImage(imageFile.readAsBytesSync());
      if (image == null) {
        throw Exception('Could not decode image');
      }

      // Resize if necessary
      img.Image resizedImage = image;
      if (image.width > limitedWidth || image.height > limitedHeight) {
        resizedImage = img.copyResize(image,
            width: limitedWidth,
            height: limitedHeight,
            interpolation: img.Interpolation.linear);
      }

      // Compress and encode to file
      final compressQuality = effectiveQuality * 100; // Convert to percentage
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

  /// Compress a video with adaptive quality
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

      // Determine optimal quality for video
      final VideoQuality quality = await _getOptimalVideoQuality(targetQuality);

      // Show progress in debug mode
      if (kDebugMode) {
        VideoCompress.compressProgress$.subscribe((progress) {
          AppLogger.d(
            'Video compression progress: $progress%',
            category: LogCategory.media,
          );
        });
      }

      // Start compression
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

  /// Generate a thumbnail for a video
  Future<File?> generateVideoThumbnail(File videoFile, {int? maxWidth}) async {
    try {
      if (!await videoFile.exists()) {
        AppLogger.e(
          'Cannot generate thumbnail for non-existent video file',
          category: LogCategory.media,
          data: {'path': videoFile.path},
        );
        return null;
      }

      // Determine optimal quality
      final quality = await _getOptimalImageQuality(null);

      // Generate thumbnail
      final thumbnailData = await VideoCompress.getByteThumbnail(
        videoFile.path,
        quality: quality,
        position: -1, // Default position
      );

      if (thumbnailData == null) {
        AppLogger.e(
          'Failed to generate video thumbnail',
          category: LogCategory.media,
          data: {'path': videoFile.path},
        );
        return null;
      }

      // Save thumbnail to file
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

  /// Create a temporary file with specified extension
  Future<File> _createTempFile(String extension) async {
    _tempDir ??= await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = Random().nextInt(10000);
    return File('${_tempDir!.path}/media_${timestamp}_$random$extension');
  }

  /// Get image dimensions
  Future<Tuple2<int, int>?> _getImageDimensions(File imageFile) async {
    try {
      // Use compute for off-main-thread processing
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

  /// Determine optimal image quality based on network conditions
  Future<int> _getOptimalImageQuality(int? requestedQuality) async {
    // Use requested quality if provided
    if (requestedQuality != null) {
      return requestedQuality.clamp(
          _minImageQuality.toInt(), _maxImageQuality.toInt());
    }

    // Fall back to default if adaptive compression disabled
    if (!_adaptiveCompressionEnabled) {
      return _defaultImageQuality;
    }

    // Check network conditions for adaptive quality
    try {
      if (locator.isRegistered<NetworkOptimizer>()) {
        final networkOptimizer = locator<NetworkOptimizer>();
        final qualityFactor = networkOptimizer.getOptimalImageQuality();

        // Scale between min and max quality
        final range = _maxImageQuality - _minImageQuality;
        final quality = (_minImageQuality + (range * qualityFactor)).round();

        return quality;
      }
    } catch (e) {
      // Ignore errors and use default
    }

    return _defaultImageQuality;
  }

  /// Determine optimal video quality based on network conditions
  Future<VideoQuality> _getOptimalVideoQuality(int? targetQuality) async {
    // Use requested quality directly if specified
    if (targetQuality != null) {
      return _getVideoQualityFromResolution(targetQuality);
    }

    // Fall back to default if adaptive compression disabled
    if (!_adaptiveCompressionEnabled) {
      return _getVideoQualityFromResolution(_defaultVideoQuality);
    }

    // Check network conditions for adaptive quality
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

    return _getVideoQualityFromResolution(_defaultVideoQuality);
  }

  /// Convert resolution to VideoQuality enum
  VideoQuality _getVideoQualityFromResolution(int resolution) {
    if (resolution <= 480) {
      return VideoQuality.LowQuality;
    } else if (resolution <= 720) {
      return VideoQuality.MediumQuality;
    } else {
      return VideoQuality.HighestQuality;
    }
  }

  /// Clean up temporary files
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

  /// Dispose stream controllers to prevent memory leaks
  void dispose() {
    _progressController.close();
    _completionController.close();
  }
}

/// Utility class for returning tuples
class Tuple2<T1, T2> {
  final T1 item1;
  final T2 item2;

  Tuple2(this.item1, this.item2);
}

/// Helper function to decode image dimensions in an isolate
Tuple2<int, int>? _decodeImageDimensions(Uint8List bytes) {
  try {
    final decodedImage = img.decodeImage(bytes);
    if (decodedImage != null) {
      return Tuple2(decodedImage.width, decodedImage.height);
    }
  } catch (_) {
    // Return null if decoding fails
  }
  return null;
}
