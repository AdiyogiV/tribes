import 'package:aurogram/core/theme/app_dimensions.dart';
import 'package:flutter/material.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/shared/presentation/widgets/universal/transparent_toolbox.dart';
import 'package:aurogram/shared/models/astrology_profile.dart';
import 'package:aurogram/shared/models/daily_insight.dart';

/// Daily insights card showing personalized astrology insight text.
class ProfileInsightsCard extends StatelessWidget {
  final bool isDark;
  final Future<AstrologyProfile?>? astrologyProfileFuture;
  final Stream<DailyInsight?>? dailyInsightStream;
  final VoidCallback? onTap;

  const ProfileInsightsCard({
    super.key,
    required this.isDark,
    required this.astrologyProfileFuture,
    required this.dailyInsightStream,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = AppTheme.primaryColor;

    return FutureBuilder<AstrologyProfile?>(
      future: astrologyProfileFuture,
      builder: (context, snapshot) {
        final isLoading = snapshot.connectionState == ConnectionState.waiting;
        final profile = snapshot.data;
        final hasProfile =
            profile != null && profile.isEnabled && profile.hasCalculatedData;

        // While the astrology future is still loading, show a skeleton
        // placeholder so the card reserves space instead of being invisible.
        if (isLoading) {
          return _buildInsightsLoadingSkeleton(context, primaryColor);
        }

        if (!hasProfile) {
          return const SizedBox.shrink();
        }

        return TransparentToolbox.buildCard(
          context: context,
          onTap: onTap,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'INSIGHTS',
                      style: AppTheme.cardLabelStyle,
                    ),
                    const SizedBox(height: AppDimensions.spacingSm),
                    StreamBuilder<DailyInsight?>(
                      stream: dailyInsightStream,
                      builder: (context, insightSnapshot) {
                        final insight = insightSnapshot.data;
                        final isLoading = insightSnapshot.connectionState ==
                            ConnectionState.waiting;

                        if (isLoading) {
                          // Skeleton loading state
                          final skeletonBase = isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : primaryColor.withValues(alpha: 0.1);
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: double.infinity,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: skeletonBase,
                                  borderRadius: BorderRadius.circular(AppDimensions.radiusSmMd),
                                ),
                              ),
                              const SizedBox(height: AppDimensions.spacingSm),
                              Container(
                                width: MediaQuery.of(context).size.width * 0.7,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: skeletonBase,
                                  borderRadius: BorderRadius.circular(AppDimensions.radiusSmMd),
                                ),
                              ),
                              const SizedBox(height: AppDimensions.spacingSm),
                              Container(
                                width: MediaQuery.of(context).size.width * 0.5,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: skeletonBase,
                                  borderRadius: BorderRadius.circular(AppDimensions.radiusSmMd),
                                ),
                              ),
                            ],
                          );
                        } else if (insight != null &&
                            insight.message.isNotEmpty) {
                          // Use rich text formatting to handle **bold** and _italic_ markdown
                          return _buildFormattedInsightText(
                              insight.message, primaryColor);
                        } else {
                          return Text(
                            'Tap to generate your personalized insight.',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: primaryColor.withValues(alpha: 0.6),
                              fontStyle: FontStyle.italic,
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: AppTheme.primaryLow,
              ),
            ],
          ),
        );
      },
    );
  }

  /// Skeleton placeholder shown while the astrology profile future resolves.
  /// Reserves the same height as a loaded insights card so the layout doesn't
  /// jump when the real content appears.
  Widget _buildInsightsLoadingSkeleton(BuildContext context, Color primaryColor) {
    final skeletonBase = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : primaryColor.withValues(alpha: 0.1);

    return TransparentToolbox.buildCard(
      context: context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'INSIGHTS',
            style: AppTheme.cardLabelStyle,
          ),
          const SizedBox(height: AppDimensions.spacingSm),
          Container(
            width: double.infinity,
            height: 12,
            decoration: BoxDecoration(
              color: skeletonBase,
              borderRadius: BorderRadius.circular(AppDimensions.radiusSmMd),
            ),
          ),
          const SizedBox(height: AppDimensions.spacingSm),
          Container(
            width: MediaQuery.of(context).size.width * 0.7,
            height: 12,
            decoration: BoxDecoration(
              color: skeletonBase,
              borderRadius: BorderRadius.circular(AppDimensions.radiusSmMd),
            ),
          ),
          const SizedBox(height: AppDimensions.spacingSm),
          Container(
            width: MediaQuery.of(context).size.width * 0.5,
            height: 12,
            decoration: BoxDecoration(
              color: skeletonBase,
              borderRadius: BorderRadius.circular(AppDimensions.radiusSmMd),
            ),
          ),
        ],
      ),
    );
  }

  /// Build formatted insight text with markdown-style formatting:
  /// - **bold** renders in bold
  /// - _italic_ renders in italic
  Widget _buildFormattedInsightText(String text, Color baseColor) {
    final List<TextSpan> spans = [];
    final RegExp pattern = RegExp(r'\*\*(.+?)\*\*|_(.+?)_|([^*_]+)');

    final baseStyle = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w500,
      color: baseColor.withValues(alpha: 0.85),
      height: 1.5,
    );

    for (final match in pattern.allMatches(text)) {
      if (match.group(1) != null) {
        // **bold**
        spans.add(TextSpan(
          text: match.group(1),
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: baseColor,
          ),
        ));
      } else if (match.group(2) != null) {
        // _italic_
        spans.add(TextSpan(
          text: match.group(2),
          style: TextStyle(
            fontStyle: FontStyle.italic,
            color: baseColor.withValues(alpha: 0.85),
          ),
        ));
      } else if (match.group(3) != null) {
        // Regular text
        spans.add(TextSpan(text: match.group(3)));
      }
    }

    return RichText(
      text: TextSpan(
        style: baseStyle,
        children: spans.isEmpty ? [TextSpan(text: text)] : spans,
      ),
    );
  }
}
