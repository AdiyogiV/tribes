import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:aurogram/core/routing/route_names.dart';
import 'package:aurogram/core/logging/app_logger.dart';
import 'package:aurogram/shared/models/call.dart';

// ── Page imports (centralized — only this file should import pages) ──────────
import 'package:aurogram/features/astrology/presentation/pages/daily_insight_page.dart';
import 'package:aurogram/features/astrology/presentation/pages/astrology_details_page.dart';
import 'package:aurogram/features/astrology/presentation/pages/astrology_setup_page.dart';
import 'package:aurogram/features/astrology/presentation/pages/astro_chat_page.dart';
import 'package:aurogram/features/ayurveda/presentation/pages/ayurveda_details_page.dart';
import 'package:aurogram/features/ayurveda/presentation/pages/vikriti_checkin_page.dart';
import 'package:aurogram/features/ayurveda/presentation/pages/prakriti_refinement_page.dart';
import 'package:aurogram/features/ai_chat/presentation/pages/ai_chat_page.dart';
import 'package:aurogram/features/ai_chat/presentation/pages/recent_conversations_page.dart';
import 'package:aurogram/features/astrology/presentation/widgets/cosmic_dashboard.dart';
import 'package:aurogram/features/feed/presentation/pages/thread_view.dart';
import 'package:aurogram/features/spaces/presentation/pages/space_screen.dart';
import 'package:aurogram/features/spaces/presentation/pages/space_chat_screen.dart';
import 'package:aurogram/features/spaces/presentation/pages/edit_space.dart';
import 'package:aurogram/features/spaces/presentation/pages/add_spaces_members.dart';
import 'package:aurogram/features/profile/presentation/pages/user_profile.dart';
import 'package:aurogram/features/profile/presentation/pages/social/invites.dart';
import 'package:aurogram/features/profile/presentation/pages/social/requests.dart';
import 'package:aurogram/features/profile/presentation/pages/social/followers_following_page.dart';
import 'package:aurogram/features/profile/presentation/pages/social/aura_leaderboard.dart';
import 'package:aurogram/features/calling/presentation/pages/group_call_screen.dart';
import 'package:aurogram/features/calling/presentation/pages/incoming_call_screen.dart'
    if (dart.library.html) 'package:aurogram/platform/incoming_call_screen_stub.dart';
import 'package:aurogram/features/calling/presentation/pages/call_screen.dart'
    if (dart.library.html) 'package:aurogram/platform/call_screen_stub.dart';
import 'package:aurogram/features/anonymous_messages/pages/inbox_screen.dart';
import 'package:aurogram/features/anonymous_messages/pages/get_link_screen.dart';
import 'package:aurogram/features/anonymous_messages/pages/send_composer_screen.dart';
import 'package:aurogram/features/spaces/presentation/pages/invite_landing_page.dart';
import 'package:aurogram/features/auth/login.dart';
import 'package:aurogram/shared/models/ayurveda_profile.dart';
import 'package:aurogram/shared/models/astrology_profile.dart';
import 'package:aurogram/shared/services/media/audio_input_service.dart';
import 'package:aurogram/app/tabs/tab_handler.dart';
import 'package:aurogram/features/notifications/presentation/pages/notifications.dart';
import 'package:aurogram/features/settings/presentation/pages/user_settings.dart';
import 'package:aurogram/features/stories/pages/story_composer_page.dart';
import 'package:aurogram/features/profile/presentation/pages/edit_user_profile.dart';
import 'package:aurogram/features/profile/presentation/pages/social/namaste_history.dart';
import 'package:aurogram/features/creation/pages/uploads_page.dart';
import 'package:aurogram/features/spaces/presentation/pages/gram_creation_page.dart'
    show SpaceCreationPage;
import 'package:aurogram/features/stories/pages/story_viewer_page.dart';
import 'package:aurogram/features/spaces/presentation/widgets/media_gallery_page.dart';
import 'package:aurogram/features/spaces/presentation/widgets/tiles/video_player_screen.dart';
import 'package:aurogram/features/astrology/presentation/pages/saved_insights_page.dart';
import 'package:aurogram/features/astrology/presentation/pages/compatibility_details_page.dart';
import 'package:aurogram/features/onboarding/presentation/pages/onboarding_complete.dart';

/// Global app router instance — set once during app startup.
///
/// Services that lack a BuildContext can use:
///   `appRouter.push('/user/abc123');`
///
/// Widgets should prefer:
///   `context.push('/user/abc123');`
late final GoRouter appRouter;

