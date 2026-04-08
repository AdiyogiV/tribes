import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:aurogram/features/feed/data/datasources/post_db_service.dart';
import 'package:aurogram/shared/services/media/video_prewarm_service.dart';
import 'package:aurogram/shared/services/batch_data_loader.dart';
import 'package:aurogram/features/feed/presentation/pages/feed_controller.dart';
import 'package:aurogram/core/logging/app_logger.dart';

/// Encapsulates the feed post preloading and batch user/space data loading logic
/// that was repeated across _loadFeed, _loadMorePosts, and _handleRefresh.
class FeedBatchPreloader {
  final PostDbService postDbService;
  final BatchDataLoader batchLoader;

  FeedBatchPreloader({
    required this.postDbService,
    required this.batchLoader,
  });

  /// Preload post data ahead of viewport for instant rendering.
  ///
  /// Returns the list of valid post IDs (those that exist and have required fields).
  Future<List<String>> preloadPostData(
    int startIndex,
    int count, {
    required List<String> postIds,
  }) async {
    if (startIndex >= postIds.length) return [];

    final startTime = DateTime.now();
    final endIndex = (startIndex + count).clamp(0, postIds.length);
    final postsToPreload = postIds.sublist(startIndex, endIndex);
    final validPostIds = <String>[];

    if (kDebugMode) {
      AppLogger.i(
        'Preload START',
        category: LogCategory.performance,
        data: {'start': startIndex, 'count': postsToPreload.length},
      );
    }

    final results = await postDbService.getPosts(postsToPreload);
    for (final postId in postsToPreload) {
      final snapshot = results[postId];
      if (snapshot == null || !snapshot.exists) {
        postDbService.markPostAsMissing(postId);
        postDbService.cleanupMissingPostReferences(postId);
        continue;
      }
      final data = snapshot.data() as Map<String, dynamic>?;
      if (data == null) {
        postDbService.markPostAsMissing(postId);
        postDbService.cleanupMissingPostReferences(postId);
        continue;
      }
      final uploading = data['uploading'] as bool? ?? false;
      final hasRequired = data['timestamp'] != null &&
          data['author'] != null &&
          data['space'] != null;
      if (!hasRequired && !uploading) {
        postDbService.markPostAsMissing(postId);
        postDbService.cleanupMissingPostReferences(postId);
        continue;
      }
      validPostIds.add(postId);

      final postType = data['postType'] as String? ?? 'video';
      final videoUrl = data['video'] as String?;
      if (postType == 'video' &&
          videoUrl != null &&
          videoUrl.isNotEmpty &&
          !uploading) {
        VideoPrewarmService().prewarm(postId, videoUrl);
      }
    }

    final endTime = DateTime.now();
    final durationMs = endTime.difference(startTime).inMilliseconds;

    if (kDebugMode) {
      final successCount = results.values.where((doc) => doc != null).length;
      final errorCount = results.values.where((doc) => doc == null).length;
      AppLogger.i(
        'Preload COMPLETE',
        category: LogCategory.performance,
        data: {
          'start': startIndex,
          'total': postsToPreload.length,
          'success': successCount,
          'errors': errorCount,
          'took_ms': durationMs,
          'avg_ms_per_post':
              (durationMs / postsToPreload.length).toStringAsFixed(1),
          'validCount': validPostIds.length,
        },
      );
    }

    return validPostIds;
  }

  /// Batch load counters for a list of valid post IDs.
  Future<void> batchLoadCounters(
    List<String> validPostIds,
    FeedController feedController,
  ) async {
    if (validPostIds.isEmpty) return;
    try {
      await feedController.batchLoadCounters(validPostIds);
      if (kDebugMode) {
        AppLogger.i(
          'Batch counter load complete',
          category: LogCategory.performance,
          data: {'count': validPostIds.length},
        );
      }
    } catch (e) {
      AppLogger.w('Batch counter load failed', data: {'error': e.toString()});
    }
  }

  /// Batch load user and space data for a list of post IDs and store them
  /// in [feedController] for instant header rendering.
  Future<void> batchLoadUserSpaceData(
    List<String> validPostIds,
    FeedController feedController,
  ) async {
    if (validPostIds.isEmpty) return;

    try {
      final userIds = <String>{};
      final spaceIds = <String>{};

      for (final postId in validPostIds) {
        final cached = postDbService.peekPost(postId);
        if (cached != null && cached.exists) {
          final data = cached.data() as Map<String, dynamic>?;
          if (data != null) {
            final authorId = data['author'] as String?;
            final spaceId = data['space'] as String?;
            if (authorId != null) userIds.add(authorId);
            if (spaceId != null) spaceIds.add(spaceId);
          }
        }
      }

      final userDataFuture = batchLoader.batchLoadUsers(userIds.toList());
      final spaceDataFuture = batchLoader.batchLoadSpaces(spaceIds.toList());
      final results = await Future.wait([userDataFuture, spaceDataFuture]);

      final userData = results[0] as Map<String, UserData>;
      final spaceData = results[1] as Map<String, SpaceData>;

      for (final postId in validPostIds) {
        final cached = postDbService.peekPost(postId);
        if (cached != null && cached.exists) {
          final data = cached.data() as Map<String, dynamic>?;
          if (data != null) {
            final authorId = data['author'] as String?;
            final spaceId = data['space'] as String?;
            if (authorId != null && userData.containsKey(authorId)) {
              feedController.setUserData(postId, userData[authorId]!);
            }
            if (spaceId != null && spaceData.containsKey(spaceId)) {
              feedController.setSpaceData(postId, spaceData[spaceId]!);
            }
          }
        }
      }

      if (kDebugMode) {
        AppLogger.i(
          'User/space data loaded',
          category: LogCategory.performance,
          data: {
            'users': userData.length,
            'spaces': spaceData.length,
          },
        );
      }
    } catch (e) {
      AppLogger.w('Error batch loading user/space data',
          data: {'error': e.toString()});
    }
  }
}
