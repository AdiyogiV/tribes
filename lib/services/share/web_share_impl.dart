// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:async';
import 'dart:js_interop';
import 'package:web/web.dart' as web;

/// Web implementation of Web Share API
class WebShareHelper {
  /// Check if Web Share API is available
  static bool get isAvailable {
    try {
      // Check if navigator.share exists by checking the navigator object
      final navigator = web.window.navigator;
      // Use JS interop to check if 'share' property exists
      return _hasShareAPI(navigator as JSObject);
    } catch (e) {
      return false;
    }
  }

  /// Share content using Web Share API
  /// Returns true if share was successful, false otherwise
  static Future<bool> share({
    required String text,
    required String url,
    String? title,
  }) async {
    try {
      if (!isAvailable) return false;
      
      final shareData = web.ShareData(
        title: title ?? 'Check this out',
        text: text,
        url: url,
      );

      await web.window.navigator.share(shareData).toDart;
      return true;
    } catch (e) {
      // User cancelled or share failed
      // AbortError is thrown when user cancels
      if (e.toString().contains('AbortError')) {
        return false; // User cancelled, not an error
      }
      return false;
    }
  }
}

/// JS interop helper to check if share API exists
@JS('Object.prototype.hasOwnProperty.call')
external bool _jsHasProperty(JSObject obj, String prop);

bool _hasShareAPI(JSObject navigator) {
  try {
    // Check if 'share' is a property on navigator
    return _jsHasProperty(navigator, 'share');
  } catch (e) {
    return false;
  }
}
