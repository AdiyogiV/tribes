import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:aurogram/providers/ai_chat_provider.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:aurogram/utils/chat/markdown_utils.dart';
import 'package:aurogram/models/thought_process.dart';
import 'package:aurogram/widgets/chat/voice_message_widget.dart';
import 'package:aurogram/utils/chat/url_launcher_utils.dart';

// NOTE: Removed complex _ThoughtsCache - was causing sync issues
// Thoughts now flow from single source: provider.currentThoughtProcess OR message.thoughtProcess

class ChatMessageWidgets {
  /// Build thoughts box below user message
  ///
  /// SINGLE SOURCE OF TRUTH: Thoughts always come from message.thoughtProcess
  /// No session-level thought process, no caching - just the message.
  static Widget buildThoughtsBoxBelowUserMessage(
    AiChatProvider provider,
    BuildContext context, {
    required String userMessageId,
    Map<String, bool>? thoughtExpansionState,
    Function(String, bool)? onThoughtExpansionChanged,
  }) {
    final userMessageIndex =
        provider.messages.indexWhere((m) => m.id == userMessageId);

    if (userMessageIndex == -1) {
      return const SizedBox.shrink();
    }

    // Find the associated assistant message (next message after user)
    AiMessage? assistantMessage;
    for (int i = userMessageIndex + 1; i < provider.messages.length; i++) {
      final msg = provider.messages[i];
      if (msg.role == 'user') break;
      if (msg.role == 'assistant') {
        assistantMessage = msg;
        break;
      }
    }

    // No assistant message = no thoughts to show
    if (assistantMessage == null) {
      return const SizedBox.shrink();
    }

    // SINGLE SOURCE: thoughts always from message.thoughtProcess
    final thoughtProcess = assistantMessage.thoughtProcess;
    final hasThoughts =
        thoughtProcess != null && thoughtProcess.steps.isNotEmpty;

    // ONLY show thoughts box when we actually have thoughts
    // Don't show empty box just because streaming is happening
    if (!hasThoughts) {
      return const SizedBox.shrink();
    }

    final thoughtsKey = 'thoughts_$userMessageId';
    final isExpanded = thoughtExpansionState?[thoughtsKey] ?? false;
    final isStreaming = assistantMessage.pending;

    return _ThoughtsOnlyWidget(
      key: ValueKey(thoughtsKey),
      userMessageId: userMessageId,
      thoughtProcess: thoughtProcess,
      isStreaming: isStreaming,
      isExpanded: isExpanded,
      onToggleExpansion: () {
        onThoughtExpansionChanged?.call(thoughtsKey, !isExpanded);
      },
    );
  }

  static Widget buildMessage(
    AiMessage message,
    AiChatProvider provider,
    Map<String, bool> searchResultsExpansionState,
    Function(String, bool) onExpansionChanged,
    BuildContext context, {
    Map<String, bool>? thoughtExpansionState,
    Function(String, bool)? onThoughtExpansionChanged,
  }) {
    final isUser = message.role == 'user';
    final content = message.content;
    final isLastMessage =
        provider.messages.isNotEmpty && provider.messages.last == message;

    final hasSearchResults = !isUser &&
        ((message.searchResults != null && message.searchResults!.isNotEmpty) ||
            (isLastMessage &&
                provider.currentSession.searchResults.isNotEmpty &&
                !provider.isStreaming));

    if (isUser) {
      return _buildUserMessage(message, context);
    } else {
      return _buildAiMessage(
        content,
        hasSearchResults,
        provider,
        message,
        searchResultsExpansionState,
        onExpansionChanged,
        context,
      );
    }
  }

