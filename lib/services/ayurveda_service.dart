import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:aurogram/models/ayurveda_profile.dart';
import 'package:aurogram/models/astrology_profile.dart';
import 'package:aurogram/utils/logging/app_logger.dart';

/// Service for Ayurveda profile management
/// Separate from AstrologyService but can use astrology data for calculations
class AyurvedaService {
  AyurvedaService._();

  static final AyurvedaService _singleton = AyurvedaService._();
  factory AyurvedaService() => _singleton;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(region: 'asia-southeast2');

  User? get _user => _auth.currentUser;

  // Cache
  static final Map<String, AyurvedaProfile?> _profileCache = {};

  /// Clear cache for a user
  static void clearCache(String? uid) {
    if (uid != null) {
      _profileCache.remove(uid);
    }
  }

  /// Get Ayurveda profile for a user
  Future<AyurvedaProfile?> getProfile(String uid,
      {bool forceRefresh = false}) async {
    if (!forceRefresh && _profileCache.containsKey(uid)) {
      return _profileCache[uid];
    }

    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (!doc.exists) {
        _profileCache[uid] = null;
        return null;
      }

      final data = doc.data();
      if (data == null || !data.containsKey('ayurvedaData')) {
        _profileCache[uid] = null;
        return null;
      }

      final profile = AyurvedaProfile.fromMap(
        Map<String, dynamic>.from(data['ayurvedaData'] as Map<String, dynamic>),
      );
      _profileCache[uid] = profile;
      return profile;
    } catch (e, stackTrace) {
      AppLogger.e('Error fetching Ayurveda profile',
          category: LogCategory.database, error: e, stackTrace: stackTrace);
      return _profileCache[uid];
    }
  }

  /// Stream Ayurveda profile changes
  Stream<AyurvedaProfile?> streamProfile(String uid) {
    return _firestore.collection('users').doc(uid).snapshots().map((doc) {
      try {
        if (!doc.exists) {
          _profileCache[uid] = null;
          return null;
        }

        final data = doc.data();
        if (data == null || !data.containsKey('ayurvedaData')) {
          return _profileCache[uid];
        }

        final profile = AyurvedaProfile.fromMap(
          Map<String, dynamic>.from(
              data['ayurvedaData'] as Map<String, dynamic>),
        );
        _profileCache[uid] = profile;
        return profile;
      } catch (e, stackTrace) {
        AppLogger.e('Error parsing Ayurveda profile from stream',
            category: LogCategory.database, error: e, stackTrace: stackTrace);
        return _profileCache[uid];
      }
    });
  }

  /// Calculate Ayurveda profile from astrology data
  /// This triggers the backend to calculate Prakriti from the birth chart
  Future<AyurvedaProfile?> calculateProfile() async {
    final user = _user;
    if (user == null) return null;

    try {
      AppLogger.i('Calculating Ayurveda profile',
          category: LogCategory.general);

      final callable = _functions.httpsCallable('calculateAyurvedaProfile');
      final result = await callable.call();

      if (result.data != null && result.data['success'] == true) {
        // Clear cache and refetch
        clearCache(user.uid);
        return await getProfile(user.uid, forceRefresh: true);
      }

      return null;
    } catch (e, stackTrace) {
      AppLogger.e('Error calculating Ayurveda profile',
          category: LogCategory.general, error: e, stackTrace: stackTrace);
      return null;
    }
  }

  /// Reset and recalculate Ayurveda profile completely
  /// Deletes all existing data (questionnaire, check-ins, vikriti) and starts fresh
  /// Use this when user wants to start over or when birth details change
  Future<AyurvedaProfile?> resetProfile() async {
    final user = _user;
    if (user == null) return null;

    try {
      AppLogger.i('Resetting Ayurveda profile completely',
          category: LogCategory.general);

      final callable = _functions.httpsCallable('resetAyurvedaProfile');
      final result = await callable.call();

      if (result.data != null && result.data['success'] == true) {
        // Clear cache and refetch fresh profile
        clearCache(user.uid);
        return await getProfile(user.uid, forceRefresh: true);
      }

      return null;
    } catch (e, stackTrace) {
      AppLogger.e('Error resetting Ayurveda profile',
          category: LogCategory.general, error: e, stackTrace: stackTrace);
      return null;
    }
  }

  /// Get current Vikriti (dynamic calculation based on current factors)
  /// This doesn't store data - it calculates current state from:
  /// - Prakriti (base)
  /// - Current dasha
  /// - Current season
  /// - Age
  /// - Optional symptoms
  Future<VikritiData?> calculateVikriti({
    required AyurvedaProfile profile,
    required AstrologyProfile astroProfile,
    Map<String, int>? symptoms, // { vata: count, pitta: count, kapha: count }
  }) async {
    if (profile.prakriti == null) return null;

    try {
      final callable = _functions.httpsCallable('calculateCurrentVikriti');
      final result = await callable.call({
        'prakriti': profile.prakriti!.toMap(),
        'currentDasha': astroProfile.currentDasha,
        'birthYear': astroProfile.birthYear,
        if (symptoms != null) 'symptoms': symptoms,
      });

      if (result.data != null) {
        return VikritiData.fromMap(Map<String, dynamic>.from(result.data));
      }
      return null;
    } catch (e, stackTrace) {
      AppLogger.e('Error calculating Vikriti',
          category: LogCategory.general, error: e, stackTrace: stackTrace);
      return null;
    }
  }

  /// Save refined Prakriti (after user answers questionnaire)
  Future<bool> saveRefinedPrakriti(
    PrakritiData refinedPrakriti, {
    PhysicalProfile? physicalProfile,
    Map<String, String>? questionnaireAnswers,
    int? questionsAnswered,
  }) async {
    final user = _user;
    if (user == null) return false;

    try {
      // Keep derived fields consistent when user refines their dosha balance.
      // Agni is derived from the dosha spread (same logic as backend).
      String determineAgniTypeFromDoshas(int vata, int pitta, int kapha) {
        final maxVal = [vata, pitta, kapha].reduce((a, b) => a > b ? a : b);
        final minVal = [vata, pitta, kapha].reduce((a, b) => a < b ? a : b);

        // Balanced doshas => Sama Agni
        if ((maxVal - minVal) < 15) return 'sama';

        if (vata >= pitta && vata >= kapha) return 'vishama';
        if (pitta >= vata && pitta >= kapha) return 'tikshna';
        return 'manda';
      }

      final agniType = determineAgniTypeFromDoshas(
        refinedPrakriti.vata,
        refinedPrakriti.pitta,
        refinedPrakriti.kapha,
      );

      final updates = <String, dynamic>{
        'ayurvedaData.prakriti': {
          'vata': refinedPrakriti.vata,
          'pitta': refinedPrakriti.pitta,
          'kapha': refinedPrakriti.kapha,
          'type': refinedPrakriti.type,
          'dominant': refinedPrakriti.dominant,
          'secondary': refinedPrakriti.secondary,
        },
        'ayurvedaData.agniType': agniType,
        'ayurvedaData.prakritiRefined': true,
        'ayurvedaData.refinedAt': FieldValue.serverTimestamp(),
      };

      if (questionnaireAnswers != null) {
        updates['ayurvedaData.questionnaireAnswers'] = questionnaireAnswers;
      }

      if (questionsAnswered != null) {
        updates['ayurvedaData.questionsAnswered'] = questionsAnswered;
      }

      if (physicalProfile != null) {
        updates['ayurvedaData.physicalProfile'] = {
          if (physicalProfile.heightCm != null)
            'heightCm': physicalProfile.heightCm,
          if (physicalProfile.weightKg != null)
            'weightKg': physicalProfile.weightKg,
          if (physicalProfile.bodyFrame != null)
            'bodyFrame': physicalProfile.bodyFrame,
          if (physicalProfile.skinType != null)
            'skinType': physicalProfile.skinType,
          'updatedAt': FieldValue.serverTimestamp(),
        };
      }

      await _firestore.collection('users').doc(user.uid).update(updates);

      clearCache(user.uid);
      return true;
    } catch (e, stackTrace) {
      AppLogger.e('Error saving refined Prakriti',
          category: LogCategory.database, error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// Save check-in data
  Future<bool> saveCheckIn({
    required Map<String, dynamic> checkInData,
  }) async {
    final user = _user;
    if (user == null) return false;

    try {
      await _firestore.collection('users').doc(user.uid).update({
        'ayurvedaData.lastCheckIn': FieldValue.serverTimestamp(),
        'ayurvedaData.lastSymptoms': checkInData,
        'ayurvedaData.checkInHistory': FieldValue.arrayUnion([
          {
            ...checkInData,
            'timestamp': Timestamp.now(),
          }
        ]),
      });

      clearCache(user.uid);
      return true;
    } catch (e, stackTrace) {
      AppLogger.e('Error saving check-in',
          category: LogCategory.database, error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// Save Vikriti result to Firestore
  Future<bool> saveVikriti(VikritiData vikriti) async {
    final user = _user;
    if (user == null) return false;

    try {
      await _firestore.collection('users').doc(user.uid).update({
        'ayurvedaData.vikriti': {
          'vata': vikriti.vata,
          'pitta': vikriti.pitta,
          'kapha': vikriti.kapha,
          'isBalanced': vikriti.isBalanced,
          'imbalances': vikriti.imbalances
              .map((i) => {
                    'dosha': i.dosha,
                    'shift': i.shift,
                    'severity': i.severity,
                    'prakritiValue': i.prakritiValue,
                    'vikritiValue': i.vikritiValue,
                  })
              .toList(),
          'factors': vikriti.factors
              .map((f) => {
                    'source': f.source,
                    'dosha': f.dosha,
                    'description': f.description,
                    'strength': f.strength,
                    if (f.guidance != null) 'guidance': f.guidance,
                  })
              .toList(),
          'calculatedAt': FieldValue.serverTimestamp(),
        },
      });

      clearCache(user.uid);
      return true;
    } catch (e, stackTrace) {
      AppLogger.e('Error saving Vikriti',
          category: LogCategory.database, error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// Get dosha recommendations
  Map<String, dynamic> getRecommendations(String dosha) {
    return _doshaRecommendations[dosha] ?? {};
  }

  /// Get current dosha period based on time of day
  Map<String, dynamic> getCurrentDoshaPeriod() {
    final hour = DateTime.now().hour;

    for (final period in _doshaClock) {
      final start = period['start'] as int;
      final end = period['end'] as int;

      if (start <= end) {
        if (hour >= start && hour < end) return period;
      } else {
        // Handle wrap-around (22-2)
        if (hour >= start || hour < end) return period;
      }
    }
    return _doshaClock[0];
  }
}

// ============================================================================
// STATIC DATA
// ============================================================================

const List<Map<String, dynamic>> _doshaClock = [
  {
    'start': 2,
    'end': 6,
    'dosha': 'vata',
    'period': 'Early morning',
    'guidance': 'Light sleep, spiritual practices, wake before 6'
  },
  {
    'start': 6,
    'end': 10,
    'dosha': 'kapha',
    'period': 'Morning',
    'guidance': 'Exercise, light breakfast, best for physical activity'
  },
  {
    'start': 10,
    'end': 14,
    'dosha': 'pitta',
    'period': 'Midday',
    'guidance': 'Main meal, focused work, strongest digestion'
  },
  {
    'start': 14,
    'end': 18,
    'dosha': 'vata',
    'period': 'Afternoon',
    'guidance': 'Creative work, light snack, avoid overstimulation'
  },
  {
    'start': 18,
    'end': 22,
    'dosha': 'kapha',
    'period': 'Evening',
    'guidance': 'Light dinner, wind down, relaxation'
  },
  {
    'start': 22,
    'end': 2,
    'dosha': 'pitta',
    'period': 'Night',
    'guidance': 'Deep sleep, body repairs, be asleep before 10 PM'
  },
];

const Map<String, Map<String, dynamic>> _doshaRecommendations = {
  'vata': {
    'foods': {
      'favor': [
        'Warm soups and stews',
        'Cooked grains (rice, oats)',
        'Root vegetables',
        'Ghee and healthy oils',
        'Sweet fruits',
        'Warm spices (ginger, cinnamon)',
      ],
      'avoid': [
        'Raw salads and cold foods',
        'Dry snacks',
        'Carbonated drinks',
        'Excessive caffeine',
      ],
    },
    'lifestyle': [
      'Maintain regular routine',
      'Warm oil self-massage',
      'Gentle yoga and stretching',
      'Stay warm, avoid cold',
    ],
    'quickRemedies': {
      'anxiety': 'Warm milk with nutmeg before bed',
      'constipation': 'Warm water with ghee in morning',
      'insomnia': 'Foot massage with warm sesame oil',
    },
  },
  'pitta': {
    'foods': {
      'favor': [
        'Cooling foods (cucumber, melon)',
        'Sweet and bitter vegetables',
        'Coconut water',
        'Sweet fruits',
        'Cooling spices (coriander, fennel)',
      ],
      'avoid': [
        'Spicy foods',
        'Fermented foods',
        'Alcohol',
        'Excessive salt',
      ],
    },
    'lifestyle': [
      'Avoid overheating',
      'Moonlight walks',
      'Moderate exercise',
      'Cooling activities',
    ],
    'quickRemedies': {
      'anger': 'Coconut water, walk in nature',
      'acidity': 'Fennel tea after meals',
      'skinIssues': 'Aloe vera, avoid spicy food',
    },
  },
  'kapha': {
    'foods': {
      'favor': [
        'Light, warm foods',
        'Spicy foods (ginger, pepper)',
        'Leafy greens',
        'Legumes',
        'Honey (in moderation)',
      ],
      'avoid': [
        'Heavy, oily foods',
        'Dairy products',
        'Sweet foods',
        'Cold foods',
      ],
    },
    'lifestyle': [
      'Wake before 6 AM',
      'Vigorous exercise',
      'Avoid daytime sleep',
      'Stay active',
    ],
    'quickRemedies': {
      'congestion': 'Ginger tea with honey',
      'lethargy': 'Morning exercise, light breakfast',
      'weight': 'Warm water with honey and lemon',
    },
  },
};
