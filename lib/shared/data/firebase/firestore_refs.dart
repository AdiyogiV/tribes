import 'package:cloud_firestore/cloud_firestore.dart';

/// Centralized Firestore collection references.
/// All Firestore collection paths are defined here to prevent typos
/// and enable easy refactoring.
class FirestoreRefs {
  FirestoreRefs._();

  static final _db = FirebaseFirestore.instance;

  // ── User-related ──────────────────────────────────────────────────────
  static CollectionReference get users => _db.collection('users');
  static CollectionReference get nicknames => _db.collection('nicknames');
  static CollectionReference get blocks => _db.collection('blocks');
  static CollectionReference get phoneIndex => _db.collection('phoneIndex');

  // ── Spaces ────────────────────────────────────────────────────────────
  static CollectionReference get spaces => _db.collection('spaces');
  static CollectionReference get userSpaces => _db.collection('userSpaces');
  static CollectionReference get spaceRoles => _db.collection('spaceRoles');

  // ── Posts & Feed ──────────────────────────────────────────────────────
  static CollectionReference get posts => _db.collection('posts');
  static CollectionReference get spacePosts => _db.collection('spacePosts');
  static CollectionReference get postReplies => _db.collection('postReplies');
  static CollectionReference get postLikes => _db.collection('postLikes');
  static CollectionReference get userReplies => _db.collection('userReplies');
  static CollectionReference get votes => _db.collection('votes');

  // ── Notifications ─────────────────────────────────────────────────────
  static CollectionReference get notifications => _db.collection('notifications');

  // ── Misc ──────────────────────────────────────────────────────────────
  static CollectionReference get items => _db.collection('items');
  static CollectionReference get calls => _db.collection('calls');
  static CollectionReference get reports => _db.collection('reports');
}
