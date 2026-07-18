import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:aurogram/features/astrology/data/utils/planet_utils.dart';
import 'package:aurogram/features/astrology/domain/astrology_service.dart';
import 'package:aurogram/features/astrology/domain/forecast_service.dart';
import 'package:aurogram/features/astrology/domain/sky_positions_service.dart';
import 'package:aurogram/features/astrology/presentation/widgets/cards/vedic_time_utils.dart';
import 'package:aurogram/features/ayurveda/domain/ayurveda_service.dart';
import 'package:aurogram/features/baba/domain/baba_context.dart';
import 'package:aurogram/features/profile/domain/user_service.dart';

/// Every network read on the cold-open path is bounded by this so a slow or
/// hung Firestore/profile call can never stall the "connecting" state (the tap
/// would otherwise feel dead for seconds). On timeout we simply omit that fact
/// — the playbook has safe defaults for every missing field.
const Duration _leadReadTimeout = Duration(seconds: 3);

/// Builds the opening [SESSION FACTS] cue for a call.
///
/// ARCHITECTURE: this emits FACTS ONLY — the live state the CX brain cannot
/// know on its own (the user's name, whether they're a guest, whether their
/// chart exists, where they are). It deliberately contains NO behavioural
/// instructions: HOW Baba greets, leads, onboards or nudges login is owned by
/// the CX agent playbook (voice-relay/src/cx_tools.js BABA_TOOL_GUIDELINES),
/// the single source of truth. Keeping behaviour out of here is what stops the
/// app and the playbook from drifting apart.
///
/// (The kickoff is still sent as a directive so Baba SPEAKS FIRST and leads;
/// the playbook's opening sequence decides what that first move is, reading
/// these facts.)
class BabaLead {
  BabaLead._();

  static Future<String> directive() async {
    String? name;
    String? recall;
    String? todayVibe;
    String? story;
    String? chartSummary;
    final user = FirebaseAuth.instance.currentUser;
    // A guest is an anonymous Firebase session (or none yet): data is saved but
    // NOT secured to a real account.
    final isGuest = user == null || user.isAnonymous;
    final uid = user?.uid;

    // Chart status is a THREE-way fact, never a bool, because a failed read and
    // a genuinely chart-less user are NOT the same thing:
    //   'none'    — we successfully read the profile and there is no chart yet
    //               (a real new/guest user → onboarding is correct).
    //   'exists'  — we read the profile and the chart is complete.
    //   'unknown' — the profile READ ITSELF failed (App Check/Firestore outage,
    //               timeout, permission-denied). We must NOT report 'none' here:
    //               that made Baba re-onboard returning users during a Firebase
    //               blip. The playbook treats 'unknown' as "assume returning,
    //               do not ask for birth details, retry with getMyChart".
    // With NO uid at all there is truly nothing saved → 'none'.
    String chartStatus = uid == null ? 'none' : 'unknown';
    if (uid != null) {
      // Isolate the profile read: on ANY failure we keep 'unknown' rather than
      // letting the whole cold-open fall back to a misleading 'none'/no-name.
      try {
        final profile =
            await AstrologyService().getProfile(uid).timeout(_leadReadTimeout);
        chartStatus = (profile?.isComplete ?? false) ? 'exists' : 'none';
        chartSummary = _chartFacts(profile);
      } catch (_) {
        // chartStatus stays 'unknown' — a read outage, not a chartless user.
      }
      // Each remaining read is independently best-effort so one failing can
      // never suppress the others (previously a single throw skipped them all).
      try {
        final doc = await UserService().getUser(uid).timeout(_leadReadTimeout);
        final data = doc.data() as Map<String, dynamic>?;
        final n = data?['name']?.toString().trim();
        if (n != null && n.isNotEmpty) name = n;
      } catch (_) {/* name is optional */}
      try {
        recall = await _loadRecall(uid);
      } catch (_) {/* recall is optional */}
      try {
        final forecast = await _loadForecastFacts(uid);
        todayVibe = forecast.$1;
        story = forecast.$2;
      } catch (_) {/* forecast is optional */}
    }

    // Day/time-varying cosmic facts. These make every call open fresh even
    // before Baba fires a tool — the single biggest anti-repetition win. All
    // pure/cached, no network. Any of them may be absent (e.g. panchang still
    // loading); we simply omit what we don't have.
    String? vedicDate;
    String? prahar;
    String? doshaNow;
    String? sky;
    try {
      final now = DateTime.now();
      prahar = VedicTimeUtils.getVedicPrahar(now);
      vedicDate =
          VedicTimeUtils.buildFullVedicDate(SkyPositionsService().getTodayPanchang());
      doshaNow = AyurvedaService().getCurrentDoshaPeriod()['dosha']?.toString();
      sky = _skyFacts(now);
    } catch (_) {/* cosmic facts are best-effort seasoning */}

    // The call can open from ANY screen (the overlay is app-wide). Tell Baba
    // where the user actually is, from the router-backed BabaContext — not a
    // hardcoded 'dashboard', which made his opening facts wrong whenever a user
    // summoned him from the chart, settings, or anywhere else.
    final screen = BabaContext.instance.screen?.key ?? 'dashboard';

    final cue = factsCue(
      name: name,
      isGuest: isGuest,
      chartStatus: chartStatus,
      screen: screen,
      vedicDate: vedicDate,
      prahar: prahar,
      doshaNow: doshaNow,
      recall: recall,
      todayVibe: todayVibe,
      story: story,
      chartSummary: chartSummary,
      sky: sky,
    );
    return cue;
  }

