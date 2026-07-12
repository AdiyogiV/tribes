import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:aurogram/shared/services/share/share_service.dart';
import 'package:aurogram/shared/models/astrology_profile.dart';
import 'package:aurogram/core/logging/app_logger.dart';
import 'package:aurogram/features/onboarding/domain/onboarding_constants.dart';
import 'package:aurogram/features/onboarding/presentation/mixins/data_polling_mixin.dart';
import 'package:aurogram/features/onboarding/presentation/mixins/navigation_mixin.dart';
import 'package:aurogram/features/onboarding/presentation/widgets/onboarding_progress_sidebar.dart';
import 'package:aurogram/features/onboarding/presentation/widgets/star_field_painter.dart';
import 'package:aurogram/features/onboarding/presentation/steps/loading_phase.dart';
import 'package:aurogram/features/onboarding/presentation/steps/sign_reveal_phase.dart';
import 'package:aurogram/features/onboarding/presentation/steps/reading_phases.dart';
import 'package:aurogram/features/onboarding/presentation/steps/path_choice_phase.dart';
import 'package:aurogram/features/astrology/domain/sky_positions_service.dart';
import 'package:aurogram/shared/presentation/responsive/responsive.dart';

/// Beautiful multi-phase onboarding experience
/// User controls navigation with explicit Continue buttons
///
/// For updates (isUpdate=true): Shows card reveal then returns
/// For new setup (isUpdate=false): Full flow with reading and choice
class OnboardingComplete extends StatefulWidget {
  final bool hasBirthDetails;
  final bool
      isUpdate; // True when user is updating birth details (not first-time setup)

  const OnboardingComplete({
    super.key,
    required this.hasBirthDetails,
    this.isUpdate = false,
  });

  @override
  State<OnboardingComplete> createState() => _OnboardingCompleteState();
}

