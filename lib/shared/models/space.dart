import 'package:aurogram/shared/models/space_types.dart';

/// Space model for the app.
/// A Space represents a group/community where users can post content.
///
/// NOTE: Profile grams have been removed from the architecture.
/// User profiles are now separate from spaces - profiles have followers,
/// spaces have members. This is cleaner and more scalable.
class Space {
  String? id;
  String? name;
  String? searchName;
  SpaceType spaceType;
  String? description;
  String? displayPicture;
  String? creatorId;
  bool adminOnlyPosting;
  bool limitedVisibility;

  Space({
    this.id,
    required this.name,
    required this.searchName,
    required this.spaceType,
    this.description,
    this.displayPicture,
    this.creatorId,
    this.adminOnlyPosting = false,
    this.limitedVisibility = false,
  });

  factory Space.fromJson(Map<String, dynamic> json) {
    // Handle legacy spaceType indices and normalize
    final rawSpaceType = json['spaceType'] ?? json['farmType'] ?? 1;
    final spaceType = spaceTypeFromIndex(rawSpaceType);

    return Space(
      id: json['id'],
      name: json['name'],
      searchName: json['searchName'],
      spaceType: normalizeSpaceType(spaceType),
      description: json['description'],
      displayPicture: json['displayPicture'],
      creatorId: json['creatorId'],
      adminOnlyPosting: json['adminOnlyPosting'] ?? false,
      limitedVisibility: json['limitedVisibility'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'searchName': searchName,
      'spaceType': spaceType.index,
      'description': description,
      'displayPicture': displayPicture,
      'creatorId': creatorId,
      'adminOnlyPosting': adminOnlyPosting,
      'limitedVisibility': limitedVisibility,
    };
  }

  /// Check if this is a public space
  bool get isPublic => isPublicSpaceType(spaceType);

  /// Check if this is a private space
  bool get isPrivate => isPrivateSpaceType(spaceType);
}

/// Backward compatibility aliases
typedef Farm = Space;
typedef Gram = Space;
