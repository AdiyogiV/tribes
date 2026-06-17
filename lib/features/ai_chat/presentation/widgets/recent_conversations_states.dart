import 'package:aurogram/core/theme/app_dimensions.dart';
import 'package:flutter/material.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/core/theme/header_style.dart';
import 'package:aurogram/shared/presentation/widgets/loaders/skeleton_widgets.dart';

class RecentConversationsSkeleton extends StatelessWidget {
  const RecentConversationsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.only(top: AppHeaderStyle.contentTopPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppHeaderStyle.contentHorizontalPadding + 4,
              0,
              AppHeaderStyle.contentHorizontalPadding,
              12,
            ),
            child: Row(
              children: const [
                SkeletonBox(width: 50, height: 14, borderRadius: 6),
                SizedBox(width: AppDimensions.spacingSm),
                SkeletonBox(width: 24, height: 18, borderRadius: 9),
              ],
            ),
          ),
          ...List.generate(6, (index) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                AppHeaderStyle.contentHorizontalPadding,
                0,
                AppHeaderStyle.contentHorizontalPadding,
                AppHeaderStyle.cardVerticalGap,
              ),
              child: Container(
                height: AppHeaderStyle.cardCompactHeight,
                padding: const EdgeInsets.only(left: 16, right: 12),
                decoration: BoxDecoration(
                  color: isDark
                      ? Theme.of(context).colorScheme.surface
                      : Colors.white,
                  borderRadius:
                      BorderRadius.circular(AppHeaderStyle.cardBorderRadius),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: const [
                    SkeletonBox(width: 44, height: 44, borderRadius: 22),
                    SizedBox(width: AppDimensions.spacingMdLg),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SkeletonBox(
                              width: double.infinity,
                              height: 14,
                              borderRadius: 6),
                          SizedBox(height: AppDimensions.spacingSmMd),
                          SkeletonBox(width: 120, height: 12, borderRadius: 5),
                        ],
                      ),
                    ),
                    SizedBox(width: AppDimensions.spacingMd),
                    SkeletonBox(width: 30, height: 12, borderRadius: 5),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class RecentConversationsEmpty extends StatelessWidget {
  const RecentConversationsEmpty({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: AppHeaderStyle.contentTopPadding + 16),
      child: Column(
        children: [
          Icon(
            Icons.forum_outlined,
            size: 52,
            color: AppTheme.primaryColor.withValues(alpha: 0.3),
          ),
          const SizedBox(height: AppDimensions.spacingMd),
          Text(
            'No conversations yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.primaryColor.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: AppDimensions.spacingSm),
          Text(
            'Start a new chat from HolyCow to see it here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.primaryColor.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}

class RecentConversationsNoResults extends StatelessWidget {
  const RecentConversationsNoResults({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: AppHeaderStyle.contentTopPadding + 16),
      child: Column(
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 52,
            color: AppTheme.primaryColor.withValues(alpha: 0.3),
          ),
          const SizedBox(height: AppDimensions.spacingMd),
          Text(
            'No results found',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.primaryColor.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: AppDimensions.spacingSm),
          Text(
            'Try a different keyword.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.primaryColor.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}

class RecentConversationsError extends StatelessWidget {
  const RecentConversationsError({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: AppHeaderStyle.contentTopPadding + 16),
      child: Column(
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 52,
            color: AppTheme.errorColor.withValues(alpha: 0.6),
          ),
          const SizedBox(height: AppDimensions.spacingMd),
          Text(
            'Unable to load conversations',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.primaryColor.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: AppDimensions.spacingSm),
          Text(
            'Please check your connection and try again.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.primaryColor.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}

class RecentConversationsSignInPrompt extends StatelessWidget {
  const RecentConversationsSignInPrompt({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: AppHeaderStyle.contentTopPadding + 16),
      child: Column(
        children: [
          Icon(
            Icons.lock_outline_rounded,
            size: 52,
            color: AppTheme.primaryColor.withValues(alpha: 0.3),
          ),
          const SizedBox(height: AppDimensions.spacingMd),
          Text(
            'Sign in to view conversations',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.primaryColor.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: AppDimensions.spacingSm),
          Text(
            'Your chats will appear here once you\'re signed in.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.primaryColor.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}
