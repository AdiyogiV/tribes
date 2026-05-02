import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:aurogram/shared/services/database_service.dart';
import 'package:aurogram/features/profile/presentation/widgets/preview_boxes/preview_box.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:aurogram/shared/services/search_service.dart';
// Removed unused import: title.dart
import 'package:aurogram/features/profile/presentation/widgets/preview_boxes/crew_preview.dart';
import 'package:aurogram/features/profile/presentation/widgets/preview_boxes/gram_preview_box.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/core/theme/header_style.dart';
import 'package:aurogram/shared/presentation/responsive/responsive.dart';
import 'package:aurogram/core/logging/app_logger.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';

class Discovery extends StatefulWidget {
  const Discovery({super.key});

  @override
  DiscoveryState createState() => DiscoveryState();
}

class DiscoveryState extends State<Discovery> {
  final SearchService _searchService = SearchService();
  // Refresh system similar to gallery
  bool _isRefreshing = false;

  TextEditingController? _textController;
  final FocusNode _focusNode = FocusNode();

  int selectedSpaceType = 0;
  List<Widget> suggestions = [];
  final Map<String, Timestamp?> _spaceUpdatedMap = {};
  final Map<String, StreamSubscription<DocumentSnapshot>>
      _discoveryUpdatedSubs = {};
  List<String> _currentSpaceIds = [];

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
    getSuggestions('');
  }

  Future<void> getSuggestions(String input) async {
    suggestions = [];
    switch (selectedSpaceType) {
      case -1:
        {
          _clearDiscoveryUpdatedListeners();
          getPosts();
        }
        break;
      case 0:
        {
          getSpaces(input);
        }
        break;

      default:
        {
          _clearDiscoveryUpdatedListeners();
          getUsers(input);
        }
        break;
    }
  }

  Future<void> getPosts() async {
    try {
      List<QueryDocumentSnapshot> feedDocs;

      feedDocs = await DatabaseService().getGlobalFeed(100);
      suggestions = feedDocs
          .asMap()
          .map((index, documents) => MapEntry(
                index,
                GestureDetector(
                  key: ValueKey('post_${documents.id}'),
                  onTap: () {
                    context.push('/thread/${documents.id}');
                  },
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    width: MediaQuery.of(context).size.width / 2,
                    child: PreviewBox(
                      key: ValueKey('preview_${documents.id}'),
                      previewUrl: (documents.data()
                                  as Map<String, dynamic>?)?['thumbnail']
                              as String? ??
                          '',
                      title: (documents.data()
                          as Map<String, dynamic>?)?['title'] as String?,
                      author: (documents.data()
                          as Map<String, dynamic>?)?['author'] as String?,
                      content: (documents.data()
                          as Map<String, dynamic>?)?['content'] as String?,
                      postType: (documents.data()
                          as Map<String, dynamic>?)?['postType'] as String?,
                    ),
                  ),
                ),
              ))
          .values
          .toList();
    } catch (e) {
      AppLogger.e('Error searching users',
          category: LogCategory.general, data: {'error': e.toString()});
    }
    if (mounted) setState(() {});
  }

  Future<void> getSpaces(String input) async {
    try {
      // Use centralized search service
      final results = await _searchService.searchSpaces(input, limit: 50);

      // Filter out private spaces - only show public spaces in discovery
      List<String> publicSpaceIds = [];
      for (var spaceDoc in results) {
        try {
          final spaceData = SearchService.getSpaceData(spaceDoc);
          if (spaceData != null) {
            final spaceType = spaceData['spaceType'] as int?;

            // PUBLIC: open (0), public (1)
            // PRIVATE: private (2), personal (3)
            if (spaceType == 0 || spaceType == 1) {
              publicSpaceIds.add(spaceDoc.id);
            }
          }
        } catch (e) {
          AppLogger.w('Error checking space type',
              category: LogCategory.general,
              data: {'spaceId': spaceDoc.id, 'error': e.toString()});
          // Skip this space if we can't determine its type
        }
      }

      // Track current result IDs (only public spaces)
      _currentSpaceIds = publicSpaceIds;

      // Start/update listeners for real-time updated timestamps
      _attachDiscoveryUpdatedListeners(_currentSpaceIds);

      // Build suggestions ordered by current known updated timestamps
      _rebuildDiscoverySuggestions();
    } catch (e) {
      AppLogger.e('Error searching spaces',
          category: LogCategory.general, data: {'error': e.toString()});
    }
    if (mounted) setState(() {});
  }

  void _attachDiscoveryUpdatedListeners(List<String> spaceIds) {
    // Remove listeners for spaces not in the new result set
    final toRemove = _discoveryUpdatedSubs.keys
        .where((id) => !spaceIds.contains(id))
        .toList(growable: false);
    for (final id in toRemove) {
      _discoveryUpdatedSubs[id]?.cancel();
      _discoveryUpdatedSubs.remove(id);
      _spaceUpdatedMap.remove(id);
    }

    // Add listeners for new spaces — capped at 10 to prevent listener
    // storms when search returns many results. Beyond 10 we fall back to
    // a static order; users can refresh to re-sort.
    const int kMaxLiveSortListeners = 10;
    int liveCount = _discoveryUpdatedSubs.length;
    for (final id in spaceIds) {
      if (_discoveryUpdatedSubs.containsKey(id)) continue;
      if (liveCount >= kMaxLiveSortListeners) break;
      liveCount++;
      // ignore: cancel_subscriptions — stored in _discoveryUpdatedSubs and cancelled in dispose
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
          } else {
            updated = null;
          }
        }
        final previousUpdated = _spaceUpdatedMap[id];
        // Only rebuild if timestamp actually changed
        if (previousUpdated?.millisecondsSinceEpoch !=
            updated?.millisecondsSinceEpoch) {
          _spaceUpdatedMap[id] = updated;
          _rebuildDiscoverySuggestions();
          if (mounted) setState(() {});
        }
      });
      _discoveryUpdatedSubs[id] = sub;
    }
  }

  void _clearDiscoveryUpdatedListeners() {
    for (final sub in _discoveryUpdatedSubs.values) {
      sub.cancel();
    }
    _discoveryUpdatedSubs.clear();
    _spaceUpdatedMap.clear();
    _currentSpaceIds.clear();
  }

  void _rebuildDiscoverySuggestions() {
    // Sort current space IDs by updated desc, fallback to no-update at end
    final sorted = List<String>.from(_currentSpaceIds);
    sorted.sort((a, b) {
      final ta = _spaceUpdatedMap[a];
      final tb = _spaceUpdatedMap[b];
      if (ta != null && tb != null) return tb.compareTo(ta);
      if (ta == null && tb == null) return 0;
      if (tb != null) return 1;
      return -1;
    });

    suggestions = sorted
        .map((spaceId) => GestureDetector(
              key: ValueKey('disc_$spaceId'),
              onTap: () {
                context.push('/space/$spaceId');
              },
              child: GramPreviewBox(
                key: ValueKey('box_$spaceId'),
                gram: spaceId,
                showChatButton: true,
              ),
            ))
        .toList();
  }

  Future<void> getUsers(String input) async {
    if (input == '') return;
    try {
      // Use centralized search service
      final results = await _searchService.searchUsers(input, limit: 50);

      suggestions = results
          .asMap()
          .map(
            (index, doc) => MapEntry(
              index,
              GestureDetector(
                key: ValueKey('user_${doc.id}'),
                onTap: () {
                  context.push('/user/${doc.id}');
                },
                child: CrewPreview(
                  key: ValueKey('crew_${doc.id}'),
                  user: doc.id,
                ),
              ),
            ),
          )
          .values
          .toList();
    } catch (e) {
      AppLogger.e('Error in discovery suggestions',
          category: LogCategory.general, data: {'error': e.toString()});
    }
    if (mounted) setState(() {});
  }

  /// Handle refresh action similar to gallery
  Future<void> _handleRefresh() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    
    // Yield a frame so shimmer appears before work starts
    await Future.delayed(Duration.zero);
    
    try {
      await getSuggestions(_textController?.text ?? '');
    } catch (e) {
      AppLogger.e('Error during refresh',
          category: LogCategory.general, error: e);
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  @override
  void dispose() {
    for (final sub in _discoveryUpdatedSubs.values) {
      sub.cancel();
    }
    _discoveryUpdatedSubs.clear();
    _focusNode.dispose();
    _textController!.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldLightColor,
      extendBody: true,
      resizeToAvoidBottomInset: false,
      // Full-width scroll view so scrollbar appears at viewport edge
      // Use LayoutBuilder to get actual available width (accounts for sidebar)
      body: LayoutBuilder(
        builder: (context, constraints) {
          final contentPadding = Responsive.horizontalPaddingFor(constraints.maxWidth, 800);
          return CustomScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              // Header handles its own centering
              _getAppBar(context),
              // Pull to refresh - hidden indicator, title shimmers instead
              CupertinoSliverRefreshControl(
                onRefresh: _handleRefresh,
                builder: (context, refreshState, pulledExtent, refreshTriggerPullDistance, refreshIndicatorExtent) {
                  return const SizedBox.shrink();
                },
              ),
              // Content with responsive horizontal padding
              SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: contentPadding),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    children: [
                      // Show skeletons during refresh for visual feedback
                      if (_isRefreshing)
                        ..._buildDiscoverySkeletons()
                      else
                        Wrap(
                          children: suggestions,
                        ),
                      SizedBox(
                        height: 250,
                      )
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Build skeleton placeholders during refresh - minimal, no shimmer wrapper
  List<Widget> _buildDiscoverySkeletons() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final Color cardColor = isDark ? AppTheme.cardDarkColor : Colors.white;
    final Color placeholder = AppTheme.primaryColor.withValues(alpha: isDark ? 0.12 : 0.08);
    final Color placeholderDark = AppTheme.primaryColor.withValues(alpha: isDark ? 0.18 : 0.12);
    
    return List.generate(4, (index) {
      final widths = [130.0, 110.0, 145.0, 120.0];
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Material(
          color: cardColor,
          elevation: 1,
          shadowColor: Colors.black.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
          child: Container(
            height: 100,
            padding: const EdgeInsets.all(AppDimensions.paddingLg),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: placeholder,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                  ),
                ),
                const SizedBox(width: AppDimensions.spacingMdLg),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: widths[index % widths.length],
                        height: 14,
                        decoration: BoxDecoration(
                          color: placeholderDark,
                          borderRadius: BorderRadius.circular(7),
                        ),
                      ),
                      const SizedBox(height: AppDimensions.spacingSm),
                      Container(
                        width: widths[index % widths.length] - 30,
                        height: 11,
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
        ),
      );
    });
  }

  SliverAppBar _getAppBar(BuildContext context) {
    Widget switcherWidget = CupertinoSlidingSegmentedControl<int>(
      children: {
        0: Icon(CupertinoIcons.grid_circle, color: AppTheme.primaryColor, size: AppHeaderStyle.headerIconSize),
        1: Icon(CupertinoIcons.group_solid, color: AppTheme.primaryColor, size: AppHeaderStyle.headerIconSize),
      },
      onValueChanged: (int? newValue) {
        if (mounted) {
          setState(() {
            selectedSpaceType = newValue!;
          });
        }
        _handleRefresh();
      },
      groupValue: selectedSpaceType,
    );

    return AppHeaderStyle.buildStandardHeader(
      context: context,
      title: selectedSpaceType == 0 ? "grams" : 'users',
      actionButton: switcherWidget,
      leadingWidget: const SizedBox.shrink(),
      searchFocusNode: _focusNode,
      onSearch: (query) {
        getSuggestions(query);
      },
      isRefreshing: _isRefreshing,
    );
  }
}
