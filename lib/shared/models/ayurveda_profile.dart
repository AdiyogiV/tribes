import 'package:cloud_firestore/cloud_firestore.dart';

/// Ayurveda Profile - Separate from Astrology but connected through birth data
/// Stored at: users/{uid} -> ayurvedaData field
class AyurvedaProfile {
  // Prakriti - Birth Constitution (permanent, calculated from birth chart)
  final PrakritiData? prakriti;

  // Whether Prakriti has been refined by user questionnaire
  final bool prakritiRefined;

  // Number of questions answered for refinement
  final int? questionsAnswered;

  // Physical Profile (user-provided body data)
  final PhysicalProfile? physicalProfile;

  // Agni - Digestive Fire Type
  final String? agniType; // sama, vishama, tikshna, manda

  // Manas Prakriti - Mental Constitution (Sattva/Rajas/Tamas)
  final ManasPrakriti? manasPrakriti;

  // Health Vulnerabilities (from chart analysis)
  final List<HealthVulnerability>? healthVulnerabilities;

  // Vikriti - Current State (calculated from user's last check-in)
  final VikritiData? vikriti;

  // User-reported data
  final List<Map<String, dynamic>>? checkInHistory;
  final Map<String, dynamic>? lastSymptoms;
  final DateTime? lastCheckIn;

  // Metadata
  final DateTime? calculatedAt;
  final String? version;

  AyurvedaProfile({
    this.prakriti,
    this.prakritiRefined = false,
    this.questionsAnswered,
    this.physicalProfile,
    this.agniType,
    this.manasPrakriti,
    this.healthVulnerabilities,
    this.vikriti,
    this.checkInHistory,
    this.lastSymptoms,
    this.lastCheckIn,
    this.calculatedAt,
    this.version,
  });

  bool get hasData => prakriti != null;

  /// Get dominant dosha name
  String? get dominantDosha => prakriti?.dominant;

  /// Get prakriti type string (e.g., "Vata-Pitta")
  String? get prakritiType => prakriti?.type;

  factory AyurvedaProfile.fromMap(Map<String, dynamic> map) {
    return AyurvedaProfile(
      prakriti: map['prakriti'] != null
          ? PrakritiData.fromMap(Map<String, dynamic>.from(map['prakriti']))
          : null,
      prakritiRefined: map['prakritiRefined'] ?? false,
      questionsAnswered: map['questionsAnswered'],
      physicalProfile: map['physicalProfile'] != null
          ? PhysicalProfile.fromMap(
              Map<String, dynamic>.from(map['physicalProfile']))
          : null,
      agniType: map['agniType'],
      manasPrakriti: map['manasPrakriti'] != null
          ? ManasPrakriti.fromMap(
              Map<String, dynamic>.from(map['manasPrakriti']))
          : null,
      healthVulnerabilities: map['healthVulnerabilities'] != null
          ? (map['healthVulnerabilities'] as List)
              .map((v) =>
                  HealthVulnerability.fromMap(Map<String, dynamic>.from(v)))
              .toList()
          : null,
      vikriti: map['vikriti'] != null
          ? VikritiData.fromMap(Map<String, dynamic>.from(map['vikriti']))
          : null,
      checkInHistory: map['checkInHistory'] != null
          ? List<Map<String, dynamic>>.from((map['checkInHistory'] as List)
              .map((c) => Map<String, dynamic>.from(c)))
          : null,
      lastSymptoms: map['lastSymptoms'] != null
          ? Map<String, dynamic>.from(map['lastSymptoms'])
          : null,
      lastCheckIn: map['lastCheckIn'] != null
          ? (map['lastCheckIn'] as Timestamp).toDate()
          : null,
      calculatedAt: map['calculatedAt'] != null
          ? (map['calculatedAt'] as Timestamp).toDate()
          : null,
      version: map['version'],
    );
  }

  Map<String, dynamic> toMap() {
    final data = <String, dynamic>{
      if (prakriti != null) 'prakriti': prakriti!.toMap(),
      if (agniType != null) 'agniType': agniType,
      if (manasPrakriti != null) 'manasPrakriti': manasPrakriti!.toMap(),
      if (healthVulnerabilities != null)
        'healthVulnerabilities':
            healthVulnerabilities!.map((v) => v.toMap()).toList(),
      if (checkInHistory != null) 'checkInHistory': checkInHistory,
      if (lastSymptoms != null) 'lastSymptoms': lastSymptoms,
      if (lastCheckIn != null) 'lastCheckIn': Timestamp.fromDate(lastCheckIn!),
      if (calculatedAt != null)
        'calculatedAt': Timestamp.fromDate(calculatedAt!),
      if (version != null) 'version': version,
    };
    return data;
  }
}

