import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:aurogram/utils/logging/app_logger.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:aurogram/utils/responsive.dart';
import 'package:aurogram/widgets/universal/transparent_toolbox.dart';
import 'package:aurogram/services/auth_service.dart';
import 'package:aurogram/services/onboarding_service.dart';
import 'package:aurogram/services/analytics_service.dart';
import 'package:aurogram/services/sky_positions_service.dart';
import 'package:aurogram/pages/astrology/astrology_setup_page.dart';
import 'package:aurogram/pages/login/login.dart';
import 'package:aurogram/pages/onboarding/widgets/zodiac_wheel_painter.dart';
import 'package:aurogram/utils/theme/app_dimensions.dart';

/// FTUE (First Time User Experience) page
/// Shows different states based on login status:
/// - Pre-login: Shows features + "Login to Unlock All" CTA
/// - Post-login: Shows features + "Unlock Astrology" CTA
class FtueWelcome extends StatefulWidget {
  const FtueWelcome({super.key});

  @override
  State<FtueWelcome> createState() => _FtueWelcomeState();
}

class _FtueWelcomeState extends State<FtueWelcome>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  bool _isNavigating = false;
  Map<String, double>? _planetPositions;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..forward();
    _loadSkyPositions();
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
          AppLogger.d('FtueWelcome: Loaded ${planetLongs.length} planet positions', category: LogCategory.ui);
          setState(() => _planetPositions = planetLongs);
        }
      }
    } catch (e) {
      AppLogger.w('FtueWelcome: Failed to load sky positions: $e', category: LogCategory.ui);
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  /// Check if user is logged in
  bool get _isLoggedIn => FirebaseAuth.instance.currentUser != null;

  /// Navigate to login page
  Future<void> _goToLogin() async {
    if (_isNavigating) return;
    setState(() => _isNavigating = true);
    HapticFeedback.mediumImpact();

    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => LoginPage()),
    );

    // User came back from login - check if they logged in
    if (mounted) {
      setState(() => _isNavigating = false);
      // If logged in, the auth state change will trigger a rebuild
      // and show the post-login FTUE or navigate away
    }
  }

  /// Navigate to astro setup
  /// AstrologySetupPage handles navigation to OnboardingComplete after saving
  Future<void> _goToAstroSetup() async {
    if (_isNavigating) return;
    setState(() => _isNavigating = true);
    HapticFeedback.mediumImpact();

    // Navigate to astrology setup page
    // For new setups, AstrologySetupPage will push OnboardingComplete directly
    // User can navigate back through the flow if needed
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const AstrologySetupPage()),
    );

    // User backed out of the flow - stay on FTUE
    if (mounted) {
      setState(() => _isNavigating = false);
    }
  }

  /// Complete FTUE and go home
  /// [targetTab]: 0=HolyCow AI, 1=Messages, 2=Grams, 3=Profile
  Future<void> _completeFtue({int targetTab = 0}) async {
    if (_isNavigating) return;
    setState(() => _isNavigating = true);
    HapticFeedback.lightImpact();

    final authService = context.read<AuthService>();
    authService.initialTabIndex = targetTab;

    if (_isLoggedIn) {
      _markFtueCompleteInFirestore(false);
      authService.updateStatusBasedOnNewUserFlag(false,
          initialTabIndex: targetTab);
    }

    await OnboardingService().markFtueShown();

    // Explicitly navigate back to root (TabHandler) - simple and reliable
    if (mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  void _markFtueCompleteInFirestore(bool hasBirthDetails) {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'ftueCompleted': true,
          'ftueCompletedAt': FieldValue.serverTimestamp(),
        }).catchError((_) {});

        try {
          AnalyticsService()
              .trackFtueCompleted(birthDetailsProvided: hasBirthDetails);
          AnalyticsService().setHasBirthDetails(hasBirthDetails);
        } catch (_) {
          AppLogger.w('FtueWelcome: analytics tracking failed', category: LogCategory.general);
        }
      }
    } catch (_) {
      AppLogger.w('FtueWelcome: FTUE completion save failed', category: LogCategory.general);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      // Never allow back - user must use Skip button or close button
      // Going back would return to init page which is invalid after setup
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        // If user tries to go back, complete FTUE and go to feed instead
        if (!didPop && !_isNavigating) {
          _completeFtue();
        }
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: ResponsiveBuilder(
          builder: (context, isMobile, isTablet, isDesktop) {
            // Use horizontal layout for wide screens
            final isWideScreen = isTablet || isDesktop;

            if (isWideScreen) {
              return _buildWideLayout(isDark, isDesktop);
            }
            return _buildMobileLayout(isDark);
          },
        ),
      ),
    );
  }

  /// Wide screen layout (tablet/desktop) - side by side
  /// Uses Column + Row with Flexible widgets for true responsiveness.
  /// Wrapped in SafeArea so header and close button are below status bar/notch on iPad.
  Widget _buildWideLayout(bool isDark, bool isDesktop) {
    return SafeArea(
      child: Stack(
        children: [
          // Main content
          Column(
            children: [
              // Header row: title and close button aligned (same as mobile)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(width: 40),
                    Expanded(
                      child: Center(
                        child: Text(
                          'Aurogram',
                          style: TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 48,
                      child: IconButton(
                        onPressed: _isNavigating ? null : () => _completeFtue(),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: Icon(
                          Icons.close_rounded,
                          color: _isNavigating
                              ? AppTheme.primaryColor.withValues(alpha: 0.3)
                              : AppTheme.primaryColor.withValues(alpha: 0.6),
                          size: 28,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Mantra below title
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                child: _buildMantra(isDark, isWide: true),
              ),
              const SizedBox(height: AppDimensions.spacingXs),
              // Main content - flexible row with wheel and poem
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // Calculate wheel size
                    final maxSize = constraints.maxWidth < constraints.maxHeight
                        ? constraints.maxWidth
                        : constraints.maxHeight;
                    final wheelSize = (maxSize * 0.75).clamp(150.0, 500.0);

                    // Calculate top offset: center wheel vertically, then shift up more to align with poem
                    final verticalCenter = constraints.maxHeight / 2;
                    final wheelTopOffset =
                        verticalCenter - (wheelSize / 2) - 40;
                    final topOffset =
                        wheelTopOffset.clamp(0.0, double.infinity);

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left side - Zodiac wheel
                        Expanded(
                          flex: 5,
                          child: SizedBox(
                            height: constraints.maxHeight,
                            child: Stack(
                              children: [
                                Positioned(
                                  top: topOffset,
                                  left: 0,
                                  right: 0,
                                  child: Center(
                                    child:
                                        _buildWheelSection(wheelSize, isDark),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Right side - Poem
                        Expanded(
                          flex: 5,
                          child: SizedBox(
                            height: constraints.maxHeight,
                            child: Stack(
                              children: [
                                Positioned(
                                  top: topOffset,
                                  left: 0,
                                  right: 0,
                                  bottom: 0,
                                  child: SingleChildScrollView(
                                    physics: const BouncingScrollPhysics(),
                                    padding: const EdgeInsets.only(bottom: 120),
                                    child: _buildWideContentSection(
                                        isDark, isDesktop),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
          // Bottom button - positioned overlay for transparent glass effect
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: _buildResponsiveButton(isDark),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Wheel section for wide layouts - sized by parent
  Widget _buildWheelSection(double wheelSize, bool isDark) {
    return ZodiacWheelWithIcon(
      wheelSize: wheelSize,
      planetPositions: _planetPositions,
      primaryColor: AppTheme.primaryColor,
      opacity: 1.0,
      animate: true,
    );
  }

  /// Content section for wide layouts (right side) - poem only
  Widget _buildWideContentSection(bool isDark, bool isDesktop) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: _buildPoem(isDark),
      ),
    );
  }

  /// Mobile layout - Stack with scrollable content and overlayed button
  /// Uses Stack + Positioned for transparent button overlay (like login page)
  Widget _buildMobileLayout(bool isDark) {
    return Stack(
      children: [
        // Main scrollable content
        SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: 120, // Space for the overlayed button
            ),
            child: Column(
              children: [
                // Header with logo, title, and close button
                _buildHeader(isDark),
                const SizedBox(height: AppDimensions.spacingSm),
                // Mantra - three-word philosophy
                _buildMantra(isDark),
                const SizedBox(height: AppDimensions.spacingLg),
                // Zodiac wheel - use LayoutBuilder for responsive sizing
                LayoutBuilder(
                  builder: (context, constraints) {
                    // Use available width, but cap at reasonable size
                    final wheelSize =
                        (constraints.maxWidth * 0.85).clamp(150.0, 360.0);

                    return Center(
                      child: ZodiacWheelWithIcon(
                        wheelSize: wheelSize,
                        planetPositions: _planetPositions,
                        primaryColor: AppTheme.primaryColor,
                        opacity: 1.0,
                        animate: true,
                      ),
                    );
                  },
                ),
                const SizedBox(height: AppDimensions.spacingXxl),
                // Full poem
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: _buildPoem(isDark),
                ),
                const SizedBox(height: AppDimensions.spacingLg),
              ],
            ),
          ),
        ),
        // Bottom button - positioned overlay for transparent glass effect
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: _buildResponsiveButton(isDark),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Responsive button with max width constraint
  Widget _buildResponsiveButton(bool isDark) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 400),
      child:
          _isLoggedIn ? _buildAstroButton(isDark) : _buildLoginButton(isDark),
    );
  }

  /// Simple header with title and close button
  Widget _buildHeader(bool isDark) {
    return FadeTransition(
      opacity: CurvedAnimation(parent: _animController, curve: Curves.easeOut),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Spacer for balance
          const SizedBox(width: 40),

          // Title - centered
          Expanded(
            child: Center(
              child: Text(
                'Aurogram',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                  letterSpacing: -0.5,
                ),
              ),
            ),
          ),

          // Close button - top right
          SizedBox(
            width: 40,
            child: IconButton(
              onPressed: _isNavigating ? null : () => _completeFtue(),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: Icon(
                Icons.close_rounded,
                color: _isNavigating
                    ? AppTheme.primaryColor.withValues(alpha: 0.3)
                    : AppTheme.primaryColor.withValues(alpha: 0.6),
                size: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Full poem displayed (no expand/collapse)
  Widget _buildPoem(bool isDark) {
    // Larger font for wide screens
    final isWide = !Responsive.isMobile(context);
    final poemStyle = TextStyle(
      fontSize: isWide ? 17 : 15,
      height: 1.8,
      fontWeight: FontWeight.w600,
      color: AppTheme.primaryColor.withValues(alpha: 0.85),
    );

    return Column(
      children: [
        Text(
          "In people you loved too fast,\n"
          "in places that felt like yours,\n"
          "every song that broke you open,\n"
          "like waves hitting forgotten shores.",
          textAlign: TextAlign.center,
          style: poemStyle,
        ),
        const SizedBox(height: AppDimensions.spacingLg),
        Text(
          "Sunshine of those chilly days,\n"
          "clouds that returned to pour,\n"
          "every season, that came back,\n"
          "like it had been here before.",
          textAlign: TextAlign.center,
          style: poemStyle,
        ),
        const SizedBox(height: AppDimensions.spacingLg),
        Text(
          "Something beneath it all,\n"
          "a pull without a name,\n"
          "almost visible, always moving,\n"
          "a thread through the frame.",
          textAlign: TextAlign.center,
          style: poemStyle,
        ),
        const SizedBox(height: AppDimensions.spacingLg),
        Text(
          "Aurogram lets you read those quiet lines,\n"
          "your chart, your stars, your cosmic designs.",
          textAlign: TextAlign.center,
          style: poemStyle,
        ),
      ],
    );
  }

  /// Mantra section - three-word philosophy
  Widget _buildMantra(bool isDark, {bool isWide = false}) {
    final fontSize = isWide ? 18.0 : 15.0;
    final dotSize = isWide ? 22.0 : 18.0;

    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 0.15),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic),
      )),
      child: FadeTransition(
        opacity: CurvedAnimation(
          parent: _animController,
          curve: const Interval(0.2, 1.0),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingXxl),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildMantraWord('Your stars', AppTheme.cosmicPurple, fontSize),
              _buildMantraDot(dotSize),
              _buildMantraWord('Your vibe', AppTheme.primaryColor, fontSize),
              _buildMantraDot(dotSize),
              _buildMantraWord('Your gram', AppTheme.emeraldGreen, fontSize),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMantraWord(String text, Color color, double fontSize) {
    return Text(
      text,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w600,
        color: color,
        letterSpacing: -0.2,
      ),
    );
  }

  Widget _buildMantraDot(double size) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Text(
        '·',
        style: TextStyle(
          fontSize: size,
          fontWeight: FontWeight.bold,
          color: AppTheme.primaryColor.withValues(alpha: 0.3),
        ),
      ),
    );
  }

  /// Login button for pre-login state
  Widget _buildLoginButton(bool isDark) {
    final isEnabled = !_isNavigating;

    return GestureDetector(
      onTap: isEnabled ? _goToLogin : null,
      child: TransparentToolbox(
        content: Opacity(
          opacity: isEnabled ? 1.0 : 0.5,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Login icon
              Icon(
                Icons.login_rounded,
                color: AppTheme.primaryColor,
                size: 22,
              ),
              const SizedBox(width: AppDimensions.spacingMd),
              // Text
              Text(
                _isNavigating ? 'Loading...' : 'Login to Unlock All Features',
                style: TextStyle(
                  color: AppTheme.primaryColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Astrology button for post-login state
  Widget _buildAstroButton(bool isDark) {
    final isEnabled = !_isNavigating;

    // Deep indigo/night sky colors
    final nightSkyColor = isDark
        ? const Color(0xFF4F46E5) // Lighter indigo in dark mode for contrast
        : const Color(0xFF312E81); // Deep indigo in light mode
    final starColor = isDark
        ? const Color(0xFFFCD34D) // Warm yellow stars
        : const Color(0xFFFBBF24);

    return GestureDetector(
      onTap: isEnabled ? _goToAstroSetup : null,
      child: TransparentToolbox(
        content: Opacity(
          opacity: isEnabled ? 1.0 : 0.5,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Star icon
              Icon(
                Icons.auto_awesome_rounded,
                color: starColor,
                size: 20,
              ),
              const SizedBox(width: AppDimensions.spacingMd),
              // Text
              Expanded(
                child: Text(
                  _isNavigating ? 'Loading...' : 'Unlock Astrology',
                  style: TextStyle(
                    color: nightSkyColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              // Chevron
              Icon(
                Icons.chevron_right_rounded,
                color: nightSkyColor.withValues(alpha: 0.7),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
