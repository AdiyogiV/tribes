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
