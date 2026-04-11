import 'package:flutter/material.dart';
import 'package:aurogram/core/logging/app_logger.dart';
import 'package:aurogram/core/routing/app_router.dart';
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
      '${RouteNames.spaceInvite}/$spaceId',
      extra: {'inviterId': inviterId},
    );
  }

  /// Navigate to specific post
  static void navigateToPost(String postId) {
    AppLogger.i('🔗 navigateToPost called',
        category: LogCategory.navigation, data: {'postId': postId});

    _navigate('${RouteNames.threadView}/$postId');
  }

  /// Navigate to user profile
  static void navigateToUserProfile(String userId) {
    AppLogger.i('🔗 navigateToUserProfile called',
        category: LogCategory.navigation, data: {'userId': userId});

    _navigate('${RouteNames.userProfile}/$userId');
  }

  /// Navigate to anonymous message send composer (by slug)
  static void navigateToSecretMessageSlug(String slug) {
    AppLogger.i('🔗 navigateToSecretMessageSlug called',
        category: LogCategory.navigation, data: {'slug': slug});

    _navigate('${RouteNames.secretMessageSend}/$slug');
  }

  /// Internal navigation helper with retry logic
  static void _navigate(String path, {Object? extra}) {
    // Try immediate navigation
    if (_tryNavigate(path, extra: extra)) {
      return;
    }

    // Store pending navigation and retry after delay
    AppLogger.i('🔗 Navigator not ready, scheduling retry',
        category: LogCategory.navigation);
    _pendingNavigation = _PendingNavigation(path, extra);

    // Retry after delays (app might still be initializing)
    Future.delayed(const Duration(milliseconds: 500), () => _processPending());
    Future.delayed(const Duration(seconds: 1), () => _processPending());
    Future.delayed(const Duration(seconds: 2), () => _processPending());
  }

  /// Try to navigate immediately via GoRouter
  static bool _tryNavigate(String path, {Object? extra}) {
    try {
      appRouter.push(path, extra: extra);
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

    if (_tryNavigate(_pendingNavigation!.path,
        extra: _pendingNavigation!.extra)) {
      _pendingNavigation = null;
    }
  }

  /// Call this when app is fully ready (e.g., after splash screen)
  static void processPendingNavigation() {
    _processPending();
  }
}

class _PendingNavigation {
  final String path;
  final Object? extra;

  _PendingNavigation(this.path, this.extra);
}
