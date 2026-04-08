import 'dart:math';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:aurogram/core/logging/app_logger.dart';

/// In-memory cache of rendered post heights for feed layout stability.
/// Used for prefetch indexing and scroll offset preservation.
class FeedLayoutCache {
  final Map<String, double> _postHeights = {};

  double _averageHeight = 600.0;
  int _averageSampleCount = 0;
  int _heightUpdates = 0;

  double get averageHeight => _averageHeight;
  int get sampleCount => _averageSampleCount;
  int get measuredCount => _postHeights.length;

  void updateHeight(String postId, double height) {
    if (height <= 0) return;
    final previous = _postHeights[postId];
    _postHeights[postId] = height;
    _heightUpdates += 1;

    // Update running average with light smoothing.
    if (previous == null) {
      _averageSampleCount += 1;
      final weight = min(_averageSampleCount, 20);
      _averageHeight =
          ((_averageHeight * (weight - 1)) + height) / weight.toDouble();
    }

    if (kDebugMode) {
      final delta = previous != null ? (height - previous).abs() : height;
      if (delta > 40 || _heightUpdates % 25 == 0) {
        AppLogger.d(
          'FeedLayoutCache: height update',
          category: LogCategory.ui,
          data: {
            'postId': postId.substring(0, 4),
            'height': height.toStringAsFixed(1),
            'prev': previous?.toStringAsFixed(1),
            'avg': _averageHeight.toStringAsFixed(1),
            'measured': _postHeights.length,
          },
        );
      }
    }
  }

  double? getHeight(String postId) => _postHeights[postId];

  double estimateHeight(String postId) =>
      _postHeights[postId] ?? _averageHeight;

  double estimateRangeHeight(List<String> postIds) {
    if (postIds.isEmpty) return 0;
    double total = 0;
    for (final postId in postIds) {
      total += estimateHeight(postId);
    }
    return total;
  }

  int estimateIndexForOffset(List<String> feed, double offset) {
    if (feed.isEmpty) return 0;
    double cumulative = 0;
    for (int i = 0; i < feed.length; i++) {
      cumulative += estimateHeight(feed[i]);
      if (cumulative >= offset) return i;
    }
    return max(0, feed.length - 1);
  }
}
