import 'package:flutter/material.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/core/theme/header_style.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';

/// Sign-in prompt displayed when the user is not authenticated.
class BabaSignInPrompt extends StatelessWidget {
  final bool isDark;

  const BabaSignInPrompt({super.key, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingXxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.account_circle_outlined,
              size: 48,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
            const SizedBox(height: AppDimensions.spacingLg),
            Text(
              'Sign in to see\nyour chat history',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: AppTheme.babaTextSize,
                color: isDark ? Colors.white54 : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Placeholder shown when the conversation history is empty.
class BabaEmptyHistory extends StatelessWidget {
  final bool isDark;

  const BabaEmptyHistory({super.key, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingXxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.forum_outlined,
              size: 48,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
            const SizedBox(height: AppDimensions.spacingLg),
            Text(
              'No conversations yet',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: AppTheme.babaTextSize,
                color: isDark ? Colors.white54 : Colors.black54,
              ),
            ),
            const SizedBox(height: AppDimensions.spacingSm),
            Text(
              'Start chatting to see\nyour history here',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: AppTheme.babaTextSize,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Skeleton loader for the conversation history list.
class BabaHistorySkeleton extends StatelessWidget {
  const BabaHistorySkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: AppDimensions.paddingSm),
      itemCount: 5,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingLg, vertical: AppDimensions.paddingSm),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMdSm),
                ),
              ),
              const SizedBox(width: AppDimensions.spacingMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      height: 14,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(AppDimensions.radiusXs),
                      ),
                    ),
                    const SizedBox(height: AppDimensions.spacingSmMd),
                    Container(
                      height: 10,
                      width: 60,
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(AppDimensions.radiusXs),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Skeleton loader for the full cosmic dashboard while profile data is loading.
class AstroDashboardSkeleton extends StatelessWidget {
  final bool isDark;
  final Color brown;

  const AstroDashboardSkeleton({
    super.key,
    required this.isDark,
    required this.brown,
  });

  @override
  Widget build(BuildContext context) {
    // Using a simple shimmer-like appearance without depending on ShimmerBox import
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppHeaderStyle.contentHorizontalPadding,
        AppHeaderStyle.contentTopPadding,
        AppHeaderStyle.contentHorizontalPadding,
        16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 24,
            decoration: BoxDecoration(
              color: brown.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppDimensions.radiusSmMd),
            ),
          ),
          const SizedBox(height: AppDimensions.spacingXl),
          Container(
            height: 100,
            decoration: BoxDecoration(
              color: brown.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
            ),
          ),
          const SizedBox(height: AppDimensions.spacingXl),
          Container(
            height: 200,
            decoration: BoxDecoration(
              color: brown.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
            ),
          ),
        ],
      ),
    );
  }
}
