import 'package:firebase_auth/firebase_auth.dart';

import 'package:aurogram/core/routing/app_router.dart';
import 'package:aurogram/core/routing/route_names.dart';
import 'package:aurogram/features/baba/domain/baba_app_map.dart';
import 'package:aurogram/features/baba/domain/baba_chat_controller.dart';
import 'package:aurogram/features/baba/domain/baba_context.dart';
import 'package:aurogram/features/baba/domain/baba_tool_registry.dart';
import 'package:aurogram/features/baba/voice/voice_session_controller.dart';

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
    BabaToolRegistry.instance.register(_endCall);
  }

  /// His eyes: what screen is the user on, and what's visible right now.
  static final BabaTool _whereAmI = BabaTool(
    name: 'whereAmI',
    description:
        'Check where the user currently is in the app and what is on their '
        'screen right now. Returns route, screen, label and description plus, '
        'when the screen supports it, an "onScreen" object: status '
        '(loading/ready/empty/error), a one-line "headline" you can read almost '
        'verbatim, "facts" (key->value you can cite), and "items" (visible item '
        'labels). Read "onScreen" and answer from it — do not guess; if status is '
        'loading/empty, say so instead of inventing. Call this whenever you '
        'need context before helping, explaining, reading the screen aloud, or '
        'leading them somewhere.',
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
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      // The birth CHART route is parameterised (`/astrology/details/:uid`), so
      // it MUST carry the uid in the PATH - navigating to the bare path throws
      // "Route not found". Guard the uid too: without a chart there's nothing
      // to show, so send them to set up birth details instead of a broken page.
      if (dest == 'chart') {
        if (uid.isEmpty) {
          return {
            'navigated': false,
            'reason': 'not signed in - cannot open chart',
          };
        }
        appRouter.go('${RouteNames.astrologyDetails}/$uid');
        return {'navigated': true, 'destination': 'chart'};
      }
      // The daily-insight page needs the signed-in uid to stream the profile;
      // without it Firestore throws "document path must be a non-empty string".
      final extra = dest == 'dailyInsight' ? {'uid': uid} : null;
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
      // Nothing to pop (top of stack) - fall back to home so "back" never dead-ends.
      appRouter.go(RouteNames.home);
      return {'wentBack': true, 'fellBackToHome': true};
    },
  );

  /// His "goodbye": end the live voice call. The farewell line finishes
  /// playing first (the controller defers the real hang-up), so nothing is
  /// clipped. Use ONLY when the conversation is genuinely done.
  static final BabaTool _endCall = BabaTool(
    name: 'endCall',
    description:
        'End the voice call and say goodbye. Call this ONLY when the '
        'conversation is truly finished - the user said bye/goodbye/that is '
        'all, or you have wrapped everything up. Say your short farewell line '
        'in the SAME turn as this call; the goodbye plays fully before the '
        'call disconnects.',
    parameters: const {'type': 'object', 'properties': {}},
    defaultHandler: (args) async {
      VoiceSessionController().endAfterFarewell();
      return {'ok': true, 'ending': true};
    },
  );
}
