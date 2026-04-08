import 'package:flutter/material.dart';
import 'package:country_code_picker/country_code_picker.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:aurogram/widgets/universal/transparent_toolbox.dart';
import 'package:aurogram/utils/theme/app_dimensions.dart';

/// Country-code picker toolbox.
class CountryCodeToolbox extends StatelessWidget {
  final TextEditingController countryCode;
  final ValueChanged<String> onChanged;

  const CountryCodeToolbox({
    super.key,
    required this.countryCode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TransparentToolbox(
      content: Center(
        child: CountryCodePicker(
          onChanged: (code) => onChanged(code.toString()),
          initialSelection: '+91',
          favorite: ['+91'],
          showCountryOnly: false,
          showOnlyCountryWhenClosed: true,
          alignLeft: false,
          padding: EdgeInsets.symmetric(horizontal: AppDimensions.paddingLg),
          textStyle: TextStyle(
            color: AppTheme.primaryColor.withValues(alpha: 0.85),
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}

/// Send-verification-code button toolbox.
class SendVerificationToolbox extends StatelessWidget {
  final VoidCallback? onTap;
  final bool isLoading;
  final bool enabled;

  const SendVerificationToolbox({
    super.key,
    required this.onTap,
    required this.isLoading,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    return TransparentToolbox.button(
      text: 'Send Verification Code',
      onTap: enabled ? onTap : null,
      isLoading: isLoading,
      icon: Icons.arrow_forward,
      enabled: enabled,
    );
  }
}

/// Phone number entry toolbox.
class PhoneEntryToolbox extends StatelessWidget {
  final TextEditingController phoneController;
  final TextEditingController countryCode;
  final bool isLoading;
  final VoidCallback onSubmitted;

  const PhoneEntryToolbox({
    super.key,
    required this.phoneController,
    required this.countryCode,
    required this.isLoading,
    required this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return TransparentToolbox(
      content: Row(
        children: [
          // Country code display
          Container(
            padding: EdgeInsets.symmetric(horizontal: AppDimensions.paddingMd, vertical: AppDimensions.paddingSm),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
            ),
            child: Text(
              countryCode.text,
              style: TextStyle(
                color: AppTheme.primaryColor.withValues(alpha: 0.85),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(width: AppDimensions.spacingMd),
          // Phone number input
          Expanded(
            child: TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) {
                if (!isLoading &&
                    phoneController.text.isNotEmpty &&
                    countryCode.text.isNotEmpty) {
                  onSubmitted();
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
}

/// OTP entry toolbox.
class OTPEntryToolbox extends StatelessWidget {
  final TextEditingController otpController;
  final bool isVerifyingOTP;
  final VoidCallback onSubmitted;

  const OTPEntryToolbox({
    super.key,
    required this.otpController,
    required this.isVerifyingOTP,
    required this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return TransparentToolbox(
      content: Row(
        children: [
          Icon(
            Icons.security,
            color: AppTheme.primaryColor.withValues(alpha: 0.85),
            size: 24,
          ),
          SizedBox(width: AppDimensions.spacingMd),
          Expanded(
            child: TextField(
              controller: otpController,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) {
                if (!isVerifyingOTP && otpController.text.isNotEmpty) {
                  onSubmitted();
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
                letterSpacing: 2.0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Change-number toolbox (shown in OTP state).
class ChangeNumberToolbox extends StatelessWidget {
  final bool isVerifyingOTP;
  final VoidCallback onChangeNumber;

  const ChangeNumberToolbox({
    super.key,
    required this.isVerifyingOTP,
    required this.onChangeNumber,
  });

  @override
  Widget build(BuildContext context) {
    return TransparentToolbox(
      content: GestureDetector(
        onTap: isVerifyingOTP ? null : onChangeNumber,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.edit,
              color: AppTheme.primaryColor.withValues(alpha: 0.85),
              size: 20,
            ),
            SizedBox(width: AppDimensions.spacingSm),
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
}

/// Verify-OTP button toolbox.
class VerifyOTPToolbox extends StatelessWidget {
  final VoidCallback onTap;
  final bool isVerifyingOTP;

  const VerifyOTPToolbox({
    super.key,
    required this.onTap,
    required this.isVerifyingOTP,
  });

  @override
  Widget build(BuildContext context) {
    return TransparentToolbox.button(
      text: 'Verify Code',
      onTap: onTap,
      isLoading: isVerifyingOTP,
      icon: Icons.check,
    );
  }
}
