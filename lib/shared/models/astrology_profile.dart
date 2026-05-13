import 'package:cloud_firestore/cloud_firestore.dart';

enum AstroVisibility {
  public, // Basic signs visible to everyone, details only to owner (standard)
  private, // Legacy - kept for backward compatibility
}

class AstrologyProfile {
  // Birth Data (never changes)
  final DateTime? birthDate; // Legacy, for display only
  final int? birthYear;
  final int? birthMonth;
  final int? birthDay;
  final String? birthTime; // "HH:MM" format
  final String? birthPlace;
  final double? birthLatitude;
  final double? birthLongitude;
  final String? timeZone;
  final double? timeZoneOffset; // Numeric offset in hours (e.g., 5.5 for IST)
  final String? gender; // Optional: "Male", "Female", "Other"

  // Settings
  final bool isEnabled; // Feature on/off
  final AstroVisibility visibility;

  // Cached Basic Data (never changes - calculate once!)
  final String? sunSign;
  final String? moonSign;
  final String? ascendant; // Lagna (most important in Vedic)
  final String? nakshatra; // Moon nakshatra (Janma)
  final String? moonNakshatra; // Moon nakshatra (explicit)
  final String? lagnaNakshatra; // Lagna nakshatra

  // Cached Complex Data (never changes)
  final Map<String, dynamic>? birthChartData;
  final String? chartSvgUrl; // Chart SVG from API
  final List<String>? yogas;
  /// Samvat info for the user's BIRTH DATE (Vikram year, lunar month, etc.)
  /// NOT today's date! For today's Vedic date, use DailyInsight.astrologicalData['todaySamvat']
  /// Firestore key: 'samvatInfo' (kept for backward compatibility)
  final Map<String, dynamic>? birthSamvatInfo;
  
  // Pre-processed display data (calculated on backend)
  final List<Map<String, dynamic>>? processedPlanets; // Pre-processed planet data for UI
  
  // Comprehensive Astrology Data
  final Map<String, dynamic>? doshas; // Mangal, Kaal Sarp, Pitra, Shani
  final Map<String, dynamic>? yogasDetailed; // Detailed yoga information
  final List<Map<String, dynamic>>? rajYogas; // Calculated Raj Yogas
  final Map<String, dynamic>? panchang; // Daily panchang details
  final Map<String, dynamic>? muhurat; // Auspicious/inauspicious times
  final Map<String, dynamic>? navamsa; // D9 divisional chart
  final Map<String, dynamic>? houseInterpretations; // AI-generated house interpretations
  final Map<String, dynamic>? skyHouseReadings; // Biweekly per-house current-state readings

  // Cached Periodic Data (refresh monthly)
  final Map<String, dynamic>? currentDasha;
  final DateTime? dashaLastUpdated;

  // Sync Status - tracks which level of data has been fetched
  // Values: 'none', 'partial', 'basic_complete', 'standard_complete', 'full_complete'
  final String? syncStatus;
  final String? syncMode;
  final DateTime? lastSyncAt;

  // Metadata
  final DateTime? createdAt;
  final DateTime? lastUpdated;

  AstrologyProfile({
    this.birthDate,
    this.birthYear,
    this.birthMonth,
    this.birthDay,
    this.birthTime,
    this.birthPlace,
    this.birthLatitude,
    this.birthLongitude,
    this.timeZone,
    this.timeZoneOffset,
    this.gender,
    this.isEnabled = false,
    this.visibility = AstroVisibility.public, // Default: basic signs always visible
    this.sunSign,
    this.moonSign,
    this.ascendant,
    this.nakshatra,
    this.moonNakshatra,
    this.lagnaNakshatra,
    this.birthChartData,
    this.chartSvgUrl,
    this.yogas,
    this.birthSamvatInfo,
    this.processedPlanets,
    this.doshas,
    this.yogasDetailed,
    this.rajYogas,
    this.panchang,
    this.muhurat,
    this.navamsa,
    this.houseInterpretations,
    this.skyHouseReadings,
    this.currentDasha,
    this.dashaLastUpdated,
    this.syncStatus,
    this.syncMode,
    this.lastSyncAt,
    this.createdAt,
    this.lastUpdated,
  });
  
  /// Check if we have at least basic sync complete
  bool get hasBasicSync => 
      syncStatus == 'basic_complete' || 
      syncStatus == 'standard_complete' || 
      syncStatus == 'full_complete';
  
  /// Check if we need a full sync for complete data
  bool get needsFullSync => 
      syncStatus != 'full_complete' && 
      syncStatus != 'standard_complete';

  bool get isComplete =>
      (birthDate != null || (birthYear != null && birthMonth != null && birthDay != null)) &&
      birthTime != null &&
      birthLatitude != null &&
      birthLongitude != null;

  bool get hasCalculatedData =>
      sunSign != null && moonSign != null && ascendant != null;

