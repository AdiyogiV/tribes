import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:aurogram/utils/logging/app_logger.dart';

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

// =============================================================================
// LIFE PHASE SYNC (Dasha Comparison)
// =============================================================================

/// Individual's life phase info
class LifePhaseUser {
  final String mahaDasha;
  final String? antarDasha;
  final String energyType;
  final String theme;
  final String description;
  final String color;
  final String? mahaStartDate;
  final String? mahaEndDate;
  final String? antarStartDate;
  final String? antarEndDate;

  LifePhaseUser({
    required this.mahaDasha,
    this.antarDasha,
    required this.energyType,
    required this.theme,
    required this.description,
    required this.color,
    this.mahaStartDate,
    this.mahaEndDate,
    this.antarStartDate,
    this.antarEndDate,
  });

  factory LifePhaseUser.fromMap(Map<String, dynamic> map) {
    return LifePhaseUser(
      mahaDasha: map['mahaDasha'] ?? '',
      antarDasha: map['antarDasha'],
      energyType: map['energyType'] ?? 'unknown',
      theme: map['theme'] ?? '',
      description: map['description'] ?? '',
      color: map['color'] ?? '#6B7280',
      // Support both old field names and new ones
      mahaStartDate: map['mahaStartDate'] ?? map['startDate'],
      mahaEndDate: map['mahaEndDate'] ?? map['endDate'],
      antarStartDate: map['antarStartDate'],
      antarEndDate: map['antarEndDate'],
    );
  }
}

/// Sync interpretation between two life phases
class LifePhaseSync {
  final String label;
  final String quality; // "excellent", "good", "moderate", "challenging", "growth"
  final String insight;
  final bool sameMahaDasha;

  LifePhaseSync({
    required this.label,
    required this.quality,
    required this.insight,
    this.sameMahaDasha = false,
  });

  factory LifePhaseSync.fromMap(Map<String, dynamic> map) {
    return LifePhaseSync(
      label: map['label'] ?? 'Unknown',
      quality: map['quality'] ?? 'moderate',
      insight: map['insight'] ?? '',
      sameMahaDasha: map['sameMahaDasha'] ?? false,
    );
  }
}

/// Complete Life Phase Sync result
class LifePhaseSyncResult {
  final LifePhaseUser user1;
  final LifePhaseUser user2;
  final LifePhaseSync sync;

  LifePhaseSyncResult({
    required this.user1,
    required this.user2,
    required this.sync,
  });

  factory LifePhaseSyncResult.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      throw ArgumentError('LifePhaseSyncResult.fromMap received null');
    }

    final user1Raw = map['user1'];
    final user2Raw = map['user2'];
    final syncRaw = map['sync'];

    return LifePhaseSyncResult(
      user1: LifePhaseUser.fromMap(
          user1Raw != null ? Map<String, dynamic>.from(user1Raw as Map) : {}),
      user2: LifePhaseUser.fromMap(
          user2Raw != null ? Map<String, dynamic>.from(user2Raw as Map) : {}),
      sync: LifePhaseSync.fromMap(
          syncRaw != null ? Map<String, dynamic>.from(syncRaw as Map) : {}),
    );
  }
}

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
// COMBINED COMPATIBILITY RESULT
// =============================================================================

/// Complete compatibility result with cosmic, life phase, and traditional scores
class CompatibilityResult {
  final CosmicMatch? cosmicMatch;
  final LifePhaseSyncResult? lifePhaseSync;
  final TraditionalMatch? traditionalMatch; // Nullable - may be unavailable
  final bool cached;
  final bool partial; // True if some data unavailable (e.g., API rate limited)

  CompatibilityResult({
    this.cosmicMatch,
    this.lifePhaseSync,
    this.traditionalMatch,
    this.cached = false,
    this.partial = false,
  });

