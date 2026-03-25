import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:aurogram/services/auth_service.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:aurogram/utils/theme/header_style.dart';
import 'package:aurogram/utils/theme/theme_helper.dart';
import 'package:aurogram/utils/responsive.dart';
import 'package:country_code_picker/country_code_picker.dart';
import 'package:aurogram/widgets/universal/transparent_toolbox.dart';
import 'dart:ui';

class LoginPage extends StatefulWidget {
  /// When true, shows a back button (e.g. when pushed as a route).
  /// When false, no back button (e.g. when used as a tab).
  final bool showBackButton;

  const LoginPage({super.key, this.showBackButton = true});

  @override
  LoginPageState createState() => LoginPageState();
}

class LoginPageState extends State<LoginPage> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _countryCode = TextEditingController(text: '+91');
  String? _verificationId;
  ConfirmationResult? _confirmationResult; // For web phone auth
  bool _codeSent = false;
  bool _isLoading = false;
  bool _isVerifyingOTP = false;
  bool _eulaAccepted = false; // EULA acceptance required for App Store compliance

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    _countryCode.dispose();
    super.dispose();
  }

  Future<void> _verifyOTP() async {
    if (_otpController.text.isEmpty) {
      _showErrorDialog('Please enter the OTP');
      return;
    }

    // Check for required verification state
    if (kIsWeb) {
      if (_confirmationResult == null) {
        _showErrorDialog(
            'Verification session expired. Please request a new code.');
        return;
      }
    } else {
      if (_verificationId == null) {
        _showErrorDialog(
            'Verification ID is missing. Please request a new code.');
        return;
      }
    }

    setState(() {
      _isVerifyingOTP = true;
    });

    try {
      if (kIsWeb) {
        // Web: Use confirmation result to confirm OTP
        await _confirmationResult!.confirm(_otpController.text);
      } else {
        // Mobile: Use signInWithOTP
        await Provider.of<AuthService>(context, listen: false)
            .signInWithOTP(_otpController.text, _verificationId!);
      }
      // Wait for a short duration to allow auth state to update
      await Future.delayed(Duration(seconds: 1));
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() {
        _isVerifyingOTP = false;
      });
      String errorMessage = 'Invalid OTP. Please try again.';

      // Check for FirebaseAuthException with specific error codes
      if (e is FirebaseAuthException) {
        switch (e.code) {
          case 'invalid-verification-code':
            errorMessage =
                'Invalid verification code. Please check and try again.';
            break;
          case 'invalid-verification-id':
            errorMessage =
                'Verification session expired. Please request a new code.';
            break;
          case 'session-expired':
            errorMessage =
                'Verification session expired. Please request a new code.';
            break;
          case 'network-request-failed':
            errorMessage =
                'Network error. Please check your connection and try again.';
            break;
          case 'too-many-requests':
            errorMessage = 'Too many attempts. Please try again later.';
            break;
          default:
            errorMessage =
                e.message ?? 'Verification failed. Please try again.';
        }
      } else {
        // Fallback for non-FirebaseAuthException errors
        final errorString = e.toString().toLowerCase();
        if (errorString.contains('invalid-verification-code') ||
            errorString.contains('invalid verification')) {
          errorMessage =
              'Invalid verification code. Please check and try again.';
        } else if (errorString.contains('session-expired') ||
            errorString.contains('expired')) {
          errorMessage =
              'Verification session expired. Please request a new code.';
        } else if (errorString.contains('network')) {
          errorMessage =
              'Network error. Please check your connection and try again.';
        }
      }
      _showErrorDialog(errorMessage);
    }
  }

  /// Web-specific phone verification using reCAPTCHA
  Future<void> _verifyPhoneWeb(String phoneNumber) async {
    try {
      // Use signInWithPhoneNumber for web with automatic reCAPTCHA
      _confirmationResult = await FirebaseAuth.instance.signInWithPhoneNumber(
        phoneNumber,
        // RecaptchaVerifier is automatically handled by Firebase on web
      );

      if (!mounted) return;
      setState(() {
        _codeSent = true;
        _isLoading = false;
      });
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      String errorMessage = e.message ?? 'Verification failed';
      if (e.code == 'too-many-requests') {
        errorMessage = 'Too many attempts. Please try again later.';
      } else if (e.code == 'invalid-phone-number') {
        errorMessage = 'Invalid phone number format.';
      }
      _showErrorDialog(errorMessage);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      _showErrorDialog('Verification failed. Please try again.');
    }
  }

  Future<void> _verifyPhone() async {
    if (_phoneController.text.isEmpty || _countryCode.text.isEmpty) {
      _showErrorDialog('Please enter a valid phone number');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final phoneNumber = '${_countryCode.text}${_phoneController.text}';

    try {
      // Web uses signInWithPhoneNumber with reCAPTCHA
      if (kIsWeb) {
        await _verifyPhoneWeb(phoneNumber);
        return;
      }

      // Mobile uses verifyPhoneNumber with SMS auto-retrieval
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          if (!mounted) return;
          setState(() {
            _isLoading = false;
          });
          try {
            await Provider.of<AuthService>(context, listen: false)
                .signIn(credential);
            if (mounted) {
              Navigator.of(context).pop();
            }
          } catch (e) {
            if (mounted) {
              _showErrorDialog(
                  'Auto-verification failed. Please enter the code manually.');
            }
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          if (!mounted) return;
          setState(() {
            _isLoading = false;
          });
          _showErrorDialog(e.message ?? 'Verification failed');
        },
        codeSent: (String verificationId, int? resendToken) {
          if (!mounted) return;
          setState(() {
            _verificationId = verificationId;
            _codeSent = true;
            _isLoading = false;
          });
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
          if (!mounted) return;
          setState(() {
            _isLoading = false;
          });
        },
        timeout: const Duration(seconds: 120),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      _showErrorDialog('Error: ${e.toString()}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        resizeToAvoidBottomInset: true,
        appBar: AppHeaderStyle.buildStandardAppBar(
          context: context,
          title: 'login',
          automaticallyImplyLeading: false,
          leadingWidget: widget.showBackButton
              ? BackButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                )
              : null,
        ),
        body: ResponsiveBuilder(
          builder: (context, isMobile, isTablet, isDesktop) {
            final isWideScreen = isTablet || isDesktop;

            if (isWideScreen) {
              return _buildWideLayout(isDesktop);
            }
            return _buildMobileLayout();
          },
        ),
      ),
    );
  }

  /// Wide screen layout (tablet/desktop) - centered card style
  Widget _buildWideLayout(bool isDesktop) {
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: isDesktop ? 480 : 420),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: AppHeaderStyle.contentTopPadding),
                const SizedBox(height: 24),
                _buildBenefitsStrip(isWide: true),
                const SizedBox(height: 24),
                _buildBrandHeader(isWide: true),
                const SizedBox(height: 32),
                _buildPolicyText(),
                const SizedBox(height: 32),
                _buildSubtitle(isWide: true),
                const SizedBox(height: 40),
                // Toolboxes in card - no longer positioned, just in flow
                _buildResponsiveToolboxes(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Mobile layout – clean structure with proper keyboard handling
  Widget _buildMobileLayout() {
    final mediaQuery = MediaQuery.of(context);
    final safeBottom = mediaQuery.padding.bottom;

    // Toolbox measurements
    const double singleToolboxHeight = 70.0;
    const double toolboxCount = 3.0;
    const double totalToolboxHeight = singleToolboxHeight * toolboxCount;

    // Bottom padding when keyboard is closed
    final double closedBottomPadding = widget.showBackButton
        ? (safeBottom > 0 ? safeBottom : 16.0) // Pushed: safe area or 16
        : AppHeaderStyle.contentBottomPadding; // Tabs: 120 for tab bar

    // Content padding to prevent overlap
    final double contentBottomPadding =
        totalToolboxHeight + closedBottomPadding + 16.0;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Scrollable content
        SingleChildScrollView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          child: Padding(
            padding: EdgeInsets.only(
              top: AppHeaderStyle.contentTopPadding,
              bottom: contentBottomPadding,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 12),
                _buildBenefitsStrip(isWide: false),
                const SizedBox(height: 24),
                _buildBrandHeader(isWide: false),
                const SizedBox(height: 32),
                _buildPolicyText(),
                const SizedBox(height: 32),
                _buildSubtitle(isWide: false),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),

        // Fixed toolboxes at bottom (let Scaffold handle keyboard insets)
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: _buildBottomToolboxes(),
            ),
          ),
        ),
      ],
    );
  }

  /// Responsive toolboxes for wide layout (in flow, not positioned)
  Widget _buildResponsiveToolboxes() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // First toolbox: Country code picker OR Change number
        _codeSent ? _buildChangeNumberToolbox() : _buildCountryCodeToolbox(),
        // Second toolbox: Phone entry OR OTP entry (transforms)
        _codeSent ? _buildOTPEntryToolbox() : _buildPhoneEntryToolbox(),
        // Third toolbox: Send verification OR Verify OTP
        _codeSent ? _buildVerifyOTPToolbox() : _buildSendVerificationToolbox(),
      ],
    );
  }

  Widget _buildSubtitle({required bool isWide}) {
    if (!_codeSent) {
      return const SizedBox.shrink();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _codeSent
              ? 'Enter the verification code sent to your phone'
              : 'Sign in with your phone number',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppTheme.primaryColor.withValues(alpha: 0.9),
                fontWeight: FontWeight.w400,
                fontSize: isWide ? 15 : 16,
                height: 1.4,
              ),
        ),
      ],
    );
  }

  Widget _buildBrandHeader({required bool isWide}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 12),
        Text(
          'welcome to aurogram',
          textAlign: TextAlign.center,
          style: ThemeHelper.headerStyle.copyWith(
            fontWeight: FontWeight.w900,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildBenefitsStrip({required bool isWide}) {
    final double iconSize = isWide ? 72 : 64;

    return Wrap(
      alignment: WrapAlignment.center,
      runSpacing: 16,
      spacing: 10,
      children: [
        _buildIconOnly(
          child: Image.asset(
            'assets/icons/namaste.png',
            width: iconSize,
            height: iconSize,
            fit: BoxFit.contain,
          ),
        ),
        _buildIconOnly(
          child: Image.asset(
            'assets/images/icon_transparent.png',
            width: iconSize,
            height: iconSize,
            fit: BoxFit.contain,
          ),
        ),
        _buildIconOnly(
          child: Image.asset(
            'assets/images/cow1.png',
            width: iconSize,
            height: iconSize,
            fit: BoxFit.contain,
          ),
        ),
      ],
    );
  }

  Widget _buildIconOnly({required Widget child}) {
    return child;
  }

  Widget _buildPolicyText() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          // EULA Acceptance Checkbox
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: _eulaAccepted,
                onChanged: (value) {
                  setState(() {
                    _eulaAccepted = value ?? false;
                  });
                },
                activeColor: AppTheme.primaryColor,
                checkColor: Colors.white,
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _eulaAccepted = !_eulaAccepted;
                    });
                  },
                  child: Text(
                    'I agree to the Terms of Service, Privacy Policy, and Community Guidelines',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.primaryColor,
                          fontSize: 14,
                          height: 1.4,
                        ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.center,
            runSpacing: 8,
            children: [
              GestureDetector(
                onTap: () => _showPolicyDialog('Community Guidelines'),
                child: Text(
                  'Community Guidelines',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w500,
                        fontSize: 15,
                        decoration: TextDecoration.underline,
                      ),
                ),
              ),
              Text(
                '  •  ',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondaryLightColor,
                      fontSize: 15,
                    ),
              ),
              GestureDetector(
                onTap: () => _showPolicyDialog('Privacy Policy'),
                child: Text(
                  'Privacy Policy',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w500,
                        fontSize: 15,
                        decoration: TextDecoration.underline,
                      ),
                ),
              ),
              Text(
                '  •  ',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondaryLightColor,
                      fontSize: 15,
                    ),
              ),
              GestureDetector(
                onTap: () => _showPolicyDialog('Terms of Service'),
                child: Text(
                  'Terms of Service',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w500,
                        fontSize: 15,
                        decoration: TextDecoration.underline,
                      ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomToolboxes() {
    // Apply SafeArea once, then remove per-toolbox padding to avoid gaps.
    return SafeArea(
      top: false,
      left: false,
      right: false,
      child: MediaQuery.removePadding(
        context: context,
        removeTop: true,
        removeBottom: true,
        removeLeft: true,
        removeRight: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _codeSent
                ? _buildChangeNumberToolbox()
                : _buildCountryCodeToolbox(),
            _codeSent ? _buildOTPEntryToolbox() : _buildPhoneEntryToolbox(),
            _codeSent
                ? _buildVerifyOTPToolbox()
                : _buildSendVerificationToolbox(),
          ],
        ),
      ),
    );
  }

  Widget _buildCountryCodeToolbox() {
    return TransparentToolbox(
      content: Center(
        child: CountryCodePicker(
          onChanged: (code) {
            setState(() {
              _countryCode.text = code.toString();
            });
          },
          initialSelection: '+91',
          favorite: ['+91'],
          showCountryOnly: false,
          showOnlyCountryWhenClosed: true,
          alignLeft: false,
          padding: EdgeInsets.symmetric(horizontal: 16),
          textStyle: TextStyle(
            color: AppTheme.primaryColor.withValues(alpha: 0.85),
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildSendVerificationToolbox() {
    return TransparentToolbox.button(
      text: 'Send Verification Code',
      onTap: _eulaAccepted ? _verifyPhone : null,
      isLoading: _isLoading,
      icon: Icons.arrow_forward,
      enabled: _eulaAccepted,
    );
  }

  Widget _buildPhoneEntryToolbox() {
    return TransparentToolbox(
      content: Row(
        children: [
          // Country code display
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _countryCode.text,
              style: TextStyle(
                color: AppTheme.primaryColor.withValues(alpha: 0.85),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(width: 12),
          // Phone number input
          Expanded(
            child: TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) {
                if (!_isLoading &&
                    _phoneController.text.isNotEmpty &&
                    _countryCode.text.isNotEmpty) {
                  _verifyPhone();
                } else {
                  FocusScope.of(context).unfocus();
                }
              },
              decoration: InputDecoration(
                hintText: 'Enter phone number',
                hintStyle: TextStyle(
                  color: AppTheme.primaryColor.withValues(alpha: 0.6),
                  fontSize: 16,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 0,
                  vertical: 0,
                ),
              ),
              style: TextStyle(
                color: AppTheme.primaryColor.withValues(alpha: 0.85),
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOTPEntryToolbox() {
    return TransparentToolbox(
      content: Row(
        children: [
          Icon(
            Icons.security,
            color: AppTheme.primaryColor.withValues(alpha: 0.85),
            size: 24,
          ),
          SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) {
                if (!_isVerifyingOTP && _otpController.text.isNotEmpty) {
                  _verifyOTP();
                } else {
                  FocusScope.of(context).unfocus();
                }
              },
              decoration: InputDecoration(
                hintText: 'Enter OTP code',
                hintStyle: TextStyle(
                  color: AppTheme.primaryColor.withValues(alpha: 0.6),
                  fontSize: 16,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 0,
                  vertical: 0,
                ),
              ),
              style: TextStyle(
                color: AppTheme.primaryColor.withValues(alpha: 0.85),
                fontSize: 16,
                letterSpacing: 2.0, // Better spacing for OTP
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChangeNumberToolbox() {
    return TransparentToolbox(
      content: GestureDetector(
        onTap: _isVerifyingOTP
            ? null
            : () {
                setState(() {
                  _codeSent = false;
                  _phoneController.clear();
                  _otpController.clear();
                });
              },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.edit,
              color: AppTheme.primaryColor.withValues(alpha: 0.85),
              size: 20,
            ),
            SizedBox(width: 8),
            Text(
              'Change Phone Number',
              style: TextStyle(
                color: AppTheme.primaryColor.withValues(alpha: 0.85),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVerifyOTPToolbox() {
    return TransparentToolbox.button(
      text: 'Verify Code',
      onTap: _verifyOTP,
      isLoading: _isVerifyingOTP,
      icon: Icons.check,
    );
  }

  void _showPolicyDialog(String policyType) {
    String title;
    String content;

    switch (policyType) {
      case 'Community Guidelines':
        title = 'Community Guidelines';
        content = '''Aurogram is a safe, respectful space for everyone.

• Be kind
• Be respectful
• No harassment
• No bullying
• No hate speech
• Content appropriate for all ages
• Welcome new members
• Report bad behaviour
• No impersonation
• No scams

We're here to make Aurogram a place you can trust.''';
        break;
      case 'Privacy Policy':
        title = 'Privacy Policy';
        content = '''Your privacy matters to us.

• We collect only what's needed
• We never sell your data
• Data is encrypted
• Stored securely
• You can delete anytime
• You control your account
• No third-party data sharing
• Minimal analytics
• Location only when you allow
• Transparent about what we use

We're committed to keeping your information safe.''';
        break;
      case 'Terms of Service':
        title = 'Terms of Service';
        content =
            '''By using Aurogram, you agree to use it respectfully and lawfully.

ZERO TOLERANCE POLICY:
• We have zero tolerance for objectionable content or abusive users
• Objectionable content includes harassment, threats, hate speech, explicit content, or any content that violates community standards
• Users who violate these terms will be immediately removed from the platform
• We act on reports within 24 hours by removing content and ejecting offending users

USER RESPONSIBILITIES:
• Use services in good faith
• Respect others' privacy
• Respect others' rights
• No spam
• No misuse
• No illegal activity
• No fake accounts
• Follow the law
• Report objectionable content immediately

MODERATION:
• We may suspend or permanently ban rule-breakers
• All user-generated content is subject to review
• We reserve the right to remove any content that violates these terms

We're here to keep Aurogram safe for everyone.''';
        break;
      default:
        return;
    }

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.3),
      builder: (context) => _TransparentPolicyDialog(
        title: title,
        content: content,
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(
              Icons.error_outline,
              color: AppTheme.errorColor,
              size: 24,
            ),
            SizedBox(width: 12),
            Text(
              'Error',
              style: TextStyle(
                color: AppTheme.errorColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.primaryColor,
            ),
            child: Text(
              'OK',
              style: TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Transparent policy dialog that matches the TransparentToolbox styling
class _TransparentPolicyDialog extends StatelessWidget {
  final String title;
  final String content;

  const _TransparentPolicyDialog({
    required this.title,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color barBase =
        isDark ? Theme.of(context).colorScheme.surface : Colors.white;
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth > 600;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * (isWide ? 0.7 : 0.8),
          maxWidth: isWide ? 500 : screenWidth * 0.9,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Material(
          elevation: 4,
          color: Colors.transparent,
          shadowColor: Colors.black.withValues(alpha: 0.04),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          clipBehavior: Clip.antiAlias,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    barBase.withValues(alpha: isDark ? 0.85 : 0.95),
                    barBase.withValues(alpha: isDark ? 0.80 : 0.90),
                  ],
                ),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.10)
                      : barBase.withValues(alpha: 0.32),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.fromLTRB(28, 28, 28, 20),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(
                                  color: AppTheme.primaryColor,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 22,
                                ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: Icon(
                            Icons.close,
                            color: AppTheme.primaryColor,
                            size: 24,
                          ),
                          style: IconButton.styleFrom(
                            backgroundColor:
                                AppTheme.primaryColor.withValues(alpha: 0.1),
                            shape: const CircleBorder(),
                            padding: EdgeInsets.all(8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Content
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(28, 0, 28, 32),
                      child: DefaultTextStyle(
                        style: TextStyle(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.w400,
                          fontSize: 18,
                          height: 1.5,
                        ),
                        child: Text(content),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
