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
import 'package:aurogram/features/baba/domain/baba_context.dart';
import 'package:aurogram/features/baba/domain/baba_tool_registry.dart';
import 'package:aurogram/features/onboarding/domain/baba_onboarding_tools.dart';
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
    _bindAdvanceTool();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rotateController.dispose();
    _fadeController.dispose();
    _messageTimer?.cancel();
    // Release the advance tool so it falls back to its "not on reveal" default.
    BabaToolRegistry.instance.unbindHandler(BabaOnboardingTools.advanceOnboarding);
    // Stop feeding Baba this screen's content (the call itself keeps going;
    // ambient location tracking continues via the router).
    BabaContext.instance.clearDetail();
    super.dispose();
  }

  /// Announce this reveal step to Baba through the shared context spine so he
  /// can narrate it. If a call is live he reacts now; if one starts here he
  /// picks it up on connect. (Where the user is is already tracked for free.)
  void _narrateScreen(String detail) {
    BabaContext.instance.publish(detail, speak: true);
  }

  /// Compact account fact for reveal cues: guest vs secured. Behaviour (the
  /// login nudge) is the playbook's job; we only report the state.
  String _accountFact() {
    final user = FirebaseAuth.instance.currentUser;
    return (user == null || user.isAnonymous) ? 'guest' : 'secured';
  }

  /// Trim a reading to a cue-sized snippet. The full reading is on screen for
  /// the user to read; Baba only needs enough to narrate faithfully without
  /// blowing the CX input token budget (whole call must stay under limit).
  String _cueText(String? content, {int max = 300}) {
    final t = (content ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();
    if (t.isEmpty) return '(still being written — say it is loading)';
    return t.length <= max ? t : '${t.substring(0, max)}…';
  }

  /// Let Baba drive the reveal flow hands-free: bind [advanceOnboarding] to the
  /// same transitions the on-screen Continue button triggers, gated by the
  /// exact same readiness checks so he can never skip a still-loading step.
  void _bindAdvanceTool() {
    BabaToolRegistry.instance.bindHandler(
      BabaOnboardingTools.advanceOnboarding,
      (args) async => _babaAdvanceOnboarding(),
    );
  }

  Future<Map<String, dynamic>> _babaAdvanceOnboarding() async {
    if (!mounted) {
      return {'ok': false, 'advanced': false, 'reason': 'screen gone'};
    }
    switch (_phase) {
      case OnboardingPhase.signReveal:
        if (_signRevealStep >= 3) {
          _goToReadingPhase(viaVoiceResult: true);
          // Hand Baba the ACTUAL birth-reading text in the tool result he is
          // responding to - not a separate screen-context message he ignores.
          // This is why the reading was never spoken: the model reacts to the
          // tool result (which had no story), so the story must live HERE.
          return {
            'ok': true,
            'advanced': true,
            'now': 'birthReading',
            'narrate': _cueText(_firstReadingContent, max: 600),
          };
        }
        return {
          'ok': false,
          'advanced': false,
          'reason': 'the sun/moon/rising cards are still revealing',
        };
      case OnboardingPhase.birthReading:
        final ready =
            !_isGeneratingReading && (_firstReadingContent?.isNotEmpty ?? false);
        if (ready) {
          _goToCurrentTimesPhase(viaVoiceResult: true);
          return {
            'ok': true,
            'advanced': true,
            'now': 'currentTimes',
            'narrate': _cueText(_currentTimesReadingContent, max: 600),
          };
        }
        return {
          'ok': false,
          'advanced': false,
          'reason': 'their birth reading is still being written',
        };
      case OnboardingPhase.currentTimes:
        final ready = !_isGeneratingCurrentTimesReading &&
            (_currentTimesReadingContent?.isNotEmpty ?? false);
        if (ready) {
          _finishOnboarding(viaVoiceResult: true);
          return {
            'ok': true,
            'advanced': true,
            'now': 'home',
            'narrate': 'They are now on the home dashboard. Warmly say you have '
                'brought them here and give a one-line tour of what lives here '
                '(their daily sky/nakshatra wheel, upcoming events, and that '
                'their daily insight lives here).',
          };
        }
        return {
          'ok': false,
          'advanced': false,
          'reason': 'their current-times reading is still being written',
        };
      default:
        return {
          'ok': false,
          'advanced': false,
          'reason': 'nothing to advance from here',
        };
    }
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
      // Tell Baba the calculation did NOT complete, so he says it's taking
      // longer / didn't go through and offers a retry - instead of filling the
      // silence with invented signs (he has NO chart data at this point).
      _narrateScreen(
        '[REVEAL] step=failed; reason=calculation_timeout; account=${_accountFact()}. '
        'The chart did NOT finish calculating - no signs are available. '
        'Do NOT state any sign or placement.',
      );
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

    // All three placements are on screen — feed Baba the FACTS (reveal step +
    // real placements). HOW he reacts (congratulate, insight, advance, nudge)
    // is owned by the CX playbook.
    final p = _profile;
    if (p != null) {
      _narrateScreen(
        '[REVEAL] step=signReveal; account=${_accountFact()}; '
        'sun=${p.sunSign ?? 'unknown'}; moon=${p.moonSign ?? 'unknown'}; '
        'rising=${p.ascendant ?? 'unknown'}.',
      );
    }
  }

  /// Advance to the birth-reading phase.
  ///
  /// [viaVoiceResult] = triggered by Baba's advanceOnboarding tool, which
  /// ALREADY returns the reading text in its result for him to narrate - so we
  /// SKIP the screen-context publish to avoid sending the same reading twice on
  /// two channels (the model acts on the tool result and ignores publish). The
  /// on-screen Continue button path leaves it false, so publish IS the channel
  /// that reaches him then (no tool result exists).
  void _goToReadingPhase({bool viaVoiceResult = false}) {
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
    // Pre-warm the NEXT reading now so its text is ready to hand back in the
    // advanceOnboarding result when Baba moves on (otherwise current-times
    // would still be loading at the moment he needs to narrate it).
    pollForCurrentTimesReading();
    if (!viaVoiceResult) {
      _narrateScreen(
        '[REVEAL] step=birthReading; account=${_accountFact()}. '
        'Their birth reading is now on screen; narrate FROM this text, do not '
        'invent: "${_cueText(_firstReadingContent)}"',
      );
    }
  }

  void _goToCurrentTimesPhase({bool viaVoiceResult = false}) {
    if (!mounted) return;
    setState(() {
      _phase = OnboardingPhase.currentTimes;
      final hasContent = _currentTimesReadingContent != null &&
          _currentTimesReadingContent!.isNotEmpty;
      _isGeneratingCurrentTimesReading = !hasContent;
    });
    pollForCurrentTimesReading();

    // Facts only: the current-times reading is up, plus whether they're still a
    // guest. The playbook owns the behaviour (orient them, then — if guest —
    // the benefits-led login nudge; else advance to home when ready).
    if (!viaVoiceResult) {
      _narrateScreen(
        '[REVEAL] step=currentTimes; account=${_accountFact()}. '
        'Final reveal step; their current-times reading is on screen. Narrate '
        'FROM this text, do not invent: "${_cueText(_currentTimesReadingContent)}"',
      );
    }
  }

    /// Ends the reading flow. First-time users land straight on the home
  /// dashboard (tab 0); the update flow simply pops back to its caller.
  void _finishOnboarding({bool viaVoiceResult = false}) {
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    if (widget.isUpdate) {
      Navigator.of(context).pop();
      Navigator.of(context).pop(true);
      return;
    }
    navigateToHome(targetTab: 0);
    // Tell Baba he has landed on the dashboard so he announces it and gives a
    // short tour - instead of falling silent and making the user ask.
    if (!viaVoiceResult) {
      _narrateScreen(
        '[REVEAL] step=home; account=${_accountFact()}. '
        'Onboarding is complete and the user is now on the home dashboard. '
        'Warmly say you have brought them here and give a one-line tour.',
      );
    }
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
