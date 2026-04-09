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

  // ── Calling ──────────────────────────────────────────────────────────
  static const callScreen = '/call';
  static const incomingCall = '/call/incoming';
  static const groupCall = '/call/group';

  // ── Social ───────────────────────────────────────────────────────────
  static const invites = '/invites';
  static const requests = '/requests';

  // ── Anonymous Messages ───────────────────────────────────────────────
  static const secretMessagesInbox = '/anonymous/inbox';
  static const secretMessageSend = '/anonymous/send';

  // ── Spaces (invitations) ────────────────────────────────────────
  static const spaceInvite = '/space/invite';

  // ── Stories ──────────────────────────────────────────────────────────
  static const storyComposer = '/stories/compose';

  // ── Notifications ────────────────────────────────────────────────────
  static const notifications = '/notifications';

  // ── Settings ─────────────────────────────────────────────────────────
  static const settings = '/settings';
}
