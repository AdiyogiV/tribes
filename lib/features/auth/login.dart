import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:aurogram/features/auth/auth_service.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/core/theme/header_style.dart';
import 'package:aurogram/shared/presentation/responsive/responsive.dart';
import 'package:aurogram/features/auth/login_widgets.dart';
import 'package:aurogram/features/auth/baba_login_tools.dart';
import 'package:aurogram/features/baba/domain/baba_tool_registry.dart';
import 'package:aurogram/features/baba/domain/baba_context.dart';
import 'package:aurogram/features/baba/domain/baba_snapshot.dart';
import 'package:aurogram/features/baba/voice/voice_session_controller.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';
import 'package:aurogram/features/astrology/presentation/widgets/rotating_nakshatra_wheel.dart';
import 'package:aurogram/core/routing/app_router.dart';
import 'package:aurogram/core/routing/route_names.dart';

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

  // Baba's live-call presence floats a control bar at the bottom-centre. While
  // a call is active we lift the login toolboxes above it so the submit button
  // is never hidden behind Aurobhatt's UI.
  final VoiceSessionController _voice = VoiceSessionController();
  static const double _babaCallBarHeight = 92.0;
  double get _babaCallInset => _voice.isCallLive ? _babaCallBarHeight : 0.0;

  void _onVoiceStateChanged() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _bindBabaTools();
    // Rebuild when a call starts/ends so the toolboxes lift/settle.
    _voice.addListener(_onVoiceStateChanged);
    // Tell Baba what this screen is showing RIGHT NOW (phone entry vs OTP), so
    // whereAmI is accurate - critical after a drop/resume when he must NOT
    // assume the old step. Pulled on demand, always current.
    BabaContext.instance.registerSnapshot('login', _babaSnapshot);
  }

  /// Live state of the login screen for Baba's whereAmI.
  BabaSnapshot _babaSnapshot() => BabaSnapshot.ready(
        step: _codeSent ? 'otpEntry' : 'phoneEntry',
        headline: _codeSent
            ? 'The login screen, awaiting the 6-digit OTP from SMS'
            : 'The login screen, awaiting the phone number',
        facts: {
          'phoneFilled': _phoneController.text.isNotEmpty,
          'countryCode': _countryCode.text,
          'codeSent': _codeSent,
          'otpFilled': _otpController.text.isNotEmpty,
        },
        availableActions: _codeSent
            ? const [BabaLoginTools.setOtp]
            : const [BabaLoginTools.setPhoneNumber],
      );

  // ── Baba tool handler: fill the phone number for a hands-free guest login ──
  // Declaration is global (registered at startup); we bind the live behaviour
  // only while this screen is mounted, mirroring the birth-details setup page.
  void _bindBabaTools() {
    BabaToolRegistry.instance.bindHandler(BabaLoginTools.setPhoneNumber,
        (args) async {
      // STT gives numbers with stray spaces/words — keep digits only.
      final digits =
          (args['phone'] as String?)?.replaceAll(RegExp(r'[^0-9]'), '') ?? '';
      if (digits.isEmpty) {
        return {'ok': false, 'set': false, 'reason': 'need the phone digits'};
      }
      // Normalise an optional country code to '+<digits>'.
      final rawCc = (args['countryCode'] as String?)?.trim();
      String? cc;
      if (rawCc != null && rawCc.isNotEmpty) {
        final ccDigits = rawCc.replaceAll(RegExp(r'[^0-9]'), '');
        if (ccDigits.isNotEmpty) cc = '+$ccDigits';
      }
      final send = args['send'] == true;
      if (!mounted) {
        return {'ok': false, 'set': false, 'reason': 'login screen not ready'};
      }
      setState(() {
        if (cc != null) _countryCode.text = cc;
        _phoneController.text = digits;
      });
      // Optionally kick off the OTP send. Baba can't read the SMS code, so the
      // user still enters the OTP themselves.
      if (send && !_codeSent && !_isLoading) {
        await _verifyPhone();
      }
      return {
        'ok': true,
        'set': true,
        'phone': '${_countryCode.text}$digits',
        'otpSent': send,
        'note': send
            ? 'OTP sent by SMS. Ask the user to read out or type the code — you '
                'cannot see it.'
            : 'Number filled. They can tap send, or ask you to send the OTP.',
      };
    });

    BabaToolRegistry.instance.bindHandler(BabaLoginTools.setOtp, (args) async {
      // STT gives the code with stray spaces/words — keep digits only.
      final code =
          (args['code'] as String?)?.replaceAll(RegExp(r'[^0-9]'), '') ?? '';
      if (code.isEmpty) {
        return {'ok': false, 'set': false, 'reason': 'need the OTP digits'};
      }
      if (!mounted) {
        return {'ok': false, 'set': false, 'reason': 'login screen not ready'};
      }
      if (!_codeSent) {
        // The OTP field only exists after the code has been sent.
        return {
          'ok': false,
          'set': false,
          'reason': 'no OTP has been sent yet - send the code first '
              '(setPhoneNumber with send:true), then fill the OTP',
        };
      }
      final submit = args['submit'] == true;
      setState(() => _otpController.text = code);
      if (submit && !_isVerifyingOTP) {
        final ok = await _verifyOTP();
        return {
          'ok': ok,
          'set': true,
          'submitted': true,
          'note': ok
              ? 'Verified - the user is now signed in.'
              : 'The code was NOT accepted (wrong or expired). Ask them to '
                  're-read it or resend - do NOT say the account is secured.',
        };
      }
      return {
        'ok': true,
        'set': true,
        'submitted': false,
        'note': 'Code filled. Tell the user to tap verify, or ask you to submit.',
      };
    });
  }

  /// Height occupied by the transparent app bar (toolbar + web top padding).
  /// Used to offset content now that the body extends behind the header.
  double get _headerHeight =>
      AppHeaderStyle.headerToolbarHeight + (kIsWeb ? AppHeaderStyle.webTopPadding : 0.0);

  /// Rotating Nakshatra wheel header (decorative; same illustration the
  /// dashboard uses, minus the interactivity).
  Widget _buildWheelHeader({required bool isWide}) {
    return Center(
      child: RotatingNakshatraWheel(
        size: isWide ? 240 : 220,
        rotationPeriod: const Duration(seconds: 30),
      ),
    );
  }

  @override
  void dispose() {
    _voice.removeListener(_onVoiceStateChanged);
    BabaContext.instance.unregisterSnapshot('login');
    for (final tool in BabaLoginTools.names) {
      BabaToolRegistry.instance.unbindHandler(tool);
    }
    _phoneController.dispose();
    _otpController.dispose();
    _countryCode.dispose();
    super.dispose();
  }

  /// Leave the login route AFTER the current frame settles.
  ///
  /// A successful sign-in flips auth state, which makes the tree underneath
  /// login (TabHandler, CallService, and any nested navigators) rebuild. If we
  /// navigate synchronously in that same frame we re-enter navigation while the
  /// build owner is locked (finalizeTree) - that throws
  /// "!_debugLocked: is not true" in NavigatorState and leaves a DEAD screen.
  /// This is especially easy to hit when the phone number already belongs to an
  /// existing account, so sign-in SWITCHES uid and triggers a full rebuild.
  ///
  /// We POP when login was pushed on top of another route, but Baba opens it
  /// with appRouter.go('/login') which REPLACES the stack - then canPop() is
  /// false and a bare pop would strand the user on login. So when we cannot pop,
  /// we go home. There is no auth-redirect in the router, so this explicit hop
  /// is what actually gets the user off the login screen.
  void _dismissAfterAuth() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted) {
        final nav = Navigator.of(context);
        if (nav.canPop()) {
          nav.pop();
        } else {
          appRouter.go(RouteNames.home);
        }
      }
      // If Baba did NOT drive this sign-in (the user tapped Verify, or Android
      // auto-retrieved the code), his mental model is now stale — he still
      // thinks we're on the OTP step. Proactively tell him we're signed in and
      // moved once the navigation settles. When HE drove it via setOtp, the
      // tool result already carries the settled state, so we skip the double.
      if (!BabaToolRegistry.instance.isDispatching) {
        await BabaContext.instance.settle();
        BabaContext.instance.announceStateChange();
      }
    });
  }

  /// Verify the OTP and sign in. Returns true ONLY when sign-in actually
  /// succeeded, so the Baba tool handler can report the truth instead of
  /// assuming success (a wrong/expired code must NOT be announced as "account
  /// secured"). On failure it surfaces a dialog for the on-screen user.
  Future<bool> _verifyOTP() async {
    if (_otpController.text.isEmpty) {
      _showErrorDialog('Please enter the OTP');
      return false;
    }

    // Check for required verification state
    if (kIsWeb) {
      if (_confirmationResult == null) {
        _showErrorDialog(
            'Verification session expired. Please request a new code.');
        return false;
      }
    } else {
      if (_verificationId == null) {
        _showErrorDialog(
            'Verification ID is missing. Please request a new code.');
        return false;
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
      _dismissAfterAuth();
      return true;
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
      return false;
    }
  }

  /// Web-specific phone verification using reCAPTCHA.
  ///
  /// If the current user is an anonymous GUEST, LINK the phone to that account
  /// (preserves uid + data). Otherwise sign in normally.
  Future<void> _verifyPhoneWeb(String phoneNumber) async {
    try {
      final current = FirebaseAuth.instance.currentUser;
      if (current != null && current.isAnonymous) {
        _confirmationResult = await current.linkWithPhoneNumber(phoneNumber);
      } else {
        _confirmationResult = await FirebaseAuth.instance.signInWithPhoneNumber(
          phoneNumber,
        );
      }

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
            _dismissAfterAuth();
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
        // Let content render behind the transparent header (floating header,
        // matching the other tabs).
        extendBodyBehindAppBar: true,
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
                SizedBox(
                    height: _headerHeight + AppHeaderStyle.contentTopPadding),
                const SizedBox(height: AppDimensions.spacingXxl),
                _buildWheelHeader(isWide: true),
                const SizedBox(height: AppDimensions.spacingXxl),
                LoginPolicyText(
                  onShowPolicy: (type) => showPolicyDialog(context, type),
                ),
                const SizedBox(height: AppDimensions.spacingSection),
                LoginSubtitle(isWide: true, codeSent: _codeSent),
                const SizedBox(height: AppDimensions.spacingLargeSection),
                _buildToolboxColumn(),
                // Clear Baba's call bar when a call is active.
                AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  child: SizedBox(height: _babaCallInset),
                ),
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
        totalToolboxHeight + closedBottomPadding + 16.0 + _babaCallInset;

    return Stack(
      fit: StackFit.expand,
      children: [
        SingleChildScrollView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          child: Padding(
            padding: EdgeInsets.only(
              top: mediaQuery.padding.top +
                  _headerHeight +
                  AppHeaderStyle.contentTopPadding,
              bottom: contentBottomPadding,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppDimensions.spacingMd),
                _buildWheelHeader(isWide: false),
                const SizedBox(height: AppDimensions.spacingXxl),
                LoginPolicyText(
                  onShowPolicy: (type) => showPolicyDialog(context, type),
                ),
                const SizedBox(height: AppDimensions.spacingSection),
                LoginSubtitle(isWide: false, codeSent: _codeSent),
                const SizedBox(height: AppDimensions.spacingLargeSection),
              ],
            ),
          ),
        ),

        // Fixed toolboxes at bottom — lifted above Baba's call bar when active.
        AnimatedPositioned(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          bottom: _babaCallInset,
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
                enabled: true,
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
