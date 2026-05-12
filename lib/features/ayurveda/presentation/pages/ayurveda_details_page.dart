import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:aurogram/core/routing/route_names.dart';
import 'package:aurogram/shared/models/ayurveda_profile.dart';
import 'package:aurogram/shared/models/astrology_profile.dart';
import 'package:aurogram/features/ayurveda/domain/ayurveda_service.dart';
import 'package:aurogram/features/astrology/domain/astrology_service.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/features/astrology/data/utils/astrology_context_builder.dart';
import 'package:aurogram/features/astrology/presentation/widgets/astro_chat_input.dart';
import 'package:aurogram/features/ayurveda/presentation/widgets/ayurveda_details_header.dart';
import 'package:aurogram/features/ayurveda/presentation/widgets/ayurveda_reset_overlay.dart';
import 'package:aurogram/features/ayurveda/presentation/widgets/ayurveda_details_skeleton.dart';
import 'package:aurogram/features/ayurveda/presentation/widgets/dosha_dashboard_card.dart';
import 'package:aurogram/features/ayurveda/presentation/widgets/consolidated_cards.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';
import 'package:aurogram/shared/presentation/widgets/feedback/snack_bar_service.dart';
import 'package:provider/provider.dart';
import 'package:aurogram/shared/providers/watch_health_provider.dart';
import 'package:aurogram/features/ayurveda/presentation/widgets/watch_health_cards.dart';

/// Main Ayurveda details page
/// Shows Prakriti profile, current Vikriti, health insights, and recommendations
class AyurvedaDetailsPage extends StatefulWidget {
  final String uid;

  const AyurvedaDetailsPage({super.key, required this.uid});

  @override
  State<AyurvedaDetailsPage> createState() => _AyurvedaDetailsPageState();
}

class _AyurvedaDetailsPageState extends State<AyurvedaDetailsPage> {
  final _ayurvedaService = AyurvedaService();
  final _astrologyService = AstrologyService();

  AyurvedaProfile? _profile;
  AstrologyProfile? _astroProfile;
  VikritiData? _vikriti;
  bool _isCalculatingVikriti = false;
  bool _isResetting = false;
  bool _hasCheckedInitialCalculation = false;

  final _msgController = TextEditingController();
  final _focusNode = FocusNode();

  // Cache streams once in initState — never recreate in build().
  // Creating streams inside build() causes StreamBuilder to unsubscribe/
  // resubscribe on every rebuild, which introduces a race condition where
  // one stream emits before the other, triggering a spurious
  // _calculateProfile() that overwrites vikriti data in Firestore.
  late final Stream<AstrologyProfile?> _astroStream;
  late final Stream<AyurvedaProfile?> _ayurvedaStream;

  @override
  void dispose() {
    _msgController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _astroStream = _astrologyService.streamProfile(widget.uid);
    _ayurvedaStream = _ayurvedaService.streamProfile(widget.uid);
  }

  /// Check if Ayurveda needs to be calculated and trigger it if needed.
  /// IMPORTANT: Both streams must have emitted at least once before we
  /// decide the profile is truly missing. Otherwise a slow ayurveda stream
  /// looks like "no profile" and triggers a cloud-function recalculation
  /// that overwrites existing data (including vikriti).
  void _checkAndCalculateIfNeeded(
      AyurvedaProfile? profile,
      AstrologyProfile? astroProfile, {
      required bool ayurvedaStreamHasEmitted,
  }) {
    // Only check once to avoid multiple calls
    if (_hasCheckedInitialCalculation) return;

    // Don't act until the ayurveda stream has actually emitted — a null
    // profile might just mean the stream hasn't delivered data yet.
    if (!ayurvedaStreamHasEmitted) return;

    // If no Ayurveda profile but has astrology, calculate it
    if (profile == null && astroProfile?.hasCalculatedData == true) {
      _hasCheckedInitialCalculation = true;
      _calculateProfile();
    } else if (profile != null ||
        astroProfile == null ||
        !astroProfile.hasCalculatedData) {
      // Mark as checked if we have profile or astrology isn't ready
      _hasCheckedInitialCalculation = true;
    }
  }

