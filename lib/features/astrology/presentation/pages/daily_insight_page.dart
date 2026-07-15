import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:aurogram/shared/models/daily_insight.dart';
import 'package:aurogram/shared/models/astrology_profile.dart';
import 'package:aurogram/features/astrology/domain/astrology_service.dart';
import 'package:aurogram/features/notifications/domain/notification_service.dart';
import 'package:aurogram/features/astrology/presentation/widgets/insight_cards/insight_card.dart';
import 'package:go_router/go_router.dart';
import 'package:aurogram/features/astrology/presentation/widgets/astro_chat_input.dart';
import 'package:aurogram/core/logging/app_logger.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/features/astrology/data/utils/astrology_context_builder.dart';
import 'package:aurogram/features/astrology/presentation/widgets/timeline/muhurat_timeline_widget.dart';
import 'package:aurogram/features/astrology/presentation/pages/insight/insight_widgets.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';
import 'package:aurogram/shared/presentation/widgets/feedback/snack_bar_service.dart';
import 'package:aurogram/features/baba/domain/baba_snapshot.dart';

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

class _DailyInsightPageState extends State<DailyInsightPage>
    with BabaScreenAware<DailyInsightPage> {
  final _astrologyService = AstrologyService();
  bool _isGeneratingInsight = false;

  // ── Baba page awareness ──────────────────────────────────────────────
  // So Baba can answer "what does today's reading say?" from what's actually
  // rendered — the theme + the section headings currently on screen.
  @override
  String get babaScreenKey => 'dailyInsight';

  @override
  Map<String, dynamic> babaSnapshot() => {
        'date': _lastInsight?.dateString ?? widget.insightDate ?? 'today',
        'viewingHistory': widget.insightDate != null,
        'hasInsight': _lastInsight != null,
        if (_lastInsight != null) 'theme': _lastInsight!.displayTheme,
        if (_lastInsight != null)
          'sections':
              _lastInsight!.sections.map((s) => s.title).toList(growable: false),
        'generating': _isGeneratingInsight,
      };

  /// The uid to stream against. Falls back to the signed-in user when a caller
  /// (e.g. Baba's navigateTo) opens this page without passing one — an empty
  /// uid makes Firestore throw "document path must be a non-empty string".
  String get _uid =>
      widget.uid.isNotEmpty ? widget.uid : (FirebaseAuth.instance.currentUser?.uid ?? '');

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

    // Aura: award daily insight view (+1 once per day) via socialGateway (fire-and-forget)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FirebaseFunctions.instanceFor(region: 'asia-southeast2')
          .httpsCallable('socialGateway')
          .call({'method': 'awardAuraAction', 'action': 'daily_insight_view'})
          .then((_) {}, onError: (_, __) {});
    });
  }

  /// Check and offer notification permissions with subtle non-intrusive prompt
  Future<void> _checkNotificationPermissions() async {
    await Future.delayed(const Duration(seconds: 5));

    if (!mounted || _notificationPromptShown) return;

    final notificationService = NotificationService();

    if (notificationService.permissionsRequested) return;
    final hasPermission = await notificationService.hasPermission();
    if (hasPermission) return;

    _notificationPromptShown = true;

    if (!mounted) return;

    final shouldEnable = await ScaffoldMessenger.of(context)
        .showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.wb_sunny_rounded,
                    color: Colors.amber.shade200, size: 20),
                const SizedBox(width: AppDimensions.spacingMd),
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
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusMd)),
            margin: const EdgeInsets.all(AppDimensions.paddingLg),
          ),
        )
        .closed;

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
      final astroContext = AstrologyContextBuilder.buildContext(
        profile: _lastProfile,
        insight: _lastInsight,
      );

      _messageController.clear();
      _focusNode.unfocus();

      HapticFeedback.lightImpact();

      context.push('/astrology/chat', extra: {
        'astrologyContext': astroContext,
        'initialMessage': text,
      });
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
        // Server short-circuited (already generated today / quota hit). Don't
        // pretend new wisdom arrived — that's what makes users re-tap a no-op.
        if (result['rateLimited'] == true) {
          showCustomSnackBar(context,
              message: "Today's reading is already in — check back tomorrow",
              backgroundColor: Colors.amber.shade700);
        } else {
          showCustomSnackBar(context, message: 'Wisdom received', backgroundColor: Colors.green.shade600);
        }
      } else {
        throw Exception(result?['error'] ?? 'Unknown error');
      }
    } catch (e) {
      if (!mounted) return;
      showCustomSnackBar(context, message: 'Failed: ${e.toString().replaceAll("Exception: ", "")}', backgroundColor: Colors.red.shade600);
    } finally {
      if (mounted) setState(() => _isGeneratingInsight = false);
    }
  }

  void _openSavedInsights() {
    HapticFeedback.lightImpact();
    context.push('/astrology/saved/${_uid}');
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
                      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingLg),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 40,
                            child: IconButton(
                              icon: Icon(Icons.arrow_back_ios_new_rounded,
                                  size: 20, color: brown),
                              onPressed: () => Navigator.of(context).pop(),
                              padding: EdgeInsets.zero,
                            ),
                          ),
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
                    stream: _astrologyService.streamProfile(_uid),
                    builder: (context, profileSnapshot) {
                      if (profileSnapshot.data != null) {
                        _lastProfile = profileSnapshot.data;
                      }

                      return StreamBuilder<DailyInsight?>(
                        stream: widget.insightDate != null
                            ? _astrologyService.streamInsightForDate(
                                _uid, widget.insightDate!)
                            : _astrologyService.streamTodayInsight(_uid),
                        builder: (context, insightSnapshot) {
                          final insight = insightSnapshot.data;
                          final isLoading = insightSnapshot.connectionState ==
                              ConnectionState.waiting;

                          if (insight != null) {
                            _lastInsight = insight;
                          }

                          if (isLoading && insight == null) {
                            return const InsightSkeleton();
                          }

                          return LayoutBuilder(
                            builder: (context, constraints) {
                              final screenWidth = constraints.maxWidth;
                              final horizontalPadding = screenWidth > 700
                                  ? ((screenWidth - 600) / 2)
                                      .clamp(16.0, 200.0)
                                  : 16.0;
                              final spacing = screenWidth > 700 ? 16.0 : 12.0;

                              return Padding(
                                padding: EdgeInsets.symmetric(
                                    horizontal: horizontalPadding),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: AppDimensions.spacingSm),

                                    if (insight != null) ...[
                                      if (insight.sections.isNotEmpty)
                                        ...insight.sections
                                            .asMap()
                                            .entries
                                            .map((entry) {
                                          final index = entry.key;
                                          final section = entry.value;
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
                                                              .withValues(alpha: 0.3),
                                                          blurRadius: 12,
                                                          spreadRadius: 2,
                                                        ),
                                                      ],
                                                    )
                                                  : null,
                                              child: InsightCard(
                                                section: section,
                                                footer:
                                                    InsightReactionFooter(
                                                  section: section,
                                                  profile:
                                                      profileSnapshot.data,
                                                  isDark: isDark,
                                                  cardIndex: index,
                                                  insightDate:
                                                      insight.dateString,
                                                  uid: _uid,
                                                ),
                                              ),
                                            ),
                                          );
                                        })
                                      else ...[
                                        if (insight.displayTheme.isNotEmpty)
                                          LegacyInsightCard(
                                            title: insight.displayTheme
                                                .toUpperCase(),
                                            content: insight.displayMessage,
                                            isDark: isDark,
                                            brown: brown,
                                          ),

                                        ...insight.sections
                                            .map((section) => Padding(
                                                  padding: EdgeInsets.only(
                                                      top: spacing),
                                                  child: LegacyInsightCard(
                                                    title: section.title
                                                        .toUpperCase(),
                                                    content: section.content,
                                                    isDark: isDark,
                                                    brown: brown,
                                                  ),
                                                )),
                                      ],
                                    ] else if (_isGeneratingInsight)
                                      InsightLoadingCard(
                                          isDark: isDark, brown: brown)
                                    else
                                      InsightEmptyState(
                                          isDark: isDark, brown: brown),

                                    // Muhurat Timeline
                                    if (_lastProfile != null &&
                                        _lastProfile!.muhurat != null) ...[
                                      SizedBox(height: spacing),
                                      MuhuratTimelineWidget(
                                        muhurat: _lastProfile!.muhurat!,
                                      ),
                                    ],

                                    SizedBox(height: spacing + 4),
                                    InsightGenerateButton(
                                      insight: insight,
                                      isDark: isDark,
                                      brown: brown,
                                      isGenerating: _isGeneratingInsight,
                                      onGenerate: () =>
                                          _generateDailyInsight(
                                        forceRegenerate: insight != null,
                                      ),
                                    ),

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
}
