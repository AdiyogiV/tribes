import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:aurogram/models/space_roles.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:aurogram/models/space_types.dart';
import '../models/space.dart';
import 'package:aurogram/utils/memory/memory_manager.dart';
import 'package:aurogram/utils/network/network_manager.dart';
import 'package:aurogram/utils/logging/app_logger.dart';
import 'package:aurogram/services/analytics_service.dart';

// Conditional import for dart:io
import 'dart:io' if (dart.library.html) 'package:aurogram/platform/io_stub.dart';
import 'package:aurogram/platform/file_helper.dart' as file_helper;

typedef ProgressCallback = void Function(String message);

class SpaceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final CollectionReference _spaces;
  final CollectionReference _userSpaces;
  final CollectionReference _spaceRoles;

  SpaceService()
      : _spaces = FirebaseFirestore.instance.collection('spaces'),
        _userSpaces = FirebaseFirestore.instance.collection('userSpaces'),
        _spaceRoles = FirebaseFirestore.instance.collection('spaceRoles');

  String _getCurrentUser() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("User not authenticated!");
    return user.uid;
  }

  /// Upload space display picture - handles both path (mobile) and bytes (web)
  Future<void> _uploadDisplayPicture(Space space, {Uint8List? imageBytes}) async {
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
        await storageRef.putFile(file_helper.createIOFile(space.displayPicture!));
      }

      space.displayPicture = await storageRef.getDownloadURL();
    } catch (e) {
      AppLogger.e('Error uploading space display picture',
          category: LogCategory.general, error: e);
    }
  }

  /// Add space with image bytes (for web)
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
      final userSpaceRef = _userSpaces.doc(user).collection('spaces').doc(space.id);
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

      AnalyticsService().trackSpaceCreated(
        spaceId: space.id!,
        spaceType: space.spaceType.name,
      );

      return space.id!;
    } catch (e) {
      AppLogger.e('Error adding space', error: e);
      rethrow;
    }
  }

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
      AppLogger.e(
        'Error creating Space',
        category: LogCategory.general,
        error: e,
      );
      rethrow;
    }
  }

  // Cache of missing space IDs to prevent repeated lookups
  final Set<String> _notFoundSpaceIds = {};

  // Cache of successfully retrieved spaces
  final Map<String, Space> _spaceCache = {};

  /// Clean up references to missing spaces for a user
  Future<void> cleanupMissingSpace(String spaceId, String userId) async {
    try {
      // Mark as not found to avoid future lookups
      _notFoundSpaceIds.add(spaceId);

      // Remove from user's spaces collection
      await _userSpaces.doc(userId).collection('spaces').doc(spaceId).delete();

      // Log only once to avoid spam
      AppLogger.i(
        'Removed invalid space reference',
        category: LogCategory.general,
        data: {'spaceId': spaceId, 'userId': userId},
      );
    } catch (e) {
      // Silent error - this is just cleanup
    }
  }

  Future<Space> getSpace(String spaceId) async {
    // Return error immediately if spaceId is empty
    if (spaceId.isEmpty) {
      throw Exception("Invalid space ID (empty)");
    }

    // Check cache for successful lookups first
    if (_spaceCache.containsKey(spaceId)) {
      return _spaceCache[spaceId]!;
    }

    // Check if we already know this space doesn't exist
    if (_notFoundSpaceIds.contains(spaceId)) {
      throw Exception("Space not found! SpaceID: $spaceId (cached)");
    }

    // Check for network connectivity but don't immediately fail
    final networkManager = NetworkManager();
    bool isConnected = networkManager.isOnline;

    // If not connected, try once more with a short delay
    if (!isConnected) {
      // Wait briefly and check again
      await Future.delayed(Duration(milliseconds: 800));
      isConnected = await networkManager.checkInternetAccess();

      // If still not connected, check if we have a cached document
      if (!isConnected) {
        try {
          // Try to use cached data from Firestore if available
          final document =
              await _spaces.doc(spaceId).get(GetOptions(source: Source.cache));

          if (document.exists && document.data() != null) {
            final space =
                Space.fromJson(document.data() as Map<String, dynamic>);

            // Don't cache this as a normal lookup since it's from cache
            AppLogger.i(
              'Used cached space data due to network unavailability for space',
              category: LogCategory.general,
              data: {'spaceId': spaceId},
            );

            return space;
          }
        } catch (_) {
          // If cache lookup fails, continue to the network error
        }

        throw Exception("No network connection available");
      }
    }

    DocumentSnapshot? document;
    try {
      // Get from server with a reasonable timeout
      document = await _spaces.doc(spaceId).get().timeout(
        Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException("Network request timed out");
        },
      );

      // CRITICAL: Only mark as not found if document.exists is explicitly false
      // This is the ONLY reliable way to know a space doesn't exist
      if (!document.exists) {
        // Remember this space doesn't exist to prevent repeated lookups
        _notFoundSpaceIds.add(spaceId);

        // Clean up references if user is logged in
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          cleanupMissingSpace(spaceId, user.uid);
        }

        throw Exception("Space not found! SpaceID: $spaceId");
      }

      // Convert to Space object
      final space = Space.fromJson(document.data() as Map<String, dynamic>);

      // Cache successful result
      _spaceCache[spaceId] = space;

      return space;
    } catch (e) {
      // Handle timeouts specially - don't mark as not found, allow retry
      if (e is TimeoutException) {
        AppLogger.w(
          'Network timeout when fetching space',
          category: LogCategory.network,
          data: {'spaceId': spaceId},
        );
        throw Exception("Network timeout - please try again");
      }

      // CRITICAL: If we got a document but it doesn't exist, we already handled it above
      // If we got an exception BEFORE getting the document, it's a transient error
      // NEVER mark as not found unless document.exists was explicitly false
      if (document != null && !document.exists) {
        // This case is already handled above, but just in case
        rethrow;
      }

      // NEVER mark as not found for exceptions from .get() call
      // Only mark as not found when document.exists == false (handled above)
      // For all other errors (network, Firestore, permission, etc.), treat as transient and allow retry
      AppLogger.w(
        'Transient error fetching Space (will retry on refresh)',
        category: LogCategory.general,
        data: {'spaceId': spaceId, 'error': e.toString(), 'errorType': e.runtimeType.toString()},
      );
      
      rethrow;
    }
  }

  Future<List<Space>> getAllSpaces() async {
    try {
      final querySnapshot = await _spaces.get();
      return querySnapshot.docs
          .map((doc) => Space.fromJson(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      AppLogger.e(
        'Error fetching all Spaces',
        category: LogCategory.general,
        error: e,
      );
      rethrow;
    }
  }

  Stream<List<Space>> getSpacesStream() {
    return _spaces.snapshots().map((snapshot) => snapshot.docs
        .map((doc) => Space.fromJson(doc.data() as Map<String, dynamic>))
        .toList());
  }

  Future<void> updateSpace(Space updatedSpace) async {
    try {
      await _uploadDisplayPicture(updatedSpace);
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
      AppLogger.e(
        'Error updating Space',
        category: LogCategory.general,
        error: e,
      );
      rethrow;
    }
  }

  Future<SpaceType> getSpaceType(String spaceId) async {
    try {
      Space space = await getSpace(spaceId);
      return space.spaceType;
    } catch (e) {
      AppLogger.e(
        'Error fetching Space type',
        category: LogCategory.general,
        error: e,
      );
      rethrow;
    }
  }

  Future<SpaceRoles> getSpaceRole(String spaceId, String userId) async {
    try {
      DocumentSnapshot spaceRoleDocument =
          await _spaceRoles.doc(spaceId).collection('roles').doc(userId).get();
      if (!spaceRoleDocument.exists) return SpaceRoles.none;
      String roleString = spaceRoleDocument['role'];
      return _stringToSpaceRole(roleString);
    } catch (e) {
      AppLogger.e(
        'Error fetching Space role',
        category: LogCategory.general,
        error: e,
      );
      rethrow;
    }
  }

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

  Future<bool> inviteToSpace(String spaceId, String memberId) async {
    try {
      final user = _getCurrentUser();
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
      AppLogger.e(
        'Error inviting to Space',
        category: LogCategory.general,
        error: e,
      );
      rethrow;
    }
  }

  Future<bool> addToSpace(String spaceId, String memberId) async {
    try {
      final user = _getCurrentUser();
      WriteBatch batch = _firestore.batch();

      batch.set(_spaceRoles.doc(spaceId).collection('roles').doc(memberId), {
        'role': 'member',
        'inviter': user,
        'timestamp': FieldValue.serverTimestamp(),
      });

      batch.set(_userSpaces.doc(memberId).collection('spaces').doc(spaceId), {
        'role': 'member',
        'inviter': user,
        'timestamp': FieldValue.serverTimestamp(),
      });

      await batch.commit();
      return true;
    } catch (e) {
      AppLogger.e(
        'Error adding member to Space',
        category: LogCategory.general,
        error: e,
      );
      rethrow;
    }
  }

  Future<bool> addInviteeToSpace(String spaceId, String inviter) async {
    try {
      final user = _getCurrentUser();
      SpaceRoles currRole = await getSpaceRole(spaceId, user);
      if (currRole == SpaceRoles.creator) {
        return true;
      }

      WriteBatch batch = _firestore.batch();

      batch.set(_spaceRoles.doc(spaceId).collection('roles').doc(user), {
        'role': 'member',
        'inviter': inviter,
        'timestamp': FieldValue.serverTimestamp(),
      });

      batch.set(_userSpaces.doc(user).collection('spaces').doc(spaceId), {
        'role': 'member',
        'inviter': inviter,
        'timestamp': FieldValue.serverTimestamp(),
      });

      await batch.commit();
      return true;
    } catch (e) {
      AppLogger.e(
        'Error adding invitee to Space',
        category: LogCategory.general,
        error: e,
      );
      rethrow;
    }
  }

  Future<void> removeSpaceMember(String spaceId, String memberId) async {
    try {
      WriteBatch batch = _firestore.batch();

      batch.delete(_spaceRoles.doc(spaceId).collection('roles').doc(memberId));
      batch.delete(_userSpaces.doc(memberId).collection('spaces').doc(spaceId));

      await batch.commit();
    } catch (e) {
      AppLogger.e(
        'Error removing Space member',
        category: LogCategory.database,
        error: e,
      );
      rethrow;
    }
  }

  Future<bool> deleteSpace(String spaceId) async {
    try {
      final user = _getCurrentUser();
      final spaceRole = await getSpaceRole(spaceId, user);

      if (spaceRole != SpaceRoles.creator) {
        AppLogger.i(
          'User is not the creator of this space',
          category: LogCategory.general,
          data: {'spaceId': spaceId},
        );
        return false;
      }

      WriteBatch batch = _firestore.batch();

      // Delete space document
      batch.delete(_spaces.doc(spaceId));

      // Get all users in the space
      QuerySnapshot spaceRolesDocs =
          await _spaceRoles.doc(spaceId).collection('roles').get();

      // Delete from userSpaces for users in the space
      for (var roleDoc in spaceRolesDocs.docs) {
        String userId = roleDoc.id;
        batch.delete(_userSpaces.doc(userId).collection('spaces').doc(spaceId));
      }

      // Delete space roles
      for (var roleDoc in spaceRolesDocs.docs) {
        batch.delete(roleDoc.reference);
      }

      // Delete posts in the space
      QuerySnapshot spacePosts = await _firestore
          .collection('spacePosts')
          .doc(spaceId)
          .collection('posts')
          .get();

      for (var postDoc in spacePosts.docs) {
        await _deletePostAndRepliesRecursively(postDoc.id, spaceId, batch);
      }

      // Try to delete space display picture
      try {
        await _storage.ref().child('spaces/$spaceId/displayPicture').delete();
      } catch (e) {
        AppLogger.i(
          'No display picture found for space',
          category: LogCategory.general,
          data: {'spaceId': spaceId},
        );
      }

      // Commit the batch
      await batch.commit();

      AppLogger.i(
        'Gram and all its contents deleted successfully',
        category: LogCategory.general,
        data: {'spaceId': spaceId},
      );
      return true;
    } catch (e) {
      AppLogger.e(
        'Error deleting space',
        category: LogCategory.general,
        error: e,
      );
      return false;
    }
  }

  Future<void> _deletePostAndRepliesRecursively(
      String postId, String spaceId, WriteBatch batch) async {
    // Delete the post document
    batch.delete(_firestore.collection('posts').doc(postId));

    // Delete the post from spacePosts
    batch.delete(_firestore
        .collection('spacePosts')
        .doc(spaceId)
        .collection('posts')
        .doc(postId));

    // Get all replies for this post
    QuerySnapshot postReplies = await _firestore
        .collection('postReplies')
        .doc(postId)
        .collection('replies')
        .get();

    // Recursively delete each reply
    for (var replyDoc in postReplies.docs) {
      String replyId = replyDoc.id;
      await _deletePostAndRepliesRecursively(replyId, spaceId, batch);
    }

    // Delete the postReplies document for this post
    batch.delete(_firestore.collection('postReplies').doc(postId));

    // Try to delete storage files
    try {
      await _storage.ref().child('posts/$postId/thumbnail.jpg').delete();
    } catch (e) {
      AppLogger.i(
        'No thumbnail found for post',
        category: LogCategory.general,
        data: {'postId': postId},
      );
    }
    try {
      await _storage.ref().child('posts/$postId/video.mp4').delete();
    } catch (e) {
      AppLogger.i(
        'No video found for post',
        category: LogCategory.general,
        data: {'postId': postId},
      );
    }
  }

  Future<bool> clearAllPostsInSpace(String spaceId) async {
    try {
      // Uncomment this if you want to restrict clearing posts to creators and admins
      // final user = _getCurrentUser();
      // final spaceRole = await getSpaceRole(spaceId, user);
      // if (spaceRole != SpaceRoles.creator && spaceRole != SpaceRoles.admin) {
      //   AppLogger.d('', category: LogCategory.general);
      //   return false;
      // }

      WriteBatch batch = _firestore.batch();

      // Get all posts in the space
      QuerySnapshot spacePosts = await _firestore
          .collection('spacePosts')
          .doc(spaceId)
          .collection('posts')
          .get();

      for (var postDoc in spacePosts.docs) {
        batch.delete(postDoc.reference);
        await _deletePostAndRepliesRecursively(postDoc.id, spaceId, batch);
      }

      // Commit the batch
      await batch.commit();

      AppLogger.i(
        'All posts in the space have been cleared successfully',
        category: LogCategory.general,
        data: {'spaceId': spaceId},
      );
      return true;
    } catch (e) {
      AppLogger.e(
        'Error clearing posts in space',
        category: LogCategory.general,
        error: e,
      );
      return false;
    }
  }

  Future<List<Space>> getPublicSpaces() async {
    try {
      // Query for public spaces (indices 0 and 1 for backward compat)
      final querySnapshot = await _spaces.where('spaceType',
          whereIn: [0, 1]).get();
      return querySnapshot.docs
          .map((doc) => Space.fromJson(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      AppLogger.e(
        'Error fetching public Spaces',
        category: LogCategory.general,
        error: e,
      );
      rethrow;
    }
  }

  Future<List<Space>> getUserSpaces(String userId) async {
    try {
      final userSpacesSnapshot =
          await _userSpaces.doc(userId).collection('spaces').get();
      List<Space> userSpaces = [];
      for (var doc in userSpacesSnapshot.docs) {
        Space space = await getSpace(doc.id);
        userSpaces.add(space);
      }
      return userSpaces;
    } catch (e) {
      AppLogger.e(
        'Error fetching user\'s Spaces',
        category: LogCategory.general,
        error: e,
      );
      rethrow;
    }
  }

  // Method to create a space with required memoryManager and networkManager parameters
  Future<String> createSpace({
    required String name,
    String? description,
    List<String>? memberIds,
    required MemoryManager memoryManager,
    required NetworkManager networkManager,
  }) async {
    try {
      final user = _getCurrentUser();
      final space = Space(
        name: name,
        searchName: name.toLowerCase(),
        description: description ?? '',
        spaceType: SpaceType.public,
        creatorId: user,
        adminOnlyPosting: false,
        limitedVisibility: false,
      );

      return await addSpace(space, (message) {
        AppLogger.i(
          message,
          category: LogCategory.general,
        );
      });
    } catch (e) {
      AppLogger.e(
        'Error creating Space',
        category: LogCategory.general,
        error: e,
      );
      rethrow;
    }
  }

  /// Batch validates user spaces and returns invalid space IDs
  Future<List<String>> batchValidateUserSpaces(String userId) async {
    if (userId.isEmpty) return [];

    try {
      // Get all spaces for this user
      final userSpacesSnapshot = await FirebaseFirestore.instance
          .collection('userSpaces')
          .doc(userId)
          .collection('spaces')
          .get();

      // Collect spaces to remove if invalid
      final invalidSpaces = <String>[];

      // Check each space
      for (final doc in userSpacesSnapshot.docs) {
        try {
          if (_notFoundSpaceIds.contains(doc.id)) {
            // Already know this space doesn't exist
            invalidSpaces.add(doc.id);
            continue;
          }

          // Try to fetch the space
          await getSpace(doc.id);
          // Space exists, no action needed
        } catch (e) {
          // Only mark for cleanup if we're certain the space doesn't exist
          // Don't treat transient errors (network, timeout) as invalid
          final errorString = e.toString();
          if (errorString.contains('Space not found') && 
              !errorString.contains('Network') &&
              !errorString.contains('timeout') &&
              !errorString.contains('Timeout')) {
            invalidSpaces.add(doc.id);
          }
          // For transient errors, just skip - don't mark as invalid
        }
      }

      return invalidSpaces;
    } catch (e) {
      AppLogger.e(
        'Error batch validating spaces',
        category: LogCategory.general,
        error: e,
      );
      return [];
    }
  }

  /// Batch cleanup invalid spaces for a user
  Future<void> batchCleanupInvalidSpaces(
      String userId, List<String> invalidSpaceIds) async {
    if (userId.isEmpty || invalidSpaceIds.isEmpty) return;

    try {
      AppLogger.i(
        'Cleaning up ${invalidSpaceIds.length} invalid spaces for user',
        category: LogCategory.general,
        data: {'userId': userId, 'invalidSpaceIds': invalidSpaceIds},
      );

      // Create a batch write
      final batch = FirebaseFirestore.instance.batch();

      for (final spaceId in invalidSpaceIds) {
        // Add to not found cache
        _notFoundSpaceIds.add(spaceId);

        // Remove from user's spaces collection
        final ref = FirebaseFirestore.instance
            .collection('userSpaces')
            .doc(userId)
            .collection('spaces')
            .doc(spaceId);
        batch.delete(ref);
      }

      // Execute batch deletion
      await batch.commit();
    } catch (e) {
      AppLogger.e(
        'Error batch cleaning spaces',
        category: LogCategory.general,
        error: e,
      );
    }
  }

  // Clear cache to force refresh
  void clearSpaceCache() {
    _spaceCache.clear();
  }

  // Clear cache for a specific space
  void invalidateSpaceCache(String spaceId) {
    _spaceCache.remove(spaceId);
  }

  // Clear not found cache - useful when auth state changes or on app start
  // This prevents stale "not found" entries from blocking retries
  void clearNotFoundCache() {
    _notFoundSpaceIds.clear();
  }

  /// Checks if a user is a member of a specific space.
  Future<bool> isSpaceMember(String spaceId, String userId) async {
    // Renamed from isExistsSpaceMember for clarity
    try {
      final roleDoc =
          await _spaceRoles.doc(spaceId).collection('roles').doc(userId).get();
      return roleDoc.exists;
    } catch (e, stack) {
      AppLogger.e(
          'Error checking space membership for user $userId in space $spaceId',
          category: LogCategory.database,
          error: e,
          stackTrace: stack);
      // Return false on error, as the membership status is unknown/unconfirmed
      return false;
    }
  }

  /// Adds a user to a space, determining role based on space type.
  Future<void> addSpaceMember(String spaceId, String userId) async {
    final WriteBatch batch = _firestore.batch();
    try {
      // Fetch the space details first to determine the type
      final Space space = await getSpace(spaceId);

      String role = 'requested'; // Default role for private/invite-only spaces

      // Determine role based on space type
      // Public spaces allow direct join as member
      if (isPublicSpaceType(space.spaceType)) {
        role = 'member';
      }

      // Set role in spaceRoles subcollection
      final spaceRoleRef =
          _spaceRoles.doc(spaceId).collection('roles').doc(userId);
      batch.set(spaceRoleRef, {
        'role': role,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Set role in userSpaces subcollection
      final userSpaceRef =
          _userSpaces.doc(userId).collection('spaces').doc(spaceId);
      batch.set(userSpaceRef, {
        'role': role,
        'timestamp': FieldValue.serverTimestamp(),
        'spaceType': space.spaceType.index, // Store enum index for consistency
        'adminOnlyPosting': space.adminOnlyPosting,
        'limitedVisibility': space.limitedVisibility,
      });

      await batch.commit();
      AppLogger.i('Added member $userId to space $spaceId with role $role',
          category: LogCategory.database);

      // Track joins only for the current user (avoid admin actions)
      if (FirebaseAuth.instance.currentUser?.uid == userId) {
        AnalyticsService().trackSpaceJoined(spaceId: spaceId, role: role);
      }
    } catch (e, stack) {
      AppLogger.e('Error adding member $userId to space $spaceId',
          category: LogCategory.database, error: e, stackTrace: stack);
      // Rethrow a specific exception
      throw Exception(
          'Failed to add member $userId to space $spaceId: ${e.toString()}');
    }
  }

  /// Promotes a user to admin within a space.
  Future<void> makeAdmin(String spaceId, String userId) async {
    final WriteBatch batch = _firestore.batch();
    try {
      final spaceRoleRef =
          _spaceRoles.doc(spaceId).collection('roles').doc(userId);

      // Check current role first (requires a read before batch)
      DocumentSnapshot roleDoc = await spaceRoleRef.get();

      if (!roleDoc.exists) {
        AppLogger.w(
            'User $userId not a member of space $spaceId, cannot make admin',
            category: LogCategory.database);
        throw Exception('User is not a member of this space');
      }

      String currentRole = (roleDoc.data() as Map<String, dynamic>)['role'];
      if (currentRole == 'admin' || currentRole == 'creator') {
        AppLogger.i('User $userId is already $currentRole in space $spaceId',
            category: LogCategory.database);
        return; // No change needed, operation successful
      }

      // Update role in spaceRoles
      batch.update(spaceRoleRef, {
        'role': 'admin',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update role in userSpaces
      final userSpaceRef =
          _userSpaces.doc(userId).collection('spaces').doc(spaceId);
      batch.update(userSpaceRef, {
        'role': 'admin',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
      AppLogger.i('Made user $userId admin in space $spaceId',
          category: LogCategory.database);
    } catch (e, stack) {
      AppLogger.e('Error making user $userId admin in space $spaceId',
          category: LogCategory.database, error: e, stackTrace: stack);
      // Rethrow a specific exception
      throw Exception(
          'Failed to make user $userId admin in space $spaceId: ${e.toString()}');
    }
  }

  /// Gets a stream of space roles/references for a specific user.
  Stream<QuerySnapshot> getSpacesByUserStream(String userId) {
    // Directly return the stream from the userSpaces collection
    return _userSpaces
        .doc(userId)
        .collection('spaces')
        .orderBy('timestamp', descending: true)
        .snapshots();
    // Note: Error handling for streams is typically done in the listener (StreamBuilder/Consumer)
  }

  /// Gets a list of space roles/references for a specific user once.
  Future<List<QueryDocumentSnapshot>> getSpacesByUser(String userId) async {
    try {
      final querySnapshot = await _userSpaces
          .doc(userId)
          .collection('spaces')
          .orderBy('timestamp', descending: true)
          .get();
      return querySnapshot.docs;
    } catch (e, stack) {
      AppLogger.e('Error fetching spaces for user $userId',
          category: LogCategory.database, error: e, stackTrace: stack);
      // Rethrow a specific exception or return empty list based on desired behavior
      throw Exception(
          'Failed to fetch spaces for user $userId: ${e.toString()}');
      // return []; // Alternative: return empty list on error
    }
  }
}
