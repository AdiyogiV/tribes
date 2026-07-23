import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:aurogram/core/logging/app_logger.dart';

/// One day of the unified forecast — the single read-model shared by the
/// nakshatra wheel, the daily card, and Aurobhatt.
///
/// `alignment` + the classical signals are COMPUTED server-side (SENSE);
/// `heading` + `narrative` are NARRATED once/month by one Gemini call. See
/// backend/docs/unified_forecast_architecture.md.
class ForecastDay {
  final String date; // yyyy-MM-dd (IST)
  final int? alignment; // 0-100, real Vedic day-signal
  final String? tara;
  final List<String> favorable;
  final List<String> unfavorable;
  final String? heading; // ≤4 words, AI
  final String? narrative; // 1-3 sentences, AI (PRIVATE — second-person diary)
  final String? publicNote; // ≤12 words, AI (PUBLIC — third-person, friend-safe)
  final String? action; // concrete daily focus
  final String? caution; // practical restraint
  final String? tip; // grounded wellbeing/reflection suggestion
  final String? timing; // non-fabricated timing guidance
  final List<String> goodFor; // FAVOR column — AI, grounded in the day's signals
  final List<String> avoid; // AVOID column — AI, grounded in the day's signals

  const ForecastDay({
    required this.date,
    this.alignment,
    this.tara,
    this.favorable = const [],
    this.unfavorable = const [],
    this.heading,
    this.narrative,
    this.publicNote,
    this.action,
    this.caution,
    this.tip,
    this.timing,
    this.goodFor = const [],
    this.avoid = const [],
  });

  factory ForecastDay.fromMap(Map<String, dynamic> m) {
    List<String> strList(dynamic v) =>
        (v as List?)?.map((e) => e.toString()).toList() ?? const [];
    return ForecastDay(
      date: m['date']?.toString() ?? '',
      alignment: (m['alignment'] as num?)?.toInt(),
      tara: m['tara']?.toString(),
      favorable: strList(m['favorable']),
      unfavorable: strList(m['unfavorable']),
      heading: m['heading']?.toString(),
      narrative: m['narrative']?.toString(),
      publicNote: m['publicNote']?.toString(),
      action: m['action']?.toString(),
      caution: m['caution']?.toString(),
      tip: m['tip']?.toString(),
      timing: m['timing']?.toString(),
      goodFor: strList(m['goodFor']),
      avoid: strList(m['avoid']),
    );
  }
}

/// Streams and refreshes the per-user forecast stored at
/// `users/{uid}/forecast/{yyyy-MM}`.
class ForecastService {
  ForecastService._();
  static final ForecastService _singleton = ForecastService._();
  factory ForecastService() => _singleton;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'asia-southeast2');

  /// yyyy-MM-dd key (IST-agnostic local date; matches the backend's IST keys
  /// closely enough for day selection on the wheel).
  static String dateKey(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static const int _monthsEitherSide = 7;

  static String monthKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}';

  Map<String, ForecastDay> _flatten(
      Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    final out = <String, ForecastDay>{};
    for (final doc in docs) {
      final days = (doc.data()['days'] as List?) ?? const [];
      for (final raw in days) {
        if (raw is Map) {
          final day = ForecastDay.fromMap(Map<String, dynamic>.from(raw));
          if (day.date.isNotEmpty) out[day.date] = day;
        }
      }
    }
    return out;
  }

  CollectionReference<Map<String, dynamic>> _col(String uid) =>
      _firestore.collection('users').doc(uid).collection('forecast');

  Query<Map<String, dynamic>> _relevantMonths(String uid) {
    final now = DateTime.now();
    final start = monthKey(DateTime(now.year, now.month - _monthsEitherSide));
    final end = monthKey(DateTime(now.year, now.month + _monthsEitherSide));
    return _col(uid)
        .where(FieldPath.documentId, isGreaterThanOrEqualTo: start)
        .where(FieldPath.documentId, isLessThanOrEqualTo: end)
        .orderBy(FieldPath.documentId);
  }

  /// Live map of date → forecast day within the wheel's useful time window.
  /// Historical month documents outside that window are never downloaded or
  /// repeatedly flattened on each Firestore update.
  Stream<Map<String, ForecastDay>> streamForecast(String uid) =>
      _relevantMonths(uid).snapshots().map((snap) {
        final map = _flatten(snap.docs);
        return map;
      });

  /// One-shot read of the forecast (used by Aurobhatt's getMyForecast tool).
  Future<Map<String, ForecastDay>> fetchForecast(String uid) async {
    final snap = await _relevantMonths(uid).get();
    return _flatten(snap.docs);
  }

  /// The user's evolving storyline arc (from users/{uid}/memory/profile), if any.
  Future<Map<String, dynamic>?> fetchStoryline(String uid) async {
    try {
      final snap = await _firestore
          .collection('users')
          .doc(uid)
          .collection('memory')
          .doc('profile')
          .get();
      final s = snap.data()?['storyline'];
      return s is Map ? Map<String, dynamic>.from(s) : null;
    } catch (_) {
      return null;
    }
  }

  bool _computeInFlight = false;

  /// Trigger an on-demand signal recompute (no AI) so a newly-active user sees
  /// a real alignment immediately, without waiting for the nightly batch.
  /// Safe to call optimistically — it de-dupes and swallows failures.
  Future<void> ensureComputed() async {
    if (_computeInFlight) return;
    _computeInFlight = true;
    try {
      await _functions
          .httpsCallable('astroGateway')
          .call({'method': 'computeMyForecast'});
    } catch (e) {
      AppLogger.w('[forecast] computeMyForecast: FAILED (non-fatal)',
          category: LogCategory.database, data: {'error': e.toString()});
    } finally {
      _computeInFlight = false;
    }
  }
}
