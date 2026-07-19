import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:aurogram/features/spaces/presentation/grams/gram_skeleton_widgets.dart';
import 'package:aurogram/features/spaces/presentation/grams/grams_app_bar.dart';
import 'package:aurogram/features/spaces/presentation/grams/grams_desktop_layout.dart';
import 'package:aurogram/features/spaces/presentation/grams/grams_public_section.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:aurogram/features/profile/presentation/widgets/preview_boxes/gram_preview_box.dart';
import 'package:aurogram/features/spaces/domain/space_service.dart';
import 'package:aurogram/core/di/injection.dart';
import 'package:aurogram/core/theme/header_style.dart';
import 'package:aurogram/core/logging/app_logger.dart';
import 'package:aurogram/shared/presentation/widgets/universal/transparent_toolbox.dart';
import 'package:aurogram/shared/services/search_service.dart';
import 'package:aurogram/shared/presentation/responsive/responsive.dart';
import 'package:aurogram/shared/models/space.dart';

class Grams extends StatefulWidget {
  const Grams({super.key});

  @override
  GramsState createState() => GramsState();
}

class GramsState extends State<Grams> with AutomaticKeepAliveClientMixin {
  final User? _user = FirebaseAuth.instance.currentUser;
  final CollectionReference _userSpacesCollection =
      FirebaseFirestore.instance.collection('userSpaces');
  final CollectionReference _spacesCollection =
      FirebaseFirestore.instance.collection('spaces');
  final FocusNode _searchFocusNode = FocusNode();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  late final Stream<QuerySnapshot> _spacesStream;
  bool _validatedOnce = false;
  final Map<String, Widget> _gramItemCache = {};
  final Map<String, Timestamp?> _lastUpdatedMap = {};
  final Map<String, StreamSubscription<DocumentSnapshot>>
      _updatedSubscriptions = {};
  bool _isRefreshing = false;
  int _reloadToken = 0;

  // Search optimization
  Timer? _searchDebounceTimer;
  final Map<String, Map<String, dynamic>> _gramDataCache =
      {}; // Cache gram data

  // State caching - prevents reload on navigation
  List<QueryDocumentSnapshot>? _cachedGrams;
  bool _initialLoadComplete = false;
  final Set<String> _prefetchedSpaceIds = <String>{};

  // Public grams cache for explorer view
  List<QueryDocumentSnapshot>? _cachedPublicGrams;
  bool _publicGramsLoaded = false;

