import 'package:cloud_firestore/cloud_firestore.dart';

/// Available card types for insight sections
/// Unified to single insight type - legacy types kept for backward compatibility
class InsightCardType {
  static const String insight = 'insight'; // Unified type
  
  // Legacy types kept for backward compatibility
  @Deprecated('Use insight instead')
  static const String hero = 'hero';
  @Deprecated('Use insight instead')
  static const String prediction = 'prediction';
  @Deprecated('Use insight instead')
  static const String guidance = 'guidance';
  
  static const List<String> all = [insight, hero, prediction, guidance];
}

/// A single wisdom section with title, content, and card type
class InsightSection {
  final String title;
  final String content;
  
  /// Card type - unified to 'insight' for all cards
  /// Legacy types (hero, prediction, etc.) are kept for backward compatibility but all render the same
  final String cardType;
  
  /// Card-specific structured data (optional)
  /// Examples:
  /// - prediction data: {"date": "Dec 15", "planet": "Saturn", "house": 8}
  /// - timing data: {"windows": [{"name": "Rahu Kaal", "start": "3:00", "end": "4:30", "type": "avoid"}]}
  /// - planetary data: {"planets": [{"name": "Moon", "value": 147, "symbol": "☽"}]}
  /// - alert data: {"event": "Mercury Retrograde", "until": "Nov 29", "severity": "caution"}
  final Map<String, dynamic>? data;
  
  /// Display order (1-6 for standard generation)
  final int? displayOrder;
  
  /// ISO timestamp for when this card should be shown (for future queue system)
  final String? scheduledFor;
  
  /// ISO timestamp for when this card expires/becomes irrelevant
  final String? relevantUntil;

  InsightSection({
    required this.title,
    required this.content,
    this.cardType = InsightCardType.insight,
    this.data,
    this.displayOrder,
    this.scheduledFor,
    this.relevantUntil,
  });

