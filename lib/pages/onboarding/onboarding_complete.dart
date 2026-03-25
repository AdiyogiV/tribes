import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:aurogram/services/auth_service.dart';
import 'package:aurogram/services/astrology_service.dart';
import 'package:aurogram/services/notification_service.dart';
import 'package:aurogram/models/astrology_profile.dart';
import 'package:aurogram/utils/logging/app_logger.dart';
import 'package:aurogram/pages/astrology/daily_insight_page.dart';
import 'package:aurogram/pages/astrology/astrology_details_page.dart';
import 'package:aurogram/pages/ayurveda/ayurveda_details_page.dart';
import 'package:aurogram/widgets/universal/transparent_toolbox.dart';
import 'package:aurogram/services/onboarding_service.dart';
import 'package:aurogram/services/share_service.dart';
import 'package:aurogram/services/ayurveda_service.dart';
import 'package:aurogram/models/ayurveda_profile.dart';
import 'package:aurogram/pages/onboarding/widgets/onboarding_dialogs.dart';
import 'package:aurogram/pages/onboarding/widgets/onboarding_progress_sidebar.dart';
import 'package:aurogram/pages/onboarding/widgets/star_field_painter.dart';
import 'package:aurogram/pages/onboarding/widgets/zodiac_wheel_painter.dart';
import 'package:aurogram/services/sky_positions_service.dart';
import 'package:aurogram/utils/responsive.dart';
import 'package:aurogram/utils/chat/markdown_utils.dart';

// Intent class for Enter key handling
class _EnterIntent extends Intent {
  final VoidCallback onTap;
  const _EnterIntent(this.onTap);
}

// ============================================================================
// ANIMATION TIMING CONSTANTS
// Centralized for consistency and easy tuning
// ============================================================================
class _AnimationTiming {
  static const cardRevealDelay = Duration(milliseconds: 600);
  static const initialRevealDelay = Duration(milliseconds: 400);
  static const loadingMessageCycle = Duration(seconds: 2);
  static const pollingInterval = Duration(seconds: 2);
  static const maxPollingWait = Duration(seconds: 60);
  // Increased wait time - backend sync can take 10-20 seconds
  static const maxAstroWait = Duration(seconds: 25);
  static const astroRetryInterval = Duration(milliseconds: 800);
}

// ============================================================================
// ONBOARDING PHASE CONSTANTS (sequential: main flow 0-5, alternate 6-7)
// ============================================================================
class _OnboardingPhase {
  static const int loading = 0;
  static const int signReveal = 1;
  static const int ayurveda = 2;
  static const int birthReading = 3;
  static const int currentTimes = 4;
  static const int pathChoice = 5;
  static const int skip = 6;
  static const int retry = 7;
}

// ============================================================================
// THEME COLORS - Aligned with AppTheme farm aesthetic
// ============================================================================
class _OnboardingColors {
  // Primary accents - using app theme colors
  static Color get primary => AppTheme.primaryColor;
  static const Color sunGold = Color(0xFFF5C542);
  static const Color moonPurple = Color(0xFF8B5CF6);
  static const Color risingGreen = Color(0xFF10B981);
  static const Color warmAmber = Color(0xFFE6A23C);