  // Desktop master-detail state
  String? _selectedGramId;
  Space? _selectedGram;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    // Create the stream once to avoid resubscription on rebuilds
    if (_user != null) {
      _spacesStream = _userSpacesCollection
          .doc(_user!.uid)
          .collection('spaces')
          .where('role', whereIn: ['member', 'owner', 'creator']).snapshots();
    } else {
      _spacesStream = const Stream<QuerySnapshot>.empty();
    }
    _loadPublicGrams();
  }

  /// Handle search query changes
  void _onSearchChanged(String query) {
    // Cancel previous timer
    _searchDebounceTimer?.cancel();

    // If query is empty, update immediately
    if (query.trim().isEmpty) {
      setState(() {
        _searchQuery = query;
        // Don't clear cache - just filter what's displayed
      });
      return;
    }

    // Debounce search for 300ms
    _searchDebounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _searchQuery = query; // Keep original case for smart matching
          // Don't clear cache - just filter what's displayed
        });
      }
    });
  }

  Widget _buildGramList() {
    if (_user == null) {
      return GramsPublicList(
        publicGramsLoaded: _publicGramsLoaded,
        cachedPublicGrams: _cachedPublicGrams,
        searchQuery: _searchQuery,
        buildPublicGramItem: _buildPublicGramItem,
        skeleton: const GramSkeletonGrid(),
        onLoadPublicGrams: _loadPublicGrams,
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _spacesStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !_initialLoadComplete) {
          return const GramSkeletonGrid();
        }
        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          _cachedGrams = snapshot.data!.docs;
          _initialLoadComplete = true;
          // Batch-prefetch all space docs in ONE Firestore query so that
          // each GramPreviewBox can serve from cache instead of making its
          // own round-trip. Idempotent + fire-and-forget.
          _maybePrefetchSpaces(_cachedGrams!);
        }
        final spaceDocs = _cachedGrams ?? snapshot.data?.docs ?? [];

        if (spaceDocs.isEmpty) {
          return GramsPublicExplorer(
            publicGramsLoaded: _publicGramsLoaded,
            cachedPublicGrams: _cachedPublicGrams,
            searchQuery: _searchQuery,
            buildGramItem: _buildGramItem,
            skeleton: const GramSkeletonGrid(),
            onLoadPublicGrams: _loadPublicGrams,
          );
        }

        if (_searchQuery.trim().isNotEmpty) {
          return FutureBuilder<List<QueryDocumentSnapshot>>(
            future: _filterGramsByQuery(spaceDocs, _searchQuery.trim()),
            builder: (context, filterSnapshot) {
              if (filterSnapshot.connectionState == ConnectionState.waiting) {
                return Opacity(
                  opacity: 0.7,
                  child: _buildFilteredGramList(List.from(spaceDocs)),
                );
              }
              return _buildSearchResults(filterSnapshot.data ?? const []);
            },
          );
        }
        return _buildFilteredGramList(List.from(spaceDocs));
      },
    );
  }

  /// Helper to build search results with common parameters.
  Widget _buildSearchResults(List<QueryDocumentSnapshot> userGrams) {
    return GramsSearchResults(
      userGrams: userGrams,
      publicGramsLoaded: _publicGramsLoaded,
      cachedPublicGrams: _cachedPublicGrams,
      searchQuery: _searchQuery,
      lastUpdatedMap: _lastUpdatedMap,
      buildGramItem: _buildGramItem,
      skeleton: const GramSkeletonGrid(),
      onLoadPublicGrams: _loadPublicGrams,
    );
  }

  /// Fetch space data and filter by query.
  ///
  /// Tries the in-memory caches first (SpaceService.spaceCache and our
  /// local _gramDataCache). Only spaces missing from both caches incur a
  /// network round-trip, and those are batched in parallel.
  Future<List<QueryDocumentSnapshot>> _filterGramsByQuery(
      List<QueryDocumentSnapshot> docs, String query) async {
    final SpaceService? spaceService =
        locator.isRegistered<SpaceService>() ? locator<SpaceService>() : null;

    Future<MapEntry<QueryDocumentSnapshot, Map<String, dynamic>?>> resolve(
        QueryDocumentSnapshot doc) async {
      final spaceId = doc.id;

      // 1. Local search cache.
      final localHit = _gramDataCache[spaceId];
      if (localHit != null) return MapEntry(doc, localHit);

      // 2. SpaceService in-memory cache (no network).
      final cached = spaceService?.spaceCache[spaceId];
      if (cached != null) {
        final json = {
          'name': cached.name,
          'description': cached.description,
        };
        _gramDataCache[spaceId] = json;
        return MapEntry(doc, json);
      }

      // 3. Last resort — fetch via SpaceService (which has its own retry +
      // negative cache + 10s timeout, so we don't replicate any of that).
      try {
        if (spaceService == null) return MapEntry(doc, null);
        final space = await spaceService.getSpace(spaceId);
        final json = {'name': space.name, 'description': space.description};
        _gramDataCache[spaceId] = json;
        return MapEntry(doc, json);
      } catch (_) {
        return MapEntry(doc, null);
      }
    }

    final results = await Future.wait(docs.map(resolve));

    final List<QueryDocumentSnapshot> matchingDocs = [];
    for (final entry in results) {
      final spaceData = entry.value;
      if (spaceData == null) continue;
      final spaceName = (spaceData['name'] ?? '').toString();
      final spaceDescription = (spaceData['description'] ?? '').toString();
      if (SearchService.smartMatch(query, spaceName) ||
          SearchService.smartMatch(query, spaceDescription)) {
        matchingDocs.add(entry.key);
      }
    }
    return matchingDocs;
  }

  /// Build the filtered/sorted gram list
  Widget _buildFilteredGramList(List<QueryDocumentSnapshot> filteredDocs) {
    // Ensure we are listening for updates for these grams to enable real-time sorting
    _ensureUpdatedSubscriptions(
        filteredDocs.map((d) => d.id).toList(growable: false));

    // Sort by latest activity (spaces.lastPostAt/updated) descending with stable tiebreaker
    List<QueryDocumentSnapshot> sortedDocs = List.from(filteredDocs);
    sortedDocs.sort((a, b) {
      final Timestamp? aUpdated = _lastUpdatedMap[a.id];
      final Timestamp? bUpdated = _lastUpdatedMap[b.id];

      if (aUpdated != null && bUpdated != null) {
        final int cmp = bUpdated.compareTo(aUpdated);
        if (cmp != 0) return cmp;
        // Stable tiebreaker by id to prevent jitter between rebuilds
        return a.id.compareTo(b.id);
      }
      if (aUpdated == null && bUpdated == null) {
        final aData = a.data() as Map<String, dynamic>;
        final bData = b.data() as Map<String, dynamic>;
        final Timestamp? aFallback = (aData['joinedAt'] as Timestamp?) ??
            (aData['timestamp'] as Timestamp?) ??
            (aData['updatedAt'] as Timestamp?);
        final Timestamp? bFallback = (bData['joinedAt'] as Timestamp?) ??
            (bData['timestamp'] as Timestamp?) ??
            (bData['updatedAt'] as Timestamp?);
        if (aFallback != null && bFallback != null) {
          final int cmp = bFallback.compareTo(aFallback);
          if (cmp != 0) return cmp;
          return a.id.compareTo(b.id);
        }
        if (aFallback != null) return -1;
        if (bFallback != null) return 1;
        return a.id.compareTo(b.id);
      }
      if (bUpdated != null) return 1;
      return -1;
    });

    // Cleanup of orphaned grams now happens lazily in SpaceService.getSpace
    // (which calls cleanupMissingSpace on a confirmed not-exists doc). Doing
    // it eagerly here used to fire one extra getSpace() call per gram on
    // every screen rebuild, which compounded the listener storm. The
    // _handleRefresh path still triggers a batch validation explicitly.

    // Get user's gram IDs to filter out from public grams
    final userGramIds = sortedDocs.map((d) => d.id).toSet();

    return Column(
      children: [
        const SizedBox(height: AppHeaderStyle.contentTopPadding),
        // User's own grams grouped with an elegant heading
        if (sortedDocs.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                Text(
                  'PRIVATE',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: Theme.of(context).brightness == Brightness.dark 
                        ? const Color(0xFFEEEEEE) 
                        : const Color(0xFF444444),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    height: 1,
                    color: Theme.of(context).brightness == Brightness.dark 
                        ? const Color(0xFF333333) 
                        : const Color(0xFFEEEEEE),
                  ),
                ),
              ],
            ),
          ),
        Wrap(
          children:
              sortedDocs.map((document) => _buildGramItem(document)).toList(),
        ),
        // Public grams section below user's grams
        GramsPublicSection(
          userGramIds: userGramIds,
          publicGramsLoaded: _publicGramsLoaded,
          cachedPublicGrams: _cachedPublicGrams,
          searchQuery: _searchQuery,
          buildGramItem: _buildGramItem,
          onLoadPublicGrams: _loadPublicGrams,
        ),
        SizedBox(height: AppHeaderStyle.contentBottomPadding + 50),
      ],
    );
  }

  bool _publicGramsLoading = false;

  /// Load public grams once and cache.
  ///
  /// Guarded by [_publicGramsLoaded] (idempotent) and [_publicGramsLoading]
  /// (re-entrancy). Both must be reset by callers wanting a refresh — see
  /// [_handleRefresh] which clears [_publicGramsLoaded] back to false. The
  /// loading flag is reset in `finally` so a failed/aborted load doesn't
  /// poison the next refresh attempt.
  Future<void> _loadPublicGrams() async {
    if (_publicGramsLoaded || _publicGramsLoading) return;
    _publicGramsLoading = true;
    AppLogger.d('Loading public grams', category: LogCategory.database);
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('spaces')
          .where('spaceType', whereIn: [0, 1])
          .limit(30) // Reasonable limit for discovery
          .get();

      // Filter valid public grams
      _cachedPublicGrams = snapshot.docs.where((doc) {
        final data = doc.data();
        final spaceType = data['spaceType'] as int? ?? 3;
        final limitedVisibility = data['limitedVisibility'] as bool? ?? false;
        return (spaceType == 0 || spaceType == 1) && !limitedVisibility;
      }).toList();

      _publicGramsLoaded = true;
      AppLogger.d('Public grams loaded',
          category: LogCategory.database,
          data: {'count': _cachedPublicGrams!.length});
      if (mounted) setState(() {});
    } catch (e) {
      AppLogger.e('Failed to load public grams',
          category: LogCategory.database,
          error: e,
          data: {'error': e.toString()});
      _publicGramsLoaded = true;
      _cachedPublicGrams = [];
      if (mounted) setState(() {});
    } finally {
      // CRITICAL: must reset so the next refresh can proceed. Without this
      // the flag was stuck at true after the first load, making refresh a
      // no-op and the public-grams section vanish (cleared cache + guard
      // refused to re-fetch).
      _publicGramsLoading = false;
    }
  }

  /// Build a gram item for public grams (for unauthenticated users)
  Widget _buildPublicGramItem(QueryDocumentSnapshot doc) {
    final String id = doc.id;
    final bool isWideLayout = Responsive.isWideLayout(context);

    return GestureDetector(
      key: ValueKey(id),
      onTap: () {
        if (isWideLayout) {
          _selectGram(id);
        } else {
          context.push('/space/$id');
        }
      },
      child: GramPreviewBox(
        key: ValueKey(id),
        gram: id,
        showChatButton: !isWideLayout,
        reloadToken: _reloadToken,
        lastUpdated: _lastUpdatedMap[id],
      ),
    );
  }



  Widget _buildGramItem(QueryDocumentSnapshot document) {
    final String id = document.id;
    final bool isWideLayout = Responsive.isWideLayout(context);

    // We can't cache the widget when the timestamp can change, since the
    // last-updated badge needs to reflect new posts. Cache only in narrow
    // layout where there's no master/detail selection state, AND only when
    // we already have a fresh timestamp.
    final cachedTs = _lastUpdatedMap[id];
    if (!isWideLayout && _gramItemCache.containsKey(id)) {
      return _gramItemCache[id]!;
    }

    final widgetItem = GestureDetector(
      key: ValueKey(id),
      onTap: () {
        if (isWideLayout) {
          _selectGram(id);
        } else {
          context.push('/space/$id');
        }
      },
      child: GramPreviewBox(
        key: ValueKey(id),
        gram: id,
        showChatButton: !isWideLayout,
        reloadToken: _reloadToken,
        lastUpdated: cachedTs,
      ),
    );

    if (!isWideLayout && cachedTs != null) {
      _gramItemCache[id] = widgetItem;
    }
    return widgetItem;
  }

  /// Batch-prefetch space details for all visible grams in a single
  /// Firestore query (chunked to 30 IDs per `whereIn`). This eliminates
  /// the N+1 problem where every [GramPreviewBox] would otherwise trigger
  /// its own getSpace() round-trip.
  ///
  /// Idempotent: skips IDs already prefetched in this session.
  void _maybePrefetchSpaces(List<QueryDocumentSnapshot> docs) {
    if (!locator.isRegistered<SpaceService>()) return;
    final newIds = docs
        .map((d) => d.id)
        .where((id) => id.isNotEmpty && !_prefetchedSpaceIds.contains(id))
        .toList(growable: false);
    if (newIds.isEmpty) return;
    _prefetchedSpaceIds.addAll(newIds);
    unawaited(locator<SpaceService>().prefetchSpaces(newIds));
  }

  void _ensureUpdatedSubscriptions(List<String> spaceIds) {
    // Remove subscriptions for spaces no longer present
    final toRemove = _updatedSubscriptions.keys
        .where((id) => !spaceIds.contains(id))
        .toList(growable: false);
    for (final id in toRemove) {
      _updatedSubscriptions[id]?.cancel();
      _updatedSubscriptions.remove(id);
      _lastUpdatedMap.remove(id);
      _gramItemCache.remove(id);
    }

    // Add subscriptions for new spaces - LIMIT to 5 at a time with staggered delays
    // This prevents timeout storms from 20+ concurrent Firestore listeners
    final newIds = spaceIds
        .where((id) => !_updatedSubscriptions.containsKey(id))
        .take(5) // Only add up to 5 new subscriptions per call
        .toList();

    for (int i = 0; i < newIds.length; i++) {
      final id = newIds[i];
      // Stagger subscriptions by 100ms to avoid request storms
      Future.delayed(Duration(milliseconds: i * 100), () {
        if (!mounted || _updatedSubscriptions.containsKey(id)) return;

        // ignore: cancel_subscriptions — stored in _updatedSubscriptions and cancelled in dispose
        final sub = FirebaseFirestore.instance
            .collection('spaces')
            .doc(id)
            .snapshots()
            .listen((doc) {
          Timestamp? updated;
          if (doc.exists) {
            final data = doc.data();
            if (data is Map<String, dynamic>) {
              updated = data['lastPostAt'] as Timestamp? ??
                  data['updated'] as Timestamp? ??
                  data['lastActivity'] as Timestamp?;
            }
          }
          // Only trigger rebuild if timestamp actually changed
          final previousUpdated = _lastUpdatedMap[id];
          if (previousUpdated?.millisecondsSinceEpoch !=
              updated?.millisecondsSinceEpoch) {
            _lastUpdatedMap[id] = updated;
            // Invalidate the cached widget so the new badge renders.
            _gramItemCache.remove(id);
            _scheduleRebuild();
          }
        });
        _updatedSubscriptions[id] = sub;
      });
    }
  }

  // Debounce rebuilds to prevent excessive setState calls
  Timer? _rebuildDebounce;
  void _scheduleRebuild() {
    _rebuildDebounce?.cancel();
    _rebuildDebounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final bool isWideLayout = Responsive.isWideLayout(context);

    // In wide layout (desktop / iPad landscape), use master-detail layout
    if (isWideLayout) {
      return Scaffold(
        extendBody: true,
        backgroundColor: Colors.transparent,
        body: GramsDesktopLayout(
          isRefreshing: _isRefreshing,
          selectedGramId: _selectedGramId,
          selectedGram: _selectedGram,
          searchController: _searchController,
          searchFocusNode: _searchFocusNode,
          onSearchChanged: _onSearchChanged,
          onShowCreationDialog: _showCreationDialog,
          onClearSelection: () {
            setState(() {
              _selectedGramId = null;
              _selectedGram = null;
            });
          },
          onRefresh: _handleRefresh,
          uploadIndicator: const GramsUploadIndicator(),
          gramList: _buildGramList(),
        ),
      );
    }

    // Mobile layout
    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        onTap: () {
          // Dismiss keyboard when tapping outside
          _searchFocusNode.unfocus();
        },
        child: Stack(
          children: [
            // Main content
            CustomScrollView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              cacheExtent: 600,
              slivers: [
                // Header
                buildGramsSliverAppBar(
                  context: context,
                  isRefreshing: _isRefreshing,
                  hasUser: _user != null,
                  onShowCreationDialog: _showCreationDialog,
                  onShowInvites: _showInvites,
                ),
                // Pull to refresh - hidden indicator, title shimmers instead
                CupertinoSliverRefreshControl(
                  onRefresh: _handleRefresh,
                  builder: (context, refreshState, pulledExtent,
                      refreshTriggerPullDistance, refreshIndicatorExtent) {
                    return const SizedBox.shrink();
                  },
                ),
                // Content
                SliverToBoxAdapter(
                  child: AnimatedOpacity(
                    opacity: _isRefreshing ? 0.7 : 1.0,
                    duration: const Duration(milliseconds: 200),
                    child: _buildGramList(),
                  ),
                ),
                // Add bottom padding so content isn't hidden behind toolbox
                SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
            // Toolbox positioned as overlay at bottom
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: TransparentToolbox.search(
                searchController: _searchController,
                focusNode: _searchFocusNode,
                onSearchChanged: _onSearchChanged,
                hintText: 'Search',
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Handle gram selection for desktop - loads the Space and updates state
  Future<void> _selectGram(String gramId) async {
    try {
      final spaceService = locator<SpaceService>();
      final space = await spaceService.getSpace(gramId);

      if (mounted) {
        setState(() {
          _selectedGramId = gramId;
          _selectedGram = space;
        });
      }
    } catch (e) {
      AppLogger.e('Error loading gram for selection',
          category: LogCategory.general,
          data: {'gramId': gramId, 'error': e.toString()});
    }
  }

  /// Show the gram creation dialog
  void _showCreationDialog() {
    context.push('/space/create');
  }

  /// Navigate to gram invites page
  void _showInvites() {
    context.push('/invites');
  }

  Future<void> _handleRefresh() async {
    if (_isRefreshing) return;
    if (mounted) setState(() => _isRefreshing = true);
    await Future.delayed(Duration.zero);
    try {
      _gramItemCache.clear();
      _gramDataCache.clear();
      _prefetchedSpaceIds.clear();
      GramPreviewBox.clearSpaceCache();
      if (locator.isRegistered<SpaceService>()) {
        locator<SpaceService>().clearSpaceCache();
      }
      _publicGramsLoaded = false;
      _cachedPublicGrams = null;
      await _reloadUpdatedTimestamps();
      _reloadToken++;
      _validateGramsInBackground();
      if (mounted) setState(() {});
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  Future<void> _reloadUpdatedTimestamps() async {
    if (_user == null) return;
    try {
      final snap = await _userSpacesCollection.doc(_user!.uid)
          .collection('spaces')
          .where('role', whereIn: ['member', 'owner', 'creator']).get();
      // Fetch all space docs in parallel instead of sequentially
      await Future.wait(snap.docs.map((d) async {
        try {
          final doc = await _spacesCollection.doc(d.id).get();
          final data = doc.exists ? doc.data() as Map<String, dynamic>? : null;
          _lastUpdatedMap[d.id] = data?['lastPostAt'] as Timestamp? ??
              data?['updated'] as Timestamp? ??
              data?['lastActivity'] as Timestamp?;
        } catch (_) {}
      }));
    } catch (_) {}
  }

  Future<void> _validateGramsInBackground() async {
    if (_validatedOnce || _user == null) return;
    _validatedOnce = true;
    try {
      final spaceService = locator<SpaceService>();
      final invalidSpaces = await spaceService.batchValidateUserSpaces(_user!.uid);
      if (invalidSpaces.isNotEmpty) {
        await spaceService.batchCleanupInvalidSpaces(_user!.uid, invalidSpaces);
        if (mounted) setState(() {});
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _rebuildDebounce?.cancel();
    for (final sub in _updatedSubscriptions.values) {
      sub.cancel();
    }
    _updatedSubscriptions.clear();
    _searchDebounceTimer?.cancel();
    _searchFocusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }
}
