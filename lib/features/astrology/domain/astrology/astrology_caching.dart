part of '../astrology_service.dart';

/// Local prediction caching, template-based predictions, and user
/// engagement data for [AstrologyService].
extension AstrologyCachingExtension on AstrologyService {
  static const List<String> _predictionTemplates = [
    '{sign}, align with your Lagna today and let deliberate actions speak for you.',
    'Ground yourself, {sign}. Small rituals will amplify clarity and confidence.',
    'Your moon energy needs gentle pacing today, {sign}. Protect your emotional bandwidth.',
    '{sign}, conversations carry karmic weight now\u2014listen fully before responding.',
    'Channel your Mars drive into disciplined structure, {sign}. Focus beats force.',
    'Let Rahu-inspired curiosity guide learning today, {sign}, but keep boundaries firm.',
    'Saturn reminds you to honor commitments, {sign}. Consistency attracts the right allies.',
    '{sign}, soften your approach and invite grace\u2014Venus rewards balanced effort.',
  ];

  static const String _predictionDateKey = 'astro_prediction_date';
  static const String _predictionTextKey = 'astro_prediction_text';
  static const String _predictionSignKey = 'astro_prediction_sign';

  String get _todayDateString =>
      DateTime.now().toIso8601String().split('T').first;

  /// Get a daily prediction for the given sun sign (cached for today).
  Future<String?> getDailyPrediction(String? sunSign) async {
    final normalizedSign = _normalizeSign(sunSign);
    final cached = await _getCachedPrediction(normalizedSign);
    if (cached != null) return cached;

    final prediction = _formatPrediction(normalizedSign);
    await _cachePrediction(normalizedSign, prediction);
    return prediction;
  }

  Future<String?> _getCachedPrediction(String sunSign) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = _todayDateString;
      final cachedDate = prefs.getString(_predictionDateKey);
      final cachedPrediction = prefs.getString(_predictionTextKey);
      final cachedSign = prefs.getString(_predictionSignKey);

      if (cachedDate == today &&
          cachedSign == sunSign &&
          cachedPrediction != null) {
        AppLogger.d('Using cached daily prediction',
            category: LogCategory.general);
        return cachedPrediction;
      }
      return null;
    } catch (e) {
      AppLogger.w('Prediction cache read failed',
          category: LogCategory.general, data: {'error': e.toString()});
      return null;
    }
  }

  Future<void> _cachePrediction(String sunSign, String prediction) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_predictionDateKey, _todayDateString);
      await prefs.setString(_predictionTextKey, prediction);
      await prefs.setString(_predictionSignKey, sunSign);
      AppLogger.d('Daily prediction cached', category: LogCategory.general);
    } catch (e) {
      AppLogger.w('Prediction cache write failed',
          category: LogCategory.general, data: {'error': e.toString()});
    }
  }

  String _normalizeSign(String? sunSign) {
    if (sunSign == null) return 'your sign';
    final trimmed = sunSign.trim();
    if (trimmed.isEmpty || trimmed.toLowerCase() == 'unknown') {
      return 'your sign';
    }
    return trimmed;
  }

  String _formatPrediction(String sunSign) {
    if (_predictionTemplates.isEmpty) {
      return 'Stay aligned with your breath today, $sunSign.';
    }
    final index =
        DateTime.now().millisecondsSinceEpoch % _predictionTemplates.length;
    return _predictionTemplates[index].replaceAll('{sign}', sunSign);
  }

  /// Get user engagement data (streak, last read, etc.).
  Future<Map<String, dynamic>?> getUserEngagement() async {
    final user = currentUser;
    if (user == null) return null;
    if (!await ensureAuthToken()) return null;

    try {
      final doc = await firestore
          .collection('users')
          .doc(user.uid)
          .collection('astrology')
          .doc('engagement')
          .get();

      if (!doc.exists) {
        return {'streak': 0, 'lastRead': null};
      }

      return doc.data();
    } catch (e) {
      AppLogger.e('Error getting user engagement',
          category: LogCategory.database, error: e);
      return {'streak': 0};
    }
  }
}
