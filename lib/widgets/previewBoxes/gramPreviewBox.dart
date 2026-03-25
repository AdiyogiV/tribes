import 'dart:async';
import 'dart:math' as Math;
import 'package:aurogram/models/space_types.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:aurogram/models/space.dart';
import 'package:aurogram/services/space_service.dart';
import 'package:aurogram/widgets/previewBoxes/gramPicture.dart';
import 'package:aurogram/widgets/previewBoxes/previewBox.dart';
import 'package:aurogram/utils/dependency_injection.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:aurogram/utils/theme/header_style.dart';
import 'package:aurogram/pages/spaces/spaceChatScreen.dart';
import 'package:aurogram/services/chat/space_chat_service.dart';
import 'package:aurogram/utils/time_display.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:aurogram/widgets/ui/skeleton_widgets.dart';

class GramPreviewBox extends StatefulWidget {
  final String? gram;
  final bool compact;
  final bool showChatButton;
  final int reloadToken;

  const GramPreviewBox(
      {this.gram,
      this.compact = false,
      this.showChatButton = false,
      this.reloadToken = 0,
      Key? key})
      : super(key: key);

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
  Timestamp? _lastUpdated;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
      _updatedSubscription;
  late int _lastReloadToken;
  int _retryCount = 0;
  bool _isInitialLoad = true;

  final SpaceChatService _chatService = SpaceChatService();

  // Cache the stream for post previews to prevent recreation on rebuilds
  Stream<QuerySnapshot>? _postPreviewsStream;
  String? _cachedSpaceIdForStream;

  // Cache futures for mini thumbnails to prevent recreation

  // Simplified: we won't maintain our own mini-preview caches; rely on Firestore stream cache

  // Deterministic random in [minValue, maxValue] based on a string seed
  double _stableRandomInRange(String seed, double minValue, double maxValue) {
    if (maxValue <= minValue) return minValue;
    int acc = 23;
    final units = seed.codeUnits;
    for (int i = 0; i < units.length; i++) {
      acc = (acc * 33 + units[i]) & 0x7fffffff;
    }
    final rng = Math.Random(acc);
    final r = rng.nextDouble();
    return minValue + r * (maxValue - minValue);
  }

  // Per-instance random base so each GramPreviewBox looks different
  late final int _randomBase;

  @override
  void initState() {
    super.initState();
    _randomBase = Math.Random().nextInt(0x7fffffff);
    _lastReloadToken = widget.reloadToken;
    _spaceFuture = _loadSpaceDetails(forceReload: false);
    if (widget.gram != null && widget.gram!.isNotEmpty) {
      _subscribeToSpaceUpdated(widget.gram!);
    }
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
    // Invalidate static caches for this space id
    final String spaceId = widget.gram!;
    GramPreviewBox._spaceCache.remove(spaceId);
    GramPreviewBox._spaceCacheExpiry.remove(spaceId);
    // Recreate future to refetch details
    setState(() {
      // Don't reset _retryCount and _isInitialLoad here
      // Let the build method manage them based on success/failure
      _spaceFuture = _loadSpaceDetails(forceReload: true);
    });
  }

  void _subscribeToSpaceUpdated(String spaceId) {
    _updatedSubscription?.cancel();
    _updatedSubscription = FirebaseFirestore.instance
        .collection('spacePosts')
        .doc(spaceId)
        .snapshots()
        .listen(
      (doc) {
        Timestamp? updated;
        if (doc.exists) {
          final data = doc.data();
          if (data != null) {
            updated = data['updated'] as Timestamp?;
          }
        }

        // Only trigger setState if the timestamp actually changed to avoid unnecessary rebuilds
        if (mounted && _lastUpdated != updated) {
          setState(() {
            _lastUpdated = updated;
          });
        }
      },
      onError: (error) {
        // Log but don't crash - this subscription is for update timestamps only
        debugPrint('GramPreviewBox space update subscription error: $error');
      },
    );
  }

