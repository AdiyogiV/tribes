import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:aurogram/features/auth/auth_service.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/core/theme/header_style.dart';
import 'package:aurogram/shared/presentation/responsive/responsive.dart';
import 'package:aurogram/features/auth/login_widgets.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';

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
        await _confirmationResult!.confirm(_otpController.text);
      } else {
        await Provider.of<AuthService>(context, listen: false)
            .signInWithOTP(_otpController.text, _verificationId!);
      }
      await Future.delayed(Duration(seconds: 1));
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() {
        _isVerifyingOTP = false;
      });
      String errorMessage = 'Invalid OTP. Please try again.';

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
      _confirmationResult = await FirebaseAuth.instance.signInWithPhoneNumber(
        phoneNumber,
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
      if (kIsWeb) {
        await _verifyPhoneWeb(phoneNumber);
        return;
      }

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

  void _handleChangeNumber() {
    setState(() {
      _codeSent = false;
      _phoneController.clear();
      _otpController.clear();
    });
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
                const SizedBox(height: AppDimensions.spacingXxl),
                LoginBenefitsStrip(isWide: true),
                const SizedBox(height: AppDimensions.spacingXxl),
                LoginBrandHeader(isWide: true),
                const SizedBox(height: AppDimensions.spacingSection),
                LoginPolicyText(
                  eulaAccepted: _eulaAccepted,
                  onEulaChanged: (v) => setState(() => _eulaAccepted = v),
                  onShowPolicy: (type) => showPolicyDialog(context, type),
                ),
                const SizedBox(height: AppDimensions.spacingSection),
                LoginSubtitle(isWide: true, codeSent: _codeSent),
                const SizedBox(height: AppDimensions.spacingLargeSection),
                _buildToolboxColumn(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Mobile layout - clean structure with proper keyboard handling
  Widget _buildMobileLayout() {
    final mediaQuery = MediaQuery.of(context);
    final safeBottom = mediaQuery.padding.bottom;

    const double singleToolboxHeight = 70.0;
    const double toolboxCount = 3.0;
    const double totalToolboxHeight = singleToolboxHeight * toolboxCount;

    final double closedBottomPadding = widget.showBackButton
        ? (safeBottom > 0 ? safeBottom : 16.0)
        : AppHeaderStyle.contentBottomPadding;

    final double contentBottomPadding =
        totalToolboxHeight + closedBottomPadding + 16.0;

    return Stack(
      fit: StackFit.expand,
      children: [
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
                const SizedBox(height: AppDimensions.spacingMd),
                LoginBenefitsStrip(isWide: false),
                const SizedBox(height: AppDimensions.spacingXxl),
                LoginBrandHeader(isWide: false),
                const SizedBox(height: AppDimensions.spacingSection),
                LoginPolicyText(
                  eulaAccepted: _eulaAccepted,
                  onEulaChanged: (v) => setState(() => _eulaAccepted = v),
                  onShowPolicy: (type) => showPolicyDialog(context, type),
                ),
                const SizedBox(height: AppDimensions.spacingSection),
                LoginSubtitle(isWide: false, codeSent: _codeSent),
                const SizedBox(height: AppDimensions.spacingLargeSection),
              ],
            ),
          ),
        ),

        // Fixed toolboxes at bottom
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: SafeArea(
                top: false,
                left: false,
                right: false,
                child: MediaQuery.removePadding(
                  context: context,
                  removeTop: true,
                  removeBottom: true,
                  removeLeft: true,
                  removeRight: true,
                  child: _buildToolboxColumn(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Shared toolbox column used by both layouts.
  Widget _buildToolboxColumn() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _codeSent
            ? ChangeNumberToolbox(
                isVerifyingOTP: _isVerifyingOTP,
                onChangeNumber: _handleChangeNumber,
              )
            : CountryCodeToolbox(
                countryCode: _countryCode,
                onChanged: (code) =>
                    setState(() => _countryCode.text = code),
              ),
        _codeSent
            ? OTPEntryToolbox(
                otpController: _otpController,
                isVerifyingOTP: _isVerifyingOTP,
                onSubmitted: _verifyOTP,
              )
            : PhoneEntryToolbox(
                phoneController: _phoneController,
                countryCode: _countryCode,
                isLoading: _isLoading,
                onSubmitted: _verifyPhone,
              ),
        _codeSent
            ? VerifyOTPToolbox(
                onTap: _verifyOTP,
                isVerifyingOTP: _isVerifyingOTP,
              )
            : SendVerificationToolbox(
                onTap: _verifyPhone,
                isLoading: _isLoading,
                enabled: _eulaAccepted,
              ),
      ],
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        ),
        title: Row(
          children: [
            Icon(
              Icons.error_outline,
              color: AppTheme.errorColor,
              size: 24,
            ),
            SizedBox(width: AppDimensions.spacingMd),
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
