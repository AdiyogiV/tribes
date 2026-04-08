import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:aurogram/shared/presentation/widgets/media/common_widgets.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:aurogram/features/auth/auth_service.dart';
import 'package:aurogram/features/astrology/domain/astrology_service.dart';
import 'package:aurogram/features/notifications/domain/notification_service.dart';
import 'package:aurogram/services/onboarding_service.dart';
import 'package:aurogram/features/astrology/presentation/pages/daily_insight_page.dart';
import 'package:aurogram/features/astrology/presentation/pages/astrology_details_page.dart';
import 'package:aurogram/features/ayurveda/presentation/pages/ayurveda_details_page.dart';
import 'package:aurogram/features/onboarding/domain/onboarding_constants.dart';
import 'package:aurogram/features/onboarding/presentation/widgets/onboarding_dialogs.dart';

/// Provides navigation helpers for the onboarding flow.
///
/// The host State must expose the fields that navigation reads/writes via the
/// abstract getters/setters declared here.
mixin NavigationMixin<T extends StatefulWidget> on State<T> {
  // ---- fields the host must provide ----
  bool get navIsNavigating;
  set navIsNavigating(bool value);

  /// Whether this is an update flow (not first-time setup).
  bool get navIsUpdate;

  // ---- navigation methods ----

  void navigateToHome({int targetTab = 3}) async {
    if (navIsNavigating || !mounted) return;
    navIsNavigating = true;

    HapticFeedback.mediumImpact();

    // CRITICAL: Mark FTUE as shown BEFORE navigating
    await OnboardingService().markFtueShown();

    if (!mounted) return;

    final authService = context.read<AuthService>();
    authService.updateStatusBasedOnNewUserFlag(false,
        initialTabIndex: targetTab);
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void navigateToDailyInsight() async {
    if (navIsNavigating || !mounted) return;
    navIsNavigating = true;

    HapticFeedback.mediumImpact();

    // Trigger lazy sync for full data
    AstrologyService().triggerLazySync(mode: 'standard');

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      navigateToHome(targetTab: 0);
      return;
    }

    // For updates: pop back then push daily insight
    if (navIsUpdate) {
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
    await _showNotificationPermissionPrompt();

    if (!mounted) return;

    // CRITICAL: Mark FTUE as shown BEFORE navigating
    await OnboardingService().markFtueShown();

    if (!mounted) return;

    final authService = context.read<AuthService>();
    authService.updateStatusBasedOnNewUserFlag(false, initialTabIndex: 0);

    Navigator.of(context).popUntil((route) => route.isFirst);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => DailyInsightPage(uid: uid),
      ),
    );
  }

  void navigateToAstroDetails() async {
    if (navIsNavigating || !mounted) return;
    navIsNavigating = true;

    HapticFeedback.mediumImpact();

    // Trigger lazy sync for full data (house interpretations etc.)
    AstrologyService().triggerLazySync(mode: 'standard');

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      navigateToHome(targetTab: 0);
      return;
    }

    // For updates: just pop back to astro details page
    if (navIsUpdate) {
      Navigator.of(context).pop();
      Navigator.of(context).pop(true);
      return;
    }

    // For new setup: full navigation flow
    await OnboardingService().markFtueShown();

    if (!mounted) return;

    final authService = context.read<AuthService>();
    authService.updateStatusBasedOnNewUserFlag(false, initialTabIndex: 3);

    Navigator.of(context).popUntil((route) => route.isFirst);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AstrologyDetailsPage(uid: uid),
      ),
    );
  }

  void navigateToAyurveda() async {
    if (navIsNavigating || !mounted) return;
    navIsNavigating = true;

    HapticFeedback.mediumImpact();

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      navigateToHome(targetTab: 0);
      return;
    }

    // For updates: just pop back then push ayurveda
    if (navIsUpdate) {
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
    await OnboardingService().markFtueShown();

    if (!mounted) return;

    final authService = context.read<AuthService>();
    authService.updateStatusBasedOnNewUserFlag(false, initialTabIndex: 3);

    Navigator.of(context).popUntil((route) => route.isFirst);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AyurvedaDetailsPage(uid: uid),
      ),
    );
  }

  /// Show contextual notification permission prompt.
  Future<void> _showNotificationPermissionPrompt() async {
    final notificationService = NotificationService();

    if (notificationService.permissionsRequested) return;
    final hasPermission = await notificationService.hasPermission();
    if (hasPermission) return;

    if (!mounted) return;

    final shouldRequest = await AppBottomSheet.show<bool>(
      context,
      child: NotificationPermissionSheet(
        primaryColor: OnboardingColors.primary,
        isDark: Theme.of(context).brightness == Brightness.dark,
      ),
    );

    if (shouldRequest == true) {
      await notificationService.requestPermissions();
    }
  }
}
