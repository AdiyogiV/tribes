import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'package:video_player/video_player.dart';
import 'package:aurogram/shared/services/cache_service.dart';
import 'package:aurogram/shared/services/media/video_controller_pool.dart';
import 'package:aurogram/core/di/injection.dart';
import 'package:aurogram/core/logging/app_logger.dart';

/// Prewarms video controllers for upcoming posts (small window).
class VideoPrewarmService {
  static final VideoPrewarmService _instance =
      VideoPrewarmService._internal();
  factory VideoPrewarmService() => _instance;
  VideoPrewarmService._internal();

  final Set<String> _inflight = {};

  Future<void> prewarm(String postId, String videoUrl) async {
    if (postId.isEmpty || videoUrl.isEmpty) return;
    final pool = VideoControllerPool();
    if (pool.hasController(postId) || _inflight.contains(postId)) return;
    _inflight.add(postId);

    final startTime = DateTime.now();
    VideoPlayerController? controller;
    try {
      if (kIsWeb) {
        controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
      } else {
        final cacheService = locator<CacheService>();
        final file = await cacheService.getFilefromCache(videoUrl);
        controller = file != null
            ? VideoPlayerController.file(file.file)
            : VideoPlayerController.networkUrl(Uri.parse(videoUrl));
        if (file == null) {
          cacheService.downloadFile(videoUrl);
        }
      }

      await controller.initialize();
      await controller.setLooping(false);
      await controller.setVolume(0.0);

      pool.addController(postId, controller);
      controller = null;

      if (kDebugMode) {
        AppLogger.d(
          'VideoPrewarm: initialized',
          category: LogCategory.media,
          data: {
            'postId': postId.substring(0, 4),
            'ms': DateTime.now().difference(startTime).inMilliseconds,
          },
        );
      }
    } catch (e) {
      AppLogger.w(
        'VideoPrewarm: failed',
        category: LogCategory.media,
        data: {'postId': postId.substring(0, 4), 'error': e.toString()},
      );
    } finally {
      _inflight.remove(postId);
      if (controller != null) {
        try {
          controller.dispose();
        } catch (_) {
          AppLogger.w('VideoPrewarmService: failed to dispose prewarm controller', category: LogCategory.general);
        }
      }
    }
  }
}
