import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:aurogram/core/logging/app_logger.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:aurogram/features/profile/domain/contact_service.dart';

export 'user/_user_display_name.dart';
export 'user/_user_block.dart';
export 'user/_user_registration.dart';
export 'user/_user_profile.dart';

class UserService {
  final FirebaseAuth auth = FirebaseAuth.instance;
  User? get user => auth.currentUser;
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final CollectionReference userCollection =
      FirebaseFirestore.instance.collection('users');
  final CollectionReference nicknameCollection =
      FirebaseFirestore.instance.collection('nicknames');
  final CollectionReference blockCollection =
      FirebaseFirestore.instance.collection('blocks');

  // Cache for deleted user status to avoid repeated queries
  static final Map<String, bool> deletedUserCache = {};
  static final Map<String, DateTime> deletedUserCacheTimestamps = {};
  static final Map<String, String> displayNameCache = {};
  static final Map<String, DateTime> displayNameCacheTimestamps = {};
  static const Duration cacheExpiry = Duration(minutes: 15);
  static const String deletedUserLabel = 'Deleted User';

  /// Saves FCM token to Firestore with multi-device support.
  /// Adds token to fcmTokens array and also sets legacy fcmToken field.
  Future<void> saveFcmToken(String token) async {
    if (user != null) {
      try {
        final userDoc = userCollection.doc(user!.uid);
        final snapshot = await userDoc.get();

        if (snapshot.exists) {
          final data = snapshot.data() as Map<String, dynamic>?;
          final existingTokens =
              (data?['fcmTokens'] as List<dynamic>?)?.cast<String>() ?? [];

          if (!existingTokens.contains(token)) {
            // Add new token to array
            await userDoc.update({
              'fcmToken': token,
              'fcmTokens': FieldValue.arrayUnion([token]),
              'lastTokenUpdate': FieldValue.serverTimestamp(),
            });
          } else {
            // Token exists, just update timestamp
            await userDoc.update({
              'fcmToken': token,
              'lastTokenUpdate': FieldValue.serverTimestamp(),
            });
          }
        } else {
          // Create new document with token
          await userDoc.set({
            'fcmToken': token,
            'fcmTokens': [token],
            'lastTokenUpdate': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      } catch (e) {
        AppLogger.e('Error saving FCM token',
            category: LogCategory.messaging, error: e);
        // Fallback to simple set for backward compatibility
        await userCollection.doc(user!.uid).set({
          'fcmToken': token,
        }, SetOptions(merge: true));
      }
    }
  }

  // Add this method to get FCM token
  Future<String?> getFcmToken() async {
    if (user != null) {
      DocumentSnapshot doc = await userCollection.doc(user!.uid).get();
      return doc.get('fcmToken') as String?;
    }
    return null;
  }

  // sayNamaste() has been moved to NamasteService (backend-first approach)
  // Use NamasteService().sendNamaste() instead

  Future<DocumentSnapshot> getUser(String user) async {
    return await FirebaseFirestore.instance.collection('users').doc(user).get();
  }

  /// Save phone index for contact discovery
  Future<void> savePhoneIndex(String phoneNumber) async {
    if (user == null) return;
    try {
      await ContactService.savePhoneIndex(phoneNumber, user!.uid);
    } catch (e) {
      AppLogger.w('Failed to save phone index',
          category: LogCategory.database, data: {'error': e.toString()});
    }
  }

  /// Ensure current user's phone is indexed (call on app startup for backfill)
  Future<void> ensurePhoneIndexed() async {
    if (user?.phoneNumber == null) {
      AppLogger.d('Cannot index phone - user phone is null',
          category: LogCategory.database);
      return;
    }

    try {
      final normalized = _normalizePhone(user!.phoneNumber!);
      if (normalized == null) {
        AppLogger.w('Cannot normalize phone for indexing',
            category: LogCategory.database,
            data: {'phone': user!.phoneNumber});
        return;
      }

      final hash = _hashPhone(normalized);

      // 1. Ensure phone is in user document (backfill for old users)
      final userDoc = await userCollection.doc(user!.uid).get();
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>?;
        if (userData != null && userData['phoneNumber'] == null) {
          await userCollection.doc(user!.uid).update({
            'phoneNumber': user!.phoneNumber,
          });
          AppLogger.i('Backfilled phone number in user document',
              category: LogCategory.database, data: {'phone': normalized});
        }
      }

      // 2. Ensure phone is in phoneIndex
      final indexDoc =
          await firestore.collection('phoneIndex').doc(hash).get();
      if (!indexDoc.exists) {
        await ContactService.savePhoneIndex(user!.phoneNumber!, user!.uid);
        AppLogger.i('Backfilled phone index for current user',
            category: LogCategory.database,
            data: {'hash': hash, 'phone': normalized});
      } else {
        AppLogger.d('Phone already indexed',
            category: LogCategory.database, data: {'hash': hash});
      }
    } catch (e) {
      AppLogger.e('Failed to ensure phone indexed',
          category: LogCategory.database, error: e);
    }
  }

  /// Normalize phone number for consistent hashing
  String? _normalizePhone(String phone) {
    var digits = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final digitCount = digits.replaceAll('+', '').length;
    if (digitCount < 10) return null;
    if (!digits.startsWith('+')) {
      if (digits.length == 10) {
        digits = '+91$digits';
      } else if (digits.startsWith('91') && digits.length == 12) {
        digits = '+$digits';
      } else if (digits.length > 10) {
        digits = '+$digits';
      }
    }
    return digits;
  }

  /// Hash phone number for privacy
  /// Returns full 64-character SHA256 hash for collision resistance
  String _hashPhone(String phone) {
    final bytes = utf8.encode(phone);
    final digest = sha256.convert(bytes);
    return digest.toString(); // Full 64-char hash
  }

  /// Stores deletion reference for audit trail.
  /// The Cloud Function will update this document with cleanup status.
  Future<void> storeDeletedUserReference() async {
    await firestore.collection('deletedUsers').doc(user?.uid).set({
      'phoneNumber': user?.phoneNumber,
      'email': user?.email,
      'deletionRequestedAt': FieldValue.serverTimestamp(),
      'status':
          'pending', // Cloud Function will update to 'completed' or 'failed'
      'requestedFrom': 'app',
    });
  }

  /// Removes deletion reference if account deletion fails.
  /// This prevents users from being permanently blocked if Auth deletion fails.
  Future<void> removeDeletedUserReference() async {
    try {
      await firestore.collection('deletedUsers').doc(user?.uid).delete();
      AppLogger.i('Removed deletedUsers record after failed deletion',
          category: LogCategory.auth);
    } catch (e) {
      AppLogger.e('Failed to remove deletedUsers record',
          category: LogCategory.auth, error: e);
      // Don't rethrow - we're already in error handling
    }
  }
}

class NeedsReauthenticationException implements Exception {
  @override
  String toString() => 'User needs to reauthenticate before deleting account';
}
