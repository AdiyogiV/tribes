import 'package:firebase_auth/firebase_auth.dart';

import 'package:aurogram/core/routing/app_router.dart';
import 'package:aurogram/core/routing/route_names.dart';
import 'package:aurogram/features/baba/domain/baba_app_map.dart';
import 'package:aurogram/features/baba/domain/baba_chat_controller.dart';
import 'package:aurogram/features/baba/domain/baba_context.dart';
import 'package:aurogram/features/baba/domain/baba_tool_registry.dart';

/// Baba's core, always-on powers — the generic verbs that work on EVERY screen.
///
/// Design: a tiny, generic capability set (see the user's "real Jarvis" goal)
/// rather than one bespoke tool per feature. Screens and destinations come from
/// [BabaAppMap] (one source of truth), so adding a screen there instantly makes
/// it navigable and describable — no new tools, no new prompt.
///
/// Registered once at startup from the app composition root (`app_bootstrap`).
/// Feature-specific tools (e.g. onboarding setters) declare themselves in their
/// own feature; `baba/` never depends on a feature.
class BabaToolCatalog {
  BabaToolCatalog._();

  /// Register Baba's core tools into the [BabaToolRegistry]. Idempotent.
  static void registerCore() {
    BabaToolRegistry.instance.register(_whereAmI);
    BabaToolRegistry.instance.register(_navigateTo);
    BabaToolRegistry.instance.register(_goBack);
  }

  /// His eyes: what screen is the user on, and what's visible right now.
  static final BabaTool _whereAmI = BabaTool(
    name: 'whereAmI',
    description:
        'Check where the user currently is in the app and what is on their '
        'screen right now. Returns route, screen, label and description plus, '
        'when the screen supports it, an "onScreen" object with the ACTUAL '
        'live data being displayed (e.g. the insight theme and section titles, '
        "the chart's sun/moon/rising, the birth-setup step and captured "
        'values). Read "onScreen" and answer from it — do not guess. Call this '
        'whenever you need context before helping, explaining, reading the '
        'screen aloud, or leading them somewhere.',
    parameters: const {'type': 'object', 'properties': {}},
    defaultHandler: (args) async => BabaContext.instance.snapshot(),
  );

  /// His feet: open any known screen.
  static final BabaTool _navigateTo = BabaTool(
    name: 'navigateTo',
    description: "Take the user to one of the app's screens. Use when they ask "
        'to go somewhere, or when leading them there yourself.',
    parameters: {
      'type': 'object',
      'properties': {
        'destination': {
          'type': 'string',
          'enum': BabaAppMap.navigableKeys,
          'description': 'Which screen to open. Use "birthDetails" to open the '
              'birth-details setup so you can collect date, time and place.',
        },
      },
      'required': ['destination'],
    },
    defaultHandler: (args) async {
      final dest = args['destination'] as String?;
      // "chat" isn't a route — Baba wraps the app, so typing to him happens in
      // an in-place floating sheet, not a separate page. Open it right here.
      if (dest == 'chat') {
        BabaChatController.instance.open();
        return {'navigated': true, 'destination': 'chat'};
      }
      final path = dest == null ? null : BabaAppMap.pathFor(dest);
      if (path == null) {
        return {'navigated': false, 'reason': 'unknown destination: $dest'};
      }
      // The daily-insight page needs the signed-in uid to stream the profile;
      // without it Firestore throws "document path must be a non-empty string".
      final extra = dest == 'dailyInsight'
          ? {'uid': FirebaseAuth.instance.currentUser?.uid ?? ''}
          : null;
      appRouter.go(path, extra: extra);
      return {'navigated': true, 'destination': dest};
    },
  );

  /// His "back": return to the previous screen (or home if nothing to pop).
  static final BabaTool _goBack = BabaTool(
    name: 'goBack',
    description:
        'Go back to the previous screen. Use when the user says "go back", '
        '"take me back", or wants to leave the current screen.',
    parameters: const {'type': 'object', 'properties': {}},
    defaultHandler: (args) async {
      if (appRouter.canPop()) {
        appRouter.pop();
        return {'wentBack': true};
      }
      // Nothing to pop (top of stack) — fall back to home so "back" never dead-ends.
      appRouter.go(RouteNames.home);
      return {'wentBack': true, 'fellBackToHome': true};
    },
  );
}
