import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:aurogram/models/daily_insight.dart';
import 'package:aurogram/models/astrology_profile.dart';
import 'package:aurogram/services/astrology_service.dart';
import 'package:aurogram/services/notification_service.dart';
import 'package:aurogram/services/share_service.dart';
import 'package:aurogram/widgets/astrology/insight_cards/insight_card.dart';
import 'package:aurogram/pages/astrology/saved_insights_page.dart';
import 'package:aurogram/widgets/astrology/astro_chat_input.dart';
import 'package:aurogram/widgets/ui/skeleton_widgets.dart';
import 'package:aurogram/pages/astrology/astro_chat_page.dart';
import 'package:aurogram/pages/helpers/flash.dart';
import 'package:aurogram/utils/logging/app_logger.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:aurogram/utils/astrology/astrology_context_builder.dart';
import 'package:aurogram/widgets/astrology/timeline/muhurat_timeline_widget.dart';

class DailyInsightPage extends StatefulWidget {
  final String uid;

  /// Optional: specific date to show (for history view). If null, shows today.
  final String? insightDate;

  /// Optional: card index to highlight (for notification deep linking)
  final int? highlightCardIndex;

  const DailyInsightPage({
    super.key,
    required this.uid,
    this.insightDate,
    this.highlightCardIndex,
  });

  @override
  State<DailyInsightPage> createState() => _DailyInsightPageState();
}

class _DailyInsightPageState extends State<DailyInsightPage> {
  final _astrologyService = AstrologyService();
  bool _isGeneratingInsight = false;

  // AI Chat input controllers
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  // For scroll-to-card functionality
  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _cardKeys = {};

  // Cache profile and insight for context building
  AstrologyProfile? _lastProfile;
  DailyInsight? _lastInsight;

  // Track if notification prompt was shown
  bool _notificationPromptShown = false;

