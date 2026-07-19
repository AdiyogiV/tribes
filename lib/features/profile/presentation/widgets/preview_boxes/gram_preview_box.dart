import 'package:aurogram/core/theme/app_dimensions.dart';
import 'dart:math' as math;
import 'package:aurogram/shared/models/space_types.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:aurogram/shared/models/space.dart';
import 'package:aurogram/features/spaces/domain/space_service.dart';
import 'package:aurogram/features/profile/presentation/widgets/preview_boxes/gram_picture.dart';
import 'package:aurogram/core/di/injection.dart';
import 'package:aurogram/core/logging/app_logger.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/core/theme/header_style.dart';
import 'package:aurogram/features/chat/domain/space_chat_service.dart';
import 'package:aurogram/shared/utils/time_display.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:aurogram/features/profile/presentation/widgets/preview_boxes/gram/gram_preview_loading.dart';
import 'package:aurogram/features/profile/presentation/widgets/preview_boxes/gram/gram_preview_actions.dart';
import 'package:aurogram/features/profile/presentation/widgets/preview_boxes/gram/gram_preview_media.dart';

// Re-export sub-widgets so existing imports continue to work
export 'package:aurogram/features/profile/presentation/widgets/preview_boxes/gram/gram_preview_loading.dart';

class GramPreviewBox extends StatefulWidget {
  final String? gram;
  final bool compact;
  final bool showChatButton;
  final int reloadToken;

  /// Optional last-updated timestamp injected by the parent (e.g. Grams tab
  /// which already maintains a per-space subscription). When provided the
  /// preview avoids opening its own `spacePosts/{id}` listener — saving
  /// O(N) Firestore listeners on screens that render many previews.
  final Timestamp? lastUpdated;

  const GramPreviewBox(
      {this.gram,
      this.compact = false,
      this.showChatButton = false,
      this.reloadToken = 0,
      this.lastUpdated,
      super.key});

  // Static cache for space details to avoid repeated lookups
  static final Map<String, Map<String, dynamic>?> _spaceCache = {};
  static final Map<String, DateTime> _spaceCacheExpiry = {};
  static const Duration _cacheDuration = Duration(minutes: 5);

  /// Clear the static space cache - call this on refresh to ensure fresh data
  static void clearSpaceCache([String? spaceId]) {
    if (spaceId != null) {
      _spaceCache.remove(spaceId);
      _spaceCacheExpiry.remove(spaceId);
    } else {
      _spaceCache.clear();
      _spaceCacheExpiry.clear();
    }
  }

  @override
  _GramPreviewBoxState createState() => _GramPreviewBoxState();
}

