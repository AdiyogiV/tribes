import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:aurogram/core/logging/app_logger.dart';
import 'package:aurogram/features/baba/domain/baba_tool_registry.dart';

/// Lets Baba REMEMBER something a user tells him during a call, so he builds a
/// relationship across sessions instead of starting blank every time.
///
/// WHERE it writes: the same durable memory doc the backend already maintains,
/// `users/{uid}/memory/profile`, but into a dedicated `voiceNotes` array. The
/// nightly memory job writes `rollingSummary`/`threads` with `{merge:true}`, so
/// `voiceNotes` is never clobbered. The read side ([BabaLead]) folds the latest
/// notes into the call-opening [SESSION FACTS], so what Baba saves this call he
/// can recall on the next one.
///
/// Bounded: keeps only the most recent [_maxNotes] notes (read-modify-write) so
/// the doc can't grow without limit.
class BabaMemoryTools {
  BabaMemoryTools._();

  static const String rememberThis = 'rememberThis';
  static const int _maxNotes = 20;

  static BabaTool declaration() => BabaTool(
        name: rememberThis,
        description:
            'Save a durable fact the user tells you about their own life so you '
            'remember it on future calls — their work, relationships, goals, '
            'worries, preferences, a name, an event coming up. Call this the '
            'moment they share something worth keeping. Pass a short first-person '
            "note (e.g. 'Starting a new job in August, nervous about it') and an "
            "optional topic ('career'). Do NOT save astrology readings or your "
            'own advice — only what THEY told you about themselves.',
        parameters: const {
          'type': 'object',
          'properties': {
            'note': {
              'type': 'string',
              'description':
                  'The fact to remember, in a short first-person sentence.',
            },
            'topic': {
              'type': 'string',
              'description':
                  'Optional one-word bucket, e.g. career, family, health, money.',
            },
          },
          'required': ['note'],
        },
        defaultHandler: (args) async => _remember(args),
      );

  static Future<Map<String, dynamic>> _remember(
      Map<String, dynamic> args) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return {'ok': false, 'reason': 'user not signed in'};
    }
    final note = args['note']?.toString().trim();
    if (note == null || note.isEmpty) {
      return {'ok': false, 'reason': 'nothing to remember (empty note)'};
    }
    final topic = args['topic']?.toString().trim();

    try {
      final ref =
          FirebaseFirestore.instance.doc('users/$uid/memory/profile');
      final entry = <String, dynamic>{
        'note': note,
        if (topic != null && topic.isNotEmpty) 'topic': topic,
        'ts': DateTime.now().millisecondsSinceEpoch,
      };

      // Read-modify-write so we can keep the array bounded (arrayUnion cannot
      // trim). Low-frequency (one call turn), so no contention in practice.
      final snap = await ref.get();
      final existing = (snap.data()?['voiceNotes'] as List?) ?? const [];
      final notes = <Map<String, dynamic>>[
        ...existing.whereType<Map>().map((e) => Map<String, dynamic>.from(e)),
        entry,
      ];
      final trimmed = notes.length > _maxNotes
          ? notes.sublist(notes.length - _maxNotes)
          : notes;

      await ref.set({'voiceNotes': trimmed}, SetOptions(merge: true));
      return {'ok': true, 'remembered': true, 'note': note};
    } catch (e, st) {
      AppLogger.e('rememberThis failed',
          category: LogCategory.database, error: e, stackTrace: st);
      return {'ok': false, 'reason': 'could not save right now'};
    }
  }
}