  factory InsightSection.fromMap(Map<String, dynamic> map) {
    return InsightSection(
      title: map['title'] as String? ?? '',
      content: map['content'] as String? ?? '',
      cardType: map['cardType'] as String? ?? InsightCardType.insight,
      data: map['data'] != null 
          ? Map<String, dynamic>.from(map['data'] as Map) 
          : null,
      displayOrder: map['displayOrder'] as int?,
      scheduledFor: map['scheduledFor'] as String?,
      relevantUntil: map['relevantUntil'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'title': title,
        'content': content,
        'cardType': cardType,
        if (data != null) 'data': data,
        if (displayOrder != null) 'displayOrder': displayOrder,
        if (scheduledFor != null) 'scheduledFor': scheduledFor,
        if (relevantUntil != null) 'relevantUntil': relevantUntil,
      };
  
  /// Check if this is an insight card
  bool get isInsight => cardType == InsightCardType.insight;
}

class DailyInsight {
  /// The theme/essence of this moment (2-5 words)
  final String? theme;

  /// The main wisdom message
  final String message;

  /// Dynamic sections - as many or few as meaningful
  final List<InsightSection> sections;

  /// When this insight was generated
  final DateTime generatedAt;

  /// The date this insight is for
  final DateTime? date;

  /// Version for backward compatibility
  final String? version;

  /// Raw astrological data used to generate this insight (legacy)
  final Map<String, dynamic>? astrologicalData;
  
  /// Complete astrology context used to generate this insight (v6+)
  /// This includes userChart, todayData, cosmicWeather, and forecasts
  /// Used by AI chat to have the same context as insight generation
  final Map<String, dynamic>? astroContext;

  /// Whether notification was sent
  final bool notificationSent;

  // ============ LEGACY FIELDS FOR BACKWARD COMPATIBILITY ============
  // These support old insights that used the rigid structure

  final String? dailyTheme; // Old field, maps to theme
  final String? mainInsight; // Old field, maps to message
  final Map<String, dynamic>? lifeAreas; // Old rigid structure
  final Map<String, dynamic>? timing;
  final Map<String, dynamic>? activities;
  final Map<String, dynamic>? lucky;
  final Map<String, dynamic>? remedies;
  final Map<String, dynamic>? awareness;

  /// Check if this is the new flexible format (v3)
  bool get isFlexible => version == 'v3' || sections.isNotEmpty;

  /// Get display theme (works for all versions)
  String get displayTheme => theme ?? dailyTheme ?? 'Wisdom';

  /// Get display message (works for all versions)
  String get displayMessage => message.isNotEmpty ? message : (mainInsight ?? '');

  /// Alias for displayMessage (backward compatibility)
  String get displayInsight => displayMessage;

  DailyInsight({
    this.theme,
    required this.message,
    this.sections = const [],
    required this.generatedAt,
    this.date,
    this.version,
    this.astrologicalData,
    this.astroContext,
    this.notificationSent = false,
    // Legacy
    this.dailyTheme,
    this.mainInsight,
    this.lifeAreas,
    this.timing,
    this.activities,
    this.lucky,
    this.remedies,
    this.awareness,
  });

  factory DailyInsight.fromMap(Map<String, dynamic> map) {
    // Parse sections if present (new format)
    List<InsightSection> parsedSections = [];
    if (map['sections'] != null && map['sections'] is List) {
      parsedSections = (map['sections'] as List)
          .map((s) => InsightSection.fromMap(Map<String, dynamic>.from(s as Map)))
          .toList();
    }

    // For backward compatibility, convert old rigid structure to sections
    if (parsedSections.isEmpty) {
      // Convert old lifeAreas to sections
      if (map['lifeAreas'] != null && map['lifeAreas'] is Map) {
        final la = Map<String, dynamic>.from(map['lifeAreas'] as Map);
        if (la['career'] != null) {
          parsedSections.add(InsightSection(title: 'CAREER', content: la['career'] as String));
        }
        if (la['relationships'] != null) {
          parsedSections.add(InsightSection(title: 'RELATIONSHIPS', content: la['relationships'] as String));
        }
        if (la['health'] != null) {
          parsedSections.add(InsightSection(title: 'HEALTH', content: la['health'] as String));
        }
        if (la['spiritual'] != null) {
          parsedSections.add(InsightSection(title: 'SPIRITUAL', content: la['spiritual'] as String));
        }
      }

      // Convert timing
      if (map['timing'] != null && map['timing'] is Map) {
        final t = Map<String, dynamic>.from(map['timing'] as Map);
        final timingParts = <String>[];
        if (t['best'] != null) timingParts.add('Best: ${t['best']}');
        if (t['careful'] != null) timingParts.add('Careful: ${t['careful']}');
        if (timingParts.isNotEmpty) {
          parsedSections.add(InsightSection(title: 'TIMING', content: timingParts.join('\n')));
        }
      }

      // Convert remedies
      if (map['remedies'] != null && map['remedies'] is Map) {
        final r = Map<String, dynamic>.from(map['remedies'] as Map);
        final remedyParts = <String>[];
        if (r['quick'] != null) remedyParts.add(r['quick'] as String);
        if (r['mantra'] != null) remedyParts.add('Mantra: ${r['mantra']}');
        if (remedyParts.isNotEmpty) {
          parsedSections.add(InsightSection(title: 'REMEDY', content: remedyParts.join('\n')));
        }
      }
    }

    return DailyInsight(
      // New format fields
      theme: map['theme'] as String?,
      message: map['message'] as String? ??
          map['mainInsight'] as String? ??
          map['insight'] as String? ??
          '',
      sections: parsedSections,

      // Metadata
      generatedAt: map['generatedAt'] != null
          ? (map['generatedAt'] as Timestamp).toDate()
          : DateTime.now(),
      date: map['date'] != null ? DateTime.tryParse(map['date'] as String) : null,
      version: map['version'] as String?,
      astrologicalData: map['astrologicalData'] != null
          ? Map<String, dynamic>.from(map['astrologicalData'] as Map)
          : null,
      astroContext: map['astroContext'] != null
          ? Map<String, dynamic>.from(map['astroContext'] as Map)
          : null,
      notificationSent: map['notificationSent'] as bool? ?? false,

      // Legacy fields (for raw access if needed)
      dailyTheme: map['dailyTheme'] as String?,
      mainInsight: map['mainInsight'] as String?,
      lifeAreas: map['lifeAreas'] != null
          ? Map<String, dynamic>.from(map['lifeAreas'] as Map)
          : null,
      timing: map['timing'] != null ? Map<String, dynamic>.from(map['timing'] as Map) : null,
      activities:
          map['activities'] != null ? Map<String, dynamic>.from(map['activities'] as Map) : null,
      lucky: map['lucky'] != null ? Map<String, dynamic>.from(map['lucky'] as Map) : null,
      remedies:
          map['remedies'] != null ? Map<String, dynamic>.from(map['remedies'] as Map) : null,
      awareness:
          map['awareness'] != null ? Map<String, dynamic>.from(map['awareness'] as Map) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (theme != null) 'theme': theme,
      'message': message,
      'sections': sections.map((s) => s.toMap()).toList(),
      'generatedAt': Timestamp.fromDate(generatedAt),
      if (date != null) 'date': date!.toIso8601String().split('T').first,
      if (version != null) 'version': version,
      if (astrologicalData != null) 'astrologicalData': astrologicalData,
      'notificationSent': notificationSent,
    };
  }

  String get dateString {
    if (date != null) {
      return date!.toIso8601String().split('T').first;
    }
    return generatedAt.toIso8601String().split('T').first;
  }
}
