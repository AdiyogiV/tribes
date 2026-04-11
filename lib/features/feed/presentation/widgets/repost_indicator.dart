import 'package:aurogram/core/theme/app_dimensions.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/shared/presentation/widgets/avatars/user_avatar.dart';

/// Widget that shows repost information at the top of a reposted post
class RepostIndicator extends StatelessWidget {
  final String reposterName;
  final String? reposterAvatar;
  final String originalAuthorName;
  final String? reposterId;
  final VoidCallback? onTapReposter;

  const RepostIndicator({
    super.key,
    required this.reposterName,
    this.reposterAvatar,
    required this.originalAuthorName,
    this.reposterId,
    this.onTapReposter,
  });

  void _handleTap(BuildContext context) {
    if (onTapReposter != null) {
      onTapReposter!();
      return;
    }

    // Navigate to reposter's profile if reposterId is available
    if (reposterId != null && reposterId!.isNotEmpty) {
      context.push('/user/profile/${reposterId!}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _handleTap(context),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
        color: AppTheme.scaffoldColor,
        child: Row(
          children: [
            Icon(
              Icons.repeat_rounded,
              size: 16,
              color: AppTheme.textSecondaryColor,
            ),
            const SizedBox(width: AppDimensions.spacingSm),
            // Reposter avatar
            if (reposterAvatar != null && reposterAvatar!.isNotEmpty)
              UserAvatar(
                imageUrl: reposterAvatar,
                size: 20,
                nameInitials: reposterName.isNotEmpty
                    ? reposterName.substring(0, 1).toUpperCase()
                    : null,
              )
            else
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                ),
                child: Icon(
                  Icons.person,
                  size: 12,
                  color: AppTheme.primaryColor.withValues(alpha: 0.5),
                ),
              ),
            const SizedBox(width: AppDimensions.spacingSm),
            Expanded(
              child: Text(
                '$reposterName reposted from $originalAuthorName',
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondaryColor,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact repost indicator for smaller spaces
class CompactRepostIndicator extends StatelessWidget {
  final String reposterName;
  final VoidCallback? onTap;

  const CompactRepostIndicator({
    super.key,
    required this.reposterName,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.repeat_rounded,
              size: 12,
              color: AppTheme.textSecondaryColor,
            ),
            const SizedBox(width: AppDimensions.spacingXs),
            Text(
              '$reposterName reposted',
              style: TextStyle(
                fontSize: 11,
                color: AppTheme.textSecondaryColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
