import 'package:aurogram/core/logging/app_logger.dart';
import 'package:aurogram/features/baba/domain/baba_tool_registry.dart';
import 'package:aurogram/features/profile/domain/user_service.dart';

/// Baba's identity tool for the value-first flow.
///
/// Unlike the birth-details setters (which only work on the setup screen), this
/// has a REAL default handler that works ANYWHERE — because Baba asks the
/// user's name up front, on the dashboard, before any login. The name is saved
/// under the current (anonymous guest) uid so he can address them by name and
/// so registering later is seamless (see [UserRegistration.saveGuestName]).
class BabaIdentityTools {
  BabaIdentityTools._();

  static const setUserName = 'setUserName';

  static Future<Map<String, dynamic>> _saveName(
      Map<String, dynamic> args) async {
    final name = (args['name'] as String?)?.trim() ?? '';
    if (name.isEmpty) {
      return {'saved': false, 'message': 'No name was provided.'};
    }
    final ok = await UserService().saveGuestName(name);
    if (!ok) {
      AppLogger.w('setUserName: saveGuestName returned false',
          category: LogCategory.auth);
      return {
        'saved': false,
        'message': 'Could not save the name right now; you may proceed anyway.',
      };
    }
    return {'saved': true, 'name': name};
  }

  /// The global declaration(s) to register once at app start.
  static List<BabaTool> declarations() => [
        BabaTool(
          name: setUserName,
          description:
              "Record the user's first name (or preferred name) as soon as "
              'they tell you, early in the conversation. Use it to address '
              'them warmly for the rest of the session. Read it back to '
              'confirm you heard it right.',
          parameters: {
            'type': 'object',
            'properties': {
              'name': {
                'type': 'string',
                'description': "The user's name as they said it.",
              },
            },
            'required': ['name'],
          },
          defaultHandler: _saveName,
        ),
      ];
}
