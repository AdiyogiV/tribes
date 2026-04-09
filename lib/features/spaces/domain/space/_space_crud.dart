import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:aurogram/shared/models/space_roles.dart';
import 'package:aurogram/shared/models/space_types.dart';
import 'package:aurogram/shared/models/space.dart';
import 'package:aurogram/core/logging/app_logger.dart';

import '../space_service.dart';

/// Extension on [SpaceService] for basic CRUD operations (read, update, query types/roles).
extension SpaceCrud on SpaceService {
  Future<List<Space>> getAllSpaces() async {
    try {
      final querySnapshot = await spaces.get();
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
    return spaces.snapshots().map((snapshot) => snapshot.docs
        .map((doc) => Space.fromJson(doc.data() as Map<String, dynamic>))
        .toList());
  }

  Future<void> updateSpace(Space updatedSpace) async {
    try {
      await uploadDisplayPicture(updatedSpace);
      await spaces.doc(updatedSpace.id).update(updatedSpace.toJson());

      // Update userSpaces collection for all members
      QuerySnapshot membersSnapshot =
          await spaceRoles.doc(updatedSpace.id).collection('roles').get();

      WriteBatch batch = firestore.batch();
      for (var doc in membersSnapshot.docs) {
        String userId = doc.id;
        batch.update(
          userSpaces.doc(userId).collection('spaces').doc(updatedSpace.id),
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
          await spaceRoles.doc(spaceId).collection('roles').doc(userId).get();
      if (!spaceRoleDocument.exists) return SpaceRoles.none;
      String roleString = spaceRoleDocument['role'];
      return stringToSpaceRole(roleString);
    } catch (e) {
      AppLogger.e(
        'Error fetching Space role',
        category: LogCategory.general,
        error: e,
      );
      rethrow;
    }
  }

  SpaceRoles stringToSpaceRole(String roleString) {
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
}
