import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:aurogram/core/routing/route_names.dart';
import 'package:aurogram/features/auth/auth_service.dart';
import 'package:aurogram/features/onboarding/domain/onboarding_service.dart';

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

    // CRITICAL: Mark FTUE as shown BEFORE navigating.
    // This also flags the notification-permission prompt as pending so the
    // TabHandler shows it on the dashboard's first load.
    await OnboardingService().markFtueShown();

    if (!mounted) return;

    final authService = context.read<AuthService>();
    authService.updateStatusBasedOnNewUserFlag(false,
        initialTabIndex: targetTab);

    // Reset the whole stack to the home shell the GoRouter way. This app is
    // fully GoRouter-driven, so the old imperative
    // `Navigator.of(context).popUntil((route) => route.isFirst)` popped pages
    // straight off GoRouter's page stack - popping the LAST one tripped
    // `currentConfiguration.isNotEmpty` (go_router delegate) and left a BLANK
    // screen plus a NavigatorState.dispose crash. `context.go` replaces the
    // stack cleanly; TabHandler then reads `initialTabIndex` to land on the
    // requested tab.
    context.go(RouteNames.home);
  }
}
