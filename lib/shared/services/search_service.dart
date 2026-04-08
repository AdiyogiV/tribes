import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:aurogram/utils/logging/app_logger.dart';

/// Centralized search service using Firestore
/// Replaces Algolia for all search functionality
class SearchService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Live current user - never cached, so logout/login always uses the active account.
  User? get _currentUser => FirebaseAuth.instance.currentUser;

  /// Smart string matching that handles:
  /// - Word-based matching (matches any word in query against any word in target)
  /// - Space normalization (handles multiple spaces, leading/trailing spaces)
  /// - Case-insensitive matching
  /// - Partial word matches
  /// - Fuzzy matching for better results
  static bool smartMatch(String query, String target) {
    if (query.trim().isEmpty) return true;
    if (target.trim().isEmpty) return false;

    // Normalize both strings: lowercase, remove extra spaces, trim
    final normalizedQuery = _normalizeString(query);
    final normalizedTarget = _normalizeString(target);

    // Exact match (after normalization)
    if (normalizedTarget.contains(normalizedQuery)) {
      return true;
    }

    // Word-based matching: split into words and check if any query word matches any target word
    final queryWords = _tokenize(normalizedQuery);
    final targetWords = _tokenize(normalizedTarget);

    // Check if all query words have a match in target (all words must match)
    for (final queryWord in queryWords) {
      if (queryWord.isEmpty) continue;

      bool wordMatches = false;
      for (final targetWord in targetWords) {
        // Exact word match
        if (targetWord == queryWord) {
          wordMatches = true;
          break;
        }
        // Partial word match (query word is contained in target word or vice versa)
        if (targetWord.contains(queryWord) || queryWord.contains(targetWord)) {
          wordMatches = true;
          break;
        }
        // Fuzzy match: check if words are similar (for typos or variations)
        if (_areWordsSimilar(queryWord, targetWord)) {
          wordMatches = true;
          break;
        }
      }

      if (!wordMatches) {
        return false; // At least one query word doesn't match
      }
    }

    return true; // All query words matched
  }

  /// Normalize string: lowercase, remove extra spaces, trim
  static String _normalizeString(String str) {
    return str
        .toLowerCase()
        .replaceAll(
            RegExp(r'\s+'), ' ') // Replace multiple spaces with single space
        .trim();
  }

  /// Capitalize first character (best-effort for prefix querying)
  static String _capitalizeFirst(String value) {
    if (value.isEmpty) return value;
    return value[0].toUpperCase() + value.substring(1);
  }

  /// Tokenize string into words (split by spaces and filter empty)
  static List<String> _tokenize(String str) {
    return str.split(' ').where((word) => word.isNotEmpty).toList();
  }

  /// Check if two words are similar (fuzzy matching)
  /// Handles common variations and typos
  static bool _areWordsSimilar(String word1, String word2) {
    if (word1.isEmpty || word2.isEmpty) return false;

    // If words are very close in length and share most characters
    final lengthDiff = (word1.length - word2.length).abs();
    if (lengthDiff > 2) return false; // Too different in length

    // Check character overlap
    final chars1 = word1.split('').toSet();
    final chars2 = word2.split('').toSet();
    final intersection = chars1.intersection(chars2);
    final union = chars1.union(chars2);

    // If more than 70% of characters match, consider them similar
    if (union.isEmpty) return false;
    final similarity = intersection.length / union.length;
    if (similarity >= 0.7) return true;

    // Check if one word starts with the other (for partial matches)
    if (word1.length >= 3 && word2.length >= 3) {
      if (word1.startsWith(word2) || word2.startsWith(word1)) {
        return true;
      }
    }

    return false;
  }

  /// Search users by name or nickname with smart matching
  /// Returns a list of QueryDocumentSnapshot for users matching the query
  Future<List<QueryDocumentSnapshot>> searchUsers(
    String query, {
    int limit = 20,
    String? excludeUserId,
  }) async {
    if (query.trim().isEmpty) {
      return [];
    }

    try {
      final searchLower = query.toLowerCase().trim();
      final userIdToExclude = excludeUserId ?? _currentUser?.uid;

      // Use generous fetch limit per query - we'll filter client-side with smartMatch
      final fetchLimit = (limit * 5).clamp(50, 200);

      // Prefer prefix queries on the full query and each word.
      // If we still have too few candidates, fall back to first-char broadening.
      final List<Future<QuerySnapshot>> queryFutures = [];

      final searchWords =
          searchLower.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
      final Set<String> prefixesToQuery = {};

      if (searchLower.isNotEmpty) {
        prefixesToQuery.add(searchLower);
      }
      for (final word in searchWords) {
        if (word.length >= 2) {
          prefixesToQuery.add(word);
        }
      }

      AppLogger.i('User search query setup',
          category: LogCategory.general,
          data: {
            'query': searchLower,
            'words': searchWords.length,
            'prefixes': prefixesToQuery.length,
            'limit': limit,
          });

      void addPrefixQueries(String field, String prefix) {
        if (prefix.isEmpty) return;
        final variants = <String>{
          prefix,
          _capitalizeFirst(prefix),
          prefix.toUpperCase(),
        };
        for (final variant in variants) {
          try {
            queryFutures.add(_firestore
                .collection('users')
                .where(field, isGreaterThanOrEqualTo: variant)
                .where(field, isLessThan: '$variant\uf8ff')
                .limit(fetchLimit)
                .get());
          } catch (e) {
            AppLogger.w('Error in $field query (prefix $variant): $e',
                category: LogCategory.general,
                data: {'query': query, 'error': e.toString()});
          }
        }
      }

      for (final prefix in prefixesToQuery) {
        addPrefixQueries('name', prefix);
        addPrefixQueries('nickname', prefix);
      }

      // If no queries were created, return empty list
      if (queryFutures.isEmpty) {
        AppLogger.w('No queries created for search',
            category: LogCategory.general, data: {'query': query});
        return [];
      }

      Future<List<QuerySnapshot>> executeQueries(
          List<Future<QuerySnapshot>> futures) async {
        if (futures.isEmpty) return [];
        return Future.wait(
          futures.map((future) => future.catchError((e) {
                AppLogger.w('Query execution error: $e',
                    category: LogCategory.general,
                    data: {'query': query, 'error': e.toString()});
                // Return empty snapshot on error
                return _firestore.collection('users').limit(0).get();
              })),
          eagerError: false,
        );
      }

      // Execute primary prefix queries
      final results = await executeQueries(queryFutures);
      final totalDocsPrimary =
          results.fold<int>(0, (acc, snap) => acc + snap.docs.length);

      bool usedFallback = false;
      if (totalDocsPrimary < limit && searchLower.isNotEmpty) {
        // Fallback: broaden by first character to avoid missing candidates.
        final fallbackFutures = <Future<QuerySnapshot>>[];
        final firstChar = searchLower[0];
        final fallbackPrefixes = <String>{firstChar};
        for (final prefix in fallbackPrefixes) {
          try {
            fallbackFutures.add(_firestore
                .collection('users')
                .where('name', isGreaterThanOrEqualTo: prefix)
                .where('name', isLessThan: '$prefix\uf8ff')
                .limit(fetchLimit)
                .get());
            fallbackFutures.add(_firestore
                .collection('users')
                .where('nickname', isGreaterThanOrEqualTo: prefix)
                .where('nickname', isLessThan: '$prefix\uf8ff')
                .limit(fetchLimit)
                .get());
          } catch (e) {
            AppLogger.w('Error in fallback prefix query ($prefix): $e',
                category: LogCategory.general,
                data: {'query': query, 'error': e.toString()});
          }
        }
        final fallbackResults = await executeQueries(fallbackFutures);
        results.addAll(fallbackResults);
        usedFallback = fallbackResults.isNotEmpty;
      }

      AppLogger.i('User search query results',
          category: LogCategory.general,
          data: {
            'query': searchLower,
            'queries': results.length,
            'total_docs':
                results.fold<int>(0, (acc, snap) => acc + snap.docs.length),
            'total_docs_primary': totalDocsPrimary,
            'fallback_used': usedFallback,
          });

      // Get deleted user IDs to filter them out
      final allUserIds = <String>{};
      for (final snapshot in results) {
        for (final doc in snapshot.docs) {
          if (userIdToExclude == null || doc.id != userIdToExclude) {
            allUserIds.add(doc.id);
          }
        }
      }

      // Check deletedUsers in batches
      final deletedUserIds = <String>{};
      if (allUserIds.isNotEmpty) {
        final deletedUserIdsList = allUserIds.toList();
        for (int i = 0; i < deletedUserIdsList.length; i += 10) {
          final batch = deletedUserIdsList.skip(i).take(10).toList();
          try {
            final deletedSnapshot = await _firestore
                .collection('deletedUsers')
                .where(FieldPath.documentId, whereIn: batch)
                .get();
            deletedUserIds.addAll(deletedSnapshot.docs.map((d) => d.id));
          } catch (e) {
            AppLogger.w('Error checking deleted users',
                category: LogCategory.general, data: {'error': e.toString()});
          }
        }
      }

      // Combine results and remove duplicates, filtering deleted users
      final Map<String, QueryDocumentSnapshot> uniqueUsers = {};

      for (final snapshot in results) {
        for (final doc in snapshot.docs) {
          // Filter out excluded user and deleted users
          if ((userIdToExclude == null || doc.id != userIdToExclude) &&
              !deletedUserIds.contains(doc.id)) {
            uniqueUsers[doc.id] = doc;
          }
        }
      }

      // Apply smart matching to filter results
      // This allows finding users with names like "John Doe" when searching "doe"
      final List<QueryDocumentSnapshot> matchedUsers = [];
      for (final doc in uniqueUsers.values) {
        final userData = doc.data() as Map<String, dynamic>?;
        if (userData == null) continue;

        final name = userData['name'] as String? ?? '';
        final nickname = userData['nickname'] as String? ?? '';

        // Use smart matching on both name and nickname
        // Smart matching handles partial matches, word order, etc.
        if (smartMatch(query, name) || smartMatch(query, nickname)) {
          matchedUsers.add(doc);
        }
      }

      if (matchedUsers.isEmpty && uniqueUsers.isNotEmpty) {
        final sample = uniqueUsers.values.take(5).map((doc) {
          final data = doc.data() as Map<String, dynamic>?;
          final name = data?['name'] as String? ?? '';
          final nickname = data?['nickname'] as String? ?? '';
          return {
            'id': doc.id,
            'name': name,
            'nickname': nickname,
            'name_match': smartMatch(query, name),
            'nickname_match': smartMatch(query, nickname),
          };
        }).toList();
        AppLogger.i('User search candidate sample',
            category: LogCategory.general,
            data: {'query': query, 'sample': sample});
      }

      // Sort by relevance (exact prefix matches first, then others)
      matchedUsers.sort((a, b) {
        final aData = a.data() as Map<String, dynamic>;
        final bData = b.data() as Map<String, dynamic>;
        final aName = (aData['name'] as String? ?? '').toLowerCase();
        final bName = (bData['name'] as String? ?? '').toLowerCase();
        final aNickname = (aData['nickname'] as String? ?? '').toLowerCase();
        final bNickname = (bData['nickname'] as String? ?? '').toLowerCase();

        // Prioritize exact prefix matches
        final aStartsWith =
            aName.startsWith(searchLower) || aNickname.startsWith(searchLower);
        final bStartsWith =
            bName.startsWith(searchLower) || bNickname.startsWith(searchLower);

        if (aStartsWith && !bStartsWith) return -1;
        if (!aStartsWith && bStartsWith) return 1;
        return 0; // Keep original order if both match type
      });

      // Return limited results
      final finalResults = matchedUsers.take(limit).toList();

      AppLogger.i('User search completed',
          category: LogCategory.general,
          data: {
            'query': query,
            'results_count': finalResults.length,
            'total_candidates': uniqueUsers.length,
            'deleted_filtered': deletedUserIds.length,
          });

      return finalResults;
    } catch (e) {
      AppLogger.e('Error searching users',
          category: LogCategory.general,
          error: e,
          data: {
            'query': query,
            'error_type': e.runtimeType.toString(),
            'error_message': e.toString(),
          });
      return [];
    }
  }

  /// Search spaces by name with smart matching
  /// Returns a list of QueryDocumentSnapshot for PUBLIC spaces matching the query
  /// Private spaces (spaceType 2=private, 3=personal) are excluded from search results
  Future<List<QueryDocumentSnapshot>> searchSpaces(
    String query, {
    int limit = 20,
  }) async {
    try {
      if (query.trim().isEmpty) {
        // Return only PUBLIC spaces if query is empty
        // Public: open (0), public (1)
        // Private: private (2), personal (3)
        final snapshot = await _firestore
            .collection('spaces')
            .where('spaceType', whereIn: [0, 1])
            .limit(limit)
            .get();

        // Filter out spaces with limited visibility
        return snapshot.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>?;
          if (data == null) return false;
          final limitedVisibility = data['limitedVisibility'] as bool? ?? false;
          return !limitedVisibility;
        }).toList();
      }

      final searchLower = query.toLowerCase().trim();
      final searchUpper = '${searchLower}z'; // For prefix search
      final fetchLimit = (limit * 3).clamp(20, 100); // Fetch more for filtering

      // Search by name (prefix search)
      final snapshot = await _firestore
          .collection('spaces')
          .where('name', isGreaterThanOrEqualTo: searchLower)
          .where('name', isLessThan: searchUpper)
          .limit(fetchLimit)
          .get();

      // Apply smart matching and filter out private spaces
      final List<QueryDocumentSnapshot> matchedSpaces = [];
      for (final doc in snapshot.docs) {
        final spaceData = doc.data() as Map<String, dynamic>?;
        if (spaceData == null) continue;

        // Filter out private spaces (spaceType >= 2) and limited visibility
        final spaceType = spaceData['spaceType'] as int? ?? 2;
        final limitedVisibility =
            spaceData['limitedVisibility'] as bool? ?? false;
        if (spaceType >= 2 || limitedVisibility) {
          continue; // Skip private spaces
        }

        final name = spaceData['name'] as String? ?? '';

        // Use smart matching on space name
        if (smartMatch(query, name)) {
          matchedSpaces.add(doc);
        }
      }

      // Sort by relevance (exact prefix matches first)
      matchedSpaces.sort((a, b) {
        final aData = a.data() as Map<String, dynamic>;
        final bData = b.data() as Map<String, dynamic>;
        final aName = (aData['name'] as String? ?? '').toLowerCase();
        final bName = (bData['name'] as String? ?? '').toLowerCase();

        final aStartsWith = aName.startsWith(searchLower);
        final bStartsWith = bName.startsWith(searchLower);

        if (aStartsWith && !bStartsWith) return -1;
        if (!aStartsWith && bStartsWith) return 1;
        return 0;
      });

      return matchedSpaces.take(limit).toList();
    } catch (e) {
      AppLogger.e('Error searching spaces',
          category: LogCategory.general,
          error: e,
          data: {
            'query': query,
            'error_type': e.runtimeType.toString(),
          });
      return [];
    }
  }

  /// Search posts by content or title
  /// Returns a list of QueryDocumentSnapshot for posts matching the query
  Future<List<QueryDocumentSnapshot>> searchPosts(
    String query, {
    int limit = 40,
  }) async {
    try {
      if (query.trim().isEmpty) {
        return [];
      }

      final searchLower = query.toLowerCase();
      final searchUpper = '${searchLower}z'; // For prefix search

      // Search by title if it exists, otherwise search by content
      // Note: Firestore doesn't support full-text search, so this is prefix-based
      final titleQuery = _firestore
          .collection('posts')
          .where('title', isGreaterThanOrEqualTo: searchLower)
          .where('title', isLessThan: searchUpper)
          .limit(limit);

      final snapshot = await titleQuery.get();
      return snapshot.docs;
    } catch (e) {
      AppLogger.e('Error searching posts',
          category: LogCategory.general,
          error: e,
          data: {
            'query': query,
            'error_type': e.runtimeType.toString(),
          });
      return [];
    }
  }

  /// Get user data from a document snapshot
  static Map<String, dynamic>? getUserData(QueryDocumentSnapshot doc) {
    return doc.data() as Map<String, dynamic>?;
  }

  /// Get space data from a document snapshot
  static Map<String, dynamic>? getSpaceData(QueryDocumentSnapshot doc) {
    return doc.data() as Map<String, dynamic>?;
  }

  /// Get post data from a document snapshot
  static Map<String, dynamic>? getPostData(QueryDocumentSnapshot doc) {
    return doc.data() as Map<String, dynamic>?;
  }
}
