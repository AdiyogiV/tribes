import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:aurogram/features/profile/domain/user_service.dart';
import 'package:aurogram/core/logging/app_logger.dart';
import 'package:aurogram/shared/presentation/responsive/responsive.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/shared/presentation/widgets/universal/transparent_toolbox.dart';
import 'package:aurogram/core/routing/route_names.dart';
import 'package:aurogram/shared/presentation/widgets/feedback/snack_bar_service.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';

class InitUser extends StatefulWidget {
  const InitUser({super.key});

  @override
  InitUserState createState() => InitUserState();
}

// Intent class for Enter key handling
class _ContinueIntent extends Intent {
  const _ContinueIntent();
}

class InitUserState extends State<InitUser>
    with SingleTickerProviderStateMixin {
  final _nameController = TextEditingController();
  String? _username;
  bool _isLoading = false;

  /// Incremented on every call so stale async completions are ignored.
  int _usernameCallId = 0;

  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Warm greeting based on time of day
  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    if (hour < 21) return 'Good evening';
    return 'Welcome';
  }

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_generateUsername);

    _animController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
        CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic));

    _animController.forward();
  }

  void _generateUsername() async {
    // Capture the call ID before any await so stale completions can be discarded.
    final callId = ++_usernameCallId;

    final name = _nameController.text.trim();
    if (name.isEmpty) {
      if (mounted) setState(() => _username = null);
      return;
    }

    final base = name.split(' ')[0].toLowerCase();
    final random = Random();

    try {
      // Fetch the nicknames document ONCE instead of once per candidate.
      final doc = await FirebaseFirestore.instance
          .collection('nicknames')
          .doc('pairs')
          .get();

      // Discard if the user has typed more since this call started.
      if (callId != _usernameCallId || !mounted) return;

      final existing = doc.exists ? (doc.data() ?? {}) : <String, dynamic>{};

      for (int i = 0; i < 50; i++) {
        final candidate = '$base${random.nextInt(9000) + 1000}';
        if (!existing.containsKey(candidate)) {
          if (callId == _usernameCallId && mounted) {
            setState(() => _username = candidate);
          }
          return;
        }
      }

      // All 50 random candidates collided — use a timestamp-based fallback.
      final fallback =
          '$base${DateTime.now().millisecondsSinceEpoch % 10000}';
      if (callId == _usernameCallId && mounted) {
        setState(() => _username = fallback);
      }
    } catch (e) {
      // Firestore unavailable — still unblock the user with an offline fallback.
      AppLogger.w('Username generation Firestore read failed — using offline fallback',
          category: LogCategory.auth, data: {'error': e.toString()});
      if (callId != _usernameCallId || !mounted) return;
      final fallback = '$base${random.nextInt(9000) + 1000}';
      setState(() => _username = fallback);
    }
  }

  Future<void> _continue() async {
    if (_nameController.text.trim().isEmpty || _username == null || _isLoading) {
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() => _isLoading = true);

    try {
      final success = await UserService().registerNewUser(
        _nameController.text.trim(),
        _username!,
        null,
      );

      if (!success) {
        if (mounted) {
          showCustomSnackBar(context, message: 'Failed. Please try again.');
          setState(() => _isLoading = false);
        }
        return;
      }

      if (mounted) {
        // Go straight to birth-details setup (poem/FTUE welcome removed).
        // Use push (not pushReplacement) so TabHandler remains the root route;
        // when onboarding completes, popUntil(route.isFirst) returns here and
        // TabHandler rebuilds with Authenticated status to show the tabs.
        context.push(RouteNames.astrologySetup);
      }
    } catch (e) {
      AppLogger.e('Profile error', category: LogCategory.auth, error: e);
      if (mounted) {
        showCustomSnackBar(context, message: 'Something went wrong.');
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canContinue =
        _nameController.text.trim().isNotEmpty && _username != null;
    final name = _nameController.text.trim();

    return Shortcuts(
      shortcuts: {
        if (canContinue && !_isLoading)
          LogicalKeySet(LogicalKeyboardKey.enter): _ContinueIntent(),
      },
      child: Actions(
        actions: {
          _ContinueIntent: CallbackAction<_ContinueIntent>(
            onInvoke: (_) {
              if (canContinue && !_isLoading) {
                _continue();
              }
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: Scaffold(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              resizeToAvoidBottomInset: true,
              body: ResponsiveBuilder(
                builder: (context, isMobile, isTablet, isDesktop) {
                  final isWideScreen = isTablet || isDesktop;

                  if (isWideScreen) {
                    return _buildWideLayout(name, canContinue, isDesktop);
                  }
                  return _buildMobileLayout(name, canContinue);
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Wide screen layout (tablet/desktop) - centered card style
  Widget _buildWideLayout(String name, bool canContinue, bool isDesktop) {
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: isDesktop ? 520 : 480),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: AppDimensions.spacingLargeSection),
                    _buildHeader(name),
                    const SizedBox(height: 48),
                    // Toolboxes in flow (not positioned)
                    _buildNameEntryToolbox(),
                    const SizedBox(height: AppDimensions.spacingLg),
                    _buildContinueToolbox(canContinue),
                    const SizedBox(height: AppDimensions.spacingLargeSection),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Mobile layout - original vertical stack with positioned bottom
  Widget _buildMobileLayout(String name, bool canContinue) {
    return Stack(
      children: [
        // Main content
        SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 200),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: AppDimensions.spacingHero),
                    _buildHeader(name),
                    const SizedBox(height: AppDimensions.spacingLargeSection),
                  ],
                ),
              ),
            ),
          ),
        ),
        // Bottom toolboxes
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: _buildBottomToolboxes(canContinue, name),
        ),
      ],
    );
  }

  Widget _buildHeader(String name) {
    return Column(
      children: [
        // App icon
        Container(
          height: 100,
          width: 100,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDimensions.radiusXxl),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppDimensions.radiusXxl),
            child: Image.asset(
              'assets/images/icon_transparent.png',
              fit: BoxFit.contain,
            ),
          ),
        ),
        const SizedBox(height: AppDimensions.spacingSection),

        // Dynamic greeting
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: Text(
            name.isEmpty ? '$_greeting!' : 'Hello, $name!',
            key: ValueKey(name.isEmpty ? 'greeting' : 'name'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  fontSize: 32,
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
          ),
        ),

        const SizedBox(height: AppDimensions.spacingMd),

        // Subtitle
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: Text(
            name.isEmpty
                ? "What should we call you?"
                : "Let's get you started.",
            key: ValueKey(name.isEmpty ? 'ask' : 'confirm'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              color: AppTheme.primaryColor.withValues(alpha: 0.75),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomToolboxes(bool canContinue, String name) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.zero,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Name entry toolbox
            _buildNameEntryToolbox(),

            // Continue button toolbox
            _buildContinueToolbox(canContinue),
          ],
        ),
      ),
    );
  }

  Widget _buildNameEntryToolbox() {
    return TransparentToolbox(
      content: Row(
        children: [
          Icon(
            Icons.person_outline_rounded,
            color: AppTheme.primaryColor.withValues(alpha: 0.85),
            size: 24,
          ),
          const SizedBox(width: AppDimensions.spacingMd),
          Expanded(
            child: TextField(
              controller: _nameController,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) {
                FocusScope.of(context).unfocus();
                if (_nameController.text.trim().isNotEmpty &&
                    _username != null) {
                  _continue();
                }
              },
              decoration: InputDecoration(
                hintText: 'Enter your name',
                hintStyle: TextStyle(
                  color: AppTheme.primaryColor.withValues(alpha: 0.5),
                  fontSize: 16,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                contentPadding: EdgeInsets.zero,
              ),
              style: TextStyle(
                color: AppTheme.primaryColor.withValues(alpha: 0.9),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          // Clear button
          if (_nameController.text.isNotEmpty)
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                _nameController.clear();
              },
              child: Icon(
                Icons.close_rounded,
                color: AppTheme.primaryColor.withValues(alpha: 0.4),
                size: 20,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildContinueToolbox(bool canContinue) {
    return TransparentToolbox.button(
      text: 'Continue',
      onTap: _continue,
      isLoading: _isLoading,
      enabled: canContinue,
      icon: Icons.arrow_forward_rounded,
    );
  }
}
