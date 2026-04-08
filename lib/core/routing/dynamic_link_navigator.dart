import 'package:flutter/material.dart';
import 'package:aurogram/pages/spaces/invite_landing_page.dart';
import 'package:aurogram/pages/content/thread_view.dart';
import 'package:aurogram/pages/tabs/user_profile.dart';
import 'package:aurogram/pages/send_me_something/send_composer_screen.dart';
import 'package:aurogram/utils/logging/app_logger.dart';

class DynamicLinkNavigator {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  /// Pending navigation to execute when navigator is ready
  static _PendingNavigation? _pendingNavigation;

  /// Navigate to space invitation
  static void navigateToSpaceInvite(String spaceId, String? inviterId) {
    AppLogger.i('🔗 navigateToSpaceInvite called',
        category: LogCategory.navigation,
        data: {'spaceId': spaceId, 'inviterId': inviterId});

    _navigate(() {
      return InviteLandingPage(
        space: spaceId,
        invitee: inviterId,
      );
    });
  }

  /// Navigate to specific post
  static void navigateToPost(String postId) {
    AppLogger.i('🔗 navigateToPost called',
        category: LogCategory.navigation, data: {'postId': postId});

    _navigate(() => ThreadView(postId: postId));
  }

  /// Navigate to user profile
  static void navigateToUserProfile(String userId) {
    AppLogger.i('🔗 navigateToUserProfile called',
        category: LogCategory.navigation, data: {'userId': userId});

    _navigate(() => UserProfilePage(uid: userId));
  }

  /// Navigate to anonymous message send composer (by slug)
  static void navigateToSecretMessageSlug(String slug) {
    AppLogger.i('🔗 navigateToSecretMessageSlug called',
        category: LogCategory.navigation, data: {'slug': slug});

    _navigate(() => SecretMessageSendComposer(slug: slug));
  }

  /// Internal navigation helper with retry logic
  static void _navigate(Widget Function() pageBuilder) {
    // Try immediate navigation
    if (_tryNavigate(pageBuilder)) {
      return;
    }

    // Store pending navigation and retry after delay
    AppLogger.i('🔗 Navigator not ready, scheduling retry',
        category: LogCategory.navigation);
    _pendingNavigation = _PendingNavigation(pageBuilder);

    // Retry after delays (app might still be initializing)
    Future.delayed(const Duration(milliseconds: 500), () => _processPending());
    Future.delayed(const Duration(seconds: 1), () => _processPending());
    Future.delayed(const Duration(seconds: 2), () => _processPending());
  }

  /// Try to navigate immediately
  static bool _tryNavigate(Widget Function() pageBuilder) {
    try {
      final context = navigatorKey.currentContext;
      if (context == null) {
        AppLogger.d('🔗 Navigator context is null',
            category: LogCategory.navigation);
        return false;
      }

      final navigator = Navigator.of(context);
      navigator.push(
        MaterialPageRoute(builder: (context) => pageBuilder()),
      );

      AppLogger.i('🔗 Navigation successful', category: LogCategory.navigation);
      return true;
    } catch (e) {
      AppLogger.e('🔗 Navigation error',
          category: LogCategory.navigation, error: e);
      return false;
    }
  }

  /// Process pending navigation if any
  static void _processPending() {
    if (_pendingNavigation == null) return;

    AppLogger.d('🔗 Processing pending navigation',
        category: LogCategory.navigation);

    if (_tryNavigate(_pendingNavigation!.pageBuilder)) {
      _pendingNavigation = null;
    }
  }

  /// Call this when app is fully ready (e.g., after splash screen)
  static void processPendingNavigation() {
    _processPending();
  }
}

class _PendingNavigation {
  final Widget Function() pageBuilder;

  _PendingNavigation(this.pageBuilder);
}
