import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:aurogram/shared/models/search_result.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/features/chat/domain/url_launcher_utils.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';

class SourcesSection extends StatefulWidget {
  final List<SearchResult> sources;
  final String messageContent;
  final bool isExpanded;
  final VoidCallback? onToggleExpansion;

  const SourcesSection({
    super.key,
    required this.sources,
    required this.messageContent,
    this.isExpanded = false,
    this.onToggleExpansion,
  });

  @override
  State<SourcesSection> createState() => _SourcesSectionState();
}

class _SourcesSectionState extends State<SourcesSection>
    with SingleTickerProviderStateMixin {
  late AnimationController _expansionController;
  late Animation<double> _expansionAnimation;

  @override
  void initState() {
    super.initState();

    _expansionController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _expansionAnimation = CurvedAnimation(
      parent: _expansionController,
      curve: Curves.easeInOut,
    );

    if (widget.isExpanded) {
      _expansionController.forward();
    }
  }

  @override
  void didUpdateWidget(SourcesSection oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isExpanded != oldWidget.isExpanded) {
      if (widget.isExpanded) {
        _expansionController.forward();
      } else {
        _expansionController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _expansionController.dispose();
    super.dispose();
  }

  void _toggleExpansion() {
    if (widget.onToggleExpansion != null) {
      widget.onToggleExpansion!();
    }
    HapticFeedback.lightImpact();
  }

  // Show all sources instead of only referenced
  List<SearchResult> get _referencedSources {
    return widget.sources;
  }

  @override
  Widget build(BuildContext context) {
    final referencedSources = _referencedSources;

    // Don't show if no referenced sources
    if (referencedSources.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
              onTap: _toggleExpansion,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: AppDimensions.paddingLg, vertical: AppDimensions.paddingMd),
                child: Row(
                  children: [
                    Icon(
                      Icons.link,
                      size: 16,
                      color: AppTheme.primaryColor.withValues(alpha: 0.7),
                    ),
                    const SizedBox(width: AppDimensions.spacingSm),
                    Expanded(
                      child: Text(
                        'Sources (${referencedSources.length})',
                        style: TextStyle(
                          fontSize: AppTheme.holyCowTextSize,
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    AnimatedRotation(
                      turns: widget.isExpanded ? 0.5 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        Icons.keyboard_arrow_down,
                        size: 18,
                        color: AppTheme.primaryColor.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Expandable content
          SizeTransition(
            sizeFactor: _expansionAnimation,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: [
                  const Divider(height: 1),
                  const SizedBox(height: AppDimensions.spacingMd),
                  ...referencedSources
                      .map((source) => _buildSourceCard(source)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSourceCard(SearchResult source) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppDimensions.paddingMd),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
          onTap: () => UrlLauncherUtils.launchURL(source.link, context),
          child: Container(
            padding: const EdgeInsets.all(AppDimensions.paddingMd),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Domain and external link icon
                Row(
                  children: [
                    // Favicon or default icon
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                      ),
                      child: source.favicon != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                              child: Image.network(
                                source.favicon!,
                                width: 16,
                                height: 16,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Icon(
                                    Icons.public,
                                    size: 10,
                                    color: AppTheme.primaryColor,
                                  );
                                },
                              ),
                            )
                          : Icon(
                              Icons.public,
                              size: 10,
                              color: AppTheme.primaryColor,
                            ),
                    ),
                    const SizedBox(width: AppDimensions.spacingSm),
                    Expanded(
                      child: Text(
                        source.displayLink,
                        style: TextStyle(
                          fontSize: AppTheme.holyCowTextSize,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(AppDimensions.paddingXs),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppDimensions.radiusSmMd),
                      ),
                      child: Icon(
                        Icons.open_in_new,
                        size: 10,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppDimensions.spacingSm),
                // Title
                Text(
                  source.title,
                  style: const TextStyle(
                    fontSize: AppTheme.holyCowTextSize,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111827),
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppDimensions.spacingSmMd),
                // Snippet
                Text(
                  source.snippet,
                  style: TextStyle(
                    fontSize: AppTheme.holyCowTextSize,
                    color: Colors.grey[700],
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                // Referenced indicator
                if (source.isReferenced) ...[
                  const SizedBox(height: AppDimensions.spacingSmMd),
                  Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        size: 12,
                        color: Colors.green[600],
                      ),
                      const SizedBox(width: AppDimensions.spacingXs),
                      Text(
                        'Referenced in response',
                        style: TextStyle(
                          fontSize: AppTheme.holyCowTextSize,
                          color: Colors.green[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
