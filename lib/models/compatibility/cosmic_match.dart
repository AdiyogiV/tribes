// =============================================================================
// COSMIC MATCH MODELS (Universal Compatibility)
// =============================================================================

/// A single pillar of cosmic compatibility
class CosmicPillar {
  final int score; // 0-100 percentage
  final String source; // pillar source identifier
  final String insight;
  final String? name; // display name from backend
  final String? description; // what this pillar measures
  final int? weight; // weight percentage in overall score
  final Map<String, dynamic> details;

  CosmicPillar({
    required this.score,
    required this.source,
    required this.insight,
    this.name,
    this.description,
    this.weight,
    required this.details,
  });

  factory CosmicPillar.fromMap(Map<String, dynamic> map) {
    return CosmicPillar(
      score: (map['score'] ?? map['percentage'] ?? 0).toInt(),
      source: map['source'] ?? '',
      insight: map['insight'] ?? '',
      name: map['name'],
      description: map['description'],
      weight: map['weight'] != null ? (map['weight'] as num).toInt() : null,
      details: Map<String, dynamic>.from(map),
    );
  }

  /// Get a user-friendly name for this pillar
  String get displayName {
    // Use backend-provided name if available
    if (name != null && name!.isNotEmpty) return name!;

    // Fallback to source-based naming
    switch (source) {
      case 'graha_maitri':
        return 'Mental';
      case 'gana':
        return 'Temperament';
      case 'tara':
        return 'Flow';
      case 'rashi_position':
      case 'moon_position':
        return 'Emotional';
      case 'yoni_affinity':
        return 'Instinctual';
      case 'nadi':
        return 'Energy';
      case 'sun_harmony':
        return 'Identity';
      case 'lagna_harmony':
        return 'Social';
      case 'element_balance':
        return 'Elements';
      default:
        return source.replaceAll('_', ' ');
    }
  }

  /// Get an icon for this pillar
  String get emoji {
    switch (source) {
      case 'graha_maitri':
        return '🧠';
      case 'gana':
        return '💫';
      case 'tara':
        return '✨';
      case 'rashi_position':
      case 'moon_position':
        return '💚';
      case 'yoni_affinity':
        return '🦋';
      case 'nadi':
        return '⚡';
      case 'sun_harmony':
        return '☀️';
      case 'lagna_harmony':
        return '🤝';
      case 'element_balance':
        return '🌍';
      default:
        return '⭐';
    }
  }
}

/// Cosmic Match - Universal compatibility score (gender-neutral)
/// Now supports comprehensive 8-pillar system
class CosmicMatch {
  final int score; // 0-100 percentage
  final int? rawScore; // Pre-normalization score (for debugging)
  final String label; // "Developing", "Moderate", "Good", "Strong", "Excellent", "Exceptional"
  final String insight;
  final int pillarCount; // Number of pillars used in calculation
  final DataCompleteness? dataCompleteness;
  final Map<String, CosmicPillar> _pillarsMap;

  CosmicMatch({
    required this.score,
    this.rawScore,
    required this.label,
    required this.insight,
    this.pillarCount = 4,
    this.dataCompleteness,
    required Map<String, CosmicPillar> pillarsMap,
  }) : _pillarsMap = pillarsMap;

  factory CosmicMatch.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return CosmicMatch(
        score: 0,
        label: 'Unknown',
        insight: 'Unable to calculate cosmic match.',
        pillarsMap: {},
      );
    }

    // Safely convert nested map - Firebase returns _Map<Object?, Object?>
    final pillarsRaw = map['pillars'];
    final pillarsData = pillarsRaw != null
        ? Map<String, dynamic>.from(pillarsRaw as Map)
        : <String, dynamic>{};

    // Parse all pillars dynamically
    final pillarsMap = <String, CosmicPillar>{};
    for (final entry in pillarsData.entries) {
      if (entry.value != null) {
        pillarsMap[entry.key] = CosmicPillar.fromMap(
          Map<String, dynamic>.from(entry.value as Map),
        );
      }
    }

    // Parse data completeness if available
    DataCompleteness? completeness;
    if (map['dataCompleteness'] != null) {
      completeness = DataCompleteness.fromMap(
        Map<String, dynamic>.from(map['dataCompleteness'] as Map),
      );
    }

    return CosmicMatch(
      score: (map['score'] ?? 0).toInt(),
      rawScore: map['rawScore'] != null ? (map['rawScore'] as num).toInt() : null,
      label: map['label'] ?? 'Unknown',
      insight: map['insight'] ?? '',
      pillarCount: map['pillarCount'] ?? pillarsMap.length,
      dataCompleteness: completeness,
      pillarsMap: pillarsMap,
    );
  }

  /// Get all pillars as a list for iteration (ordered by importance)
  List<CosmicPillar> get pillars {
    // Define preferred order for display
    const order = [
      'mental',
      'temperament',
      'flow',
      'emotional',
      'instinctual',
      'energyFlow',
      'coreIdentity',
      'social',
      'elementBalance',
    ];

    final result = <CosmicPillar>[];
    for (final key in order) {
      if (_pillarsMap.containsKey(key)) {
        result.add(_pillarsMap[key]!);
      }
    }

    // Add any remaining pillars not in the predefined order
    for (final entry in _pillarsMap.entries) {
      if (!order.contains(entry.key)) {
        result.add(entry.value);
      }
    }

    return result;
  }

  /// Get a specific pillar by key (for backward compatibility)
  CosmicPillar? getPillar(String key) => _pillarsMap[key];

  // Convenience getters for backward compatibility
  CosmicPillar? get mental => _pillarsMap['mental'];
  CosmicPillar? get temperament => _pillarsMap['temperament'];
  CosmicPillar? get harmony => _pillarsMap['flow'] ?? _pillarsMap['harmony'];
  CosmicPillar? get emotional => _pillarsMap['emotional'];
  CosmicPillar? get instinctual => _pillarsMap['instinctual'];
  CosmicPillar? get energyFlow => _pillarsMap['energyFlow'];
  CosmicPillar? get coreIdentity => _pillarsMap['coreIdentity'];
  CosmicPillar? get social => _pillarsMap['social'];
  CosmicPillar? get elementBalance => _pillarsMap['elementBalance'];
}

/// Data completeness information for the cosmic match
class DataCompleteness {
  final bool hasMoonData;
  final bool hasSunData;
  final bool hasLagnaData;
  final String completenessLevel; // "basic", "enhanced", "full"

  DataCompleteness({
    required this.hasMoonData,
    required this.hasSunData,
    required this.hasLagnaData,
    required this.completenessLevel,
  });

  factory DataCompleteness.fromMap(Map<String, dynamic> map) {
    return DataCompleteness(
      hasMoonData: map['hasMoonData'] ?? false,
      hasSunData: map['hasSunData'] ?? false,
      hasLagnaData: map['hasLagnaData'] ?? false,
      completenessLevel: map['completenessLevel'] ?? 'basic',
    );
  }
}
