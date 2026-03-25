import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:aurogram/pages/helpers/gram_creation_page.dart'
    show SpaceCreationPage;
import 'package:aurogram/pages/uploads/uploads_page.dart';
import 'package:aurogram/services/cache_service.dart';
import 'package:aurogram/services/media/media_compression_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:aurogram/pages/spaces/space_screen.dart';
import 'package:aurogram/widgets/preview_boxes/gram_preview_box.dart';
import 'package:aurogram/services/space_service.dart';
import 'package:aurogram/utils/dependency_injection.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:aurogram/utils/theme/header_style.dart';
import 'package:aurogram/utils/logging/app_logger.dart';
import 'package:aurogram/widgets/universal/transparent_toolbox.dart';
import 'package:aurogram/services/search_service.dart';
import 'package:aurogram/widgets/ui/skeleton_widgets.dart';
import 'package:aurogram/widgets/ui/gradient_separator.dart';
import 'package:aurogram/utils/responsive.dart';
import 'package:aurogram/models/space.dart';
import 'package:aurogram/widgets/theatre/embedded_theatre_view.dart';
import 'package:aurogram/pages/invites.dart';

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
    _prefetchFirstVideos();
  }

  Future<void> _prefetchFirstVideos() async {
    if (_user == null) return;

    try {
      QuerySnapshot spacesSnapshot = await _userSpacesCollection
          .doc(_user!.uid)
          .collection('spaces')
          .where('role', whereIn: ['member', 'owner', 'creator'])
          .limit(10) // Fetch more to account for filtering
          .get();

      // Create a queue of grams to prefetch
      final gramsToPrefetch = spacesSnapshot.docs.take(5).toList();

      // Process grams one at a time with delay to avoid overloading network
      for (int i = 0; i < gramsToPrefetch.length && i < 3; i++) {
        final gramDoc = gramsToPrefetch[i];
        String gramId = gramDoc.id;

        try {
          String? firstVideoUrl = await _getFirstVideoUrl(gramId);
          if (firstVideoUrl != null) {
            await _downloadMusic(gramDoc.data() as Map<String, dynamic>);
          }

          // Add a small delay between downloads
          await Future.delayed(Duration(milliseconds: 200));
        } catch (e) {
          // Silently ignore errors for prefetching
        }
      }
    } catch (e) {
      // Ignore errors for prefetching
    }
  }

  Future<String?> _getFirstVideoUrl(String spaceId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('posts')
          .where('space', isEqualTo: spaceId)
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs.first.data()['video'] as String?;
      }
    } catch (e) {
      AppLogger.e('Error fetching first video URL',
          category: LogCategory.media, data: {'error': e.toString()});
    }
    return null;
  }

  /// Downloads music file from the given space data
  Future<void> _downloadMusic(Map<String, dynamic> item) async {
    if (item["music_url"] != null) {
      try {
        final cacheService = locator<CacheService>();
        await cacheService.downloadFile(item["music_url"]);
      } catch (e) {
        // Silently ignore download errors during prefetching
      }
    }
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
    // If user is not authenticated, show public grams instead
    if (_user == null) {
      return _buildPublicGramsList();
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _spacesStream,
      builder: (context, snapshot) {
        // Use cached data while waiting to prevent flicker
        if (snapshot.connectionState == ConnectionState.waiting &&
            !_initialLoadComplete) {
          // Show skeleton placeholders on first load only
          return _buildSkeletonGrid(context);
        }

        // Cache the grams data
        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          _cachedGrams = snapshot.data!.docs;
          _initialLoadComplete = true;
        }

        // Use cached data if available, otherwise show empty state
        final spaceDocs = _cachedGrams ?? snapshot.data?.docs ?? [];

        if (spaceDocs.isEmpty) {
          // Show public grams to explore instead of empty state
          return _buildPublicGramsExplorer();
        }

        List<QueryDocumentSnapshot> filteredDocs = List.from(spaceDocs);
        if (_searchQuery.trim().isNotEmpty) {
          final query = _searchQuery.trim();

          // Need to fetch actual space data - use FutureBuilder with cached state
          return FutureBuilder<List<QueryDocumentSnapshot>>(
            future: _filterGramsByQuery(spaceDocs, query),
            builder: (context, filterSnapshot) {
              // Show current filtered results while loading new ones (no spinner)
              if (filterSnapshot.connectionState == ConnectionState.waiting) {
                // Just show existing list with subtle opacity
                return Opacity(
                  opacity: 0.7,
                  child: _buildFilteredGramList(filteredDocs),
                );
              }

              if (!filterSnapshot.hasData || filterSnapshot.data!.isEmpty) {
                // No user grams match, but still show matching public grams
                return _buildSearchResultsWithPublicGrams([]);
              }

              // Show both user's matching grams and matching public grams
              return _buildSearchResultsWithPublicGrams(filterSnapshot.data!);
            },
          );
        }

        return _buildFilteredGramList(filteredDocs);
      },
    );
  }

  /// Skeleton grid for initial loading - instant display with shimmer
  /// Matches the actual GramPreviewBox card dimensions (full width, ~88px height)
  Widget _buildSkeletonGrid(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        children: [
          const SizedBox(height: AppHeaderStyle.contentTopPadding),
          // Generate 5 skeleton items - no delay, instant display
          ...List.generate(5, (index) => _buildSkeletonItem(context, index)),
          SizedBox(height: AppHeaderStyle.contentBottomPadding + 50),
        ],
      ),
    );
  }

  /// Single skeleton item - matches GramPreviewBox layout with shimmer animation
  /// Uses warm beige colors consistent with feed and chat skeletons
  Widget _buildSkeletonItem(BuildContext context, [int index = 0]) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color cardColor = isDark ? AppTheme.cardDarkColor : Colors.white;
    // Warm beige colors matching feed skeleton
    final Color placeholder =
        isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE8E0D5);
    final Color placeholderDark =
        isDark ? Colors.white.withValues(alpha: 0.14) : const Color(0xFFD8CFC2);

    // Vary widths for organic look
    final titleWidths = [130.0, 110.0, 145.0, 120.0, 135.0];
    final subtitleWidths = [80.0, 65.0, 90.0, 75.0, 85.0];

    return Padding(
      padding: EdgeInsets.fromLTRB(
          AppHeaderStyle.contentHorizontalPadding,
          0,
          AppHeaderStyle.contentHorizontalPadding,
          AppHeaderStyle.cardVerticalGap),
      child: Material(
        color: cardColor,
        elevation: isDark ? 2 : 1,
        shadowColor: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
        borderRadius: BorderRadius.circular(AppHeaderStyle.cardBorderRadius),
        child: ShimmerBox(
          child: Container(
            height: AppHeaderStyle.cardRegularHeight,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Avatar placeholder
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: placeholderDark,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 16),
                // Content area
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
                            width: titleWidths[index % titleWidths.length],
                            height: 14,
                            decoration: BoxDecoration(
                              color: placeholderDark,
                              borderRadius: BorderRadius.circular(7),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            width:
                                subtitleWidths[index % subtitleWidths.length],
                            height: 10,
                            decoration: BoxDecoration(
                              color: placeholder,
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ),
                        ],
                      ),
                      // Mini previews placeholder row
                      Row(
                        children: List.generate(
                            4,
                            (i) => Transform.translate(
                                  offset: Offset(-i * 8.0, 0),
                                  child: Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: placeholder,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                          color: cardColor, width: 2),
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

  /// Fetch space data and filter by query (optimized with parallel fetching and caching)
  Future<List<QueryDocumentSnapshot>> _filterGramsByQuery(
      List<QueryDocumentSnapshot> docs, String query) async {
    // Fetch all space data in parallel
    final fetchFutures = docs.map((doc) async {
      final spaceId = doc.id;

      // Check cache first
      if (_gramDataCache.containsKey(spaceId)) {
        return MapEntry(doc, _gramDataCache[spaceId]!);
      }

      // Fetch from Firestore
      try {
        final spaceDoc = await FirebaseFirestore.instance
            .collection('spaces')
            .doc(spaceId)
            .get();

        if (!spaceDoc.exists || spaceDoc.data() == null) {
          return MapEntry<QueryDocumentSnapshot, Map<String, dynamic>?>(
              doc, null);
        }

        final spaceData = spaceDoc.data()!;
        // Cache it
        _gramDataCache[spaceId] = spaceData;
        return MapEntry(doc, spaceData);
      } catch (e) {
        return MapEntry<QueryDocumentSnapshot, Map<String, dynamic>?>(
            doc, null);
      }
    }).toList();

    // Wait for all fetches to complete
    final results = await Future.wait(fetchFutures);

    // Filter based on query
    final List<QueryDocumentSnapshot> matchingDocs = [];
    for (final entry in results) {
      final doc = entry.key;
      final spaceData = entry.value;

      if (spaceData == null) continue;

      final spaceName = (spaceData['name'] ?? '').toString();
      final spaceDescription = (spaceData['description'] ?? '').toString();

      // Try smart matching
      if (SearchService.smartMatch(query, spaceName) ||
          SearchService.smartMatch(query, spaceDescription)) {
        matchingDocs.add(doc);
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

    // Validate only once on initial data to avoid repeated rebuild side-effects
    if (!_validatedOnce) {
      _validatedOnce = true;
      _validateUserGrams(filteredDocs);
    }

    // Get user's gram IDs to filter out from public grams
    final userGramIds = sortedDocs.map((d) => d.id).toSet();

    return Column(
      children: [
        const SizedBox(height: AppHeaderStyle.contentTopPadding),
        // User's own grams first
        Wrap(
          children:
              sortedDocs.map((document) => _buildGramItem(document)).toList(),
        ),
        // Public grams section below user's grams
        _buildPublicGramsSection(userGramIds),
        SizedBox(height: AppHeaderStyle.contentBottomPadding + 50),
      ],
    );
  }

  /// Build public grams section to show below user's own grams
  Widget _buildPublicGramsSection(Set<String> userGramIds) {
    // Load public grams if not loaded
    if (!_publicGramsLoaded) {
      _loadPublicGrams();
      return const SizedBox.shrink(); // Will rebuild once loaded
    }

    // No public grams available
    if (_cachedPublicGrams == null || _cachedPublicGrams!.isEmpty) {
      return const SizedBox.shrink();
    }

    // Filter out user's own grams from public grams
    List<QueryDocumentSnapshot> publicGrams = _cachedPublicGrams!
        .where((doc) => !userGramIds.contains(doc.id))
        .toList();

    // Apply search filter if active
    if (_searchQuery.trim().isNotEmpty) {
      final query = _searchQuery.trim();
      publicGrams = publicGrams.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final spaceName = data['name'] as String? ?? '';
        final spaceDescription = data['description'] as String? ?? '';
        return SearchService.smartMatch(query, spaceName) ||
            SearchService.smartMatch(query, spaceDescription);
      }).toList();
    }

    // No public grams to show after filtering
    if (publicGrams.isEmpty) {
      return const SizedBox.shrink();
    }

    // Show public grams with a subtle divider/label
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Subtle divider with label
        Column(
          children: [
            const GradientSeparator(
              padding: EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            ),
            Center(
              child: Text(
                'discover',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.5),
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
        // Public grams grid
        Wrap(
          children:
              publicGrams.map((document) => _buildGramItem(document)).toList(),
        ),
      ],
    );
  }

  /// Build search results showing both user's grams and public grams
  Widget _buildSearchResultsWithPublicGrams(
      List<QueryDocumentSnapshot> userGrams) {
    // Load public grams if not loaded
    if (!_publicGramsLoaded) {
      _loadPublicGrams();
      // Show skeleton while loading
      return _buildSkeletonGrid(context);
    }

    // Get user's gram IDs to filter out duplicates
    final userGramIds = userGrams.map((d) => d.id).toSet();

    // Filter public grams by search query and exclude user's grams
    List<QueryDocumentSnapshot> matchingPublicGrams = [];
    if (_cachedPublicGrams != null && _cachedPublicGrams!.isNotEmpty) {
      final query = _searchQuery.trim();
      matchingPublicGrams = _cachedPublicGrams!.where((doc) {
        // Exclude user's own grams
        if (userGramIds.contains(doc.id)) return false;

        // Apply search filter
        final data = doc.data() as Map<String, dynamic>;
        final spaceName = data['name'] as String? ?? '';
        final spaceDescription = data['description'] as String? ?? '';
        return SearchService.smartMatch(query, spaceName) ||
            SearchService.smartMatch(query, spaceDescription);
      }).toList();
    }

    // If both are empty, show "No grams found"
    if (userGrams.isEmpty && matchingPublicGrams.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: AppHeaderStyle.contentTopPadding),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 60),
              Icon(
                Icons.search_off,
                size: 64,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.4),
              ),
              SizedBox(height: 16),
              Text(
                'No grams found',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontSize: 18,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.8),
                    ),
              ),
              SizedBox(height: 8),
              Text(
                'Try a different search term',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.6),
                    ),
              ),
            ],
          ),
        ),
      );
    }

    // Sort user's grams by latest activity
    List<QueryDocumentSnapshot> sortedUserGrams = List.from(userGrams);
    sortedUserGrams.sort((a, b) {
      final Timestamp? aUpdated = _lastUpdatedMap[a.id];
      final Timestamp? bUpdated = _lastUpdatedMap[b.id];
      if (aUpdated != null && bUpdated != null) {
        return bUpdated.compareTo(aUpdated);
      }
      if (bUpdated != null) return 1;
      if (aUpdated != null) return -1;
      return a.id.compareTo(b.id);
    });

    return Column(
      children: [
        const SizedBox(height: AppHeaderStyle.contentTopPadding),
        // User's matching grams first
        if (sortedUserGrams.isNotEmpty)
          Wrap(
            children: sortedUserGrams
                .map((document) => _buildGramItem(document))
                .toList(),
          ),
        // Matching public grams below
        if (matchingPublicGrams.isNotEmpty) ...[
          if (sortedUserGrams.isNotEmpty)
            Column(
              children: [
                const GradientSeparator(
                  padding: EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                ),
                Center(
                  child: Text(
                    'discover',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.5),
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          Wrap(
            children: matchingPublicGrams
                .map((document) => _buildGramItem(document))
                .toList(),
          ),
        ],
        SizedBox(height: AppHeaderStyle.contentBottomPadding + 50),
      ],
    );
  }

  /// Shows public grams when user has no grams - gives them something to explore
  /// Uses caching to prevent excessive rebuilds
  Widget _buildPublicGramsExplorer() {
    // Load public grams once if not loaded
    if (!_publicGramsLoaded) {
      _loadPublicGrams();
      return _buildSkeletonGrid(context);
    }

    // Use cached data
    if (_cachedPublicGrams == null || _cachedPublicGrams!.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 80.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.groups_outlined,
                size: 64,
                color: AppTheme.primaryColor.withValues(alpha: 0.6),
              ),
              SizedBox(height: 16),
              Text(
                'Create Your First Gram',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              SizedBox(height: 8),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  'Start a gram and invite your friends to share content together',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.7),
                      ),
                  textAlign: TextAlign.center,
                ),
              ),
              SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SpaceCreationPage(),
                    ),
                  );
                },
                icon: Icon(Icons.add),
                label: Text('Create Gram'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Apply search filter from cached data
    List<QueryDocumentSnapshot> publicGrams = _cachedPublicGrams!;
    if (_searchQuery.trim().isNotEmpty) {
      final query = _searchQuery.trim();
      publicGrams = _cachedPublicGrams!.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final spaceName = data['name'] as String? ?? '';
        final spaceDescription = data['description'] as String? ?? '';
        return SearchService.smartMatch(query, spaceName) ||
            SearchService.smartMatch(query, spaceDescription);
      }).toList();

      if (publicGrams.isEmpty) {
        return Padding(
          padding: const EdgeInsets.only(top: AppHeaderStyle.contentTopPadding),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 60), // Visual spacing for empty state
                Icon(
                  Icons.search_off,
                  size: 64,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.4),
                ),
                SizedBox(height: 16),
                Text(
                  'No grams found',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontSize: 18,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.8),
                      ),
                ),
                SizedBox(height: 8),
                Text(
                  'Try a different search term',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.6),
                      ),
                ),
              ],
            ),
          ),
        );
      }
    }

    // Show public grams in a clean grid
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppHeaderStyle.contentTopPadding),
        // Public grams grid
        Wrap(
          children: publicGrams.map((document) {
            return _buildGramItem(document);
          }).toList(),
        ),
        SizedBox(height: AppHeaderStyle.contentBottomPadding + 50),
      ],
    );
  }

  /// Load public grams once and cache
  Future<void> _loadPublicGrams() async {
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
      if (mounted) setState(() {});
    } catch (e) {
      _publicGramsLoaded = true;
      _cachedPublicGrams = [];
      if (mounted) setState(() {});
    }
  }

  /// Build public grams list for unauthenticated users
  /// Uses caching to prevent excessive rebuilds
  Widget _buildPublicGramsList() {
    // Load public grams once if not loaded
    if (!_publicGramsLoaded) {
      _loadPublicGrams();
      return _buildSkeletonGrid(context);
    }

    // Use cached data - show empty state if no public grams
    if (_cachedPublicGrams == null || _cachedPublicGrams!.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 80.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.groups_outlined,
                size: 64,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.4),
              ),
              SizedBox(height: 16),
              Text(
                'No public grams yet',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontSize: 18,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.8),
                    ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                'Sign in to create or join grams',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.6),
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    // Apply search filter from cached data
    List<QueryDocumentSnapshot> filteredGrams = _cachedPublicGrams!;
    if (_searchQuery.trim().isNotEmpty) {
      final query = _searchQuery.trim();
      filteredGrams = _cachedPublicGrams!.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final spaceName = data['name'] as String? ?? '';
        final spaceDescription = data['description'] as String? ?? '';
        return SearchService.smartMatch(query, spaceName) ||
            SearchService.smartMatch(query, spaceDescription);
      }).toList();

      if (filteredGrams.isEmpty) {
        return Padding(
          padding: const EdgeInsets.only(top: AppHeaderStyle.contentTopPadding),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 60), // Visual spacing for empty state
                Icon(
                  Icons.search_off,
                  size: 64,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.4),
                ),
                SizedBox(height: 16),
                Text(
                  'No grams found',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontSize: 18,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.8),
                      ),
                ),
                SizedBox(height: 8),
                Text(
                  'Try a different search term',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.6),
                      ),
                ),
              ],
            ),
          ),
        );
      }
    }

    return Column(
      children: [
        const SizedBox(height: AppHeaderStyle.contentTopPadding),
        Wrap(
          children:
              filteredGrams.map((doc) => _buildPublicGramItem(doc)).toList(),
        ),
        SizedBox(height: 150),
      ],
    );
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
          Navigator.of(context, rootNavigator: true).push(
            CupertinoPageRoute(builder: (context) => SpaceScreen(rid: id)),
          );
        }
      },
      child: GramPreviewBox(
        key: ValueKey(id),
        gram: id,
        showChatButton: !isWideLayout,
        reloadToken: _reloadToken,
      ),
    );
  }

  /// Validate grams and clean up references to non-existent ones
  Future<void> _validateUserGrams(List<QueryDocumentSnapshot> grams) async {
    if (_user == null) return;

    for (final gramDoc in grams) {
      try {
        // Try to verify the gram exists
        final spaceService = locator<SpaceService>();
        await spaceService.getSpace(gramDoc.id);
      } catch (e) {
        // Gram doesn't exist, schedule cleanup
        if (e.toString().contains('Space not found')) {
          _cleanupInvalidGram(gramDoc.id);
        }
      }
    }
  }

  /// Clean up invalid gram reference for current user
  Future<void> _cleanupInvalidGram(String gramId) async {
    if (_user == null) return;

    try {
      // Remove the reference from user's grams collection
      await _userSpacesCollection
          .doc(_user!.uid)
          .collection('spaces')
          .doc(gramId)
          .delete();

      AppLogger.d('Cleaned up invalid gram reference',
          category: LogCategory.general, data: {'gramId': gramId});
    } catch (e) {
      // Silently ignore cleanup errors
    }
  }

  Widget _buildGramItem(QueryDocumentSnapshot document) {
    final String id = document.id;
    final bool isWideLayout = Responsive.isWideLayout(context);

    // Don't cache when in wide layout since selection state changes appearance
    if (!isWideLayout && _gramItemCache.containsKey(id))
      return _gramItemCache[id]!;

    final widgetItem = GestureDetector(
      key: ValueKey(id),
      onTap: () {
        if (isWideLayout) {
          _selectGram(id);
        } else {
          Navigator.of(context, rootNavigator: true).push(
            CupertinoPageRoute(builder: (context) => SpaceScreen(rid: id)),
          );
        }
      },
      child: GramPreviewBox(
        key: ValueKey(id),
        gram: id,
        showChatButton: !isWideLayout,
        reloadToken: _reloadToken,
      ),
    );

    if (!isWideLayout) {
      _gramItemCache[id] = widgetItem;
    }
    return widgetItem;
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
        body: _buildDesktopLayout(),
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
                _buildSliverAppBar(),
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

  /// Build desktop master-detail layout with gram list on left and chat on right
  Widget _buildDesktopLayout() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dividerColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.06);

    return Row(
      children: [
        // Left panel - Gram list (fixed width)
        SizedBox(
          width: 340,
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? AppTheme.cardDarkColor : Colors.white,
              border: Border(
                right: BorderSide(color: dividerColor, width: 1),
              ),
            ),
            child: Stack(
              children: [
                RefreshIndicator(
                  onRefresh: _handleRefresh,
                  color: AppTheme.primaryColor,
                  child: GestureDetector(
                    onTap: () => _searchFocusNode.unfocus(),
                    child: CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      cacheExtent: 600,
                      slivers: [
                        AppHeaderStyle.buildWideLayoutHeaderSliver(
                          context,
                          title: 'Grams',
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_isRefreshing)
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        AppTheme.primaryColor),
                                  ),
                                ),
                              const SizedBox(width: 8),
                              _buildUploadIndicator(),
                              const SizedBox(width: 8),
                              IconButton(
                                onPressed: _showCreationDialog,
                                icon: Icon(
                                  Icons.add_rounded,
                                  color: AppTheme.primaryColor,
                                  size: 24,
                                ),
                                tooltip: 'Create Gram',
                              ),
                            ],
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: AnimatedOpacity(
                            opacity: _isRefreshing ? 0.7 : 1.0,
                            duration: const Duration(milliseconds: 200),
                            child: _buildGramList(),
                          ),
                        ),
                        SliverToBoxAdapter(child: SizedBox(height: 80)),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: TransparentToolbox.search(
                    searchController: _searchController,
                    focusNode: _searchFocusNode,
                    onSearchChanged: _onSearchChanged,
                    hintText: 'Search grams',
                  ),
                ),
              ],
            ),
          ),
        ),

        // Right panel - Gram posts/content view (fills remaining space)
        Expanded(
          child: _selectedGramId != null && _selectedGram != null
              ? EmbeddedTheatreView(
                  key: ValueKey(_selectedGramId),
                  spaceId: _selectedGramId!,
                  space: _selectedGram,
                  onBack: () {
                    setState(() {
                      _selectedGramId = null;
                      _selectedGram = null;
                    });
                  },
                )
              : _buildEmptyDetailState(isDark),
        ),
      ],
    );
  }

  /// Build empty state for the detail panel when no gram is selected
  Widget _buildEmptyDetailState(bool isDark) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.square_grid_2x2,
              size: 80,
              color: AppTheme.primaryColor.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 24),
            Text(
              'Select a gram',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w500,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.6)
                    : Colors.black.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Choose from your grams\nto view the chat',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.4)
                    : Colors.black.withValues(alpha: 0.4),
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

  /// Build upload indicator widget
  Widget _buildUploadIndicator() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: MediaCompressionService().getUploadProgress(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SizedBox.shrink();
        }

        final activeUploads = snapshot.data
                ?.where((item) =>
                    item['status'] != 'completed' &&
                    item['status'] != 'failed' &&
                    item['status'] != 'cancelled')
                .length ??
            0;

        if (activeUploads > 0) {
          return InkWell(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => UploadsPage(),
                ),
              );
            },
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Badge(
                label: Text(
                  activeUploads.toString(),
                  style: TextStyle(color: Colors.white, fontSize: 10),
                ),
                backgroundColor: AppTheme.errorColor,
                child: Icon(
                  Icons.cloud_upload_outlined,
                  color: AppTheme.primaryColor,
                  size: 24,
                ),
              ),
            ),
          );
        }

        return SizedBox.shrink();
      },
    );
  }

  SliverAppBar _buildSliverAppBar() {
    Widget uploadIndicator = FutureBuilder<List<Map<String, dynamic>>>(
      future: MediaCompressionService().getUploadProgress(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SizedBox.shrink();
        }

        final activeUploads = snapshot.data
                ?.where((item) =>
                    item['status'] != 'completed' &&
                    item['status'] != 'failed' &&
                    item['status'] != 'cancelled')
                .length ??
            0;

        if (activeUploads > 0) {
          return InkWell(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => UploadsPage(),
                ),
              );
            },
            child: Badge(
              label: Text(
                activeUploads.toString(),
                style:
                    TextStyle(color: AppTheme.scaffoldLightColor, fontSize: 10),
              ),
              backgroundColor: AppTheme.errorColor,
              child: Icon(
                Icons.cloud_upload,
                color: AppTheme.primaryColor,
                size: AppHeaderStyle.headerIconSize,
              ),
            ),
          );
        }

        return SizedBox.shrink();
      },
    );

    Widget actionButtons = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Invites icon button
        IconButton(
          onPressed: _showInvites,
          icon: Icon(
            Icons.card_giftcard,
            color: AppTheme.primaryColor,
            size: AppHeaderStyle.headerIconSize,
          ),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          tooltip: 'Gram Invites',
        ),
        SizedBox(width: 4),
        uploadIndicator,
        if (uploadIndicator is! SizedBox)
          SizedBox(width: 4), // Only add spacing if upload indicator exists
      ],
    );

    // Plus button moved to left side
    Widget? leadingButton;
    if (_user != null) {
      leadingButton = AppHeaderStyle.buildCreateButton(
        label: "Gram",
        onPressed: _showCreationDialog,
        simpleIcon: true,
      );
    }

    return AppHeaderStyle.buildStandardHeader(
      context: context,
      title: 'sub-grams',
      actionButton: actionButtons,
      leadingWidget: leadingButton ?? const SizedBox.shrink(),
      showSearchField: false,
      isRefreshing: _isRefreshing,
    );
  }

  /// Show the gram creation dialog
  void _showCreationDialog() {
    Navigator.of(context, rootNavigator: true)
        .push(CupertinoPageRoute(builder: (context) => SpaceCreationPage()));
  }

  /// Navigate to gram invites page
  void _showInvites() {
    Navigator.of(context, rootNavigator: true).push(
      CupertinoPageRoute(builder: (context) => const Invites()),
    );
  }

  /// Handle refresh action - seamless, no spinners
  Future<void> _handleRefresh() async {
    if (_isRefreshing) return;

    if (mounted) {
      setState(() => _isRefreshing = true);
    }

    // Yield a frame so shimmer appears before work starts
    await Future.delayed(Duration.zero);

    try {
      // Force reload: clear ALL space caches so list rebuilds fresh
      _gramItemCache.clear();

      // Clear the static space cache in GramPreviewBox
      GramPreviewBox.clearSpaceCache();

      // Also clear SpaceService cache (it caches Space objects)
      if (locator.isRegistered<SpaceService>()) {
        locator<SpaceService>().clearSpaceCache();
      }

      // Reset public spaces cache to force reload
      _publicGramsLoaded = false;
      _cachedPublicGrams = null;

      // Eagerly fetch latest 'updated' for visible spaces to ensure correct ordering
      await _reloadUpdatedTimestamps();

      // Tell GramPreviewBox to reload its own data
      _reloadToken++;

      // Validate and prefetch in background (non-blocking)
      _validateGramsInBackground();
      _prefetchFirstVideos();

      if (mounted) setState(() {});
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  /// Reload the 'updated' timestamps for all current spaces once
  Future<void> _reloadUpdatedTimestamps() async {
    if (_user == null) return;
    try {
      final spacesSnapshot = await _userSpacesCollection
          .doc(_user!.uid)
          .collection('spaces')
          .where('role', whereIn: ['member', 'owner', 'creator']).get();
      final List<String> ids = spacesSnapshot.docs.map((d) => d.id).toList();

      // Fetch spacePosts docs in small batches to reduce load
      for (final String id in ids) {
        try {
          final doc = await _spacesCollection.doc(id).get();
          Timestamp? updated;
          if (doc.exists) {
            final data = doc.data() as Map<String, dynamic>?;
            updated = data?['lastPostAt'] as Timestamp? ??
                data?['updated'] as Timestamp? ??
                data?['lastActivity'] as Timestamp?;
          }
          _lastUpdatedMap[id] = updated;
        } catch (_) {}
      }
    } catch (_) {}
  }

  /// Run a background validation of all spaces for current user
  /// Only runs once per session to prevent timeout storms
  Future<void> _validateGramsInBackground() async {
    // Guard: only validate once per session to prevent request storms
    if (_validatedOnce || _user == null) return;
    _validatedOnce = true;

    try {
      // Use SpaceService batch validation and cleanup
      final spaceService = locator<SpaceService>();

      // Validate spaces and get list of invalid ones
      final invalidSpaces =
          await spaceService.batchValidateUserSpaces(_user!.uid);

      // Batch cleanup invalid spaces if any found
      if (invalidSpaces.isNotEmpty) {
        await spaceService.batchCleanupInvalidSpaces(_user!.uid, invalidSpaces);

        // Refresh UI if changes were made
        if (mounted && invalidSpaces.isNotEmpty) {
          setState(() {});
        }
      }
    } catch (e) {
      // Silently ignore batch cleanup errors
      AppLogger.w('Error validating spaces',
          category: LogCategory.general, data: {'error': e.toString()});
    }
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