  /// Calculate Vikriti when both profiles are available
  void _updateVikriti(
      AyurvedaProfile? profile, AstrologyProfile? astroProfile) {
    if (profile != null && astroProfile != null) {
      // Use saved Vikriti from profile first
      if (profile.vikriti != null) {
        if (_vikriti != profile.vikriti) {
          setState(() => _vikriti = profile.vikriti);
        }
      } else if (_vikriti == null && !_isCalculatingVikriti) {
        // Only calculate if no saved Vikriti and not already calculating
        _calculateVikriti();
      }
    } else if (_vikriti != null) {
      setState(() => _vikriti = null);
    }
  }

  Future<void> _calculateProfile() async {
    final newProfile = await _ayurvedaService.calculateProfile();
    if (mounted && newProfile != null) {
      setState(() => _profile = newProfile);
    }
  }

  Future<void> _calculateVikriti() async {
    if (_profile == null || _astroProfile == null) return;

    setState(() => _isCalculatingVikriti = true);

    try {
      final vikriti = await _ayurvedaService.calculateVikriti(
        profile: _profile!,
        astroProfile: _astroProfile!,
      );

      if (mounted && vikriti != null) {
        setState(() => _vikriti = vikriti);

        // Save vikriti to Firestore so subsequent page loads don't need
        // to recalculate via cloud function (expensive cold start)
        _ayurvedaService.saveVikriti(vikriti);
      }
    } finally {
      if (mounted) {
        setState(() => _isCalculatingVikriti = false);
      }
    }
  }

  /// Show confirmation dialog and reset Ayurveda profile
  Future<void> _confirmAndResetProfile() async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Reset Ayurveda Profile?'),
        content: const Text(
          'This will delete all your Ayurveda data including questionnaire answers, check-in history, and current state. Your profile will be recalculated fresh from your birth chart.',
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context, false),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Reset'),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isResetting = true);
    HapticFeedback.mediumImpact();

