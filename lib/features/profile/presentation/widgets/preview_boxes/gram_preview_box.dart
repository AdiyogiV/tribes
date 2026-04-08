import 'package:aurogram/core/theme/app_dimensions.dart';
import 'dart:async';
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

  const GramPreviewBox(
      {this.gram,
      this.compact = false,
      this.showChatButton = false,
      this.reloadToken = 0,
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
    final String spaceId = widget.gram!;
    GramPreviewBox._spaceCache.remove(spaceId);
    GramPreviewBox._spaceCacheExpiry.remove(spaceId);
    setState(() {
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
        if (mounted && _lastUpdated != updated) {
          setState(() {
            _lastUpdated = updated;
          });
        }
      },
      onError: (error) {
        AppLogger.w(
          'GramPreviewBox space update subscription error',
          category: LogCategory.database,
          data: {'error': error.toString(), 'spaceId': widget.gram ?? ''},
        );
      },
    );
  }

  void _ensurePostPreviewsStream(String spaceId) {
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

    int retryCount = 0;
    const maxRetries = 2;

    while (retryCount <= maxRetries) {
      try {
        final user = FirebaseAuth.instance.currentUser;
        final bool useDirectQuery = user == null || !locator.isRegistered<SpaceService>();

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

        GramPreviewBox._spaceCache[spaceId] = details;
        GramPreviewBox._spaceCacheExpiry[spaceId] = DateTime.now().add(GramPreviewBox._cacheDuration);

        return details;
      } catch (e) {
        retryCount++;

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

        if (isTransientError && retryCount <= maxRetries) {
          await Future.delayed(Duration(milliseconds: 800 * retryCount));
          continue;
        }

        if (isTransientError) {
          if (GramPreviewBox._spaceCache.containsKey(spaceId) &&
              GramPreviewBox._spaceCache[spaceId] != null) {
            return GramPreviewBox._spaceCache[spaceId];
          }
        }

        if (errorString.contains('space not found') && !isTransientError) {
          GramPreviewBox._spaceCache[spaceId] = null;
          GramPreviewBox._spaceCacheExpiry[spaceId] = DateTime.now().add(Duration(minutes: 1));
          return null;
        }

        if (isTransientError) {
          GramPreviewBox._spaceCache.remove(spaceId);
          GramPreviewBox._spaceCacheExpiry.remove(spaceId);
        }

        rethrow;
      }
    }

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
        if (snapshot.connectionState == ConnectionState.waiting) {
          return GramPreviewLoading.buildLoadingState(context, compact: widget.compact);
        }

        if (snapshot.hasError) {
          final errorString = snapshot.error.toString().toLowerCase();
          final isTransientError = errorString.contains("network") ||
              errorString.contains("timeout") ||
              errorString.contains("firebaseexception") ||
              errorString.contains("platformexception") ||
              errorString.contains("permission-denied") ||
              errorString.contains("unavailable") ||
              errorString.contains("uninitialized");

          if (isTransientError && _retryCount < 5) {
            _retryCount++;
            final retryDelay = _isInitialLoad ?
                Duration(milliseconds: 300 + (_retryCount * 200)) :
                Duration(seconds: 2);

            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && widget.gram != null) {
                Future.delayed(retryDelay, () {
                  if (mounted) _forceReload();
                });
              }
            });
            return GramPreviewLoading.buildLoadingState(context, compact: widget.compact);
          }
          return GramPreviewLoading.buildErrorState(context, compact: widget.compact);
        }

        if (!snapshot.hasData || snapshot.data == null) {
          if (_isInitialLoad && _retryCount < 3) {
            _retryCount++;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && widget.gram != null) {
                Future.delayed(Duration(milliseconds: 500), () {
                  if (mounted) _forceReload();
                });
              }
            });
            return GramPreviewLoading.buildLoadingState(context, compact: widget.compact);
          }
          return GramPreviewLoading.buildErrorState(context, compact: widget.compact);
        }

        _isInitialLoad = false;
        _retryCount = 0;

        final spaceData = snapshot.data!;
        return _buildSpacePreview(spaceData);
      },
    );
  }

  Widget _buildSpacePreview(Map<String, dynamic> spaceData) {
    final String? name = spaceData['name'];
    final SpaceType? type = spaceData['spaceType'];
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    if (widget.compact) {
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
              const SizedBox(width: AppDimensions.spacingMdSm),
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
                          const SizedBox(width: AppDimensions.spacingXs),
                          Flexible(
                            child: Text(
                              _getSpaceTypeLabel(type),
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? AppTheme.textSecondaryDarkColor
                                    : AppTheme.textSecondaryLightColor,
                              ),
                              overflow: TextOverflow.ellipsis,
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

    // Full card version
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
                const SizedBox(width: AppDimensions.spacingLg),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                          const SizedBox(width: AppDimensions.spacingSm),
                          GramPreviewActions.buildCallButton(
                            context,
                            spaceData['id'] as String? ?? '',
                            spaceData['name'] as String? ?? 'Gram',
                          ),
                          if (widget.showChatButton) ...[
                            GramPreviewActions.buildChatAndLockIcons(
                              context, spaceData, type, _chatService),
                          ],
                        ],
                      ),
                      _buildBottomRow(
                        spaceData['id'] ?? '',
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

    final bool hasTime = _lastUpdated != null;
    final user = FirebaseAuth.instance.currentUser;
    final bool canShowPreviews = user != null || isPublicSpace;

    if (!canShowPreviews) {
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

    _ensurePostPreviewsStream(spaceId);

    return StreamBuilder<QuerySnapshot>(
      stream: _postPreviewsStream!,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          AppLogger.w(
            'GramPreviewBox post stream error',
            category: LogCategory.database,
            data: {
              'spaceId': spaceId,
              'error': snapshot.error.toString(),
            },
          );
        }

        final bool hasPreviews = snapshot.hasData &&
            snapshot.data!.docs.isNotEmpty;

        if (!hasTime && !hasPreviews) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (hasPreviews)
                Flexible(child: GramPreviewMedia.buildMiniPostStack(
                  context: context,
                  rawPosts: snapshot.data!.docs.map((doc) {
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
                  gramId: widget.gram,
                  randomBase: _randomBase,
                  stableRandomInRange: _stableRandomInRange,
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
      color = AppTheme.successColor;
    } else if (diff.inHours < 24) {
      color = AppTheme.warningColor;
    } else {
      color = isDark ? AppTheme.textSecondaryDarkColor : AppTheme.textSecondaryLightColor;
    }

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

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _updatedSubscription?.cancel();
    _postPreviewsStream = null;
    _cachedSpaceIdForStream = null;
    super.dispose();
  }
}
