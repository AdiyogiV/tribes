import 'package:firebase_auth/firebase_auth.dart';

import 'package:aurogram/features/ayurveda/domain/ayurveda_service.dart';
import 'package:aurogram/features/baba/domain/baba_tool_registry.dart';

/// Baba's on-demand access to the user's OWN Ayurvedic constitution — so he can
/// mentor the body the way getMyChart lets him read the stars. Returns their
/// prakriti (dosha make-up), agni (digestive fire), and concrete diet/lifestyle
/// suggestions, tuned to the dosha ruling THIS time of day.
///
/// Kept compact on purpose (a few favoured/avoided foods, a couple of lifestyle
/// cues) so the voice brain can offer ONE grounded suggestion, not a lecture.
class BabaAyurvedaTools {
  BabaAyurvedaTools._();

  static const String getMyWellness = 'getMyWellness';

  static BabaTool declaration() => BabaTool(
        name: getMyWellness,
        description:
            "Fetch the user's OWN Ayurvedic constitution — their prakriti "
            '(vata/pitta/kapha balance and type), agni (digestion), the dosha '
            'ruling this time of day, and concrete diet + lifestyle suggestions '
            'for them right now (foods to favour/avoid, a lifestyle cue, a quick '
            'remedy). Call this when the user asks about their body, health, '
            'energy, diet, sleep, what to eat, or how to feel better. If they '
            "have no profile yet, it says so — offer to set up their details.",
        parameters: const {'type': 'object', 'properties': {}},
        appendsWorldState: false,
        defaultHandler: (_) async => _fetch(),
      );

  static Future<Map<String, dynamic>> _fetch() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return {'ok': false, 'reason': 'user not signed in'};
    }

    final service = AyurvedaService();
    final now = service.getCurrentDoshaPeriod();
    final doshaNow = <String, dynamic>{
      'dosha': now['dosha'],
      'period': now['period'],
      'guidance': now['guidance'],
    };

    final profile = await service.getProfile(uid);
    if (profile == null || !profile.hasData) {
      return {
        'ok': true,
        'hasProfile': false,
        'doshaNow': doshaNow,
        'hint': 'No Ayurvedic profile yet. It comes from their birth chart — '
            'offer to set up birth details, or point them to the Ayurveda '
            'screen to complete it.',
      };
    }

    final dominant = profile.dominantDosha; // 'vata' | 'pitta' | 'kapha'
    final rec = dominant != null
        ? service.getRecommendations(dominant)
        : const <String, dynamic>{};
    final foods = rec['foods'] as Map<String, dynamic>?;

    return {
      'ok': true,
      'hasProfile': true,
      if (profile.prakritiType != null) 'prakriti': profile.prakritiType,
      if (dominant != null) 'dominantDosha': dominant,
      if (profile.agniType != null) 'agni': profile.agniType,
      'doshaNow': doshaNow,
      if (foods != null) 'favorFoods': _take(foods['favor'], 4),
      if (foods != null) 'avoidFoods': _take(foods['avoid'], 3),
      'lifestyle': _take(rec['lifestyle'], 3),
      if (rec['quickRemedies'] is Map)
        'quickRemedies': rec['quickRemedies'],
    };
  }

  /// Defensively take up to [n] string items from a dynamic list.
  static List<String> _take(dynamic list, int n) {
    if (list is! List) return const [];
    return list
        .whereType<String>()
        .take(n)
        .toList(growable: false);
  }
}
