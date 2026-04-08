part of '../space_service.dart';

/// Extension on [SpaceService] for querying, validation, cache management, and streams.
extension SpaceQuery on SpaceService {
  Future<List<Space>> getPublicSpaces() async {
    try {
      // Query for public spaces (indices 0 and 1 for backward compat)
      final querySnapshot =
          await spaces.where('spaceType', whereIn: [0, 1]).get();
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
          await userSpaces.doc(userId).collection('spaces').get();
      List<Space> result = [];
      for (var doc in userSpacesSnapshot.docs) {
        Space space = await getSpace(doc.id);
        result.add(space);
      }
      return result;
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
      final user = getCurrentUser();
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
          if (notFoundSpaceIds.contains(doc.id)) {
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
        notFoundSpaceIds.add(spaceId);

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
    spaceCache.clear();
  }

  // Clear cache for a specific space
  void invalidateSpaceCache(String spaceId) {
    spaceCache.remove(spaceId);
  }

  // Clear not found cache - useful when auth state changes or on app start
  // This prevents stale "not found" entries from blocking retries
  void clearNotFoundCache() {
    notFoundSpaceIds.clear();
  }

  /// Gets a stream of space roles/references for a specific user.
  Stream<QuerySnapshot> getSpacesByUserStream(String userId) {
    // Directly return the stream from the userSpaces collection
    return userSpaces
        .doc(userId)
        .collection('spaces')
        .orderBy('timestamp', descending: true)
        .snapshots();
    // Note: Error handling for streams is typically done in the listener (StreamBuilder/Consumer)
  }

  /// Gets a list of space roles/references for a specific user once.
  Future<List<QueryDocumentSnapshot>> getSpacesByUser(String userId) async {
    try {
      final querySnapshot = await userSpaces
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
