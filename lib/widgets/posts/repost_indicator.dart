import 'package:flutter/material.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:aurogram/widgets/user_avatar.dart';
import 'package:aurogram/pages/tabs/user_profile.dart';

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
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => UserProfilePage(uid: reposterId!),
        ),
      );
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
            const SizedBox(width: 8),
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
                  color: AppTheme.primaryColor.withOpacity(0.1),
                ),
                child: Icon(
                  Icons.person,
                  size: 12,
                  color: AppTheme.primaryColor.withOpacity(0.5),
                ),
              ),
            const SizedBox(width: 8),
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
            const SizedBox(width: 4),
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
