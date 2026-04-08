import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:aurogram/shared/presentation/widgets/media/common_widgets.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/shared/models/thought_process.dart';
import 'package:aurogram/features/chat/domain/url_launcher_utils.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';

/// Minimal thoughts indicator widget - shows AI processing steps
/// SIMPLIFIED: No complex queue/cache system - just renders what it's given
class ThoughtsOnlyWidget extends StatefulWidget {
  final String userMessageId;
  final ThoughtProcess? thoughtProcess;
  final bool isStreaming;
  final bool isExpanded;
  final VoidCallback onToggleExpansion;

  const ThoughtsOnlyWidget({
    super.key,
    required this.userMessageId,
    required this.thoughtProcess,
    required this.isStreaming,
    required this.isExpanded,
    required this.onToggleExpansion,
  });

  @override
  State<ThoughtsOnlyWidget> createState() => _ThoughtsOnlyWidgetState();
}

class _ThoughtsOnlyWidgetState extends State<ThoughtsOnlyWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    if (widget.isStreaming) _pulseController.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(ThoughtsOnlyWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Handle pulse animation based on streaming state
    if (widget.isStreaming && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    } else if (!widget.isStreaming && _pulseController.isAnimating) {
      _pulseController.stop();
      _pulseController.value = 1.0;
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  // Theme-aligned colors
  Color _getStepColor(String type, bool isDark) {
    switch (type) {
      case 'thinking':
        return AppTheme.honeyAmber; // Warm amber for thinking
      case 'decision':
        return AppTheme.sunGold; // Golden for decisions
      case 'search':
      case 'search_results':
        return Colors.purple; // Purple for search
      case 'analysis':
        return AppTheme.forestGreen; // Forest green for analysis
      case 'writing':
      case 'synthesis':
        return Colors.blue; // Blue for writing
      case 'completion':
        return AppTheme.grassGreen; // Grass green for done
      default:
        return isDark ? AppTheme.primaryLightColor : AppTheme.primaryDarkColor;
    }
  }

  String _getStepLabel(String type) {
    switch (type) {
      case 'thinking':
        return 'Thinking';
      case 'decision':
        return 'Planning';
      case 'search':
      case 'search_results':
        return 'Searching';
      case 'analysis':
        return 'Analysing';
      case 'writing':
      case 'synthesis':
        return 'Writing';
      case 'completion':
        return 'Done';
      default:
        return 'Processing';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Simple: use steps from thoughtProcess directly
    final steps = widget.thoughtProcess?.filteredSteps ?? [];

    // If no steps and not streaming, don't show
    if (steps.isEmpty && !widget.isStreaming) {
      return const SizedBox.shrink();
    }

    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topLeft,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        child: Container(
          margin: const EdgeInsets.only(top: 6, bottom: 8),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white,
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.grey.withValues(alpha: 0.12),
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.3)
                    : Colors.black.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context, isDark, steps),
              if (widget.isExpanded && steps.isNotEmpty)
                _buildExpandedContent(context, isDark, steps),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(
      BuildContext context, bool isDark, List<ThoughtStep> steps) {
    final latestStep = steps.isNotEmpty ? steps.last : null;
    final latestStepType = latestStep?.type ?? 'processing';
    final stepColor = _getStepColor(latestStepType, isDark);

    final isComplete = latestStepType == 'completion' ||
        (widget.thoughtProcess?.isComplete ?? false) ||
        !widget.isStreaming;

    final stepCount = steps.where((s) => s.type != 'completion').length;
    final isDecisionStep = latestStepType == 'decision' && widget.isStreaming;

    // Get detail text
    String? detailText;
    if (!isComplete && latestStep != null) {
      if (latestStep.query != null && latestStep.query!.isNotEmpty) {
        detailText = latestStep.query;
      } else if (latestStep.message.isNotEmpty) {
        detailText = latestStep.message;
      }
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        onTap: () {
          HapticFeedback.lightImpact();
          widget.onToggleExpansion();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            crossAxisAlignment: isComplete
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.start,
            children: [
              // Status indicator - fixed width for alignment
              SizedBox(
                width: 16,
                height: 16,
                child: Center(
                  child: widget.isStreaming && !isComplete
                      ? AnimatedBuilder(
                          animation: _pulseController,
                          builder: (context, _) => Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: stepColor.withValues(
                                  alpha: 0.5 + (_pulseController.value * 0.5)),
                              shape: BoxShape.circle,
                            ),
                          ),
                        )
                      : Icon(
                          Icons.check_rounded,
                          size: 14,
                          color: isDark ? Colors.white30 : Colors.grey[400],
                        ),
                ),
              ),

              const SizedBox(width: AppDimensions.spacingMdSm),

              // Content - no animation, just update in place
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: isComplete
                      ? [
                          Text(
                            stepCount > 0 ? '$stepCount steps' : 'Done',
                            style: TextStyle(
                              fontSize: AppTheme.holyCowTextSize,
                              color: isDark ? Colors.white38 : Colors.grey[500],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ]
                      : [
                          Text(
                            _getStepLabel(latestStepType),
                            style: TextStyle(
                              fontSize: AppTheme.holyCowTextSize,
                              fontWeight: FontWeight.w600,
                              color: stepColor,
                              letterSpacing: 0.1,
                            ),
                          ),
                          if (detailText != null && detailText.isNotEmpty) ...[
                            const SizedBox(height: AppDimensions.spacingXxxs),
                            Text(
                              detailText,
                              style: TextStyle(
                                fontSize: AppTheme.holyCowTextSize,
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.45)
                                    : Colors.grey[600],
                                height: 1.4,
                                fontStyle: latestStepType == 'search'
                                    ? FontStyle.italic
                                    : FontStyle.normal,
                              ),
                              maxLines: isDecisionStep ? 4 : 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                ),
              ),

              const SizedBox(width: AppDimensions.spacingSm),

              // Expand chevron - vertically centered
              AnimatedRotation(
                turns: widget.isExpanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 18,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.25)
                      : Colors.grey[400],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpandedContent(
      BuildContext context, bool isDark, List<ThoughtStep> steps) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(
            height: 1,
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.grey.withValues(alpha: 0.12),
          ),
          const SizedBox(height: AppDimensions.spacingMdSm),
          ...steps.map((step) => _buildStepItem(context, isDark, step)),
        ],
      ),
    );
  }

  Widget _buildStepItem(BuildContext context, bool isDark, ThoughtStep step) {
    final stepColor = _getStepColor(step.type, isDark);
    final hasResults = step.results != null && step.results!.isNotEmpty;
    final isSearchStep = step.type == 'search' || step.type == 'search_results';

    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.paddingSm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Step label
          SizedBox(
            width: 64,
            child: Text(
              _getStepLabel(step.type).toUpperCase(),
              style: TextStyle(
                fontSize: AppTheme.holyCowTextSize,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
                color: stepColor,
              ),
            ),
          ),

          const SizedBox(width: AppDimensions.spacingXxs),

          // Step content
          Expanded(
            child: isSearchStep && step.query != null && step.query!.isNotEmpty
                ? GestureDetector(
                    onTap: hasResults
                        ? () => _showSearchResultsPopup(
                            context, isDark, step.query!, step.results!)
                        : null,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            step.query!,
                            style: TextStyle(
                              fontSize: AppTheme.holyCowTextSize,
                              color: hasResults
                                  ? (isDark
                                      ? Colors.blue[300]
                                      : Colors.blue[600])
                                  : (isDark
                                      ? Colors.white54
                                      : Colors.grey[600]),
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                        if (hasResults)
                          Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Icon(
                              Icons.chevron_right_rounded,
                              size: 16,
                              color:
                                  isDark ? Colors.blue[300] : Colors.blue[600],
                            ),
                          ),
                      ],
                    ),
                  )
                : Text(
                    step.message,
                    style: TextStyle(
                      fontSize: AppTheme.holyCowTextSize,
                      color: isDark ? Colors.white54 : Colors.grey[600],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  /// Show search results in a popup dialog instead of inline expansion
  void _showSearchResultsPopup(
    BuildContext context,
    bool isDark,
    String query,
    List<SearchResult> results,
  ) {
    // Aggressively unfocus to prevent keyboard issues
    FocusManager.instance.primaryFocus?.unfocus();
    HapticFeedback.lightImpact();

    AppBottomSheet.show(
      context,
      maxHeightFraction: 0.55,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '"$query"',
                    style: TextStyle(
                      fontSize: AppTheme.holyCowTextSize,
                      fontStyle: FontStyle.italic,
                      color: isDark ? Colors.white60 : Colors.grey[700],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppDimensions.spacingSm),
                Text(
                  '${results.length}',
                  style: TextStyle(
                    fontSize: AppTheme.holyCowTextSize,
                    color: isDark ? Colors.white30 : Colors.grey[400],
                  ),
                ),
                const SizedBox(width: AppDimensions.spacingMdSm),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Icon(
                    Icons.close_rounded,
                    size: 20,
                    color: isDark ? Colors.white38 : Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),

          Divider(
              height: 1,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.grey[200]),

          // Results list
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              itemCount: results.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppDimensions.spacingSm),
              itemBuilder: (_, i) =>
                  _buildSearchResultCard(context, isDark, results[i]),
            ),
          ),
        ],
      ),
    ).whenComplete(() {
      // Use FocusManager for more reliable unfocus after modal closes
      // Add slight delay to ensure modal is fully dismissed before unfocusing
      Future.delayed(const Duration(milliseconds: 50), () {
        FocusManager.instance.primaryFocus?.unfocus();
      });
    });
  }

  Widget _buildSearchResultCard(
      BuildContext context, bool isDark, SearchResult result) {
    return GestureDetector(
      onTap: () {
        if (result.link.isNotEmpty) {
          UrlLauncherUtils.launchURL(result.link, context);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color:
              isDark ? Colors.white.withValues(alpha: 0.03) : Colors.grey[50],
          borderRadius: BorderRadius.circular(AppDimensions.radiusMdSm),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.grey.withValues(alpha: 0.1),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Domain first
            if (result.link.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  _extractDomain(result.link),
                  style: TextStyle(
                    fontSize: AppTheme.holyCowTextSize,
                    color: isDark ? Colors.white30 : Colors.grey[400],
                  ),
                ),
              ),
            // Title
            Row(
              children: [
                Expanded(
                  child: Text(
                    result.title,
                    style: TextStyle(
                      fontSize: AppTheme.holyCowTextSize,
                      fontWeight: FontWeight.w500,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.8)
                          : Colors.grey[800],
                      height: 1.25,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (result.link.isNotEmpty)
                  Icon(
                    Icons.arrow_outward_rounded,
                    size: 12,
                    color: isDark ? Colors.white24 : Colors.grey[400],
                  ),
              ],
            ),
            const SizedBox(height: AppDimensions.spacingXs),
            // Snippet
            Text(
              result.snippet,
              style: TextStyle(
                fontSize: AppTheme.holyCowTextSize,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.45)
                    : Colors.grey[600],
                height: 1.35,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  String _extractDomain(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.host.replaceFirst('www.', '');
    } catch (_) {
      return url;
    }
  }
}
