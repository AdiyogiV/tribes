/// Zodiac sign traits and descriptions for share cards
class ZodiacTraits {
  /// Two key personality traits per sign
  static const Map<String, List<String>> signTraits = {
    'Aries': ['Bold', 'Fearless'],
    'Taurus': ['Grounded', 'Loyal'],
    'Gemini': ['Curious', 'Witty'],
    'Cancer': ['Nurturing', 'Intuitive'],
    'Leo': ['Confident', 'Generous'],
    'Virgo': ['Analytical', 'Caring'],
    'Libra': ['Balanced', 'Charming'],
    'Scorpio': ['Intense', 'Passionate'],
    'Sagittarius': ['Adventurous', 'Optimistic'],
    'Capricorn': ['Ambitious', 'Disciplined'],
    'Aquarius': ['Innovative', 'Independent'],
    'Pisces': ['Empathetic', 'Creative'],
  };

  /// Poetic descriptors for each sign (used in summary)
  static const Map<String, String> signPoetic = {
    'Aries': 'bold fire',
    'Taurus': 'quiet strength',
    'Gemini': 'restless curiosity',
    'Cancer': 'deep empathy',
    'Leo': 'radiant warmth',
    'Virgo': 'gentle precision',
    'Libra': 'effortless grace',
    'Scorpio': 'magnetic depth',
    'Sagittarius': 'boundless spirit',
    'Capricorn': 'steady ambition',
    'Aquarius': 'visionary spark',
    'Pisces': 'dreamy intuition',
  };

  /// What each placement means
  static const Map<String, String> placementMeaning = {
    'rising': 'How others see you',
    'sun': 'Your core identity',
    'moon': 'Your emotional world',
  };

  /// Get traits for a sign (returns default if not found)
  static List<String> getTraits(String? sign) {
    if (sign == null) return ['—', '—'];
    final normalized = _normalizeSign(sign);
    return signTraits[normalized] ?? ['—', '—'];
  }

  /// Get poetic descriptor for a sign
  static String getPoetic(String? sign) {
    if (sign == null) return 'a unique spark';
    final normalized = _normalizeSign(sign);
    return signPoetic[normalized] ?? 'a unique spark';
  }

  /// Generate a poetic summary combining all three signs
  static String generateSummary({
    required String? risingSign,
    required String? sunSign,
    required String? moonSign,
  }) {
    final rising = getPoetic(risingSign);
    final sun = getPoetic(sunSign);
    final moon = getPoetic(moonSign);

    // Simple, grammatically correct templates
    final templates = [
      'You carry $rising, live with $sun, and feel through $moon.',
      'Others see $rising. You embody $sun. You feel with $moon.',
      '$rising meets the world. $sun drives you. $moon moves you.',
      'Your presence: $rising. Your essence: $sun. Your heart: $moon.',
    ];

    // Use a simple hash to pick template consistently for same signs
    final hash = (risingSign?.hashCode ?? 0) + (sunSign?.hashCode ?? 0);
    return templates[hash.abs() % templates.length];
  }

  /// Normalize sign name (handle variations)
  static String _normalizeSign(String sign) {
    final clean = sign.trim();
    if (clean.isEmpty) return clean;
    return clean[0].toUpperCase() + clean.substring(1).toLowerCase();
  }
}
