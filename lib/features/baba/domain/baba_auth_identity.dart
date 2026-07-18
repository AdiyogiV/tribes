import 'package:firebase_auth/firebase_auth.dart';

/// The auth facts that affect Baba's behavior and cached session context.
///
/// Firebase can upgrade an anonymous user in place without changing the uid, so
/// uid alone is not enough to decide whether an existing greeting is still
/// valid. Keeping this as a value object also makes the transition policy easy
/// to test without booting Firebase.
class BabaAuthIdentity {
  const BabaAuthIdentity({required this.uid, required this.isAnonymous});

  factory BabaAuthIdentity.fromUser(User? user) => BabaAuthIdentity(
        uid: user?.uid,
        isAnonymous: user == null || user.isAnonymous,
      );

  final String? uid;
  final bool isAnonymous;

  String get account => isAnonymous ? 'guest' : 'secured';

  bool requiresSessionRefresh(BabaAuthIdentity next) => this != next;

  @override
  bool operator ==(Object other) =>
      other is BabaAuthIdentity &&
      uid == other.uid &&
      isAnonymous == other.isAnonymous;

  @override
  int get hashCode => Object.hash(uid, isAnonymous);
}