  Widget _buildMiniPostPreviews(String spaceId, {bool isPublicSpace = true}) {
    if (spaceId.isEmpty) return SizedBox.shrink();

    // For logged-out users, only show previews for public spaces (default to public if unknown)
    final user = FirebaseAuth.instance.currentUser;
    if (user == null && !isPublicSpace) {
      return const SizedBox.shrink();
    }

    // Only create new stream if spaceId changed or stream doesn't exist
    if (_postPreviewsStream == null || _cachedSpaceIdForStream != spaceId) {
      _postPreviewsStream = FirebaseFirestore.instance
          .collection('spacePosts')
          .doc(spaceId)
          .collection('posts')
          .orderBy('timestamp', descending: true)
          .limit(7)
          .snapshots();
      _cachedSpaceIdForStream = spaceId;
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _postPreviewsStream!,
      builder: (context, snapshot) {
        // Handle errors gracefully (e.g., permission denied)
        if (snapshot.hasError) {
          return const SizedBox.shrink();
        }
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return const SizedBox.shrink();
        }
        final posts = docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return {
            'id': doc.id,
            'thumbnail': data['thumbnail'],
            'title': data['title'],
            'author': data['author'],
            'postType': data['postType'] ?? 'video',
            'content': data['content'],
          };
        }).toList();
        return _buildMiniPostStack(posts);
      },
    );
  }

  Widget _buildMiniPostStack(List<Map<String, dynamic>> rawPosts) {
    // Filter out permanently bad preview keys
    final List<Map<String, dynamic>> posts = rawPosts.where((p) {
      return true; // Let PreviewBox handle its own validation
    }).toList();

    if (posts.isEmpty) {
      return const SizedBox(width: 100, height: 44);
    }

    final int visible = Math.min(posts.length, 7); // Show up to 7 previews
    
    // Calculate total width needed based on visible cards
    // First card is full width (40), each subsequent card adds ~16px visible
    final double totalWidth = 40.0 + (visible > 1 ? (visible - 1) * 16.0 : 0);

    return SizedBox(
      width: totalWidth.clamp(100.0, 200.0),
      height: 44, // Extra height for elevation shadows
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Stack from back to front for proper layering (rightmost first = lowest elevation)
          for (int i = visible - 1; i >= 0; i--)
            _buildExponentialCard(posts[i], i, visible),
        ],
      ),
    );
  }

  Widget _buildExponentialCard(
      Map<String, dynamic> post, int index, int total) {
    final double cardSize = 40.0;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Tighter overlapping - each card shows progressively less
    double leftPosition = 0.0;
    if (index > 0) {
      // Each card overlaps more tightly
      double cumulativePosition = 0.0;
      for (int i = 1; i <= index; i++) {
        final double visibleWidth = Math.max(12.0, 20.0 - (i * 1.5));
        cumulativePosition += visibleWidth;
      }
      leftPosition = cumulativePosition;
    }

    // Subtle random rotation for visual interest
    final int totalCards = Math.max(1, total);
    final double t = totalCards > 1 ? index / (totalCards - 1) : 0.0;
    final double ease = t * t * (3 - 2 * t);
    final String seed =
        '${widget.gram ?? ''}_${post['id'] ?? ''}_${index}_$_randomBase';
    const double baseMinStart = 1.0;
    const double baseMinEnd = 3.0;
    const double baseMaxStart = 3.0;
    const double baseMaxEnd = 8.0;
    final double minDegrees = baseMinStart + ease * (baseMinEnd - baseMinStart);
    final double maxDegrees = baseMaxStart + ease * (baseMaxEnd - baseMaxStart);
    final double clampedMin = Math.min(minDegrees, maxDegrees - 0.1);
    final double degrees = _stableRandomInRange(seed, clampedMin, maxDegrees);
    final double sign =
        _stableRandomInRange('${seed}_sign', -1.0, 1.0) >= 0 ? 1.0 : -1.0;
    final double zigzagAngle = sign * (degrees * (Math.pi / 180.0));
    
    // Elevation: highest on leftmost (index 0), decreasing to 0 on rightmost
    final double elevation = totalCards > 1 
        ? 4.0 * (1.0 - (index / (totalCards - 1)))
        : 4.0;

    return Positioned(
      left: leftPosition,
      top: 2,
      child: Transform.rotate(
        angle: zigzagAngle,
        child: Material(
          elevation: elevation,
          color: isDark ? AppTheme.cardDarkColor : Colors.white,
          borderRadius: BorderRadius.circular(10),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            width: cardSize,
            height: cardSize,
            child: _buildPostPreview(post),
          ),
        ),
      ),
    );
  }

  Widget _buildPostPreview(Map<String, dynamic> post) {
    final String key = 'mini_${post['id'] ?? ''}';
    final String postType = (post['postType'] as String?) ?? 'video';

    return PreviewBox(
      key: ValueKey(key),
      previewUrl: (post['thumbnail'] as String?) ?? '',
      title: (post['title'] as String?) ?? '',
      author: null, // Don't show author picture in space previews
      content: (post['content'] as String?) ?? '',
      postType: postType,
      compact: true, // Use compact mode for mini thumbnails
      showNoteIcon: false, // Don't show note icon in space previews
      hideWhileLoading: false,
      skipIfMissing: false,
    );
  }

  Future<Map<String, dynamic>?> _loadSpaceDetails(
      {bool forceReload = false}) async {
    if (widget.gram == null) {
      return null;
    }

    final String spaceId = widget.gram!;

    // Check cache first unless forced reload
    if (!forceReload) {
      if (GramPreviewBox._spaceCache.containsKey(spaceId)) {
        final expiry = GramPreviewBox._spaceCacheExpiry[spaceId];
        if (expiry != null && expiry.isAfter(DateTime.now())) {
          return GramPreviewBox._spaceCache[spaceId];
        } else {
          // Expired entry, remove from cache
          GramPreviewBox._spaceCache.remove(spaceId);
          GramPreviewBox._spaceCacheExpiry.remove(spaceId);
        }
      }
    }

    // Add retry mechanism for network issues
    int retryCount = 0;
    const maxRetries = 2;

    while (retryCount <= maxRetries) {
      try {
        // For unauthenticated users or when SpaceService isn't registered,
        // query Firestore directly to avoid dependency issues
        final user = FirebaseAuth.instance.currentUser;
        final bool useDirectQuery = user == null || !locator.isRegistered<SpaceService>();
        
        Space space;
        if (useDirectQuery) {
          // Query Firestore directly for public spaces
          final doc = await FirebaseFirestore.instance
              .collection('spaces')
              .doc(spaceId)
              .get();
          
          if (!doc.exists || doc.data() == null) {
            throw Exception('Space not found! SpaceID: $spaceId');
          }
          
          space = Space.fromJson(doc.data()!);
        } else {
          // Use SpaceService for authenticated users
          final spaceService = locator<SpaceService>();
          space = await spaceService.getSpace(spaceId);
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

        // Cache the result
        GramPreviewBox._spaceCache[spaceId] = details;
        GramPreviewBox._spaceCacheExpiry[spaceId] = DateTime.now().add(GramPreviewBox._cacheDuration);

        return details;
      } catch (e) {
        retryCount++;

        // Check for transient errors that should trigger retry
        final errorString = e.toString().toLowerCase();
        final isTransientError = errorString.contains("no network connection") ||
            errorString.contains("network timeout") ||
            errorString.contains("network request timed out") ||
            errorString.contains("firebaseexception") ||
            errorString.contains("platformexception") ||
            errorString.contains("permission-denied") ||
            errorString.contains("unavailable") ||
            errorString.contains("uninitialized") ||
            errorString.contains("failed-precondition");

        // If it's a transient error and we haven't exhausted retries, try again after delay
        if (isTransientError && retryCount <= maxRetries) {
          await Future.delayed(Duration(milliseconds: 800 * retryCount));
          continue;
        }

        // For transient errors, check if we have a stale cached version we can use as fallback
        if (isTransientError) {
          // Try to use a stale cache entry if available (ignore expiry)
          if (GramPreviewBox._spaceCache.containsKey(spaceId) &&
              GramPreviewBox._spaceCache[spaceId] != null) {
            // Use stale cached data as fallback
            return GramPreviewBox._spaceCache[spaceId];
          }
        }

        // Only cache null result if space truly doesn't exist (not transient errors)
        // This allows retries for network/Firestore issues
        if (errorString.contains('space not found') && 
            !isTransientError) {
          // Cache the null result to avoid repeated lookups, but with shorter expiry for errors
          GramPreviewBox._spaceCache[spaceId] = null;
          GramPreviewBox._spaceCacheExpiry[spaceId] = DateTime.now().add(Duration(minutes: 1));
          return null; // Space doesn't exist - return null
        }
        
        // For transient errors during initial load, DON'T cache null
        // Just rethrow to allow retry logic in the FutureBuilder
        // Remove any stale cached null values to prevent false negatives
        if (isTransientError) {
          GramPreviewBox._spaceCache.remove(spaceId);
          GramPreviewBox._spaceCacheExpiry.remove(spaceId);
        }
        
        // For transient errors, rethrow the exception so FutureBuilder can handle it
        // This allows the FutureBuilder to distinguish between "doesn't exist" (null) 
        // and "transient error" (exception) for proper retry logic
        rethrow;
      }
    }

    // This should never be reached due to the return in the catch block
    return null;
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
        // Show loading while waiting or if there's an error but it might be transient
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState();
        }

        // If there's an error, check if it's transient (should retry)
        if (snapshot.hasError) {
          final errorString = snapshot.error.toString().toLowerCase();
          final isTransientError = errorString.contains("network") ||
              errorString.contains("timeout") ||
              errorString.contains("firebaseexception") ||
              errorString.contains("platformexception") ||
              errorString.contains("permission-denied") ||
              errorString.contains("unavailable") ||
              errorString.contains("uninitialized");
          
          // For transient errors, show loading state and retry
          if (isTransientError && _retryCount < 5) {
            _retryCount++;
            // Retry immediately for initial loads, with increasing delay for subsequent retries
            final retryDelay = _isInitialLoad ? 
                Duration(milliseconds: 300 + (_retryCount * 200)) : 
                Duration(seconds: 2);
            
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && widget.gram != null) {
                Future.delayed(retryDelay, () {
                  if (mounted) {
                    _forceReload();
                  }
                });
              }
            });
            return _buildLoadingState();
          }
          // Permanent error (space doesn't exist) or too many retries - show error state
          return _buildErrorState();
        }

        // No data means space doesn't exist (permanent error)
        // But if we're still in initial load phase, give it more time
        if (!snapshot.hasData || snapshot.data == null) {
          if (_isInitialLoad && _retryCount < 3) {
            _retryCount++;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && widget.gram != null) {
                Future.delayed(Duration(milliseconds: 500), () {
                  if (mounted) {
                    _forceReload();
                  }
                });
              }
            });
            return _buildLoadingState();
          }
          return _buildErrorState();
        }

        // Successfully loaded data - mark initial load as complete
        _isInitialLoad = false;
        _retryCount = 0;
        
        final spaceData = snapshot.data!;
        return _buildSpacePreview(spaceData);
      },
    );
  }

  Widget _buildLoadingState() {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color cardColor = isDark ? AppTheme.cardDarkColor : Colors.white;
    // Warm beige colors matching feed skeleton
    final Color placeholder = isDark 
        ? Colors.white.withValues(alpha: 0.08)
        : const Color(0xFFE8E0D5);
    final Color placeholderDark = isDark 
        ? Colors.white.withValues(alpha: 0.14)
        : const Color(0xFFD8CFC2);
    
    if (widget.compact) {
      // Compact skeleton - matches compact preview dimensions with shimmer
      return ShimmerBox(
        child: SizedBox(
          height: 42,
          child: Row(
            children: [
              // Avatar skeleton
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: placeholderDark,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(width: 10),
              // Text placeholders
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 100,
                      height: 12,
                      decoration: BoxDecoration(
                        color: placeholderDark,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: 60,
                      height: 10,
                      decoration: BoxDecoration(
                        color: placeholder,
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Full skeleton matching feed post card style
    return Padding(
      padding: EdgeInsets.fromLTRB(AppHeaderStyle.contentHorizontalPadding, 0, AppHeaderStyle.contentHorizontalPadding, AppHeaderStyle.cardVerticalGap),
      child: Material(
        color: cardColor,
        elevation: isDark ? 2 : 1,
        shadowColor: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
        borderRadius: BorderRadius.circular(AppHeaderStyle.cardBorderRadius),
        clipBehavior: Clip.antiAlias,
        child: ShimmerBox(
          child: Container(
            height: AppHeaderStyle.cardRegularHeight,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Avatar skeleton - circular
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: placeholderDark,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 16),
                // Content skeleton
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title and subtitle
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 130,
                            height: 14,
                            decoration: BoxDecoration(
                              color: placeholderDark,
                              borderRadius: BorderRadius.circular(7),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            width: 80,
                            height: 10,
                            decoration: BoxDecoration(
                              color: placeholder,
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ),
                        ],
                      ),
                      // Mini previews skeleton row
                      Row(
                        children: List.generate(4, (i) => Transform.translate(
                          offset: Offset(-i * 8.0, 0),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: placeholder,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: cardColor, width: 2),
                            ),
                          ),
                        )),
                      ),
                    ],
                  ),
                ),
                // Right side
                Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      width: 35,
                      height: 10,
                      decoration: BoxDecoration(
                        color: placeholder,
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: placeholder,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    if (widget.compact) {
      return Container(
        height: 42,
        width: 42,
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Icon(
            Icons.error_outline,
            color: isDark ? AppTheme.textSecondaryDarkColor : AppTheme.textSecondaryLightColor,
            size: 18,
          ),
        ),
      );
    }

    final Color barBase = isDark ? AppTheme.cardDarkColor : Colors.white;
    
    return Padding(
      padding: EdgeInsets.fromLTRB(AppHeaderStyle.contentHorizontalPadding, 0, AppHeaderStyle.contentHorizontalPadding, AppHeaderStyle.cardVerticalGap),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppHeaderStyle.cardBorderRadius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Material(
          elevation: 4,
          color: Colors.transparent,
          shadowColor: Colors.black.withValues(alpha: 0.04),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppHeaderStyle.cardBorderRadius),
          ),
          clipBehavior: Clip.antiAlias,
          child: Container(
            height: AppHeaderStyle.cardCompactHeight,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppHeaderStyle.cardBorderRadius),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  barBase.withValues(alpha: isDark ? 0.85 : 0.90),
                  barBase.withValues(alpha: isDark ? 0.80 : 0.85),
                ],
              ),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.10)
                    : barBase.withValues(alpha: 0.32),
              ),
            ),
            child: Center(
              child: Text(
                "Gram unavailable",
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? AppTheme.textSecondaryDarkColor : AppTheme.textSecondaryLightColor,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSpacePreview(Map<String, dynamic> spaceData) {
    final String? name = spaceData['name'];
    final SpaceType? type = spaceData['spaceType'];
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    if (widget.compact) {
      // Compact version for Feed header
      return SizedBox(
        height: 42,
        child: Material(
          elevation: 0,
          borderRadius: BorderRadius.zero,
          clipBehavior: Clip.antiAliasWithSaveLayer,
          color: Colors.transparent,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              SizedBox(
                width: 42,
                height: 42,
                child: GramPicture(
                  displayPicture: spaceData['displayPicture'],
                  size: 42.0,
                  spaceId: spaceData['id'] ?? '',
                  borderRadius: 0.0,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name ?? 'Gram',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryColor,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (type != null)
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: getColorFromSpaceType(type),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _getSpaceTypeLabel(type),
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? AppTheme.textSecondaryDarkColor
                                  : AppTheme.textSecondaryLightColor,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: AppTheme.primaryColor.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      );
    }

    // Full card version - styled exactly like tabs bar / transparent toolbox
    final Color barBase = isDark ? AppTheme.cardDarkColor : Colors.white;

    return Padding(
      padding: EdgeInsets.fromLTRB(AppHeaderStyle.contentHorizontalPadding, 0, AppHeaderStyle.contentHorizontalPadding, AppHeaderStyle.cardVerticalGap),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppHeaderStyle.cardBorderRadius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Material(
          elevation: 4,
          color: Colors.transparent,
          shadowColor: Colors.black.withValues(alpha: 0.04),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppHeaderStyle.cardBorderRadius),
          ),
          clipBehavior: Clip.antiAlias,
          child: Container(
            constraints: const BoxConstraints(minHeight: 70),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppHeaderStyle.cardBorderRadius),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  barBase.withValues(alpha: isDark ? 0.85 : 0.90),
                  barBase.withValues(alpha: isDark ? 0.80 : 0.85),
                ],
              ),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.10)
                    : barBase.withValues(alpha: 0.32),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                // Space Picture - circular avatar with elevation
                Material(
                  elevation: 1,
                  color: isDark ? AppTheme.cardDarkColor : Colors.white,
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: GramPicture(
                    displayPicture: spaceData['displayPicture'],
                    size: 56,
                    spaceId: spaceData['id'] ?? '',
                    borderRadius: 28.0,
                  ),
                ),
                const SizedBox(width: 16),
                // Space name and info
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top row: Space name + chat button (always visible)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text(
                              name ?? 'Gram',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primaryColor,
                                letterSpacing: -0.0,
                              ),
                            ),
                          ),
                          if (widget.showChatButton) ...[
                            const SizedBox(width: 8),
                            _buildIconsRow(spaceData, type),
                          ],
                        ],
                      ),
                      // Bottom row: mini previews + time (always show for public spaces)
                      // Show previews regardless of chat button visibility for public grams
                      _buildBottomRow(
                        spaceData['id'] ?? '',
                        // Default to public if type is unknown, only hide for explicitly private types
                        isPublicSpace: type == null || isPublicSpaceType(type),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Bottom row that only renders when there's actual content (previews or time)
  Widget _buildBottomRow(String spaceId, {bool isPublicSpace = true}) {
    if (spaceId.isEmpty) return const SizedBox.shrink();
    
    // Check if we have time to show
    final bool hasTime = _lastUpdated != null;
    
    // For logged-out users, only show previews for public spaces
    final user = FirebaseAuth.instance.currentUser;
    final bool canShowPreviews = user != null || isPublicSpace;
    
    if (!canShowPreviews) {
      // For private spaces with logged-out users, only show time if available
      if (hasTime) {
        return Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Row(
            children: [
              const Spacer(),
              _buildLastUpdatedIndicator(),
            ],
          ),
        );
      }
      return const SizedBox.shrink();
    }
    
    // Initialize stream if needed (same logic as _buildMiniPostPreviews)
    if (_postPreviewsStream == null || _cachedSpaceIdForStream != spaceId) {
      _postPreviewsStream = FirebaseFirestore.instance
          .collection('spacePosts')
          .doc(spaceId)
          .collection('posts')
          .orderBy('timestamp', descending: true)
          .limit(7)
          .snapshots();
      _cachedSpaceIdForStream = spaceId;
    }
    
    // Use StreamBuilder to check if we have previews
    return StreamBuilder<QuerySnapshot>(
      stream: _postPreviewsStream!,
      builder: (context, snapshot) {
        // Debug: Log stream errors for troubleshooting
        if (snapshot.hasError) {
          debugPrint('GramPreviewBox post stream error: ${snapshot.error}');
          // Fall through - will show empty since hasPreviews will be false
        }
        
        final bool hasPreviews = snapshot.hasData && 
            snapshot.data!.docs.isNotEmpty;
        
        // If no content at all, return empty (truly collapse)
        if (!hasTime && !hasPreviews) {
          return const SizedBox.shrink();
        }
        
        // We have content, show the row with spacing
        return Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (hasPreviews)
                Flexible(child: _buildMiniPostStack(
                  snapshot.data!.docs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return {
                      'id': doc.id,
                      'thumbnail': data['thumbnail'],
                      'title': data['title'],
                      'author': data['author'],
                      'postType': data['postType'] ?? 'video',
                      'content': data['content'],
                    };
                  }).toList(),
                )),
              if (hasPreviews && hasTime) const Spacer(),
              if (hasTime) _buildLastUpdatedIndicator(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLastUpdatedIndicator() {
    if (_lastUpdated == null) return const SizedBox.shrink();
    final DateTime dt = _lastUpdated!.toDate();
    final Duration diff = DateTime.now().difference(dt);
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    Color color;
    if (diff.inMinutes < 60) {
      color = AppTheme.successColor; // recent activity
    } else if (diff.inHours < 24) {
      color = AppTheme.warningColor; // today
    } else {
      color = isDark ? AppTheme.textSecondaryDarkColor : AppTheme.textSecondaryLightColor;
    }

    // Use the unified timestamp formatting
    String label = TimeDisplay.getCompactTimestamp(dt);

    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w600,
        ),
        textAlign: TextAlign.end,
      ),
    );
  }

  Widget _buildIconsRow(Map<String, dynamic> spaceData, SpaceType? type) {
    // Show lock for private spaces (type 2) or if limitedVisibility is true
    final limitedVisibility = spaceData['limitedVisibility'] as bool? ?? false;
    final isPrivate = (type != null && isPrivateSpaceType(type)) || limitedVisibility;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Lock icon for private spaces
        if (isPrivate)
          Padding(
            padding: const EdgeInsets.only(right: 2.0),
            child: Opacity(
              opacity: 0.9,
              child: Image.asset(
                'assets/images/lock.png',
                width: 28,
                height: 28,
              ),
            ),
          ),
        // Paper plane icon
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _openChat(spaceData),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 10.0, vertical: 2.0),
            child: Icon(
              CupertinoIcons.paperplane_fill,
              size: 24,
              color: AppTheme.primaryColor,
            ),
          ),
        ),
      ],
    );
  }

  void _openChat(Map<String, dynamic> spaceData) {
    final String? spaceId = spaceData['id'] as String?;
    if (spaceId == null || spaceId.isEmpty) return;

    // Mark all messages as read when opening chat
    _chatService.markAllMessagesAsRead(spaceId);

    Space space;
    final dynamic obj = spaceData['spaceObject'];
    if (obj is Space) {
      space = obj;
    } else {
      final String name = (spaceData['name'] as String?) ?? '';
      final SpaceType spaceType =
          spaceData['spaceType'] as SpaceType? ?? SpaceType.public;
      space = Space(
        id: spaceId,
        name: name,
        searchName: name.toLowerCase(),
        spaceType: spaceType,
        description: spaceData['description'] as String?,
        displayPicture: spaceData['displayPicture'] as String?,
      );
    }

    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (context) => SpaceChatScreen(
          spaceId: spaceId,
          space: space,
        ),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _updatedSubscription?.cancel();
    // Clear cached resources for this instance
    // PreviewBox handles its own caching
    _postPreviewsStream = null;
    _cachedSpaceIdForStream = null;
    super.dispose();
  }
}


