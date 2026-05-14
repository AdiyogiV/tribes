import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:aurogram/core/logging/app_logger.dart';

/// Service to fetch cosmic daily intelligence output.
///
/// Reads from `cosmic_daily_output/{date}` — a single document per day
/// containing world energy, predictions, house readings, and signal summaries.
class CurrentSkyService {
  static final CurrentSkyService _instance = CurrentSkyService._internal();
  factory CurrentSkyService() => _instance;
  CurrentSkyService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Stream today's cosmic daily output (realtime).
  Stream<CosmicDailyOutput?> streamDailyOutput() {
    return _firestore
        .collection('cosmic_daily_output')
        .doc(_todayKey())
        .snapshots()
        .map((snap) => snap.exists ? CosmicDailyOutput.fromFirestore(snap) : null);
  }

  /// Get output for a specific date.
  Future<CosmicDailyOutput?> getDailyOutput(String dateStr) async {
    try {
      final doc = await _firestore
          .collection('cosmic_daily_output')
          .doc(dateStr)
          .get();
      if (!doc.exists) return null;
      return CosmicDailyOutput.fromFirestore(doc);
    } catch (e) {
      AppLogger.e('Failed to get daily output for $dateStr',
          error: e, category: LogCategory.general);
      return null;
    }
  }

  /// Manually trigger a cosmic daily run.
  /// Deployed in `asia-southeast2` (see `functions/cosmic_daily.js`).
  Future<Map<String, dynamic>> triggerDailyRun({String? date}) async {
    try {
      final callable = FirebaseFunctions.instanceFor(region: 'asia-southeast2')
          .httpsCallable(
        'cosmicDailyManual',
        options: HttpsCallableOptions(timeout: const Duration(minutes: 5)),
      );
      final result = await callable.call({'date': date});
      return Map<String, dynamic>.from(result.data);
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// DATA MODELS
// ═══════════════════════════════════════════════════════════════════════════════

/// Complete daily cosmic output — one document per day.
class CosmicDailyOutput {
  final String date;
  final String worldEnergy;
  final List<CosmicPrediction> predictions;
  final Map<int, MundaneHouse> houses;
  final List<SignalSummary> signals;
  final DateTime? generatedAt;

  CosmicDailyOutput({
    required this.date,
    required this.worldEnergy,
    required this.predictions,
    required this.houses,
    required this.signals,
    this.generatedAt,
  });

  factory CosmicDailyOutput.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    // Parse predictions
    final rawPredictions = data['predictions'] as List<dynamic>? ?? [];
    final predictions = rawPredictions
        .map((p) => CosmicPrediction.fromMap(Map<String, dynamic>.from(p)))
        .toList();

    // Parse houses
    final rawHouses = data['houses'] as Map<String, dynamic>? ?? {};
    final houses = <int, MundaneHouse>{};
    for (final entry in rawHouses.entries) {
      final num = int.tryParse(entry.key);
      if (num != null && entry.value is Map) {
        houses[num] = MundaneHouse.fromMap(
          num,
          Map<String, dynamic>.from(entry.value as Map),
        );
      }
    }

    // Parse signal summaries
    final rawSignals = data['signalsSummary'] as List<dynamic>? ?? [];
    final signals = rawSignals
        .map((s) => SignalSummary.fromMap(Map<String, dynamic>.from(s)))
        .toList();

    return CosmicDailyOutput(
      date: data['date'] ?? doc.id,
      worldEnergy: data['worldEnergy'] ?? '',
      predictions: predictions,
      houses: houses,
      signals: signals,
      generatedAt: (data['generatedAt'] as Timestamp?)?.toDate(),
    );
  }
}

/// A concrete prediction with timeframe and confidence.
class CosmicPrediction {
  final String claim;
  final String timeframe;
  final double confidence;
  final String basedOn;
  final List<String> domains;

  CosmicPrediction({
    required this.claim,
    required this.timeframe,
    required this.confidence,
    required this.basedOn,
    required this.domains,
  });

  factory CosmicPrediction.fromMap(Map<String, dynamic> data) {
    return CosmicPrediction(
      claim: data['claim'] ?? '',
      timeframe: data['timeframe'] ?? '',
      confidence: (data['confidence'] as num?)?.toDouble() ?? 0.5,
      basedOn: data['basedOn'] ?? '',
      domains: List<String>.from(data['domains'] ?? []),
    );
  }

  String get confidenceLabel {
    if (confidence >= 0.8) return 'High';
    if (confidence >= 0.5) return 'Medium';
    return 'Low';
  }
}

/// A mundane house with sign, planets, and reading.
class MundaneHouse {
  final int number;
  final String sign;
  final String name;
  final String domain;
  final List<HousePlanet> planets;
  final String reading;

  MundaneHouse({
    required this.number,
    required this.sign,
    required this.name,
    required this.domain,
    required this.planets,
    required this.reading,
  });

  factory MundaneHouse.fromMap(int number, Map<String, dynamic> data) {
    final rawPlanets = data['planets'] as List<dynamic>? ?? [];
    final planets = rawPlanets
        .map((p) => HousePlanet.fromMap(Map<String, dynamic>.from(p)))
        .toList();

    return MundaneHouse(
      number: number,
      sign: data['sign'] ?? '',
      name: data['name'] ?? '',
      domain: data['domain'] ?? '',
      planets: planets,
      reading: data['reading'] ?? '',
    );
  }

  bool get hasPlanets => planets.isNotEmpty;
}

/// A planet transiting a house.
class HousePlanet {
  final String planet;
  final double degree;
  final bool isRetro;

  HousePlanet({
    required this.planet,
    required this.degree,
    required this.isRetro,
  });

  factory HousePlanet.fromMap(Map<String, dynamic> data) {
    return HousePlanet(
      planet: data['planet'] ?? '',
      degree: (data['degree'] as num?)?.toDouble() ?? 0,
      isRetro: data['isRetro'] ?? false,
    );
  }
}

/// Compact signal summary for display.
class SignalSummary {
  final String type;
  final List<String> planets;
  final int intensity;
  final String? aspect;
  final String? dignity;
  final double? orb;
  final bool? applying;
  final List<String> domains;

  SignalSummary({
    required this.type,
    required this.planets,
    required this.intensity,
    this.aspect,
    this.dignity,
    this.orb,
    this.applying,
    required this.domains,
  });

  factory SignalSummary.fromMap(Map<String, dynamic> data) {
    return SignalSummary(
      type: data['type'] ?? '',
      planets: List<String>.from(data['planets'] ?? []),
      intensity: (data['intensity'] as num?)?.toInt() ?? 0,
      aspect: data['aspect'],
      dignity: data['dignity'],
      orb: (data['orb'] as num?)?.toDouble(),
      applying: data['applying'],
      domains: List<String>.from(data['domains'] ?? []),
    );
  }

  String get description {
    switch (type) {
      case 'aspect':
        final dir = applying == true ? '→' : applying == false ? '←' : '';
        final orbStr = orb != null ? ' (${orb!.toStringAsFixed(1)}°)' : '';
        return '${planets.join(' + ')} ${aspect ?? ''}$orbStr $dir';
      case 'dignity':
        return '${planets.first} ${dignity ?? ''}';
      default:
        return '${planets.join('+')} $type';
    }
  }
}
