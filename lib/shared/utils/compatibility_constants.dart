/// Constants for compatibility scoring
class CompatibilityConstants {
  CompatibilityConstants._();

  // ==========================================================================
  // COSMIC MATCH THRESHOLDS (Universal Compatibility)
  // ==========================================================================
  
  /// Cosmic match score thresholds (percentage)
  static const int cosmicExcellent = 80;
  static const int cosmicStrong = 65;
  static const int cosmicGood = 50;
  static const int cosmicModerate = 35;

  /// Get label for cosmic match score
  static String getCosmicLabel(int score) {
    if (score >= cosmicExcellent) return 'Cosmic Soulmates ✨';
    if (score >= cosmicStrong) return 'Deep Resonance';
    if (score >= cosmicGood) return 'Aligned Vibes';
    if (score >= cosmicModerate) return 'Growing Energy';
    return 'Different Orbits';
  }

  // ==========================================================================
  // TRADITIONAL ASHTAKOOT THRESHOLDS
  // ==========================================================================

  // Score thresholds for categorization (percentage)
  static const double excellentThreshold = 70.0;
  static const double goodThreshold = 50.0;
  static const double moderateThreshold = 30.0;

  // Ashtakoot point thresholds (out of 36)
  static const int ashtakootExcellent = 25; // 70%
  static const int ashtakootGood = 18;      // 50%
  static const int ashtakootAverage = 14;   // 39%
  static const int ashtakootChallenging = 10; // 28%

  // Cache TTL in days
  static const int cacheTtlDays = 30;

  // Maximum score for Ashtakoot matching
  static const int maxAshtakootScore = 36;

  // Individual koota max scores
  static const Map<String, int> kootaMaxScores = {
    'Varna': 1,
    'Vashya': 2,
    'Tara': 3,
    'Yoni': 4,
    'Graha Maitri': 5,
    'Maitri': 5, // Alias
    'Gana': 6,
    'Rasi': 7,
    'Bhakut': 7, // Alias
    'Nadi': 8,
  };

  // Get max score for a koota by name
  static int getMaxScoreForKoota(String name) {
    return kootaMaxScores[name] ?? 1;
  }

  // Get score label based on percentage
  static String getScoreLabel(double percentage) {
    if (percentage >= excellentThreshold) return 'EXCELLENT';
    if (percentage >= goodThreshold) return 'GOOD';
    if (percentage >= moderateThreshold) return 'MODERATE';
    return 'LOW';
  }

  // Get score category for badge (simpler labels)
  static String getBadgeLabel(double percentage) {
    if (percentage >= excellentThreshold) return 'High';
    if (percentage >= goodThreshold) return 'Medium';
    return 'Low';
  }

  /// Get Ashtakoot label based on points (out of 36)
  static String getAshtakootLabel(double points) {
    if (points >= ashtakootExcellent) return 'Divine Match 🙏';
    if (points >= ashtakootGood) return 'Blessed Bond';
    if (points >= ashtakootAverage) return 'Balanced Path';
    if (points >= ashtakootChallenging) return 'Learning Bond';
    return 'Karmic Journey';
  }
}