/// Prakriti (Birth Constitution) Data
class PrakritiData {
  final int vata; // Percentage 0-100
  final int pitta; // Percentage 0-100
  final int kapha; // Percentage 0-100
  final String type; // e.g., "Vata-Pitta", "Pitta", "Tridoshic"
  final String dominant; // Primary dosha
  final String? secondary; // Secondary dosha (if dual type)

  PrakritiData({
    required this.vata,
    required this.pitta,
    required this.kapha,
    required this.type,
    required this.dominant,
    this.secondary,
  });

  factory PrakritiData.fromMap(Map<String, dynamic> map) {
    // Handle nested dosha object or flat structure
    final doshaMap = map['dosha'] as Map<String, dynamic>? ?? map;

    return PrakritiData(
      vata: (doshaMap['vata'] ?? map['vata'] ?? 33).toInt(),
      pitta: (doshaMap['pitta'] ?? map['pitta'] ?? 33).toInt(),
      kapha: (doshaMap['kapha'] ?? map['kapha'] ?? 34).toInt(),
      type: map['type'] ?? 'Unknown',
      dominant: map['dominant'] ?? 'vata',
      secondary: map['secondary'],
    );
  }

  Map<String, dynamic> toMap() => {
        'vata': vata,
        'pitta': pitta,
        'kapha': kapha,
        'type': type,
        'dominant': dominant,
        if (secondary != null) 'secondary': secondary,
      };

  /// Get the dosha with highest percentage
  String get highestDosha {
    if (vata >= pitta && vata >= kapha) return 'vata';
    if (pitta >= vata && pitta >= kapha) return 'pitta';
    return 'kapha';
  }

  /// Check if doshas are relatively balanced
  bool get isBalanced {
    final max = [vata, pitta, kapha].reduce((a, b) => a > b ? a : b);
    final min = [vata, pitta, kapha].reduce((a, b) => a < b ? a : b);
    return (max - min) < 15;
  }
}

/// Manas Prakriti (Mental Constitution)
class ManasPrakriti {
  final int sattva; // Clarity, purity
  final int rajas; // Activity, passion
  final int tamas; // Inertia, darkness
  final String dominant;

  ManasPrakriti({
    required this.sattva,
    required this.rajas,
    required this.tamas,
    required this.dominant,
  });

  factory ManasPrakriti.fromMap(Map<String, dynamic> map) {
    final gunaMap = map['guna'] as Map<String, dynamic>? ?? map;

    return ManasPrakriti(
      sattva: (gunaMap['sattva'] ?? map['sattva'] ?? 33).toInt(),
      rajas: (gunaMap['rajas'] ?? map['rajas'] ?? 33).toInt(),
      tamas: (gunaMap['tamas'] ?? map['tamas'] ?? 34).toInt(),
      dominant: map['dominant'] ?? 'sattva',
    );
  }

  Map<String, dynamic> toMap() => {
        'sattva': sattva,
        'rajas': rajas,
        'tamas': tamas,
        'dominant': dominant,
      };
}

/// Health Vulnerability from chart analysis
class HealthVulnerability {
  final String type; // 'weakPlanet', 'planetIn6th', '6thHouseSign'
  final String? planet;
  final String? sign;
  final String? dhatu; // Body tissue
  final List<String>? organs;
  final String description;
  final String? reason; // e.g., "combust", "debilitated"

  HealthVulnerability({
    required this.type,
    this.planet,
    this.sign,
    this.dhatu,
    this.organs,
    required this.description,
    this.reason,
  });

  factory HealthVulnerability.fromMap(Map<String, dynamic> map) {
    return HealthVulnerability(
      type: map['type'] ?? 'unknown',
      planet: map['planet'],
      sign: map['sign'],
      dhatu: map['dhatu'],
      organs: map['organs'] != null ? List<String>.from(map['organs']) : null,
      description: map['description'] ?? '',
      reason: map['reason'],
    );
  }

  Map<String, dynamic> toMap() => {
        'type': type,
        if (planet != null) 'planet': planet,
        if (sign != null) 'sign': sign,
        if (dhatu != null) 'dhatu': dhatu,
        if (organs != null) 'organs': organs,
        'description': description,
        if (reason != null) 'reason': reason,
      };
}

/// Vikriti (Current State) - Calculated dynamically, not stored
class VikritiData {
  final int vata;
  final int pitta;
  final int kapha;
  final List<DoshaImbalance> imbalances;
  final List<VikritieFactor> factors;
  final bool isBalanced;

  VikritiData({
    required this.vata,
    required this.pitta,
    required this.kapha,
    required this.imbalances,
    required this.factors,
    required this.isBalanced,
  });

