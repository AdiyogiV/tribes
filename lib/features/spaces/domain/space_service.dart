import 'dart:async';
import 'package:flutter/foundation.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:aurogram/shared/models/space_roles.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:aurogram/shared/models/space_types.dart';
import 'package:aurogram/shared/models/space.dart';
import 'package:aurogram/core/storage/memory_manager.dart';
import 'package:aurogram/core/network/network_manager.dart';
import 'package:aurogram/core/logging/app_logger.dart';
import 'package:aurogram/shared/services/analytics_service.dart';

import 'package:aurogram/platform/file_helper.dart' as file_helper;

part 'space/_space_crud.dart';
part 'space/_space_members.dart';
part 'space/_space_delete.dart';
part 'space/_space_query.dart';

typedef ProgressCallback = void Function(String message);

class SpaceService {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final FirebaseStorage storage = FirebaseStorage.instance;
  final CollectionReference spaces;
  final CollectionReference userSpaces;
  final CollectionReference spaceRoles;

  SpaceService()
      : spaces = FirebaseFirestore.instance.collection('spaces'),
        userSpaces = FirebaseFirestore.instance.collection('userSpaces'),
        spaceRoles = FirebaseFirestore.instance.collection('spaceRoles');

  String getCurrentUser() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("User not authenticated!");
    return user.uid;
  }

  /// Upload space display picture - handles both path (mobile) and bytes (web)
  Future<void> uploadDisplayPicture(Space space,
      {Uint8List? imageBytes}) async {
    if (imageBytes == null &&
        (space.displayPicture == null || space.displayPicture!.isEmpty)) {
      return;
    }

    final storageRef =
        storage.ref().child('spaces/${space.id}/displayPicture');

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

  /// Add space with image bytes (for web)
  Future<String> addSpaceWithBytes(
      Space space, Uint8List? imageBytes, ProgressCallback progress) async {
    final user = getCurrentUser();
    final WriteBatch batch = firestore.batch();
    final spaceRef = spaces.doc();

    try {
      space.id = spaceRef.id;
      space.creatorId = user;
      progress("Uploading image...");
      await uploadDisplayPicture(space, imageBytes: imageBytes);
      progress("Saving group details...");

      batch.set(spaceRef, space.toJson());

      // Add creator to space members
      final memberRef =
          spaces.doc(space.id).collection('members').doc(user);
      batch.set(memberRef, {
        'userId': user,
        'joinedAt': Timestamp.now(),
        'role': 'admin',
      });

      // Add to user's spaces
      final userSpaceRef =
          userSpaces.doc(user).collection('spaces').doc(space.id);
      batch.set(userSpaceRef, {
        'spaceId': space.id,
        'joinedAt': Timestamp.now(),
        'role': 'admin',
      });

      // Add space role for creator
      final roleRef = spaceRoles.doc(space.id);
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
    final user = getCurrentUser();
    final WriteBatch batch = firestore.batch();
    final spaceRef = spaces.doc();

    try {
      space.id = spaceRef.id;
      space.creatorId = user;
      progress("Uploading image...");
      await uploadDisplayPicture(space);
      progress("Saving group details...");

      batch.set(spaceRef, space.toJson());

      final userSpaceData = {
        'spaceType': space.spaceType.index,
        'role': 'creator',
        'timestamp': FieldValue.serverTimestamp(),
        'adminOnlyPosting': space.adminOnlyPosting,
        'limitedVisibility': space.limitedVisibility,
      };

      batch.set(
          userSpaces.doc(user).collection('spaces').doc(spaceRef.id),
          userSpaceData);

      final spaceRoleData = {
        'role': 'creator',
        'timestamp': FieldValue.serverTimestamp(),
      };
      batch.set(
          spaceRoles.doc(spaceRef.id).collection('roles').doc(user),
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
  final Set<String> notFoundSpaceIds = {};

  // Cache of successfully retrieved spaces
  final Map<String, Space> spaceCache = {};

  /// Clean up references to missing spaces for a user
  Future<void> cleanupMissingSpace(String spaceId, String userId) async {
    try {
      // Mark as not found to avoid future lookups
      notFoundSpaceIds.add(spaceId);

      // Remove from user's spaces collection
      await userSpaces
          .doc(userId)
          .collection('spaces')
          .doc(spaceId)
          .delete();

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
    if (spaceCache.containsKey(spaceId)) {
      return spaceCache[spaceId]!;
    }

    // Check if we already know this space doesn't exist
    if (notFoundSpaceIds.contains(spaceId)) {
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
          final document = await spaces
              .doc(spaceId)
              .get(GetOptions(source: Source.cache));

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
      document = await spaces.doc(spaceId).get().timeout(
        Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException("Network request timed out");
        },
      );

      // CRITICAL: Only mark as not found if document.exists is explicitly false
      // This is the ONLY reliable way to know a space doesn't exist
      if (!document.exists) {
        // Remember this space doesn't exist to prevent repeated lookups
        notFoundSpaceIds.add(spaceId);

        // Clean up references if user is logged in
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          cleanupMissingSpace(spaceId, user.uid);
        }

        throw Exception("Space not found! SpaceID: $spaceId");
      }

      // Convert to Space object
      final space =
          Space.fromJson(document.data() as Map<String, dynamic>);

      // Cache successful result
      spaceCache[spaceId] = space;

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
        data: {
          'spaceId': spaceId,
          'error': e.toString(),
          'errorType': e.runtimeType.toString()
        },
      );

      rethrow;
    }
  }
}
