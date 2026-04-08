import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/core/logging/app_logger.dart';
import 'package:aurogram/features/profile/presentation/widgets/preview_boxes/preview_box.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';

/// Mini post preview stack and bottom row builders for GramPreviewBox.
///
/// These are mixin-style helpers that operate on state passed in as parameters,
/// keeping the main state class smaller.
class GramPreviewMedia {
  GramPreviewMedia._();

  /// Build the mini post previews from a Firestore stream
  static Widget buildMiniPostPreviews({
    required BuildContext context,
    required String spaceId,
    required Stream<QuerySnapshot>? postPreviewsStream,
    required String? gramId,
    required int randomBase,
    required double Function(String, double, double) stableRandomInRange,
    bool isPublicSpace = true,
  }) {
    if (spaceId.isEmpty || postPreviewsStream == null) return const SizedBox.shrink();

    // For logged-out users, only show previews for public spaces
    final user = FirebaseAuth.instance.currentUser;
    if (user == null && !isPublicSpace) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<QuerySnapshot>(
      stream: postPreviewsStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          AppLogger.w(
            'GramPreviewBox post previews stream error',
            category: LogCategory.database,
            data: {
              'spaceId': spaceId,
              'error': snapshot.error.toString(),
            },
          );
          return const SizedBox.shrink();
        }
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return const SizedBox.shrink();
        }
        final posts = docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return {
            'id': doc.id,
            'thumbnail': data['thumbnail'],
            'title': data['title'],
            'author': data['author'],
            'postType': data['postType'] ?? 'video',
            'content': data['content'],
          };
        }).toList();
        return buildMiniPostStack(
          context: context,
          rawPosts: posts,
          gramId: gramId,
          randomBase: randomBase,
          stableRandomInRange: stableRandomInRange,
        );
      },
    );
  }

  static Widget buildMiniPostStack({
    required BuildContext context,
    required List<Map<String, dynamic>> rawPosts,
    required String? gramId,
    required int randomBase,
    required double Function(String, double, double) stableRandomInRange,
  }) {
    // Filter out permanently bad preview keys
    final List<Map<String, dynamic>> posts = rawPosts.where((p) {
      return true; // Let PreviewBox handle its own validation
    }).toList();

    if (posts.isEmpty) {
      return const SizedBox(width: 100, height: 44);
    }

    final int visible = math.min(posts.length, 7); // Show up to 7 previews

    // Calculate total width needed based on visible cards
    final double totalWidth = 40.0 + (visible > 1 ? (visible - 1) * 16.0 : 0);

    return SizedBox(
      width: totalWidth.clamp(100.0, 200.0),
      height: 44,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (int i = visible - 1; i >= 0; i--)
            _buildExponentialCard(
              context: context,
              post: posts[i],
              index: i,
              total: visible,
              gramId: gramId,
              randomBase: randomBase,
              stableRandomInRange: stableRandomInRange,
            ),
        ],
      ),
    );
  }

  static Widget _buildExponentialCard({
    required BuildContext context,
    required Map<String, dynamic> post,
    required int index,
    required int total,
    required String? gramId,
    required int randomBase,
    required double Function(String, double, double) stableRandomInRange,
  }) {
    final double cardSize = 40.0;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    double leftPosition = 0.0;
    if (index > 0) {
      double cumulativePosition = 0.0;
      for (int i = 1; i <= index; i++) {
        final double visibleWidth = math.max(12.0, 20.0 - (i * 1.5));
        cumulativePosition += visibleWidth;
      }
      leftPosition = cumulativePosition;
    }

    final int totalCards = math.max(1, total);
    final double t = totalCards > 1 ? index / (totalCards - 1) : 0.0;
    final double ease = t * t * (3 - 2 * t);
    final String seed =
        '${gramId ?? ''}_${post['id'] ?? ''}_${index}_$randomBase';
    const double baseMinStart = 1.0;
    const double baseMinEnd = 3.0;
    const double baseMaxStart = 3.0;
    const double baseMaxEnd = 8.0;
    final double minDegrees = baseMinStart + ease * (baseMinEnd - baseMinStart);
    final double maxDegrees = baseMaxStart + ease * (baseMaxEnd - baseMaxStart);
    final double clampedMin = math.min(minDegrees, maxDegrees - 0.1);
    final double degrees = stableRandomInRange(seed, clampedMin, maxDegrees);
    final double sign =
        stableRandomInRange('${seed}_sign', -1.0, 1.0) >= 0 ? 1.0 : -1.0;
    final double zigzagAngle = sign * (degrees * (math.pi / 180.0));

    final double elevation = totalCards > 1
        ? 4.0 * (1.0 - (index / (totalCards - 1)))
        : 4.0;

    return Positioned(
      left: leftPosition,
      top: 2,
      child: Transform.rotate(
        angle: zigzagAngle,
        child: Material(
          elevation: elevation,
          color: isDark ? AppTheme.cardDarkColor : Colors.white,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMdSm),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            width: cardSize,
            height: cardSize,
            child: _buildPostPreview(post),
          ),
        ),
      ),
    );
  }

  static Widget _buildPostPreview(Map<String, dynamic> post) {
    final String key = 'mini_${post['id'] ?? ''}';
    final String postType = (post['postType'] as String?) ?? 'video';

    return PreviewBox(
      key: ValueKey(key),
      previewUrl: (post['thumbnail'] as String?) ?? '',
      title: (post['title'] as String?) ?? '',
      author: null,
      content: (post['content'] as String?) ?? '',
      postType: postType,
      compact: true,
      showNoteIcon: false,
      hideWhileLoading: false,
      skipIfMissing: false,
    );
  }
}