  factory VikritiData.fromMap(Map<String, dynamic> map) {
    // Convert nested map safely (Cloud Functions return _Map<Object?, Object?>)
    Map<String, dynamic>? doshaMap;
    if (map['dosha'] != null) {
      doshaMap = Map<String, dynamic>.from(map['dosha'] as Map);
    }
    final effectiveMap = doshaMap ?? map;

    return VikritiData(
      vata: (effectiveMap['vata'] ?? map['vata'] ?? 33).toInt(),
      pitta: (effectiveMap['pitta'] ?? map['pitta'] ?? 33).toInt(),
      kapha: (effectiveMap['kapha'] ?? map['kapha'] ?? 34).toInt(),
      imbalances: map['imbalances'] != null
          ? (map['imbalances'] as List)
              .map((i) =>
                  DoshaImbalance.fromMap(Map<String, dynamic>.from(i as Map)))
              .toList()
          : [],
      factors: map['factors'] != null
          ? (map['factors'] as List)
              .map((f) =>
                  VikritieFactor.fromMap(Map<String, dynamic>.from(f as Map)))
              .toList()
          : [],
      isBalanced: map['balanced'] ?? true,
    );
  }
}

/// Dosha Imbalance detected in Vikriti
class DoshaImbalance {
  final String dosha;
  final int shift; // How much it shifted from Prakriti
  final String severity; // 'moderate', 'high'
  final int prakritiValue;
  final int vikritiValue;

  DoshaImbalance({
    required this.dosha,
    required this.shift,
    required this.severity,
    required this.prakritiValue,
    required this.vikritiValue,
  });

  factory DoshaImbalance.fromMap(Map<String, dynamic> map) {
    return DoshaImbalance(
      dosha: map['dosha'] ?? '',
      shift: (map['shift'] ?? 0).toInt(),
      severity: map['severity'] ?? 'moderate',
      prakritiValue: (map['prakritiValue'] ?? 0).toInt(),
      vikritiValue: (map['vikritiValue'] ?? 0).toInt(),
    );
  }
}

/// Factor contributing to Vikriti
/// Enhanced with Tarabala, Chandrabala, and Ashtakavarga factors
class VikritieFactor {
  final String source; // 'dasha', 'lifeStage', 'season', 'tarabala', 'chandrabala', 'ashtakavarga'
  final String description;
  final String dosha;
  final int strength;
  final String? guidance;
  final bool? favorable; // For tarabala/chandrabala/ashtakavarga factors
  final double? dignityMultiplier; // For dasha factors with dignity adjustment
  final int? bindus; // For ashtakavarga factors

  VikritieFactor({
    required this.source,
    required this.description,
    required this.dosha,
    required this.strength,
    this.guidance,
    this.favorable,
    this.dignityMultiplier,
    this.bindus,
  });

  factory VikritieFactor.fromMap(Map<String, dynamic> map) {
    return VikritieFactor(
      source: map['source'] ?? '',
      description: map['description'] ?? '',
      dosha: map['dosha'] ?? '',
      strength: (map['strength'] ?? 0).toInt(),
      guidance: map['guidance'],
      favorable: map['favorable'],
      dignityMultiplier: map['dignityMultiplier']?.toDouble(),
      bindus: map['bindus'],
    );
  }
}

/// Physical Profile - User-provided body data for more accurate Prakriti
class PhysicalProfile {
  final double? heightCm; // Height in centimeters
  final double? weightKg; // Weight in kilograms
  final String? bodyFrame; // 'small', 'medium', 'large'
  final String? skinType; // 'dry', 'oily', 'combination'
  final DateTime? updatedAt;

  PhysicalProfile({
    this.heightCm,
    this.weightKg,
    this.bodyFrame,
    this.skinType,
    this.updatedAt,
  });

  /// Calculate BMI if height and weight are available
  double? get bmi {
    if (heightCm == null || weightKg == null || heightCm! <= 0) return null;
    final heightM = heightCm! / 100;
    return weightKg! / (heightM * heightM);
  }

  /// BMI category
  String? get bmiCategory {
    final b = bmi;
    if (b == null) return null;
    if (b < 18.5) return 'underweight';
    if (b < 25) return 'normal';
    if (b < 30) return 'overweight';
    return 'obese';
  }

  factory PhysicalProfile.fromMap(Map<String, dynamic> map) {
    return PhysicalProfile(
      heightCm: (map['heightCm'] as num?)?.toDouble(),
      weightKg: (map['weightKg'] as num?)?.toDouble(),
      bodyFrame: map['bodyFrame'],
      skinType: map['skinType'],
      updatedAt: map['updatedAt'] != null
          ? (map['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() => {
        if (heightCm != null) 'heightCm': heightCm,
        if (weightKg != null) 'weightKg': weightKg,
        if (bodyFrame != null) 'bodyFrame': bodyFrame,
        if (skinType != null) 'skinType': skinType,
        if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
      };
}
