import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:aurogram/core/logging/app_logger.dart';

/// Service to fetch cosmic intelligence agent data:
/// - Global sky signals (aspects, dignities, ingresses, etc.)
/// - Per-ascendant transit readings
/// - Agent predictions and validation history
class CurrentSkyService {
  static final CurrentSkyService _instance = CurrentSkyService._internal();
  factory CurrentSkyService() => _instance;
  CurrentSkyService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Cache
  Map<String, dynamic>? _cachedSignals;
  String? _cachedSignalsDate;
  Map<String, dynamic>? _cachedTransitReading;
  String? _cachedTransitDate;
  String? _cachedTransitAsc;

  // ═══════════════════════════════════════════════════════════════════════════
  // GLOBAL SIGNALS — What's happening in the sky today
  // ═══════════════════════════════════════════════════════════════════════════

  /// Stream today's active signals from Firestore.
  /// These are written by the cosmic agent daily.
  Stream<List<SkySignal>> streamTodaySignals() {
    final today = _todayKey();
    return _firestore
        .collection('global_astro_signals')
        .where('date', isEqualTo: today)
        .orderBy('intensity', descending: true)
        .limit(20)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => SkySignal.fromFirestore(doc))
            .toList());
  }

  /// Get signals for a specific date (non-realtime).
  Future<List<SkySignal>> getSignalsForDate(String dateStr) async {
    try {
      final snap = await _firestore
          .collection('global_astro_signals')
          .where('date', isEqualTo: dateStr)
          .orderBy('intensity', descending: true)
          .limit(20)
          .get();

      return snap.docs.map((doc) => SkySignal.fromFirestore(doc)).toList();
    } catch (e) {
      AppLogger.e('Failed to get signals for $dateStr',
          error: e, category: LogCategory.general);
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TRANSIT READINGS — Per-user house readings
  // ═══════════════════════════════════════════════════════════════════════════

  /// Get the transit house reading for a user's ascendant.
  /// Returns the pre-computed batch reading for their ascendant sign.
  Future<TransitReading?> getTransitReading(
      String ascendantSign, {String? date}) async {
    final dateStr = date ?? _todayKey();

    // Check cache
    if (_cachedTransitReading != null &&
        _cachedTransitDate == dateStr &&
        _cachedTransitAsc == ascendantSign) {
      return TransitReading.fromMap(_cachedTransitReading!, ascendantSign);
    }

    try {
      final doc = await _firestore
          .collection('global_astro_transit_readings')
          .doc(dateStr)
          .get();

      if (!doc.exists) return null;

      final data = doc.data()?['byAscendant']?[ascendantSign];
      if (data == null) return null;

      _cachedTransitReading = data as Map<String, dynamic>;
      _cachedTransitDate = dateStr;
      _cachedTransitAsc = ascendantSign;

      return TransitReading.fromMap(_cachedTransitReading!, ascendantSign);
    } catch (e) {
      AppLogger.e('Failed to get transit reading',
          error: e, category: LogCategory.general);
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // AGENT PREDICTIONS — What the agent thinks will happen
  // ═══════════════════════════════════════════════════════════════════════════

  /// Stream recent predictions from the cosmic agent.
  Stream<List<AgentPrediction>> streamRecentPredictions({int limit = 10}) {
    return _firestore
        .collection('global_astro_predictions')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => AgentPrediction.fromFirestore(doc))
            .toList());
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // AGENT RUN STATUS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Get the latest agent run summary.
  Future<Map<String, dynamic>?> getLatestRunSummary() async {
    try {
      final snap = await _firestore
          .collection('global_astro_agent_runs')
          .orderBy('startedAt', descending: true)
          .limit(1)
          .get();

      if (snap.docs.isEmpty) return null;
      return snap.docs.first.data();
    } catch (e) {
      return null;
    }
  }

  /// Manually trigger a cosmic agent run (for testing).
  Future<Map<String, dynamic>> triggerAgentRun({String? date}) async {
    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'cosmicAgentManual',
        options: HttpsCallableOptions(timeout: const Duration(minutes: 5)),
      );
      final result = await callable.call({'date': date});
      return Map<String, dynamic>.from(result.data);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════════════════════

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// DATA MODELS
// ═══════════════════════════════════════════════════════════════════════════════

/// A signal extracted from the sky (aspect, ingress, station, etc.)
class SkySignal {
  final String id;
  final String type;
  final List<String> planets;
  final int intensity;
  final String status;
  final List<String> domains;
  final String date;
  final String? aspect;
  final String? dignity;
  final String? stationType;
  final double? orb;
  final bool? applying;
  final Map<String, dynamic>? detail;

  SkySignal({
    required this.id,
    required this.type,
    required this.planets,
    required this.intensity,
    required this.status,
    required this.domains,
    required this.date,
    this.aspect,
    this.dignity,
    this.stationType,
    this.orb,
    this.applying,
    this.detail,
  });

  factory SkySignal.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return SkySignal(
      id: doc.id,
      type: data['type'] ?? '',
      planets: List<String>.from(data['planets'] ?? []),
      intensity: (data['intensity'] ?? 0).toInt(),
      status: data['status'] ?? '',
      domains: List<String>.from(data['domains'] ?? []),
      date: data['date'] ?? '',
      aspect: data['aspect'],
      dignity: data['dignity'],
      stationType: data['stationType'],
      orb: (data['orb'] as num?)?.toDouble(),
      applying: data['applying'],
      detail: data['detail'] as Map<String, dynamic>?,
    );
  }

  /// Human-readable description of the signal
  String get description {
    switch (type) {
      case 'aspect':
        final dir = applying == true ? '→' : applying == false ? '←' : '';
        final orbStr = orb != null ? ' (${orb!.toStringAsFixed(1)}°)' : '';
        return '${planets.join(' + ')} ${aspect ?? ''}$orbStr $dir';
      case 'ingress':
        return '${planets.first} enters ${detail?['toSign'] ?? 'new sign'}';
      case 'station':
        return '${planets.first} goes ${stationType ?? 'station'}';
      case 'dignity':
        return '${planets.first} ${dignity ?? ''} in ${detail?['sign'] ?? ''}';
      case 'eclipse':
        return '${detail?['eclipseType'] ?? 'Eclipse'} indicator near ${planets.join('+')}';
      case 'combustion':
        return '${planets.first} combust (${orb?.toStringAsFixed(1)}° from Sun)';
      case 'speed':
        return '${planets.first} ${detail?['anomalyType'] ?? 'speed anomaly'}';
      case 'parivartana':
        return '${planets.join(' ↔ ')} mutual reception';
      case 'nakshatra':
        return '${planets.first} enters ${detail?['toNakshatra'] ?? 'new nakshatra'}';
      default:
        return '${planets.join('+')} $type';
    }
  }

  /// Color category for UI
  String get colorCategory {
    if (type == 'eclipse') return 'red';
    if (type == 'combustion') return 'orange';
    if (dignity == 'debilitated') return 'red';
    if (dignity == 'exalted') return 'green';
    if (aspect == 'trine' || aspect == 'sextile') return 'green';
    if (aspect == 'square' || aspect == 'opposition') return 'amber';
    if (type == 'station') return 'purple';
    if (type == 'parivartana') return 'blue';
    return 'grey';
  }
}

/// Pre-computed transit reading for one ascendant sign
class TransitReading {
  final String ascendant;
  final Map<int, HouseReading> houses;
  final String? generatedAt;

  TransitReading({
    required this.ascendant,
    required this.houses,
    this.generatedAt,
  });

  factory TransitReading.fromMap(Map<String, dynamic> data, String ascendant) {
    final housesMap = data['houses'] as Map<String, dynamic>? ?? {};
    final houses = <int, HouseReading>{};

    for (final entry in housesMap.entries) {
      final num = int.tryParse(entry.key);
      if (num != null && entry.value is Map<String, dynamic>) {
        houses[num] = HouseReading.fromMap(entry.value as Map<String, dynamic>);
      }
    }

    return TransitReading(
      ascendant: ascendant,
      houses: houses,
      generatedAt: data['generatedAt'],
    );
  }
}

/// Reading for a single house
class HouseReading {
  final int houseNumber;
  final String houseName;
  final String sign;
  final String signLord;
  final List<Map<String, dynamic>> transitPlanets;
  final String? reading;
  final bool hasTransits;

  HouseReading({
    required this.houseNumber,
    required this.houseName,
    required this.sign,
    required this.signLord,
    required this.transitPlanets,
    this.reading,
    this.hasTransits = false,
  });

  factory HouseReading.fromMap(Map<String, dynamic> data) {
    return HouseReading(
      houseNumber: data['houseNumber'] ?? 0,
      houseName: data['houseName'] ?? '',
      sign: data['sign'] ?? '',
      signLord: data['signLord'] ?? '',
      transitPlanets: List<Map<String, dynamic>>.from(
          (data['transitPlanets'] as List?)?.map((e) => Map<String, dynamic>.from(e)) ?? []),
      reading: data['reading'],
      hasTransits: data['hasTransits'] ?? false,
    );
  }
}

/// Agent prediction with validation status
class AgentPrediction {
  final String id;
  final String claim;
  final double confidence;
  final List<String> domains;
  final String status;
  final double? brierScore;
  final String? validationEvidence;
  final DateTime? createdAt;
  final String? resolvesBy;

  AgentPrediction({
    required this.id,
    required this.claim,
    required this.confidence,
    required this.domains,
    required this.status,
    this.brierScore,
    this.validationEvidence,
    this.createdAt,
    this.resolvesBy,
  });

  factory AgentPrediction.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return AgentPrediction(
      id: doc.id,
      claim: data['claim'] ?? '',
      confidence: (data['confidence'] as num?)?.toDouble() ?? 0.5,
      domains: List<String>.from(data['domains'] ?? []),
      status: data['status'] ?? 'pending',
      brierScore: (data['brierScore'] as num?)?.toDouble(),
      validationEvidence: data['validationEvidence'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      resolvesBy: data['resolvesBy'],
    );
  }

  /// Status icon for UI
  String get statusEmoji {
    switch (status) {
      case 'confirmed':
        return '✅';
      case 'unconfirmed':
        return '❌';
      case 'ambiguous':
        return '❓';
      default:
        return '⏳';
    }
  }
}
