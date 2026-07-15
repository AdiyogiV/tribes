import 'package:firebase_auth/firebase_auth.dart';

import 'package:aurogram/features/astrology/domain/astrology_service.dart';
import 'package:aurogram/features/profile/domain/user_service.dart';

/// Builds Baba's OPENING directive so he LEADS the call (greets + takes the
/// initiative) instead of waiting to be spoken to. This is the single source of
/// truth for "active Baba" — used everywhere a call can start (the floating orb
/// AND the dashboard cow), so Baba behaves identically wherever you summon him.
///
/// The directive is DATA-AWARE on two axes so he always picks up where the user
/// is: whether he knows their NAME, and whether their BIRTH DETAILS are set up.
/// This drives value-first onboarding: greet -> learn name -> give a taste of
/// insight -> offer a real reading.
class BabaLead {
  BabaLead._();

  static Future<String> directive() async {
    var setUp = false;
    String? name;
    final user = FirebaseAuth.instance.currentUser;
    // A guest is an anonymous Firebase session (or none yet): data is saved but
    // NOT secured to a real account. We nudge these users to log in.
    final isGuest = user == null || user.isAnonymous;
    try {
      final uid = user?.uid;
      if (uid != null) {
        final profile = await AstrologyService().getProfile(uid);
        setUp = profile?.isComplete ?? false;
        try {
          final doc = await UserService().getUser(uid);
          final data = doc.data() as Map<String, dynamic>?;
          final n = data?['name']?.toString().trim();
          if (n != null && n.isNotEmpty) name = n;
        } catch (_) {/* name is optional */}
      }
    } catch (_) {
      // If we can't tell, fall through to the safe onboarding lead.
    }

    final knowsName = name != null && name.isNotEmpty;

    // Persistent, warm login nudge for guests who already have value on the
    // line (a chart / a name). Appended so it never blocks the value-first
    // taste, but ensures a guest is reminded EVERY session until they log in.
    final guestNudge = isGuest
        ? ' IMPORTANT: this user is a GUEST - their data is saved but NOT yet '
            'secured to a real account. After you have been useful this turn, '
            'warmly and explicitly remind them that logging in (a quick phone '
            'number) permanently secures everything and nothing is lost, and '
            'offer to take them there with navigateTo login. Keep it brief and '
            'kind, never a hard wall; if they decline, let them continue and '
            'nudge again next time.'
        : '';

    // Already fully set up: never re-onboard; greet (by name if known) and lead
    // to a useful next step.
    if (setUp) {
      final who = knowsName ? ' $name' : '';
      return 'The user just opened you. They ALREADY have their birth details '
              'set up - do NOT ask for birth date, time or place again. Greet$who '
              'warmly in one short breath, then IMMEDIATELY take the lead with a '
              'PROACTIVE, SPECIFIC recommendation - do NOT ask an open "how can I '
              'help?". First call getMyChart (and whereAmI) so your suggestion fits '
              'THEIR real chart and current screen, then offer ONE concrete next '
              'step and act on it if they agree - for example open their daily '
              'insight, explain a notable placement or dasha in their chart, or '
              'suggest a timely Ayurvedic tip. If they decline, offer a different '
              'useful step - never go passive or wait to be asked.$guestNudge';
    }

    // Value-first onboarding: no name yet -> introduce, learn name, give a
    // little free value, THEN offer the reading.
    if (!knowsName) {
      return 'The user just opened you for the FIRST time. You do not know '
          'their name yet. IMMEDIATELY speak first - do NOT wait for them. '
          'Warmly introduce yourself as Aurobhatt (Baba) in one short breath '
          'and ask what you may call them. When they answer, call the '
          'setUserName tool to remember it, read it back, then give a small, '
          'genuine taste of value - a brief vivid astrological observation '
          'about today - WITHOUT needing their birth details. Then offer to '
          'look at their personal stars, and if they agree, take them to the '
          'birth-details screen (navigateTo birthDetails). One or two sentences '
          'per turn, always end by moving them forward. Do NOT mention '
          'accounts, signing up or logging in yet - value first.';
    }

    // Know their name but no birth details.
    return 'The user just opened you. You already know their name is $name - '
        'IMMEDIATELY greet them by name warmly in one short breath, do NOT wait '
        'for them to speak. They have NOT set up their birth details yet, so '
        'offer to read their personal stars now and take them to the '
        'birth-details screen (navigateTo birthDetails) to collect date, time '
        'and place. One or two sentences, end by moving them forward.';
  }
}