class _OnboardingCompleteState extends State<OnboardingComplete>
    with
        TickerProviderStateMixin,
        DataPollingMixin<OnboardingComplete>,
        NavigationMixin<OnboardingComplete> {
  // Animation controllers
  late AnimationController _pulseController;
  late AnimationController _rotateController;
  late AnimationController _fadeController;

  // State
  int _phase = OnboardingPhase.loading;
  int _signRevealStep = 0; // 0=none, 1=sun, 2=moon, 3=rising
  bool _isNavigating = false;
  String _loadingMessage = 'Reading the stars...';
  Timer? _messageTimer;

  // Data
  AstrologyProfile? _profile;
  String? _firstReadingContent;
  bool _isGeneratingReading = false;
  String? _currentTimesReadingContent;
  bool _isGeneratingCurrentTimesReading = false;
  Map<String, double>? _planetPositions;

  // Loading messages
  final List<String> _loadingMessages = [
    'Reading the stars...',
    'Calculating planetary positions...',
    'Mapping your cosmic blueprint...',
    'Discovering your unique gifts...',
  ];

  // ---- DataPollingMixin bridge ----
  @override
  AstrologyProfile? get pollingProfile => _profile;
  @override
  set pollingProfile(AstrologyProfile? v) => _profile = v;

  @override
  String? get pollingFirstReadingContent => _firstReadingContent;
  @override
  set pollingFirstReadingContent(String? v) => _firstReadingContent = v;

  @override
  bool get pollingIsGeneratingReading => _isGeneratingReading;
  @override
  set pollingIsGeneratingReading(bool v) => _isGeneratingReading = v;

  @override
  String? get pollingCurrentTimesReadingContent => _currentTimesReadingContent;
  @override
  set pollingCurrentTimesReadingContent(String? v) =>
      _currentTimesReadingContent = v;

  @override
  bool get pollingIsGeneratingCurrentTimesReading =>
      _isGeneratingCurrentTimesReading;
  @override
  set pollingIsGeneratingCurrentTimesReading(bool v) =>
      _isGeneratingCurrentTimesReading = v;

  // ---- NavigationMixin bridge ----
  @override
  bool get navIsNavigating => _isNavigating;
  @override
  set navIsNavigating(bool v) => _isNavigating = v;

  @override
  bool get navIsUpdate => widget.isUpdate;

  // ===========================================================================
  // Lifecycle
  // ===========================================================================

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _loadSkyPositions();
    _startJourney();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rotateController.dispose();
    _fadeController.dispose();
    _messageTimer?.cancel();
    super.dispose();
  }

  // ===========================================================================
  // Initialisation helpers
  // ===========================================================================

  Future<void> _loadSkyPositions() async {
    try {
      final skyService = SkyPositionsService();
      await skyService.fetchPositions();
      final positions = skyService.getPositionsForDate(DateTime.now());
      if (positions != null && mounted) {
        final planetLongs = <String, double>{};
        positions.forEach((planet, data) {
          if (data is Map && data['longitude'] != null) {
            planetLongs[planet] = (data['longitude'] as num).toDouble();
          }
        });
        if (planetLongs.isNotEmpty) {
          setState(() => _planetPositions = planetLongs);
        }
      }
    } catch (e) {
      // Silently fail - wheel will work without planet positions
    }
  }

  void _initAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    )..repeat(reverse: true);

    _rotateController = AnimationController(
      duration: const Duration(seconds: 25),
      vsync: this,
    )..repeat();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    )..forward();

    int msgIndex = 0;
    _messageTimer =
        Timer.periodic(AnimationTiming.loadingMessageCycle, (timer) {
      if (mounted && _phase == OnboardingPhase.loading) {
        setState(() {
          msgIndex = (msgIndex + 1) % _loadingMessages.length;
          _loadingMessage = _loadingMessages[msgIndex];
        });
      }
    });
  }

  // ===========================================================================
  // Phase orchestration
  // ===========================================================================

  void _startJourney() async {
    if (!widget.hasBirthDetails) {
      setState(() => _phase = OnboardingPhase.skip);
      return;
    }

    await waitForAstroData();

    if (_profile == null) {
      AppLogger.w('No profile found after waiting - showing retry/skip option',
          category: LogCategory.general);
      if (mounted) {
        setState(() => _phase = OnboardingPhase.retry);
      }
      return;
    }

    // Brief delay so Firestore write has propagated before backend reads it.
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;

    triggerDailyInsightInBackground();
    // Pre-warm first reading as soon as astro profile is ready so it is
    // likely available before the user reaches the birth-reading phase.
    pollForFirstReading();
    _showSignsPhase();
  }

  void _showSignsPhase() async {
    if (!mounted) return;
    setState(() => _phase = OnboardingPhase.signReveal);

    await Future.delayed(AnimationTiming.initialRevealDelay);

    for (int step = 1; step <= 3; step++) {
      if (!mounted) return;
      HapticFeedback.lightImpact();
      setState(() => _signRevealStep = step);
      if (step < 3) await Future.delayed(AnimationTiming.cardRevealDelay);
    }
  }

  void _goToReadingPhase() {
    if (!mounted) return;
    final hasReading =
        _firstReadingContent != null && _firstReadingContent!.isNotEmpty;
    if (!hasReading) {
      // Safety net: ensure polling is active even if a phase transition path skipped it.
      pollForFirstReading();
    }
    AppLogger.i('Moving to reading phase. Has reading: $hasReading',
        category: LogCategory.general);
    setState(() {
      _phase = OnboardingPhase.birthReading;
      _isGeneratingReading = !hasReading;
    });
  }

  void _goToCurrentTimesPhase() {
    if (!mounted) return;
    setState(() {
      _phase = OnboardingPhase.currentTimes;
      final hasContent = _currentTimesReadingContent != null &&
          _currentTimesReadingContent!.isNotEmpty;
      _isGeneratingCurrentTimesReading = !hasContent;
    });
    pollForCurrentTimesReading();
  }

    /// Ends the reading flow. First-time users land straight on the home
  /// dashboard (tab 0); the update flow simply pops back to its caller.
  void _finishOnboarding() {
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    if (widget.isUpdate) {
      Navigator.of(context).pop();
      Navigator.of(context).pop(true);
      return;
    }
    navigateToHome(targetTab: 0);
  }

  void _retryAstroLoad() async {
    if (!mounted) return;
    setState(() => _phase = OnboardingPhase.loading);
    await waitForAstroData();
    if (_profile != null) {
      triggerDailyInsightInBackground();
      pollForFirstReading();
      _showSignsPhase();
    } else {
      AppLogger.w('Retry failed - navigating to profile',
          category: LogCategory.general);
      navigateToHome(targetTab: 4);
    }
  }

  // ===========================================================================
  // Build
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    VoidCallback? continueAction;
    bool canContinue = false;

    switch (_phase) {
      case OnboardingPhase.signReveal:
        if (_signRevealStep >= 3) {
          canContinue = true;
          continueAction = _goToReadingPhase;
        }
        break;
      case OnboardingPhase.birthReading:
        if (!_isGeneratingReading &&
            _firstReadingContent != null &&
            _firstReadingContent!.isNotEmpty) {
          canContinue = true;
          continueAction = _goToCurrentTimesPhase;
        }
        break;
      case OnboardingPhase.currentTimes:
                if (!_isGeneratingCurrentTimesReading &&
            _currentTimesReadingContent != null &&
            _currentTimesReadingContent!.isNotEmpty) {
          canContinue = true;
          continueAction = _finishOnboarding;
        }
        break;
    }

    return Shortcuts(
      shortcuts: {
        if (canContinue && continueAction != null)
          LogicalKeySet(LogicalKeyboardKey.enter):
              EnterIntent(continueAction),
      },
      child: Actions(
        actions: {
          EnterIntent: CallbackAction<EnterIntent>(
            onInvoke: (intent) {
              HapticFeedback.lightImpact();
              intent.onTap();
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            body: ResponsiveBuilder(
              builder: (context, isMobile, isTablet, isDesktop) {
                final isWideScreen = isTablet || isDesktop;

                if (isWideScreen) {
                  return Row(
                    children: [
                      OnboardingProgressSidebar(
                        currentPhase: _phase,
                        signRevealStep: _signRevealStep,
                        hasReading: _firstReadingContent != null &&
                            _firstReadingContent!.isNotEmpty,
                        isGeneratingReading: _isGeneratingReading,
                        hasCurrentTimesReading:
                            _currentTimesReadingContent != null &&
                                _currentTimesReadingContent!.isNotEmpty,
                        isGeneratingCurrentTimesReading:
                            _isGeneratingCurrentTimesReading,
                      ),
                      Expanded(
                        child: Stack(
                          children: [
                            if (widget.hasBirthDetails)
                              Positioned.fill(
                                child: AnimatedStarField(
                                  rotationAnimation: _rotateController,
                                  alphaMultiplier: _phase >= 2 ? 0.15 : 0.1,
                                ),
                              ),
                            SafeArea(
                              child: FadeTransition(
                                opacity: CurvedAnimation(
                                  parent: _fadeController,
                                  curve: Curves.easeOut,
                                ),
                                child: _buildPhaseContent(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }

                return Stack(
                  children: [
                    if (widget.hasBirthDetails)
                      Positioned.fill(
                        child: AnimatedStarField(
                          rotationAnimation: _rotateController,
                          alphaMultiplier: _phase >= 2 ? 0.15 : 0.1,
                        ),
                      ),
                    FadeTransition(
                      opacity: CurvedAnimation(
                        parent: _fadeController,
                        curve: Curves.easeOut,
                      ),
                      child: _buildPhaseContent(),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhaseContent() {
    switch (_phase) {
      case OnboardingPhase.loading:
        return LoadingPhase(
          loadingMessage: _loadingMessage,
          planetPositions: _planetPositions,
        );
      case OnboardingPhase.signReveal:
        if (_profile == null) {
          return LoadingPhase(
            loadingMessage: _loadingMessage,
            planetPositions: _planetPositions,
          );
        }
        return SignRevealPhase(
          profile: _profile!,
          signRevealStep: _signRevealStep,
          onContinue: _goToReadingPhase,
          onShare: () {
            final p = _profile!;
            final user = FirebaseAuth.instance.currentUser;
            ShareService.showCosmicCardPreview(
              context: context,
              userId: user?.uid ?? '',
              userName: user?.displayName,
              sunSign: p.sunSign ?? '',
              moonSign: p.moonSign ?? '',
              risingSign: p.ascendant ?? '',
            );
          },
        );
      case OnboardingPhase.birthReading:
        return BirthReadingPhase(
          readingContent: _firstReadingContent,
          isGenerating: _isGeneratingReading,
          onContinue: _goToCurrentTimesPhase,
        );
      case OnboardingPhase.currentTimes:
        return CurrentTimesReadingPhase(
          readingContent: _currentTimesReadingContent,
          isGenerating: _isGeneratingCurrentTimesReading,
          onContinue: _finishOnboarding,
        );
      case OnboardingPhase.skip:
        return SkipPhase(
          onChat: () => navigateToHome(targetTab: 0),
          onAddBirthDetails: () => navigateToHome(targetTab: 4),
        );
      case OnboardingPhase.retry:
        return RetryPhase(
          onRetry: _retryAstroLoad,
          onGoToProfile: () => navigateToHome(targetTab: 4),
          onExplore: () => navigateToHome(targetTab: 0),
        );
      default:
        return LoadingPhase(
          loadingMessage: _loadingMessage,
          planetPositions: _planetPositions,
        );
    }
  }
}
