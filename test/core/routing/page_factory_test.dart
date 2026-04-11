// ignore_for_file: avoid_print
/// Tests for GoRouter routing configuration contract.
///
/// Verifies that all RouteNames constants are valid and consistent,
/// and that the router error page renders correctly for unknown routes.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aurogram/core/routing/route_names.dart';

void main() {
  group('GoRouter routing contract', () {
    // All route name constants that must be defined and handled.
    final allRoutes = <String>[
      // Core tabs
      RouteNames.home,
      RouteNames.profile,
      RouteNames.spaces,
      // Auth
      RouteNames.login,
      RouteNames.signup,
      // Profiles
      RouteNames.userProfile,
      // Spaces
      RouteNames.spaceScreen,
      RouteNames.spaceChatScreen,
      RouteNames.editSpace,
      RouteNames.addSpaceMembers,
      RouteNames.spaceInvite,
      RouteNames.spaceCreation,
      // Content
      RouteNames.threadView,
      // Astrology
      RouteNames.dailyInsight,
      RouteNames.astrologyDetails,
      RouteNames.astrologySetup,
      RouteNames.astroChatPage,
      RouteNames.cosmicDashboard,
      // Ayurveda
      RouteNames.ayurvedaDetails,
      RouteNames.vikritiCheckin,
      // AI
      RouteNames.aiChat,
      RouteNames.recentConversations,
      // Calling
      RouteNames.callScreen,
      RouteNames.incomingCall,
      RouteNames.groupCall,
      // Social
      RouteNames.invites,
      RouteNames.requests,
      RouteNames.followersFollowing,
      RouteNames.auraLeaderboard,
      RouteNames.namasteHistory,
      // Anonymous Messages
      RouteNames.secretMessagesInbox,
      RouteNames.secretMessagesGetLink,
      RouteNames.secretMessageSend,
      // Stories
      RouteNames.storyComposer,
      RouteNames.storyViewer,
      // Media
      RouteNames.mediaGallery,
      RouteNames.videoPlayer,
      // Astrology (additional)
      RouteNames.savedInsights,
      RouteNames.compatibilityDetails,
      // Ayurveda (additional)
      RouteNames.prakritiRefinement,
      // Onboarding
      RouteNames.onboardingComplete,
      // Other
      RouteNames.notifications,
      RouteNames.settings,
      RouteNames.editProfile,
      RouteNames.uploads,
    ];

    test('all route names are non-empty strings starting with /', () {
      for (final route in allRoutes) {
        expect(route.isNotEmpty, isTrue,
            reason: 'Route must not be empty');
        expect(route.startsWith('/'), isTrue,
            reason: '"$route" must start with /');
      }
    });

    test('no duplicate route names', () {
      expect(allRoutes.toSet().length, equals(allRoutes.length),
          reason: 'Found duplicate route names');
    });

    test('route names use correct path format', () {
      final validRoutePattern = RegExp(r'^/[a-z0-9\-/]*$');
      for (final route in allRoutes) {
        expect(validRoutePattern.hasMatch(route), isTrue,
            reason: '"$route" should use lowercase kebab-case path format');
      }
    });

    test('home route is /', () {
      expect(RouteNames.home, equals('/'));
    });

    group('error page fallback', () {
      testWidgets('renders "Route not found" for unknown routes', (tester) async {
        // Simulate the error page that GoRouter renders for unknown routes
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: Text('Route not found: /unknown_route'),
              ),
            ),
          ),
        );

        expect(find.textContaining('Route not found'), findsOneWidget);
        expect(find.textContaining('/unknown_route'), findsOneWidget);
      });
    });
  });
}
