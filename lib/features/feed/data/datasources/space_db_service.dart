import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:aurogram/shared/models/space.dart';
import 'package:aurogram/shared/models/space_roles.dart';
import 'package:aurogram/shared/models/space_types.dart';
import 'package:aurogram/core/logging/app_logger.dart';

import 'package:aurogram/platform/file_helper.dart' as file_helper;

typedef ProgressCallback = void Function(String message);

/// Service for handling space-related database operations
class SpaceDbService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Live current user - never cached, so logout/login always uses the active account.
  User? get _currentUser => FirebaseAuth.instance.currentUser;

  final CollectionReference _spaces;
  final CollectionReference _userSpaces;
  final CollectionReference _spaceRoles;

  SpaceDbService()
      : _spaces = FirebaseFirestore.instance.collection('spaces'),
        _userSpaces = FirebaseFirestore.instance.collection('userSpaces'),
        _spaceRoles = FirebaseFirestore.instance.collection('spaceRoles');

  /// Gets the current user ID or throws an exception if not authenticated
  String _getCurrentUser() {
    if (_currentUser == null) throw Exception("User not authenticated!");
    return _currentUser!.uid;
  }

  /// Uploads a space display picture to Firebase Storage
  /// Supports both file path (mobile) and bytes (web)
  Future<void> _uploadDisplayPicture(Space space,
      {Uint8List? imageBytes}) async {
    if (imageBytes == null &&
        (space.displayPicture == null || space.displayPicture!.isEmpty)) {
      return;
    }

    final storageRef =
        _storage.ref().child('spaces/${space.id}/displayPicture');

    try {
      if (imageBytes != null) {
        // Web: upload from bytes
        await storageRef.putData(
            imageBytes, SettableMetadata(contentType: 'image/jpeg'));
      } else if (!kIsWeb && space.displayPicture != null) {
        // Mobile: upload from file path
        await storageRef
            .putFile(file_helper.createIOFile(space.displayPicture!));
      }

      space.displayPicture = await storageRef.getDownloadURL();
    } catch (e) {
      AppLogger.e('Error uploading space display picture',
          category: LogCategory.general, error: e);
    }
  }

  /// Creates a new space with image bytes (for web)
  Future<String> addSpaceWithBytes(
      Space space, Uint8List? imageBytes, ProgressCallback progress) async {
    final user = _getCurrentUser();
    final WriteBatch batch = _firestore.batch();
    final spaceRef = _spaces.doc();

    try {
      space.id = spaceRef.id;
      space.creatorId = user;
      progress("Uploading image...");
      await _uploadDisplayPicture(space, imageBytes: imageBytes);
      progress("Saving group details...");

      batch.set(spaceRef, space.toJson());

      // Add creator to space members
      final memberRef = _spaces.doc(space.id).collection('members').doc(user);
      batch.set(memberRef, {
        'userId': user,
        'joinedAt': Timestamp.now(),
        'role': 'admin',
      });

      // Add to user's spaces
      final userSpaceRef =
          _userSpaces.doc(user).collection('spaces').doc(space.id);
      batch.set(userSpaceRef, {
        'spaceId': space.id,
        'joinedAt': Timestamp.now(),
        'role': 'admin',
      });

      // Add space role for creator
      final roleRef = _spaceRoles.doc(space.id);
      batch.set(roleRef, {
        'roles': {user: SpaceRoles.admin}
      });

      await batch.commit();
      progress("Complete!");
      return space.id!;
    } catch (e) {
      AppLogger.e('Error adding space', error: e);
      FirebaseCrashlytics.instance.recordError(e, StackTrace.current);
      rethrow;
    }
  }

  /// Creates a new space
  Future<String> addSpace(Space space, ProgressCallback progress) async {
    final user = _getCurrentUser();
    final WriteBatch batch = _firestore.batch();
    final spaceRef = _spaces.doc();

    try {
      space.id = spaceRef.id;
      space.creatorId = user;
      progress("Uploading image...");
      await _uploadDisplayPicture(space);
      progress("Saving group details...");

      batch.set(spaceRef, space.toJson());

      final userSpaceData = {
        'spaceType': space.spaceType.index,
        'role': 'creator',
        'timestamp': FieldValue.serverTimestamp(),
        'adminOnlyPosting': space.adminOnlyPosting,
        'limitedVisibility': space.limitedVisibility,
      };

      batch.set(_userSpaces.doc(user).collection('spaces').doc(spaceRef.id),
          userSpaceData);

      final spaceRoleData = {
        'role': 'creator',
        'timestamp': FieldValue.serverTimestamp(),
      };
      batch.set(_spaceRoles.doc(spaceRef.id).collection('roles').doc(user),
          spaceRoleData);

      await batch.commit();
      progress("Gram created successfully!");

      return spaceRef.id;
    } catch (e) {
      AppLogger.e("", category: LogCategory.general);
      FirebaseCrashlytics.instance.recordError(e, StackTrace.current);
      rethrow;
    }
  }

  /// Retrieves a space by ID
  Future<Space> getSpace(String spaceId) async {
    try {
      final document = await _spaces.doc(spaceId).get();
      if (!document.exists) {
        throw Exception("Space not found! SpaceID: $spaceId");
      }
      return Space.fromJson(document.data() as Map<String, dynamic>);
    } catch (e) {
      AppLogger.e("", category: LogCategory.general);
      FirebaseCrashlytics.instance.recordError(e, StackTrace.current);
      rethrow;
    }
  }

  /// Retrieves spaces — applies a limit to prevent full collection scans.
  @Deprecated('No callers found — prefer user-scoped queries. Consider removing.')
  Future<List<Space>> getAllSpaces({int limit = 100}) async {
    try {
      final querySnapshot = await _spaces.limit(limit).get();
      return querySnapshot.docs
          .map((doc) => Space.fromJson(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      AppLogger.e("getAllSpaces failed", category: LogCategory.general);
      FirebaseCrashlytics.instance.recordError(e, StackTrace.current);
      rethrow;
    }
  }

  /// Streams spaces — applies a limit to prevent full collection scans.
  @Deprecated('No callers found — prefer user-scoped queries. Consider removing.')
  Stream<List<Space>> getSpacesStream({int limit = 100}) {
    return _spaces.limit(limit).snapshots().map((snapshot) => snapshot.docs
        .map((doc) => Space.fromJson(doc.data() as Map<String, dynamic>))
        .toList());
  }

  /// Updates an existing space
  Future<void> updateSpace(Space updatedSpace, {Uint8List? imageBytes}) async {
    try {
      await _uploadDisplayPicture(updatedSpace, imageBytes: imageBytes);
      await _spaces.doc(updatedSpace.id).update(updatedSpace.toJson());

      // Update userSpaces collection for all members
      QuerySnapshot membersSnapshot =
          await _spaceRoles.doc(updatedSpace.id).collection('roles').get();

      WriteBatch batch = _firestore.batch();
      for (var doc in membersSnapshot.docs) {
        String userId = doc.id;
        batch.update(
          _userSpaces.doc(userId).collection('spaces').doc(updatedSpace.id),
          {
            'spaceType': updatedSpace.spaceType.index,
            'adminOnlyPosting': updatedSpace.adminOnlyPosting,
            'limitedVisibility': updatedSpace.limitedVisibility,
          },
        );
      }
      await batch.commit();
    } catch (e) {
      AppLogger.e("", category: LogCategory.general);
      FirebaseCrashlytics.instance.recordError(e, StackTrace.current);
      rethrow;
    }
  }

  /// Gets a space's type
  Future<SpaceType> getSpaceType(String spaceId) async {
    try {
      Space space = await getSpace(spaceId);
      return space.spaceType;
    } catch (e) {
      AppLogger.e("", category: LogCategory.general);
      FirebaseCrashlytics.instance.recordError(e, StackTrace.current);
      rethrow;
    }
  }

  /// Gets a user's role in a space
  Future<SpaceRoles> getSpaceRole(String spaceId, String userId) async {
    try {
      DocumentSnapshot spaceRoleDocument =
          await _spaceRoles.doc(spaceId).collection('roles').doc(userId).get();
      if (!spaceRoleDocument.exists) return SpaceRoles.none;
      String roleString = spaceRoleDocument['role'];
      return _stringToSpaceRole(roleString);
    } catch (e) {
      AppLogger.e("", category: LogCategory.general);
      FirebaseCrashlytics.instance.recordError(e, StackTrace.current);
      rethrow;
    }
  }

  /// Converts a string role to SpaceRoles enum
  SpaceRoles _stringToSpaceRole(String roleString) {
    switch (roleString) {
      case 'creator':
        return SpaceRoles.creator;
      case 'admin':
        return SpaceRoles.admin;
      case 'member':
        return SpaceRoles.member;
      case 'invited':
        return SpaceRoles.invited;
      case 'requested':
        return SpaceRoles.requested;
      default:
        return SpaceRoles.none;
    }
  }

  /// Invites a user to a space
  Future<bool> inviteToSpace(String spaceId, String memberId) async {
    try {
      final user = _getCurrentUser();

      // Check if current user has permission to invite (admin or creator)
      SpaceRoles currentUserRole = await getSpaceRole(spaceId, user);
      if (currentUserRole != SpaceRoles.admin &&
          currentUserRole != SpaceRoles.creator) {
        AppLogger.w('User does not have permission to invite members',
            category: LogCategory.general);
        throw Exception('Only admins and creators can invite members');
      }

      WriteBatch batch = _firestore.batch();

      batch.set(_spaceRoles.doc(spaceId).collection('roles').doc(memberId), {
        'role': 'invited',
        'inviter': user,
        'timestamp': FieldValue.serverTimestamp(),
      });

      batch.set(_userSpaces.doc(memberId).collection('spaces').doc(spaceId), {
        'role': 'invited',
        'inviter': user,
        'timestamp': FieldValue.serverTimestamp(),
      });

      await batch.commit();
      return true;
    } catch (e) {
      AppLogger.e("Error inviting to space",
          category: LogCategory.general, error: e);
      FirebaseCrashlytics.instance.recordError(e, StackTrace.current);
      return false;
    }
  }

  /// Accepts a space invitation
  Future<bool> acceptInvitation(String spaceId) async {
    try {
      final user = _getCurrentUser();
      WriteBatch batch = _firestore.batch();

      DocumentSnapshot roleDoc =
          await _spaceRoles.doc(spaceId).collection('roles').doc(user).get();

      if (!roleDoc.exists || roleDoc['role'] != 'invited') {
        AppLogger.d("", category: LogCategory.general);
        return false;
      }

      batch.update(_spaceRoles.doc(spaceId).collection('roles').doc(user), {
        'role': 'member',
        'joinedAt': FieldValue.serverTimestamp(),
      });

      batch.update(_userSpaces.doc(user).collection('spaces').doc(spaceId), {
        'role': 'member',
        'joinedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
      return true;
    } catch (e) {
      AppLogger.e("", category: LogCategory.general);
      FirebaseCrashlytics.instance.recordError(e, StackTrace.current);
      return false;
    }
  }

  /// Requests to join a space
  Future<bool> requestToJoinSpace(String spaceId) async {
    try {
      final user = _getCurrentUser();
      Space space = await getSpace(spaceId);

      // If space is public, join directly as member
      if (isPublicSpaceType(space.spaceType)) {
        return await _joinSpaceAsMember(spaceId);
      }

      // Otherwise, create a request
      WriteBatch batch = _firestore.batch();

      batch.set(_spaceRoles.doc(spaceId).collection('roles').doc(user), {
        'role': 'requested',
        'timestamp': FieldValue.serverTimestamp(),
      });

      batch.set(_userSpaces.doc(user).collection('spaces').doc(spaceId), {
        'role': 'requested',
        'timestamp': FieldValue.serverTimestamp(),
      });

      await batch.commit();
      return true;
    } catch (e) {
      AppLogger.e("", category: LogCategory.general);
      FirebaseCrashlytics.instance.recordError(e, StackTrace.current);
      return false;
    }
  }

  /// Join a space as a member (for public/open spaces)
  Future<bool> _joinSpaceAsMember(String spaceId) async {
    try {
      final user = _getCurrentUser();
      WriteBatch batch = _firestore.batch();

      batch.set(_spaceRoles.doc(spaceId).collection('roles').doc(user), {
        'role': 'member',
        'joinedAt': FieldValue.serverTimestamp(),
      });

      batch.set(_userSpaces.doc(user).collection('spaces').doc(spaceId), {
        'role': 'member',
        'joinedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
      return true;
    } catch (e) {
      AppLogger.e("", category: LogCategory.general);
      FirebaseCrashlytics.instance.recordError(e, StackTrace.current);
      return false;
    }
  }

  /// Approves a user's request to join a space
  Future<bool> approveJoinRequest(String spaceId, String memberId) async {
    try {
      // Check admin permissions
      final user = _getCurrentUser();
      SpaceRoles currentUserRole = await getSpaceRole(spaceId, user);
      if (currentUserRole != SpaceRoles.admin &&
          currentUserRole != SpaceRoles.creator) {
        AppLogger.d("", category: LogCategory.general);
        return false;
      }

      // Check if member has a pending request
      DocumentSnapshot memberRoleDoc = await _spaceRoles
          .doc(spaceId)
          .collection('roles')
          .doc(memberId)
          .get();

      if (!memberRoleDoc.exists || memberRoleDoc['role'] != 'requested') {
        AppLogger.d("", category: LogCategory.general);
        return false;
      }

      // Approve the request
      WriteBatch batch = _firestore.batch();

      batch.update(_spaceRoles.doc(spaceId).collection('roles').doc(memberId), {
        'role': 'member',
        'approvedBy': user,
        'joinedAt': FieldValue.serverTimestamp(),
      });

      batch
          .update(_userSpaces.doc(memberId).collection('spaces').doc(spaceId), {
        'role': 'member',
        'approvedBy': user,
        'joinedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
      return true;
    } catch (e) {
      AppLogger.e("", category: LogCategory.general);
      FirebaseCrashlytics.instance.recordError(e, StackTrace.current);
      return false;
    }
  }

  /// Makes a user an admin in a space
  Future<bool> makeAdmin(String spaceId, String userId) async {
    try {
      // Check creator permissions
      final user = _getCurrentUser();
      DocumentSnapshot creatorDoc =
          await _spaceRoles.doc(spaceId).collection('roles').doc(user).get();

      if (!creatorDoc.exists || creatorDoc['role'] != 'creator') {
        AppLogger.d("", category: LogCategory.general);
        return false;
      }

      // Check if user is already an admin or creator
      DocumentSnapshot roleDoc =
          await _spaceRoles.doc(spaceId).collection('roles').doc(userId).get();

      if (!roleDoc.exists) {
        AppLogger.d('', category: LogCategory.general);
        return false;
      }

      String currentRole = roleDoc['role'];
      if (currentRole == 'admin' || currentRole == 'creator') {
        AppLogger.d('', category: LogCategory.general);
        return false;
      }

      // Update the user's role to admin
      WriteBatch batch = _firestore.batch();

      batch.update(_spaceRoles.doc(spaceId).collection('roles').doc(userId), {
        'role': 'admin',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      batch.update(_userSpaces.doc(userId).collection('spaces').doc(spaceId), {
        'role': 'admin',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
      AppLogger.d('', category: LogCategory.general);
      return true;
    } catch (e) {
      AppLogger.e('', category: LogCategory.general);
      FirebaseCrashlytics.instance.recordError(e, StackTrace.current);
      return false;
    }
  }

  /// Removes a user from a space
  Future<bool> removeSpaceMember(String spaceId, String memberId) async {
    try {
      // Check permissions
      final user = _getCurrentUser();
      SpaceRoles currentUserRole = await getSpaceRole(spaceId, user);

      // Only admin or creator can remove members
      if (currentUserRole != SpaceRoles.admin &&
          currentUserRole != SpaceRoles.creator) {
        // Or users can remove themselves
        if (user != memberId) {
          AppLogger.d("", category: LogCategory.general);
          return false;
        }
      }

      // Creator can't be removed
      DocumentSnapshot memberRoleDoc = await _spaceRoles
          .doc(spaceId)
          .collection('roles')
          .doc(memberId)
          .get();

      if (memberRoleDoc.exists && memberRoleDoc['role'] == 'creator') {
        AppLogger.d("", category: LogCategory.general);
        return false;
      }

      // Remove the member
      WriteBatch batch = _firestore.batch();

      batch.delete(_spaceRoles.doc(spaceId).collection('roles').doc(memberId));
      batch.delete(_userSpaces.doc(memberId).collection('spaces').doc(spaceId));

      await batch.commit();
      return true;
    } catch (e) {
      AppLogger.e('', category: LogCategory.general);
      FirebaseCrashlytics.instance.recordError(e, StackTrace.current);
      return false;
    }
  }

  /// Checks if a user has posting permissions in a space
  Future<bool> checkSpaceFeedPostingPermissions(String spaceId) async {
    try {
      final user = _getCurrentUser();
      SpaceRoles role = await getSpaceRole(spaceId, user);

      // Check if user is a member
      if (role != SpaceRoles.member &&
          role != SpaceRoles.admin &&
          role != SpaceRoles.creator) {
        return false;
      }

      // Get space details
      Space space = await getSpace(spaceId);

      // If admin-only posting is enabled, only admins and creator can post
      if (space.adminOnlyPosting) {
        return role == SpaceRoles.admin || role == SpaceRoles.creator;
      }

      // Otherwise, all members can post
      return true;
    } catch (e) {
      AppLogger.e('', category: LogCategory.general);
      FirebaseCrashlytics.instance.recordError(e, StackTrace.current);
      return false;
    }
  }
}
