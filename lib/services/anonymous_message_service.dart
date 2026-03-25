import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:aurogram/utils/logging/app_logger.dart';

class AnonymousMessageService {
  static final AnonymousMessageService _instance =
      AnonymousMessageService._internal();
  factory AnonymousMessageService() => _instance;
  AnonymousMessageService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'asia-southeast2');

  User? get _currentUser => _auth.currentUser;

  Future<String?> getExistingSlug() async {
    final user = _currentUser;
    if (user == null) return null;
    final doc = await _firestore.collection('users').doc(user.uid).get();
    final data = doc.data();
    return data?['anonymousLinkSlug'] as String?;
  }

  Future<String> getOrCreateSlug() async {
    final user = _currentUser;
    if (user == null) {
      throw StateError('User not signed in');
    }

    final existing = await getExistingSlug();
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }

    for (var attempt = 0; attempt < 5; attempt++) {
      final slug = _generateSlug();
      final exists = await _slugExists(slug);
      if (exists) continue;

      await _firestore.collection('users').doc(user.uid).update({
        'anonymousLinkSlug': slug,
      });
      return slug;
    }

    throw StateError('Failed to generate unique link');
  }

  Future<Map<String, dynamic>?> getUserBySlug(String slug) async {
    final snapshot = await _firestore
        .collection('users')
        .where('anonymousLinkSlug', isEqualTo: slug)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) return null;
    return {
      'uid': snapshot.docs.first.id,
      ...snapshot.docs.first.data(),
    };
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> inboxStream(String recipientId) {
    return _firestore
        .collection('anonymousMessages')
        .where('recipientId', isEqualTo: recipientId)
        .where('status', isEqualTo: 'visible')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> updateMessageStatus(String messageId, String status) async {
    await _firestore.collection('anonymousMessages').doc(messageId).update({
      'status': status,
    });
  }

  Future<void> submitMessage({
    String? slug,
    String? recipientId,
    required String text,
  }) async {
    final callable = _functions.httpsCallable('submitAnonymousMessage');
    await callable.call({
      if (slug != null) 'slug': slug,
      if (recipientId != null) 'recipientId': recipientId,
      'text': text,
    });
  }

  Future<bool> _slugExists(String slug) async {
    final snapshot = await _firestore
        .collection('users')
        .where('anonymousLinkSlug', isEqualTo: slug)
        .limit(1)
        .get();
    return snapshot.docs.isNotEmpty;
  }

  String _generateSlug() {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final rand = Random.secure();
    return List.generate(8, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  String buildShareLink(String slug) {
    return 'https://aurogram.in/s/$slug';
  }

  String buildSharePrefill() {
    return 'Send me an anonymous message';
  }

  void logError(String message, Object error) {
    AppLogger.e(message, category: LogCategory.general, error: error);
  }
}
