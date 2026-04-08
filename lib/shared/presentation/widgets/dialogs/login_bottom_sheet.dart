import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'package:aurogram/features/auth/login.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/widgets/universal/transparent_toolbox.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';

/// Minimal login bottom sheet
class LoginBottomSheet extends StatefulWidget {
  final String? contextMessage;

  const LoginBottomSheet({
    super.key,
    this.contextMessage,
  });

  @override
  State<LoginBottomSheet> createState() => _LoginBottomSheetState();
}

class _LoginBottomSheetState extends State<LoginBottomSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    ));
    
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _goToLogin() {
    HapticFeedback.mediumImpact();
    Navigator.of(context).pop();
    Navigator.of(context).push(
      CupertinoPageRoute(builder: (_) => LoginPage()),
    );
  }

  void _dismiss() {
    HapticFeedback.lightImpact();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _dismiss,
      child: Material(
        color: Colors.transparent,
        child: Stack(
          children: [
            // Blurred backdrop
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                color: Colors.black.withValues(alpha: 0.25),
              ),
            ),
            
            // Logo - centered in page
            Center(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppDimensions.radiusXxl),
                  child: Image.asset(
                    'assets/images/icon_transparent.png',
                    width: 120,
                    height: 120,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            
            // Bottom buttons
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: GestureDetector(
                onTap: () {},
                child: SlideTransition(
                  position: _slideAnimation,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: SafeArea(
                      child: Padding(
                        padding: EdgeInsets.zero,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Login button
                            GestureDetector(
                              onTap: _goToLogin,
                              child: TransparentToolbox(
                                content: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.login_rounded,
                                      color: AppTheme.primaryColor,
                                      size: AppTheme.iconSizeS,
                                    ),
                                    const SizedBox(width: AppDimensions.spacingMdSm),
                                    Text(
                                      'Login to Continue',
                                      style: TextStyle(
                                        color: AppTheme.primaryColor,
                                        fontSize: AppTheme.fontSizeL,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            
                            // Maybe later
                            GestureDetector(
                              onTap: _dismiss,
                              child: TransparentToolbox(
                                content: Center(
                                  child: Text(
                                    'Maybe Later',
                                    style: TextStyle(
                                      color: AppTheme.primaryMedium, // Uses opacityMedium (0.6)
                                      fontSize: AppTheme.fontSizeRegular,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
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

/// Show the minimal login bottom sheet
void showLoginBottomSheet(
  BuildContext context, {
  String? contextMessage,
  IconData? featureIcon,
  String? featureName,
}) {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Login',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 150),
    pageBuilder: (context, animation, secondaryAnimation) {
      return LoginBottomSheet(contextMessage: contextMessage);
    },
  );
}
