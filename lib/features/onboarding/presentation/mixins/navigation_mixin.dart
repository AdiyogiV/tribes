import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:aurogram/core/routing/app_router.dart';
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

    // Reset the whole stack to the home shell the GoRouter way. `go` replaces
    // the stack cleanly (the old imperative popUntil popped pages off
    // GoRouter's own stack and tripped `currentConfiguration.isNotEmpty` +
    // NavigatorState.dispose); TabHandler then reads `initialTabIndex`.
    //
    // CRITICAL: defer to AFTER this frame. Baba can trigger this from a voice
    // tool call, and the tool dispatch pumps frames to let the UI settle
    // (observe-on-act). Calling `go` synchronously then mutates the route
    // stack DURING finalizeTree - it disposes this page's subtree while the
    // Navigator is locked (`!_debugLocked`), empties the stack and leaves a
    // BLANK screen. A post-frame callback runs between frames, when navigating
    // is safe. Use the global `appRouter` (not `context.go`) so a context torn
    // down by the transition can't crash the callback.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      appRouter.go(RouteNames.home);
    });
  }
}
