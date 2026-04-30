import 'dart:async';
import 'package:flutter/foundation.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:aurogram/shared/models/space_roles.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:aurogram/shared/models/space.dart';
import 'package:aurogram/core/logging/app_logger.dart';
import 'package:aurogram/shared/services/analytics_service.dart';

import 'package:aurogram/platform/file_helper.dart' as file_helper;

export 'space/_space_crud.dart';
export 'space/_space_members.dart';
export 'space/_space_delete.dart';
export 'space/_space_query.dart';

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

    // Check in-memory cache for successful lookups first.
    if (spaceCache.containsKey(spaceId)) {
      return spaceCache[spaceId]!;
    }

    // Check if we already know this space doesn't exist.
    if (notFoundSpaceIds.contains(spaceId)) {
      throw Exception("Space not found! SpaceID: $spaceId (cached)");
    }

    // Stale-while-revalidate: try Firestore's local persistence cache
    // FIRST. This is essentially free (~1ms) and lets us render the gram
    // immediately even when the network is slow / App Check is throttling.
    // We then kick off a server refresh in the background so the next
    // lookup sees fresh data.
    try {
      final cachedDoc = await spaces
          .doc(spaceId)
          .get(const GetOptions(source: Source.cache));
      if (cachedDoc.exists && cachedDoc.data() != null) {
        final space =
            Space.fromJson(cachedDoc.data() as Map<String, dynamic>);
        spaceCache[spaceId] = space;
        // Background refresh — don't await; failures are silent because the
        // user already has data.
        unawaited(_refreshSpaceFromServer(spaceId));
        return space;
      }
    } catch (_) {
      // Cache miss / persistence disabled — fall through to server fetch.
    }

    // Cache miss: must hit the server. Use a shorter timeout (5s) so a
    // single slow space doesn't gate the whole UI for 10 full seconds when
    // App Check or the network is misbehaving.
    DocumentSnapshot? document;
    try {
      document = await spaces.doc(spaceId).get().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          throw TimeoutException("Network request timed out");
        },
      );

      // CRITICAL: Only mark as not found if document.exists is explicitly false.
      if (!document.exists) {
        notFoundSpaceIds.add(spaceId);
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          cleanupMissingSpace(spaceId, user.uid);
        }
        throw Exception("Space not found! SpaceID: $spaceId");
      }

      final space =
          Space.fromJson(document.data() as Map<String, dynamic>);
      spaceCache[spaceId] = space;
      return space;
    } catch (e) {
      if (e is TimeoutException) {
        AppLogger.w(
          'Network timeout when fetching space',
          category: LogCategory.network,
          data: {'spaceId': spaceId},
        );
        throw Exception("Network timeout - please try again");
      }
      // Never mark as not found for transient errors.
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

  /// Background refresh used by the stale-while-revalidate path in
  /// [getSpace]. Updates [spaceCache] silently when newer data arrives.
  Future<void> _refreshSpaceFromServer(String spaceId) async {
    try {
      final doc = await spaces
          .doc(spaceId)
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 8));
      if (doc.exists && doc.data() != null) {
        spaceCache[spaceId] =
            Space.fromJson(doc.data() as Map<String, dynamic>);
      } else if (doc.metadata.isFromCache == false) {
        // Server explicitly said it doesn't exist.
        notFoundSpaceIds.add(spaceId);
        spaceCache.remove(spaceId);
      }
    } catch (_) {
      // Silent — user already has cached data; we'll retry next lookup.
    }
  }
}