  bool get needsDashaUpdate {
    if (dashaLastUpdated == null) return true;
    return DateTime.now().difference(dashaLastUpdated!).inDays > 30;
  }

  factory AstrologyProfile.fromMap(Map<String, dynamic> map) {
    return AstrologyProfile(
      birthDate: map['birthDate'] != null
          ? (map['birthDate'] as Timestamp).toDate()
          : null,
      birthYear: map['birthYear'],
      birthMonth: map['birthMonth'],
      birthDay: map['birthDay'],
      birthTime: map['birthTime'],
      birthPlace: map['birthPlace'],
      birthLatitude: map['birthLatitude']?.toDouble(),
      birthLongitude: map['birthLongitude']?.toDouble(),
      timeZone: map['timeZone'],
      timeZoneOffset: map['timeZoneOffset']?.toDouble(),
      gender: map['gender'],
      isEnabled: map['isEnabled'] ?? false,
      visibility: AstroVisibility.values.firstWhere(
        (e) => e.toString() == 'AstroVisibility.${map['visibility']}',
        orElse: () => AstroVisibility.public, // Default to public
      ),
      sunSign: map['sunSign'],
      moonSign: map['moonSign'],
      ascendant: map['ascendant'],
      nakshatra: map['nakshatra'] ??
          map['moonNakshatra'], // Fallback for backward compat
      moonNakshatra: map['moonNakshatra'] ?? map['nakshatra'],
      lagnaNakshatra: map['lagnaNakshatra'],
      birthChartData: map['birthChartData'] != null
          ? Map<String, dynamic>.from(
              map['birthChartData'] as Map<String, dynamic>,
            )
          : null,
      chartSvgUrl: map['chartSvgUrl'],
      yogas: map['yogas'] != null ? List<String>.from(map['yogas']) : null,
      // Firestore key stays 'samvatInfo' for backward compat — this is BIRTH date samvat
      birthSamvatInfo: map['samvatInfo'] != null
          ? Map<String, dynamic>.from(
              map['samvatInfo'] as Map<String, dynamic>,
            )
          : null,
      processedPlanets: map['processedPlanets'] != null
          ? List<Map<String, dynamic>>.from(
              map['processedPlanets'].map((p) => Map<String, dynamic>.from(p)),
            )
          : null,
      doshas: map['doshas'] != null
          ? Map<String, dynamic>.from(
              map['doshas'] as Map<String, dynamic>,
            )
          : null,
      yogasDetailed: map['yogasDetailed'] != null
          ? Map<String, dynamic>.from(
              map['yogasDetailed'] as Map<String, dynamic>,
            )
          : null,
      rajYogas: map['rajYogas'] != null
          ? List<Map<String, dynamic>>.from(
              (map['rajYogas'] as List).map((y) => Map<String, dynamic>.from(y as Map)),
            )
          : null,
      panchang: map['panchang'] != null
          ? Map<String, dynamic>.from(
              map['panchang'] as Map<String, dynamic>,
            )
          : null,
      muhurat: map['muhurat'] != null
          ? Map<String, dynamic>.from(
              map['muhurat'] as Map<String, dynamic>,
            )
          : null,
      navamsa: map['navamsa'] != null
          ? Map<String, dynamic>.from(
              map['navamsa'] as Map<String, dynamic>,
            )
          : null,
      houseInterpretations: map['houseInterpretations'] != null
          ? Map<String, dynamic>.from(
              map['houseInterpretations'] as Map<String, dynamic>,
            )
          : null,
      skyHouseReadings: map['skyHouseReadings'] != null
          ? Map<String, dynamic>.from(
              map['skyHouseReadings'] as Map<String, dynamic>,
            )
          : null,
      currentDasha: map['currentDasha'] != null
          ? Map<String, dynamic>.from(
              map['currentDasha'] as Map<String, dynamic>,
            )
          : null,
      dashaLastUpdated: map['dashaLastUpdated'] != null
          ? (map['dashaLastUpdated'] as Timestamp).toDate()
          : null,
      syncStatus: map['syncStatus'],
      syncMode: map['syncMode'],
      lastSyncAt: map['lastSyncAt'] != null
          ? (map['lastSyncAt'] as Timestamp).toDate()
          : null,
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : null,
      lastUpdated: map['lastUpdated'] != null
          ? (map['lastUpdated'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    final data = <String, dynamic>{
      'birthDate': birthDate != null ? Timestamp.fromDate(birthDate!) : null,
      'birthYear': birthYear,
      'birthMonth': birthMonth,
      'birthDay': birthDay,
      'birthTime': birthTime,
      'birthPlace': birthPlace,
      'birthLatitude': birthLatitude,
      'birthLongitude': birthLongitude,
      'timeZone': timeZone,
      'timeZoneOffset': timeZoneOffset,
      'gender': gender,
      'isEnabled': isEnabled,
      'visibility': visibility.toString().split('.').last,
      'sunSign': sunSign,
      'moonSign': moonSign,
      'ascendant': ascendant,
      'nakshatra': nakshatra,
      'moonNakshatra': moonNakshatra,
      'lagnaNakshatra': lagnaNakshatra,
      'birthChartData': birthChartData,
      'chartSvgUrl': chartSvgUrl,
      'yogas': yogas,
      'samvatInfo': birthSamvatInfo, // Firestore key stays 'samvatInfo'
      'processedPlanets': processedPlanets,
      'doshas': doshas,
      'yogasDetailed': yogasDetailed,
      'rajYogas': rajYogas,
      'panchang': panchang,
      'muhurat': muhurat,
      'navamsa': navamsa,
      'houseInterpretations': houseInterpretations,
      'skyHouseReadings': skyHouseReadings,
      'currentDasha': currentDasha,
      'dashaLastUpdated': dashaLastUpdated != null
          ? Timestamp.fromDate(dashaLastUpdated!)
          : null,
      'syncStatus': syncStatus,
      'syncMode': syncMode,
      'lastSyncAt': lastSyncAt != null ? Timestamp.fromDate(lastSyncAt!) : null,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'lastUpdated': Timestamp.fromDate(DateTime.now()),
    };
    data.removeWhere((key, value) => value == null);
    return data;
  }

  AstrologyProfile copyWith({
    DateTime? birthDate,
    int? birthYear,
    int? birthMonth,
    int? birthDay,
    String? birthTime,
    String? birthPlace,
    double? birthLatitude,
    double? birthLongitude,
    String? timeZone,
    double? timeZoneOffset,
    String? gender,
    bool? isEnabled,
    AstroVisibility? visibility,
    String? sunSign,
    String? moonSign,
    String? ascendant,
    String? nakshatra,
    String? moonNakshatra,
    String? lagnaNakshatra,
    Map<String, dynamic>? birthChartData,
    String? chartSvgUrl,
    List<String>? yogas,
    Map<String, dynamic>? birthSamvatInfo,
    List<Map<String, dynamic>>? processedPlanets,
    Map<String, dynamic>? doshas,
    Map<String, dynamic>? yogasDetailed,
    List<Map<String, dynamic>>? rajYogas,
    Map<String, dynamic>? panchang,
    Map<String, dynamic>? muhurat,
    Map<String, dynamic>? navamsa,
    Map<String, dynamic>? houseInterpretations,
    Map<String, dynamic>? skyHouseReadings,
    Map<String, dynamic>? currentDasha,
    DateTime? dashaLastUpdated,
    String? syncStatus,
    String? syncMode,
    DateTime? lastSyncAt,
    DateTime? createdAt,
    DateTime? lastUpdated,
  }) {
    return AstrologyProfile(
      birthDate: birthDate ?? this.birthDate,
      birthYear: birthYear ?? this.birthYear,
      birthMonth: birthMonth ?? this.birthMonth,
      birthDay: birthDay ?? this.birthDay,
      birthTime: birthTime ?? this.birthTime,
      birthPlace: birthPlace ?? this.birthPlace,
      birthLatitude: birthLatitude ?? this.birthLatitude,
      birthLongitude: birthLongitude ?? this.birthLongitude,
      timeZone: timeZone ?? this.timeZone,
      timeZoneOffset: timeZoneOffset ?? this.timeZoneOffset,
      gender: gender ?? this.gender,
      isEnabled: isEnabled ?? this.isEnabled,
      visibility: visibility ?? this.visibility,
      sunSign: sunSign ?? this.sunSign,
      moonSign: moonSign ?? this.moonSign,
      ascendant: ascendant ?? this.ascendant,
      nakshatra: nakshatra ?? this.nakshatra,
      moonNakshatra: moonNakshatra ?? this.moonNakshatra,
      lagnaNakshatra: lagnaNakshatra ?? this.lagnaNakshatra,
      birthChartData: birthChartData ?? this.birthChartData,
      chartSvgUrl: chartSvgUrl ?? this.chartSvgUrl,
      yogas: yogas ?? this.yogas,
      birthSamvatInfo: birthSamvatInfo ?? this.birthSamvatInfo,
      processedPlanets: processedPlanets ?? this.processedPlanets,
      doshas: doshas ?? this.doshas,
      yogasDetailed: yogasDetailed ?? this.yogasDetailed,
      rajYogas: rajYogas ?? this.rajYogas,
      panchang: panchang ?? this.panchang,
      muhurat: muhurat ?? this.muhurat,
      navamsa: navamsa ?? this.navamsa,
      houseInterpretations: houseInterpretations ?? this.houseInterpretations,
      skyHouseReadings: skyHouseReadings ?? this.skyHouseReadings,
      currentDasha: currentDasha ?? this.currentDasha,
      dashaLastUpdated: dashaLastUpdated ?? this.dashaLastUpdated,
      syncStatus: syncStatus ?? this.syncStatus,
      syncMode: syncMode ?? this.syncMode,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      createdAt: createdAt ?? this.createdAt,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}
