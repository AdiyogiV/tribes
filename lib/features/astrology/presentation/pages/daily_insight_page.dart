import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:aurogram/shared/models/astrology_profile.dart';
import 'package:aurogram/features/astrology/domain/astrology_service.dart';
import 'package:aurogram/features/notifications/domain/notification_service.dart';
import 'package:go_router/go_router.dart';
import 'package:aurogram/core/logging/app_logger.dart';
import 'package:aurogram/features/astrology/presentation/widgets/timeline/muhurat_timeline_widget.dart';
import 'package:aurogram/features/astrology/presentation/pages/insight/forecast_day_view.dart';
import 'package:aurogram/features/astrology/presentation/pages/insight/insight_widgets.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';
import 'package:aurogram/features/astrology/domain/forecast_service.dart';
import 'package:aurogram/features/baba/domain/baba_snapshot.dart';

class DailyInsightPage extends StatefulWidget {
  final String uid;
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

  @override
  String get babaScreenKey => 'dailyInsight';

  @override
  BabaSnapshot babaSnapshot() {
    final forecast = _lastForecast;
    if (_isRefreshingForecast) {
      return const BabaSnapshot.loading(headline: "Today's energy is refreshing");
    }
    if (forecast == null) {
      return const BabaSnapshot.empty(headline: 'No daily energy on screen yet');
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

  String get _uid => widget.uid.isNotEmpty
      ? widget.uid
      : (FirebaseAuth.instance.currentUser?.uid ?? '');

  final ScrollController _scrollController = ScrollController();
  AstrologyProfile? _lastProfile;
  ForecastDay? _lastForecast;

  String get _forecastDate => widget.insightDate ?? ForecastService.dateKey(_istNow);
  DateTime get _istNow => DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));
  bool get _isToday => _forecastDate == ForecastService.dateKey(_istNow);
  bool _notificationPromptShown = false;

  @override
  void initState() {
    super.initState();
    _refreshForecast();
    _checkNotificationPermissions();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FirebaseFunctions.instanceFor(region: 'asia-southeast2')
          .httpsCallable('socialGateway')
          .call({'method': 'awardAuraAction', 'action': 'daily_insight_view'})
          .then((_) {}, onError: (_, __) {});
    });
  }

  Future<void> _checkNotificationPermissions() async {
    await Future.delayed(const Duration(seconds: 5));
    if (!mounted || _notificationPromptShown) return;
    final notificationService = NotificationService();
    if (notificationService.permissionsRequested) return;
    final hasPermission = await notificationService.hasPermission();
    if (hasPermission) return;

    _notificationPromptShown = true;
    if (!mounted) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fgColor = isDark ? Colors.white : Colors.black;
    final bgColor = isDark ? Colors.black : Colors.white;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.wb_sunny_outlined, color: bgColor, size: 20),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                'Get daily cosmic updates?',
                style: TextStyle(color: bgColor, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        action: SnackBarAction(
          label: 'Enable',
          textColor: bgColor,
          onPressed: () async {
            HapticFeedback.lightImpact();
            await notificationService.requestPermissions();
          },
        ),
        duration: const Duration(seconds: 6),
        behavior: SnackBarBehavior.floating,
        backgroundColor: fgColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
        margin: const EdgeInsets.all(24),
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
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
    // Stark editorial colors
    final bgColor = isDark ? Colors.black : Colors.white;
    final fgColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: bgColor,
      resizeToAvoidBottomInset: true,
      body: GestureDetector(
        onTap: () {},
        behavior: HitTestBehavior.opaque,
        child: Stack(
          children: [
            CustomScrollView(
              controller: _scrollController,
              slivers: [
                SliverToBoxAdapter(
                  child: SafeArea(
                    bottom: false,
                    child: Container(
                      height: 60,
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 40,
                            child: IconButton(
                              icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: fgColor),
                              onPressed: () => Navigator.of(context).pop(),
                              padding: EdgeInsets.zero,
                              alignment: Alignment.centerLeft,
                            ),
                          ),
                          Expanded(
                            child: Center(
                              child: Text(
                                _isToday ? "TODAY" : "DAILY",
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 3.0,
                                  color: fgColor,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 40,
                            child: IconButton(
                              icon: Icon(Icons.bookmark_outline, size: 20, color: fgColor),
                              onPressed: _openSavedInsights,
                              padding: EdgeInsets.zero,
                              alignment: Alignment.centerRight,
                              tooltip: 'Saved daily energies',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
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
                          final forecast = forecastSnapshot.data?[_forecastDate];
                          final isLoading = forecastSnapshot.connectionState == ConnectionState.waiting;

                          if (forecast != null) _lastForecast = forecast;
                          if (isLoading && forecast == null) {
                            return const InsightSkeleton();
                          }

                          return LayoutBuilder(
                            builder: (context, constraints) {
                              final screenWidth = constraints.maxWidth;
                              final horizontalPadding = screenWidth > 700
                                  ? ((screenWidth - 600) / 2).clamp(32.0, 200.0)
                                  : 32.0;
                              final spacing = screenWidth > 700 ? 32.0 : 32.0;

                              return Padding(
                                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 24),
                                    if (forecast != null)
                                      ForecastDayView(
                                        forecast: forecast,
                                        profile: profileSnapshot.data,
                                        uid: _uid,
                                      )
                                    else if (_isRefreshingForecast)
                                      InsightLoadingCard(isDark: isDark, brown: fgColor)
                                    else
                                      InsightEmptyState(isDark: isDark, brown: fgColor),
                                      
                                    if (_lastProfile?.muhurat != null) ...[
                                      SizedBox(height: spacing),
                                      MuhuratTimelineWidget(muhurat: _lastProfile!.muhurat!),
                                    ],
                                    const SizedBox(height: 60),
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
          ],
        ),
      ),
    );
  }
}