/// Creates and assigns the global [appRouter].
///
/// [navigatorKey] is shared with services that need direct navigator access
/// during the migration period. Once all navigation goes through GoRouter,
/// the navigatorKey can be removed.
GoRouter createAppRouter(GlobalKey<NavigatorState> navigatorKey) {
  appRouter = GoRouter(
    navigatorKey: navigatorKey,
    initialLocation: RouteNames.home,
    debugLogDiagnostics: false, // Set true for route debugging

    // ── Routes ───────────────────────────────────────────────────────────
    routes: [
      // Home — TabHandler manages its own auth state + tab navigation
      GoRoute(
        path: RouteNames.home,
        name: 'home',
        builder: (_, __) => TabHandler(),
      ),

      // ── Profiles ─────────────────────────────────────────────────────
      GoRoute(
        path: '${RouteNames.userProfile}/:uid',
        name: 'userProfile',
        builder: (_, state) => UserProfilePage(
          uid: state.pathParameters['uid'],
        ),
      ),

      // ── Spaces ───────────────────────────────────────────────────────
      GoRoute(
        path: '${RouteNames.spaceScreen}/:rid',
        name: 'spaceScreen',
        builder: (_, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return SpaceScreen(
            rid: state.pathParameters['rid'] ?? '',
            postId: extra['postId'] as String?,
          );
        },
      ),

      GoRoute(
        path: '${RouteNames.spaceChatScreen}/:spaceId',
        name: 'spaceChatScreen',
        builder: (_, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return SpaceChatScreen(
            spaceId: state.pathParameters['spaceId'] ?? '',
            space: extra['space'],
            otherUserId: extra['otherUserId'] as String?,
          );
        },
      ),

      // ── Content ──────────────────────────────────────────────────────
      GoRoute(
        path: '${RouteNames.threadView}/:postId',
        name: 'threadView',
        builder: (_, state) => ThreadView(
          postId: state.pathParameters['postId'] ?? '',
        ),
      ),

      // ── Astrology ────────────────────────────────────────────────────
      GoRoute(
        path: RouteNames.dailyInsight,
        name: 'dailyInsight',
        builder: (_, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return DailyInsightPage(
            uid: extra['uid'] as String? ?? '',
            highlightCardIndex: extra['cardIndex'] as int?,
            insightDate: extra['insightDate'] as String?,
          );
        },
      ),

      // ── Calling ──────────────────────────────────────────────────────
      GoRoute(
        path: RouteNames.callScreen,
        name: 'callScreen',
        pageBuilder: (_, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return CupertinoPage(
            child: CallScreen(
              calleeId: extra['calleeId'] as String? ?? '',
              calleeName: extra['calleeName'] as String? ?? '',
              calleeAvatar: extra['calleeAvatar'] as String?,
              callType: extra['callType'] as CallType? ?? CallType.voice,
              isIncoming: extra['isIncoming'] as bool? ?? false,
            ),
          );
        },
      ),

      GoRoute(
        path: RouteNames.incomingCall,
        name: 'incomingCall',
        pageBuilder: (_, state) {
          return CupertinoPage(
            child: IncomingCallScreen(call: state.extra as Call),
          );
        },
      ),

      GoRoute(
        path: '${RouteNames.groupCall}/:spaceId',
        name: 'groupCall',
        pageBuilder: (_, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return CupertinoPage(
            child: GroupCallScreen(
              spaceId: state.pathParameters['spaceId'] ?? '',
              spaceName: extra['spaceName'] as String? ?? 'Group Call',
            ),
          );
        },
      ),

      // ── Social ───────────────────────────────────────────────────────
      // ── Social (connections & leaderboard) ─────────────────────────
      GoRoute(
        path: '${RouteNames.followersFollowing}/:userId',
        name: 'followersFollowing',
        builder: (_, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return FollowersFollowingPage(
            userId: state.pathParameters['userId'] ?? '',
            userName: extra['userName'] as String?,
            initialTabIndex: extra['initialTabIndex'] as int? ?? 0,
          );
        },
      ),

      GoRoute(
        path: RouteNames.auraLeaderboard,
        name: 'auraLeaderboard',
        builder: (_, __) => AuraLeaderboardPage(),
      ),

      GoRoute(
        path: RouteNames.invites,
        name: 'invites',
        builder: (_, __) => const Invites(),
      ),

      GoRoute(
        path: RouteNames.requests,
        name: 'requests',
        builder: (_, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return Requests(space: extra?['space'] as String?);
        },
      ),

      // ── Anonymous Messages ───────────────────────────────────────────
      GoRoute(
        path: RouteNames.secretMessagesInbox,
        name: 'secretMessagesInbox',
        builder: (_, __) => const SecretMessagesInboxScreen(),
      ),

      GoRoute(
        path: RouteNames.secretMessagesGetLink,
        name: 'secretMessagesGetLink',
        builder: (_, __) => const SecretMessagesGetLinkScreen(),
      ),

      GoRoute(
        path: '${RouteNames.secretMessageSend}/:slug',
        name: 'secretMessageSend',
        builder: (_, state) => SecretMessageSendComposer(
          slug: state.pathParameters['slug'] ?? '',
        ),
      ),

      // ── Invitations ──────────────────────────────────────────────────
      GoRoute(
        path: '${RouteNames.spaceInvite}/:spaceId',
        name: 'spaceInvite',
        builder: (_, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return InviteLandingPage(
            space: state.pathParameters['spaceId'] ?? '',
            invitee: extra?['inviterId'] as String?,
          );
        },
      ),

      // ── Space Settings & Members ─────────────────────────────────────
      GoRoute(
        path: '${RouteNames.editSpace}/:spaceId',
        name: 'editSpace',
        builder: (_, state) => EditSpace(
          space: state.pathParameters['spaceId'] ?? '',
        ),
      ),

      GoRoute(
        path: '${RouteNames.addSpaceMembers}/:spaceId',
        name: 'addSpaceMembers',
        builder: (_, state) => AddSpacesMember(
          space: state.pathParameters['spaceId'] ?? '',
        ),
      ),

      // ── Astrology ────────────────────────────────────────────────────
      GoRoute(
        path: '${RouteNames.astrologyDetails}/:uid',
        name: 'astrologyDetails',
        builder: (_, state) => AstrologyDetailsPage(
          uid: state.pathParameters['uid'] ?? '',
        ),
      ),

      GoRoute(
        path: RouteNames.astrologySetup,
        name: 'astrologySetup',
        builder: (_, __) => const AstrologySetupPage(),
      ),

      GoRoute(
        path: RouteNames.astroChatPage,
        name: 'astroChatPage',
        builder: (_, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return AstroChatPage(
            astrologyContext: extra['astrologyContext'] as Map<String, dynamic>? ?? {},
            initialMessage: extra['initialMessage'] as String?,
            initialVoiceMessage: extra['initialVoiceMessage'] as InitialVoiceMessage?,
            chatSource: extra['chatSource'] as String? ?? 'astrology',
          );
        },
      ),

      // ── Ayurveda ─────────────────────────────────────────────────────
      GoRoute(
        path: '${RouteNames.ayurvedaDetails}/:uid',
        name: 'ayurvedaDetails',
        builder: (_, state) => AyurvedaDetailsPage(
          uid: state.pathParameters['uid'] ?? '',
        ),
      ),

      GoRoute(
        path: RouteNames.vikritiCheckin,
        name: 'vikritiCheckin',
        builder: (_, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return VikritiCheckInPage(
            ayurvedaProfile: extra['ayurvedaProfile'] as AyurvedaProfile,
            astroProfile: extra['astroProfile'] as AstrologyProfile,
          );
        },
      ),

      GoRoute(
        path: RouteNames.prakritiRefinement,
        name: 'prakritiRefinement',
        builder: (_, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return PrakritiRefinementPage(
            predictedPrakriti: extra['predictedPrakriti'] as PrakritiData,
          );
        },
      ),

      // ── AI Chat ──────────────────────────────────────────────────────
      GoRoute(
        path: RouteNames.aiChat,
        name: 'aiChat',
        builder: (_, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return AiChatPage(
            conversationId: extra?['conversationId'] as String?,
            initialMessage: extra?['initialMessage'] as String?,
            initialVoiceResult: extra?['initialVoiceResult'] as AudioInputResult?,
          );
        },
      ),

      GoRoute(
        path: RouteNames.recentConversations,
        name: 'recentConversations',
        builder: (_, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return RecentConversationsPage(
            onConversationSelected: extra?['onConversationSelected'] as Function(String)?,
          );
        },
      ),

      // ── Cosmic Dashboard ─────────────────────────────────────────────
      GoRoute(
        path: RouteNames.cosmicDashboard,
        name: 'cosmicDashboard',
        builder: (_, __) => const CosmicDashboard(),
      ),

      // ── Notifications ──────────────────────────────────────────────────
      GoRoute(
        path: RouteNames.notifications,
        name: 'notifications',
        builder: (_, __) => Notifications(),
      ),

      // ── Settings ────────────────────────────────────────────────────────
      GoRoute(
        path: RouteNames.settings,
        name: 'settings',
        builder: (_, __) => UserSettingsPage(),
      ),

      // ── Stories ─────────────────────────────────────────────────────────
      GoRoute(
        path: RouteNames.storyComposer,
        name: 'storyComposer',
        builder: (_, __) => const StoryComposerPage(),
      ),

      // ── Profile Editing ─────────────────────────────────────────────────
      GoRoute(
        path: '${RouteNames.editProfile}/:uid',
        name: 'editProfile',
        builder: (_, state) => EditProfile(
          uid: state.pathParameters['uid'],
        ),
      ),

      // ── Namaste History ─────────────────────────────────────────────────
      GoRoute(
        path: RouteNames.namasteHistory,
        name: 'namasteHistory',
        builder: (_, __) => NamasteHistoryPage(),
      ),

      // ── Uploads ─────────────────────────────────────────────────────────
      GoRoute(
        path: RouteNames.uploads,
        name: 'uploads',
        builder: (_, __) => UploadsPage(),
      ),

      // ── Space Creation ──────────────────────────────────────────────────
      GoRoute(
        path: RouteNames.spaceCreation,
        name: 'spaceCreation',
        builder: (_, __) => SpaceCreationPage(),
      ),

      // ── Story Viewer ──────────────────────────────────────────────────
      GoRoute(
        path: RouteNames.storyViewer,
        name: 'storyViewer',
        builder: (_, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return StoryViewerPage(
            userIds: extra['userIds'] as List<String>? ?? [],
            initialUserIndex: extra['initialUserIndex'] as int? ?? 0,
          );
        },
      ),

      // ── Media Gallery & Video Player ─────────────────────────────────
      GoRoute(
        path: '${RouteNames.mediaGallery}/:spaceId',
        name: 'mediaGallery',
        builder: (_, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return MediaGalleryPage(
            spaceId: state.pathParameters['spaceId'] ?? '',
            title: extra['title'] as String? ?? 'Media',
          );
        },
      ),

      GoRoute(
        path: RouteNames.videoPlayer,
        name: 'videoPlayer',
        builder: (_, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return VideoPlayerScreen(
            videoUrl: extra['videoUrl'] as String? ?? '',
          );
        },
      ),

      // ── Saved Insights ──────────────────────────────────────────────
      GoRoute(
        path: '${RouteNames.savedInsights}/:uid',
        name: 'savedInsights',
        builder: (_, state) => SavedInsightsPage(
          uid: state.pathParameters['uid'] ?? '',
        ),
      ),

      // ── Compatibility Details ────────────────────────────────────────
      GoRoute(
        path: RouteNames.compatibilityDetails,
        name: 'compatibilityDetails',
        builder: (_, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return CompatibilityDetailsPage(
            result: extra['result'],
            otherUserId: extra['otherUserId'] as String? ?? '',
            currentUserName: extra['currentUserName'] as String? ?? '',
            otherUserName: extra['otherUserName'] as String? ?? '',
            currentUserPhotoUrl: extra['currentUserPhotoUrl'] as String?,
            otherUserPhotoUrl: extra['otherUserPhotoUrl'] as String?,
            currentUserSun: extra['currentUserSun'] as String?,
            currentUserMoon: extra['currentUserMoon'] as String?,
            currentUserRising: extra['currentUserRising'] as String?,
            otherUserSun: extra['otherUserSun'] as String?,
            otherUserMoon: extra['otherUserMoon'] as String?,
            otherUserRising: extra['otherUserRising'] as String?,
          );
        },
      ),

      // ── Onboarding Complete ──────────────────────────────────────────
      GoRoute(
        path: RouteNames.onboardingComplete,
        name: 'onboardingComplete',
        builder: (_, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return OnboardingComplete(
            hasBirthDetails: extra['hasBirthDetails'] as bool? ?? false,
            isUpdate: extra['isUpdate'] as bool? ?? false,
          );
        },
      ),

      // ── Auth ─────────────────────────────────────────────────────────
      GoRoute(
        path: RouteNames.login,
        name: 'login',
        builder: (_, __) => LoginPage(),
      ),
    ],

    // ── Error page ─────────────────────────────────────────────────────
    errorBuilder: (_, state) {
      AppLogger.w('Route not found: ${state.uri}',
          category: LogCategory.general);
      return Scaffold(
        body: Center(
          child: Text('Route not found: ${state.uri}'),
        ),
      );
    },
  );

  return appRouter;
}