  static Color _sentBubbleColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF3A3A3C)
          : AppTheme.primaryColor;

  static Widget _buildUserMessage(AiMessage message, BuildContext context) {
    final sentColor = _sentBubbleColor(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(flex: 1),
          Flexible(
            flex: 5,
            child: message.isVoiceMessage &&
                    message.audioUrl != null &&
                    message.audioUrl!.isNotEmpty &&
                    message.audioUrl != 'local' // Has actual URL for playback
                ? VoiceMessageWidget(
                    transcript: message.content,
                    audioUrl: message.audioUrl!,
                    durationInSeconds: message.audioDuration ?? 0,
                    isUserMessage: true,
                  )
                : message.isVoiceMessage && message.audioUrl == 'local'
                    // Local-only voice message (logged out user) - no upload, no loading
                    ? _buildLocalOnlyVoiceMessage(message, context)
                    : message.isVoiceMessage &&
                            (message.audioUrl == null ||
                                message.audioUrl!.isEmpty)
                        // Still uploading - show loading indicator
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: sentColor,
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(16),
                                topRight: Radius.circular(16),
                                bottomLeft: Radius.circular(16),
                                bottomRight: Radius.circular(4),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Small loading indicator while uploading
                                SizedBox(
                                  width: 32,
                                  height: 32,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color:
                                          Colors.white.withValues(alpha: 0.2),
                                    ),
                                    padding: const EdgeInsets.all(8),
                                    child: const CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                // Duration info
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Simple progress placeholder
                                    Container(
                                      width: 80,
                                      height: 3,
                                      decoration: BoxDecoration(
                                        color:
                                            Colors.white.withValues(alpha: 0.3),
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      message.audioDuration != null
                                          ? '${(message.audioDuration! ~/ 60).toString().padLeft(1, '0')}:${(message.audioDuration! % 60).toString().padLeft(2, '0')}'
                                          : '0:00',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color:
                                            Colors.white.withValues(alpha: 0.7),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          )
                        : Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: sentColor,
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(16),
                                topRight: Radius.circular(16),
                                bottomLeft: Radius.circular(16),
                                bottomRight: Radius.circular(4),
                              ),
                            ),
                            child: Text(
                              message.content,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.white,
                                height: 1.45,
                              ),
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  /// Build local-only voice message bubble (for logged out users)
  /// Shows mic icon instead of loading spinner since upload was skipped
  static Widget _buildLocalOnlyVoiceMessage(
      AiMessage message, BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _sentBubbleColor(context),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Mic icon (not loading) - indicates voice sent successfully
          SizedBox(
            width: 32,
            height: 32,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.2),
              ),
              padding: const EdgeInsets.all(8),
              child: const Icon(
                Icons.mic,
                size: 16,
                color: Colors.white70,
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Duration info
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Static progress bar
              Container(
                width: 80,
                height: 3,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                message.audioDuration != null
                    ? '${(message.audioDuration! ~/ 60).toString().padLeft(1, '0')}:${(message.audioDuration! % 60).toString().padLeft(2, '0')}'
                    : '0:00',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Widget _buildAiMessage(
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
          _TypingIndicatorBubble(isDark: isDark),
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
        borderRadius: BorderRadius.circular(8),
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
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.link_rounded,
                size: 11,
                color: isDark ? Colors.white54 : Colors.grey[600],
              ),
              const SizedBox(width: 4),
              Text(
                '${sources.length}',
                style: TextStyle(
                  fontSize: 10,
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
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          Clipboard.setData(ClipboardData(text: content));
          HapticFeedback.lightImpact();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Copied', style: TextStyle(fontSize: 13)),
              duration: const Duration(milliseconds: 1200),
              behavior: SnackBarBehavior.floating,
              backgroundColor: isDark ? Colors.grey[800] : Colors.grey[700],
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.grey.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(8),
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

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 10),
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.2)
                    : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Row(
                children: [
                  Text(
                    'Sources',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.grey[800],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '(${sources.length})',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white38 : Colors.grey[500],
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.of(ctx).pop(),
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
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) =>
                    _buildSourceCard(ctx, isDark, sources[i]),
              ),
            ),
          ],
        ),
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
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          UrlLauncherUtils.launchURL(source.link, context);
          Navigator.of(context).pop();
        },
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color:
                isDark ? Colors.white.withValues(alpha: 0.03) : Colors.grey[50],
            borderRadius: BorderRadius.circular(10),
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
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      source.displayLink,
                      style: TextStyle(
                        fontSize: 10,
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

              const SizedBox(height: 8),

              // Title
              Text(
                source.title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.85)
                      : Colors.grey[800],
                  height: 1.25,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 4),

              // Snippet
              Text(
                source.snippet,
                style: TextStyle(
                  fontSize: 11,
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
                const SizedBox(height: 6),
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
                        fontSize: 9,
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

/// Minimal thoughts indicator widget - shows AI processing steps
/// SIMPLIFIED: No complex queue/cache system - just renders what it's given
class _ThoughtsOnlyWidget extends StatefulWidget {
  final String userMessageId;
  final ThoughtProcess? thoughtProcess;
  final bool isStreaming;
  final bool isExpanded;
  final VoidCallback onToggleExpansion;

  const _ThoughtsOnlyWidget({
    super.key,
    required this.userMessageId,
    required this.thoughtProcess,
    required this.isStreaming,
    required this.isExpanded,
    required this.onToggleExpansion,
  });

  @override
  State<_ThoughtsOnlyWidget> createState() => _ThoughtsOnlyWidgetState();
}

class _ThoughtsOnlyWidgetState extends State<_ThoughtsOnlyWidget>
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
  void didUpdateWidget(_ThoughtsOnlyWidget oldWidget) {
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
        borderRadius: BorderRadius.circular(12),
        child: Container(
          margin: const EdgeInsets.only(top: 6, bottom: 8),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white,
            borderRadius: BorderRadius.circular(12),
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
        borderRadius: BorderRadius.circular(12),
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

              const SizedBox(width: 10),

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
                              fontSize: 12,
                              color: isDark ? Colors.white38 : Colors.grey[500],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ]
                      : [
                          Text(
                            _getStepLabel(latestStepType),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: stepColor,
                              letterSpacing: 0.1,
                            ),
                          ),
                          if (detailText != null && detailText.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              detailText,
                              style: TextStyle(
                                fontSize: 11,
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

              const SizedBox(width: 8),

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
          const SizedBox(height: 10),
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
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Step label
          SizedBox(
            width: 64,
            child: Text(
              _getStepLabel(step.type).toUpperCase(),
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
                color: stepColor,
              ),
            ),
          ),

          const SizedBox(width: 2),

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
                              fontSize: 11,
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
                      fontSize: 11,
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

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: true,
      builder: (ctx) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.55,
        ),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 10),
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.2)
                    : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '"$query"',
                      style: TextStyle(
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                        color: isDark ? Colors.white60 : Colors.grey[700],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${results.length}',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white30 : Colors.grey[400],
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () => Navigator.of(ctx).pop(),
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
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) =>
                    _buildSearchResultCard(ctx, isDark, results[i]),
              ),
            ),
          ],
        ),
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
          borderRadius: BorderRadius.circular(10),
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
                    fontSize: 10,
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
                      fontSize: 12,
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
            const SizedBox(height: 4),
            // Snippet
            Text(
              result.snippet,
              style: TextStyle(
                fontSize: 11,
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

/// Typing indicator bubble shown while AI is processing before text streams
class _TypingIndicatorBubble extends StatelessWidget {
  final bool isDark;

  const _TypingIndicatorBubble({required this.isDark});

  @override
  Widget build(BuildContext context) {
    const borderRadius = BorderRadius.only(
      topLeft: Radius.circular(4),
      topRight: Radius.circular(16),
      bottomLeft: Radius.circular(16),
      bottomRight: Radius.circular(16),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Material(
            elevation: 2,
            shadowColor: Colors.black.withValues(alpha: 0.15),
            borderRadius: borderRadius,
            color: isDark
                ? AppTheme.cardDarkColor.withValues(alpha: 0.85)
                : Colors.white,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                borderRadius: borderRadius,
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.grey.withValues(alpha: 0.1),
                ),
              ),
              child: _BouncingDots(isDark: isDark),
            ),
          ),
        ],
      ),
    );
  }
}

/// Animated bouncing dots for typing indicator
class _BouncingDots extends StatefulWidget {
  final bool isDark;

  const _BouncingDots({required this.isDark});

  @override
  State<_BouncingDots> createState() => _BouncingDotsState();
}

class _BouncingDotsState extends State<_BouncingDots>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      3,
      (i) => AnimationController(
        duration: const Duration(milliseconds: 400),
        vsync: this,
      ),
    );

    _animations = _controllers.map((controller) {
      return Tween<double>(begin: 0, end: -6).animate(
        CurvedAnimation(parent: controller, curve: Curves.easeInOut),
      );
    }).toList();

    // Stagger the animations
    for (int i = 0; i < _controllers.length; i++) {
      Future.delayed(Duration(milliseconds: i * 150), () {
        if (mounted) {
          _controllers[i].repeat(reverse: true);
        }
      });
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dotColor =
        widget.isDark ? Colors.white.withValues(alpha: 0.5) : Colors.grey[400]!;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return AnimatedBuilder(
          animation: _animations[i],
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, _animations[i].value),
              child: Container(
                margin: EdgeInsets.only(right: i < 2 ? 4 : 0),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                ),
              ),
            );
          },
        );
      }),
    );
  }
}
