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
import 'package:aurogram/features/baba/domain/baba_snapshot.dart';
import 'package:aurogram/features/baba/domain/baba_tool_registry.dart';
import 'package:aurogram/features/baba/domain/baba_tool_result.dart';
import 'package:aurogram/features/baba/voice/voice_session_controller.dart';
import 'package:aurogram/features/onboarding/domain/baba_onboarding_tools.dart';
import 'package:aurogram/features/onboarding/domain/onboarding_reveal_workflow.dart';
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
        NavigationMixin<OnboardingComplete>,
        BabaScreenAware<OnboardingComplete> {
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
  Map<String, double>? _planetPositions;

  late final OnboardingRevealWorkflow _voiceWorkflow;
  StreamSubscription<String>? _presentationReceiptSub;

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
    _voiceWorkflow = OnboardingRevealWorkflow(phase: 'loading');
    _presentationReceiptSub = VoiceSessionController()
        .presentationCompleted
        .listen(_onPresentationCompleted);
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
    unawaited(_presentationReceiptSub?.cancel());
    // Release the advance tool so it falls back to its "not on reveal" default.
    BabaToolRegistry.instance
        .unbindHandler(BabaOnboardingTools.advanceOnboarding);
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

  // ===========================================================================
  // Baba awareness — the reveal is now a first-class, step-aware screen. Baba
  // PERCEIVES this live snapshot (via whereAmI and on every tool result) and
  // narrates FROM it, so his voice can never describe a step the UI has moved
  // past. This is the perceive half of the loop; _babaAdvanceOnboarding is the
  // act half — both read the exact same state.
  // ===========================================================================

  @override
  String get babaScreenKey => 'onboardingReveal';

  @override
  BabaSnapshot babaSnapshot() {
    final account = _accountFact();
    switch (_phase) {
      case OnboardingPhase.loading:
        return const BabaSnapshot.loading(
          headline: 'Reading the stars and calculating their birth chart',
          step: 'loading',
          blockedReason: 'the chart is still being calculated',
        );
      case OnboardingPhase.signReveal:
        final p = _profile;
        if (p == null) {
          return const BabaSnapshot.loading(
            headline: 'Calculating their birth chart',
            step: 'signReveal',
            blockedReason: 'the chart is still being calculated',
          );
        }
        final revealed = _signRevealStep >= 3;
        return BabaSnapshot.ready(
          headline: revealed
              ? 'Their Sun, Moon and Rising signs are all revealed on screen'
              : 'Revealing their Sun, Moon and Rising signs one by one',
          step: 'signReveal',
          facts: {
            'account': account,
            'sun': p.sunSign ?? 'unknown',
            'moon': p.moonSign ?? 'unknown',
            'rising': p.ascendant ?? 'unknown',
            'cardsRevealed': _signRevealStep,
            'workflow': _voiceWorkflow.snapshot(),
          },
          canProceed: revealed,
          blockedReason:
              revealed ? null : 'the sun/moon/rising cards are still revealing',
          availableActions: revealed ? const ['advanceOnboarding'] : const [],
        );
      case OnboardingPhase.reading:
        final ready = !_isGeneratingReading &&
            (_firstReadingContent?.isNotEmpty ?? false);
        final workflow = _voiceWorkflow.snapshot();
        final presentationComplete =
            workflow['presentationState'] == 'completed';
        return BabaSnapshot(
          status: ready ? BabaScreenStatus.ready : BabaScreenStatus.loading,
          step: 'reading',
          headline: ready
              ? 'Their reading is on screen (the final reveal step)'
              : 'Their reading is still being written',
          facts: {
            'account': account,
            if (ready) 'reading': _cueText(_firstReadingContent, max: 600),
            'uiReady': ready,
            'workflow': workflow,
          },
          canProceed: ready && presentationComplete,
          blockedReason: !ready
              ? 'their reading is still being written'
              : !presentationComplete
                  ? 'their reading is still being presented'
                  : null,
          availableActions: ready && presentationComplete
              ? const ['advanceOnboarding']
              : const [],
        );
      case OnboardingPhase.retry:
        return const BabaSnapshot.error(
          headline:
              'The chart did not finish calculating — no signs are available',
          step: 'failed',
          blockedReason:
              'the birth chart calculation timed out; do NOT state any sign or placement',
        );
      case OnboardingPhase.skip:
        return const BabaSnapshot.empty(
          headline: 'No birth details yet — offering to add them or explore',
          step: 'skip',
        );
      default:
        return const BabaSnapshot.loading(
            headline: 'Preparing the reveal', step: 'loading');
    }
  }

  /// Let Baba drive the reveal flow hands-free: bind [advanceOnboarding] to the
  /// same transitions the on-screen Continue button triggers, gated by the
  /// exact same readiness checks so he can never skip a still-loading step.
  void _bindAdvanceTool() {
    BabaToolRegistry.instance.bindHandler(
      BabaOnboardingTools.advanceOnboarding,
      _babaAdvanceOnboarding,
    );
  }

  void _onPresentationCompleted(String presentationId) {
    if (!_voiceWorkflow.completePresentation(presentationId)) return;
    BabaContext.instance.markStateChanged('onboardingReveal');
    AppLogger.i('Onboarding narration receipt accepted',
        category: LogCategory.voice,
        data: {
          'presentationId': presentationId,
          'phase': _voiceWorkflow.phase,
          'version': _voiceWorkflow.version,
        });
  }

  /// Baba's "advance the reveal" action. Honest and state-driven:
  ///
  ///   * On a successful advance it returns a `narrate` field carrying the
  ///     text Baba must SPEAK for the step just entered (the reading, or a
  ///     home-tour instruction). This is
  ///     deliberate: the model acts on the RESULT's own fields and treats the
  ///     appended `state` as background, so narration MUST live in the result
  ///     or Baba says nothing and just advances again ~1/sec (the runaway
  ///     reveal loop). Kept in sync with the skip-publish in
  ///     [_goToReadingPhase] (viaVoiceResult:true),
  ///     which rely on this result being the narration channel.
  ///   * It refuses (blocked, without moving the UI) while he is still
  ///     PRESENTING this step (isNarrating) or the step isn't ready. This is
  ///     the root fix for "UI ahead of voice": advancing can no longer outrun
  ///     his own sentence. He finishes, then advances — still the driver, just
  ///     no longer blind to his own voice.
  Future<Map<String, dynamic>> _babaAdvanceOnboarding(
      Map<String, dynamic> args) async {
    if (!mounted) {
      return const BabaToolResult.failed(reason: 'screen_gone').toJson();
    }
    final requestId = args['requestId'];
    final fromPhase = args['fromPhase'];
    // `fromVersion` is advisory only (the workflow gates on phase, which moves
    // in lockstep with version). Accept a missing/any value so a model that
    // echoes a stale version can still advance instead of looping on a
    // stale_transition_token rejection. Fall back to the live version.
    final rawFromVersion = args['fromVersion'];
    final fromVersion =
        rawFromVersion is int ? rawFromVersion : _voiceWorkflow.version;
    if (requestId is! String || requestId.isEmpty || fromPhase is! String) {
      return BabaToolResult.rejected(
        reason: 'missing_transition_token',
        data: {'workflow': _voiceWorkflow.snapshot()},
      ).toJson();
    }

    late final String nextPhase;
    late final bool uiReady;
    late final String blockedReason;
    late final String narration;
    late final VoidCallback applyUi;
    switch (_phase) {
      case OnboardingPhase.signReveal:
        nextPhase = 'reading';
        uiReady = _signRevealStep >= 3;
        blockedReason = 'sign_cards_still_revealing';
        narration = _cueText(_firstReadingContent, max: 600);
        applyUi = () => _goToReadingPhase(viaVoiceResult: true);
        break;
      case OnboardingPhase.reading:
        nextPhase = 'home';
        uiReady = !_isGeneratingReading &&
            (_firstReadingContent?.isNotEmpty ?? false);
        blockedReason = 'reading_still_loading';
        narration = 'Welcome them into their Aurogram home, point out the '
            'daily sky wheel, and invite them to open today\'s Daily Insight.';
        applyUi = () => _finishOnboarding(viaVoiceResult: true);
        break;
      default:
        return BabaToolResult.rejected(
          reason: 'intent_not_available',
          data: {'workflow': _voiceWorkflow.snapshot()},
        ).toJson();
    }

    final presentationId =
        'onboarding:$nextPhase:${_voiceWorkflow.version + 1}:$requestId';
    final result = _voiceWorkflow.continueTo(
      requestId: requestId,
      fromPhase: fromPhase,
      fromVersion: fromVersion,
      nextPhase: nextPhase,
      uiReady: uiReady,
      blockedReason: blockedReason,
      presentationId: presentationId,
      narration: narration,
      acknowledgedPresentationId: args['acknowledgedPresentationId'] as String?,
    );
    if (result.status == BabaToolStatus.applied) applyUi();
    return result.toJson();
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
    _voiceWorkflow.synchronizeManualPhase('signReveal');

    await Future.delayed(AnimationTiming.initialRevealDelay);

    for (int step = 1; step <= 3; step++) {
      if (!mounted) return;
      HapticFeedback.lightImpact();
      setState(() => _signRevealStep = step);
      // Signal the World Model that a sub-step moved so Baba's awareness (and,
      // on Live, a silent delta) tracks each card as it lands.
      BabaContext.instance.markStateChanged('onboardingReveal');
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
      _phase = OnboardingPhase.reading;
      _isGeneratingReading = !hasReading;
    });
    _voiceWorkflow.synchronizeManualPhase('reading');
    if (!viaVoiceResult) {
      _narrateScreen(
        '[REVEAL] step=reading; account=${_accountFact()}. '
        'Their reading is now on screen; narrate FROM this text, do not '
        'invent: "${_cueText(_firstReadingContent)}"',
      );
    }
  }

  /// Ends the reading flow. First-time users land straight on the home
  /// dashboard (tab 0); the update flow simply pops back to its caller.
  void _finishOnboarding({bool viaVoiceResult = false}) {
    if (!mounted) return;
    _voiceWorkflow.synchronizeManualPhase('home');
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
      case OnboardingPhase.reading:
        if (!_isGeneratingReading &&
            _firstReadingContent != null &&
            _firstReadingContent!.isNotEmpty) {
          canContinue = true;
          continueAction = _finishOnboarding;
        }
        break;
    }

    return Shortcuts(
      shortcuts: {
        if (canContinue && continueAction != null)
          LogicalKeySet(LogicalKeyboardKey.enter): EnterIntent(continueAction),
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
      case OnboardingPhase.reading:
        return ReadingPhase(
          readingContent: _firstReadingContent,
          isGenerating: _isGeneratingReading,
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
