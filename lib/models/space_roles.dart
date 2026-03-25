/// SpaceRoles enum
/// Defines the different roles a user can have in a Space
enum SpaceRoles { admin, creator, requested, owner, member, invited, none }

/// Backward compatibility aliases
typedef FarmRoles = SpaceRoles;
typedef GramRoles = SpaceRoles;
