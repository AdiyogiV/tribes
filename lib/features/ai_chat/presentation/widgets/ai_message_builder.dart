import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:aurogram/shared/presentation/widgets/media/common_widgets.dart';
import 'package:aurogram/features/ai_chat/domain/ai_chat_models.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/features/chat/domain/markdown_utils.dart';
import 'package:aurogram/features/chat/domain/url_launcher_utils.dart';
import 'package:aurogram/shared/models/search_result.dart';
import 'typing_indicator.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';
import 'package:aurogram/shared/presentation/widgets/feedback/snack_bar_service.dart';
import 'package:aurogram/features/ai_chat/domain/ai_chat_provider.dart';

/// Builder methods for AI assistant messages including sources dialog
class AiMessageBuilder {
  /// Build an AI assistant message bubble
  static Widget buildAiMessage(
    String content,
    bool hasSearchResults,
    AiChatProvider provider,
    AiMessage message,
    Map<String, bool> searchResultsExpansionState,
    Function(String, bool) onExpansionChanged,
    BuildContext context,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Show typing indicator when pending with no content
    if (content.isEmpty && !hasSearchResults && message.pending) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          TypingIndicatorBubble(isDark: isDark),
        ],
      );
    }

    // Don't show empty AI message box if not pending
    if (content.isEmpty && !hasSearchResults) {
      return const SizedBox.shrink();
    }

    final allSearchResults =
        message.searchResults ?? provider.currentSession.searchResults;

    final isStreaming = message.pending;
    final isGreeting = message.id.startsWith('greeting-');

    // Shared border radius for AI messages
    const borderRadius = BorderRadius.only(
      topLeft: Radius.circular(4),
      topRight: Radius.circular(16),
      bottomLeft: Radius.circular(16),
      bottomRight: Radius.circular(16),
    );

    // Wrap in Row to left-align and constrain width (like user messages)
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Flexible(
          child: AnimatedSize(
            // Shorter duration during streaming for smoother updates
            // Longer duration when complete for polished feel
            duration: isStreaming
                ? const Duration(milliseconds: 100)
                : const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            alignment: Alignment.topLeft,
            child: Container(
              key: Key('ai_message_${message.id}'),
              margin: const EdgeInsets.only(bottom: 16),
              child: Material(
                elevation: 0,
                color: Colors.transparent,
                borderRadius: borderRadius,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: borderRadius,
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.12)
                          : Colors.black.withValues(alpha: 0.06),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Content with smooth animation (greeting same style as normal messages)
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                            14, 12, 14, isGreeting ? 12 : 8),
                        child: MarkdownUtils.buildRichContent(content, context,
                            sources: allSearchResults,
                            textColor: AppTheme.primaryColor),
                      ),
                      // Footer with sources and copy - only show when not streaming and not greeting
                      if (!isGreeting && (!isStreaming || content.length > 50))
                        Padding(
                          padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                          child: Row(
                            children: [
                              if (allSearchResults.isNotEmpty)
                                _buildSourcesButton(allSearchResults, context),
                              const Spacer(),
                              _buildCopyButton(content, context),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  static Widget _buildSourcesButton(
      List<SearchResult> sources, BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
        onTap: () {
          HapticFeedback.lightImpact();
          _showSourcesDialog(sources, context);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.grey.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.link_rounded,
                size: 11,
                color: isDark ? Colors.white54 : Colors.grey[600],
              ),
              const SizedBox(width: AppDimensions.spacingXs),
              Text(
                '${sources.length}',
                style: TextStyle(
                  fontSize: AppTheme.holyCowTextSize,
                  color: isDark ? Colors.white54 : Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _buildCopyButton(String content, BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
        onTap: () {
          Clipboard.setData(ClipboardData(text: content));
          HapticFeedback.lightImpact();
          showCustomSnackBar(context, message: 'Copied', backgroundColor: isDark ? Colors.grey[800] : Colors.grey[700], duration: const Duration(milliseconds: 1200), behavior: SnackBarBehavior.floating);
        },
        child: Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.grey.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
          ),
          child: Icon(
            Icons.copy_rounded,
            size: 12,
            color: isDark ? Colors.white30 : Colors.grey[400],
          ),
        ),
      ),
    );
  }

  /// Show sources in a bottom sheet (cleaner than dialog)
  static void _showSourcesDialog(
      List<SearchResult> sources, BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Aggressively unfocus to prevent keyboard issues
    FocusManager.instance.primaryFocus?.unfocus();

    AppBottomSheet.show(
      context,
      maxHeightFraction: 0.6,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Text(
                  'Sources',
                  style: TextStyle(
                    fontSize: AppTheme.holyCowTextSize,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.grey[800],
                  ),
                ),
                const SizedBox(width: AppDimensions.spacingSmMd),
                Text(
                  '(${sources.length})',
                  style: TextStyle(
                    fontSize: AppTheme.holyCowTextSize,
                    color: isDark ? Colors.white38 : Colors.grey[500],
                  ),
                ),
                const Spacer(),
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

          // Sources list
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              itemCount: sources.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppDimensions.spacingSm),
              itemBuilder: (_, i) =>
                  _buildSourceCard(context, isDark, sources[i]),
            ),
          ),
        ],
      ),
    ).whenComplete(() {
      // Use FocusManager for more reliable unfocus after modal closes
      Future.delayed(const Duration(milliseconds: 50), () {
        FocusManager.instance.primaryFocus?.unfocus();
      });
    });
  }

  /// Clean source card design
  static Widget _buildSourceCard(
      BuildContext context, bool isDark, SearchResult source) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMdSm),
        onTap: () {
          UrlLauncherUtils.launchURL(source.link, context);
          Navigator.of(context).pop();
        },
        child: Container(
          padding: const EdgeInsets.all(AppDimensions.paddingMd),
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
              // Domain & link icon
              Row(
                children: [
                  // Favicon
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.grey.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: source.favicon != null && source.favicon!.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: Image.network(
                              source.favicon!,
                              width: 16,
                              height: 16,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Icon(
                                Icons.public_rounded,
                                size: 10,
                                color:
                                    isDark ? Colors.white38 : Colors.grey[500],
                              ),
                            ),
                          )
                        : Icon(
                            Icons.public_rounded,
                            size: 10,
                            color: isDark ? Colors.white38 : Colors.grey[500],
                          ),
                  ),
                  const SizedBox(width: AppDimensions.spacingSmMd),
                  Expanded(
                    child: Text(
                      source.displayLink,
                      style: TextStyle(
                        fontSize: AppTheme.holyCowTextSize,
                        color: isDark ? Colors.white38 : Colors.grey[500],
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(
                    Icons.arrow_outward_rounded,
                    size: 12,
                    color: isDark ? Colors.white24 : Colors.grey[400],
                  ),
                ],
              ),

              const SizedBox(height: AppDimensions.spacingSm),

              // Title
              Text(
                source.title,
                style: TextStyle(
                  fontSize: AppTheme.holyCowTextSize,
                  fontWeight: FontWeight.w500,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.85)
                      : Colors.grey[800],
                  height: 1.25,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: AppDimensions.spacingXs),

              // Snippet
              Text(
                source.snippet,
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

              // Referenced badge
              if (source.isReferenced) ...[
                const SizedBox(height: AppDimensions.spacingSmMd),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_rounded,
                      size: 10,
                      color: isDark ? Colors.white30 : Colors.grey[400],
                    ),
                    const SizedBox(width: 3),
                    Text(
                      'Cited',
                      style: TextStyle(
                        fontSize: AppTheme.holyCowTextSize,
                        color: isDark ? Colors.white30 : Colors.grey[400],
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
    );
  }
}
