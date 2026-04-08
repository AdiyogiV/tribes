// =============================================================================
// TRADITIONAL MATCH MODELS (Ashtakoot)
// =============================================================================

/// Traditional Ashtakoot matching score
class TraditionalMatch {
  final double totalScore;
  final int outOf;
  final double percentage;
  final Map<String, dynamic>? details;
  final String matchType; // "traditional", "mutual", "same_gender"

  TraditionalMatch({
    required this.totalScore,
    required this.outOf,
    required this.percentage,
    this.details,
    this.matchType = 'mutual',
  });

  factory TraditionalMatch.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return TraditionalMatch(
        totalScore: 0,
        outOf: 36,
        percentage: 0,
      );
    }

    return TraditionalMatch(
      totalScore: (map['totalScore'] ?? 0).toDouble(),
      outOf: map['outOf'] ?? 36,
      percentage: (map['percentage'] ?? 0).toDouble(),
      details: map['details'] != null
          ? Map<String, dynamic>.from(map['details'] as Map)
          : null,
      matchType: map['matchType'] ?? 'mutual',
    );
  }

  /// Get user-friendly match type description
  String get matchTypeDescription {
    switch (matchType) {
      case 'traditional':
        return 'Traditional Match';
      case 'same_gender':
        return 'Mutual Compatibility';
      case 'mutual':
      default:
        return 'Mutual Compatibility';
    }
  }
}

// =============================================================================
// LEGACY MODEL (kept for backward compatibility)
// =============================================================================

/// Legacy compatibility score - kept for backward compatibility
class CompatibilityScore {
  final double totalScore;
  final int outOf;
  final double percentage;
  final Map<String, dynamic>? details;
  final bool cached;

  CompatibilityScore({
    required this.totalScore,
    required this.outOf,
    required this.percentage,
    this.details,
    this.cached = false,
  });

  factory CompatibilityScore.fromMap(Map<String, dynamic> map) {
    return CompatibilityScore(
      totalScore: (map['totalScore'] ?? 0).toDouble(),
      outOf: map['outOf'] ?? 36,
      percentage: (map['percentage'] ?? 0).toDouble(),
      details: map['details'] != null
          ? Map<String, dynamic>.from(map['details'] as Map)
          : null,
      cached: map['cached'] ?? false,
    );
  }
}