    try {
      final newProfile = await _ayurvedaService.resetProfile();

      if (mounted) {
        if (newProfile != null) {
          setState(() {
            _profile = newProfile;
            _vikriti = null; // Clear old vikriti
            _isResetting = false;
          });

          // Show success message
          showCustomSnackBar(context, message: 'Ayurveda profile reset successfully', backgroundColor: Colors.green.shade600, behavior: SnackBarBehavior.floating);

          // Recalculate vikriti
          _calculateVikriti();
        } else {
          setState(() => _isResetting = false);
          showCustomSnackBar(context, message: 'Failed to reset profile', backgroundColor: Colors.red.shade600, behavior: SnackBarBehavior.floating);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isResetting = false);
        showCustomSnackBar(context, message: 'Error: $e', backgroundColor: Colors.red.shade600, behavior: SnackBarBehavior.floating);
      }
    }
  }

  Future<void> _showAyurvedaInfoDialog({
    required String title,
    required String message,
  }) async {
    HapticFeedback.lightImpact();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final c = AppTheme.primaryColor;
    final dividerColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.06);

    await showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(AppDimensions.paddingLg),
        child: Material(
          color: isDark ? Theme.of(context).colorScheme.surface : Colors.white,
          elevation: 3,
          shadowColor: Colors.black.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(AppDimensions.radiusXxl),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(AppDimensions.paddingXxl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(AppDimensions.paddingMd),
                          decoration: BoxDecoration(
                            color: c.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(AppDimensions.radiusMdLg),
                          ),
                          child: Icon(
                            Icons.spa_rounded,
                            size: 26,
                            color: c,
                          ),
                        ),
                        const SizedBox(width: AppDimensions.spacingLg),
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w400,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.close_rounded,
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.7)
                                : Colors.black54,
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppDimensions.spacingMd),
                    Container(height: 1, color: dividerColor),
                    const SizedBox(height: AppDimensions.spacingMdLg),
                    SelectableText(
                      message,
                      style: TextStyle(
                        fontSize: 14.5,
                        height: 1.5,
                        fontWeight: FontWeight.w400,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          // Loading overlay when resetting
          if (_isResetting) AyurvedaResetOverlay(isDark: isDark),
          StreamBuilder<AstrologyProfile?>(
            stream: _astroStream,
            builder: (context, astroSnapshot) {
              final astroProfile = astroSnapshot.data;

              return StreamBuilder<AyurvedaProfile?>(
                stream: _ayurvedaStream,
                builder: (context, ayurSnapshot) {
                  final ayurProfile = ayurSnapshot.data;
                  final isLoading = (astroSnapshot.connectionState ==
                              ConnectionState.waiting &&
                          astroProfile == null) ||
                      (ayurSnapshot.connectionState ==
                              ConnectionState.waiting &&
                          ayurProfile == null);

                  // Update state when streams emit new data (for use in callbacks)
                  // Track whether the ayurveda stream has actually emitted
                  // (vs still being in ConnectionState.waiting with no data).
                  final ayurvedaHasEmitted =
                      ayurSnapshot.connectionState != ConnectionState.waiting ||
                      ayurProfile != null;

                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      bool shouldUpdate = false;

                      if (_profile != ayurProfile) {
                        _profile = ayurProfile;
                        shouldUpdate = true;
                      }
                      if (_astroProfile != astroProfile) {
                        _astroProfile = astroProfile;
                        shouldUpdate = true;
                      }

                      if (shouldUpdate) {
                        // Check if Ayurveda needs to be calculated
                        _checkAndCalculateIfNeeded(
                          ayurProfile,
                          astroProfile,
                          ayurvedaStreamHasEmitted: ayurvedaHasEmitted,
                        );
                        // Update Vikriti
                        _updateVikriti(ayurProfile, astroProfile);
                      }
                    }
                  });

                  return CustomScrollView(
                    slivers: [
                      // Header
                      SliverToBoxAdapter(
                        child: AyurvedaDetailsHeader(
                          onBack: () => Navigator.pop(context),
                          showMenu: ayurProfile != null && astroProfile != null,
                          onReset: _confirmAndResetProfile,
                        ),
                      ),

                      // Content - use stream data directly, but also update state for callbacks
                      SliverToBoxAdapter(
                        child: isLoading
                            ? const AyurvedaDetailsSkeleton()
                            : ayurProfile == null
                                ? _buildNoProfile(context)
                                : _buildContentWithProfile(
                                    context, isDark, ayurProfile, astroProfile),
                      ),
                    ],
                  );
                },
              );
            },
          ),

          // AI Chat Input at bottom — reuse cached streams
          StreamBuilder<AstrologyProfile?>(
            stream: _astroStream,
            builder: (context, astroSnapshot) {
              return StreamBuilder<AyurvedaProfile?>(
                stream: _ayurvedaStream,
                builder: (context, ayurSnapshot) {
                  final chatAyurProfile = ayurSnapshot.data;
                  final chatAstroProfile = astroSnapshot.data;

                  if (chatAyurProfile == null || chatAstroProfile == null) {
                    return const SizedBox.shrink();
                  }

                  return Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: AstroChatInput(
                      messageController: _msgController,
                      focusNode: _focusNode,
                      onSendMessage: () =>
                          _chatWithProfiles(chatAstroProfile, chatAyurProfile),
                      hintText: 'Ask about wellness',
                      enableVoice: true,
                      isEntryPage: true,
                      astrologyContextBuilder: () =>
                          AstrologyContextBuilder.buildWellnessChatContext(
                        chatAyurProfile,
                      ),
                      chatSource: 'wellness',
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  void _chatWithProfiles(
      AstrologyProfile? astroProfile, AyurvedaProfile? ayurProfile) {
    final text = _msgController.text.trim();
    if (text.isEmpty || ayurProfile == null) return;

    final wellnessContext =
        AstrologyContextBuilder.buildWellnessChatContext(ayurProfile);
    _msgController.clear();
    _focusNode.unfocus();
    HapticFeedback.lightImpact();

    context.push(
      RouteNames.astroChatPage,
      extra: {
        'astrologyContext': wellnessContext,
        'initialMessage': text,
        'chatSource': 'wellness',
      },
    );
  }

  Widget _buildNoProfile(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.spa_outlined,
              size: 40,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: AppDimensions.spacingXl),
          Text(
            'Ayurveda Profile',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppDimensions.spacingSm),
          Text(
            'Complete your astrology profile to unlock personalized Ayurveda insights based on your birth chart.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentWithProfile(BuildContext context, bool isDark,
      AyurvedaProfile? profile, AstrologyProfile? astroProfile) {
    if (profile == null || profile.prakriti == null) {
      return _buildNoProfile(context);
    }

    final prakriti = profile.prakriti!;

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        // On wider screens, add more horizontal padding to create a centered column
        final horizontalPadding = screenWidth > 700
            ? ((screenWidth - 600) / 2).clamp(16.0, 200.0)
            : 16.0;
        final spacing = screenWidth > 700 ? 16.0 : 12.0;

        // Access watch health data and trends from provider
        final watchProvider = context.watch<WatchHealthProvider>();
        final watchHealth = watchProvider.healthData;
        final trends = watchProvider.hasHistory
            ? <String, List<double>>{
                'hrv': watchProvider.metricTrend('hrv'),
                'restingHR': watchProvider.metricTrend('restingHR'),
                'steps': watchProvider.metricTrend('steps'),
                'spO2': watchProvider.metricTrend('spO2'),
                'respRate': watchProvider.metricTrend('respRate'),
                'activeEnergy': watchProvider.metricTrend('activeEnergy'),
                'sleepHours': watchProvider.metricTrend('sleepHours'),
                'wristTemp': watchProvider.metricTrend('wristTemp'),
                'vo2Max': watchProvider.metricTrend('vo2Max'),
              }
            : null;

        return Padding(
          padding: EdgeInsets.all(horizontalPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Card 1: Current Balance (Vikriti) - current state
              TodaysBalanceCard(
                prakriti: prakriti,
                vikriti: _vikriti,
                isCalculating: _isCalculatingVikriti,
                lastCheckIn: _profile?.lastCheckIn,
                onInfo: () => _showAyurvedaInfoDialog(
                  title: 'Current Balance (Vikriti)',
                  message:
                      'Vikriti is your current dosha state - it shifts daily based on various factors.\n\n'
                      '• Planetary periods (Dasha)\n'
                      '• Moon\'s position (Tarabala & Chandrabala)\n'
                      '• Season and time of day\n'
                      '• Your lifestyle choices\n\n'
                      'Quick check-ins help track these changes and provide personalized guidance.',
                ),
                isDark: isDark,
              ),

              SizedBox(height: spacing),

              // Watch Health Cards — Ojas, Nadi, Sleep, Body Signals
              if (watchHealth != null && watchHealth.hasData) ...[
                // Ojas vitality gauge (hero card from watch)
                if (watchHealth.ojasScore != null) ...[
                  OjasScoreCard(data: watchHealth, isDark: isDark),
                  SizedBox(height: spacing),
                ],

                // Nadi pulse reading (dosha from HRV)
                if (watchHealth.nadiDosha != null || watchHealth.hrv != null) ...[
                  WatchNadiCard(data: watchHealth, isDark: isDark),
                  SizedBox(height: spacing),
                ],

                // Sleep breakdown
                if (watchHealth.sleepHours != null) ...[
                  SleepSummaryCard(
                    data: watchHealth,
                    isDark: isDark,
                  ),
                  SizedBox(height: spacing),
                ],

                // All body signals — 2-column grid of minimal tiles
                BodySignalsGrid(
                  data: watchHealth,
                  isDark: isDark,
                  trends: trends,
                ),
                SizedBox(height: spacing),
              ],

              // Card 2: Core Constitution (Prakriti) - permanent profile
              PrakritiHeroCard(
                prakriti: prakriti,
                isRefined: profile.prakritiRefined,
                onRefine: _openPrakritiRefinement,
                onInfo: () => _showAyurvedaInfoDialog(
                  title: 'Core Constitution (Prakriti)',
                  message:
                      'Prakriti is your unique mind-body constitution determined at birth.\n\n'
                      'It represents your natural balance of the three doshas:\n'
                      '• Vata (Air + Space) - Movement, creativity\n'
                      '• Pitta (Fire + Water) - Transformation, intellect\n'
                      '• Kapha (Earth + Water) - Structure, stability\n\n'
                      'Unlike Vikriti, your Prakriti doesn\'t change - it\'s your baseline for life.',
                ),
                isDark: isDark,
              ),

              SizedBox(height: spacing),

              // Card 4: Static Tips (Collapsible - fallback/reference)
              CollapsibleRecommendationsCard(
                dominantDosha: prakriti.dominant,
                recommendations:
                    _ayurvedaService.getRecommendations(prakriti.dominant),
                vulnerabilities: profile.healthVulnerabilities,
                isDark: isDark,
              ),

              const SizedBox(height: 160), // Bottom padding
            ],
          ),
        );
      },
    );
  }

  void _openPrakritiRefinement() {
    if (_profile?.prakriti == null) return;

    HapticFeedback.lightImpact();
    context.push(
      RouteNames.prakritiRefinement,
      extra: {
        'predictedPrakriti': _profile!.prakriti!,
      },
    );
  }
}
