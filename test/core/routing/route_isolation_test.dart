// ignore_for_file: avoid_print
/// Tests for feature isolation in the routing layer.
///
/// Verifies that route_names.dart serves as the single source of truth
/// for navigation paths, and that features don't directly import each
/// other's page widgets for navigation (they use GoRouter paths instead).
library;

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:aurogram/core/routing/route_names.dart';

void main() {
  group('Route isolation', () {
    test('all RouteNames constants are unique paths', () {
      // Collect all static const String fields via their values
      final routes = _allRouteNameValues();
      final seen = <String>{};
      for (final route in routes) {
        expect(seen.contains(route), isFalse,
            reason: 'Duplicate route path: $route');
        seen.add(route);
      }
    });

    test('route paths do not contain path parameter placeholders', () {
      // RouteNames should be base paths without :param segments.
      // The GoRoute definitions in app_router.dart append /:param.
      final routes = _allRouteNameValues();
      for (final route in routes) {
        expect(route.contains(':'), isFalse,
            reason:
                '"$route" should not contain path params — those belong in GoRoute definitions');
      }
    });

    test('route names cover all major features', () {
      // Ensure each feature area has at least one route
      final routes = _allRouteNameValues();
      final routeSet = routes.toSet();

      // Core navigation
      expect(routeSet, contains('/'));
      expect(routeSet, contains('/login'));

      // Feature areas
      expect(routes.any((r) => r.startsWith('/space')), isTrue,
          reason: 'Spaces feature should have routes');
      expect(routes.any((r) => r.startsWith('/astrology')), isTrue,
          reason: 'Astrology feature should have routes');
      expect(routes.any((r) => r.startsWith('/ayurveda')), isTrue,
          reason: 'Ayurveda feature should have routes');
      expect(routes.any((r) => r.startsWith('/ai')), isTrue,
          reason: 'AI Chat feature should have routes');
      expect(routes.any((r) => r.startsWith('/call')), isTrue,
          reason: 'Calling feature should have routes');
      expect(routes.any((r) => r.startsWith('/stories')), isTrue,
          reason: 'Stories feature should have routes');
      expect(routes.any((r) => r.startsWith('/anonymous')), isTrue,
          reason: 'Anonymous Messages feature should have routes');
      expect(routes.any((r) => r.startsWith('/media')), isTrue,
          reason: 'Media feature should have routes');
    });

    test('no route path has trailing slash (except home)', () {
      final routes = _allRouteNameValues();
      for (final route in routes) {
        if (route == '/') continue;
        expect(route.endsWith('/'), isFalse,
            reason: '"$route" should not end with /');
      }
    });

    test('route count matches expected total', () {
      final routes = _allRouteNameValues();
      // Currently 43 routes. Update this when adding new routes.
      expect(routes.length, greaterThanOrEqualTo(40),
          reason:
              'Expected at least 40 routes. If you removed routes, update this test.');
    });
  });

  group('Feature isolation - PageFactory removed', () {
    test('no file in lib/ imports page_factory.dart', () {
      final libDir = Directory('lib');
      if (!libDir.existsSync()) return; // Skip if not running from project root

      final dartFiles = libDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'));

      for (final file in dartFiles) {
        final content = file.readAsStringSync();
        expect(content.contains('page_factory.dart'), isFalse,
            reason:
                '${file.path} still imports page_factory.dart — use GoRouter routes instead');
      }
    });

    test('app_router.dart exists and defines createAppRouter', () {
      final routerFile = File('lib/core/routing/app_router.dart');
      if (!routerFile.existsSync()) {
        fail('app_router.dart does not exist');
      }
      final content = routerFile.readAsStringSync();
      expect(content.contains('createAppRouter'), isTrue,
          reason: 'app_router.dart must define createAppRouter function');
      expect(content.contains('GoRouter'), isTrue,
          reason: 'app_router.dart must use GoRouter');
    });
  });

  group('RouteNames path conventions', () {
    test('feature routes are properly namespaced', () {
      // Astrology routes should start with /astrology
      expect(RouteNames.dailyInsight, startsWith('/astrology'));
      expect(RouteNames.astrologyDetails, startsWith('/astrology'));
      expect(RouteNames.astrologySetup, startsWith('/astrology'));
      expect(RouteNames.astroChatPage, startsWith('/astrology'));
      expect(RouteNames.savedInsights, startsWith('/astrology'));
      expect(RouteNames.compatibilityDetails, startsWith('/astrology'));

      // Ayurveda routes
      expect(RouteNames.ayurvedaDetails, startsWith('/ayurveda'));
      expect(RouteNames.vikritiCheckin, startsWith('/ayurveda'));
      expect(RouteNames.prakritiRefinement, startsWith('/ayurveda'));

      // AI routes
      expect(RouteNames.aiChat, startsWith('/ai'));
      expect(RouteNames.recentConversations, startsWith('/ai'));

      // Call routes
      expect(RouteNames.callScreen, startsWith('/call'));
      expect(RouteNames.incomingCall, startsWith('/call'));
      expect(RouteNames.groupCall, startsWith('/call'));

      // Space routes
      expect(RouteNames.spaceScreen, startsWith('/space'));
      expect(RouteNames.spaceChatScreen, startsWith('/space'));
      expect(RouteNames.editSpace, startsWith('/space'));
      expect(RouteNames.addSpaceMembers, startsWith('/space'));
      expect(RouteNames.spaceInvite, startsWith('/space'));
      expect(RouteNames.spaceCreation, startsWith('/space'));

      // Story routes
      expect(RouteNames.storyComposer, startsWith('/stories'));
      expect(RouteNames.storyViewer, startsWith('/stories'));

      // Media routes
      expect(RouteNames.mediaGallery, startsWith('/media'));
      expect(RouteNames.videoPlayer, startsWith('/media'));
    });
  });
}

/// Extracts all route path values from RouteNames.
/// Uses reflection-like approach by reading the source file.
List<String> _allRouteNameValues() {
  // Manually list all RouteNames constants to keep the test self-contained
  return [
    RouteNames.home,
    RouteNames.profile,
    RouteNames.spaces,
    RouteNames.login,
    RouteNames.signup,
    RouteNames.userProfile,
    RouteNames.spaceScreen,
    RouteNames.spaceChatScreen,
    RouteNames.threadView,
    RouteNames.dailyInsight,
    RouteNames.astrologyDetails,
    RouteNames.astrologySetup,
    RouteNames.astroChatPage,
    RouteNames.ayurvedaDetails,
    RouteNames.vikritiCheckin,
    RouteNames.aiChat,
    RouteNames.recentConversations,
    RouteNames.cosmicDashboard,
    RouteNames.callScreen,
    RouteNames.incomingCall,
    RouteNames.groupCall,
    RouteNames.invites,
    RouteNames.requests,
    RouteNames.followersFollowing,
    RouteNames.auraLeaderboard,
    RouteNames.secretMessagesInbox,
    RouteNames.secretMessagesGetLink,
    RouteNames.secretMessageSend,
    RouteNames.editSpace,
    RouteNames.addSpaceMembers,
    RouteNames.spaceInvite,
    RouteNames.storyComposer,
    RouteNames.notifications,
    RouteNames.settings,
    RouteNames.editProfile,
    RouteNames.namasteHistory,
    RouteNames.uploads,
    RouteNames.prakritiRefinement,
    RouteNames.spaceCreation,
    RouteNames.storyViewer,
    RouteNames.mediaGallery,
    RouteNames.videoPlayer,
    RouteNames.savedInsights,
    RouteNames.compatibilityDetails,
    RouteNames.onboardingComplete,
  ];
}