  factory CompatibilityResult.fromMap(Map<String, dynamic> map) {
    // Parse cosmic match - safely convert nested maps from Firebase
    CosmicMatch? cosmic;
    if (map['cosmicMatch'] != null) {
      cosmic = CosmicMatch.fromMap(
          Map<String, dynamic>.from(map['cosmicMatch'] as Map));
    }

    // Parse life phase sync
    LifePhaseSyncResult? lifePhase;
    if (map['lifePhaseSync'] != null) {
      try {
        lifePhase = LifePhaseSyncResult.fromMap(
            Map<String, dynamic>.from(map['lifePhaseSync'] as Map));
      } catch (e) {
        // Life phase data may be missing for some users
        lifePhase = null;
      }
    }

    // Parse traditional match (nullable - may be unavailable due to API issues)
    TraditionalMatch? traditional;
    if (map['traditionalMatch'] != null) {
      traditional = TraditionalMatch.fromMap(
          Map<String, dynamic>.from(map['traditionalMatch'] as Map));
    } else if (map['totalScore'] != null && map['totalScore'] != 0) {
      // Fallback to legacy fields for backward compatibility (only if score exists)
      traditional = TraditionalMatch(
        totalScore: (map['totalScore'] ?? 0).toDouble(),
        outOf: map['outOf'] ?? 36,
        percentage: (map['percentage'] ?? 0).toDouble(),
        details: map['details'] != null
            ? Map<String, dynamic>.from(map['details'] as Map)
            : null,
        matchType: 'mutual',
      );
    }
    // If traditionalMatch is null and no legacy fields, traditional stays null

    return CompatibilityResult(
      cosmicMatch: cosmic,
      lifePhaseSync: lifePhase,
      traditionalMatch: traditional,
      cached: map['cached'] ?? false,
      partial: map['partial'] ?? false,
    );
  }

  /// Check if traditional match (Ashtakoot) is available
  bool get hasTraditionalMatch => traditionalMatch != null;

  /// Primary score to display (cosmic match if available, else traditional)
  int get primaryScore {
    return cosmicMatch?.score ?? traditionalMatch?.percentage.round() ?? 0;
  }

  /// Primary label
  String get primaryLabel {
    return cosmicMatch?.label ?? _getTraditionalLabel();
  }

