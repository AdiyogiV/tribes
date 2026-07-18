import 'package:aurogram/core/routing/app_router.dart';
import 'package:aurogram/features/baba/domain/baba_app_map.dart';
import 'package:aurogram/features/baba/domain/baba_context.dart';
import 'package:aurogram/features/baba/domain/baba_tool_registry.dart';

/// Baba's login tool — lets him fill a guest's phone number into the login
/// screen by voice so securing an account is hands-free.
///
/// Same pattern as [BabaOnboardingTools]: the DECLARATION is registered globally
/// once (so it's always in Baba's vocabulary and the CX/Live sessions stay
/// stable), while the real behaviour is bound by [LoginPage] on entry via
/// [BabaToolRegistry.bindHandler] and unbound on exit. When the login screen
/// isn't mounted, the [_unavailable] default handler opens it so the immediate
/// retry succeeds.
///
/// KEEP the tool `name` in sync with voice-relay/src/cx_tools.js (CX provisions
/// its own copy of the schema; the names MUST match for dispatch to route).
class BabaLoginTools {
  BabaLoginTools._();

  static const setPhoneNumber = 'setPhoneNumber';
  static const setOtp = 'setOtp';

  /// Tool names — used by the screen to unbind on dispose.
  static const names = [setPhoneNumber, setOtp];

  static Future<Map<String, dynamic>> _unavailable(
      Map<String, dynamic> args) async {
    // The phone field only exists while the login screen is mounted (that's
    // where the real handler binds). If Baba tries to fill it from elsewhere,
    // open login for him so the immediate retry lands on the right screen.
    final path = BabaAppMap.pathFor('login');
    final alreadyThere = BabaContext.instance.screen?.key == 'login';
    if (path != null && !alreadyThere) {
      appRouter.go(path);
    }
    return {
      // ok:false is critical — the model trusts `ok` to decide whether to tell
      // the user it worked. Nothing was filled, so report failure + the fix.
      'ok': false,
      'available': false,
      'navigated': path != null && !alreadyThere,
      'message': alreadyThere
          ? 'The login screen is open but the number could not be filled yet. '
              'Try setPhoneNumber again in a moment.'
          : 'Nothing was filled yet — I have just opened the login screen. '
              'Call setPhoneNumber again now to enter the number. Never tell '
              'the user it is done until a tool returns ok.',
    };
  }

  /// The global declaration to register once at app start.
  static List<BabaTool> declarations() => [
        BabaTool(
          name: setPhoneNumber,
          description: 'Fill the user\'s phone number into the login screen so '
              'a guest can secure their account. Pass the digits in "phone"; '
              'optionally "countryCode" like "+91" (defaults to +91) and '
              'send:true to send the OTP. You cannot read the SMS code — ask '
              'the user to enter the OTP themselves after it is sent.',
          parameters: {
            'type': 'object',
            'properties': {
              'phone': {
                'type': 'string',
                'description': 'Phone number digits, national part only '
                    '(e.g. "7678471702"). Non-digits are stripped.',
              },
              'countryCode': {
                'type': 'string',
                'description': 'Dialing code with plus, e.g. "+91". '
                    'Defaults to +91.',
              },
              'send': {
                'type': 'boolean',
                'description':
                    'If true, send the OTP right after filling the number.',
              },
            },
            'required': ['phone'],
          },
          defaultHandler: _unavailable,
          isMutation: true,
          requiresRequestId: true,
        ),
        BabaTool(
          name: setOtp,
          description: 'Fill (and optionally submit) the SMS one-time code on '
              'the login screen. You cannot READ the code — ask the user to '
              'read it out, then pass the digits in "code". Set submit:true to '
              'verify it immediately. Only works after the OTP has been sent.',
          parameters: {
            'type': 'object',
            'properties': {
              'code': {
                'type': 'string',
                'description': 'The OTP digits the user read out '
                    '(e.g. "123456"). Non-digits are stripped.',
              },
              'submit': {
                'type': 'boolean',
                'description':
                    'If true, verify the code right after filling it.',
              },
            },
            'required': ['code'],
          },
          defaultHandler: _unavailable,
          isMutation: true,
          requiresRequestId: true,
        ),
      ];
}
