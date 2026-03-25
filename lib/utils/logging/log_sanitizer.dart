/// Utilities to sanitize log payloads so we don't leak PII/secrets in console logs.
///
/// This is intentionally conservative and lightweight (no dependencies).
class LogSanitizer {
  static const String _redacted = '***REDACTED***';

  // Keys that commonly contain secrets/PII.
  static const Set<String> _sensitiveKeyTokens = {
    'password',
    'passcode',
    'otp',
    'token',
    'idtoken',
    'accesstoken',
    'refreshtoken',
    'authorization',
    'bearer',
    'apikey',
    'api_key',
    'secret',
    'privatekey',
    'session',
    'cookie',
    'phone',
    'phonenumber',
    'email',
  };

  static const Set<String> _maskIdTokens = {
    'uid',
    'userid',
    'user_id',
    'callerid',
    'calleeid',
    'spaceid',
    'postid',
    'chatid',
    'messageid',
    'notificationid',
    'deviceid',
  };

  /// Sanitize a data map passed to AppLogger.
  static Map<String, Object?>? sanitizeData(Map<String, Object?>? data) {
    if (data == null) return null;
    return _sanitizeMap(data, depth: 0);
  }

  static Map<String, Object?> _sanitizeMap(Map<String, Object?> input,
      {required int depth}) {
    // Prevent runaway recursion.
    if (depth >= 5) return <String, Object?>{'_truncated': true};

    final out = <String, Object?>{};
    input.forEach((key, value) {
      final normalized = _normalizeKey(key);

      if (_isSensitiveKey(normalized)) {
        out[key] = _redacted;
        return;
      }

      if (_shouldMaskId(normalized)) {
        out[key] = _maskId(value);
        return;
      }

      out[key] = _sanitizeValue(value, depth: depth + 1);
    });
    return out;
  }

  static Object? _sanitizeValue(Object? value, {required int depth}) {
    if (value == null) return null;

    if (value is String) {
      return _truncateString(value);
    }

    if (value is num || value is bool) return value;

    if (value is Map) {
      // Best-effort cast; if it doesn't match expected types, stringify.
      final map = <String, Object?>{};
      value.forEach((k, v) {
        if (k is String) {
          map[k] = v is Object ? v : null;
        }
      });
      return _sanitizeMap(map, depth: depth);
    }

    if (value is List) {
      if (depth >= 5) return const ['_truncated'];
      return value.take(25).map((e) => _sanitizeValue(e, depth: depth + 1)).toList();
    }

    // Fallback: avoid dumping large objects.
    return _truncateString(value.toString());
  }

  static String _normalizeKey(String key) {
    return key.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toLowerCase();
  }

  static bool _isSensitiveKey(String normalizedKey) {
    return _sensitiveKeyTokens.any(normalizedKey.contains);
  }

  static bool _shouldMaskId(String normalizedKey) {
    return _maskIdTokens.any(normalizedKey.contains);
  }

  static String _maskId(Object? value) {
    final s = value?.toString();
    if (s == null || s.isEmpty) return 'unknown';
    if (s.length <= 8) return '***';
    return '${s.substring(0, 4)}…${s.substring(s.length - 4)}';
  }

  static String _truncateString(String input, {int max = 300}) {
    final trimmed = input.replaceAll('\n', r'\n');
    if (trimmed.length <= max) return trimmed;
    return '${trimmed.substring(0, max)}…';
  }
}

