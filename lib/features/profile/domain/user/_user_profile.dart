import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:aurogram/core/logging/app_logger.dart';
import 'package:aurogram/platform/file_helper.dart' as file_helper;

import '../user_service.dart';

/// Extension on [UserService] for profile management, account deletion, and re-authentication.
extension UserProfile on UserService {
  /// Upload display picture - handles both file path (mobile) and bytes (web)
  /// [source] can be a String file path (mobile) or Uint8List bytes (web)
  Future<String?> uploadDisplayPictureInternal(dynamic source) async {
    try {
      FirebaseStorage storage = FirebaseStorage.instance;
      Reference storageRef =
          storage.ref().child('users/${user?.uid}/displayPicture.jpg');

      if (source is Uint8List) {
        // Web: upload from bytes
        await storageRef.putData(
            source, SettableMetadata(contentType: 'image/jpeg'));
      } else if (source is String && !kIsWeb) {
        // Mobile: upload from file path
        await storageRef.putFile(file_helper.createIOFile(source));
      } else {
        AppLogger.e('Invalid display picture source type',
            category: LogCategory.auth);
        return null;
      }

      return await storageRef.getDownloadURL();
    } catch (e) {
      AppLogger.e('Error uploading display picture',
          category: LogCategory.auth, error: e);
      return null;
    }
  }

  /// Upload display picture from bytes (for web and cross-platform use)
  Future<String?> uploadDisplayPictureFromBytes(Uint8List bytes) async {
    return await uploadDisplayPictureInternal(bytes);
  }

  /// Update user's private profile setting
  Future<bool> setPrivateProfile(bool isPrivate) async {
    try {
      if (user == null) return false;
      await userCollection.doc(user!.uid).set({
        'isPrivateProfile': isPrivate,
        'lastUpdated': Timestamp.fromDate(DateTime.now()),
      }, SetOptions(merge: true));
      return true;
    } catch (e) {
      AppLogger.e('Error updating private profile setting',
          category: LogCategory.auth, error: e);
      return false;
    }
  }

  /// Get user's private profile setting
  Future<bool> isPrivateProfile(String? userId) async {
    try {
      if (userId == null) return false;
      final doc = await userCollection.doc(userId).get();
      final data = doc.data() as Map<String, dynamic>?;
      return data?['isPrivateProfile'] as bool? ?? false;
    } catch (e) {
      AppLogger.e('Error getting private profile setting',
          category: LogCategory.general, error: e);
      return false;
    }
  }

  Future<bool> updateUserProfile({
    String? name,
    String? nickname,
    String? displayPicture,
  }) async {
    try {
      Map<String, dynamic> updateData = {};

      if (name != null) {
        updateData['name'] = name;
      }

      if (nickname != null) {
        updateData['nickname'] = nickname;
        // Get the current name if not provided
        String nameForNickname;
        if (name != null) {
          nameForNickname = name;
        } else {
          DocumentSnapshot userDoc = await userCollection.doc(user?.uid).get();
          Map<String, dynamic>? userData =
              userDoc.data() as Map<String, dynamic>?;
          nameForNickname = userData?['name'] ?? '';
        }
        // Update nickname in the nicknameCollection
        await nicknameCollection.doc('pairs').set({
          nickname: {'name': nameForNickname, 'uid': user?.uid}
        }, SetOptions(merge: true));
      }

      if (displayPicture != null) {
        String? downloadURL =
            await uploadDisplayPictureInternal(displayPicture);
        if (downloadURL != null) {
          updateData['displayPicture'] = downloadURL;
        }
      }

      if (updateData.isNotEmpty) {
        updateData["lastUpdated"] = Timestamp.fromDate(DateTime.now());
        await userCollection
            .doc(user?.uid)
            .set(updateData, SetOptions(merge: true));
      }

      return true;
    } catch (e, stackTrace) {
      AppLogger.e('Error updating user profile',
          category: LogCategory.auth, error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// Deletes the user's account.
  ///
  /// This method performs a lightweight frontend operation:
  /// 1. Validates recent authentication (Firebase requirement)
  /// 2. Stores deletion metadata for audit purposes
  /// 3. Deletes the Firebase Auth user
  ///
  /// The actual data cleanup is handled by a Cloud Function (onUserDeleted)
  /// that is automatically triggered when the auth user is deleted.
  /// This ensures reliable, complete cleanup even if the app is closed.
  ///
  /// Throws [NeedsReauthenticationException] if re-authentication is required.
  Future<bool> deleteUser() async {
    if (user == null) return false;

    // Check if sign-in is recent enough.
    // Firebase requires recent authentication for sensitive operations like account deletion.
    final lastSignIn = user?.metadata.lastSignInTime;
    if (lastSignIn == null) {
      throw NeedsReauthenticationException();
    }

    final minutesSinceSignIn =
        DateTime.now().difference(lastSignIn).inMinutes;
    if (minutesSinceSignIn >= 3) {
      // Sign-in is too old - require re-authentication
      AppLogger.i(
          'Delete account requires re-auth: last sign-in was $minutesSinceSignIn minutes ago',
          category: LogCategory.auth);
      throw NeedsReauthenticationException();
    }

    try {
      // Store deletion metadata for audit trail and Cloud Function reference
      // Cloud Function (onUserDeleted) will update this with completion status
      await storeDeletedUserReference();

      AppLogger.i('Initiating account deletion for user: ${user!.uid}',
          category: LogCategory.auth);

      // Delete the Firebase Auth user
      // This triggers the onUserDeleted Cloud Function which handles ALL data cleanup:
      // - User document + subcollections (dailyInsights, auraHistory, etc.)
      // - Posts and media files
      // - Follow relationships (both directions)
      // - Space memberships
      // - DM conversations
      // - Indices (phoneIndex, nicknames)
      // - Storage files
      await user?.delete();

      AppLogger.i(
          'Account deletion initiated successfully - Cloud Function will complete cleanup',
          category: LogCategory.auth);

      return true;
    } on FirebaseAuthException catch (e) {
      // CRITICAL FIX: Remove deletedUsers record on failure to prevent permanent login block
      AppLogger.w('Auth deletion failed, rolling back deletedUsers record',
          category: LogCategory.auth);
      await removeDeletedUserReference();

      AppLogger.e('Firebase Auth error during deletion',
          category: LogCategory.auth, error: e);
      if (e.code == 'requires-recent-login') {
        throw NeedsReauthenticationException();
      }
      rethrow;
    } catch (e) {
      // CRITICAL FIX: Remove deletedUsers record on failure to prevent permanent login block
      AppLogger.w(
          'Account deletion failed, rolling back deletedUsers record',
          category: LogCategory.general);
      await removeDeletedUserReference();

      AppLogger.e('Error during account deletion',
          category: LogCategory.general, error: e);
      // Check if it's a Firebase Auth error requiring re-login
      if (e.toString().contains('requires-recent-login')) {
        throw NeedsReauthenticationException();
      }
      rethrow;
    }
  }

  Future<void> reauthenticateUser(String password) async {
    if (user == null) throw Exception("No user is currently signed in");

    try {
      final credential = EmailAuthProvider.credential(
        email: user!.email!,
        password: password,
      );

      await user!.reauthenticateWithCredential(credential);
    } catch (e) {
      AppLogger.e('Failed to reauthenticate user',
          category: LogCategory.auth, error: e);
      throw Exception("Failed to reauthenticate user");
    }
  }
}
