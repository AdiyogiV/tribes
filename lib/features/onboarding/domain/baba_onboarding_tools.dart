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

  /// All onboarding tool names — used by the screen to unbind on dispose.
  static const names = [
    setBirthDate,
    setBirthTime,
    setBirthPlace,
    setGender,
    submitBirthDetails,
  ];

  static Future<Map<String, dynamic>> _unavailable(
          Map<String, dynamic> args) async =>
      {
        'available': false,
        'message': 'The birth-details screen is not open. Take the user there '
            'first (navigateTo), then set the value.',
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
      ];
}
