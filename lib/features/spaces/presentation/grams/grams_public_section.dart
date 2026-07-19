import 'package:cloud_firestore/cloud_firestore.dart' show QueryDocumentSnapshot, Timestamp;
import 'package:flutter/material.dart';
import 'package:aurogram/features/spaces/presentation/grams/grams_empty_state.dart';
import 'package:aurogram/shared/services/search_service.dart';
import 'package:aurogram/core/theme/header_style.dart';

/// Discover section divider with label
class GramsDiscoverDivider extends StatelessWidget {
  const GramsDiscoverDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 8),
      child: Row(
        children: [
          Text(
            'PUBLIC',
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
    );
  }
}

/// Build public grams section to show below user's own grams.
class GramsPublicSection extends StatelessWidget {
  final Set<String> userGramIds;
  final bool publicGramsLoaded;
  final List<QueryDocumentSnapshot>? cachedPublicGrams;
  final String searchQuery;
  final Widget Function(QueryDocumentSnapshot doc) buildGramItem;
  final VoidCallback onLoadPublicGrams;

  const GramsPublicSection({
    super.key,
    required this.userGramIds,
    required this.publicGramsLoaded,
    required this.cachedPublicGrams,
    required this.searchQuery,
    required this.buildGramItem,
    required this.onLoadPublicGrams,
  });

  @override
  Widget build(BuildContext context) {
    if (!publicGramsLoaded) {
      onLoadPublicGrams();
      return const SizedBox.shrink();
    }

    if (cachedPublicGrams == null || cachedPublicGrams!.isEmpty) {
      return const SizedBox.shrink();
    }

    // Filter out user's own grams
    List<QueryDocumentSnapshot> publicGrams = cachedPublicGrams!
        .where((doc) => !userGramIds.contains(doc.id))
        .toList();

    // Apply search filter if active
    if (searchQuery.trim().isNotEmpty) {
      final query = searchQuery.trim();
      publicGrams = publicGrams.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final spaceName = data['name'] as String? ?? '';
        final spaceDescription = data['description'] as String? ?? '';
        return SearchService.smartMatch(query, spaceName) ||
            SearchService.smartMatch(query, spaceDescription);
      }).toList();
    }

    if (publicGrams.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const GramsDiscoverDivider(),
        Wrap(
          children: publicGrams.map((doc) => buildGramItem(doc)).toList(),
        ),
      ],
    );
  }
}

/// Search results showing both user's grams and public grams.
class GramsSearchResults extends StatelessWidget {
  final List<QueryDocumentSnapshot> userGrams;
  final bool publicGramsLoaded;
  final List<QueryDocumentSnapshot>? cachedPublicGrams;
  final String searchQuery;
  final Map<String, Timestamp?> lastUpdatedMap;
  final Widget Function(QueryDocumentSnapshot doc) buildGramItem;
  final Widget skeleton;
  final VoidCallback onLoadPublicGrams;

  const GramsSearchResults({
    super.key,
    required this.userGrams,
    required this.publicGramsLoaded,
    required this.cachedPublicGrams,
    required this.searchQuery,
    required this.lastUpdatedMap,
    required this.buildGramItem,
    required this.skeleton,
    required this.onLoadPublicGrams,
  });

  @override
  Widget build(BuildContext context) {
    if (!publicGramsLoaded) {
      onLoadPublicGrams();
      return skeleton;
    }

    final userGramIds = userGrams.map((d) => d.id).toSet();

    // Filter public grams by search query and exclude user's grams
    List<QueryDocumentSnapshot> matchingPublicGrams = [];
    if (cachedPublicGrams != null && cachedPublicGrams!.isNotEmpty) {
      final query = searchQuery.trim();
      matchingPublicGrams = cachedPublicGrams!.where((doc) {
        if (userGramIds.contains(doc.id)) return false;
        final data = doc.data() as Map<String, dynamic>;
        final spaceName = data['name'] as String? ?? '';
        final spaceDescription = data['description'] as String? ?? '';
        return SearchService.smartMatch(query, spaceName) ||
            SearchService.smartMatch(query, spaceDescription);
      }).toList();
    }

    if (userGrams.isEmpty && matchingPublicGrams.isEmpty) {
      return const GramsSearchEmptyState();
    }

    // Sort user's grams by latest activity
    List<QueryDocumentSnapshot> sortedUserGrams = List.from(userGrams);
    sortedUserGrams.sort((a, b) {
      final Timestamp? aUpdated = lastUpdatedMap[a.id];
      final Timestamp? bUpdated = lastUpdatedMap[b.id];
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
        if (sortedUserGrams.isNotEmpty)
          Wrap(
            children: sortedUserGrams
                .map((document) => buildGramItem(document))
                .toList(),
          ),
        if (matchingPublicGrams.isNotEmpty) ...[
          if (sortedUserGrams.isNotEmpty) const GramsDiscoverDivider(),
          Wrap(
            children: matchingPublicGrams
                .map((document) => buildGramItem(document))
                .toList(),
          ),
        ],
        SizedBox(height: AppHeaderStyle.contentBottomPadding + 50),
      ],
    );
  }
}

