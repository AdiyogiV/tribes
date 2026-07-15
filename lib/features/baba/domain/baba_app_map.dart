import 'package:aurogram/core/routing/route_names.dart';

/// One screen in Aurogram, as Baba understands it.
///
/// [key] is the short, stable id Baba uses to talk about / navigate to the
/// screen (the `navigateTo` enum value). [path] is the concrete GoRouter route.
/// [navigable] marks screens Baba may open directly with no arguments (so the
/// `navigateTo` enum only ever offers routes that actually work).
class BabaScreen {
  const BabaScreen({
    required this.key,
    required this.path,
    required this.label,
    required this.description,
    this.navigable = true,
  });

  final String key;
  final String path;
  final String label;
  final String description;
  final bool navigable;
}

/// The app landscape — the ONE place that knows what Aurogram's screens are.
///
/// This is Baba's map. It drives three things so they can never drift apart:
///   * the `navigateTo` tool's destination enum + path resolution,
///   * `whereAmI` / [describe] — turning the current route into a human label,
///   * [promptSummary] — the "here's the app and what you can do" briefing
///     baked into Baba's persona (client copy; the CX playbook mirrors it).
///
/// Add a screen here once and Baba can name it, describe it, and take the user
/// there — no per-screen wiring. Keep it curated (the places worth leading a
/// user to), not an exhaustive dump of every route.
class BabaAppMap {
  BabaAppMap._();

  /// Curated, ordered list of screens Baba knows about.
  static const List<BabaScreen> screens = [
    BabaScreen(
      key: 'home',
      path: RouteNames.home,
      label: 'Home',
      description:
          'The home dashboard: daily cosmic snapshot, panchang and the feed.',
    ),
    BabaScreen(
      key: 'dailyInsight',
      path: RouteNames.dailyInsight,
      label: 'Daily Insight',
      description: "The user's personalised astrological insight for today.",
    ),
    BabaScreen(
      key: 'chat',
      path: RouteNames.aiChat,
      label: 'Chat',
      description: 'Text chat with Aurobhatt (Baba) for deeper questions.',
    ),
    BabaScreen(
      key: 'birthDetails',
      path: RouteNames.astrologySetup,
      label: 'Birth Details Setup',
      description:
          'Where birth date, time and place are collected to build the chart.',
    ),
    BabaScreen(
      key: 'chart',
      path: RouteNames.astrologyDetails,
      label: 'Birth Chart',
      description: "The user's full birth chart, houses and placements.",
    ),
    BabaScreen(
      key: 'savedInsights',
      path: RouteNames.savedInsights,
      label: 'Saved Insights',
      description: 'Insights the user has saved to revisit.',
    ),
    BabaScreen(
      key: 'ayurveda',
      path: RouteNames.ayurvedaDetails,
      label: 'Ayurveda',
      description: "The user's Ayurvedic constitution and wellness guidance.",
    ),
    BabaScreen(
      key: 'notifications',
      path: RouteNames.notifications,
      label: 'Notifications',
      description: 'Recent notifications and activity.',
    ),
    BabaScreen(
      key: 'settings',
      path: RouteNames.settings,
      label: 'Settings',
      description: 'App settings and preferences.',
    ),
    BabaScreen(
      key: 'login',
      path: RouteNames.login,
      label: 'Log in / Sign up',
      description:
          'Phone login/signup. Sending a guest here upgrades their anonymous '
          'session to a real account IN PLACE, so their chart and data carry '
          'over. Open it when a guest agrees to secure their data.',
    ),
    // Reachable/known screens Baba can NAME and recognise, but not open blindly
    // (they need arguments), so they're excluded from the navigateTo enum.
    BabaScreen(
      key: 'profile',
      path: RouteNames.profile,
      label: 'Profile',
      description: "A profile screen.",
      navigable: false,
    ),
    BabaScreen(
      key: 'spaces',
      path: RouteNames.spaces,
      label: 'Spaces',
      description: 'Shared spaces and group timelines.',
      navigable: false,
    ),
    BabaScreen(
      key: 'onboardingReveal',
      path: RouteNames.onboardingComplete,
      label: 'Chart Reveal',
      description:
          'The onboarding reveal: Sun/Moon/Rising cards, then the readings.',
      navigable: false,
    ),
  ];

  /// Destinations Baba may open directly — the `navigateTo` enum.
  static List<String> get navigableKeys =>
      screens.where((s) => s.navigable).map((s) => s.key).toList();

  /// Resolve a `navigateTo` destination key to its route path.
  static String? pathFor(String key) {
    for (final s in screens) {
      if (s.key == key) return s.path;
    }
    return null;
  }

  /// Best-match the current concrete location (URI path) to a known screen.
  /// Exact match wins; otherwise the longest path prefix (handles param routes
  /// like `/user/:uid` matching `/user`). Null when nothing sensible matches.
  static BabaScreen? match(String location) {
    final path = Uri.tryParse(location)?.path ?? location;
    BabaScreen? exact;
    BabaScreen? prefix;
    var prefixLen = 0;
    for (final s in screens) {
      if (s.path == path) {
        exact = s;
        break;
      }
      // '/' would prefix-match everything; only use it on an exact hit above.
      if (s.path != RouteNames.home &&
          path.startsWith(s.path) &&
          s.path.length > prefixLen) {
        prefix = s;
        prefixLen = s.path.length;
      }
    }
    return exact ?? prefix;
  }

  /// One-line human description of where the user currently is.
  static String describe(String location) {
    final s = match(location);
    if (s == null) return 'The user is on a screen ($location).';
    return 'The user is on the ${s.label} screen. ${s.description}';
  }

  /// Compact briefing of the app + Baba's powers, for his persona/prompt.
  /// The CX playbook mirrors this (see voice-relay/src/cx_tools.js).
  static String get promptSummary {
    final list = screens
        .map((s) => '- ${s.label}: ${s.description}')
        .join('\n');
    return 'You live inside Aurogram, a Vedic astrology + wellness companion '
        'app. You are not a passive chatbot — you can see where the user is and '
        'operate the app for them. The main screens are:\n$list\n\n'
        'Your powers: whereAmI (check what screen the user is on and what is '
        'shown), navigateTo (open a screen), goBack (return to the previous '
        'screen). Use them to LEAD the user, not just answer.';
  }
}
