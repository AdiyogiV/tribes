/// Centralized route name constants for the entire app.
///
/// Services MUST use these constants + pushNamed/push with arguments
/// instead of importing page widgets directly. This breaks the
/// service → page dependency that prevents clean feature isolation.
class RouteNames {
  RouteNames._();

  // ── Tabs ──────────────────────────────────────────────────────────────
  static const home = '/';
  static const profile = '/profile';
  static const spaces = '/spaces';

  // ── Auth ──────────────────────────────────────────────────────────────
  static const login = '/login';
  static const signup = '/signup';

  // ── Profiles ─────────────────────────────────────────────────────────
  static const userProfile = '/user';

  // ── Spaces ───────────────────────────────────────────────────────────
  static const spaceScreen = '/space';
  static const spaceChatScreen = '/space/chat';

  // ── Content ──────────────────────────────────────────────────────────
  static const threadView = '/post';

  // ── Astrology ────────────────────────────────────────────────────────
  static const dailyInsight = '/astrology/insight';
  static const astrologyDetails = '/astrology/details';
  static const astrologySetup = '/astrology/setup';
  static const astroChatPage = '/astrology/chat';

  // ── Ayurveda ────────────────────────────────────────────────────────
  static const ayurvedaDetails = '/ayurveda/details';

  // ── AI Chat ─────────────────────────────────────────────────────────
  static const aiChat = '/ai/chat';
  static const recentConversations = '/ai/conversations';

  // ── Cosmic Dashboard ────────────────────────────────────────────────
  static const cosmicDashboard = '/cosmic/dashboard';

  // ── Calling ──────────────────────────────────────────────────────────
  static const callScreen = '/call';
  static const incomingCall = '/call/incoming';
  static const groupCall = '/call/group';

  // ── Social ───────────────────────────────────────────────────────────
  static const invites = '/invites';
  static const requests = '/requests';
  static const followersFollowing = '/user/connections';
  static const auraLeaderboard = '/leaderboard';

  // ── Anonymous Messages ───────────────────────────────────────────────
  static const secretMessagesInbox = '/anonymous/inbox';
  static const secretMessagesGetLink = '/anonymous/get-link';
  static const secretMessageSend = '/anonymous/send';

  // ── Spaces (settings & members) ──────────────────────────────────
  static const editSpace = '/space/edit';
  static const addSpaceMembers = '/space/members/add';

  // ── Spaces (invitations) ────────────────────────────────────────
  static const spaceInvite = '/space/invite';

  // ── Stories ──────────────────────────────────────────────────────────
  static const storyComposer = '/stories/compose';

  // ── Notifications ────────────────────────────────────────────────────
  static const notifications = '/notifications';

  // ── Settings ─────────────────────────────────────────────────────────
  static const settings = '/settings';

  // ── Profile editing ─────────────────────────────────────────────────
  static const editProfile = '/profile/edit';

  // ── Namaste History ─────────────────────────────────────────────────
  static const namasteHistory = '/namaste/history';

  // ── Uploads ─────────────────────────────────────────────────────────
  static const uploads = '/uploads';

  // ── Ayurveda (refinement) ────────────────────────────────────────────
  static const prakritiRefinement = '/ayurveda/prakriti-refinement';

  // ── Space Creation ──────────────────────────────────────────────────
  static const spaceCreation = '/space/create';

  // ── Stories (viewer) ────────────────────────────────────────────────
  static const storyViewer = '/stories/view';

  // ── Media ───────────────────────────────────────────────────────────
  static const mediaGallery = '/media/gallery';
  static const videoPlayer = '/media/video';

  // ── Astrology (additional) ──────────────────────────────────────────
  static const savedInsights = '/astrology/saved';
  static const compatibilityDetails = '/astrology/compatibility';
  static const currentSky = '/astrology/current-sky';

  // ── Onboarding ──────────────────────────────────────────────────────
  static const onboardingComplete = '/onboarding/complete';
}
