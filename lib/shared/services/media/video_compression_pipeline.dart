import 'dart:async';
import 'dart:io';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as path;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:video_compress/video_compress.dart';
import 'package:aurogram/core/logging/app_logger.dart';

import 'media_compression_service.dart';

/// Core video compression and upload pipeline: compress, upload thumbnail,
/// upload video, update Firestore, handle replies, clean up.
extension VideoCompressionPipeline on MediaCompressionService {
  /// Compresses and uploads a video.
  Future<void> compressAndUploadVideo(
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
      NetworkRequirement networkRequirement = NetworkRequirement.preferWifi,
      bool isProfilePost = false}) async {
    // Keep track of all timers to cancel them when needed
    List<Timer> progressTimers = [];
    bool isProcessing = true;
    int currentProgress = 0;

    try {
      // Update status to compressing - starting progress
      await updateProgress(post, 'compressing', 10);
      currentProgress = 10;

      // Intermediate progress updates during compression
      void scheduleProgressUpdate(
          String phase, int progress, int delaySeconds) {
        if (progress <= currentProgress) return;

        progressTimers.add(Timer(Duration(seconds: delaySeconds), () async {
          if (isProcessing && progress > currentProgress) {
            await updateProgress(post, phase, progress);
            currentProgress = progress;
          }
        }));
      }

      scheduleProgressUpdate('compressing', 15, 2);
      scheduleProgressUpdate('compressing', 20, 5);
      scheduleProgressUpdate('compressing', 25, 10);

      // 1. Compress video
      String? compressedVideoPath = await _compressVideoFile(videoPath, post,
          quality: quality, resolution: resolution);

      if (compressedVideoPath == null) {
        isProcessing = false;
        for (var timer in progressTimers) {
          timer.cancel();
        }

        await updateProgress(post, 'compression_failed', 0);
        handleFailedCompression(post, videoPath, thumbnailPath, fetchedSpace,
            title, replyTo, replyToUid, addToSpaceFeed, link, attempts, userId,
            isProfilePost: isProfilePost);
        return;
      }

      // Compression complete
      if (30 > currentProgress) {
        await updateProgress(post, 'uploading_thumbnail', 30);
        currentProgress = 30;
      }

      if (35 > currentProgress) {
        progressTimers.add(Timer(Duration(seconds: 1), () async {
          if (isProcessing && 35 > currentProgress) {
            await updateProgress(post, 'uploading_thumbnail', 35);
            currentProgress = 35;
          }
        }));
      }

      // 2. Upload thumbnail
      AppLogger.d('Starting thumbnail upload',
          category: LogCategory.general,
          data: {'postId': post, 'thumbnailPath': thumbnailPath});

      String? thumbnail = await storageService.uploadToStorage(
          thumbnailPath, 'posts/$post/thumbnail.jpg');
      if (thumbnail == null) {
        isProcessing = false;
        for (var timer in progressTimers) {
          timer.cancel();
        }

        if (currentProgress < 30) {
          await updateProgress(post, 'thumbnail_upload_failed', 30);
        } else {
          await updateProgress(
              post, 'thumbnail_upload_failed', currentProgress);
        }

        AppLogger.e('Thumbnail upload failed',
            category: LogCategory.general,
            data: {'postId': post, 'thumbnailPath': thumbnailPath});

        handleFailedCompression(post, videoPath, thumbnailPath, fetchedSpace,
            title, replyTo, replyToUid, addToSpaceFeed, link, attempts, userId,
            isProfilePost: isProfilePost);
        return;
      }

      // Update post thumbnail immediately so UI can show it
      try {
        await postDbService.updatePostThumbnail(post, thumbnail);
      } catch (_) {
        AppLogger.w(
            'MediaCompressionService: failed to update post thumbnail',
            category: LogCategory.general);
      }

      // Update progress to video upload
      if (50 > currentProgress) {
        await updateProgress(post, 'uploading_video', 50);
        currentProgress = 50;
      }

      // 3. Upload compressed video with progress tracking
      AppLogger.d('Starting video upload',
          category: LogCategory.general,
          data: {'postId': post, 'compressedVideoPath': compressedVideoPath});

      if (60 > currentProgress) {
        progressTimers.add(Timer(Duration(seconds: 2), () async {
          if (isProcessing && 60 > currentProgress) {
            await updateProgress(post, 'uploading_video', 60);
            currentProgress = 60;
          }
        }));
      }

      if (70 > currentProgress) {
        progressTimers.add(Timer(Duration(seconds: 5), () async {
          if (isProcessing && 70 > currentProgress) {
            await updateProgress(post, 'uploading_video', 70);
            currentProgress = 70;
          }
        }));
      }

      // Upload video with progress reporting
      String? video = await storageService
          .uploadToStorage(compressedVideoPath, 'posts/$post/video.mp4',
              onProgress: (progressPercent) {
        double safePercent = progressPercent;
        if (safePercent.isNaN || !safePercent.isFinite) {
          safePercent = 0.0;
        }
        if (safePercent < 0.0) safePercent = 0.0;
        if (safePercent > 100.0) safePercent = 100.0;

        final int totalProgress = 50 + ((safePercent / 100.0) * 30.0).round();
        if (totalProgress > currentProgress) {
          updateProgress(post, 'uploading_video', totalProgress);
          currentProgress = totalProgress;
        }
      });

      if (video == null) {
        isProcessing = false;
        for (var timer in progressTimers) {
          timer.cancel();
        }

        await updateProgress(post, 'video_upload_failed', currentProgress);

        AppLogger.e('Video upload failed',
            category: LogCategory.general,
            data: {'postId': post, 'compressedVideoPath': compressedVideoPath});

        handleFailedCompression(post, videoPath, thumbnailPath, fetchedSpace,
            title, replyTo, replyToUid, addToSpaceFeed, link, attempts, userId,
            isProfilePost: isProfilePost);
        return;
      }

      // 4. Finalizing
      if (90 > currentProgress) {
        await updateProgress(post, 'finalizing', 90);
        currentProgress = 90;
      }

      // 5. Create or update post in Firestore
      if (95 > currentProgress) {
        progressTimers.add(Timer(Duration(seconds: 1), () async {
          if (isProcessing && 95 > currentProgress) {
            await updateProgress(post, 'finalizing', 95);
            currentProgress = 95;
          }
        }));
      }

      final actualUserId = userId ?? FirebaseAuth.instance.currentUser?.uid;
      if (actualUserId == null) {
        throw Exception('No user ID available for post');
      }

      AppLogger.d('CALLING updatePostWithMedia - CRITICAL STEP',
          category: LogCategory.general,
          data: {
            'postId': post,
            'videoUrl': video,
            'thumbnailUrl': thumbnail,
            'userId': actualUserId
          });

      bool updateSuccess =
          await postDbService.updatePostWithMedia(post, video, thumbnail);

      AppLogger.w(
          updateSuccess
              ? 'updatePostWithMedia SUCCESS'
              : 'updatePostWithMedia FAILED',
          category: LogCategory.general,
          data: {'postId': post, 'success': updateSuccess});

      // Add to appropriate feed
      if (isProfilePost) {
        await postDbService.addVideoToUserPosts(
            post, title, thumbnail, video, replyTo, link);
      } else if (addToSpaceFeed) {
        await postDbService.addToSpaceFeed(
            fetchedSpace, post, title, thumbnail, video, replyTo, link);
      }

      // 6. Handle replies if necessary
      if (replyTo != null) {
        await postDbService.addPostReply(
            fetchedSpace, post, title, thumbnail, video, replyTo, link);

        if (replyToUid != null && userId != null && replyToUid != userId) {
          await postDbService.addUserReply(
              replyToUid, fetchedSpace, post, title, thumbnail, video, link);
        }
      }

      AppLogger.d('Post upload and processing completed successfully',
          category: LogCategory.general,
          data: {'postId': post, 'videoUrl': video, 'thumbnailUrl': thumbnail});

      // Cancel all pending timers
      isProcessing = false;
      for (var timer in progressTimers) {
        timer.cancel();
      }
      progressTimers.clear();

      // Mark as complete
      await updateProgress(post, 'completed', 100);

      // Update status record for UI
      SharedPreferences prefs = await SharedPreferences.getInstance();
      Map<String, dynamic> progressMap = getProgressMap(prefs);

      if (progressMap.containsKey(post)) {
        progressMap[post]['status'] = 'completed';
        progressMap[post]['progress'] = 100;
        progressMap[post]['completedTimestamp'] =
            DateTime.now().millisecondsSinceEpoch;
        progressMap[post]['spaceId'] = fetchedSpace;

        await saveProgressMap(prefs, progressMap);
      }

      // 7. Clean up local files
      try {
        final videoFile = File(videoPath);
        if (await videoFile.exists()) {
          await videoFile.delete();
        }

        final thumbnailFile = File(thumbnailPath);
        if (await thumbnailFile.exists()) {
          await thumbnailFile.delete();
        }

        final compressedVideoFile = File(compressedVideoPath);
        if (await compressedVideoFile.exists()) {
          await compressedVideoFile.delete();
        }
      } catch (e) {
        AppLogger.w('Error cleaning up local files after upload',
            category: LogCategory.general, data: {'error': e.toString()});
      }

      // 8. Process next item in queue
      processCompressionQueue();
    } catch (e) {
      isProcessing = false;
      for (var timer in progressTimers) {
        timer.cancel();
      }

      await updateProgress(post, 'failed', 0);
      AppLogger.e('Error in compress and upload pipeline',
          category: LogCategory.general, error: e, data: {'postId': post});
      FirebaseCrashlytics.instance.recordError(e, StackTrace.current);
      handleFailedCompression(post, videoPath, thumbnailPath, fetchedSpace,
          title, replyTo, replyToUid, addToSpaceFeed, link, attempts, userId);
    }
  }

  /// Compresses a video file with the specified quality and resolution.
  Future<String?> _compressVideoFile(String videoPath, String postId,
      {CompressionQuality quality = CompressionQuality.balanced,
      VideoResolution resolution = VideoResolution.p720}) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final outputPath = path.join(tempDir.path, 'compressed_$postId.mp4');

      // Use video_compress package for basic compression
      try {
        final info = await VideoCompress.compressVideo(
          videoPath,
          quality: VideoQuality.MediumQuality,
          deleteOrigin: false,
        );

        if (info != null && info.path != null) {
          final compressedFile = File(info.path!);
          await compressedFile.copy(outputPath);
          await compressedFile.delete();

          AppLogger.i('Video compressed successfully using video_compress',
              category: LogCategory.general, data: {'outputPath': outputPath});
          return outputPath;
        } else {
          return null;
        }
      } catch (e) {
        AppLogger.w('video_compress compression failed',
            category: LogCategory.general,
            data: {'postId': postId, 'error': e.toString()});
        return null;
      }
    } catch (e) {
      FirebaseCrashlytics.instance.recordError(e, StackTrace.current);
      return null;
    }
  }
}