/// Shows public grams when user has no grams - gives them something to explore.
class GramsPublicExplorer extends StatelessWidget {
  final bool publicGramsLoaded;
  final List<QueryDocumentSnapshot>? cachedPublicGrams;
  final String searchQuery;
  final Widget Function(QueryDocumentSnapshot doc) buildGramItem;
  final Widget skeleton;
  final VoidCallback onLoadPublicGrams;

  const GramsPublicExplorer({
    super.key,
    required this.publicGramsLoaded,
    required this.cachedPublicGrams,
    required this.searchQuery,
    required this.buildGramItem,
    required this.skeleton,
    required this.onLoadPublicGrams,
  });

  @override
  Widget build(BuildContext context) {
    if (!publicGramsLoaded) {
      onLoadPublicGrams();
      return skeleton;
    }

    if (cachedPublicGrams == null || cachedPublicGrams!.isEmpty) {
      return const GramsCreateFirstState();
    }

    // Apply search filter from cached data
    List<QueryDocumentSnapshot> publicGrams = cachedPublicGrams!;
    if (searchQuery.trim().isNotEmpty) {
      final query = searchQuery.trim();
      publicGrams = cachedPublicGrams!.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final spaceName = data['name'] as String? ?? '';
        final spaceDescription = data['description'] as String? ?? '';
        return SearchService.smartMatch(query, spaceName) ||
            SearchService.smartMatch(query, spaceDescription);
      }).toList();

      if (publicGrams.isEmpty) {
        return const GramsSearchEmptyState();
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppHeaderStyle.contentTopPadding),
        Wrap(
          children: publicGrams.map((doc) => buildGramItem(doc)).toList(),
        ),
        SizedBox(height: AppHeaderStyle.contentBottomPadding + 50),
      ],
    );
  }
}

/// Public gram list for unauthenticated users.
class GramsPublicList extends StatelessWidget {
  final bool publicGramsLoaded;
  final List<QueryDocumentSnapshot>? cachedPublicGrams;
  final String searchQuery;
  final Widget Function(QueryDocumentSnapshot doc) buildPublicGramItem;
  final Widget skeleton;
  final VoidCallback onLoadPublicGrams;

  const GramsPublicList({
    super.key,
    required this.publicGramsLoaded,
    required this.cachedPublicGrams,
    required this.searchQuery,
    required this.buildPublicGramItem,
    required this.skeleton,
    required this.onLoadPublicGrams,
  });

  @override
  Widget build(BuildContext context) {
    if (!publicGramsLoaded) {
      onLoadPublicGrams();
      return skeleton;
    }

    if (cachedPublicGrams == null || cachedPublicGrams!.isEmpty) {
      return const GramsNoPublicState();
    }

    // Apply search filter from cached data
    List<QueryDocumentSnapshot> filteredGrams = cachedPublicGrams!;
    if (searchQuery.trim().isNotEmpty) {
      final query = searchQuery.trim();
      filteredGrams = cachedPublicGrams!.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final spaceName = data['name'] as String? ?? '';
        final spaceDescription = data['description'] as String? ?? '';
        return SearchService.smartMatch(query, spaceName) ||
            SearchService.smartMatch(query, spaceDescription);
      }).toList();

      if (filteredGrams.isEmpty) {
        return const GramsSearchEmptyState();
      }
    }

    return Column(
      children: [
        const SizedBox(height: AppHeaderStyle.contentTopPadding),
        Wrap(
          children:
              filteredGrams.map((doc) => buildPublicGramItem(doc)).toList(),
        ),
        const SizedBox(height: 150),
      ],
    );
  }
}
