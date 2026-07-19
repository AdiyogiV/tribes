import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:aurogram/shared/models/astrology_profile.dart';
import 'package:aurogram/features/astrology/domain/astrology_service.dart';
import 'package:aurogram/features/notifications/domain/notification_service.dart';
import 'package:go_router/go_router.dart';
import 'package:aurogram/features/astrology/presentation/widgets/astro_chat_input.dart';
import 'package:aurogram/core/logging/app_logger.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/features/astrology/data/utils/astrology_context_builder.dart';
import 'package:aurogram/features/astrology/presentation/widgets/timeline/muhurat_timeline_widget.dart';
import 'package:aurogram/features/astrology/presentation/pages/insight/forecast_day_view.dart';
import 'package:aurogram/features/astrology/presentation/pages/insight/insight_widgets.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';
import 'package:aurogram/features/astrology/domain/forecast_service.dart';
import 'package:aurogram/features/baba/domain/baba_snapshot.dart';

class DailyInsightPage extends StatefulWidget {
  final String uid;

  /// Optional: specific date to show (for history view). If null, shows today.
  final String? insightDate;

  const DailyInsightPage({
    super.key,
    required this.uid,
    this.insightDate,
  });

  @override
  State<DailyInsightPage> createState() => _DailyInsightPageState();
}

class _DailyInsightPageState extends State<DailyInsightPage>
    with BabaScreenAware<DailyInsightPage> {
  final _astrologyService = AstrologyService();
  bool _isRefreshingForecast = false;

  // ── Baba page awareness ──────────────────────────────────────────────
  // So Baba can answer "what does today's reading say?" from what's actually
  // rendered — the theme + the section headings currently on screen.
  @override
  String get babaScreenKey => 'dailyInsight';

  @override
  BabaSnapshot babaSnapshot() {
    final forecast = _lastForecast;
    if (_isRefreshingForecast) {
      return const BabaSnapshot.loading(
          headline: "Today's energy is refreshing");
    }
    if (forecast == null) {
      return const BabaSnapshot.empty(
          headline: 'No daily energy on screen yet');
    }
    return BabaSnapshot.ready(
      headline: "Today's energy: ${forecast.heading ?? 'Daily guidance'}",
      facts: {
        'date': forecast.date,
        'heading': forecast.heading,
        'alignment': forecast.alignment,
        'viewingHistory': widget.insightDate != null,
      },
      items: [
        if (forecast.action?.isNotEmpty == true) 'Focus',
        if (forecast.caution?.isNotEmpty == true) 'Handle gently',
        if (forecast.timing?.isNotEmpty == true) 'Timing',
        if (forecast.tip?.isNotEmpty == true) 'Practical tip',
      ],
    );
  }

  /// The uid to stream against. Falls back to the signed-in user when a caller
  /// (e.g. Baba's navigateTo) opens this page without passing one — an empty
  /// uid makes Firestore throw "document path must be a non-empty string".
  String get _uid => widget.uid.isNotEmpty
      ? widget.uid
      : (FirebaseAuth.instance.currentUser?.uid ?? '');

  // AI Chat input controllers
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  final ScrollController _scrollController = ScrollController();

  // Cache the rendered profile and forecast for Aurobhatt context.
  AstrologyProfile? _lastProfile;
  ForecastDay? _lastForecast;

  String get _forecastDate {
    if (widget.insightDate != null) return widget.insightDate!;
    return ForecastService.dateKey(_istNow);
  }

  DateTime get _istNow =>
      DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));

  bool get _isToday => _forecastDate == ForecastService.dateKey(_istNow);

  // Track if notification prompt was shown
  bool _notificationPromptShown = false;

  @override
  void initState() {
    super.initState();

    // Self-heal missing/stale forecast data without invoking a second daily AI.
    _refreshForecast();

    // Check notification permissions after a delay (fallback for users who skipped onboarding prompt)
    _checkNotificationPermissions();

    // Aura: award daily insight view (+1 once per day) via socialGateway (fire-and-forget)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FirebaseFunctions.instanceFor(region: 'asia-southeast2')
          .httpsCallable('socialGateway')
          .call({
        'method': 'awardAuraAction',
        'action': 'daily_insight_view'
      }).then((_) {}, onError: (_, __) {});
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
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusMd)),
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

  /// Send message with astrology context and push to astro chat page
  void _sendMessageWithAstroContext() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    try {
      final astroContext = AstrologyContextBuilder.buildContext(
        profile: _lastProfile,
        forecast: _lastForecast,
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

  Future<void> _refreshForecast() async {
    if (_isRefreshingForecast || widget.insightDate != null) return;
    setState(() => _isRefreshingForecast = true);
    await ForecastService().ensureComputed();
    if (mounted) setState(() => _isRefreshingForecast = false);
  }

  void _openSavedInsights() {
    HapticFeedback.lightImpact();
    context.push('/astrology/saved/$_uid');
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppDimensions.paddingLg),
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
                              child: Text(
                                  _isToday ? "today's energy" : 'daily energy',
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
                              tooltip: 'Saved daily energies',
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

                      return StreamBuilder<Map<String, ForecastDay>>(
                        stream: ForecastService().streamForecast(_uid),
                        builder: (context, forecastSnapshot) {
                          final forecast =
                              forecastSnapshot.data?[_forecastDate];
                          final isLoading = forecastSnapshot.connectionState ==
                              ConnectionState.waiting;

                          if (forecast != null) _lastForecast = forecast;
                          if (isLoading && forecast == null) {
                            return const InsightSkeleton();
                          }

                          return LayoutBuilder(
                            builder: (context, constraints) {
                              final screenWidth = constraints.maxWidth;
                              final horizontalPadding = screenWidth > 700
                                  ? ((screenWidth - 600) / 2).clamp(16.0, 200.0)
                                  : 16.0;
                              final spacing = screenWidth > 700 ? 20.0 : 16.0;

                              return Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: horizontalPadding,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(
                                      height: AppDimensions.spacingSm,
                                    ),
                                    if (forecast != null)
                                      ForecastDayView(
                                        forecast: forecast,
                                        profile: profileSnapshot.data,
                                        uid: _uid,
                                      )
                                    else if (_isRefreshingForecast)
                                      InsightLoadingCard(
                                        isDark: isDark,
                                        brown: brown,
                                      )
                                    else
                                      InsightEmptyState(
                                        isDark: isDark,
                                        brown: brown,
                                      ),
                                    if (_lastProfile?.muhurat != null) ...[
                                      SizedBox(height: spacing),
                                      MuhuratTimelineWidget(
                                        muhurat: _lastProfile!.muhurat!,
                                      ),
                                    ],
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
                  hintText: "Ask about today's energy…",
                  enableVoice: true,
                  isEntryPage: true,
                  astrologyContextBuilder: () =>
                      AstrologyContextBuilder.buildContext(
                    profile: _lastProfile,
                    forecast: _lastForecast,
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
