import 'package:cloud_functions/cloud_functions.dart';

import 'package:aurogram/core/logging/app_logger.dart';

/// Thin client for Aryabhatt's durable-memory controls.
///
/// Memory itself is built/read entirely on the backend (see
/// `backend/functions/user_memory.js`). The only thing the app needs to do is
/// give the user a "forget me" escape hatch — routed through `socialGateway`'s
/// `clearAiMemory` method so we don't spin up yet another Cloud Function.
class AryabhattMemoryService {
  AryabhattMemoryService({FirebaseFunctions? functions})
      : _functions =
            functions ?? FirebaseFunctions.instanceFor(region: 'asia-southeast2');

  final FirebaseFunctions _functions;

  /// Wipe the signed-in user's durable Aryabhatt memory. The next conversation
  /// opens with a blank slate. Throws on failure so the UI can surface it.
  Future<void> clearMemory() async {
    try {
      final callable = _functions.httpsCallable('socialGateway');
      await callable.call<dynamic>({'method': 'clearAiMemory'});
      AppLogger.i('Aryabhatt memory cleared', category: LogCategory.general);
    } on FirebaseFunctionsException catch (e) {
      AppLogger.e(
        'clearAiMemory failed',
        category: LogCategory.general,
        error: e,
      );
      rethrow;
    }
  }
}