class _GramPreviewBoxState extends State<GramPreviewBox>
    with AutomaticKeepAliveClientMixin {
  late Future<Map<String, dynamic>?> _spaceFuture;
  late int _lastReloadToken;

  final SpaceChatService _chatService = SpaceChatService();

  // Lightweight per-process cache for post previews (latest 7 docs per space).
  // Streaming this for every gram on screen used to open N Firestore
  // listeners — replaced with a one-shot fetch + 60s TTL.
  static final Map<String, List<QueryDocumentSnapshot>> _postPreviewsCache = {};
  static final Map<String, DateTime> _postPreviewsExpiry = {};
  static const Duration _postPreviewsTtl = Duration(seconds: 60);
  Future<List<QueryDocumentSnapshot>>? _postPreviewsFuture;
  String? _cachedSpaceIdForPosts;

  // Per-instance random base so each GramPreviewBox looks different
  late final int _randomBase;

  // Deterministic random in [minValue, maxValue] based on a string seed
  double _stableRandomInRange(String seed, double minValue, double maxValue) {
    if (maxValue <= minValue) return minValue;
    int acc = 23;
    final units = seed.codeUnits;
    for (int i = 0; i < units.length; i++) {
      acc = (acc * 33 + units[i]) & 0x7fffffff;
    }
    final rng = math.Random(acc);
    final r = rng.nextDouble();
    return minValue + r * (maxValue - minValue);
  }

  @override
  void initState() {
    super.initState();
    _randomBase = math.Random().nextInt(0x7fffffff);
    _lastReloadToken = widget.reloadToken;
    _spaceFuture = _loadSpaceDetails(forceReload: false);
  }

  @override
  void didUpdateWidget(covariant GramPreviewBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.reloadToken != _lastReloadToken) {
      _lastReloadToken = widget.reloadToken;
      _forceReload();
    }
  }

  void _forceReload() {
    if (widget.gram == null || widget.gram!.isEmpty) return;
    final String spaceId = widget.gram!;
    GramPreviewBox._spaceCache.remove(spaceId);
    GramPreviewBox._spaceCacheExpiry.remove(spaceId);
    _postPreviewsCache.remove(spaceId);
    _postPreviewsExpiry.remove(spaceId);
    setState(() {
      _spaceFuture = _loadSpaceDetails(forceReload: true);
      _postPreviewsFuture = null;
      _cachedSpaceIdForPosts = null;
    });
  }

  /// Fetch the latest 7 post previews once, cached for [_postPreviewsTtl].
  /// Replaces a Firestore snapshots() listener that used to fire per gram.
  Future<List<QueryDocumentSnapshot>> _loadPostPreviews(String spaceId) async {
    final cached = _postPreviewsCache[spaceId];
    final expiry = _postPreviewsExpiry[spaceId];
    if (cached != null && expiry != null && expiry.isAfter(DateTime.now())) {
      return cached;
    }
    try {
      final snap = await FirebaseFirestore.instance
          .collection('spacePosts')
          .doc(spaceId)
          .collection('posts')
          .orderBy('timestamp', descending: true)
          .limit(7)
          .get();
      _postPreviewsCache[spaceId] = snap.docs;
      _postPreviewsExpiry[spaceId] = DateTime.now().add(_postPreviewsTtl);
      return snap.docs;
    } catch (e) {
      AppLogger.w('GramPreviewBox post previews fetch failed',
          category: LogCategory.database,
          data: {'error': e.toString(), 'spaceId': spaceId});
      return cached ?? const [];
    }
  }

  Future<List<QueryDocumentSnapshot>> _ensurePostPreviewsFuture(String spaceId) {
    if (_postPreviewsFuture == null || _cachedSpaceIdForPosts != spaceId) {
      _cachedSpaceIdForPosts = spaceId;
      _postPreviewsFuture = _loadPostPreviews(spaceId);
    }
    return _postPreviewsFuture!;
  }

  Future<Map<String, dynamic>?> _loadSpaceDetails(
      {bool forceReload = false}) async {
    if (widget.gram == null) return null;

    final String spaceId = widget.gram!;

    // Check cache first unless forced reload
    if (!forceReload) {
      if (GramPreviewBox._spaceCache.containsKey(spaceId)) {
        final expiry = GramPreviewBox._spaceCacheExpiry[spaceId];
        if (expiry != null && expiry.isAfter(DateTime.now())) {
          return GramPreviewBox._spaceCache[spaceId];
        } else {
          GramPreviewBox._spaceCache.remove(spaceId);
          GramPreviewBox._spaceCacheExpiry.remove(spaceId);
        }
      }
    }

    try {
      final user = FirebaseAuth.instance.currentUser;
      final bool useDirectQuery =
          user == null || !locator.isRegistered<SpaceService>();

      Space space;
      if (useDirectQuery) {
        final doc = await FirebaseFirestore.instance
            .collection('spaces')
            .doc(spaceId)
            .get();

        if (!doc.exists || doc.data() == null) {
          throw Exception('Space not found! SpaceID: $spaceId');
        }

        space = Space.fromJson(doc.data()!);
      } else {
        // SpaceService already has its own cache + 10s timeout, so we don't
        // duplicate retry/timeout logic here. One source of truth wins.
        space = await locator<SpaceService>().getSpace(spaceId);
      }

      final details = {
        'id': space.id,
        'name': space.name,
        'description': space.description,
        'displayPicture': space.displayPicture,
        'spaceType': space.spaceType,
        'limitedVisibility': space.limitedVisibility,
        'spaceObject': space,
      };

      GramPreviewBox._spaceCache[spaceId] = details;
      GramPreviewBox._spaceCacheExpiry[spaceId] =
          DateTime.now().add(GramPreviewBox._cacheDuration);
      return details;
    } catch (e) {
      final errorString = e.toString().toLowerCase();
      // Negative-cache 'not found' for 1 minute so we don't keep hammering.
      if (errorString.contains('space not found')) {
        GramPreviewBox._spaceCache[spaceId] = null;
        GramPreviewBox._spaceCacheExpiry[spaceId] =
            DateTime.now().add(const Duration(minutes: 1));
        return null;
      }
      // Transient error: leave cache untouched so next refresh retries.
      rethrow;
    }
  }

  String _getSpaceTypeLabel(SpaceType? type) {
    if (type == null) return 'Private';
    return isPrivateSpaceType(type) ? 'Private' : 'Public';
  }

  Color getColorFromSpaceType(SpaceType type) {
    return isPrivateSpaceType(type) ? AppTheme.warningColor : AppTheme.successColor;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return FutureBuilder<Map<String, dynamic>?>(
      future: _spaceFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return GramPreviewLoading.buildLoadingState(context,
              compact: widget.compact);
        }
        if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
          // No more silent auto-retry storms — SpaceService already retries
          // internally and the user can pull-to-refresh on the parent list.
          return GramPreviewLoading.buildErrorState(context,
              compact: widget.compact);
        }
        return _buildSpacePreview(snapshot.data!);
      },
    );
  }

  Widget _buildSpacePreview(Map<String, dynamic> spaceData) {
    final String? name = spaceData['name'];
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final Color fgColor = isDark ? Colors.white : Colors.black;
    final Color subtleText = isDark ? const Color(0xFF666666) : const Color(0xFF999999);
    final Color dividerColor = isDark ? const Color(0xFF222222) : const Color(0xFFEEEEEE);

    if (widget.compact) {
      return Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.centerLeft,
        child: Text(
          name?.toLowerCase() ?? 'gram',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w400,
            color: fgColor,
            letterSpacing: -0.2,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      );
    }

    // Super Minimal List Item
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: dividerColor, width: 0.5)),
      ),
      child: Row(
        children: [
          Text(
            '#',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w300,
              color: subtleText.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name?.toLowerCase() ?? 'gram',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: fgColor,
                letterSpacing: -0.2,
              ),
            ),
          ),
          if (widget.lastUpdated != null)
            _buildLastUpdatedIndicator(subtleText),
        ],
      ),
    );
  }

  Widget _buildLastUpdatedIndicator([Color? color]) {
    final ts = widget.lastUpdated;
    if (ts == null) return const SizedBox.shrink();
    final DateTime dt = ts.toDate();
    
    return Padding(
      padding: const EdgeInsets.only(left: 12.0),
      child: Text(
        TimeDisplay.getCompactTimestamp(dt).toLowerCase(),
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _postPreviewsFuture = null;
    _cachedSpaceIdForPosts = null;
    super.dispose();
  }
}