  @override
  void initState() {
    super.initState();

    // If we have a highlight card index, scroll to it after build
    if (widget.highlightCardIndex != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToCard(widget.highlightCardIndex!);
      });
    }

    // Check notification permissions after a delay (fallback for users who skipped onboarding prompt)
    _checkNotificationPermissions();

    // Aura: award daily insight view (+1 once per day) via backend (fire-and-forget)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FirebaseFunctions.instanceFor(region: 'asia-southeast2')
          .httpsCallable('awardDailyInsightView')
          .call()
          .then((_) {}, onError: (_, __) {});
    });
  }

  /// Check and offer notification permissions with subtle non-intrusive prompt
  /// This is a fallback for users who didn't go through onboarding flow
  Future<void> _checkNotificationPermissions() async {
    // Wait for user to view insights before prompting
    await Future.delayed(const Duration(seconds: 5));

    if (!mounted || _notificationPromptShown) return;

    final notificationService = NotificationService();

    // Skip if already asked or already have permission
    if (notificationService.permissionsRequested) return;
    final hasPermission = await notificationService.hasPermission();
    if (hasPermission) return;

    _notificationPromptShown = true;

    if (!mounted) return;

    // Show subtle snackbar prompt instead of full modal
    final shouldEnable = await ScaffoldMessenger.of(context)
        .showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.wb_sunny_rounded,
                    color: Colors.amber.shade200, size: 20),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Get daily cosmic updates?',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            action: SnackBarAction(
              label: 'Enable',
              textColor: Colors.amber.shade200,
              onPressed: () async {
                HapticFeedback.lightImpact();
                await notificationService.requestPermissions();
              },
            ),
            duration: const Duration(seconds: 6),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        )
        .closed;

    // Track dismissal
    AppLogger.d('Notification prompt dismissed: $shouldEnable',
        category: LogCategory.messaging);
  }

  @override
  void dispose() {
    _messageController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToCard(int index) {
    // Small delay to ensure cards are built
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_cardKeys.containsKey(index) && mounted) {
        final key = _cardKeys[index];
        if (key?.currentContext != null) {
          Scrollable.ensureVisible(
            key!.currentContext!,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
            alignment: 0.3,
          );
        }
      }
    });
  }

  /// Send message with astrology context and push to astro chat page
  void _sendMessageWithAstroContext() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    try {
      // Use shared context builder (includes daily insight)
      final astroContext = AstrologyContextBuilder.buildContext(
        profile: _lastProfile,
        insight: _lastInsight,
      );

      // Clear input immediately for better UX
      _messageController.clear();
      _focusNode.unfocus();

      HapticFeedback.lightImpact();

      // Push astro chat page on top of current page
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => AstroChatPage(
            astrologyContext: astroContext,
            initialMessage: text,
          ),
        ),
      );
    } catch (e) {
      AppLogger.e('Error opening astro chat', error: e);
    }
  }

  Future<void> _generateDailyInsight({bool forceRegenerate = false}) async {
    if (_isGeneratingInsight) return;
    setState(() => _isGeneratingInsight = true);

    try {
      final result = await _astrologyService.generateDailyInsight(
        forceRegenerate: forceRegenerate,
      );
      if (!mounted) return;

      if (result != null && result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Wisdom received'),
            backgroundColor: Colors.green.shade600,
          ),
        );
      } else {
        throw Exception(result?['error'] ?? 'Unknown error');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Failed: ${e.toString().replaceAll('Exception: ', '')}'),
          backgroundColor: Colors.red.shade600,
        ),
      );
    } finally {
      if (mounted) setState(() => _isGeneratingInsight = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final brown = AppTheme.astroBrown(isDark);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      resizeToAvoidBottomInset: true,
      body: GestureDetector(
        onTap: () => _focusNode.unfocus(),
        behavior: HitTestBehavior.opaque,
        child: Stack(
          children: [
            CustomScrollView(
              controller: _scrollController,
              slivers: [
                // App-aligned header
                SliverToBoxAdapter(
                  child: SafeArea(
                    bottom: false,
                    child: Container(
                      height: 60,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          // Back button
                          SizedBox(
                            width: 40,
                            child: IconButton(
                              icon: Icon(Icons.arrow_back_ios_new_rounded,
                                  size: 20, color: brown),
                              onPressed: () => Navigator.of(context).pop(),
                              padding: EdgeInsets.zero,
                            ),
                          ),
                          // Centered title - matching app header style
                          Expanded(
                            child: Center(
                              child: Text('insights',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    color: brown,
                                    letterSpacing: 1.2,
                                  )),
                            ),
                          ),
                          // Saved insights button
                          SizedBox(
                            width: 40,
                            child: IconButton(
                              icon: Icon(Icons.bookmark_outline,
                                  size: 22, color: brown),
                              onPressed: _openSavedInsights,
                              padding: EdgeInsets.zero,
                              tooltip: 'Saved insights',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Content
                SliverToBoxAdapter(
                  child: StreamBuilder<AstrologyProfile?>(
                    stream: _astrologyService.streamProfile(widget.uid),
                    builder: (context, profileSnapshot) {
                      // Cache profile for context building
                      if (profileSnapshot.data != null) {
                        _lastProfile = profileSnapshot.data;
                      }

                      return StreamBuilder<DailyInsight?>(
                        stream: widget.insightDate != null
                            ? _astrologyService.streamInsightForDate(
                                widget.uid, widget.insightDate!)
                            : _astrologyService.streamTodayInsight(widget.uid),
                        builder: (context, insightSnapshot) {
                          final insight = insightSnapshot.data;
                          final isLoading = insightSnapshot.connectionState ==
                              ConnectionState.waiting;

                          // Cache insight for context building
                          if (insight != null) {
                            _lastInsight = insight;
                          }

                          if (isLoading && insight == null) {
                            return _buildInsightSkeleton();
                          }

                          return LayoutBuilder(
                            builder: (context, constraints) {
                              final screenWidth = constraints.maxWidth;
                              // On wider screens, add more horizontal padding to create a centered column
                              final horizontalPadding = screenWidth > 700
                                  ? ((screenWidth - 600) / 2).clamp(16.0, 200.0)
                                  : 16.0;
                              final spacing = screenWidth > 700 ? 16.0 : 12.0;

                              return Padding(
                                padding: EdgeInsets.symmetric(
                                    horizontal: horizontalPadding),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 8),

                                    // Always show insight if it exists (even while regenerating)
                                    if (insight != null) ...[
                                      // Check if this is modern version (v5+) or legacy
                                      if (insight.sections.isNotEmpty)
                                        // V5+: Use InsightCard for cards with keys for scroll-to
                                        ...insight.sections
                                            .asMap()
                                            .entries
                                            .map((entry) {
                                          final index = entry.key;
                                          final section = entry.value;
                                          // Store key for scroll-to functionality
                                          _cardKeys[index] ??= GlobalKey();
                                          final isHighlighted =
                                              widget.highlightCardIndex ==
                                                  index;
                                          return Padding(
                                            padding: EdgeInsets.only(
                                                bottom: spacing),
                                            child: AnimatedContainer(
                                              duration: const Duration(
                                                  milliseconds: 500),
                                              key: _cardKeys[index],
                                              decoration: isHighlighted
                                                  ? BoxDecoration(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              20),
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: AppTheme
                                                              .primaryColor
                                                              .withOpacity(0.3),
                                                          blurRadius: 12,
                                                          spreadRadius: 2,
                                                        ),
                                                      ],
                                                    )
                                                  : null,
                                              child: InsightCard(
                                                section: section,
                                                footer:
                                                    _buildCardReactionFooter(
                                                  section: section,
                                                  profile: profileSnapshot.data,
                                                  isDark: isDark,
                                                  cardIndex: index,
                                                  insightDate:
                                                      insight.dateString,
                                                ),
                                              ),
                                            ),
                                          );
                                        })
                                      else ...[
                                        // Legacy/V4: Use old card rendering
                                        // Theme card (if theme exists)
                                        if (insight.displayTheme.isNotEmpty)
                                          _buildInsightCard(
                                            insight.displayTheme.toUpperCase(),
                                            insight.displayMessage,
                                            isDark,
                                            brown,
                                          ),

                                        // All sections as equal cards
                                        ...insight.sections
                                            .map((section) => Padding(
                                                  padding: EdgeInsets.only(
                                                      top: spacing),
                                                  child: _buildInsightCard(
                                                    section.title.toUpperCase(),
                                                    section.content,
                                                    isDark,
                                                    brown,
                                                  ),
                                                )),
                                      ],
                                    ] else if (_isGeneratingInsight)
                                      // Only show loading if NO insight exists yet
                                      _buildLoadingCard(isDark, brown)
                                    else
                                      // Empty state - no insight and not generating
                                      _buildEmptyState(isDark, brown),

                                    // Muhurat Timeline (when profile is available)
                                    if (_lastProfile != null &&
                                        _lastProfile!.muhurat != null) ...[
                                      SizedBox(height: spacing),
                                      MuhuratTimelineWidget(
                                        muhurat: _lastProfile!.muhurat!,
                                      ),
                                    ],

                                    // Generate button - for testing (uncommented)
                                    SizedBox(height: spacing + 4),
                                    _buildGenerateButton(
                                        insight, isDark, brown),

                                    // Bottom padding for chat input area
                                    const SizedBox(height: 140),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),

            // Astrology-themed chat input at bottom
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: AstroChatInput(
                  messageController: _messageController,
                  focusNode: _focusNode,
                  onSendMessage: _sendMessageWithAstroContext,
                  hintText: 'Curious about today?',
                  enableVoice: true,
                  isEntryPage: true,
                  astrologyContextBuilder: () =>
                      AstrologyContextBuilder.buildContext(
                    profile: _lastProfile,
                    insight: _lastInsight,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Track reactions independently for each card
  final Map<int, bool> _accurateReactions = {};
  final Map<int, bool> _savedInsights = {};

  /// Builds inline reaction footer for insight cards
  Widget _buildCardReactionFooter({
    required InsightSection section,
    required AstrologyProfile? profile,
    required bool isDark,
    required int cardIndex,
    required String insightDate,
  }) {
    final brown = AppTheme.astroBrown(isDark);
    final isAccurate = _accurateReactions[cardIndex] ?? false;
    final isSaved = _savedInsights[cardIndex] ?? false;

    // Format date nicely
    String formattedDate = '';
    try {
      final date = DateTime.parse(insightDate);
      formattedDate = '${_getMonthName(date.month)} ${date.day}, ${date.year}';
    } catch (_) {
      formattedDate = insightDate;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Date on top
        Text(
          formattedDate,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: brown.withValues(alpha: 0.4),
          ),
        ),
        const SizedBox(height: 8),

        // Action buttons row
        Row(
          children: [
            // Accurate button
            _buildReactionButton(
              icon: Icons.auto_awesome_outlined,
              label: 'Accurate',
              isSelected: isAccurate,
              onTap: () => _handleAccurate(cardIndex),
              brown: brown,
            ),
            const SizedBox(width: 8),
            // Save button
            _buildReactionButton(
              icon: Icons.bookmark_outline,
              label: isSaved ? 'Saved' : 'Save',
              isSelected: isSaved,
              onTap: () => _handleSave(cardIndex, section, insightDate),
              brown: brown,
            ),

            const Spacer(),

            // Share button (offers Send in Chat + image export)
            _buildReactionButton(
              icon: Icons.share_outlined,
              label: 'Share',
              isSelected: false,
              onTap: () {
                HapticFeedback.lightImpact();
                ShareService.shareInsight(
                  context: context,
                  insightId: 'daily_${insightDate}_${section.cardType}',
                  cardType: section.cardType,
                  title: section.title,
                  content: section.content,
                  userName: null,
                  moonSign: profile?.moonSign,
                  risingSign: profile?.ascendant,
                  sunSign: profile?.sunSign,
                );
              },
              brown: brown,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildReactionButton({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required Color brown,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? brown.withValues(alpha: 0.12)
              : brown.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? Border.all(color: brown.withValues(alpha: 0.25), width: 1)
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? _getFilledIcon(icon) : icon,
              size: 14,
              color: isSelected ? brown : brown.withValues(alpha: 0.6),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? brown : brown.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Get filled version of icon when selected
  IconData _getFilledIcon(IconData outlinedIcon) {
    if (outlinedIcon == Icons.auto_awesome_outlined) return Icons.auto_awesome;
    if (outlinedIcon == Icons.bookmark_outline) return Icons.bookmark;
    return outlinedIcon;
  }

  /// Get month name from month number
  String _getMonthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return months[month - 1];
  }

  void _handleAccurate(int cardIndex) {
    HapticFeedback.lightImpact();
    setState(() {
      _accurateReactions[cardIndex] = !(_accurateReactions[cardIndex] ?? false);
    });

    // TODO: Could save to Firestore for analytics
    AppLogger.d(
        'Insight marked accurate: card=$cardIndex, value=${_accurateReactions[cardIndex]}',
        category: LogCategory.general);
  }

  Future<void> _handleSave(
      int cardIndex, InsightSection section, String insightDate) async {
    HapticFeedback.lightImpact();

    final wasSaved = _savedInsights[cardIndex] ?? false;

    setState(() {
      _savedInsights[cardIndex] = !wasSaved;
    });

    try {
      final userId = widget.uid;
      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('savedInsights')
          .doc('${insightDate}_$cardIndex');

      if (!wasSaved) {
        // Save the insight
        await docRef.set({
          'title': section.title,
          'content': section.content,
          'cardType': section.cardType,
          'scheduledFor': section.scheduledFor,
          'insightDate': insightDate,
          'savedAt': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Insight saved'),
              backgroundColor: AppTheme.astroBrown(
                  Theme.of(context).brightness == Brightness.dark),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        // Remove from saved
        await docRef.delete();
      }

      AppLogger.d('Insight save toggled: card=$cardIndex, saved=${!wasSaved}',
          category: LogCategory.general);
    } catch (e) {
      // Revert UI on error
      setState(() {
        _savedInsights[cardIndex] = wasSaved;
      });
      AppLogger.e('Failed to save insight', error: e);
    }
  }

  void _openSavedInsights() {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SavedInsightsPage(uid: widget.uid),
      ),
    );
  }

  // Card color matching other astrology cards
  Color _cardColor(bool isDark) {
    return isDark ? Theme.of(context).colorScheme.surface : Colors.white;
  }

  // Skeleton loading for insights - instant display
  Widget _buildInsightSkeleton() {
    final colors = SkeletonColors.fromContext(context);

    return ShimmerBox(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            // Date header skeleton
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: colors.highlight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                        width: 140,
                        height: 18,
                        decoration: BoxDecoration(
                            color: colors.base,
                            borderRadius: BorderRadius.circular(9))),
                    const SizedBox(height: 6),
                    Container(
                        width: 100,
                        height: 12,
                        decoration: BoxDecoration(
                            color: colors.shimmer,
                            borderRadius: BorderRadius.circular(6))),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Insight cards
            ...List.generate(
                3,
                (index) => Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: colors.base,
                        borderRadius: BorderRadius.circular(20),
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
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Container(
                                    height: 18,
                                    decoration: BoxDecoration(
                                        color: colors.highlight,
                                        borderRadius:
                                            BorderRadius.circular(9))),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                  width: 50,
                                  height: 28,
                                  decoration: BoxDecoration(
                                      color: colors.shimmer,
                                      borderRadius: BorderRadius.circular(14))),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Container(
                              width: double.infinity,
                              height: 14,
                              decoration: BoxDecoration(
                                  color: colors.highlight,
                                  borderRadius: BorderRadius.circular(7))),
                          const SizedBox(height: 10),
                          Container(
                              width: MediaQuery.of(context).size.width * 0.75,
                              height: 14,
                              decoration: BoxDecoration(
                                  color: colors.shimmer,
                                  borderRadius: BorderRadius.circular(7))),
                          const SizedBox(height: 10),
                          Container(
                              width: MediaQuery.of(context).size.width * 0.5,
                              height: 14,
                              decoration: BoxDecoration(
                                  color: colors.shimmer,
                                  borderRadius: BorderRadius.circular(7))),
                        ],
                      ),
                    )),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // Parse rich text with **bold**, _italic_, and symbols
  Widget _buildRichText(String text, bool isDark, Color brown,
      {double fontSize = 13}) {
    final baseColor = brown.withValues(alpha: 0.85);

    final List<TextSpan> spans = [];
    final RegExp pattern = RegExp(r'\*\*(.+?)\*\*|_(.+?)_|([^*_]+)');

    for (final match in pattern.allMatches(text)) {
      if (match.group(1) != null) {
        // **bold**
        spans.add(TextSpan(
          text: match.group(1),
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: brown,
          ),
        ));
      } else if (match.group(2) != null) {
        // _italic_
        spans.add(TextSpan(
          text: match.group(2),
          style: TextStyle(
            fontStyle: FontStyle.italic,
            color: baseColor,
          ),
        ));
      } else if (match.group(3) != null) {
        // Regular text
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

  // Single card style for ALL insight cards - matching birth details card
  Widget _buildInsightCard(
      String title, String content, bool isDark, Color brown) {
    // Skip empty content cards (headline-only cards just show title)
    final hasContent = content.isNotEmpty;

    return Material(
      color: _cardColor(isDark),
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title - always brown
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
              const SizedBox(height: 12),
              // Content with rich formatting
              _buildRichText(content, isDark, brown),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark, Color brown) {
    return Material(
      color: _cardColor(isDark),
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Your Insight',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: brown,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Tap below to receive your personalized guidance based on your birth chart and current planetary positions.',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: brown.withValues(alpha: 0.7),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingCard(bool isDark, Color brown) {
    return Material(
      color: _cardColor(isDark),
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Generating Insight',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: brown,
              ),
            ),
            const SizedBox(height: 12),
            ShimmerText(
              text: 'Reading the stars...',
              baseColor: brown.withValues(alpha: 0.7),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGenerateButton(DailyInsight? insight, bool isDark, Color brown) {
    final shouldForceRegenerate = insight != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _isGeneratingInsight
            ? null
            : () =>
                _generateDailyInsight(forceRegenerate: shouldForceRegenerate),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            border: Border.all(color: brown.withValues(alpha: 0.3), width: 1.5),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!_isGeneratingInsight)
                Text(
                  '✦',
                  style: TextStyle(fontSize: 16, color: brown),
                ),
              if (!_isGeneratingInsight) const SizedBox(width: 10),
              if (_isGeneratingInsight)
                ShimmerText(
                  text: 'Generating...',
                  baseColor: brown,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                )
              else
                Text(
                  insight != null ? 'Regenerate' : 'Get Your Insight',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: brown,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