  String _getTraditionalLabel() {
    final pct = traditionalMatch?.percentage ?? 0;
    if (pct >= 80) return 'Excellent';
    if (pct >= 65) return 'Strong';
    if (pct >= 50) return 'Good';
    if (pct >= 35) return 'Moderate';
    return 'Low';
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

// =============================================================================
// COMPATIBILITY SERVICE
// =============================================================================

/// Lightweight service for compatibility scores
///
/// Architecture:
/// - Backend handles ALL caching (30-day TTL in Firestore)
/// - Backend auto-invalidates cache when user updates astrology profile
/// - Frontend is a thin wrapper - no redundant caching
class CompatibilityService {
  CompatibilityService._();
  static final CompatibilityService _singleton = CompatibilityService._();
  factory CompatibilityService() => _singleton;

  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(region: 'asia-southeast2');
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  String? _errorCode;
  String? get errorCode => _errorCode;

  /// Error code for non-friends (mutual follow required)
  static const String errorCodeNotFriends = 'not_friends';

  /// Check if the last error was due to not being friends (mutual follow)
  bool get isNotFriendsError => _errorCode == errorCodeNotFriends;

  /// Get full compatibility result (cosmic + traditional)
  ///
  /// Returns cached result from backend if available (30-day cache)
  /// Returns null if: not logged in, self-comparison, missing profiles, not friends
  Future<CompatibilityResult?> getFullCompatibility(String otherUserId) async {
    _errorMessage = null;
    _errorCode = null;

    final user = _auth.currentUser;
    if (user == null) {
      AppLogger.w('Cannot calculate compatibility: not logged in',
          category: LogCategory.general);
      return null;
    }

    if (user.uid == otherUserId) {
      return null; // Self-compatibility not meaningful
    }

    try {
      final callable = _functions.httpsCallable('calculateCompatibility');
      final result = await callable.call({'otherUserId': otherUserId});

      // Safely convert the result data to Map<String, dynamic>
      // Firebase can return _Map<Object?, Object?> which needs explicit conversion
      final rawData = result.data;
      if (rawData == null) {
        AppLogger.w('💑 Compatibility returned null data',
            category: LogCategory.general);
        return null;
      }
      
      final data = Map<String, dynamic>.from(rawData as Map);
      if (data['success'] != true) {
        AppLogger.w(
            '💑 Compatibility returned non-success: ${data.toString()}',
            category: LogCategory.general);
        _errorMessage =
            data['message']?.toString() ?? data['error']?.toString();
        return null;
      }

      final compatibility = CompatibilityResult.fromMap(data);

      AppLogger.d(
          '💑 Compatibility: cosmic=${compatibility.cosmicMatch?.score}%, '
          'traditional=${compatibility.traditionalMatch?.totalScore ?? 'N/A'}/${compatibility.traditionalMatch?.outOf ?? 'N/A'} '
          '(cached: ${compatibility.cached}, partial: ${compatibility.partial})',
          category: LogCategory.general);

      return compatibility;
    } on FirebaseFunctionsException catch (e) {
      _errorMessage = _mapErrorToUserMessage(e.code, e.message);

      AppLogger.w(
          '💑 Compatibility failed - code: ${e.code}, message: ${e.message}, mapped: $_errorMessage',
          category: LogCategory.general);
      return null;
    } catch (e) {
      AppLogger.e('Compatibility error', category: LogCategory.general, error: e);
      _errorMessage = 'Unable to calculate compatibility.';
      return null;
    }
  }

  /// Get compatibility score between current user and another user
  /// [LEGACY] - Use getFullCompatibility for new code
  ///
  /// Returns cached result from backend if available (30-day cache)
  /// Returns null if: not logged in, self-comparison, missing profiles, not friends
  Future<CompatibilityScore?> getCompatibility(String otherUserId) async {
    final result = await getFullCompatibility(otherUserId);
    if (result == null) return null;

    // Convert to legacy format - return null if traditional match unavailable
    final traditional = result.traditionalMatch;
    if (traditional == null) return null;

    return CompatibilityScore(
      totalScore: traditional.totalScore,
      outOf: traditional.outOf,
      percentage: traditional.percentage,
      details: traditional.details,
      cached: result.cached,
    );
  }

  String? _mapErrorToUserMessage(String code, String? message) {
    if (code == 'not-found') {
      return 'Compatibility feature unavailable.';
    }
    if (code == 'invalid-argument') {
      return null; // Self-compatibility - no error message needed
    }
    if (code == 'permission-denied') {
      // Check for blocked user scenarios first (more specific)
      if (message != null && message.contains('not available')) {
        return 'Compatibility not available for this user.';
      }
      _errorCode = errorCodeNotFriends;
      return 'Follow each other to unlock compatibility';
    }
    if (code == 'failed-precondition') {
      // Check for blocked user scenario
      if (message != null && message.contains('blocked')) {
        return 'Unblock this user to see compatibility.';
      }
    }
    if (message == null) {
      return 'Compatibility not available.';
    }
    if (message.contains('mutual follow') ||
        message.contains('Follow each other')) {
      _errorCode = errorCodeNotFriends;
      return 'Follow each other to unlock compatibility';
    }
    if (message.contains('blocked')) {
      return 'Unblock this user to see compatibility.';
    }
    if (message.contains('profile')) {
      return 'Both users need astrology profiles set up.';
    }
    if (message.contains('private') || message.contains('public')) {
      return 'This user\'s astrology is private.';
    }
    if (message.contains('birth')) {
      return 'Complete birth info required.';
    }
    return 'Compatibility not available.';
  }
}
