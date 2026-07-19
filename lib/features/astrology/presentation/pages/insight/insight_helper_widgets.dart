import 'package:flutter/material.dart';
import 'package:aurogram/shared/presentation/widgets/media/common_widgets.dart';
import 'package:aurogram/shared/presentation/widgets/loaders/skeleton_widgets.dart';
import 'package:aurogram/shared/presentation/widgets/flash.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';

/// Skeleton loading placeholder for insight cards.
class InsightSkeleton extends StatelessWidget {
  const InsightSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = SkeletonColors.fromContext(context);

    return ShimmerBox(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding:
            const EdgeInsets.symmetric(horizontal: AppDimensions.paddingLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: AppDimensions.spacingLg),
            // Date header skeleton
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: colors.highlight,
                    borderRadius:
                        BorderRadius.circular(AppDimensions.radiusMdSm),
                  ),
                ),
                const SizedBox(width: AppDimensions.spacingMd),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                        width: 140,
                        height: 18,
                        decoration: BoxDecoration(
                            color: colors.base,
                            borderRadius: BorderRadius.circular(9))),
                    const SizedBox(height: AppDimensions.spacingSmMd),
                    Container(
                        width: 100,
                        height: 12,
                        decoration: BoxDecoration(
                            color: colors.shimmer,
                            borderRadius: BorderRadius.circular(
                                AppDimensions.radiusSmMd))),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spacingXxl),
            // Insight cards
            ...List.generate(
                3,
                (index) => Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(AppDimensions.paddingXl),
                      decoration: BoxDecoration(
                        color: colors.base,
                        borderRadius:
                            BorderRadius.circular(AppDimensions.radiusXl),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: colors.highlight,
                                  borderRadius: BorderRadius.circular(
                                      AppDimensions.radiusMd),
                                ),
                              ),
                              const SizedBox(width: AppDimensions.spacingMd),
                              Expanded(
                                child: Container(
                                    height: 18,
                                    decoration: BoxDecoration(
                                        color: colors.highlight,
                                        borderRadius:
                                            BorderRadius.circular(9))),
                              ),
                              const SizedBox(width: AppDimensions.spacingMd),
                              Container(
                                  width: 50,
                                  height: 28,
                                  decoration: BoxDecoration(
                                      color: colors.shimmer,
                                      borderRadius: BorderRadius.circular(
                                          AppDimensions.radiusMdLg))),
                            ],
                          ),
                          const SizedBox(height: AppDimensions.spacingLg),
                          Container(
                              width: double.infinity,
                              height: 14,
                              decoration: BoxDecoration(
                                  color: colors.highlight,
                                  borderRadius: BorderRadius.circular(7))),
                          const SizedBox(height: AppDimensions.spacingMdSm),
                          Container(
                              width: MediaQuery.of(context).size.width * 0.75,
                              height: 14,
                              decoration: BoxDecoration(
                                  color: colors.shimmer,
                                  borderRadius: BorderRadius.circular(7))),
                          const SizedBox(height: AppDimensions.spacingMdSm),
                          Container(
                              width: MediaQuery.of(context).size.width * 0.5,
                              height: 14,
                              decoration: BoxDecoration(
                                  color: colors.shimmer,
                                  borderRadius: BorderRadius.circular(7))),
                        ],
                      ),
                    )),
            const SizedBox(height: AppDimensions.spacingLargeSection),
          ],
        ),
      ),
    );
  }
}

/// Parses and renders rich text with **bold**, _italic_, and symbols.
class InsightRichText extends StatelessWidget {
  final String text;
  final bool isDark;
  final Color brown;
  final double fontSize;

  const InsightRichText({
    super.key,
    required this.text,
    required this.isDark,
    required this.brown,
    this.fontSize = 13,
  });

  @override
  Widget build(BuildContext context) {
    final baseColor = brown.withValues(alpha: 0.85);

    final List<TextSpan> spans = [];
    final RegExp pattern = RegExp(r'\*\*(.+?)\*\*|_(.+?)_|([^*_]+)');

    for (final match in pattern.allMatches(text)) {
      if (match.group(1) != null) {
        spans.add(TextSpan(
          text: match.group(1),
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: brown,
          ),
        ));
      } else if (match.group(2) != null) {
        spans.add(TextSpan(
          text: match.group(2),
          style: TextStyle(
            fontStyle: FontStyle.italic,
            color: baseColor,
          ),
        ));
      } else if (match.group(3) != null) {
        spans.add(TextSpan(
          text: match.group(3),
          style: TextStyle(color: baseColor),
        ));
      }
    }

    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w500,
          height: 1.5,
          color: baseColor,
        ),
        children: spans.isEmpty ? [TextSpan(text: text)] : spans,
      ),
    );
  }
}

/// Single card style for legacy insight cards.
class LegacyInsightCard extends StatelessWidget {
  final String title;
  final String content;
  final bool isDark;
  final Color brown;

  const LegacyInsightCard({
    super.key,
    required this.title,
    required this.content,
    required this.isDark,
    required this.brown,
  });

  Color _cardColor(BuildContext context) {
    return isDark ? Theme.of(context).colorScheme.surface : Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    final hasContent = content.isNotEmpty;

    return Material(
      color: _cardColor(context),
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppDimensions.paddingLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: brown,
                letterSpacing: 0.5,
              ),
            ),
            if (hasContent) ...[
              const SizedBox(height: AppDimensions.spacingMd),
              InsightRichText(text: content, isDark: isDark, brown: brown),
            ],
          ],
        ),
      ),
    );
  }
}

/// Empty state card shown when no insight is available.
///
/// NOTE: This wraps [EmptyStateWidget] inside a Material card to match the
/// insight page's card-based visual style. The card wrapper is kept because
/// the insight page uses elevated cards for all content sections.
class InsightEmptyState extends StatelessWidget {
  final bool isDark;
  final Color brown;

  const InsightEmptyState({
    super.key,
    required this.isDark,
    required this.brown,
  });

  Color _cardColor(BuildContext context) {
    return isDark ? Theme.of(context).colorScheme.surface : Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _cardColor(context),
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingLg),
        child: EmptyStateWidget(
          icon: Icons.auto_awesome_rounded,
          iconColor: brown,
          title: 'Daily energy unavailable',
          subtitle:
              "Your daily energy reading is not ready yet. Return shortly to try again.",
          padding: EdgeInsets.zero,
        ),
      ),
    );
  }
}

/// Loading card with shimmer animation.
class InsightLoadingCard extends StatelessWidget {
  final bool isDark;
  final Color brown;

  const InsightLoadingCard({
    super.key,
    required this.isDark,
    required this.brown,
  });

  Color _cardColor(BuildContext context) {
    return isDark ? Theme.of(context).colorScheme.surface : Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _cardColor(context),
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppDimensions.paddingLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Preparing today's energy",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: brown,
              ),
            ),
            const SizedBox(height: AppDimensions.spacingMd),
            ShimmerText(
              text: 'Reading your sky...',
              baseColor: brown.withValues(alpha: 0.7),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ],
        ),
      ),
    );
  }
}
