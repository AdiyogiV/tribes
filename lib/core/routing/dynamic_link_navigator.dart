import 'package:flutter/material.dart';
import 'package:aurogram/core/logging/app_logger.dart';
import 'package:aurogram/core/routing/page_factory.dart';
import 'package:aurogram/core/routing/route_names.dart';

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

    _navigate(
      RouteNames.spaceInvite,
      arguments: {'spaceId': spaceId, 'inviterId': inviterId},
    );
  }

  /// Navigate to specific post
  static void navigateToPost(String postId) {
    AppLogger.i('🔗 navigateToPost called',
        category: LogCategory.navigation, data: {'postId': postId});

    _navigate(RouteNames.threadView, arguments: {'postId': postId});
  }

  /// Navigate to user profile
  static void navigateToUserProfile(String userId) {
    AppLogger.i('🔗 navigateToUserProfile called',
        category: LogCategory.navigation, data: {'userId': userId});

    _navigate(RouteNames.userProfile, arguments: {'uid': userId});
  }

  /// Navigate to anonymous message send composer (by slug)
  static void navigateToSecretMessageSlug(String slug) {
    AppLogger.i('🔗 navigateToSecretMessageSlug called',
        category: LogCategory.navigation, data: {'slug': slug});

    _navigate(RouteNames.secretMessageSend, arguments: {'slug': slug});
  }

  /// Internal navigation helper with retry logic
  static void _navigate(String routeName, {Map<String, dynamic>? arguments}) {
    // Try immediate navigation
    if (_tryNavigate(routeName, arguments: arguments)) {
      return;
    }

    // Store pending navigation and retry after delay
    AppLogger.i('🔗 Navigator not ready, scheduling retry',
        category: LogCategory.navigation);
    _pendingNavigation = _PendingNavigation(routeName, arguments);

    // Retry after delays (app might still be initializing)
    Future.delayed(const Duration(milliseconds: 500), () => _processPending());
    Future.delayed(const Duration(seconds: 1), () => _processPending());
    Future.delayed(const Duration(seconds: 2), () => _processPending());
  }

  /// Try to navigate immediately
  static bool _tryNavigate(String routeName, {Map<String, dynamic>? arguments}) {
    try {
      final context = navigatorKey.currentContext;
      if (context == null) {
        AppLogger.d('🔗 Navigator context is null',
            category: LogCategory.navigation);
        return false;
      }

      final navigator = Navigator.of(context);
      navigator.push(
        PageFactory.route(routeName, arguments: arguments),
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

    if (_tryNavigate(_pendingNavigation!.routeName,
        arguments: _pendingNavigation!.arguments)) {
      _pendingNavigation = null;
    }
  }

  /// Call this when app is fully ready (e.g., after splash screen)
  static void processPendingNavigation() {
    _processPending();
  }
}

class _PendingNavigation {
  final String routeName;
  final Map<String, dynamic>? arguments;

  _PendingNavigation(this.routeName, this.arguments);
}