  // Soft backgrounds for cards
  static Color textPrimary(BuildContext context) => AppTheme.textColor;
  static Color textSecondary(BuildContext context) =>
      AppTheme.textSecondaryColor;
}

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
    with TickerProviderStateMixin {
  // Animation controllers
  late AnimationController _pulseController;
  late AnimationController _rotateController;
  late AnimationController _fadeController;

  // State
  int _phase = _OnboardingPhase
      .loading; // 0=loading, 1=signs, 2=ayurveda, 3=birth, 4=current times, 5=path, 6=skip, 7=retry
  int _signRevealStep = 0; // 0=none, 1=sun, 2=moon, 3=rising
  int _highlightRevealStep = 0; // 0=none, then 1, 2, 3...
  int _ayurvedaRevealStep = 0; // 0=none, then 1, 2, 3
  bool _isNavigating = false;
  String _loadingMessage = 'Reading the stars...';
  Timer? _messageTimer;

  // Data
  AstrologyProfile? _profile;
  AyurvedaProfile? _ayurvedaProfile;
  List<Map<String, dynamic>> _highlights = [];
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

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _loadSkyPositions();
    _startJourney();
  }

  /// Load current sky positions for the zodiac wheel background
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

    // Cycle loading messages
    int msgIndex = 0;
    _messageTimer =
        Timer.periodic(_AnimationTiming.loadingMessageCycle, (timer) {
      if (mounted && _phase == _OnboardingPhase.loading) {
        setState(() {
          msgIndex = (msgIndex + 1) % _loadingMessages.length;
          _loadingMessage = _loadingMessages[msgIndex];
        });
      }
    });
  }

  void _startJourney() async {
    if (!widget.hasBirthDetails) {
      // Skip flow - show skip phase
      setState(() => _phase = _OnboardingPhase.skip);
      return;
    }

    // Wait for astro data (backend sync to complete)
    await _waitForAstroData();

    if (_profile == null) {
      AppLogger.w('No profile found after waiting - showing retry/skip option',
          category: LogCategory.general);
      // Instead of navigating away, show a helpful message with options
      if (mounted) {
        setState(() => _phase = _OnboardingPhase.retry);
      }
      return;
    }

    // Brief delay so Firestore write (astrologyData) has propagated before backend reads it.
    // Without this, generateInsightForCurrentUser can fail with "Complete astrology setup first".
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;

    // Trigger daily insight generation in background (separate Cloud Function call)
    // This runs while user views animations, so insight is ready by the time they need it
    _triggerDailyInsightInBackground();

    // Move to signs phase and reveal them
    _showSignsPhase();
  }

  /// Triggers daily insight generation as a separate Cloud Function call.
  /// Runs asynchronously - does not block the onboarding flow.
  /// By making this a separate function call, Cloud Functions won't deprioritize it.
  void _triggerDailyInsightInBackground() {
    final astroService = AstrologyService();
    AppLogger.i('🔮 Triggering daily insight generation (background)',
        category: LogCategory.network);

    // Fire-and-forget from frontend perspective - but it's a separate Cloud Function
    // invocation, so it runs independently and won't be deprioritized
    astroService.generateDailyInsight(forceRegenerate: false).then((result) {
      AppLogger.i('✅ Daily insight generated', category: LogCategory.network);
    }).catchError((e) {
      AppLogger.w('Daily insight generation failed: $e',
          category: LogCategory.network);
    });
  }

  Future<void> _waitForAstroData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      AppLogger.w('No uid for astro data wait', category: LogCategory.general);
      return;
    }

    final astroService = AstrologyService();
    final startTime = DateTime.now();
    int pollCount = 0;

    AppLogger.i('Starting astro data poll for uid: $uid',
        category: LogCategory.general);

    while (
        DateTime.now().difference(startTime) < _AnimationTiming.maxAstroWait) {
      pollCount++;
      try {
        // Always force refresh to get latest from Firestore
        final profile = await astroService.getProfile(uid, forceRefresh: true);

        if (profile != null) {
          // Check if profile has calculated signs (backend sync complete)
          if (profile.sunSign != null && profile.moonSign != null) {
            _profile = profile;
            AppLogger.i(
                '✅ Profile loaded after $pollCount polls: ${profile.sunSign}/${profile.moonSign}/${profile.ascendant}',
                category: LogCategory.general);
            return;
          } else if (pollCount % 5 == 0) {
            // Log progress every 5 polls
            AppLogger.d(
                'Poll #$pollCount: Profile exists but waiting for calculated signs (syncStatus: ${profile.syncStatus})',
                category: LogCategory.general);
          }
        } else if (pollCount % 5 == 0) {
          AppLogger.d('Poll #$pollCount: No profile yet, waiting...',
              category: LogCategory.general);
        }
      } catch (e) {
        AppLogger.w('Profile fetch error (poll #$pollCount): $e',
            category: LogCategory.general);
      }

      if (!mounted) return;
      await Future.delayed(_AnimationTiming.astroRetryInterval);
    }

    AppLogger.w(
        'Astro data timeout after $pollCount polls (${_AnimationTiming.maxAstroWait.inSeconds}s)',
        category: LogCategory.general);
  }

  void _showSignsPhase() async {
    if (!mounted) return;
    setState(() => _phase = _OnboardingPhase.signReveal);

    await Future.delayed(_AnimationTiming.initialRevealDelay);

    // Reveal signs one by one: Sun → Moon → Rising
    for (int step = 1; step <= 3; step++) {
      if (!mounted) return;
      HapticFeedback.lightImpact();
      setState(() => _signRevealStep = step);
      if (step < 3) await Future.delayed(_AnimationTiming.cardRevealDelay);
    }
  }

  void _goToHighlightsPhase() async {
    if (!mounted || _profile == null) return;

    // Build highlights from profile
    _highlights = _buildHighlights(_profile!);

    // Start polling for first reading (for both new setup and updates)
    _pollForFirstReading();

    // Trigger Ayurveda calculation in background
    _triggerAyurvedaCalculationInBackground();

    // TODO: Temporarily disabled - skip cosmic gifts page for now
    // Keep the code below commented for easy re-enabling later
    // if (_highlights.isEmpty) {
    //   // Skip to Ayurveda if no highlights
    //   _goToAyurvedaPhase();
    //   return;
    // }

    // Always skip to Ayurveda (cosmic gifts page disabled)
    _goToAyurvedaPhase();
    return;

    // Disabled code - cosmic gifts reveal phase
    // setState(() => _phase = 2);
    // await Future.delayed(_AnimationTiming.phaseTransitionDelay);

    // // Reveal each highlight one by one
    // for (int i = 0; i < _highlights.length; i++) {
    //   if (!mounted) return;
    //   HapticFeedback.selectionClick();
    //   setState(() => _highlightRevealStep = i + 1);
    //   await Future.delayed(_AnimationTiming.highlightRevealDelay);
    // }
  }

  /// Triggers Ayurveda calculation asynchronously
  void _triggerAyurvedaCalculationInBackground() {
    final ayurvedaService = AyurvedaService();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    AppLogger.i('🔮 Triggering Ayurveda calculation (background)',
        category: LogCategory.network);

    // Check if profile already exists
    ayurvedaService.getProfile(uid, forceRefresh: true).then((existingProfile) {
      if (existingProfile != null && mounted) {
        setState(() => _ayurvedaProfile = existingProfile);
        AppLogger.i('✅ Ayurveda profile already exists',
            category: LogCategory.network);
      } else {
        // Calculate new profile
        ayurvedaService.calculateProfile().then((newProfile) {
          if (mounted && newProfile != null) {
            setState(() => _ayurvedaProfile = newProfile);
            AppLogger.i('✅ Ayurveda profile calculated',
                category: LogCategory.network);
          }
        }).catchError((e) {
          AppLogger.w('Ayurveda calculation failed: $e',
              category: LogCategory.network);
        });
      }
    }).catchError((e) {
      AppLogger.w('Ayurveda profile fetch failed: $e',
          category: LogCategory.network);
    });
  }

  /// Wait for Ayurveda data to be ready
  Future<void> _waitForAyurvedaData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final ayurvedaService = AyurvedaService();
    final startTime = DateTime.now();
    int pollCount = 0;
    const maxWait = Duration(seconds: 15); // Shorter wait for Ayurveda

    AppLogger.i('Starting Ayurveda data poll for uid: $uid',
        category: LogCategory.general);

    while (DateTime.now().difference(startTime) < maxWait) {
      pollCount++;
      try {
        final profile =
            await ayurvedaService.getProfile(uid, forceRefresh: true);

        if (profile != null && profile.prakriti != null) {
          _ayurvedaProfile = profile;
          AppLogger.i('✅ Ayurveda profile loaded after $pollCount polls',
              category: LogCategory.general);
          return;
        } else if (pollCount % 3 == 0) {
          AppLogger.d('Poll #$pollCount: Waiting for Ayurveda profile...',
              category: LogCategory.general);
        }
      } catch (e) {
        AppLogger.w('Ayurveda profile fetch error (poll #$pollCount): $e',
            category: LogCategory.general);
      }

      if (!mounted) return;
      await Future.delayed(_AnimationTiming.astroRetryInterval);
    }

    AppLogger.w('Ayurveda data timeout after $pollCount polls',
        category: LogCategory.general);
  }

  void _goToAyurvedaPhase() async {
    if (!mounted || _profile == null) {
      // Skip to reading if no profile
      _goToReadingPhase();
      return;
    }

    // Wait for Ayurveda data (with timeout)
    await _waitForAyurvedaData();

    // If no Ayurveda profile after waiting, skip to reading
    if (_ayurvedaProfile == null || _ayurvedaProfile!.prakriti == null) {
      AppLogger.i('No Ayurveda profile - skipping to reading phase',
          category: LogCategory.general);
      _goToReadingPhase();
      return;
    }

    // Calculate Vikriti if not already available
    if (_ayurvedaProfile!.vikriti == null && _profile != null) {
      try {
        final ayurvedaService = AyurvedaService();
        final vikriti = await ayurvedaService.calculateVikriti(
          profile: _ayurvedaProfile!,
          astroProfile: _profile!,
        );
        if (mounted && vikriti != null) {
          // Update the profile with vikriti (local state for reveal)
          final updatedProfile = AyurvedaProfile(
            prakriti: _ayurvedaProfile!.prakriti,
            prakritiRefined: _ayurvedaProfile!.prakritiRefined,
            questionsAnswered: _ayurvedaProfile!.questionsAnswered,
            physicalProfile: _ayurvedaProfile!.physicalProfile,
            agniType: _ayurvedaProfile!.agniType,
            manasPrakriti: _ayurvedaProfile!.manasPrakriti,
            healthVulnerabilities: _ayurvedaProfile!.healthVulnerabilities,
            vikriti: vikriti,
            checkInHistory: _ayurvedaProfile!.checkInHistory,
            lastSymptoms: _ayurvedaProfile!.lastSymptoms,
            lastCheckIn: _ayurvedaProfile!.lastCheckIn,
            calculatedAt: _ayurvedaProfile!.calculatedAt,
            version: _ayurvedaProfile!.version,
          );
          setState(() => _ayurvedaProfile = updatedProfile);

          // Persist vikriti so profile card shows "Today's Balance" without opening Ayurveda page
          try {
            await ayurvedaService.saveVikriti(vikriti);
          } catch (saveErr) {
            AppLogger.w(
                'Failed to save Vikriti to Firestore during onboarding: $saveErr',
                category: LogCategory.general);
          }
        }
      } catch (e) {
        AppLogger.w('Failed to calculate Vikriti during onboarding: $e',
            category: LogCategory.general);
      }
    }

    setState(() => _phase = _OnboardingPhase.ayurveda);

    await Future.delayed(_AnimationTiming.initialRevealDelay);

    // Reveal Ayurveda cards one by one (2-3 cards: Constitution, Dosha percentages, Vikriti if available)
    final hasVikriti = _ayurvedaProfile?.vikriti != null;
    final maxSteps = hasVikriti ? 3 : 2;

    for (int step = 1; step <= maxSteps; step++) {
      if (!mounted) return;
      HapticFeedback.lightImpact();
      setState(() => _ayurvedaRevealStep = step);
      if (step < maxSteps)
        await Future.delayed(_AnimationTiming.cardRevealDelay);
    }
  }

  void _goToReadingPhase() {
    if (!mounted) return;
    final hasReading =
        _firstReadingContent != null && _firstReadingContent!.isNotEmpty;
    AppLogger.i('Moving to reading phase. Has reading: $hasReading',
        category: LogCategory.general);
    setState(() {
      _phase = _OnboardingPhase.birthReading;
      _isGeneratingReading = !hasReading;
    });
  }

  void _goToPathChoice() {
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    setState(() => _phase = _OnboardingPhase.pathChoice);
  }

  List<Map<String, dynamic>> _buildHighlights(AstrologyProfile profile) {
    final highlights = <Map<String, dynamic>>[];

    // 1. Raj Yoga (if present) - most special
    if (profile.rajYogas != null && profile.rajYogas!.isNotEmpty) {
      final yoga = profile.rajYogas!.first;
      final yogaName = yoga['name'] ?? yoga['yoga'] ?? 'Raj Yoga';
      final yogaDesc = yoga['description'] ??
          yoga['meaning'] ??
          'A powerful combination bringing success and prosperity';
      highlights.add({
        'type': 'yoga',
        'icon': Icons.auto_awesome_rounded,
        'title': yogaName,
        'subtitle': 'Special Blessing in Your Chart',
        'description': yogaDesc,
        'color': const Color(0xFFF59E0B),
      });
    }

    // 2. Current Dasha - always relevant
    if (profile.currentDasha != null) {
      final dasha = profile.currentDasha!;
      final mahaDasha = dasha['mahadasha'] ?? dasha['maha_dasha'] ?? '';
      final antarDasha = dasha['antardasha'] ?? dasha['antar_dasha'] ?? '';

      if (mahaDasha.toString().isNotEmpty) {
        final desc = _getDashaDescription(mahaDasha.toString());
        final periodInfo = _getDashaPeriodInfo(dasha);
        highlights.add({
          'type': 'dasha',
          'icon': Icons.blur_circular_rounded,
          'title': '$mahaDasha Mahadasha',
          'subtitle': antarDasha.toString().isNotEmpty
              ? 'Currently in $antarDasha phase'
              : 'Your Current Life Chapter',
          'description': '$desc${periodInfo.isNotEmpty ? '\n$periodInfo' : ''}',
          'color': const Color(0xFF8B5CF6),
        });
      }
    }

    // 3. Nakshatra - personal identity
    final nakshatra = profile.moonNakshatra ?? profile.nakshatra;
    if (nakshatra != null && nakshatra.isNotEmpty) {
      final info = _getNakshatraInfo(nakshatra);
      highlights.add({
        'type': 'nakshatra',
        'icon': Icons.nights_stay_rounded,
        'title': nakshatra,
        'subtitle': info['title'] ?? 'Moon Nakshatra',
        'description': info['description'] ??
            'Your lunar mansion reveals your soul\'s nature',
        'color': const Color(0xFF10B981),
      });
    }

    return highlights.take(3).toList();
  }

  String _getDashaDescription(String dasha) {
    const descriptions = {
      'Sun':
          'A time of increased confidence, leadership opportunities, and self-discovery.',
      'Moon':
          'An emotionally rich period bringing deeper connections and intuition.',
      'Mars':
          'An energetic phase for taking action and pursuing your ambitions.',
      'Mercury':
          'A period favoring learning, communication, and intellectual growth.',
      'Jupiter': 'A blessed time of expansion, wisdom, and good fortune.',
      'Venus':
          'A beautiful period for love, creativity, and enjoying life\'s pleasures.',
      'Saturn':
          'A time for building lasting foundations through discipline and patience.',
      'Rahu':
          'A transformative period of worldly ambitions and unconventional paths.',
      'Ketu': 'A spiritual phase of letting go and inner growth.',
    };
    return descriptions[dasha] ??
        'A significant planetary period shaping your journey.';
  }

  String _getDashaPeriodInfo(Map<String, dynamic> dasha) {
    try {
      final levels = dasha['levels'] as Map<String, dynamic>?;
      if (levels != null && levels['maha'] != null) {
        final mahaEnd = levels['maha']['end'];
        if (mahaEnd != null) {
          final endDate = DateTime.parse(mahaEnd.toString());
          final years = endDate.difference(DateTime.now()).inDays ~/ 365;
          if (years > 0) {
            return '~$years years remaining in this phase';
          }
        }
      }
    } catch (_) {}
    return '';
  }

  Map<String, String> _getNakshatraInfo(String nakshatra) {
    const info = {
      'Ashwini': {
        'title': 'The Star of Transport',
        'description':
            'Swift healers with pioneering spirit. You have natural ability to initiate and heal.'
      },
      'Bharani': {
        'title': 'The Star of Restraint',
        'description':
            'Creative transformers with deep intensity. You understand life\'s cycles deeply.'
      },
      'Krittika': {
        'title': 'The Star of Fire',
        'description':
            'Sharp, purifying presence with strong determination. You cut through illusion.'
      },
      'Rohini': {
        'title': 'The Star of Ascent',
        'description':
            'Naturally creative and magnetic. Beauty and growth follow wherever you go.'
      },
      'Mrigashira': {
        'title': 'The Searching Star',
        'description':
            'Curious seekers with gentle nature. Your quest for truth leads to wisdom.'
      },
      'Ardra': {
        'title': 'The Storm Star',
        'description':
            'Transformative intellect with emotional depth. You bring necessary change.'
      },
      'Punarvasu': {
        'title': 'The Star of Renewal',
        'description':
            'Optimistic nurturers with wisdom. You have the gift of starting fresh.'
      },
      'Pushya': {
        'title': 'The Nourishing Star',
        'description':
            'Deeply caring and spiritual. Your support helps others flourish.'
      },
      'Ashlesha': {
        'title': 'The Embracing Star',
        'description':
            'Intuitive and mysterious. You understand hidden truths others miss.'
      },
      'Magha': {
        'title': 'The Royal Star',
        'description':
            'Natural authority and ancestral connection. Leadership comes naturally.'
      },
      'Purva Phalguni': {
        'title': 'The Star of Fortune',
        'description':
            'Creative and romantic soul. You bring joy and beauty to life.'
      },
      'Uttara Phalguni': {
        'title': 'The Star of Patronage',
        'description':
            'Generous helper who creates prosperity. Others trust you deeply.'
      },
      'Hasta': {
        'title': 'The Hand Star',
        'description':
            'Skillful creator with clever mind. Your hands bring ideas to life.'
      },
      'Chitra': {
        'title': 'The Bright Star',
        'description':
            'Brilliant visionary with artistic gifts. You see beauty in possibility.'
      },
      'Swati': {
        'title': 'The Self-Going Star',
        'description':
            'Independent and balanced. You find your own path with grace.'
      },
      'Vishakha': {
        'title': 'The Star of Purpose',
        'description':
            'Determined achiever with clear goals. Your focus brings success.'
      },
      'Anuradha': {
        'title': 'The Star of Success',
        'description':
            'Devoted friend who achieves goals. Loyalty and success define you.'
      },
      'Jyeshtha': {
        'title': 'The Elder Star',
        'description':
            'Protective wisdom with natural authority. You guide and protect others.'
      },
      'Mula': {
        'title': 'The Root Star',
        'description':
            'Deep investigator who transforms. You get to the root of everything.'
      },
      'Purva Ashadha': {
        'title': 'The Invincible Star',
        'description':
            'Confident warrior who purifies. Victory follows your convictions.'
      },
      'Uttara Ashadha': {
        'title': 'The Universal Star',
        'description':
            'Principled leader who endures. Your integrity wins lasting respect.'
      },
      'Shravana': {
        'title': 'The Star of Learning',
        'description':
            'Wise listener who connects. Knowledge flows to you naturally.'
      },
      'Dhanishtha': {
        'title': 'The Star of Symphony',
        'description':
            'Rhythmic and prosperous. You create harmony in all you do.'
      },
      'Shatabhisha': {
        'title': 'The Hundred Healers',
        'description':
            'Mysterious healer with independence. You solve what others cannot.'
      },
      'Purva Bhadrapada': {
        'title': 'The Burning Pair',
        'description':
            'Intense spiritual warrior. Your passion transforms everything.'
      },
      'Uttara Bhadrapada': {
        'title': 'The Warrior Star',
        'description':
            'Deep wisdom with self-control. Inner strength is your power.'
      },
      'Revati': {
        'title': 'The Wealthy Star',
        'description':
            'Nurturing and prosperous soul. You guide others to safe harbor.'
      },
    };
    return info[nakshatra] ??
        {
          'title': 'Moon Nakshatra',
          'description':
              'Your lunar mansion reveals your soul\'s unique gifts and nature.'
        };
  }

  String _getPlacementMeaning(String type) {
    switch (type) {
      case 'rising':
        return 'Your outer mask';
      case 'sun':
        return 'Your core identity';
      case 'moon':
        return 'Your emotional self';
      default:
        return '';
    }
  }

  List<String> _getSignTraits(String? sign) {
    if (sign == null) return [];

    final traits = {
      'Aries': ['Bold', 'Pioneering', 'Courageous'],
      'Taurus': ['Grounded', 'Stable', 'Patient'],
      'Gemini': ['Curious', 'Adaptable', 'Witty'],
      'Cancer': ['Nurturing', 'Intuitive', 'Protective'],
      'Leo': ['Creative', 'Confident', 'Warm'],
      'Virgo': ['Analytical', 'Practical', 'Thoughtful'],
      'Libra': ['Harmonious', 'Diplomatic', 'Graceful'],
      'Scorpio': ['Intense', 'Transformative', 'Magnetic'],
      'Sagittarius': ['Adventurous', 'Optimistic', 'Free'],
      'Capricorn': ['Ambitious', 'Disciplined', 'Capable'],
      'Aquarius': ['Innovative', 'Unique', 'Independent'],
      'Pisces': ['Compassionate', 'Dreamy', 'Empathic'],
    };

    return traits[sign] ?? [];
  }

  String _getSignDescription(String? sign, String type) {
    if (sign == null) return '';

    final descriptions = {
      'Aries': {
        'sun':
            'You\'re the one who starts things when everyone else is still talking. Your confidence isn\'t arrogance—it\'s knowing you can handle whatever comes next.',
        'moon':
            'Your feelings hit like a lightning strike. You don\'t do subtle emotions, and honestly? That\'s refreshing. Most people wish they could feel this clearly.',
        'rising':
            'People notice you the second you walk in. You don\'t have to try—your energy just fills the room. Some find it intense, others find it magnetic.'
      },
      'Taurus': {
        'sun':
            'You build things that last. While others chase trends, you create foundations. Your patience is strategic wisdom most people don\'t have.',
        'moon':
            'You know exactly what you need to feel good. Cozy spaces, good food, beautiful things—these are necessities, not luxuries. Smart move.',
        'rising':
            'You seem calm, but you\'re actually incredibly strong. People underestimate you because you don\'t need to prove anything. That\'s your superpower.'
      },
      'Gemini': {
        'sun':
            'You see connections others miss. Your mind works like a web—everything links to everything else. It\'s why conversations with you are never boring.',
        'moon':
            'You feel everything at once, which is why labels feel wrong. You\'re not indecisive—you\'re too complex for simple categories. That\'s actually cool.',
        'rising':
            'People can\'t figure you out, and that\'s intentional. You have layers, and you reveal them selectively. It keeps things interesting.'
      },
      'Cancer': {
        'sun':
            'You read people like books. Your intuition picks up on things others miss completely. It\'s not magic—you just pay attention to what really matters.',
        'moon':
            'Home isn\'t just a place for you—it\'s a feeling. You create spaces where people can actually relax and be themselves. That\'s rare.',
        'rising':
            'People open up to you without meaning to. Your energy says "safe space" before you even speak. You make vulnerability feel normal.'
      },
      'Leo': {
        'sun':
            'You don\'t just want attention—you deserve it. Your light is real, and when you shine, you help others find their own. That\'s leadership.',
        'moon':
            'You feel things BIG. Your emotions aren\'t performances—they\'re just too real to hide. Most people wish they could express themselves this freely.',
        'rising':
            'You walk into rooms and they get brighter. Your confidence isn\'t fake—it\'s earned. People are drawn to that kind of authenticity.'
      },
      'Virgo': {
        'sun':
            'You notice what others ignore. That detail everyone missed? You saw it. Your precision is excellence, not nitpicking. Big difference.',
        'moon':
            'You overthink because you care. Your brain doesn\'t shut off because there\'s always something to improve. That\'s dedication, not anxiety.',
        'rising':
            'People come to you when things need fixing. You don\'t just see problems—you see solutions. Your practicality is actually a gift.'
      },
      'Libra': {
        'sun':
            'You see all sides because you actually listen. Your diplomacy is emotional intelligence most people don\'t have. That\'s powerful.',
        'moon':
            'You struggle with decisions because you see infinite possibilities. It\'s not indecision—every choice matters to you. That\'s thoughtful.',
        'rising':
            'You make everything look easy. Your grace isn\'t fake—it\'s just how you move through the world. People notice, even if you don\'t realize it.'
      },
      'Scorpio': {
        'sun':
            'You transform everything you touch. Your intensity isn\'t too much—it\'s exactly what\'s needed. You don\'t do surface level, and that\'s rare.',
        'moon':
            'You feel things most people can\'t handle. Your emotional depth creates connections that last forever. Shallow people can\'t keep up—their loss.',
        'rising':
            'People are drawn to your mystery. You don\'t reveal everything, and that makes you magnetic. Your depth is obvious even when you\'re quiet.'
      },
      'Sagittarius': {
        'sun':
            'You say what others won\'t. Your honesty might sting sometimes, but it\'s always real. People respect that, even when it\'s uncomfortable.',
        'moon':
            'You need space to breathe. Commitment feels like a cage because you\'re meant to explore. Your freedom is growth, not running away.',
        'rising':
            'Your optimism is contagious. You see possibilities where others see problems. That\'s choosing hope, not denial. And it works.'
      },
      'Capricorn': {
        'sun':
            'You build things that outlast you. Your ambition is legacy-building. You think in generations, not moments. That\'s rare.',
        'moon':
            'You control your emotions because feelings can wait. Your discipline is focus—you get things done while others are still feeling.',
        'rising':
            'People see your success, but miss your process. Your drive inspires others to work harder. You show what\'s possible with dedication.'
      },
      'Aquarius': {
        'sun':
            'You think in the future while others are stuck in now. Your ideas seem weird because they\'re ahead of their time. History will prove you right.',
        'moon':
            'You process feelings through ideas because emotions are overwhelming. Your distance protects your brilliant mind. It\'s survival, not coldness.',
        'rising':
            'You\'re weird, and you know it. Your uniqueness makes some uncomfortable, but the right people find it magnetic. You attract your tribe.'
      },
      'Pisces': {
        'sun':
            'You dream so others don\'t have to. Your imagination creates possibilities that inspire change. Reality needs people like you to see beyond it.',
        'moon':
            'You feel everything, and it\'s exhausting. Your empathy connects you to energies others miss. It\'s a gift, even when it feels like a burden.',
        'rising':
            'You seem gentle, but you\'re actually incredibly strong. Your sensitivity is emotional intelligence most people don\'t understand. That\'s their loss.'
      },
    };

    return descriptions[sign]?[type] ?? '';
  }

  /// Polls Firestore for the first reading content.
  /// Backend generates this automatically after basic sync completes.
  /// Falls back to manually triggering generation if not found after initial polls.
  void _pollForFirstReading() async {
    AppLogger.i('Polling for first reading from Firestore...',
        category: LogCategory.general);

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      AppLogger.w('No uid for first reading poll',
          category: LogCategory.general);
      return;
    }

    final startTime = DateTime.now();
    int pollCount = 0;
    bool hasTriggeredGeneration = false;

    while (DateTime.now().difference(startTime) <
            _AnimationTiming.maxPollingWait &&
        _firstReadingContent == null &&
        mounted) {
      pollCount++;
      try {
        final doc =
            await FirebaseFirestore.instance.collection('users').doc(uid).get();

        if (doc.exists) {
          final data = doc.data();
          final astroData = data?['astrologyData'] as Map<String, dynamic>?;
          final firstReading =
              astroData?['firstReading'] as Map<String, dynamic>?;
          final content = firstReading?['content']?.toString();

          if (content != null && content.isNotEmpty) {
            AppLogger.i('✅ First reading found! Poll #$pollCount',
                category: LogCategory.general);

            if (mounted) {
              setState(() {
                _firstReadingContent = content;
                _isGeneratingReading = false;
              });
            }
            return;
          } else {
            // If we've polled a few times and still no reading, try triggering generation
            if (!hasTriggeredGeneration && pollCount >= 3) {
              hasTriggeredGeneration = true;
              AppLogger.i(
                  'No reading found after $pollCount polls, triggering generation...',
                  category: LogCategory.general);

              // Trigger generation in background (don't await - continue polling)
              final astroService = AstrologyService();
              astroService.generateFirstReading().then((success) {
                if (success) {
                  AppLogger.i('First reading generation triggered successfully',
                      category: LogCategory.general);
                } else {
                  AppLogger.w('First reading generation trigger failed',
                      category: LogCategory.general);
                }
              }).catchError((e) {
                AppLogger.w('Error triggering first reading generation: $e',
                    category: LogCategory.general);
              });
            } else if (pollCount % 5 == 0) {
              AppLogger.d('Poll #$pollCount: Waiting for first reading...',
                  category: LogCategory.general);
            }
          }
        }
      } catch (e) {
        AppLogger.w('First reading poll error: $e',
            category: LogCategory.general);
      }

      await Future.delayed(_AnimationTiming.pollingInterval);
    }

    AppLogger.w('First reading timeout after $pollCount polls',
        category: LogCategory.general);

    // If we still don't have a reading and haven't triggered generation, try one more time
    if (_firstReadingContent == null && !hasTriggeredGeneration && mounted) {
      AppLogger.i('Attempting final trigger of first reading generation',
          category: LogCategory.general);
      final astroService = AstrologyService();
      astroService.generateFirstReading().then((success) {
        if (success && mounted) {
          // Give it a moment then check one more time
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted) {
              _checkForFirstReadingOnce();
            }
          });
        }
      });
    }
  }

  /// Check for first reading once (used as final fallback)
  void _checkForFirstReadingOnce() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || _firstReadingContent != null) return;

    try {
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists) {
        final data = doc.data();
        final astroData = data?['astrologyData'] as Map<String, dynamic>?;
        final firstReading =
            astroData?['firstReading'] as Map<String, dynamic>?;
        final content = firstReading?['content']?.toString();

        if (content != null && content.isNotEmpty && mounted) {
          AppLogger.i('✅ First reading found in final check!',
              category: LogCategory.general);
          setState(() {
            _firstReadingContent = content;
            _isGeneratingReading = false;
          });
        }
      }
    } catch (e) {
      AppLogger.w('Final first reading check error: $e',
          category: LogCategory.general);
    }
  }

  /// Poll for current times reading (stored in user doc or subcollection).
  /// Triggers generation via service if not found after initial polls.
  void _pollForCurrentTimesReading() async {
    AppLogger.i('Polling for current times reading...',
        category: LogCategory.general);

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      AppLogger.w('No uid for current times reading poll',
          category: LogCategory.general);
      return;
    }

    final startTime = DateTime.now();
    int pollCount = 0;
    bool hasTriggeredGeneration = false;

    while (DateTime.now().difference(startTime) <
            _AnimationTiming.maxPollingWait &&
        _currentTimesReadingContent == null &&
        mounted) {
      pollCount++;
      try {
        final content = await AstrologyService().getCurrentTimesReading(uid);
        if (content != null && content.isNotEmpty) {
          AppLogger.i('✅ Current times reading found! Poll #$pollCount',
              category: LogCategory.general);
          if (mounted) {
            setState(() {
              _currentTimesReadingContent = content;
              _isGeneratingCurrentTimesReading = false;
            });
          }
          return;
        }

        if (!hasTriggeredGeneration && pollCount >= 2) {
          hasTriggeredGeneration = true;
          AppLogger.i('Triggering current times reading generation...',
              category: LogCategory.general);
          AstrologyService().generateCurrentTimesReading().then((success) {
            if (success) {
              AppLogger.i('Current times reading generation triggered',
                  category: LogCategory.general);
            }
          }).catchError((e) {
            AppLogger.w('Current times reading trigger failed: $e',
                category: LogCategory.general);
          });
        }
      } catch (e) {
        AppLogger.w('Current times reading poll error: $e',
            category: LogCategory.general);
      }

      await Future.delayed(_AnimationTiming.pollingInterval);
    }

    if (mounted && _currentTimesReadingContent == null) {
      setState(() => _isGeneratingCurrentTimesReading = false);
    }
  }

  void _navigateToHome({int targetTab = 4}) async {
    if (_isNavigating || !mounted) return;
    _isNavigating = true;

    HapticFeedback.mediumImpact();

    // CRITICAL: Mark FTUE as shown BEFORE navigating
    // This ensures TabHandler won't show FTUE page again when rebuilding
    await OnboardingService().markFtueShown();

    if (!mounted) return;

    final authService = context.read<AuthService>();
    authService.updateStatusBasedOnNewUserFlag(false,
        initialTabIndex: targetTab);
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _navigateToDailyInsight() async {
    if (_isNavigating || !mounted) return;
    _isNavigating = true;

    HapticFeedback.mediumImpact();

    // Trigger lazy sync for full data
    AstrologyService().triggerLazySync(mode: 'standard');

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      _navigateToHome(targetTab: 0);
      return;
    }

    // For updates: pop back then push daily insight
    if (widget.isUpdate) {
      // Pop twice to get back to astro details, then push daily insight
      Navigator.of(context).pop();
      Navigator.of(context).pop(true);
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => DailyInsightPage(uid: uid),
        ),
      );
      return;
    }

    // For new setup: ask for notification permissions
    // This is the perfect moment - user just set up astrology and wants daily insights
    await _showNotificationPermissionPrompt();

    if (!mounted) return;

    // CRITICAL: Mark FTUE as shown BEFORE navigating
    // This ensures TabHandler won't show FTUE page again when rebuilding
    await OnboardingService().markFtueShown();

    if (!mounted) return;

    final authService = context.read<AuthService>();
    authService.updateStatusBasedOnNewUserFlag(false, initialTabIndex: 0);

    // Navigate to home first, then push daily insight page
    Navigator.of(context).popUntil((route) => route.isFirst);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => DailyInsightPage(uid: uid),
      ),
    );
  }

  void _navigateToAstroDetails() async {
    if (_isNavigating || !mounted) return;
    _isNavigating = true;

    HapticFeedback.mediumImpact();

    // Trigger lazy sync for full data (house interpretations etc.)
    AstrologyService().triggerLazySync(mode: 'standard');

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      _navigateToHome(targetTab: 0);
      return;
    }

    // For updates: just pop back to astro details page
    if (widget.isUpdate) {
      // Pop twice: reveal page → setup page → astro details
      Navigator.of(context).pop();
      Navigator.of(context).pop(true);
      return;
    }

    // For new setup: full navigation flow
    // CRITICAL: Mark FTUE as shown BEFORE navigating
    await OnboardingService().markFtueShown();

    if (!mounted) return;

    final authService = context.read<AuthService>();
    authService.updateStatusBasedOnNewUserFlag(false, initialTabIndex: 4);

    // Navigate to home first, then push astro details page
    Navigator.of(context).popUntil((route) => route.isFirst);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AstrologyDetailsPage(uid: uid),
      ),
    );
  }

  void _navigateToAyurveda() async {
    if (_isNavigating || !mounted) return;
    _isNavigating = true;

    HapticFeedback.mediumImpact();

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      _navigateToHome(targetTab: 0);
      return;
    }

    // For updates: just pop back then push ayurveda
    if (widget.isUpdate) {
      Navigator.of(context).pop();
      Navigator.of(context).pop(true);
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => AyurvedaDetailsPage(uid: uid),
        ),
      );
      return;
    }

    // For new setup: full navigation flow
    // CRITICAL: Mark FTUE as shown BEFORE navigating
    await OnboardingService().markFtueShown();

    if (!mounted) return;

    final authService = context.read<AuthService>();
    authService.updateStatusBasedOnNewUserFlag(false, initialTabIndex: 4);

    // Navigate to home first, then push ayurveda details page
    Navigator.of(context).popUntil((route) => route.isFirst);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AyurvedaDetailsPage(uid: uid),
      ),
    );
  }

  /// Show contextual notification permission prompt
  /// Perfect timing: user just set up astrology and is about to view daily insights
  Future<void> _showNotificationPermissionPrompt() async {
    final notificationService = NotificationService();

    // Skip if already have permission or already asked
    if (notificationService.permissionsRequested) return;
    final hasPermission = await notificationService.hasPermission();
    if (hasPermission) return;

    if (!mounted) return;

    // Show a beautiful contextual prompt
    final shouldRequest = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => NotificationPermissionSheet(
        primaryColor: _OnboardingColors.primary,
        isDark: Theme.of(ctx).brightness == Brightness.dark,
      ),
    );

    if (shouldRequest == true) {
      await notificationService.requestPermissions();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rotateController.dispose();
    _fadeController.dispose();
    _messageTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Determine which continue action to trigger based on current phase
    VoidCallback? continueAction;
    bool canContinue = false;

    switch (_phase) {
      case _OnboardingPhase.signReveal:
        if (_signRevealStep >= 3) {
          canContinue = true;
          continueAction = _goToHighlightsPhase;
        }
        break;
      case _OnboardingPhase.ayurveda:
        final hasVikriti = _ayurvedaProfile?.vikriti != null;
        final maxSteps = hasVikriti ? 3 : 2;
        if (_ayurvedaRevealStep >= maxSteps) {
          canContinue = true;
          continueAction = _goToReadingPhase;
        }
        break;
      case _OnboardingPhase.birthReading:
        if (!_isGeneratingReading &&
            _firstReadingContent != null &&
            _firstReadingContent!.isNotEmpty) {
          canContinue = true;
          continueAction = _goToCurrentTimesPhase;
        }
        break;
      case _OnboardingPhase.currentTimes:
        if (!_isGeneratingCurrentTimesReading &&
            _currentTimesReadingContent != null &&
            _currentTimesReadingContent!.isNotEmpty) {
          canContinue = true;
          continueAction = _goToPathChoice;
        }
        break;
    }

    return Shortcuts(
      shortcuts: {
        if (canContinue && continueAction != null)
          LogicalKeySet(LogicalKeyboardKey.enter): _EnterIntent(continueAction),
      },
      child: Actions(
        actions: {
          _EnterIntent: CallbackAction<_EnterIntent>(
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
                      // Progress sidebar
                      OnboardingProgressSidebar(
                        currentPhase: _phase,
                        signRevealStep: _signRevealStep,
                        ayurvedaRevealStep: _ayurvedaRevealStep,
                        hasReading: _firstReadingContent != null &&
                            _firstReadingContent!.isNotEmpty,
                        isGeneratingReading: _isGeneratingReading,
                        hasCurrentTimesReading:
                            _currentTimesReadingContent != null &&
                                _currentTimesReadingContent!.isNotEmpty,
                        isGeneratingCurrentTimesReading:
                            _isGeneratingCurrentTimesReading,
                      ),
                      // Main content
                      Expanded(
                        child: Stack(
                          children: [
                            // Animated star background
                            if (widget.hasBirthDetails)
                              Positioned.fill(
                                child: AnimatedStarField(
                                  rotationAnimation: _rotateController,
                                  alphaMultiplier: _phase >= 2 ? 0.15 : 0.1,
                                ),
                              ),

                            // Main content
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

                // Mobile layout - no sidebar
                return Stack(
                  children: [
                    // Animated star background
                    if (widget.hasBirthDetails)
                      Positioned.fill(
                        child: AnimatedStarField(
                          rotationAnimation: _rotateController,
                          alphaMultiplier: _phase >= 2 ? 0.15 : 0.1,
                        ),
                      ),

                    // Main content
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
      case _OnboardingPhase.loading:
        return _buildLoadingPhase();
      case _OnboardingPhase.signReveal:
        return _buildSignRevealPhase();
      case _OnboardingPhase.ayurveda:
        return _buildAyurvedaRevealPhase();
      case _OnboardingPhase.birthReading:
        return _buildBirthReadingPhase();
      case _OnboardingPhase.currentTimes:
        return _buildCurrentTimesReadingPhase();
      case _OnboardingPhase.pathChoice:
        return _buildPathChoicePhase();
      case _OnboardingPhase.skip:
        return _buildSkipPhase();
      case _OnboardingPhase.retry:
        return _buildRetryPhase();
      default:
        return _buildLoadingPhase();
    }
  }

  Widget _buildLoadingPhase() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Rotating zodiac wheel with icon in center
            LayoutBuilder(
              builder: (context, constraints) {
                // Calculate wheel size based on available space
                final maxSize = constraints.maxWidth < constraints.maxHeight
                    ? constraints.maxWidth
                    : constraints.maxHeight;
                final wheelSize = (maxSize * 0.6).clamp(200.0, 400.0);

                return ZodiacWheelWithIcon(
                  wheelSize: wheelSize,
                  planetPositions: _planetPositions,
                  primaryColor: AppTheme.primaryColor,
                  opacity: 0.4,
                  animate: true,
                );
              },
            ),
            const SizedBox(height: 40),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: Text(
                _loadingMessage,
                key: ValueKey(_loadingMessage),
                style: TextStyle(
                  fontSize: 16,
                  color: _OnboardingColors.textSecondary(context),
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.2,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignRevealPhase() {
    final profile = _profile;
    if (profile == null) return _buildLoadingPhase();

    return ResponsiveBuilder(
      builder: (context, isMobile, isTablet, isDesktop) {
        final isWideScreen = isTablet || isDesktop;

        if (isWideScreen) {
          return _buildSignRevealWideLayout(profile, isDesktop);
        }
        return _buildSignRevealMobileLayout(profile);
      },
    );
  }

  /// Wide screen layout for sign reveal
  Widget _buildSignRevealWideLayout(AstrologyProfile profile, bool isDesktop) {
    return Column(
      children: [
        Expanded(
          child: Scrollbar(
            thumbVisibility: true,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: isDesktop ? 500 : 480),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Clean header
                        Text(
                          'Your Cosmic Blueprint',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'The three pillars of who you are',
                          style: TextStyle(
                            fontSize: 16,
                            color: _OnboardingColors.textSecondary(context),
                          ),
                        ),
                        const SizedBox(height: 32),
                        // Cards stacked vertically (same as mobile)
                        // Rising first - your outer mask
                        _buildSignCard(
                          icon: Icons.arrow_upward_rounded,
                          color: _OnboardingColors.risingGreen,
                          label: 'Rising Sign',
                          value: profile.ascendant ?? '—',
                          description:
                              _getSignDescription(profile.ascendant, 'rising'),
                          revealed: _signRevealStep >= 1,
                          signType: 'rising',
                        ),
                        const SizedBox(height: 16),
                        // Sun second - your core identity
                        _buildSignCard(
                          icon: Icons.wb_sunny_rounded,
                          color: _OnboardingColors.sunGold,
                          label: 'Sun Sign',
                          value: profile.sunSign ?? '—',
                          description:
                              _getSignDescription(profile.sunSign, 'sun'),
                          revealed: _signRevealStep >= 2,
                          signType: 'sun',
                        ),
                        const SizedBox(height: 16),
                        // Moon third - your emotional self
                        _buildSignCard(
                          icon: Icons.nights_stay_rounded,
                          color: _OnboardingColors.moonPurple,
                          label: 'Moon Sign',
                          value: profile.moonSign ?? '—',
                          description:
                              _getSignDescription(profile.moonSign, 'moon'),
                          revealed: _signRevealStep >= 3,
                          signType: 'moon',
                        ),
                        // Tap to read more hint
                        if (_signRevealStep >= 1)
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: Text(
                              'Tap any card to read more',
                              style: TextStyle(
                                fontSize: 12,
                                color: _OnboardingColors.textSecondary(context),
                                fontStyle: FontStyle.italic,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        // Small share link below cards
                        if (_signRevealStep >= 3)
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: _buildShareLink(),
                          ),
                        const SizedBox(height: 32),
                        // Continue button in flow
                        if (_signRevealStep >= 3)
                          _buildContinueButton(
                            label: 'Continue',
                            onTap: _goToHighlightsPhase,
                          ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Mobile layout for sign reveal
  Widget _buildSignRevealMobileLayout(AstrologyProfile profile) {
    return Stack(
      children: [
        // Main scrollable content
        SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(
                  left: 0, right: 0, top: 32, bottom: 120),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Clean header
                  Text(
                    'Your Cosmic Blueprint',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'The three pillars of who you are',
                    style: TextStyle(
                      fontSize: 14,
                      color: _OnboardingColors.textSecondary(context),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Rising first - your outer mask
                  _buildSignCard(
                    icon: Icons.arrow_upward_rounded,
                    color: _OnboardingColors.risingGreen,
                    label: 'Rising Sign',
                    value: profile.ascendant ?? '—',
                    description:
                        _getSignDescription(profile.ascendant, 'rising'),
                    revealed: _signRevealStep >= 1,
                    signType: 'rising',
                  ),
                  // Sun second - your core identity
                  _buildSignCard(
                    icon: Icons.wb_sunny_rounded,
                    color: _OnboardingColors.sunGold,
                    label: 'Sun Sign',
                    value: profile.sunSign ?? '—',
                    description: _getSignDescription(profile.sunSign, 'sun'),
                    revealed: _signRevealStep >= 2,
                    signType: 'sun',
                  ),
                  // Moon third - your emotional self
                  _buildSignCard(
                    icon: Icons.nights_stay_rounded,
                    color: _OnboardingColors.moonPurple,
                    label: 'Moon Sign',
                    value: profile.moonSign ?? '—',
                    description: _getSignDescription(profile.moonSign, 'moon'),
                    revealed: _signRevealStep >= 3,
                    signType: 'moon',
                  ),
                  // Tap to read more hint
                  if (_signRevealStep >= 1)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        'Tap any card to read more',
                        style: TextStyle(
                          fontSize: 11,
                          color: _OnboardingColors.textSecondary(context),
                          fontStyle: FontStyle.italic,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  // Small share link below cards
                  if (_signRevealStep >= 3) _buildShareLink(),
                ],
              ),
            ),
          ),
        ),
        // Continue button positioned at bottom (show when all signs revealed)
        if (_signRevealStep >= 3)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: _buildContinueButton(
                label: 'Continue',
                onTap: _goToHighlightsPhase,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSignCard({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
    required String description,
    required bool revealed,
    required String signType, // 'sun', 'moon', 'rising'
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: revealed ? 1.0 : 0.0),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
      builder: (context, anim, child) {
        final clampedOpacity = anim.clamp(0.0, 1.0);
        return Transform.translate(
          offset: Offset(0, 20 * (1 - anim)),
          child: Opacity(
            opacity: clampedOpacity,
            child: child,
          ),
        );
      },
      // Use TransparentToolbox for consistent styling with the app
      child: GestureDetector(
        onTap: revealed
            ? () => _showSignDetails(
                  icon: icon,
                  color: color,
                  label: label,
                  value: value,
                  description: description,
                  signType: signType,
                )
            : null,
        child: TransparentToolbox(
          height: 130,
          content: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    // Label and Icon - left aligned
                    Row(
                      children: [
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: color,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(icon, color: color, size: 20),
                      ],
                    ),
                    // Placement meaning (explaining phrase) - right aligned
                    if (_getPlacementMeaning(signType).isNotEmpty && revealed)
                      Expanded(
                        child: Text(
                          _getPlacementMeaning(signType),
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: _OnboardingColors.textSecondary(context),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                  ],
                ),
                // Sign name and tags on same line
                if (revealed) ...[
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Sign name - left aligned
                      Text(
                        value,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      // Sign traits (tags) - right aligned
                      if (_getSignTraits(value == '—' ? null : value)
                          .isNotEmpty)
                        Wrap(
                          spacing: 5,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: _getSignTraits(value == '—' ? null : value)
                              .map((trait) => Material(
                                    elevation: 1,
                                    borderRadius: BorderRadius.circular(6),
                                    color: color,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 5, vertical: 1),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        trait,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ))
                              .toList(),
                        ),
                    ],
                  ),
                ],
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: _OnboardingColors.textSecondary(context),
                      height: 1.3,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSignDetails({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
    required String description,
    required String signType,
  }) {
    final expandedContent = _getExpandedSignContent(value, signType);

    CardDetailsDialog.show(
      context,
      icon: icon,
      color: color,
      title: value,
      subtitle: label,
      description: description,
      expandedContent: expandedContent,
    );
  }

  String _getExpandedSignContent(String sign, String type) {
    // Expanded content - natural, conversational, bold, no em dashes, 3-4 paragraphs
    final insights = {
      'Aries': {
        'sun':
            'Most people think you\'re impulsive, but here\'s the thing: you\'re actually strategic as hell. You take risks because playing it safe gets you nowhere.\n\nWhen you charge ahead, you\'re clearing the path for everyone else. People follow you because you go first, and that takes real guts. Your competitive side isn\'t about beating others. It\'s about pushing yourself harder.\n\nYou don\'t wait around for perfect conditions because you know how to create them yourself. That\'s not recklessness. That\'s calculated courage.',
        'moon':
            'You process emotions faster than anyone. While other people need days to figure out their feelings, you do it in hours. Sometimes minutes.\n\nThat\'s because you feel everything so intensely that sitting with it feels impossible. Movement is your therapy. Exercise, action, doing something. That\'s how you work through feelings.\n\nWhen you\'re stuck, your body knows before your mind does. Your anger? That\'s information. Your excitement? That\'s real joy. You don\'t do subtle emotions because life\'s too short for that nonsense.',
        'rising':
            'First impressions are everything and you know it. People feel your energy before they even see you. Some find that intimidating because your confidence is obvious. Others find it magnetic because you\'re not hiding anything.\n\nYou\'ve learned to use your presence as a tool. When you walk into a room, you\'re not trying to dominate. You\'re just being yourself, and that\'s powerful enough.\n\nYour directness isn\'t rudeness. It\'s efficiency. You don\'t waste time on small talk when real connection is possible.',
      },
      'Taurus': {
        'sun':
            'Your relationship with time is different. While everyone else rushes around, you understand that the best things take time. That stubbornness people complain about? That\'s commitment.\n\nWhen you decide something matters, you stick with it. That\'s not inflexibility. That\'s integrity. You build things that last because you think in terms of legacy, not quick wins.\n\nYour patience isn\'t passive waiting. It\'s active. You know when to push and when to let things develop naturally. Quality over quantity isn\'t just a saying for you. It\'s how you live.',
        'moon':
            'Your need for comfort isn\'t weakness. It\'s self awareness. You know exactly what you need to feel good, and you\'re not apologizing for it.\n\nBeautiful spaces, good food, things that feel good. These aren\'t indulgences. They\'re necessities. Your home is your sanctuary, and you\'ve learned that environment affects everything.\n\nWhen you create beauty around you, you\'re not being materialistic. You\'re creating the conditions for your best self. Your relationship with money isn\'t greed. It\'s security. You understand that financial stability creates real freedom.',
        'rising':
            'People underestimate you because you don\'t need to prove anything. Your quiet strength is way more powerful than loud confidence.\n\nYou don\'t need to be the center of attention because you know your worth. Your reliability is a superpower. In a world full of chaos, you\'re the steady one.\n\nPeople trust you because you\'re consistent. Your calm presence makes others feel safe. You don\'t need to be loud to be heard. Your actions speak louder than words.',
      },
      'Gemini': {
        'sun':
            'Your mind doesn\'t work in straight lines. It works in webs. You see connections others miss because you\'re constantly gathering information from everywhere.\n\nThat\'s not scattered thinking. That\'s strategic curiosity. You know the best ideas come from unexpected connections. Your ability to talk about anything isn\'t superficial. It\'s genuine interest.\n\nYou\'re not trying to impress people. You\'re genuinely curious about everything. Your adaptability isn\'t indecision. It\'s intelligence. You can see multiple perspectives because you\'re not attached to one way of thinking.',
        'moon':
            'Your emotions are complex because you feel everything at once. That\'s not indecision. That\'s emotional intelligence.\n\nYou process feelings through talking because that\'s how you understand them. Your need for mental stimulation isn\'t avoidance. It\'s how you process emotions.\n\nWhen you\'re bored, you\'re not just bored. You\'re emotionally unfulfilled. Your quick emotional changes aren\'t instability. They\'re responsiveness. You feel things deeply, but you process them quickly through conversation and thinking.',
        'rising':
            'People can\'t pin you down, and that\'s intentional. You have multiple sides because you\'re genuinely multifaceted.\n\nYour adaptability isn\'t fake. It\'s authentic interest in different perspectives. You can talk to anyone because you\'re genuinely curious about everyone.\n\nYour wit isn\'t just humor. It\'s intelligence expressed playfully. People are drawn to your energy because it\'s dynamic. You don\'t need to choose one version of yourself. You can be all of them.',
      },
      'Cancer': {
        'sun':
            'Your intuition isn\'t guessing. It\'s pattern recognition at a subconscious level. You notice things others miss because you\'re paying attention to what really matters.\n\nYour sensitivity isn\'t weakness. It\'s emotional intelligence. You understand people because you feel what they feel. Your ability to know what someone needs before they ask isn\'t magic. It\'s empathy.\n\nYou navigate relationships with grace because you understand emotional dynamics. Your protective nature isn\'t controlling. It\'s caring.',
        'moon':
            'Home isn\'t a place. It\'s a feeling you create. Your need for security isn\'t neediness. It\'s wisdom.\n\nYou know that everyone needs a safe space, and you\'re good at creating that. When you care for loved ones, you\'re at your best. Your emotional depth helps you nurture others in ways they didn\'t know they needed.\n\nCreating sanctuary is your art form. Your memories aren\'t just nostalgia. They\'re emotional anchors that ground you.',
        'rising':
            'Your energy creates safety. People open up to you because they feel understood. Your warmth isn\'t fake. It\'s genuine care.\n\nYou naturally create environments where vulnerability feels normal. People trust you because you don\'t judge. You just understand.\n\nYour protective nature makes others feel safe to be authentic. You\'re the person people call when they need someone who gets it. Your emotional intelligence is obvious to everyone except you.',
      },
      'Leo': {
        'sun':
            'Your need for recognition isn\'t vanity. It\'s validation that you matter. When you shine, you give others permission to shine too.\n\nYour confidence isn\'t fake. It\'s earned through knowing who you are. You lead through inspiration, not intimidation. Your creativity isn\'t just talent. It\'s expression of your authentic self.\n\nWhen you\'re at your best, everyone around you feels more confident. Your generosity isn\'t performative. It\'s genuine. You want others to succeed because their success doesn\'t diminish yours.',
        'moon':
            'Your emotions are big because you feel everything fully. You don\'t do subtle because that\'s not who you are.\n\nYour need for appreciation isn\'t neediness. It\'s how you feel loved. When you express emotions, it\'s authentic. You don\'t hide feelings like others do.\n\nYour dramatic nature isn\'t attention seeking. It\'s emotional honesty. Most people wish they could express themselves as freely as you do. Your heart is generous, and you deserve recognition for that.',
        'rising':
            'Your presence is magnetic. People are drawn to your warmth and confidence. You don\'t have to try to stand out. You naturally do.\n\nYour optimism is contagious, and people feel better when you\'re around. You command attention without trying because your energy is naturally powerful.\n\nYour charisma isn\'t fake. It\'s authentic confidence. You don\'t need to prove anything. You just need to be yourself, and that\'s enough.',
      },
      'Virgo': {
        'sun':
            'Your attention to detail isn\'t nitpicking. It\'s excellence. You see what can be improved because you know what\'s possible.\n\nYour perfectionism isn\'t a flaw. It\'s high standards. You don\'t settle for good enough because you\'re capable of better. Your analytical mind isn\'t overthinking. It\'s thoroughness.\n\nYou notice what others miss because you pay attention. Your desire to improve things isn\'t criticism. It\'s care. You want things to be the best they can be.',
        'moon':
            'Your anxiety isn\'t weakness. It\'s your brain catching problems before they start. You think things through because you care about getting it right.\n\nYour need to be useful isn\'t low self worth. It\'s how you feel fulfilled. Helping others brings you deep satisfaction. Your analytical approach to emotions isn\'t cold. It\'s how you process them.\n\nYou feel deeply, but you think about those feelings. Your perfectionism in self care isn\'t vanity. It\'s self respect.',
        'rising':
            'People come to you for solutions because you think things through. Your practicality is a gift.\n\nPeople trust your judgment because you\'re thorough. Your thoughtful approach makes others feel understood. You\'re the person people turn to when they need someone who actually knows what they\'re doing.\n\nYour competence is obvious. You don\'t need to prove yourself. Your results speak for themselves.',
      },
      'Libra': {
        'sun':
            'Your need for balance isn\'t indecision. It\'s seeing all perspectives. You understand that most conflicts come from misunderstanding, not malice.\n\nYour diplomacy isn\'t weakness. It\'s emotional intelligence. You can see what everyone needs because you\'re not attached to one side. Your desire for harmony isn\'t avoidance. It\'s creating conditions for everyone to thrive.\n\nYou bring people together because you understand what they need. Your ability to find common ground is powerful.',
        'moon':
            'Your indecisiveness comes from seeing too many good options, not from being weak. Every choice matters to you because you understand the impact.\n\nYour need for partnership isn\'t codependency. It\'s how you discover yourself. You feel most balanced when sharing life with others.\n\nYour struggle with decisions isn\'t a flaw. It\'s thoroughness. You want to make the right choice, and that takes time. Your relationships help you understand yourself better.',
        'rising':
            'Your grace isn\'t fake. It\'s how you move through the world. People notice your charm because it\'s authentic.\n\nYour beauty reflects inner harmony. You put everyone at ease because you understand balance. People see you as the person who brings groups together.\n\nYour presence creates peace. You don\'t need to be loud to be heard. Your energy speaks for itself.',
      },
      'Scorpio': {
        'sun':
            'Your intensity isn\'t too much. It\'s exactly what\'s needed. You don\'t do surface level because depth is where real change happens.\n\nYour power comes from seeing through facades. You know people\'s secrets because you pay attention to what they don\'t say. Your ability to transform things isn\'t destruction. It\'s evolution.\n\nWhen you commit to something, you change it completely. Your intensity makes you unforgettable. You don\'t do casual. Everything matters to you.',
        'moon':
            'Your emotional depth isn\'t a burden. It\'s a gift. You feel things most people can\'t handle because you\'re built for depth.\n\nYour connections last forever because they\'re authentic. You don\'t do shallow relationships because you need real intimacy. Your emotional courage to face hard truths is rare.\n\nShallow people can\'t keep up with your depth, and that\'s their loss. You feel everything intensely because that\'s how you\'re built. Your emotional memory is perfect.',
        'rising':
            'Your mystery isn\'t a game. It\'s protection. You don\'t reveal everything because not everyone deserves access.\n\nYour depth is obvious even when you\'re quiet. You attract those who want real connection, not surface talk. Your mysterious energy is magnetic.\n\nPeople sense your intensity and are either drawn to it or intimidated by it. You don\'t need to explain yourself. Your presence says everything. Your power comes from what you don\'t say.',
      },
      'Sagittarius': {
        'sun':
            'Your honesty isn\'t tactless. It\'s necessary. You say what others won\'t because someone needs to. Your truth telling might sting, but it\'s always real.\n\nPeople respect that, even when it\'s uncomfortable. Your need to explore isn\'t restlessness. It\'s growth. You don\'t do limits because you know life is meant to be lived fully.\n\nYour optimism opens doors others don\'t even see. Your adventurous spirit inspires others to dream bigger. You don\'t do boundaries. You do expansion.',
        'moon':
            'Your need for freedom isn\'t commitment phobia. It\'s emotional necessity. Commitment feels like a cage because you\'re meant to explore.\n\nYour freedom isn\'t running away. It\'s growth. You feel most yourself when learning and expanding horizons. Routine feels like death to you because you need variety.\n\nYour emotional baseline is freedom, and that\'s not negotiable. You process feelings through movement and new experiences. Your restlessness isn\'t a flaw. It\'s how you\'re built.',
        'rising':
            'Your optimism isn\'t denial. It\'s choosing hope. You see possibilities where others see problems.\n\nYour enthusiasm inspires others to believe that life is an adventure. You don\'t do pessimism because you know there\'s always a way forward.\n\nPeople are drawn to your positive energy. Your openness makes others feel free to be themselves. Your energy is contagious. You don\'t need to convince people. Your enthusiasm is enough.',
      },
      'Capricorn': {
        'sun':
            'Your ambition isn\'t cold. It\'s your commitment to creating something lasting. You think in generations, not moments.\n\nWhile others chase quick wins, you build foundations. Your discipline isn\'t repression. It\'s focus. You get things done while others are still talking about it.\n\nYour patience isn\'t passive. It\'s strategic. You know that real success takes time. Your work ethic isn\'t obsession. It\'s dedication. You don\'t do shortcuts because you understand the value of doing things right.',
        'moon':
            'Your emotional control isn\'t repression. It\'s focus. You process feelings through action, not expression.\n\nYour walls aren\'t weakness. They\'re strategic protection. You suppress emotions to stay focused on your goals. Achievement helps you feel emotionally secure because you show love through responsibility.\n\nYou don\'t do emotional displays because you process feelings through work. Your discipline is how you care for yourself. Your emotional security comes from accomplishment.',
        'rising':
            'Your competence is obvious. People trust you with responsibility because you\'re capable. Your drive inspires others to work harder.\n\nYou show what\'s possible with dedication. People see your success, but miss your process. Your ambition makes others uncomfortable because it shows them their own laziness.\n\nYou don\'t need to prove anything. Your results speak for themselves. Your presence commands respect because you\'ve earned it.',
      },
      'Aquarius': {
        'sun':
            'Your ideas aren\'t weird. They\'re ahead of their time. History will prove you right. Your uniqueness isn\'t eccentricity. It\'s evolution.\n\nYou see possibilities others can\'t imagine yet. Your vision isn\'t limited by current reality. You don\'t do conventional because you\'re meant to innovate.\n\nYour detachment isn\'t coldness. It\'s objectivity. You can see the future because you\'re not attached to the present. Your originality isn\'t trying too hard. It\'s who you are.',
        'moon':
            'Your emotional distance isn\'t coldness. It\'s protection. You intellectualize emotions because feeling them directly is too intense.\n\nYour detachment isn\'t lack of feeling. It\'s how you process it. You need intellectual connection because your emotions are tied to your ideals.\n\nYour mind processes what your heart feels. Your distance protects your brilliant mind. It\'s survival, not coldness. Your emotions are overwhelming, so you think about them instead.',
        'rising':
            'Your weirdness isn\'t a flaw. It\'s a feature. Your uniqueness makes some uncomfortable, but the right people find it magnetic.\n\nYou attract your tribe. People notice you\'re different right away because you don\'t hide it. You attract those who appreciate original thinking.\n\nYour unconventional approach is refreshing. You don\'t try to fit in because you know you\'re meant to stand out. Your energy is magnetic to the right people.',
      },
      'Pisces': {
        'sun':
            'Your dreams aren\'t escape. They\'re vision. You see what could be, not just what is. Your imagination creates possibilities that inspire change.\n\nReality needs people like you to see beyond it. Your compassion comes from truly understanding others\' experience. You feel the interconnectedness of everything because you\'re tuned into the unseen.\n\nYour visions inspire others to imagine more. You don\'t do boundaries. You do connection.',
        'moon':
            'Your sensitivity isn\'t weakness. It\'s emotional intelligence most don\'t understand. You feel everything because you\'re permeable.\n\nYour empathy connects you to energies others miss. It\'s a gift, even when it feels like a burden. You absorb emotions from your environment because that\'s how you\'re built.\n\nCreative and spiritual practices help you stay centered. Your emotional depth is a superpower, not a curse. You feel what others can\'t.',
        'rising':
            'Your gentleness isn\'t weakness. It\'s strength. Your sensitivity is emotional intelligence most people don\'t understand.\n\nThat\'s their loss. People feel seen by you because you understand them deeply. Your gentle presence creates space for others to be authentic.\n\nYou don\'t need to be loud to be powerful. Your quiet strength is magnetic. You make others feel safe to be vulnerable. Your empathy is obvious to everyone who matters.',
      },
    };

    return insights[sign]?[type] ??
        'Your $sign $type brings unique qualities to your cosmic makeup.';
  }

  Widget _buildHighlightsPhase() {
    return Stack(
      children: [
        // Main scrollable content
        SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(
                  left: 0, right: 0, top: 16, bottom: 120),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Clean header - app icon without shadow
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.asset(
                      'assets/images/icon_transparent.png',
                      height: 56,
                      width: 56,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Your Cosmic Gifts',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: _OnboardingColors.textPrimary(context),
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Special insights from your birth chart',
                    style: TextStyle(
                      fontSize: 14,
                      color: _OnboardingColors.textSecondary(context),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ...List.generate(_highlights.length, (index) {
                    final highlight = _highlights[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildHighlightCard(
                        icon: highlight['icon'] as IconData,
                        color: highlight['color'] as Color,
                        title: highlight['title'] as String,
                        subtitle: highlight['subtitle'] as String,
                        description: highlight['description'] as String,
                        revealed: _highlightRevealStep > index,
                        highlightType: highlight['type'] as String,
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ),
        // Continue button positioned at bottom (show when all highlights revealed)
        if (_highlightRevealStep >= _highlights.length)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: _buildContinueButton(
                label: 'Continue',
                onTap: _goToAyurvedaPhase,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildHighlightCard({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required String description,
    required bool revealed,
    required String highlightType, // 'yoga', 'dasha', 'nakshatra'
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: revealed ? 1.0 : 0.0),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
      builder: (context, anim, child) {
        final clampedOpacity = anim.clamp(0.0, 1.0);
        return Transform.translate(
          offset: Offset(0, 16 * (1 - anim)),
          child: Opacity(
            opacity: clampedOpacity,
            child: child,
          ),
        );
      },
      // Use TransparentToolbox for consistent styling
      child: GestureDetector(
        onTap: revealed
            ? () => _showHighlightDetails(
                  icon: icon,
                  color: color,
                  title: title,
                  subtitle: subtitle,
                  description: description,
                  highlightType: highlightType,
                )
            : null,
        child: TransparentToolbox(
          height: 95,
          content: Row(
            children: [
              // Icon
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 14),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryColor.withValues(alpha: 0.85),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: color.withValues(alpha: 0.8),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.primaryColor.withValues(alpha: 0.55),
                        height: 1.35,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showHighlightDetails({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required String description,
    required String highlightType,
  }) {
    final expandedContent = _getExpandedHighlightContent(title, highlightType);

    CardDetailsDialog.show(
      context,
      icon: icon,
      color: color,
      title: title,
      subtitle: subtitle,
      description: description,
      expandedContent: expandedContent,
    );
  }

  String _getExpandedHighlightContent(String title, String type) {
    switch (type) {
      case 'yoga':
        return _getYogaExpandedContent(title);
      case 'dasha':
        return _getDashaExpandedContent(title);
      case 'nakshatra':
        return _getNakshatraExpandedContent(title);
      default:
        return 'This is a unique aspect of your birth chart that influences your life path.';
    }
  }

  String _getYogaExpandedContent(String yogaName) {
    // Personal context for common yogas
    final yogaInsights = {
      'Gaja Kesari':
          'This blessing in your chart indicates you\'ll gain wisdom and respect through your life. People naturally look to you for guidance.',
      'Budh Aditya':
          'Your mind and will align powerfully. You have the ability to communicate with authority and clarity.',
      'Chandra Mangal':
          'Financial prosperity tends to flow to you. Your emotional drive creates material success.',
      'Neechabhanga Raja':
          'A debilitation cancelled—what seemed like weakness becomes your greatest strength. Your challenges transform into victories.',
      'Viparita Raja':
          'Obstacles dissolve before you. You have the karmic blessing of enemies turning into stepping stones.',
      'Dhana':
          'Wealth accumulation is favored in your chart. You have natural ability to grow resources.',
      'Pancha Mahapurusha':
          'A great person yoga. You carry the energy of exceptional capability in specific life areas.',
      'Saraswati':
          'The goddess of knowledge blesses you. Learning, creativity, and eloquence come naturally.',
      'Lakshmi':
          'Prosperity and beauty naturally gravitate toward you. You attract abundance with grace.',
    };

    // Check if yoga name contains any of the keys
    for (final entry in yogaInsights.entries) {
      if (yogaName.toLowerCase().contains(entry.key.toLowerCase())) {
        return entry.value;
      }
    }

    return 'This special combination in your chart brings unique blessings. It indicates a favorable alignment that supports your success and growth.';
  }

  String _getDashaExpandedContent(String dashaTitle) {
    // Extract the planet from "X Mahadasha"
    final planet = dashaTitle.replaceAll(' Mahadasha', '').trim();

    final dashaInsights = {
      'Sun':
          'Now is the time to step into your authority. Focus on leadership roles, health, and father-related matters. Your confidence is your currency.',
      'Moon':
          'Emotional growth takes center stage. Pay attention to mother, home, and inner peace. Your intuition is heightened—trust it.',
      'Mars':
          'Energy and ambition peak. Take bold action on your goals. Physical health and brothers/siblings are highlighted. Channel aggression constructively.',
      'Mercury':
          'Communication and learning are favored. Business, writing, and intellectual pursuits flourish. Stay adaptable and curious.',
      'Jupiter':
          'A blessed period of expansion. Wisdom, teachers, and opportunities for growth appear. Be generous—it returns multiplied.',
      'Venus':
          'Love, beauty, and comfort are highlighted. Relationships, creativity, and pleasures bring fulfillment. Enjoy life while creating value.',
      'Saturn':
          'Hard work builds lasting foundations. Patience is required but rewards are permanent. Discipline transforms into mastery.',
      'Rahu':
          'Unconventional paths open. Worldly ambitions intensify. This is a time to break patterns and explore new territories.',
      'Ketu':
          'Spiritual growth accelerates. Past patterns release. Focus inward—external losses often mean internal gains.',
    };

    return dashaInsights[planet] ??
        'This planetary period shapes your current life chapter. Pay attention to its themes—they\'re your curriculum right now.';
  }

  String _getNakshatraExpandedContent(String nakshatra) {
    // Return a deeper personal insight about the nakshatra
    final nakshatraInsights = {
      'Ashwini':
          'Your healing ability is innate—not just physical, but the power to restore hope. Quick decisions often serve you well.',
      'Bharani':
          'You understand transformation at a soul level. You can hold space for others going through difficult changes.',
      'Krittika':
          'Your clarity cuts through confusion. When you speak truth, others can\'t ignore it. Use this power wisely.',
      'Rohini':
          'Creative fertility flows through you. Whatever you nurture grows beautifully. Your appreciation for beauty is a gift, not indulgence.',
      'Mrigashira':
          'Your search leads you to discoveries others miss. Restlessness is your teacher—it pushes you toward growth.',
      'Ardra':
          'You process the storms others avoid. Your willingness to face darkness makes you a powerful catalyst for change.',
      'Punarvasu':
          'Renewal is your superpower. No matter what happens, you find your way back to center. This resilience inspires others.',
      'Pushya':
          'Your nurturing nature is your greatest strength. You help others flourish without depleting yourself.',
      'Ashlesha':
          'You perceive what\'s hidden. Trust your instincts about people and situations—they rarely fail you.',
      'Magha':
          'Ancestral blessings flow through you. Honoring your lineage activates your power. You carry royal energy.',
      'Purva Phalguni':
          'Creativity and pleasure are your paths to wisdom. Your joy is productive, not escapism.',
      'Uttara Phalguni':
          'You create through service. Your generosity builds lasting prosperity. Others benefit from your success.',
      'Hasta':
          'Your hands carry intelligence. Whether physical craft or subtle manipulation of energy, skill is your domain.',
      'Chitra':
          'You see the finished masterpiece where others see raw material. Your vision creates beauty in practical form.',
      'Swati':
          'Independence isn\'t loneliness for you—it\'s freedom. Your ability to bend without breaking is your strength.',
      'Vishakha':
          'Determination is your middle name. What you decide to achieve, you achieve. Focus is your superpower.',
      'Anuradha':
          'Devotion in friendship and purpose creates your success. Your loyalty attracts equally loyal companions.',
      'Jyeshtha':
          'Elder wisdom flows through you, regardless of age. You protect what matters with fierce dedication.',
      'Mula':
          'You get to the root. Surface solutions don\'t satisfy you. Your investigations reveal fundamental truths.',
      'Purva Ashadha':
          'You purify what you touch. Your convictions have power—use them to elevate, not destroy.',
      'Uttara Ashadha':
          'Final victory is yours. Your principles may be tested, but you emerge with lasting respect.',
      'Shravana':
          'Listening is your path to wisdom. What you learn, you can teach. Knowledge flows through you.',
      'Dhanishtha':
          'Rhythm and prosperity dance together in your life. Your sense of timing brings wealth.',
      'Shatabhisha':
          'Mysterious healing powers are yours. You fix what others give up on. Solitude recharges you.',
      'Purva Bhadrapada':
          'Intense spiritual fire burns in you. Your passion for truth transforms everything it touches.',
      'Uttara Bhadrapada':
          'Depth without attachment—this is your gift. You understand letting go while caring deeply.',
      'Revati':
          'Safe harbor for wandering souls—this is your role. You guide others home to themselves.',
    };

    return nakshatraInsights[nakshatra] ??
        'Your nakshatra reveals the unique flavor of your soul. It influences how you naturally express yourself in the world.';
  }

  Widget _buildAyurvedaRevealPhase() {
    final ayurvedaProfile = _ayurvedaProfile;
    if (ayurvedaProfile == null || ayurvedaProfile.prakriti == null) {
      // Fallback to reading if no Ayurveda data
      return _buildBirthReadingPhase();
    }

    final prakriti = ayurvedaProfile.prakriti!;
    final isTridoshic = prakriti.type.toLowerCase().contains('tridoshic') ||
        prakriti.isBalanced;
    final isDualDosha = prakriti.type.contains('-') && !isTridoshic;

    return ResponsiveBuilder(
      builder: (context, isMobile, isTablet, isDesktop) {
        final isWideScreen = isTablet || isDesktop;

        if (isWideScreen) {
          return _buildAyurvedaRevealWideLayout(
            ayurvedaProfile,
            prakriti,
            isTridoshic,
            isDualDosha,
            isDesktop,
          );
        }
        return _buildAyurvedaRevealMobileLayout(
          ayurvedaProfile,
          prakriti,
          isTridoshic,
          isDualDosha,
        );
      },
    );
  }

  /// Wide screen layout for Ayurveda reveal
  Widget _buildAyurvedaRevealWideLayout(
    AyurvedaProfile ayurvedaProfile,
    PrakritiData prakriti,
    bool isTridoshic,
    bool isDualDosha,
    bool isDesktop,
  ) {
    return Column(
      children: [
        Expanded(
          child: Scrollbar(
            thumbVisibility: true,
            child: SingleChildScrollView(
              primary: true,
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: isDesktop ? 500 : 480),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Ayurveda',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: _OnboardingColors.primary,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Your predicted ayurvedic energies',
                          style: TextStyle(
                            fontSize: 16,
                            color: _OnboardingColors.textSecondary(context),
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Card 1: Your Constitution
                        _buildAyurvedaCard(
                          context: context,
                          icon: Icons.spa_rounded,
                          color: const Color(0xFF059669),
                          label: 'Your Constitution',
                          value: prakriti.type,
                          description: _getConstitutionDescription(
                              prakriti, isTridoshic, isDualDosha),
                          revealed: _ayurvedaRevealStep >= 1,
                          cardType: 'constitution',
                          prakriti: prakriti,
                        ),
                        const SizedBox(height: 12),
                        // Card 2: Dosha Percentages
                        _buildAyurvedaCard(
                          context: context,
                          icon: Icons.insights_rounded,
                          color: const Color(0xFF8B5CF6),
                          label: 'Prakriti - Your Baseline Nature',
                          value: _getDoshaBalanceTitle(prakriti, isTridoshic),
                          description: _getDoshaBalanceDescription(
                              prakriti, isTridoshic),
                          revealed: _ayurvedaRevealStep >= 2,
                          cardType: 'percentages',
                          prakriti: prakriti,
                        ),
                        // Card 3: Current Balance (Vikriti) - if available
                        if (ayurvedaProfile.vikriti != null) ...[
                          const SizedBox(height: 12),
                          _buildAyurvedaCard(
                            context: context,
                            icon: Icons.wb_twilight_rounded,
                            color: const Color(0xFFEC4899),
                            label: 'Vikriti - Your Current Energy',
                            value: _getVikritiTitle(ayurvedaProfile.vikriti!),
                            description: _getVikritiDescription(
                                ayurvedaProfile.vikriti!),
                            revealed: _ayurvedaRevealStep >= 3,
                            cardType: 'vikriti',
                            prakriti: prakriti,
                            vikriti: ayurvedaProfile.vikriti,
                          ),
                        ],
                        // Subtle hint (cards now have visual tap indicators)
                        if (_ayurvedaRevealStep >=
                            (ayurvedaProfile.vikriti != null ? 3 : 2)) ...[
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.touch_app_rounded,
                                size: 14,
                                color: _OnboardingColors.textSecondary(context)
                                    .withValues(alpha: 0.5),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Tap cards for details',
                                style: TextStyle(
                                  fontSize: 12,
                                  color:
                                      _OnboardingColors.textSecondary(context)
                                          .withValues(alpha: 0.6),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 24),
                        // Continue button in flow
                        if (_ayurvedaRevealStep >=
                            (ayurvedaProfile.vikriti != null ? 3 : 2))
                          _buildContinueButton(
                            label: 'Continue',
                            onTap: _goToReadingPhase,
                          ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Mobile layout for Ayurveda reveal
  Widget _buildAyurvedaRevealMobileLayout(
    AyurvedaProfile ayurvedaProfile,
    PrakritiData prakriti,
    bool isTridoshic,
    bool isDualDosha,
  ) {
    return Stack(
      children: [
        // Main scrollable content
        SafeArea(
          child: SingleChildScrollView(
            padding:
                const EdgeInsets.only(left: 0, right: 0, top: 16, bottom: 120),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Ayurveda',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: _OnboardingColors.primary,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Your predicted ayurvedic energies',
                  style: TextStyle(
                    fontSize: 14,
                    color: _OnboardingColors.textSecondary(context),
                  ),
                ),
                const SizedBox(height: 20),
                // Card 1: Your Constitution
                _buildAyurvedaCard(
                  context: context,
                  icon: Icons.spa_rounded,
                  color: const Color(0xFF059669),
                  label: 'Your Constitution',
                  value: prakriti.type,
                  description: _getConstitutionDescription(
                      prakriti, isTridoshic, isDualDosha),
                  revealed: _ayurvedaRevealStep >= 1,
                  cardType: 'constitution',
                  prakriti: prakriti,
                ),
                const SizedBox(height: 12),
                // Card 2: Dosha Percentages
                _buildAyurvedaCard(
                  context: context,
                  icon: Icons.insights_rounded,
                  color: const Color(0xFF8B5CF6),
                  label: 'Your Baseline Nature',
                  value: _getDoshaBalanceTitle(prakriti, isTridoshic),
                  description:
                      _getDoshaBalanceDescription(prakriti, isTridoshic),
                  revealed: _ayurvedaRevealStep >= 2,
                  cardType: 'percentages',
                  prakriti: prakriti,
                ),
                // Card 3: Current Balance (Vikriti) - if available
                if (ayurvedaProfile.vikriti != null) ...[
                  const SizedBox(height: 12),
                  _buildAyurvedaCard(
                    context: context,
                    icon: Icons.wb_twilight_rounded,
                    color: const Color(0xFFEC4899),
                    label: 'Your Current Energy',
                    value: _getVikritiTitle(ayurvedaProfile.vikriti!),
                    description:
                        _getVikritiDescription(ayurvedaProfile.vikriti!),
                    revealed: _ayurvedaRevealStep >= 3,
                    cardType: 'vikriti',
                    prakriti: prakriti,
                    vikriti: ayurvedaProfile.vikriti,
                  ),
                ],
                // Subtle hint (cards now have visual tap indicators)
                if (_ayurvedaRevealStep >=
                    (ayurvedaProfile.vikriti != null ? 3 : 2)) ...[
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.touch_app_rounded,
                        size: 14,
                        color: _OnboardingColors.textSecondary(context)
                            .withValues(alpha: 0.5),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Tap cards for details',
                        style: TextStyle(
                          fontSize: 12,
                          color: _OnboardingColors.textSecondary(context)
                              .withValues(alpha: 0.6),
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
        // Continue button positioned at bottom (show when all cards revealed)
        if (_ayurvedaRevealStep >= (ayurvedaProfile.vikriti != null ? 3 : 2))
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: _buildContinueButton(
                label: 'Continue',
                onTap: _goToReadingPhase,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAyurvedaCard({
    required BuildContext context,
    required IconData icon,
    required Color color,
    required String label,
    required String value,
    required String description,
    required bool revealed,
    required String cardType,
    PrakritiData? prakriti,
    VikritiData? vikriti,
  }) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: revealed ? 1.0 : 0.0),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
      builder: (context, anim, child) {
        final clampedOpacity = anim.clamp(0.0, 1.0);
        return Transform.translate(
          offset: Offset(0, 20 * (1 - anim)),
          child: Opacity(
            opacity: clampedOpacity,
            child: child,
          ),
        );
      },
      child: GestureDetector(
        onTap: revealed
            ? () {
                HapticFeedback.lightImpact();
                _showAyurvedaDetails(
                  icon: icon,
                  color: color,
                  label: label,
                  value: value,
                  description: description,
                  cardType: cardType,
                  prakriti: prakriti,
                  vikriti: vikriti,
                );
              }
            : null,
        child: TransparentToolbox(
          height: cardType == 'percentages' && prakriti != null
              ? 182.0
              : cardType == 'vikriti' && vikriti != null
                  ? 202.0
                  : 120.0,
          content: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header row
                Row(
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(icon, color: color, size: 20),
                  ],
                ),
                // Value - conditionally shown when revealed
                if (revealed) ...[
                  const SizedBox(height: 6),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: _OnboardingColors.textPrimary(context),
                    ),
                  ),
                ],
                // Description - always shown
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: _OnboardingColors.textSecondary(context),
                      height: 1.3,
                    ),
                    maxLines: cardType == 'constitution'
                        ? 3
                        : cardType == 'vikriti'
                            ? 2
                            : 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                // Dosha bars for percentages card
                if (cardType == 'percentages' &&
                    prakriti != null &&
                    revealed) ...[
                  const SizedBox(height: 12),
                  _buildDoshaBarMini(
                      'Vata', prakriti.vata, const Color(0xFF8B5CF6)),
                  const SizedBox(height: 10),
                  _buildDoshaBarMini(
                      'Pitta', prakriti.pitta, const Color(0xFFF59E0B)),
                  const SizedBox(height: 10),
                  _buildDoshaBarMini(
                      'Kapha', prakriti.kapha, const Color(0xFF10B981)),
                ],
                // Dosha bars for vikriti card
                if (cardType == 'vikriti' && vikriti != null && revealed) ...[
                  const SizedBox(height: 12),
                  _buildDoshaBarMini(
                      'Vata', vikriti.vata, const Color(0xFF8B5CF6)),
                  const SizedBox(height: 10),
                  _buildDoshaBarMini(
                      'Pitta', vikriti.pitta, const Color(0xFFF59E0B)),
                  const SizedBox(height: 10),
                  _buildDoshaBarMini(
                      'Kapha', vikriti.kapha, const Color(0xFF10B981)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDoshaBarMini(String label, int percentage, Color color) {
    return Row(
      children: [
        SizedBox(
          width: 50,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percentage / 100,
              backgroundColor: color.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 6,
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 35,
          child: Text(
            '$percentage%',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _OnboardingColors.textPrimary(context),
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  // Card 1: Constitution Description (2-3 lines, interesting, direct)
  String _getConstitutionDescription(
      PrakritiData prakriti, bool isTridoshic, bool isDualDosha) {
    if (isTridoshic) {
      return 'All three doshas are balanced. You adapt well to different situations.';
    } else if (isDualDosha) {
      final doshas = prakriti.type.toLowerCase().split('-');
      final primary = doshas[0];
      final secondary = doshas.length > 1 ? doshas[1] : '';

      String primaryDesc = '';
      if (primary == 'vata') {
        primaryDesc = 'Creative and quick';
      } else if (primary == 'pitta') {
        primaryDesc = 'Focused and sharp';
      } else if (primary == 'kapha') {
        primaryDesc = 'Calm and steady';
      }

      String secondaryDesc = '';
      if (secondary == 'vata') {
        secondaryDesc = 'energetic';
      } else if (secondary == 'pitta') {
        secondaryDesc = 'driven';
      } else if (secondary == 'kapha') {
        secondaryDesc = 'grounded';
      }

      return '$primaryDesc, with $secondaryDesc qualities. Your nature shifts with seasons and life phases.';
    } else {
      final dominant = prakriti.dominant.toLowerCase();

      if (dominant == 'vata') {
        return 'You\'re creative, quick-thinking, and energetic. Your mind moves fast and you adapt easily.';
      } else if (dominant == 'pitta') {
        return 'You\'re focused, driven, and sharp. You\'re goal-oriented and organized.';
      } else if (dominant == 'kapha') {
        return 'You\'re calm, steady, and nurturing. You have strong stamina and stay grounded.';
      } else {
        return 'Your unique nature shapes how you experience the world.';
      }
    }
  }

  // Card 2: Dosha Balance Title
  String _getDoshaBalanceTitle(PrakritiData prakriti, bool isTridoshic) {
    if (isTridoshic) {
      return 'Balanced';
    } else {
      return 'Prakriti';
    }
  }

  // Card 2: Dosha Balance Description
  String _getDoshaBalanceDescription(PrakritiData prakriti, bool isTridoshic) {
    if (isTridoshic) {
      return 'All three doshas are evenly balanced';
    } else {
      return 'Your natural dosha levels';
    }
  }

  // Card 3: Vikriti Title
  String _getVikritiTitle(VikritiData vikriti) {
    if (vikriti.isBalanced) {
      return 'Balanced';
    } else {
      final imbalances = vikriti.imbalances;
      if (imbalances.isNotEmpty) {
        final dosha = imbalances[0].dosha;
        return dosha.substring(0, 1).toUpperCase() + dosha.substring(1);
      }
      return 'Current State';
    }
  }

  // Card 3: Vikriti Description
  String _getVikritiDescription(VikritiData vikriti) {
    if (vikriti.isBalanced) {
      return 'Your current balance matches your natural state. You\'re in harmony.';
    } else {
      final imbalances = vikriti.imbalances;
      if (imbalances.isNotEmpty) {
        final dosha = imbalances[0].dosha.toLowerCase();
        if (dosha == 'vata') {
          return 'You may feel scattered or anxious. Focus on staying grounded and warm.';
        } else if (dosha == 'pitta') {
          return 'You may feel irritable or overheated. Focus on cooling down and taking breaks.';
        } else if (dosha == 'kapha') {
          return 'You may feel sluggish or heavy. Focus on staying active and moving.';
        }
      }
      return 'Your current balance has shifted. Understanding this helps you adjust.';
    }
  }

  // Expanded Vikriti Content
  String _getExpandedVikritiContent(
      VikritiData vikriti, PrakritiData prakriti) {
    final isBalanced = vikriti.isBalanced;
    final imbalances = vikriti.imbalances;
    final dominant = prakriti.dominant.toLowerCase();

    if (isBalanced) {
      return 'You\'re in harmony right now. Your current state matches your natural baseline.\n\n'
          'You\'re likely feeling balanced, healthy, and at ease. This is ideal - you\'re aligned with your natural constitution.\n\n'
          'To maintain this:\n'
          '• Continue your current practices\n'
          '• Pay attention to seasonal changes\n'
          '• Stay attuned to your body\'s signals';
    } else {
      String content = '';
      String tips = '';

      if (imbalances.isNotEmpty) {
        for (var imbalance in imbalances) {
          final String dosha = imbalance.dosha;
          final doshaName =
              dosha.substring(0, 1).toUpperCase() + dosha.substring(1);

          if (dosha.toLowerCase() == 'vata') {
            if (dominant == 'vata') {
              content =
                  'Your creative, quick-thinking nature is elevated right now. You may be feeling more scattered, anxious, or having trouble sleeping than usual.\n\n'
                  'This happens when you\'re overstimulated or have too much change. Your mind is moving even faster than normal, which can leave you feeling ungrounded.\n\n';
            } else {
              content =
                  'Your creative, quick-thinking side is elevated right now. You may be feeling scattered, anxious, or having trouble sleeping.\n\n'
                  'This is different from your natural state. You\'re experiencing more movement and change than usual, which can feel unsettling.\n\n';
            }
            tips = '• Keep warm, maintain routines\n'
                '• Eat warm, nourishing foods\n'
                '• Practice grounding activities\n'
                '• Slow down and create stability';
          } else if (dosha.toLowerCase() == 'pitta') {
            if (dominant == 'pitta') {
              content =
                  'Your focused, driven nature is elevated right now. You may be feeling more irritable, overheated, or experiencing acidity than usual.\n\n'
                  'This happens when you\'re pushing too hard or under stress. Your drive is intensified, which can make you feel burned out or critical.\n\n';
            } else {
              content =
                  'Your focused, driven side is elevated right now. You may be feeling irritable, overheated, or experiencing acidity.\n\n'
                  'This is different from your natural state. You\'re experiencing more intensity and heat than usual, which can feel overwhelming.\n\n';
            }
            tips = '• Stay cool, avoid excessive heat\n'
                '• Eat cooling foods\n'
                '• Practice moderation\n'
                '• Take breaks and relax';
          } else if (dosha.toLowerCase() == 'kapha') {
            if (dominant == 'kapha') {
              content =
                  'Your steady, patient nature is elevated right now. You may be feeling more sluggish, heavy, or resistant to change than usual.\n\n'
                  'This happens when you\'re too comfortable or stagnant. Your stability is intensified, which can make you feel stuck or unmotivated.\n\n';
            } else {
              content =
                  'Your steady, patient side is elevated right now. You may be feeling sluggish, heavy, or resistant to change.\n\n'
                  'This is different from your natural state. You\'re experiencing more heaviness and stability than usual, which can feel limiting.\n\n';
            }
            tips = '• Stay active, maintain variety\n'
                '• Eat light, warm foods\n'
                '• Avoid stagnation\n'
                '• Create movement and stimulation';
          }
        }
      }

      content += 'To restore balance:\n'
          '$tips';

      return content;
    }
  }

  void _showAyurvedaDetails({
    required IconData icon,
    required Color color,
    required String label,
    required String value,
    required String description,
    required String cardType,
    PrakritiData? prakriti,
    VikritiData? vikriti,
  }) {
    if (prakriti == null) return;

    final isTridoshic = prakriti.type.toLowerCase().contains('tridoshic') ||
        prakriti.isBalanced;
    final isDualDosha = prakriti.type.contains('-') && !isTridoshic;

    String expandedContent = description;

    if (cardType == 'constitution') {
      expandedContent = _getExpandedConstitutionContent(
          prakriti.type, isTridoshic, isDualDosha, prakriti);
    } else if (cardType == 'percentages') {
      expandedContent = _getExpandedPercentagesContent(prakriti, isTridoshic);
    } else if (cardType == 'vikriti' && vikriti != null) {
      expandedContent = _getExpandedVikritiContent(vikriti, prakriti);
    }

    CardDetailsDialog.show(
      context,
      icon: icon,
      color: color,
      title: value,
      subtitle: label,
      description: description,
      expandedContent: expandedContent,
    );
  }

  String _getExpandedConstitutionContent(
      String type, bool isTridoshic, bool isDualDosha, PrakritiData prakriti) {
    if (isTridoshic) {
      return 'You adapt well to different situations. This is rare.\n\n'
          'You can thrive in various environments, but you need to pay attention to your body\'s signals. When you feel off, one of your doshas may be shifting.\n\n'
          'Maintain regular routines and adjust your diet and activities based on seasons.';
    } else if (isDualDosha) {
      final doshas = type.toLowerCase().split('-');
      final primary = doshas[0];
      final secondary = doshas.length > 1 ? doshas[1] : '';

      String content = '';
      String tips = '';

      if (primary == 'vata' && secondary == 'pitta') {
        content =
            'You\'re creative and quick-thinking, but also focused and driven. Your mind moves fast and you get things done.\n\n'
            'You thrive on new ideas and projects, but you need structure to channel your energy. Without it, you can feel scattered or burn out.\n\n'
            'You\'re naturally innovative - you see possibilities others miss. But you also need to slow down sometimes and let ideas settle.';
        tips =
            '• Keep warm, maintain routines\n• Eat warm, nourishing foods\n• Take breaks to cool down\n• Balance creativity with structure';
      } else if (primary == 'vata' && secondary == 'kapha') {
        content =
            'You\'re creative and energetic, but also steady and grounded. Your mind moves fast, but you have the stamina to follow through.\n\n'
            'You\'re naturally adaptable - you can shift between being spontaneous and being methodical. This makes you versatile, but you need to watch for extremes.\n\n'
            'You may find yourself swinging between wanting change and wanting stability. Learning to balance both helps you thrive.';
        tips =
            '• Keep warm, maintain routines\n• Eat warm, nourishing foods\n• Stay active but don\'t overdo it\n• Balance spontaneity with structure';
      } else if (primary == 'pitta' && secondary == 'vata') {
        content =
            'You\'re focused and driven, but also creative and quick-thinking. You\'re goal-oriented, but your mind moves fast.\n\n'
            'You get things done efficiently, but you also have bursts of inspiration. You need to channel your drive without burning out.\n\n'
            'You\'re naturally organized, but you also need flexibility. Too much structure can stifle your creativity, too little can make you scattered.';
        tips =
            '• Stay cool, avoid excessive heat\n• Eat cooling foods\n• Maintain routines but allow flexibility\n• Balance focus with creativity';
      } else if (primary == 'pitta' && secondary == 'kapha') {
        content =
            'You\'re focused and driven, but also steady and patient. You\'re goal-oriented, but you have the stamina to see things through.\n\n'
            'You\'re naturally organized and methodical. You plan well and execute consistently. But you need to watch for becoming too rigid.\n\n'
            'You have strong willpower and determination. You can push through challenges, but you also need to take breaks and not overwork yourself.';
        tips =
            '• Stay cool, avoid excessive heat\n• Eat cooling foods\n• Stay active but don\'t overwork\n• Balance drive with rest';
      } else if (primary == 'kapha' && secondary == 'vata') {
        content =
            'You\'re steady and grounded, but also creative and adaptable. You have strong stamina, but your mind can move fast.\n\n'
            'You\'re naturally patient and reliable, but you also have bursts of energy and inspiration. You can be both methodical and spontaneous.\n\n'
            'You may find yourself wanting stability but also craving change. Learning to embrace both helps you grow without losing your grounding.';
        tips =
            '• Stay active, maintain variety\n• Eat light, warm foods\n• Keep warm, maintain routines\n• Balance stability with change';
      } else if (primary == 'kapha' && secondary == 'pitta') {
        content =
            'You\'re steady and patient, but also focused and driven. You have strong stamina, but you\'re also goal-oriented.\n\n'
            'You\'re naturally reliable and methodical. You plan well and follow through consistently. But you need to watch for becoming too comfortable.\n\n'
            'You have the patience to see things through and the drive to achieve goals. You work steadily, but you also need stimulation to avoid stagnation.';
        tips =
            '• Stay active, maintain variety\n• Eat light, warm foods\n• Stay cool, avoid excessive heat\n• Balance patience with drive';
      } else {
        content =
            'You have qualities from both doshas. This blend means you experience characteristics from both. One may feel stronger during different seasons or life phases.';
        tips =
            '• Pay attention to your body\'s signals\n• Adjust your routine based on how you feel\n• Maintain balance between both doshas';
      }

      return '$content\n\n'
          'To stay balanced:\n'
          '$tips';
    } else {
      final dominant = prakriti.dominant.toLowerCase();
      String content = '';
      String tips = '';

      if (dominant == 'vata') {
        content =
            'You\'re naturally creative, quick-thinking, and energetic. Your mind moves fast and you adapt easily.\n\n'
            'You thrive on new experiences and ideas. You\'re innovative and flexible - you see possibilities others miss. But you need grounding to channel your energy.\n\n'
            'You may find yourself jumping from one thing to another. While this keeps you engaged, you also need routines to feel stable. Without them, you can feel scattered or anxious.';
        tips =
            '• Keep warm, maintain routines\n• Eat warm, nourishing foods\n• Practice grounding activities\n• Avoid excessive travel or change';
      } else if (dominant == 'pitta') {
        content =
            'You\'re naturally focused, driven, and sharp. You\'re goal-oriented and organized.\n\n'
            'You get things done efficiently. You\'re a natural leader with clear vision. You thrive on challenges and achievement. But you need to watch for burning out.\n\n'
            'You may find yourself pushing too hard or being too critical. While this drives results, you also need to slow down and take breaks. Without them, you can feel irritable or overheated.';
        tips =
            '• Stay cool, avoid excessive heat\n• Eat cooling foods\n• Practice moderation\n• Take time for relaxation';
      } else if (dominant == 'kapha') {
        content =
            'You\'re naturally calm, steady, and nurturing. You have strong stamina and stay grounded.\n\n'
            'You\'re reliable and patient. You have the endurance to see things through. You thrive on routine and stability. But you need stimulation to avoid stagnation.\n\n'
            'You may find yourself getting too comfortable or resistant to change. While this provides security, you also need variety and activity. Without them, you can feel sluggish or heavy.';
        tips =
            '• Stay active, regular exercise\n• Eat light, warm foods\n• Maintain variety\n• Wake up early, avoid excessive sleep';
      } else {
        return 'Your unique nature shapes how you experience the world. Pay attention to what makes you feel balanced and what throws you off.';
      }

      return '$content\n\n'
          'To stay balanced:\n'
          '$tips';
    }
  }

  String _getExpandedPercentagesContent(
      PrakritiData prakriti, bool isTridoshic) {
    final vata = prakriti.vata;
    final pitta = prakriti.pitta;
    final kapha = prakriti.kapha;

    if (isTridoshic) {
      return 'Your baseline shows roughly equal Vata, Pitta, and Kapha. That balance is rare.\n\n'
          'Think of this as your natural “set point.” Day to day, one dosha may temporarily increase (stress, season, diet), but your system tends to return to this equilibrium.\n\n'
          'Noticing when you feel off helps you spot which dosha is elevated so you can gently adjust—diet, routine, or rest—until you feel aligned again.';
    } else {
      final dominant = prakriti.dominant.toLowerCase();
      String content = '';

      if (dominant == 'vata') {
        if (pitta > kapha) {
          content =
              'Your creative, quick-thinking nature is strongest. Your focused, driven side supports it.\n\n'
              'You\'re naturally innovative and adaptable. You see possibilities quickly and act on them. Your drive helps you follow through, but you need to watch for burning out.\n\n'
              'You may find yourself jumping between ideas and projects. While this keeps you engaged, you also need routines to feel stable.';
        } else {
          content =
              'Your creative, quick-thinking nature is strongest. Your steady, patient side supports it.\n\n'
              'You\'re naturally innovative and adaptable. You see possibilities quickly, and your patience helps you see them through. But you need to watch for getting stuck.\n\n'
              'You may find yourself wanting change but also craving stability. Learning to balance both helps you thrive.';
        }
      } else if (dominant == 'pitta') {
        if (vata > kapha) {
          content =
              'Your focused, driven nature is strongest. Your creative, quick-thinking side supports it.\n\n'
              'You\'re naturally goal-oriented and efficient. You get things done, and your creativity helps you find new solutions. But you need to watch for overworking.\n\n'
              'You may find yourself pushing too hard or being too critical. While this drives results, you also need flexibility and breaks.';
        } else {
          content =
              'Your focused, driven nature is strongest. Your steady, patient side supports it.\n\n'
              'You\'re naturally goal-oriented and methodical. You plan well and execute consistently. But you need to watch for becoming too rigid.\n\n'
              'You may find yourself working steadily toward goals, but you also need variety and stimulation to avoid stagnation.';
        }
      } else if (dominant == 'kapha') {
        if (vata > pitta) {
          content =
              'Your steady, patient nature is strongest. Your creative, adaptable side supports it.\n\n'
              'You\'re naturally reliable and grounded. You have the stamina to see things through, and your adaptability helps you adjust when needed. But you need to watch for getting too comfortable.\n\n'
              'You may find yourself wanting stability but also craving change. Learning to embrace both helps you grow without losing your grounding.';
        } else {
          content =
              'Your steady, patient nature is strongest. Your focused, driven side supports it.\n\n'
              'You\'re naturally reliable and methodical. You have the patience to see things through and the drive to achieve goals. But you need to watch for becoming too comfortable.\n\n'
              'You may find yourself working steadily, but you also need stimulation and activity to avoid feeling stuck.';
        }
      }

      return '$content\n\n'
          'Pay attention to how you feel - this helps you recognize when you\'re balanced and when you need to adjust.';
    }
  }

  Widget _buildBirthReadingPhase() {
    final hasReading =
        _firstReadingContent != null && _firstReadingContent!.isNotEmpty;

    return ResponsiveBuilder(
      builder: (context, isMobile, isTablet, isDesktop) {
        final isWideScreen = isTablet || isDesktop;

        if (isWideScreen) {
          return _buildBirthReadingWideLayout(hasReading, isDesktop);
        }
        return _buildBirthReadingMobileLayout(hasReading);
      },
    );
  }

  /// Wide screen layout for birth reading
  Widget _buildBirthReadingWideLayout(bool hasReading, bool isDesktop) {
    return Column(
      children: [
        Expanded(
          child: Scrollbar(
            thumbVisibility: true,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: isDesktop ? 700 : 640),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Clean header - app icon without shadow
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.asset(
                            'assets/images/icon_transparent.png',
                            height: 64,
                            width: 64,
                            fit: BoxFit.contain,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Your Birth Reading',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: _OnboardingColors.textPrimary(context),
                          ),
                        ),
                        const SizedBox(height: 24),
                        if (_isGeneratingReading && !hasReading)
                          Column(
                            children: [
                              SizedBox(
                                width: 36,
                                height: 36,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      AppTheme.primaryColor),
                                ),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                'Writing your personalized insights...',
                                style: TextStyle(
                                  fontSize: 16,
                                  color:
                                      _OnboardingColors.textSecondary(context),
                                ),
                              ),
                              const SizedBox(height: 24),
                              // Skip button while loading
                              TextButton(
                                onPressed: _goToCurrentTimesPhase,
                                child: Text(
                                  'Skip for now',
                                  style: TextStyle(
                                    color: _OnboardingColors.textSecondary(
                                        context),
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          )
                        else if (hasReading)
                          TransparentToolbox.buildCard(
                            context: context,
                            padding: const EdgeInsets.all(24),
                            child: DefaultTextStyle(
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w400,
                                color: AppTheme.primaryColor,
                                height: 1.7,
                              ),
                              child: MarkdownUtils.buildRichContent(
                                _firstReadingContent!,
                                context,
                              ),
                            ),
                          )
                        else
                          TransparentToolbox(
                            height: 160,
                            content: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.check_rounded,
                                  size: 36,
                                  color: _OnboardingColors.risingGreen,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Your Chart is Ready',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primaryColor
                                        .withValues(alpha: 0.85),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Explore your profile and get daily personalized insights.',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: AppTheme.primaryColor
                                        .withValues(alpha: 0.55),
                                    height: 1.4,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.wb_sunny_outlined,
                              size: 16,
                              color: _OnboardingColors.textSecondary(context),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Daily insights await you',
                              style: TextStyle(
                                fontSize: 13,
                                color: _OnboardingColors.textSecondary(context),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),
                        // Continue button in flow
                        if (!_isGeneratingReading || hasReading)
                          _buildContinueButton(
                            label: 'Continue',
                            onTap: _goToCurrentTimesPhase,
                          ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Mobile layout for birth reading
  Widget _buildBirthReadingMobileLayout(bool hasReading) {
    return Stack(
      children: [
        // Main scrollable content
        SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(
                  left: 16, right: 16, top: 16, bottom: 120),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Clean header - app icon without shadow
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.asset(
                      'assets/images/icon_transparent.png',
                      height: 56,
                      width: 56,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Your Birth Reading',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: _OnboardingColors.textPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_isGeneratingReading && !hasReading)
                    Column(
                      children: [
                        SizedBox(
                          width: 32,
                          height: 32,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(
                                AppTheme.primaryColor),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Writing your personalized insights...',
                          style: TextStyle(
                            fontSize: 14,
                            color: _OnboardingColors.textSecondary(context),
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Skip button while loading
                        TextButton(
                          onPressed: _goToCurrentTimesPhase,
                          child: Text(
                            'Skip for now',
                            style: TextStyle(
                              color: _OnboardingColors.textSecondary(context),
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    )
                  else if (hasReading)
                    TransparentToolbox.buildCard(
                      context: context,
                      padding: const EdgeInsets.all(20),
                      child: DefaultTextStyle(
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w400,
                          color: AppTheme.primaryColor,
                          height: 1.65,
                        ),
                        child: MarkdownUtils.buildRichContent(
                          _firstReadingContent!,
                          context,
                        ),
                      ),
                    )
                  else
                    TransparentToolbox(
                      height: 140,
                      content: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.check_rounded,
                            size: 32,
                            color: _OnboardingColors.risingGreen,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Your Chart is Ready',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color:
                                  AppTheme.primaryColor.withValues(alpha: 0.85),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Explore your profile and get daily personalized insights.',
                            style: TextStyle(
                              fontSize: 13,
                              color:
                                  AppTheme.primaryColor.withValues(alpha: 0.55),
                              height: 1.4,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.wb_sunny_outlined,
                        size: 14,
                        color: _OnboardingColors.textSecondary(context),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Daily insights await you',
                        style: TextStyle(
                          fontSize: 12,
                          color: _OnboardingColors.textSecondary(context),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        // Continue button positioned at bottom (show when not loading or has reading)
        if (!_isGeneratingReading || hasReading)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: _buildContinueButton(
                label: 'Continue',
                onTap: _goToCurrentTimesPhase,
              ),
            ),
          ),
      ],
    );
  }

  void _goToCurrentTimesPhase() {
    if (!mounted) return;
    setState(() {
      _phase = _OnboardingPhase.currentTimes;
      final hasContent = _currentTimesReadingContent != null &&
          _currentTimesReadingContent!.isNotEmpty;
      _isGeneratingCurrentTimesReading = !hasContent;
    });
    _pollForCurrentTimesReading();
  }

  Widget _buildCurrentTimesReadingPhase() {
    final hasReading = _currentTimesReadingContent != null &&
        _currentTimesReadingContent!.isNotEmpty;

    return ResponsiveBuilder(
      builder: (context, isMobile, isTablet, isDesktop) {
        final isWideScreen = isTablet || isDesktop;
        if (isWideScreen) {
          return _buildCurrentTimesReadingWideLayout(hasReading, isDesktop);
        }
        return _buildCurrentTimesReadingMobileLayout(hasReading);
      },
    );
  }

  Widget _buildCurrentTimesReadingWideLayout(bool hasReading, bool isDesktop) {
    return Column(
      children: [
        Expanded(
          child: Scrollbar(
            thumbVisibility: true,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: isDesktop ? 700 : 640),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.asset(
                            'assets/images/icon_transparent.png',
                            height: 64,
                            width: 64,
                            fit: BoxFit.contain,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Your Current Times',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: _OnboardingColors.textPrimary(context),
                          ),
                        ),
                        const SizedBox(height: 24),
                        if (_isGeneratingCurrentTimesReading && !hasReading)
                          Column(
                            children: [
                              SizedBox(
                                width: 36,
                                height: 36,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      AppTheme.primaryColor),
                                ),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                'Writing your current insights...',
                                style: TextStyle(
                                  fontSize: 16,
                                  color:
                                      _OnboardingColors.textSecondary(context),
                                ),
                              ),
                              const SizedBox(height: 24),
                              TextButton(
                                onPressed: _goToPathChoice,
                                child: Text(
                                  'Skip for now',
                                  style: TextStyle(
                                    color: _OnboardingColors.textSecondary(
                                        context),
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          )
                        else if (hasReading)
                          TransparentToolbox.buildCard(
                            context: context,
                            padding: const EdgeInsets.all(24),
                            child: DefaultTextStyle(
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w400,
                                color: AppTheme.primaryColor,
                                height: 1.7,
                              ),
                              child: MarkdownUtils.buildRichContent(
                                _currentTimesReadingContent!,
                                context,
                              ),
                            ),
                          )
                        else
                          TransparentToolbox(
                            height: 160,
                            content: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.check_rounded,
                                  size: 36,
                                  color: _OnboardingColors.risingGreen,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Ready',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primaryColor
                                        .withValues(alpha: 0.85),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.wb_sunny_outlined,
                              size: 16,
                              color: _OnboardingColors.textSecondary(context),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Daily insights await you',
                              style: TextStyle(
                                fontSize: 13,
                                color: _OnboardingColors.textSecondary(context),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),
                        if (!_isGeneratingCurrentTimesReading || hasReading)
                          _buildContinueButton(
                            label: 'Continue',
                            onTap: _goToPathChoice,
                          ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCurrentTimesReadingMobileLayout(bool hasReading) {
    return Stack(
      children: [
        SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(
                  left: 16, right: 16, top: 16, bottom: 120),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.asset(
                      'assets/images/icon_transparent.png',
                      height: 56,
                      width: 56,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Your Current Times',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: _OnboardingColors.textPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_isGeneratingCurrentTimesReading && !hasReading)
                    Column(
                      children: [
                        SizedBox(
                          width: 32,
                          height: 32,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(
                                AppTheme.primaryColor),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Writing your current insights...',
                          style: TextStyle(
                            fontSize: 14,
                            color: _OnboardingColors.textSecondary(context),
                          ),
                        ),
                        const SizedBox(height: 20),
                        TextButton(
                          onPressed: _goToPathChoice,
                          child: Text(
                            'Skip for now',
                            style: TextStyle(
                              color: _OnboardingColors.textSecondary(context),
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    )
                  else if (hasReading)
                    TransparentToolbox.buildCard(
                      context: context,
                      padding: const EdgeInsets.all(20),
                      child: DefaultTextStyle(
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w400,
                          color: AppTheme.primaryColor,
                          height: 1.65,
                        ),
                        child: MarkdownUtils.buildRichContent(
                          _currentTimesReadingContent!,
                          context,
                        ),
                      ),
                    )
                  else
                    TransparentToolbox(
                      height: 140,
                      content: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.check_rounded,
                            size: 32,
                            color: _OnboardingColors.risingGreen,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Ready',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color:
                                  AppTheme.primaryColor.withValues(alpha: 0.85),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.wb_sunny_outlined,
                        size: 14,
                        color: _OnboardingColors.textSecondary(context),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Daily insights await you',
                        style: TextStyle(
                          fontSize: 12,
                          color: _OnboardingColors.textSecondary(context),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        if (!_isGeneratingCurrentTimesReading || hasReading)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: _buildContinueButton(
                label: 'Continue',
                onTap: _goToPathChoice,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPathChoicePhase() {
    // Use same structure as sign reveal: Stack + SafeArea + scroll so cards
    // stack without expanding (SingleChildScrollView + Column.min can still
    // get unbounded height and show huge gaps on path choice).
    return Stack(
      children: [
        SafeArea(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.only(
                    left: 0, right: 0, top: 24, bottom: 120),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Clean header - app icon without shadow
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.asset(
                          'assets/images/icon_transparent.png',
                          height: 56,
                          width: 56,
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Start Exploring',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: _OnboardingColors.textPrimary(context),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Your cosmic journey begins here',
                        style: TextStyle(
                          fontSize: 14,
                          color: _OnboardingColors.textSecondary(context),
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildPathButton(
                        icon: Icons.stars_rounded,
                        color: _OnboardingColors.risingGreen,
                        title: 'Look At Your Stars',
                        subtitle: 'Explore your birth chart',
                        onTap: _navigateToAstroDetails,
                      ),
                      const SizedBox(height: 8),
                      _buildPathButton(
                        icon: Icons.spa_rounded,
                        color: const Color(0xFF059669),
                        title: 'Discover Ayurveda',
                        subtitle: 'Check wellness tips',
                        onTap: _navigateToAyurveda,
                      ),
                      const SizedBox(height: 8),
                      _buildPathButton(
                        icon: Icons.auto_awesome_rounded,
                        color: _OnboardingColors.moonPurple,
                        title: 'Personal Guidance',
                        subtitle: 'Read guidance for current times',
                        onTap: _navigateToDailyInsight,
                      ),
                      const SizedBox(height: 8),
                      _buildPathButton(
                        icon: Icons.smart_toy_rounded,
                        color: _OnboardingColors.warmAmber,
                        title: 'Chat with HolyCow',
                        subtitle: 'Ask questions about anything',
                        onTap: () => _navigateToHome(targetTab: 2),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSkipPhase() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Clean header - app icon without shadow
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset(
                'assets/images/icon_transparent.png',
                height: 56,
                width: 56,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Welcome!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: _OnboardingColors.textPrimary(context),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Add birth details anytime to unlock personalized astrology insights.',
                style: TextStyle(
                  fontSize: 14,
                  color: _OnboardingColors.textSecondary(context),
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 32),
            _buildPathButton(
              icon: Icons.smart_toy_rounded,
              color: _OnboardingColors.warmAmber,
              title: 'Meet HolyCow',
              subtitle: 'Your AI companion',
              onTap: () => _navigateToHome(targetTab: 2),
            ),
            const SizedBox(height: 12),
            _buildPathButton(
              icon: Icons.explore_rounded,
              color: _OnboardingColors.risingGreen,
              title: 'Explore Feed',
              subtitle: 'See what\'s happening',
              onTap: () => _navigateToHome(targetTab: 0),
            ),
            const SizedBox(height: 12),
            _buildPathButton(
              icon: Icons.nights_stay_rounded,
              color: _OnboardingColors.moonPurple,
              title: 'Add Birth Details',
              subtitle: 'Unlock cosmic insights',
              onTap: () => _navigateToHome(targetTab: 4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRetryPhase() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Clean header - app icon without shadow
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset(
                'assets/images/icon_transparent.png',
                height: 56,
                width: 56,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Still Calculating...',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: _OnboardingColors.textPrimary(context),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Your chart is taking a bit longer. You can wait or check your profile later.',
                style: TextStyle(
                  fontSize: 14,
                  color: _OnboardingColors.textSecondary(context),
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 32),
            _buildPathButton(
              icon: Icons.refresh_rounded,
              color: _OnboardingColors.moonPurple,
              title: 'Try Again',
              subtitle: 'Wait for calculation',
              onTap: _retryAstroLoad,
            ),
            const SizedBox(height: 12),
            _buildPathButton(
              icon: Icons.account_circle_rounded,
              color: _OnboardingColors.risingGreen,
              title: 'Go to Profile',
              subtitle: 'Check chart when ready',
              onTap: () => _navigateToHome(targetTab: 4),
            ),
            const SizedBox(height: 12),
            _buildPathButton(
              icon: Icons.explore_rounded,
              color: _OnboardingColors.warmAmber,
              title: 'Explore App',
              subtitle: 'Come back later',
              onTap: () => _navigateToHome(targetTab: 0),
            ),
          ],
        ),
      ),
    );
  }

  void _retryAstroLoad() async {
    if (!mounted) return;

    // Go back to loading phase
    setState(() => _phase = _OnboardingPhase.loading);

    // Wait again with fresh attempt
    await _waitForAstroData();

    if (_profile != null) {
      _triggerDailyInsightInBackground();
      _showSignsPhase();
    } else {
      // Still no profile - go to profile page
      AppLogger.w('Retry failed - navigating to profile',
          category: LogCategory.general);
      _navigateToHome(targetTab: 4);
    }
  }

  Widget _buildShareLink() {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 12),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          _shareCosmicProfile();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.open_in_new_rounded,
                color: AppTheme.primaryColor,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'Share your blueprint',
                style: TextStyle(
                  color: AppTheme.primaryColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _shareCosmicProfile() {
    final profile = _profile;
    if (profile == null) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    // Extract sun nakshatra from processedPlanets
    String? sunNakshatra;
    final planets = profile.processedPlanets;
    if (planets != null) {
      for (final planet in planets) {
        if (planet['name']?.toString().toLowerCase() == 'sun') {
          sunNakshatra = planet['nakshatra'] as String?;
          break;
        }
      }
    }

    HapticFeedback.lightImpact();
    ShareService.showCosmicCardPreview(
      context: context,
      userId: uid,
      userName: null,
      sunSign: profile.sunSign ?? '—',
      moonSign: profile.moonSign ?? '—',
      risingSign: profile.ascendant ?? '—',
      sunNakshatra: sunNakshatra,
      moonNakshatra: profile.moonNakshatra ?? profile.nakshatra,
      risingNakshatra: profile.lagnaNakshatra,
    );
  }

  Widget _buildContinueButton({
    required String label,
    required VoidCallback onTap,
  }) {
    return Focus(
      autofocus: false,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.numpadEnter)) {
          HapticFeedback.lightImpact();
          onTap();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: TransparentToolbox(
          content: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(
                Icons.auto_awesome_rounded,
                color: AppTheme.primaryColor,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: AppTheme.primaryColor.withValues(alpha: 0.85),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(
                Icons.arrow_forward_rounded,
                color: AppTheme.primaryColor,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPathButton({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: TransparentToolbox(
        content: Row(
          children: [
            // Icon
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            // Text content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryColor.withValues(alpha: 0.85),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.primaryColor.withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ),
            ),
            // Chevron
            Icon(
              Icons.chevron_right_rounded,
              color: color.withValues(alpha: 0.6),
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}
