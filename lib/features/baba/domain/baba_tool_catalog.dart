import 'package:aurogram/core/routing/app_router.dart';
import 'package:aurogram/core/routing/route_names.dart';
import 'package:aurogram/features/baba/domain/baba_tool_registry.dart';

/// The core, always-on tools Baba can use anywhere in the app.
///
/// Registered once at startup from the app composition root (`app_bootstrap`).
/// Feature-specific tools (e.g. onboarding) declare themselves in their own
/// feature and are registered by the composition root too — `baba/` never
/// depends on a feature.
class BabaToolCatalog {
  BabaToolCatalog._();

  /// Register Baba's core tools into the [BabaToolRegistry]. Idempotent.
  static void registerCore() {
    BabaToolRegistry.instance.register(_navigateTo);
  }

  static final BabaTool _navigateTo = BabaTool(
    name: 'navigateTo',
    description: 'Take the user to one of the app\'s main screens. Use when '
        'they ask to go somewhere, or when guiding them there yourself.',
    parameters: const {
      'type': 'object',
      'properties': {
        'destination': {
          'type': 'string',
          'enum': ['home', 'dailyInsight', 'chat'],
          'description': 'Which screen to open.',
        },
      },
      'required': ['destination'],
    },
    defaultHandler: (args) async {
      // Only whitelisted, confirmed-registered routes. (No /profile etc. -
      // those are tabs, not routes, and would throw.)
      const routes = {
        'home': RouteNames.home,
        'dailyInsight': RouteNames.dailyInsight,
        'chat': RouteNames.aiChat,
      };
      final dest = args['destination'] as String?;
      final path = routes[dest];
      if (path == null) {
        return {'navigated': false, 'reason': 'unknown destination: $dest'};
      }
      appRouter.go(path);
      return {'navigated': true, 'destination': dest};
    },
  );
}
