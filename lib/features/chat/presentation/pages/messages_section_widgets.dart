import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/core/theme/header_style.dart';
import 'package:aurogram/shared/presentation/widgets/loaders/skeleton_widgets.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';

/// Section label card shown above groups of items (e.g. "ON AUROGRAM", "CONTACTS")
class MessagesSectionLabel extends StatelessWidget {
  final String title;
  final int count;
  final bool isDark;

  const MessagesSectionLabel({
    super.key,
    required this.title,
    required this.count,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final Color cardColor =
        isDark ? Theme.of(context).colorScheme.surface : Colors.white;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppHeaderStyle.contentHorizontalPadding,
        8,
        AppHeaderStyle.contentHorizontalPadding,
        AppHeaderStyle.cardVerticalGap,
      ),
      child: Material(
        color: cardColor,
        elevation: 0.5,
        shadowColor: Colors.black.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppHeaderStyle.cardBorderRadius),
        child: Container(
          height: 44,
          padding: EdgeInsets.symmetric(horizontal: AppDimensions.paddingLg),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                title.toUpperCase(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryColor.withValues(alpha: 0.7),
                  letterSpacing: 1.0,
                ),
              ),
              SizedBox(width: AppDimensions.spacingMdSm),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Card prompting the user to find friends via contact sync
class MessagesFindFriendsCard extends StatelessWidget {
  final bool isDark;
  final bool isLoading;
  final VoidCallback onTap;

  const MessagesFindFriendsCard({
    super.key,
    required this.isDark,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color cardColor =
        isDark ? Theme.of(context).colorScheme.surface : Colors.white;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppHeaderStyle.contentHorizontalPadding,
        0,
        AppHeaderStyle.contentHorizontalPadding,
        AppHeaderStyle.cardVerticalGap,
      ),
      child: Material(
        color: cardColor,
        elevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppHeaderStyle.cardBorderRadius),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppHeaderStyle.cardBorderRadius),
          onTap: isLoading ? null : onTap,
          child: Container(
            height: AppHeaderStyle.cardCompactHeight,
            padding: EdgeInsets.only(left: 20, right: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Find friends on Aurogram',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
                isLoading
                    ? const InlineShimmerLoader(size: 20)
                    : Icon(
                        Icons.chevron_right_rounded,
                        color: AppTheme.primaryColor.withValues(alpha: 0.5),
                        size: 24,
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Show N more" pagination button
class MessagesShowMoreButton extends StatelessWidget {
  final String type;
  final int remaining;
  final bool isDark;
  final ValueChanged<String> onShowMore;

  const MessagesShowMoreButton({
    super.key,
    required this.type,
    required this.remaining,
    required this.isDark,
    required this.onShowMore,
  });

  @override
  Widget build(BuildContext context) {
    final Color cardColor =
        isDark ? Theme.of(context).colorScheme.surface : Colors.white;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppHeaderStyle.contentHorizontalPadding,
        4,
        AppHeaderStyle.contentHorizontalPadding,
        AppHeaderStyle.cardVerticalGap,
      ),
      child: Material(
        color: cardColor,
        elevation: 0.5,
        shadowColor: Colors.black.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppHeaderStyle.cardBorderRadius),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppHeaderStyle.cardBorderRadius),
          onTap: () {
            HapticFeedback.lightImpact();
            onShowMore(type);
          },
          child: SizedBox(
            height: 50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.expand_more_rounded,
                  size: 20,
                  color: AppTheme.primaryColor.withValues(alpha: 0.7),
                ),
                SizedBox(width: AppDimensions.spacingSm),
                Text(
                  'Show $remaining more',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.primaryColor.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
