/// Web-specific helper for loading Agora SDK via JavaScript interop
/// 
/// On web, the Agora SDK is lazy-loaded to reduce initial bundle size.
/// This helper calls the loadAgoraSDK() function defined in web/index.html.
library;

import 'dart:async';
import 'dart:js_interop';
import 'package:aurogram/core/logging/app_logger.dart';

/// JavaScript binding for loadAgoraSDK function
@JS('loadAgoraSDK')
external void _loadAgoraSDK(JSFunction? callback);

/// JavaScript binding for isAgoraLoaded function
@JS('isAgoraLoaded')
external bool _isAgoraLoaded();

/// Check if Agora SDK is already loaded
bool isAgoraLoaded() {
  try {
    return _isAgoraLoaded();
  } catch (e) {
    // JS function not available
    return false;
  }
}

/// Load the Agora SDK and wait for it to complete
/// Returns true if loaded successfully, false otherwise
Future<bool> loadAgoraSDK() async {
  // #region agent log
  _debugLog('loadAgoraSDK Dart called', {'alreadyLoaded': isAgoraLoaded()});
  // #endregion
  
  // Check if already loaded
  if (isAgoraLoaded()) {
    // #region agent log
    _debugLog('SDK already loaded in Dart check', {});
    // #endregion
    return true;
  }

  final completer = Completer<bool>();

  try {
    // Create a JS callback that completes our Future
    void onLoaded() {
      // #region agent log
      _debugLog('Dart callback fired from JS', {'completerCompleted': completer.isCompleted});
      // #endregion
      if (!completer.isCompleted) {
        completer.complete(true);
      }
    }

    // Convert Dart function to JS function
    final jsCallback = onLoaded.toJS;

    // #region agent log
    _debugLog('Calling JS loadAgoraSDK', {});
    // #endregion
    
    // Call the JS function
    _loadAgoraSDK(jsCallback);

    // Also set a timeout in case the callback never fires
    Future.delayed(const Duration(seconds: 15), () {
      if (!completer.isCompleted) {
        // Check if it loaded without callback
        final loaded = isAgoraLoaded();
        // #region agent log
        _debugLog('Timeout reached, checking status', {'loaded': loaded});
        // #endregion
        if (loaded) {
          completer.complete(true);
        } else {
          completer.complete(false);
        }
      }
    });

    return await completer.future;
  } catch (e) {
    // #region agent log
    _debugLog('loadAgoraSDK error', {'error': e.toString()});
    // #endregion
    // JS interop error - likely not on web or function not defined
    return false;
  }
}

// #region agent log
void _debugLog(String message, Map<String, dynamic> data) {
  try {
    // ignore: avoid_dynamic_calls
    _sendDebugLog(message, data);
  } catch (_) {
    // Fallback if AppLogger fails at platform boundary
  }
}

void _sendDebugLog(String message, Map<String, dynamic> data) {
  AppLogger.d('AgoraWebHelper: $message', category: LogCategory.voice, data: data);
}
// #endregion
