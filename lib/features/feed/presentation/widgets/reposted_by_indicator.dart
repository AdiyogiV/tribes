import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:aurogram/core/theme/app_theme.dart';

/// Twitter-style indicator: "X reposted" above the post when viewing an original
/// post in a repost context (e.g. opened from reposter's profile or in a feed of reposts).
/// Explains to the viewer why they are seeing this post.
class RepostedByIndicator extends StatelessWidget {
  final String reposterName;
  final String? reposterAvatarUrl;

  const RepostedByIndicator({
    super.key,
    required this.reposterName,
    this.reposterAvatarUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (reposterAvatarUrl != null && reposterAvatarUrl!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: CircleAvatar(
                radius: 10,
                backgroundColor: AppTheme.successColor.withValues(alpha: 0.2),
                backgroundImage: CachedNetworkImageProvider(reposterAvatarUrl!),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Icon(
                CupertinoIcons.arrow_2_squarepath,
                size: 18,
                color: AppTheme.successColor,
              ),
            ),
          Flexible(
            child: Text(
              '${reposterName.isEmpty ? "Someone" : reposterName} reposted',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppTheme.successColor,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
