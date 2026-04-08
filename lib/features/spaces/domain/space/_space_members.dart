part of '../space_service.dart';

/// Extension on [SpaceService] for member management (invite, add, remove, promote).
extension SpaceMembers on SpaceService {
  Future<bool> inviteToSpace(String spaceId, String memberId) async {
    try {
      final user = getCurrentUser();
      WriteBatch batch = firestore.batch();

      batch.set(spaceRoles.doc(spaceId).collection('roles').doc(memberId), {
        'role': 'invited',
        'inviter': user,
        'timestamp': FieldValue.serverTimestamp(),
      });

      batch.set(userSpaces.doc(memberId).collection('spaces').doc(spaceId), {
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
      final user = getCurrentUser();
      WriteBatch batch = firestore.batch();

      batch.set(spaceRoles.doc(spaceId).collection('roles').doc(memberId), {
        'role': 'member',
        'inviter': user,
        'timestamp': FieldValue.serverTimestamp(),
      });

      batch.set(userSpaces.doc(memberId).collection('spaces').doc(spaceId), {
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
      final user = getCurrentUser();
      SpaceRoles currRole = await getSpaceRole(spaceId, user);
      if (currRole == SpaceRoles.creator) {
        return true;
      }

      WriteBatch batch = firestore.batch();

      batch.set(spaceRoles.doc(spaceId).collection('roles').doc(user), {
        'role': 'member',
        'inviter': inviter,
        'timestamp': FieldValue.serverTimestamp(),
      });

      batch.set(userSpaces.doc(user).collection('spaces').doc(spaceId), {
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
      WriteBatch batch = firestore.batch();

      batch.delete(spaceRoles.doc(spaceId).collection('roles').doc(memberId));
      batch.delete(userSpaces.doc(memberId).collection('spaces').doc(spaceId));

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

  /// Checks if a user is a member of a specific space.
  Future<bool> isSpaceMember(String spaceId, String userId) async {
    // Renamed from isExistsSpaceMember for clarity
    try {
      final roleDoc =
          await spaceRoles.doc(spaceId).collection('roles').doc(userId).get();
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
    final WriteBatch batch = firestore.batch();
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
          spaceRoles.doc(spaceId).collection('roles').doc(userId);
      batch.set(spaceRoleRef, {
        'role': role,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Set role in userSpaces subcollection
      final userSpaceRef =
          userSpaces.doc(userId).collection('spaces').doc(spaceId);
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
    final WriteBatch batch = firestore.batch();
    try {
      final spaceRoleRef =
          spaceRoles.doc(spaceId).collection('roles').doc(userId);

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
          userSpaces.doc(userId).collection('spaces').doc(spaceId);
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
}
