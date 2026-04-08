import 'package:flutter/cupertino.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:aurogram/features/profile/presentation/pages/user_profile.dart';
import 'package:aurogram/features/spaces/presentation/pages/space_screen.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/core/theme/header_style.dart';
import 'package:aurogram/core/di/injection.dart';
import 'package:aurogram/features/profile/domain/user_service.dart';
import 'package:aurogram/shared/services/batch_data_loader.dart';
import 'package:aurogram/core/logging/app_logger.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';

/// Cache for user and space data to prevent constant refreshes
class _HeaderCache {
  static final Map<String, Map<String, dynamic>> _userCache = {};
  static final Map<String, Map<String, dynamic>> _spaceCache = {};
  static final Map<String, DateTime> _userTimestamps = {};
  static final Map<String, DateTime> _spaceTimestamps = {};
  static const Duration _cacheExpiry = Duration(minutes: 15);

  static Future<Map<String, dynamic>?> getUser(String uid) async {
    // Check cache first
    if (_userCache.containsKey(uid)) {
      final timestamp = _userTimestamps[uid];
      if (timestamp != null &&
          DateTime.now().difference(timestamp) < _cacheExpiry) {
        return _userCache[uid];
      }
    }

    // Fetch from Firestore (user profiles are public, readable when logged out)
    try {
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists) {
        final data = doc.data() ?? {};
        _userCache[uid] = data;
        _userTimestamps[uid] = DateTime.now();
        return data;
      } else {
        // User doesn't exist, check if deleted (only if authenticated)
        try {
          final currentUser = FirebaseAuth.instance.currentUser;
          if (currentUser != null) {
            final deletedDoc = await FirebaseFirestore.instance
                .collection('deletedUsers')
                .doc(uid)
                .get();
            if (deletedDoc.exists) {
              // Return deleted user data
              final deletedData = {
                'name': 'Deleted User',
                'displayName': 'Deleted User'
              };
              _userCache[uid] = deletedData;
              _userTimestamps[uid] = DateTime.now();
              return deletedData;
            }
          }
        } catch (e) {
          // Error checking deletedUsers - don't assume deleted
        }
      }
    } catch (e) {
      // On error, check cache as fallback
      if (_userCache.containsKey(uid)) {
        final cachedData = _userCache[uid]!;
        // Don't return "Deleted User" from cache unless we're sure
        if (cachedData['name'] != 'Deleted User' &&
            cachedData['displayName'] != 'Deleted User') {
          return cachedData;
        }
      }
    }
    return null;
  }

  static Future<Map<String, dynamic>?> getSpace(String spaceId) async {
    // Check cache first
    if (_spaceCache.containsKey(spaceId)) {
      final timestamp = _spaceTimestamps[spaceId];
      if (timestamp != null &&
          DateTime.now().difference(timestamp) < _cacheExpiry) {
        return _spaceCache[spaceId];
      }
    }

    // Fetch from Firestore
    try {
      final doc = await FirebaseFirestore.instance
          .collection('spaces')
          .doc(spaceId)
          .get();
      if (doc.exists) {
        final data = doc.data() ?? {};
        _spaceCache[spaceId] = data;
        _spaceTimestamps[spaceId] = DateTime.now();
        return data;
      }
    } catch (_) {
      AppLogger.w('PostHeader: failed to fetch space data', category: LogCategory.general);
    }
    return null;
  }

  /// Get cached data synchronously (returns null if not cached)
  static Map<String, dynamic>? getCachedUser(String uid) {
    if (_userCache.containsKey(uid)) {
      final timestamp = _userTimestamps[uid];
      if (timestamp != null &&
          DateTime.now().difference(timestamp) < _cacheExpiry) {
        return _userCache[uid];
      }
    }
    return null;
  }

  static Map<String, dynamic>? getCachedSpace(String spaceId) {
    if (_spaceCache.containsKey(spaceId)) {
      final timestamp = _spaceTimestamps[spaceId];
      if (timestamp != null &&
          DateTime.now().difference(timestamp) < _cacheExpiry) {
        return _spaceCache[spaceId];
      }
    }
    return null;
  }
}

/// Instagram-style post header: [Avatar] [Username · Gram] [Label?] [•••]
/// No time in header (time shown below caption in post body).
/// [onMoreTap] when set shows three-dots on the right (Instagram-style).
///
/// OPTIMIZATION V2: Hybrid approach for maximum performance
/// - When userData/spaceData provided: instant render (FAST PATH)
/// - When not provided: async fetch with caching (FALLBACK)
/// - This maintains backward compatibility while enabling batch loading
class PostHeader extends StatelessWidget {
  final String? uid;
  final String? space;
  final Timestamp? timestamp;
  final String? label;
  final Color? labelColor;
  final bool isProfilePost; // When true, hide the space/gram name
  final VoidCallback? onMoreTap;

