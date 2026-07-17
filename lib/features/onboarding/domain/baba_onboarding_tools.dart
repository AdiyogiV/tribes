import 'package:aurogram/core/routing/app_router.dart';
import 'package:aurogram/features/baba/domain/baba_app_map.dart';
import 'package:aurogram/features/baba/domain/baba_context.dart';
import 'package:aurogram/features/baba/domain/baba_tool_registry.dart';

/// Baba's onboarding tools — the actions he uses to co-author the birth-details
/// form by voice. The DECLARATIONS live here and are registered globally once
/// (so they're always in Baba's vocabulary and the Live session is stable).
///
/// Their real behavior is bound by [ImmersiveSetupPage] on entry via
/// [BabaToolRegistry.bindHandler] and unbound on exit. When the user isn't on
/// the birth-details screen the [_unavailable] default handler runs, which tells
/// Baba to take them there first (he has `navigateTo` for that).
class BabaOnboardingTools {
  BabaOnboardingTools._();

  static const setBirthDate = 'setBirthDate';
  static const setBirthTime = 'setBirthTime';
  static const setBirthPlace = 'setBirthPlace';
  static const setGender = 'setGender';
  static const submitBirthDetails = 'submitBirthDetails';
  static const advanceOnboarding = 'advanceOnboarding';

  /// All onboarding tool names — used by the screen to unbind on dispose.
  static const names = [
    setBirthDate,
    setBirthTime,
    setBirthPlace,
    setGender,
    submitBirthDetails,
    advanceOnboarding,
  ];

  static Future<Map<String, dynamic>> _unavailable(
          Map<String, dynamic> args) async {
    // The set/submit tools only work while the birth-details screen is mounted
    // (that's where their real handlers bind). If Baba (or the user) tries to
    // record a detail from anywhere else, DON'T just fail — open the screen for
    // them so the immediate retry succeeds. This makes "note my details" work
    // even when the user never explicitly says "take me there".
    final path = BabaAppMap.pathFor('birthDetails');
    final alreadyThere = BabaContext.instance.screen?.key == 'birthDetails';
    if (path != null && !alreadyThere) {
      appRouter.go(path);
    }
    return {
      // ok:false is critical — the model reflexively trusts `ok` and will
      // tell the user the action worked if it's true. Nothing was recorded
      // here, so this MUST report failure and point at the fix.
      'ok': false,
      'available': false,
      'navigated': path != null && !alreadyThere,
      'message': alreadyThere
          ? 'The screen is open but this value could not be recorded yet. '
              'Try the tool again in a moment.'
          : 'Nothing was saved yet — I have just opened the birth-details '
              'screen for you. Call the same tool again now to record the '
              'value. Never tell the user it is done until a tool returns ok.',
    };
  }

  /// Default for [advanceOnboarding] when the reveal screen isn't mounted:
  /// there's nothing to advance, so report that honestly (no navigation — the
  /// reveal flow only exists right after a chart is created).
  static Future<Map<String, dynamic>> _advanceUnavailable(
          Map<String, dynamic> args) async =>
      {
        'ok': false,
        'advanced': false,
        'available': false,
        'message': 'Not on the chart-reveal flow, so there is nothing to '
            'advance right now.',
      };

  /// The global declarations to register once at app start.
  static List<BabaTool> declarations() => [
        BabaTool(
          name: setBirthDate,
          description: 'Record the user\'s birth DATE once they tell you. '
              'Always read the date back to confirm.',
          parameters: {
            'type': 'object',
            'properties': {
              'year': {'type': 'integer', 'description': 'e.g. 1995'},
              'month': {'type': 'integer', 'description': '1-12'},
              'day': {'type': 'integer', 'description': '1-31'},
            },
            'required': ['year', 'month', 'day'],
          },
          defaultHandler: _unavailable,
        ),
        BabaTool(
          name: setBirthTime,
          description: 'Record the user\'s birth TIME in 24-hour form. Birth '
              'time changes the rising sign, so read it back and confirm.',
          parameters: {
            'type': 'object',
            'properties': {
              'hour24': {'type': 'integer', 'description': '0-23'},
              'minute': {'type': 'integer', 'description': '0-59'},
            },
            'required': ['hour24', 'minute'],
          },
          defaultHandler: _unavailable,
        ),
        BabaTool(
          name: setBirthPlace,
          description: 'Record the user\'s birth PLACE (city). It is geocoded '
              'to coordinates + timezone; confirm the resolved city with them.',
          parameters: {
            'type': 'object',
            'properties': {
              'city': {
                'type': 'string',
                'description': 'City name, optionally with region/country.',
              },
            },
            'required': ['city'],
          },
          defaultHandler: _unavailable,
        ),
        BabaTool(
          name: setGender,
          description: 'Record the user\'s gender (helps traditional chart '
              'reading). Only if they offer it.',
          parameters: {
            'type': 'object',
            'properties': {
              'gender': {
                'type': 'string',
                'enum': ['MALE', 'FEMALE', 'OTHER'],
              },
            },
            'required': ['gender'],
          },
          defaultHandler: _unavailable,
        ),
        BabaTool(
          name: submitBirthDetails,
          description: 'Save the birth details and reveal the chart. Only call '
              'once date, time and place are all set and confirmed.',
          parameters: {'type': 'object', 'properties': {}},
          defaultHandler: _unavailable,
        ),
        BabaTool(
          name: advanceOnboarding,
          description: 'During the post-chart REVEAL flow, move the user to the '
              'next step on screen (sign reveal -> birth reading -> current '
              'times -> done). Call this to LEAD them forward once you have '
              'narrated the current step and they are ready to continue (e.g. '
              'they say "next", "continue", "aage", "haan"). Returns the step '
              'now shown, or ok:false with a reason if the next step is not '
              'ready yet.',
          parameters: {'type': 'object', 'properties': {}},
          defaultHandler: _advanceUnavailable,
        ),
      ];
}
