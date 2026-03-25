import 'package:flutter/cupertino.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:aurogram/pages/tabs/userProfile.dart';
import 'package:aurogram/pages/spaces/spaceScreen.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:aurogram/utils/time_display.dart';

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
      if (timestamp != null && DateTime.now().difference(timestamp) < _cacheExpiry) {
        return _userCache[uid];
      }
    }
    
    // Fetch from Firestore
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists) {
        final data = doc.data() ?? {};
        _userCache[uid] = data;
        _userTimestamps[uid] = DateTime.now();
        return data;
      }
    } catch (_) {}
    return null;
  }
  
  static Future<Map<String, dynamic>?> getSpace(String spaceId) async {
    // Check cache first
    if (_spaceCache.containsKey(spaceId)) {
      final timestamp = _spaceTimestamps[spaceId];
      if (timestamp != null && DateTime.now().difference(timestamp) < _cacheExpiry) {
        return _spaceCache[spaceId];
      }
    }
    
    // Fetch from Firestore
    try {
      final doc = await FirebaseFirestore.instance.collection('spaces').doc(spaceId).get();
      if (doc.exists) {
        final data = doc.data() ?? {};
        _spaceCache[spaceId] = data;
        _spaceTimestamps[spaceId] = DateTime.now();
        return data;
      }
    } catch (_) {}
    return null;
  }
  
  /// Get cached data synchronously (returns null if not cached)
  static Map<String, dynamic>? getCachedUser(String uid) {
    if (_userCache.containsKey(uid)) {
      final timestamp = _userTimestamps[uid];
      if (timestamp != null && DateTime.now().difference(timestamp) < _cacheExpiry) {
        return _userCache[uid];
      }
    }
    return null;
  }
  
  static Map<String, dynamic>? getCachedSpace(String spaceId) {
    if (_spaceCache.containsKey(spaceId)) {
      final timestamp = _spaceTimestamps[spaceId];
      if (timestamp != null && DateTime.now().difference(timestamp) < _cacheExpiry) {
        return _spaceCache[spaceId];
      }
    }
    return null;
  }
}

/// Clean, minimal post header matching TransparentToolbox style
/// All text in primary color
/// Layout: Avatar | Name · Group · Time | Label
class PostHeader extends StatelessWidget {
  final String? uid;
  final String? space;
  final Timestamp? timestamp;
  final String? label;
  final Color? labelColor;
  final bool isProfilePost; // When true, hide the space/gram name

  const PostHeader({
    Key? key,
    this.uid,
    this.space,
    this.timestamp,
    this.label,
    this.labelColor,
    this.isProfilePost = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final timeText = timestamp != null
        ? TimeDisplay.getCompactTimestamp(timestamp!.toDate())
        : '';

    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 4, 4, 4),
      child: Row(
        children: [
          // Avatar
          GestureDetector(
            onTap: () => _navigateToProfile(context),
            child: _UserAvatar(uid: uid, size: 42),
          ),

          const SizedBox(width: 12),

          // Name + Group + Time
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // User name
                GestureDetector(
                  onTap: () => _navigateToProfile(context),
                  child: _UserName(uid: uid),
                ),

                const SizedBox(height: 3),

                // Group · Time row (hide space for profile posts)
                Row(
                  children: [
                    // Space/Group name - hidden for profile posts
                    if (!isProfilePost && space != null && space!.isNotEmpty)
                      Flexible(
                        child: GestureDetector(
                          onTap: () => _navigateToSpace(context),
                          child: _SpaceName(spaceId: space!),
                        ),
                      ),

                    // Separator dot - hidden for profile posts
                    if (!isProfilePost && space != null && space!.isNotEmpty && timeText.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Text(
                          '·',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.primaryColor.withValues(alpha: 0.5),
                          ),
                        ),
                      ),

                    // Timestamp
                    if (timeText.isNotEmpty)
                      Text(
                        timeText,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.primaryColor.withValues(alpha: 0.6),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // Label badge (REPLY, ORIGINAL)
          if (label != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: (labelColor ?? AppTheme.primaryColor).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
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

/// User avatar with caching - no more constant refreshes
class _UserAvatar extends StatefulWidget {
  final String? uid;
  final double size;

  const _UserAvatar({required this.uid, required this.size});

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
    if (oldWidget.uid != widget.uid) {
      _loadAvatar();
    }
  }

  void _loadAvatar() {
    if (widget.uid == null) {
      setState(() => _loaded = true);
      return;
    }

    // Check cache first (synchronous)
    final cached = _HeaderCache.getCachedUser(widget.uid!);
    if (cached != null) {
      _photoUrl = cached['displayPicture'] as String?;
      _loaded = true;
      if (mounted) setState(() {});
      return;
    }

    // Load from Firestore (async)
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

/// User name with caching - no more constant refreshes
class _UserName extends StatefulWidget {
  final String? uid;

  const _UserName({required this.uid});

  @override
  State<_UserName> createState() => _UserNameState();
}

class _UserNameState extends State<_UserName> {
  String _name = 'User';
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadName();
  }

  @override
  void didUpdateWidget(_UserName oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.uid != widget.uid) {
      _loadName();
    }
  }

  void _loadName() {
    if (widget.uid == null) {
      setState(() {
        _name = 'Unknown';
        _loaded = true;
      });
      return;
    }

    // Check cache first (synchronous)
    final cached = _HeaderCache.getCachedUser(widget.uid!);
    if (cached != null) {
      _name = cached['displayName'] as String? ?? cached['name'] as String? ?? 'User';
      _loaded = true;
      if (mounted) setState(() {});
      return;
    }

    // Load from Firestore (async)
    _HeaderCache.getUser(widget.uid!).then((data) {
      if (mounted) {
        setState(() {
          _name = data?['displayName'] as String? ?? data?['name'] as String? ?? 'User';
          _loaded = true;
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

/// Space name with caching - no more constant refreshes
class _SpaceName extends StatefulWidget {
  final String spaceId;

  const _SpaceName({required this.spaceId});

  @override
  State<_SpaceName> createState() => _SpaceNameState();
}

class _SpaceNameState extends State<_SpaceName> {
  String _name = 'Gram';
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadName();
  }

  @override
  void didUpdateWidget(_SpaceName oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.spaceId != widget.spaceId) {
      _loadName();
    }
  }

  void _loadName() {
    // Check cache first (synchronous)
    final cached = _HeaderCache.getCachedSpace(widget.spaceId);
    if (cached != null) {
      _name = cached['name'] as String? ?? 'Gram';
      _loaded = true;
      if (mounted) setState(() {});
      return;
    }

    // Load from Firestore (async)
    _HeaderCache.getSpace(widget.spaceId).then((data) {
      if (mounted) {
        setState(() {
          _name = data?['name'] as String? ?? 'Gram';
          _loaded = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _name,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: AppTheme.primaryColor.withValues(alpha: 0.7),
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
