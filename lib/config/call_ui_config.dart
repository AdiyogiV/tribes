import 'package:flutter/cupertino.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// Centralized call UI configuration
/// Change icons here to update everywhere at once
class CallUIConfig {
  CallUIConfig._();

  // ═══════════════════════════════════════════════════════════════
  // CALL ICONS - Change these to update all call buttons/indicators
  // ═══════════════════════════════════════════════════════════════

  /// Main call icon (used on buttons when no call active) — simple phone/call
  static const IconData callIcon = Icons.call_rounded;

  /// Icon when call is active (shown on active call buttons/indicators)
  static const IconData callActiveIcon = Icons.phone_in_talk_rounded;

  /// Icon for the active call banner
  static const IconData callBannerIcon = Icons.phone_in_talk_rounded;

  /// Icon for end call button
  static const IconData endCallIcon = CupertinoIcons.phone_down_fill;

  // ═══════════════════════════════════════════════════════════════
  // COLORS
  // ═══════════════════════════════════════════════════════════════

  /// Color when call is active
  static const Color activeCallColor = AppTheme.activeGreen;

  /// Color for end call button
  static const Color endCallColor = AppTheme.dangerRed;

  /// Muted state color
  static const Color mutedColor = Color(0xFFFF9800);

  // ═══════════════════════════════════════════════════════════════
  // ALTERNATIVE ICON OPTIONS (uncomment to try)
  // ═══════════════════════════════════════════════════════════════

  // Fun options to try:
  // static const IconData callIcon = Icons.wifi_calling_3_rounded;     // Phone with signal waves
  // static const IconData callIcon = CupertinoIcons.phone_badge_plus;  // Phone with plus
  // static const IconData callIcon = Icons.ring_volume_rounded;        // Ringing phone
  // static const IconData callIcon = Icons.duo_rounded;                // Google Duo style
  // static const IconData callIcon = Icons.video_call_rounded;         // Video with person
  // static const IconData callIcon = CupertinoIcons.video_camera_solid; // Classic video
  // static const IconData callIcon = Icons.groups_rounded;             // Group of people
  // static const IconData callIcon = Icons.celebration_rounded;        // Party popper 🎉
}
