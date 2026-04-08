import 'package:aurogram/models/compatibility/cosmic_match.dart';
import 'package:aurogram/models/compatibility/life_phase.dart';
import 'package:aurogram/models/compatibility/traditional_match.dart';

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