  // NEW: Optional pre-loaded data for fast path (batch loaded in Post widget)
  final UserData? userData;
  final SpaceData? spaceData;

  const PostHeader({
    super.key,
    this.uid,
    this.space,
    this.timestamp,
    this.label,
    this.labelColor,
    this.isProfilePost = false,
    this.onMoreTap,
    this.userData,
    this.spaceData,
  });

  static const double _avatarSize = 40.0;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      child: Row(
        children: [
          // Avatar (Instagram: smaller, left)
          GestureDetector(
            onTap: () => _navigateToProfile(context),
            child: _UserAvatar(uid: uid, size: _avatarSize, userData: userData),
          ),

          const SizedBox(width: AppDimensions.spacingMd),

          // Username + Gram (left-aligned, single line or two)
          Expanded(
            child: GestureDetector(
              onTap: () => _navigateToProfile(context),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _UserName(uid: uid, userData: userData),
                  if (!isProfilePost && space != null && space!.isNotEmpty) ...[
                    const SizedBox(height: AppDimensions.spacingXxs),
                    GestureDetector(
                      onTap: () => _navigateToSpace(context),
                      child: _SpaceName(spaceId: space!, spaceData: spaceData),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Label badge (REPLY, ORIGINAL)
          if (label != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                color: (labelColor ?? AppTheme.primaryColor)
                    .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
              ),
              child: Text(
                label!,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                  color: labelColor ?? AppTheme.primaryColor,
                ),
              ),
            ),

          // Three dots (Instagram-style) - right side of header
          if (onMoreTap != null) ...[
            if (label != null) const SizedBox(width: AppDimensions.spacingSm),
            GestureDetector(
              onTap: onMoreTap,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: Icon(
                  CupertinoIcons.ellipsis,
                  size: AppHeaderStyle.headerIconSize,
                  color: AppTheme.primaryColor,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _navigateToProfile(BuildContext context) {
    if (uid == null) return;
    Navigator.of(context).push(
      CupertinoPageRoute(builder: (_) => UserProfilePage(uid: uid)),
    );
  }

  void _navigateToSpace(BuildContext context) {
    if (space == null) return;
    Navigator.of(context).push(
      CupertinoPageRoute(builder: (_) => SpaceScreen(rid: space!)),
    );
  }
}

/// User avatar with caching - OPTIMIZED with fast path for pre-loaded data
class _UserAvatar extends StatefulWidget {
  final String? uid;
  final double size;
  final UserData? userData; // NEW: Fast path when data pre-loaded

  const _UserAvatar({required this.uid, required this.size, this.userData});

  @override
  State<_UserAvatar> createState() => _UserAvatarState();
}

class _UserAvatarState extends State<_UserAvatar> {
  String? _photoUrl;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadAvatar();
  }

  @override
  void didUpdateWidget(_UserAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);

    // CRITICAL: Only reload if uid actually changed
    // This prevents rebuilds when parent Post rebuilds but uid is the same
    if (oldWidget.uid != widget.uid || oldWidget.userData != widget.userData) {
      _loadAvatar();
    }
  }

  void _loadAvatar() {
    if (widget.uid == null) {
      setState(() => _loaded = true);
      return;
    }

    // FAST PATH: Use pre-loaded data if available (instant, no async!)
    if (widget.userData != null) {
      _photoUrl = widget.userData!.photoUrl;
      _loaded = true;
      if (mounted) setState(() {});
      return;
    }

    // FALLBACK: Check cache first (synchronous)
    final cached = _HeaderCache.getCachedUser(widget.uid!);
    if (cached != null) {
      _photoUrl = cached['displayPicture'] as String?;
      _loaded = true;
      if (mounted) setState(() {});
      return;
    }

    // FALLBACK: Load from Firestore (async)
    _HeaderCache.getUser(widget.uid!).then((data) {
      if (mounted) {
        setState(() {
          _photoUrl = data?['displayPicture'] as String?;
          _loaded = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.uid == null || !_loaded) {
      return _placeholder();
    }

    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppTheme.primaryColor.withValues(alpha: 0.1),
      ),
      child: ClipOval(
        child: _photoUrl != null && _photoUrl!.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: _photoUrl!,
                fit: BoxFit.cover,
                width: widget.size,
                height: widget.size,
                placeholder: (_, __) => _avatarIcon(),
                errorWidget: (_, __, ___) => _avatarIcon(),
                fadeInDuration: const Duration(milliseconds: 150),
                fadeOutDuration: const Duration(milliseconds: 150),
              )
            : _avatarIcon(),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppTheme.primaryColor.withValues(alpha: 0.1),
      ),
      child: _avatarIcon(),
    );
  }

  Widget _avatarIcon() {
    return Icon(
      CupertinoIcons.person_fill,
      size: widget.size * 0.5,
      color: AppTheme.primaryColor.withValues(alpha: 0.5),
    );
  }
}

/// User name with caching - OPTIMIZED with fast path for pre-loaded data
class _UserName extends StatefulWidget {
  final String? uid;
  final UserData? userData; // NEW: Fast path when data pre-loaded

  const _UserName({required this.uid, this.userData});

  @override
  State<_UserName> createState() => _UserNameState();
}

class _UserNameState extends State<_UserName> {
  String _name = 'User';

  @override
  void initState() {
    super.initState();
    _loadName();
  }

  @override
  void didUpdateWidget(_UserName oldWidget) {
    super.didUpdateWidget(oldWidget);

    // CRITICAL: Only reload if uid actually changed
    // This prevents rebuilds when parent Post rebuilds but uid is the same
    if (oldWidget.uid != widget.uid || oldWidget.userData != widget.userData) {
      _loadName();
    }
  }

  void _loadName() {
    if (widget.uid == null) {
      setState(() {
        _name = 'Unknown';
      });
      return;
    }

    // FAST PATH: Use pre-loaded data if available (instant, no async!)
    if (widget.userData != null) {
      _name = widget.userData!.displayName;
      if (mounted) setState(() {});
      return;
    }

    // FALLBACK: Check cache first (synchronous) - use HeaderCache for avatar data
    final cached = _HeaderCache.getCachedUser(widget.uid!);
    if (cached != null) {
      _name = cached['displayName'] as String? ??
          cached['name'] as String? ??
          'User';
      if (mounted) setState(() {});
      return;
    }

    // FALLBACK: Use UserService.getUserDisplayName for consistent name fetching
    // This handles deleted users correctly and works when logged out
    final userService = locator<UserService>();
    userService.getUserDisplayName(widget.uid!).then((name) {
      if (mounted) {
        setState(() {
          _name = name;
        });
      }
    }).catchError((e) {
      AppLogger.w('Error loading user name in postHeader',
          category: LogCategory.ui,
          data: {'userId': widget.uid, 'error': e.toString()});
      // On error, check if we have cached data to preserve name
      final cached = _HeaderCache.getCachedUser(widget.uid!);
      if (mounted) {
        setState(() {
          // Use cached name if available, otherwise generic fallback
          _name = cached?['displayName'] as String? ??
              cached?['name'] as String? ??
              'User';
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _name,
      style: _textStyle,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  TextStyle get _textStyle => TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: AppTheme.primaryColor,
      );
}

/// Space name with caching - OPTIMIZED with fast path for pre-loaded data
class _SpaceName extends StatefulWidget {
  final String spaceId;
  final SpaceData? spaceData; // NEW: Fast path when data pre-loaded

  const _SpaceName({required this.spaceId, this.spaceData});

  @override
  State<_SpaceName> createState() => _SpaceNameState();
}

class _SpaceNameState extends State<_SpaceName> {
  String _name = 'Gram';

  @override
  void initState() {
    super.initState();
    _loadName();
  }

  @override
  void didUpdateWidget(_SpaceName oldWidget) {
    super.didUpdateWidget(oldWidget);

    // CRITICAL: Only reload if spaceId actually changed
    // This prevents rebuilds when parent Post rebuilds but spaceId is the same
    if (oldWidget.spaceId != widget.spaceId ||
        oldWidget.spaceData != widget.spaceData) {
      _loadName();
    }
  }

  void _loadName() {
    // FAST PATH: Use pre-loaded data if available (instant, no async!)
    if (widget.spaceData != null) {
      _name = widget.spaceData!.name;
      if (mounted) setState(() {});
      return;
    }

    // FALLBACK: Check cache first (synchronous)
    final cached = _HeaderCache.getCachedSpace(widget.spaceId);
    if (cached != null) {
      _name = cached['name'] as String? ?? 'Gram';
      if (mounted) setState(() {});
      return;
    }

    // FALLBACK: Load from Firestore (async)
    _HeaderCache.getSpace(widget.spaceId).then((data) {
      if (mounted) {
        setState(() {
          _name = data?['name'] as String? ?? 'Gram';
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _name,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: AppTheme.primaryColor.withValues(alpha: 0.7),
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
