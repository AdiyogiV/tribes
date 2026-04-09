import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:aurogram/core/logging/app_logger.dart';

import 'media_compression_service.dart';

/// Queue management: add/remove/process items, progress tracking,
/// cancellation, migration, and cleanup.
extension CompressionQueueManager on MediaCompressionService {
  /// Adds a post to the compression queue for background processing.
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
      NetworkRequirement networkRequirement = NetworkRequirement.preferWifi,
      bool isProfilePost = false}) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      List<String> queue = prefs.getStringList(MediaCompressionService.COMPRESSION_QUEUE_KEY) ?? [];

      // Check if queue size exceeds the limit
      if (queue.length >= MediaCompressionService.MAX_QUEUE_SIZE) {
        AppLogger.w('Compression queue full, removing oldest item',
            category: LogCategory.general,
            data: {'queueSize': queue.length, 'maxSize': MediaCompressionService.MAX_QUEUE_SIZE});
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
        'progress': 0,
      };

      queue.add(jsonEncode(compressionInfo));
      await prefs.setStringList(MediaCompressionService.COMPRESSION_QUEUE_KEY, queue);

      // Store initial progress information
      Map<String, dynamic> progressMap = getProgressMap(prefs);
      progressMap[post] = {
        'status': 'queued',
        'progress': 0,
        'addedTimestamp': DateTime.now().millisecondsSinceEpoch,
        'title': title ?? 'Untitled Post',
        'thumbnailPath': thumbnailPath,
        'space': fetchedSpace,
      };
      await saveProgressMap(prefs, progressMap);

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

  // ── Progress map helpers ──────────────────────────────────────────────────

  /// Get a map of all compression progress information.
  Map<String, dynamic> getProgressMap(SharedPreferences prefs) {
    String progressJson = prefs.getString(MediaCompressionService.COMPRESSION_PROGRESS_KEY) ?? '{}';
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

  /// Save the progress map to shared preferences.
  Future<void> saveProgressMap(
      SharedPreferences prefs, Map<String, dynamic> progressMap) async {
    try {
      await prefs.setString(MediaCompressionService.COMPRESSION_PROGRESS_KEY, jsonEncode(progressMap));
    } catch (e) {
      AppLogger.w('Error saving compression progress map',
          category: LogCategory.general, data: {'error': e.toString()});
    }
  }

  // ── Progress queries ──────────────────────────────────────────────────────

  /// Get all upload progress information for UI display.
  Future<List<Map<String, dynamic>>> getUploadProgress() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      Map<String, dynamic> progressMap = getProgressMap(prefs);
      bool hasUpdates = false;

      List<Map<String, dynamic>> result = [];
      for (String postId in progressMap.keys) {
        var data = Map<String, dynamic>.from(progressMap[postId]);

        // Check and fix thumbnail paths
        String? thumbnailPath = data['thumbnailPath'] as String?;
        if (thumbnailPath != null && thumbnailPath.isNotEmpty) {
          if (!thumbnailPath.startsWith('http')) {
            String effectivePath = thumbnailPath;

            if (thumbnailPath.startsWith('file://')) {
              effectivePath = thumbnailPath.substring(7);
            }

            bool fileExists = false;
            try {
              if (effectivePath.startsWith('/')) {
                fileExists = await File(effectivePath).exists();
              }
            } catch (e) {
              AppLogger.w('Error checking thumbnail file existence',
                  category: LogCategory.general,
                  data: {'path': effectivePath, 'error': e.toString()});
            }

            if (!fileExists) {
              String? storageUrl = await tryGetStorageUrl(postId);
              if (storageUrl != null) {
                thumbnailPath = storageUrl;
                data['thumbnailPath'] = storageUrl;
                progressMap[postId]['thumbnailPath'] = storageUrl;
                hasUpdates = true;
                AppLogger.i('Updated thumbnail path to storage URL',
                    category: LogCategory.general, data: {'postId': postId});
              } else if (thumbnailPath.startsWith('/') ||
                  thumbnailPath.startsWith('file://')) {
                if (!thumbnailPath.startsWith('file:') &&
                    thumbnailPath.startsWith('/')) {
                  thumbnailPath = 'file://$thumbnailPath';
                  data['thumbnailPath'] = thumbnailPath;
                }
              }
            } else {
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
        await saveProgressMap(prefs, progressMap);
      }

      // Sort by timestamp (newest first)
      result.sort((a, b) =>
          (b['addedTimestamp'] ?? 0).compareTo(a['addedTimestamp'] ?? 0));

      return result;
    } catch (e) {
      AppLogger.w('Error getting upload progress',
          category: LogCategory.general, data: {'error': e.toString()});
      return [];
    }
  }

  /// Try to get the storage URL for a post's thumbnail.
  Future<String?> tryGetStorageUrl(String postId) async {
    try {
      final doc = await firestoreInstance.collection('posts').doc(postId).get();
      if (doc.exists && doc.data() != null) {
        final thumbnailUrl = doc.data()?['thumbnail'] as String?;
        if (thumbnailUrl != null && thumbnailUrl.startsWith('http')) {
          return thumbnailUrl;
        }
      }

      try {
        final ref =
            FirebaseStorage.instance.ref().child('posts/$postId/thumbnail.jpg');
        return await ref.getDownloadURL();
      } catch (e) {
        AppLogger.w('Could not get storage URL for thumbnail',
            category: LogCategory.general,
            data: {'postId': postId, 'error': e.toString()});
        return null;
      }
    } catch (e) {
      AppLogger.w('Error trying to get storage URL',
          category: LogCategory.general,
          data: {'postId': postId, 'error': e.toString()});
      return null;
    }
  }

  /// Get progress for a specific post.
  Future<Map<String, dynamic>?> getPostProgress(String postId) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      Map<String, dynamic> progressMap = getProgressMap(prefs);
      if (progressMap.containsKey(postId)) {
        return {
          'postId': postId,
          ...Map<String, dynamic>.from(progressMap[postId]),
        };
      }
      return null;
    } catch (e) {
      AppLogger.w('Error getting post progress',
          category: LogCategory.general,
          data: {'postId': postId, 'error': e.toString()});
      return null;
    }
  }

  // ── Progress updates ──────────────────────────────────────────────────────

  /// Updates progress for a specific post.
  Future<void> updateProgress(
      String postId, String status, int progress) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      Map<String, dynamic> progressMap = getProgressMap(prefs);

      if (progressMap.containsKey(postId)) {
        final currentProgress = progressMap[postId]['progress'] ?? 0;
        final currentStatus = progressMap[postId]['status'];

        if (status != currentStatus || progress > currentProgress) {
          progressMap[postId]['status'] = status;
          progressMap[postId]['progress'] = progress;
          progressMap[postId]['lastUpdated'] =
              DateTime.now().millisecondsSinceEpoch;

          await saveProgressMap(prefs, progressMap);

          // EVENT-DRIVEN: Emit progress event for real-time updates
          final progressEvent = UploadProgressEvent(
            postId: postId,
            status: status,
            progress: progress,
            timestamp: DateTime.now(),
          );
          progressController.add(progressEvent);

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
            completionController.add(completionEvent);
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
      AppLogger.w('Error updating progress',
          category: LogCategory.general,
          data: {'postId': postId, 'error': e.toString()});
    }
  }

  /// Remove progress entry for completed upload.
  Future<void> clearProgressEntry(String postId, {bool success = true}) async {
    try {
      await updateProgress(
          postId, success ? 'completed' : 'failed', success ? 100 : 0);

      SharedPreferences prefs = await SharedPreferences.getInstance();
      Map<String, dynamic> progressMap = getProgressMap(prefs);

      if (progressMap.containsKey(postId)) {
        progressMap[postId]['status'] = success ? 'completed' : 'failed';
        progressMap[postId]['progress'] = success ? 100 : 0;
        progressMap[postId]['completedTimestamp'] =
            DateTime.now().millisecondsSinceEpoch;

        await saveProgressMap(prefs, progressMap);

        AppLogger.i('Progress entry marked',
            category: LogCategory.general,
            data: {
              'status': success ? 'completed' : 'failed',
              'postId': postId
            });

        cleanupOldCompletedUploads();
      }
    } catch (e) {
      AppLogger.w('Error clearing progress entry',
          category: LogCategory.general,
          data: {'postId': postId, 'error': e.toString()});
    }
  }

  /// Clean up old completed uploads from progress tracking.
  Future<void> cleanupOldCompletedUploads() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      Map<String, dynamic> progressMap = getProgressMap(prefs);

      final now = DateTime.now().millisecondsSinceEpoch;
      const oneHourInMs = 60 * 60 * 1000;

      progressMap.removeWhere((postId, data) {
        final isCompleted =
            data['status'] == 'completed' || data['status'] == 'failed';
        final completedTime = data['completedTimestamp'] ?? 0;
        return isCompleted && (now - completedTime > oneHourInMs);
      });

      await saveProgressMap(prefs, progressMap);
    } catch (e) {
      AppLogger.w('Error cleaning up old completed uploads',
          category: LogCategory.general, data: {'error': e.toString()});
    }
  }

  /// Remove a specific progress entry by postId.
  Future<void> removeProgressEntry(String postId) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      Map<String, dynamic> progressMap = getProgressMap(prefs);

      if (progressMap.containsKey(postId)) {
        progressMap.remove(postId);
        await saveProgressMap(prefs, progressMap);
      }
    } catch (e) {
      FirebaseCrashlytics.instance.recordError(e, StackTrace.current,
          reason: 'Error removing progress entry');
    }
  }

  // ── Queue processing ──────────────────────────────────────────────────────

  /// Processes the video compression queue.
  void processCompressionQueue() async {
    AppLogger.d('Processing compression queue started',
        category: LogCategory.general,
        data: {'isProcessing': MediaCompressionService.isProcessingQueue});

    if (MediaCompressionService.isProcessingQueue) {
      MediaCompressionService.shouldProcessAgain = true;
      AppLogger.d('Queue already processing, marking for retry',
          category: LogCategory.general);
      return;
    }

    MediaCompressionService.isProcessingQueue = true;
    MediaCompressionService.shouldProcessAgain = false;

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      List<String> queue = prefs.getStringList(MediaCompressionService.COMPRESSION_QUEUE_KEY) ?? [];

      AppLogger.d('Compression queue status',
          category: LogCategory.general, data: {'queueLength': queue.length});

      if (queue.isEmpty) {
        AppLogger.d('Compression queue is empty, stopping processing',
            category: LogCategory.general);
        MediaCompressionService.isProcessingQueue = false;
        return;
      }

      String nextItem = queue.removeAt(0);
      await prefs.setStringList(MediaCompressionService.COMPRESSION_QUEUE_KEY, queue);

      Map<String, dynamic> item = jsonDecode(nextItem);

      AppLogger.d('Starting compression for next queue item',
          category: LogCategory.general,
          data: {
            'postId': item['post'],
            'remainingQueue': queue.length,
            'attempts': item['attempts'] ?? 0,
            'videoPath': item['videoPath']
          });

      await compressAndUploadVideo(
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
      MediaCompressionService.isProcessingQueue = false;
      if (MediaCompressionService.shouldProcessAgain) {
        processCompressionQueue();
      }
    }
  }

  // ── Cancellation ──────────────────────────────────────────────────────────

  /// Cancels a pending upload.
  Future<bool> cancelUpload(String postId) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();

      List<String> queue = prefs.getStringList(MediaCompressionService.COMPRESSION_QUEUE_KEY) ?? [];
      bool wasInQueue = false;

      queue = queue.where((item) {
        try {
          Map<String, dynamic> data = jsonDecode(item);
          if (data['post'] == postId) {
            wasInQueue = true;
            return false;
          }
          return true;
        } catch (e) {
          return true;
        }
      }).toList();

      await prefs.setStringList(MediaCompressionService.COMPRESSION_QUEUE_KEY, queue);
      await updateProgress(postId, 'cancelled', 0);

      try {
        await firestoreInstance.collection('posts').doc(postId).delete();
      } catch (e) {
        AppLogger.w('Error deleting cancelled post from Firestore',
            category: LogCategory.general,
            data: {'postId': postId, 'error': e.toString()});
      }

      return wasInQueue;
    } catch (e) {
      AppLogger.w('Error cancelling upload',
          category: LogCategory.general,
          data: {'postId': postId, 'error': e.toString()});
      return false;
    }
  }

  // ── Failure handling ──────────────────────────────────────────────────────

  /// Handles failed compression attempts.
  Future<void> handleFailedCompression(
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
        int newAttempts = attempts + 1;

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
        List<String> queue = prefs.getStringList(MediaCompressionService.COMPRESSION_QUEUE_KEY) ?? [];

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

        await prefs.setStringList(MediaCompressionService.COMPRESSION_QUEUE_KEY, queue);
      } else {
        AppLogger.e('Compression failed after maximum attempts',
            category: LogCategory.general,
            data: {'postId': post, 'attempts': attempts});

        await postDbService.updatePostStatus(post, false);
        await clearProgressEntry(post, success: false);

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

  // ── Queue utilities ───────────────────────────────────────────────────────

  /// Clears the compression queue.
  Future<void> clearCompressionQueue() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(MediaCompressionService.COMPRESSION_QUEUE_KEY, []);
      AppLogger.d('Compression queue cleared', category: LogCategory.general);
    } catch (e) {
      AppLogger.w('Error clearing compression queue',
          category: LogCategory.general, data: {'error': e.toString()});
      FirebaseCrashlytics.instance.recordError(e, StackTrace.current,
          reason: 'Error clearing compression queue');
    }
  }

  /// Gets the size of the compression queue.
  Future<int> getCompressionQueueSize() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      List<String> queue = prefs.getStringList(MediaCompressionService.COMPRESSION_QUEUE_KEY) ?? [];
      return queue.length;
    } catch (e) {
      AppLogger.w('Error getting compression queue size',
          category: LogCategory.general, data: {'error': e.toString()});
      FirebaseCrashlytics.instance.recordError(e, StackTrace.current,
          reason: 'Error getting compression queue size');
      return 0;
    }
  }

  // ── Migration & status management ─────────────────────────────────────────

  /// Migrate and clean up existing upload entries.
  Future<void> migrateAndCleanupUploads() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      Map<String, dynamic> progressMap = getProgressMap(prefs);
      bool hasUpdates = false;

      List<String> postsToRemove = [];
      List<Future> migrationTasks = [];

      for (String postId in progressMap.keys) {
        final entry = progressMap[postId];
        final status = entry['status'] as String?;

        final timestamp = entry['addedTimestamp'] as int?;
        if (timestamp != null) {
          final daysOld = (DateTime.now().millisecondsSinceEpoch - timestamp) /
              (1000 * 60 * 60 * 24);
          if (daysOld > 7) {
            postsToRemove.add(postId);
            continue;
          }
        }

        final thumbnailPath = entry['thumbnailPath'] as String?;
        if (thumbnailPath != null && thumbnailPath.startsWith('http')) {
          continue;
        }

        if (status == 'completed') {
          migrationTasks.add(() async {
            final url = await tryGetStorageUrl(postId);
            if (url != null) {
              progressMap[postId]['thumbnailPath'] = url;
              hasUpdates = true;
            } else {
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
              AppLogger.w('Error checking file existence during migration',
                  category: LogCategory.general,
                  data: {'path': effectivePath, 'error': e.toString()});
            }

            if (!exists) {
              final url = await tryGetStorageUrl(postId);
              if (url != null) {
                progressMap[postId]['thumbnailPath'] = url;
                hasUpdates = true;
              } else if (status != 'completed' &&
                  status != 'failed' &&
                  status != 'cancelled') {
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

      await Future.wait(migrationTasks);

      for (final postId in postsToRemove) {
        progressMap.remove(postId);
      }

      if (hasUpdates || postsToRemove.isNotEmpty) {
        await saveProgressMap(prefs, progressMap);
        AppLogger.i('Migration completed',
            category: LogCategory.general,
            data: {
              'saved': progressMap.length,
              'removed': postsToRemove.length
            });
      }
    } catch (e) {
      AppLogger.w('Error during upload entry migration',
          category: LogCategory.general, data: {'error': e.toString()});
      FirebaseCrashlytics.instance.recordError(e, StackTrace.current,
          reason: 'Error during upload entry migration');
    }
  }

  /// Update a post's URL after upload completion.
  Future<void> updatePostUrlInProgress(String postId, String? spaceId) async {
    try {
      final postRef = firestoreInstance.collection('posts').doc(postId);
      final postDoc = await postRef.get();

      if (!postDoc.exists || postDoc.data() == null) {
        AppLogger.w('Post document not found for URL update',
            category: LogCategory.general, data: {'postId': postId});
        return;
      }

      SharedPreferences prefs = await SharedPreferences.getInstance();
      Map<String, dynamic> progressMap = getProgressMap(prefs);

      if (progressMap.containsKey(postId)) {
        progressMap[postId]['postUrl'] = postId;
        progressMap[postId]['spaceId'] = spaceId;
        progressMap[postId]['completedTimestamp'] =
            DateTime.now().millisecondsSinceEpoch;

        await saveProgressMap(prefs, progressMap);
      }
    } catch (e) {
      AppLogger.w('Error updating post URL in progress',
          category: LogCategory.general,
          data: {'postId': postId, 'error': e.toString()});
    }
  }

  /// Mark upload as complete and properly set navigation info.
  Future<void> markUploadAsComplete(String postId, String? spaceId) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      Map<String, dynamic> progressMap = getProgressMap(prefs);

      if (progressMap.containsKey(postId)) {
        await updatePostUrlInProgress(postId, spaceId);

        progressMap[postId]['status'] = 'completed';
        progressMap[postId]['progress'] = 100;
        progressMap[postId]['completedTimestamp'] =
            DateTime.now().millisecondsSinceEpoch;
        progressMap[postId]['spaceId'] = spaceId;

        await saveProgressMap(prefs, progressMap);
      }
    } catch (e) {
      AppLogger.w('Error marking upload as complete',
          category: LogCategory.general,
          data: {'postId': postId, 'error': e.toString()});
    }
  }

  /// Manually update the status of an upload.
  Future<void> updateUploadStatus(String postId, String status,
      {String? error}) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      Map<String, dynamic> progressMap = getProgressMap(prefs);

      if (progressMap.containsKey(postId)) {
        var data = Map<String, dynamic>.from(progressMap[postId]);

        data['status'] = status;

        if (error != null && error.isNotEmpty) {
          data['error'] = error;
        }

        if (status == 'failed' || status == 'completed') {
          data['completedTimestamp'] = DateTime.now().millisecondsSinceEpoch;
        }

        progressMap[postId] = data;
        await saveProgressMap(prefs, progressMap);
      }
    } catch (e) {
      AppLogger.w('Error updating upload status',
          category: LogCategory.general,
          data: {'postId': postId, 'error': e.toString()});
      FirebaseCrashlytics.instance.recordError(e, StackTrace.current,
          reason: 'Error updating upload status');
    }
  }
}
