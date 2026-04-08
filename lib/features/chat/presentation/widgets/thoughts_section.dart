import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:aurogram/models/thought_process.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';

class ThoughtsSection extends StatefulWidget {
  final ThoughtProcess? thoughtProcess;
  final bool isStreaming;
  final VoidCallback? onToggleExpansion;

  const ThoughtsSection({
    super.key,
    this.thoughtProcess,
    this.isStreaming = false,
    this.onToggleExpansion,
  });

  @override
  State<ThoughtsSection> createState() => _ThoughtsSectionState();
}

class _ThoughtsSectionState extends State<ThoughtsSection>
    with TickerProviderStateMixin {
  late AnimationController _expansionController;
  late AnimationController _pulseController;
  late Animation<double> _expansionAnimation;
  late Animation<double> _pulseAnimation;
  final Map<String, bool> _expandedResults =
      {}; // Track expansion state per result set

  @override
  void initState() {
    super.initState();

    _expansionController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _expansionAnimation = CurvedAnimation(
      parent: _expansionController,
      curve: Curves.easeInOut,
    );

    _pulseAnimation = Tween<double>(
      begin: 0.6,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    // Start expanded only if thoughtProcess is explicitly expanded by user
    if (widget.thoughtProcess?.isExpanded ?? false) {
      _expansionController.forward();
    }

    // Start pulse animation if streaming
    if (widget.isStreaming) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(ThoughtsSection oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Handle expansion state changes - only expand if user explicitly expanded
    final shouldExpand = widget.thoughtProcess?.isExpanded ?? false;

    if (shouldExpand && !_expansionController.isCompleted) {
      _expansionController.forward();
    } else if (!shouldExpand && _expansionController.isCompleted) {
      _expansionController.reverse();
    }

    // Handle pulse animation for streaming
    if (widget.isStreaming && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    } else if (!widget.isStreaming && _pulseController.isAnimating) {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  @override
  void dispose() {
    _expansionController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _toggleExpansion() {
    if (widget.onToggleExpansion != null) {
      widget.onToggleExpansion!();
    }
    HapticFeedback.lightImpact();
  }

  @override
  Widget build(BuildContext context) {
    final thoughtProcess = widget.thoughtProcess;

    // Show if streaming/thinking OR if thought process exists
    // CRITICAL: Always show when streaming, even if thoughtProcess is null
    // This ensures thoughts box appears immediately even before first step arrives
    // and prevents it from disappearing for new users
    if (thoughtProcess == null && !widget.isStreaming) {
      return const SizedBox.shrink();
    }

    // Show even if no steps yet, but we're streaming/thinking
    // Use filteredSteps to remove first and last unhelpful steps
    final steps = thoughtProcess?.filteredSteps ?? [];
    final isExpanded = thoughtProcess?.isExpanded ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: AppDimensions.paddingMd),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(
          color: widget.isStreaming
              ? AppTheme.primaryColor.withValues(alpha: 0.3)
              : Colors.grey.withValues(alpha: 0.2),
          width: 1,
        ),
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
                    // Thinking icon with pulse animation
                    AnimatedBuilder(
                      animation: widget.isStreaming
                          ? _pulseAnimation
                          : const AlwaysStoppedAnimation(1.0),
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _pulseAnimation.value,
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: widget.isStreaming
                                  ? AppTheme.primaryColor.withValues(alpha: 0.1)
                                  : Colors.grey.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(AppDimensions.radiusMdSm),
                            ),
                            child: Icon(
                              widget.isStreaming
                                  ? Icons.psychology
                                  : Icons.lightbulb_outline,
                              size: 12,
                              color: widget.isStreaming
                                  ? AppTheme.primaryColor
                                  : Colors.grey[600],
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: AppDimensions.spacingSm),
                    // Title
                    Expanded(
                      child: Text(
                        widget.isStreaming ? 'Thinking...' : 'Thoughts',
                        style: TextStyle(
                          fontSize: AppTheme.holyCowTextSize,
                          fontWeight: FontWeight.w600,
                          color: widget.isStreaming
                              ? AppTheme.primaryColor
                              : Colors.grey[700],
                        ),
                      ),
                    ),
                    // Expansion arrow
                    AnimatedRotation(
                      turns: isExpanded ? 0.5 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        Icons.keyboard_arrow_down,
                        size: 18,
                        color: Colors.grey[600],
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(height: 1),
                  const SizedBox(height: AppDimensions.spacingMd),
                  // Show steps if available
                  if (steps.isNotEmpty) ...[
                    ...steps.map((step) => _buildThoughtStep(step)),
                    if (widget.isStreaming) const SizedBox(height: AppDimensions.spacingSm),
                  ],
                  // Show placeholder if no steps and not streaming
                  if (steps.isEmpty && !widget.isStreaming) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: AppDimensions.paddingSm),
                      child: Text(
                        'No thinking steps recorded',
                        style: TextStyle(
                          fontSize: AppTheme.holyCowTextSize,
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThoughtStep(ThoughtStep step) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppDimensions.paddingMd),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Step icon
          Container(
            width: 24,
            height: 24,
            margin: const EdgeInsets.only(right: 12, top: 2),
            decoration: BoxDecoration(
              color: _getStepColor(step.type).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            ),
            child: Icon(
              _getStepIcon(step.type),
              size: 12,
              color: _getStepColor(step.type),
            ),
          ),
          // Step content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Step message with rich formatting
                Text(
                  step.message,
                  style: TextStyle(
                    fontSize: AppTheme.holyCowTextSize,
                    color: Colors.grey[800],
                    height: 1.3,
                  ),
                ),

                // Show metadata information if available
                if (step.metadata != null && step.metadata!.isNotEmpty) ...[
                  const SizedBox(height: AppDimensions.spacingXs),
                  _buildMetadataInfo(step),
                ],

                // Step query if available
                if (step.query != null && step.query!.isNotEmpty) ...[
                  const SizedBox(height: AppDimensions.spacingXs),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(AppDimensions.radiusSmMd),
                      border: Border.all(color: Colors.blue[200]!, width: 0.5),
                    ),
                    child: Text(
                      '"${step.query}"',
                      style: TextStyle(
                        fontSize: AppTheme.holyCowTextSize,
                        color: Colors.blue[700],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],

                // Results with collapsible display if available
                if (step.results != null && step.results!.isNotEmpty) ...[
                  const SizedBox(height: AppDimensions.spacingSm),
                  _buildCollapsibleResults(step.results!),
                ],

                // Removed timestamp for cleaner display
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getStepColor(String type) {
    switch (type) {
      case 'search':
        return Colors.blue;
      case 'reasoning':
        return Colors.purple;
      case 'decision':
        return Colors.orange;
      case 'analysis':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  IconData _getStepIcon(String type) {
    switch (type) {
      case 'search':
        return Icons.search;
      case 'reasoning':
        return Icons.psychology;
      case 'decision':
        return Icons.account_tree;
      case 'analysis':
        return Icons.analytics;
      default:
        return Icons.circle;
    }
  }

  // Timestamp function removed for cleaner professional display

  Widget _buildMetadataInfo(ThoughtStep step) {
    if (step.metadata == null || step.metadata!.isEmpty) {
      return const SizedBox.shrink();
    }

    final metadata = step.metadata!;
    final List<Widget> metadataWidgets = [];

    // Show merged step information (our enhancement)
    if (metadata['merged_count'] != null) {
      final mergedCount = metadata['merged_count'] as int;
      metadataWidgets.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.indigo[50],
            borderRadius: BorderRadius.circular(AppDimensions.radiusXs),
            border: Border.all(color: Colors.indigo[300]!, width: 0.5),
          ),
          child: Text(
            'Combined $mergedCount steps',
            style: TextStyle(
              fontSize: AppTheme.holyCowTextSize,
              color: Colors.indigo[700],
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    // Show total sources information (our enhancement)
    if (metadata['total_sources'] != null) {
      final totalSources = metadata['total_sources'] as int;
      metadataWidgets.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.green[50],
            borderRadius: BorderRadius.circular(AppDimensions.radiusXs),
            border: Border.all(color: Colors.green[300]!, width: 0.5),
          ),
          child: Text(
            '$totalSources sources',
            style: TextStyle(
              fontSize: AppTheme.holyCowTextSize,
              color: Colors.green[700],
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    // Show round information if available (but less prominent since we're deemphasizing technical details)
    if (metadata['round'] != null && metadata['merged_count'] == null) {
      final round = metadata['round'] as int;
      final searchIndex = metadata['searchIndex'] as int?;

      metadataWidgets.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.purple[50],
            borderRadius: BorderRadius.circular(AppDimensions.radiusXs),
            border: Border.all(color: Colors.purple[300]!, width: 0.5),
          ),
          child: Text(
            searchIndex != null ? 'Round $round' : 'Round $round',
            style: TextStyle(
              fontSize: AppTheme.holyCowTextSize,
              color: Colors.purple[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );
    }

    // Show confidence level if available
    if (metadata['confidence'] != null) {
      final confidence = metadata['confidence'] as double;
      metadataWidgets.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: _getConfidenceColor(confidence).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppDimensions.radiusXs),
            border:
                Border.all(color: _getConfidenceColor(confidence), width: 0.5),
          ),
          child: Text(
            '${(confidence * 100).round()}% confident',
            style: TextStyle(
              fontSize: AppTheme.holyCowTextSize,
              color: _getConfidenceColor(confidence),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );
    }

    // Show results count if available
    if (metadata['results_count'] != null) {
      metadataWidgets.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.green[50],
            borderRadius: BorderRadius.circular(AppDimensions.radiusXs),
            border: Border.all(color: Colors.green[300]!, width: 0.5),
          ),
          child: Text(
            '${metadata['results_count']} search results',
            style: TextStyle(
              fontSize: AppTheme.holyCowTextSize,
              color: Colors.green[700],
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );
    }

    if (metadataWidgets.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: metadataWidgets,
    );
  }

  Color _getConfidenceColor(double confidence) {
    if (confidence >= 0.8) return Colors.green[600]!;
    if (confidence >= 0.6) return Colors.orange[600]!;
    return Colors.red[600]!;
  }

  Widget _buildCollapsibleResults(List<SearchResult> results) {
    return StatefulBuilder(
      builder: (context, setLocalState) {
        // Use a unique key for this specific results list to maintain state
        final resultsKey = 'results_${results.hashCode}';
        bool isExpanded = _expandedResults[resultsKey] ?? false;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Results header with expand/collapse button
            GestureDetector(
              onTap: () {
                setLocalState(() {
                  isExpanded = !isExpanded;
                  _expandedResults[resultsKey] = isExpanded;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(AppDimensions.radiusSmMd),
                  border: Border.all(color: Colors.blue[200]!, width: 0.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isExpanded ? Icons.expand_less : Icons.expand_more,
                      size: 14,
                      color: Colors.blue[600],
                    ),
                    const SizedBox(width: AppDimensions.spacingXs),
                    Text(
                      'View ${results.length} search results',
                      style: TextStyle(
                        fontSize: AppTheme.holyCowTextSize,
                        color: Colors.blue[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Collapsible results
            if (isExpanded) ...[
              const SizedBox(height: AppDimensions.spacingSmMd),
              Container(
                padding: const EdgeInsets.all(AppDimensions.paddingSm),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                  border: Border.all(color: Colors.grey[200]!, width: 0.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: results
                      .map((result) => _buildResultItem(result))
                      .toList(),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildResultItem(SearchResult result) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppDimensions.paddingSm),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusSmMd),
        border: Border.all(color: Colors.grey[300]!, width: 0.8),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Text(
            result.title,
            style: TextStyle(
              fontSize: AppTheme.holyCowTextSize,
              fontWeight: FontWeight.w600,
              color: Colors.blue[700],
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppDimensions.spacingXs),
          // Snippet
          Text(
            result.snippet,
            style: TextStyle(
              fontSize: AppTheme.holyCowTextSize,
              color: Colors.grey[700],
              height: 1.3,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppDimensions.spacingSmMd),
          // FULL LINK - This was missing!
          Row(
            children: [
              Icon(
                Icons.link,
                size: 12,
                color: Colors.green[600],
              ),
              const SizedBox(width: AppDimensions.spacingXs),
              Expanded(
                child: Text(
                  result.link,
                  style: TextStyle(
                    fontSize: AppTheme.holyCowTextSize,
                    color: Colors.green[600],
                    fontWeight: FontWeight.w500,
                    decoration: TextDecoration.underline,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacingXxs),
          // Domain
          Text(
            'Source: ${result.displayLink}',
            style: TextStyle(
              fontSize: AppTheme.holyCowTextSize,
              color: Colors.grey[500],
              fontStyle: FontStyle.italic,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