  /// A compact one-line chart summary for the cold-open: the three signs,
  /// nakshatra and the current dasha lords. Front-loaded so Baba can answer
  /// "what's my moon sign / dasha" straight away without a getMyChart round-trip
  /// (and can't mis-say it). Null when there's no calculated chart yet. Pulled
  /// from the SAME profile getMyChart uses, so the two never disagree.
  static String? _chartFacts(dynamic profile) {
    if (profile == null || profile.hasCalculatedData != true) return null;
    final parts = <String>[];
    final sun = profile.sunSign as String?;
    final moon = profile.moonSign as String?;
    final asc = profile.ascendant as String?;
    if (sun != null && sun.isNotEmpty) parts.add('Sun $sun');
    if (moon != null && moon.isNotEmpty) parts.add('Moon $moon');
    if (asc != null && asc.isNotEmpty) parts.add('Asc $asc');
    if (parts.isEmpty) return null;
    var out = parts.join(', ');
    final nak = (profile.nakshatra ?? profile.moonNakshatra) as String?;
    if (nak != null && nak.isNotEmpty) out += '; Nakshatra $nak';
    final dasha = profile.currentDasha;
    if (dasha is Map) {
      String? lord(dynamic v) => v is String
          ? v
          : (v is Map ? (v['lord'] ?? v['name'] ?? v['planet'])?.toString() : null);
      final maha = lord(dasha['mahadasha']) ?? lord(dasha['maha']);
      final antar = lord(dasha['antardasha']) ?? lord(dasha['antar']);
      if (maha != null && maha.isNotEmpty) {
        out += '; Dasha $maha${antar != null && antar.isNotEmpty ? '/$antar' : ''}';
      }
    }
    return out;
  }

  /// The live gochar as a compact one-liner (each graha and its sign, retro
  /// marked). Front-loaded so Baba can talk about "what the planets are doing
  /// now" without a getTransits round-trip. Sign is derived from longitude the
  /// SAME way the wheel and getTransits do, so all three agree. Null while the
  /// sky cache is still loading.
  static String? _skyFacts(DateTime now) {
    final positions = SkyPositionsService().getPositionsForDate(now);
    if (positions == null || positions.isEmpty) return null;
    const grahas = [
      'Sun', 'Moon', 'Mars', 'Mercury', 'Jupiter',
      'Venus', 'Saturn', 'Rahu', 'Ketu',
    ];
    final parts = <String>[];
    for (final planet in grahas) {
      final data = positions[planet];
      if (data is! Map) continue;
      var sign = data['sign']?.toString();
      if (sign == null || sign.isEmpty) {
        final lng = data['longitude'];
        if (lng is num) sign = PlanetUtils.deriveSign(lng);
      }
      if (sign == null || sign.isEmpty) continue;
      final retro = data['isRetro'] == true ? ' (R)' : '';
      parts.add('$planet $sign$retro');
    }
    return parts.isEmpty ? null : parts.join(', ');
  }

