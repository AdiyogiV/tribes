import 'package:firebase_auth/firebase_auth.dart';

import 'package:aurogram/features/astrology/domain/astrology_service.dart';
import 'package:aurogram/features/baba/domain/baba_tool_registry.dart';

/// Baba's on-demand access to the user's OWN chart facts.
///
/// WHY: the voice brain (Dialogflow CX) doesn't carry the rich per-user chart
/// the text brain assembles server-side. Rather than stuff the whole chart into
/// CX's system prompt (which blew the ~8192-token budget once), Baba PULLS a
/// small, curated summary only when a question actually needs it. That keeps the
/// base prompt lean while still letting him answer "what's my rising sign?" or
/// "which dasha am I in?" accurately.
///
/// Curated on purpose: sun/moon/rising, nakshatra, current dasha lords, a few
/// yoga/dosha NAMES — never the raw planet arrays or full dasha timeline. If the
/// user wants that depth, Baba can navigateTo the chart and read it via
/// whereAmI's `onScreen` data.
///
/// Registered from the app composition root; the CX agent must also declare it
/// (see voice-relay/src/cx_tools.js) so CX knows it can call `getMyChart`.
class BabaAstrologyTools {
  BabaAstrologyTools._();

  static const String getMyChart = 'getMyChart';

  static BabaTool declaration() => BabaTool(
        name: getMyChart,
        description:
            "Fetch a COMPACT summary of the user's own birth chart — sun, moon "
            'and rising signs, nakshatra, the current dasha lords, and key '
            'yoga/dosha names — plus birth place and time. Call this when the '
            'user asks about THEIR chart, signs, dasha, yogas, doshas or '
            'personality and you need the facts. Returns a small summary, not '
            'the full chart; for deeper detail take them to the chart screen.',
        parameters: const {'type': 'object', 'properties': {}},
        appendsWorldState: false,
        defaultHandler: (_) async => _fetch(),
      );

  static Future<Map<String, dynamic>> _fetch() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return {'ok': false, 'reason': 'user not signed in'};
    }
    final p = await AstrologyService().getProfile(uid);
    if (p == null || !p.hasCalculatedData) {
      return {
        'ok': true,
        'hasChart': false,
        'hint': 'No chart yet — offer to set up their birth details.',
      };
    }
    return {
      'ok': true,
      'hasChart': true,
      if (p.sunSign != null) 'sunSign': p.sunSign,
      if (p.moonSign != null) 'moonSign': p.moonSign,
      if (p.ascendant != null) 'rising': p.ascendant,
      if ((p.nakshatra ?? p.moonNakshatra) != null)
        'nakshatra': p.nakshatra ?? p.moonNakshatra,
      if (p.currentDasha != null) 'currentDasha': _dasha(p.currentDasha!),
      if (p.yogas != null && p.yogas!.isNotEmpty)
        'yogas': p.yogas!.take(6).toList(growable: false),
      if (p.rajYogas != null && p.rajYogas!.isNotEmpty)
        'rajYogas': p.rajYogas!
            .map((y) => y['name'])
            .whereType<String>()
            .take(6)
            .toList(growable: false),
      if (p.birthPlace != null) 'birthPlace': p.birthPlace,
      if (p.birthTime != null) 'birthTime': p.birthTime,
    };
  }

  /// Pull just the human-relevant dasha LORDS, never the full timeline (that's
  /// what bloats tokens). Defensive about the stored shape.
  static Map<String, dynamic> _dasha(Map<String, dynamic> d) {
    String? lord(dynamic v) => v is String
        ? v
        : (v is Map ? (v['lord'] ?? v['name'] ?? v['planet'])?.toString() : null);

    final out = <String, dynamic>{};
    final maha = lord(d['mahadasha']) ?? lord(d['maha']);
    final antar = lord(d['antardasha']) ?? lord(d['antar']);
    if (maha != null) out['maha'] = maha;
    if (antar != null) out['antar'] = antar;

    // Fallback so Baba always gets *something* if the shape is unexpected.
    if (out.isEmpty) {
      for (final e in d.entries) {
        if (e.value is String && out.length < 3) out[e.key] = e.value;
      }
    }
    return out;
  }
}
