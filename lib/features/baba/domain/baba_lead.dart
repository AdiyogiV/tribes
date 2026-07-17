import 'package:firebase_auth/firebase_auth.dart';

import 'package:aurogram/features/astrology/domain/astrology_service.dart';
import 'package:aurogram/features/profile/domain/user_service.dart';

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
    var hasChart = false;
    String? name;
    final user = FirebaseAuth.instance.currentUser;
    // A guest is an anonymous Firebase session (or none yet): data is saved but
    // NOT secured to a real account.
    final isGuest = user == null || user.isAnonymous;
    try {
      final uid = user?.uid;
      if (uid != null) {
        final profile = await AstrologyService().getProfile(uid);
        hasChart = profile?.isComplete ?? false;
        try {
          final doc = await UserService().getUser(uid);
          final data = doc.data() as Map<String, dynamic>?;
          final n = data?['name']?.toString().trim();
          if (n != null && n.isNotEmpty) name = n;
        } catch (_) {/* name is optional */}
      }
    } catch (_) {
      // If we can't tell, emit what we know; the playbook has safe defaults.
    }

    final cue = factsCue(
      name: name,
      isGuest: isGuest,
      hasChart: hasChart,
      screen: 'dashboard',
    );
    return cue;
  }

  /// Assemble a compact, machine-readable [SESSION FACTS] line. Facts only —
  /// no prose. The playbook interprets these and decides the behaviour.
  static String factsCue({
    required String? name,
    required bool isGuest,
    required bool hasChart,
    required String screen,
  }) {
    final knowsName = name != null && name.isNotEmpty;
    final facts = <String>[
      'name=${knowsName ? name : 'unknown'}',
      'account=${isGuest ? 'guest' : 'secured'}',
      'chart=${hasChart ? 'exists' : 'none'}',
      'screen=$screen',
    ];
    return '[SESSION FACTS] ${facts.join('; ')}. '
        'The user just opened you — speak first and lead per your playbook.';
  }
}