  /// Load two compact forecast facts for the cold-open: today's real alignment
  /// (+ its heading) and the one-line storyline arc. Both come from the SAME
  /// unified forecast the wheel shows, so Baba opens in agreement with it.
  /// Returns (todayVibe, story); either may be null. Bounded per read.
  static Future<(String?, String?)> _loadForecastFacts(String uid) async {
    String? todayVibe;
    String? story;
    final service = ForecastService();
    try {
      final forecast =
          await service.fetchForecast(uid).timeout(_leadReadTimeout);
      final today = forecast[ForecastService.dateKey(DateTime.now())];
      if (today != null && today.alignment != null) {
        final head = (today.heading != null && today.heading!.isNotEmpty)
            ? ' ${today.heading}'
            : '';
        todayVibe = '${today.alignment}%$head';
      }
    } catch (_) {/* forecast is best-effort seasoning */}
    try {
      final s = await service.fetchStoryline(uid).timeout(_leadReadTimeout);
      final arc = s?['arc']?.toString().trim();
      if (arc != null && arc.isNotEmpty) {
        story = arc.length > 200 ? '${arc.substring(0, 197)}...' : arc;
      }
    } catch (_) {/* storyline optional */}
    return (todayVibe, story);
  }

  /// Fold the durable memory doc (`users/{uid}/memory/profile`) into a short
  /// recall string: the rolling summary plus the two most recent voice notes.
  /// Bounded and single-lined so it drops cleanly into the facts cue.
  static Future<String?> _loadRecall(String uid) async {
    try {
      final snap = await FirebaseFirestore.instance
          .doc('users/$uid/memory/profile')
          .get()
          .timeout(_leadReadTimeout);
      final data = snap.data();
      if (data == null) return null;

      final parts = <String>[];
      final summary = data['rollingSummary']?.toString().trim();
      if (summary != null && summary.isNotEmpty) parts.add(summary);

      final notes = data['voiceNotes'];
      if (notes is List && notes.isNotEmpty) {
        final recent = notes
            .whereType<Map>()
            .map((e) => e['note']?.toString().trim())
            .where((n) => n != null && n.isNotEmpty)
            .cast<String>()
            .toList();
        parts.addAll(recent.reversed.take(2));
      }

      if (parts.isEmpty) return null;
      // Single line, bounded so it never bloats the cue.
      var recall = parts.join(' | ').replaceAll(RegExp(r'\s+'), ' ').trim();
      if (recall.length > 240) recall = '${recall.substring(0, 237)}...';
      return recall;
    } catch (_) {
      return null;
    }
  }

  /// Assemble a compact, machine-readable [SESSION FACTS] line. Facts only —
  /// no prose. The playbook interprets these and decides the behaviour.
  ///
  /// [chartStatus] is one of 'exists' | 'none' | 'unknown'. 'unknown' means the
  /// profile read failed (outage/timeout) — the playbook must NOT re-onboard on
  /// it. Anything unexpected is coerced to 'unknown' (fail safe: never invent a
  /// 'none' that triggers onboarding for a returning user).
  static String factsCue({
    required String? name,
    required bool isGuest,
    required String chartStatus,
    required String screen,
    String? vedicDate,
    String? prahar,
    String? doshaNow,
    String? recall,
    String? todayVibe,
    String? story,
    String? chartSummary,
    String? sky,
  }) {
    final knowsName = name != null && name.isNotEmpty;
    const validChart = {'exists', 'none', 'unknown'};
    final chart = validChart.contains(chartStatus) ? chartStatus : 'unknown';
    final facts = <String>[
      'name=${knowsName ? name : 'unknown'}',
      'account=${isGuest ? 'guest' : 'secured'}',
      'chart=$chart',
      'screen=$screen',
      if (vedicDate != null && vedicDate.isNotEmpty) 'vedicDate=$vedicDate',
      if (prahar != null && prahar.isNotEmpty) 'prahar=$prahar',
      if (doshaNow != null && doshaNow.isNotEmpty) 'doshaNow=$doshaNow',
      if (todayVibe != null && todayVibe.isNotEmpty) 'today="$todayVibe"',
      if (story != null && story.isNotEmpty) 'story="$story"',
      if (chartSummary != null && chartSummary.isNotEmpty)
        'myChart="$chartSummary"',
      if (sky != null && sky.isNotEmpty) 'sky="$sky"',
      if (recall != null && recall.isNotEmpty) 'recall="$recall"',
    ];
    return '[SESSION FACTS] ${facts.join('; ')}. '
        'The user just opened you — speak first and lead per your playbook.';
  }
}
