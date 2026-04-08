import 'package:flutter/material.dart';

/// SpaceType enum - Simplified to just public and private
///
/// Note: Enum indices are preserved for backward compatibility with Firestore data:
/// - Index 0: Legacy 'open' → treated as public
/// - Index 1: public - Anyone can find and join
/// - Index 2: private - Invite only, content hidden from non-members
/// - Index 3: Legacy 'personal' → deprecated (profile posts now use contextType='profile')
enum SpaceType {
  // Keep indices stable for backward compatibility with existing Firestore data
  // Index 0 - legacy 'open', now treated as public
  @Deprecated('Use SpaceType.public instead')
  open,

  // Index 1 - public groups
  public,

  // Index 2 - private groups
  private,

  // Index 3 - legacy 'personal', deprecated (profile posts use contextType='profile' instead)
  @Deprecated('Profile posts now use Post.contextType=profile instead')
  personal,
}

/// Backward compatibility aliases
typedef FarmType = SpaceType;
typedef GramType = SpaceType;

/// Check if a space type is private
bool isPrivateSpaceType(SpaceType type) {
  return type == SpaceType.private;
}

/// Check if a space type is public (includes legacy open and personal)
bool isPublicSpaceType(SpaceType type) {
  // ignore: deprecated_member_use_from_same_package
  return type == SpaceType.open ||
      type == SpaceType.public ||
      // ignore: deprecated_member_use_from_same_package
      type == SpaceType.personal;
}

/// Normalize legacy space types to current types
/// Use this when reading from Firestore to handle legacy data
SpaceType normalizeSpaceType(SpaceType type) {
  switch (type) {
    // ignore: deprecated_member_use_from_same_package
    case SpaceType.open:
      return SpaceType.public;
    // ignore: deprecated_member_use_from_same_package
    case SpaceType.personal:
      return SpaceType.public;
    case SpaceType.public:
    case SpaceType.private:
      return type;
  }
}

/// Get SpaceType from index with backward compatibility
SpaceType spaceTypeFromIndex(int index) {
  if (index < 0 || index >= SpaceType.values.length) {
    return SpaceType.public; // Default to public for invalid indices
  }
  return SpaceType.values[index];
}

Color getColorFromSpaceType(SpaceType type) {
  if (isPrivateSpaceType(type)) {
    return Colors.purple;
  }
  return Colors.blue;
}

/// Backward compatibility functions
Color getColorFromFarmType(SpaceType type) => getColorFromSpaceType(type);
Color getColorFromGramType(SpaceType type) => getColorFromSpaceType(type);

/// Get display name for SpaceType
String getSpaceTypeName(SpaceType type) {
  if (isPrivateSpaceType(type)) {
    return 'Private';
  }
  return 'Public';
}

/// Backward compatibility functions
String getFarmTypeName(SpaceType type) => getSpaceTypeName(type);
String getGramTypeName(SpaceType type) => getSpaceTypeName(type);

/// Get description for SpaceType
String getSpaceTypeDescription(SpaceType type) {
  if (isPrivateSpaceType(type)) {
    return 'Invite only - content visible to members';
  }
  return 'Anyone can find and join this gram';
}

/// Backward compatibility functions
String getFarmTypeDescription(SpaceType type) => getSpaceTypeDescription(type);
String getGramTypeDescription(SpaceType type) => getSpaceTypeDescription(type);
