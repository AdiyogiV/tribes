import 'package:flutter/material.dart';
import 'package:aurogram/utils/theme/app_dimensions.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:aurogram/widgets/astrology/cosmic_share_card.dart';
import 'package:aurogram/widgets/astrology/insight_share_card.dart';
import 'package:aurogram/widgets/spaces/gram_share_card.dart';
import 'package:aurogram/widgets/send_me_something/share_card_builder.dart';

class CosmicCardPreviewSheet extends StatelessWidget {
  final CosmicShareCard card;
  final VoidCallback onShare;
  final VoidCallback? onAddToStory;

  const CosmicCardPreviewSheet({
    super.key,
    required this.card,
    required this.onShare,
    this.onAddToStory,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: AppDimensions.spacingMd),
          Flexible(
            child: SingleChildScrollView(
              child: Transform.scale(
                scale: 0.85,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                  child: card,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppDimensions.spacingMd),
          Padding(
            padding: EdgeInsets.fromLTRB(24, 0, 24, bottomPadding + 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: onShare,
                    icon: const Icon(Icons.share_rounded, size: 20),
                    label: const Text('Share'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: AppDimensions.paddingMdLg),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppDimensions.radiusMdLg),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                if (onAddToStory != null) ...[
                  const SizedBox(height: AppDimensions.spacingMdSm),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: onAddToStory,
                      icon: const Icon(Icons.add_circle_outline, size: 18),
                      label: const Text('Add to Story'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primaryColor,
                        side: BorderSide(
                            color: AppTheme.primaryColor.withValues(alpha: 0.5)),
                        padding: const EdgeInsets.symmetric(vertical: AppDimensions.paddingMdLg),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppDimensions.radiusMdLg),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class GramCardPreviewSheet extends StatelessWidget {
  final GramShareCard card;
  final String spaceName;
  final VoidCallback onCopyLink;
  final VoidCallback onShareCard;
  final VoidCallback? onAddToStory;

  const GramCardPreviewSheet({
    super.key,
    required this.card,
    required this.spaceName,
    required this.onCopyLink,
    required this.onShareCard,
    this.onAddToStory,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: AppDimensions.spacingMd),
          Text(
            'Invite to $spaceName',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: AppDimensions.spacingMd),
          Flexible(
            child: SingleChildScrollView(
              child: Transform.scale(
                scale: 0.85,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                  child: card,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppDimensions.spacingMd),
          Padding(
            padding: EdgeInsets.fromLTRB(24, 0, 24, bottomPadding + 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onCopyLink,
                        icon: const Icon(Icons.link_rounded, size: 18),
                        label: const Text('Copy Link'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primaryColor,
                          side: BorderSide(
                              color: AppTheme.primaryColor.withValues(alpha: 0.5)),
                          padding: const EdgeInsets.symmetric(vertical: AppDimensions.paddingMdLg),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppDimensions.radiusMdLg),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppDimensions.spacingMd),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: onShareCard,
                        icon: const Icon(Icons.share_rounded, size: 18),
                        label: const Text('Share'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: AppDimensions.paddingMdLg),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppDimensions.radiusMdLg),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (onAddToStory != null) ...[
                  const SizedBox(height: AppDimensions.spacingMdSm),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: onAddToStory,
                      icon: const Icon(Icons.add_circle_outline, size: 18),
                      label: const Text('Add to Story'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primaryColor,
                        side: BorderSide(
                            color: AppTheme.primaryColor.withValues(alpha: 0.5)),
                        padding: const EdgeInsets.symmetric(vertical: AppDimensions.paddingMdLg),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppDimensions.radiusMdLg),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AnonymousLinkPreviewSheet extends StatelessWidget {
  final AnonymousLinkShareCard card;
  final VoidCallback onCopyLink;
  final VoidCallback onShareCard;

  const AnonymousLinkPreviewSheet({
    super.key,
    required this.card,
    required this.onCopyLink,
    required this.onShareCard,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: AppDimensions.spacingMd),
          Text(
            'Share your anonymous link',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: AppDimensions.spacingMd),
          Flexible(
            child: SingleChildScrollView(
              child: Transform.scale(
                scale: 0.85,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                  child: card,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppDimensions.spacingMd),
          Padding(
            padding: EdgeInsets.fromLTRB(24, 0, 24, bottomPadding + 12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onCopyLink,
                    icon: const Icon(Icons.link_rounded, size: 18),
                    label: const Text('Copy Link'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryColor,
                      side: BorderSide(
                          color: AppTheme.primaryColor.withValues(alpha: 0.5)),
                      padding: const EdgeInsets.symmetric(vertical: AppDimensions.paddingMdLg),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppDimensions.radiusMdLg),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppDimensions.spacingMd),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onShareCard,
                    icon: const Icon(Icons.share_rounded, size: 18),
                    label: const Text('Share Card'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: AppDimensions.paddingMdLg),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppDimensions.radiusMdLg),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class InsightCardPreviewSheet extends StatelessWidget {
  final InsightShareCard card;
  final VoidCallback onCopyText;
  final VoidCallback onShareCard;
  final VoidCallback? onAddToStory;

  const InsightCardPreviewSheet({
    super.key,
    required this.card,
    required this.onCopyText,
    required this.onShareCard,
    this.onAddToStory,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: AppDimensions.spacingMd),
          Text(
            'Share Your Insight',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: AppDimensions.spacingXs),
          Text(
            'Show friends what the stars say',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: AppDimensions.spacingLg),
          Flexible(
            child: SingleChildScrollView(
              child: Transform.scale(
                scale: 0.85,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                  child: card,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppDimensions.spacingLg),
          Padding(
            padding: EdgeInsets.fromLTRB(24, 0, 24, bottomPadding + 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onCopyText,
                        icon: const Icon(Icons.content_copy_rounded, size: 18),
                        label: const Text('Copy Text'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primaryColor,
                          side: BorderSide(
                              color: AppTheme.primaryColor.withValues(alpha: 0.5)),
                          padding: const EdgeInsets.symmetric(vertical: AppDimensions.paddingMdLg),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppDimensions.radiusMdLg),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppDimensions.spacingMd),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: onShareCard,
                        icon: const Icon(Icons.share_rounded, size: 18),
                        label: const Text('Share Card'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: AppDimensions.paddingMdLg),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppDimensions.radiusMdLg),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (onAddToStory != null) ...[
                  const SizedBox(height: AppDimensions.spacingMdSm),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: onAddToStory,
                      icon: const Icon(Icons.add_circle_outline, size: 18),
                      label: const Text('Add to Story'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.primaryColor,
                        side: BorderSide(
                            color: AppTheme.primaryColor.withValues(alpha: 0.5)),
                        padding: const EdgeInsets.symmetric(vertical: AppDimensions.paddingMdLg),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppDimensions.radiusMdLg),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CompatibilityCardPreviewSheet extends StatelessWidget {
  final Widget card;
  final String title;
  final VoidCallback onShare;

  const CompatibilityCardPreviewSheet({
    super.key,
    required this.card,
    required this.title,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: AppDimensions.spacingMd),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: AppDimensions.spacingMd),
          Flexible(
            child: SingleChildScrollView(
              child: Transform.scale(
                scale: 0.85,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                  child: card,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppDimensions.spacingMd),
          Padding(
            padding: EdgeInsets.fromLTRB(24, 0, 24, bottomPadding + 12),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onShare,
                icon: const Icon(Icons.share_rounded, size: 20),
                label: const Text('Share'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: AppDimensions.paddingMdLg),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMdLg),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
