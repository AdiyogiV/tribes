import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:aurogram/models/dm_conversation.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:aurogram/utils/logging/app_logger.dart';
import 'package:aurogram/services/search_service.dart';
import 'package:aurogram/utils/theme/app_dimensions.dart';

/// Batch prefetches user names for DM conversations to avoid repeated Firestore calls.
Future<void> prefetchUserNames(
  List<DmConversation> conversations,
  Map<String, String> userNameCache,
) async {
  final unknownUserIds = conversations
      .where((c) => c.id.startsWith('dm_'))
      .map((c) => c.otherUserId)
      .where((id) => !userNameCache.containsKey(id))
      .toSet()
      .toList();

  if (unknownUserIds.isEmpty) return;

  // Batch query in chunks of 10 (Firestore whereIn limit)
  for (var i = 0; i < unknownUserIds.length; i += 10) {
    final chunk = unknownUserIds.skip(i).take(10).toList();
    try {
      final docs = await FirebaseFirestore.instance
          .collection('users')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();

      for (final doc in docs.docs) {
        final data = doc.data();
        userNameCache[doc.id] =
            data['name'] as String? ?? data['nickname'] as String? ?? doc.id;
      }
    } catch (e) {
      AppLogger.w('Error batch fetching user names',
          category: LogCategory.ui, data: {'error': e.toString()});
    }
  }
}

/// Filters conversations by search query using smart matching.
/// Async because it may need to fetch user names for DM conversations.
Future<List<DmConversation>> filterConversationsBySearch(
  List<DmConversation> conversations,
  String query,
  Future<String> Function(String userId) getUserName,
) async {
  if (query.trim().isEmpty) return conversations;

  final List<Future<bool>> matchFutures =
      conversations.map((conversation) async {
    // For space conversations, search by space name
    if (conversation.spaceName != null) {
      if (SearchService.smartMatch(query, conversation.spaceName!)) {
        return true;
      }
    } else {
      // For DM conversations, fetch user name and search by it
      final userName = await getUserName(conversation.otherUserId);
      if (SearchService.smartMatch(query, userName)) {
        return true;
      }
    }

    // Search in last message content
    if (conversation.lastMessageContent != null &&
        SearchService.smartMatch(query, conversation.lastMessageContent!)) {
      return true;
    }

    return false;
  }).toList();

  final matches = await Future.wait(matchFutures);

  final List<DmConversation> filtered = [];
  for (int i = 0; i < conversations.length; i++) {
    if (matches[i]) filtered.add(conversations[i]);
  }
  return filtered;
}

/// Searches users via Firestore with debounce-awareness.
Future<void> searchUsersInFirestore({
  required String query,
  required int minSearchLength,
  required String currentSearchQuery,
  required SearchService searchService,
  required bool Function() isMounted,
  required List<QueryDocumentSnapshot> currentResults,
  required bool Function(List<QueryDocumentSnapshot>, List<QueryDocumentSnapshot>)
      areSameResults,
  required void Function({
    required List<QueryDocumentSnapshot> results,
    required bool isSearching,
  }) onResultsUpdated,
}) async {
  if (query.trim().length < minSearchLength) {
    if (currentResults.isEmpty) return;
    onResultsUpdated(results: [], isSearching: false);
    return;
  }

  // Don't search if query changed while we were waiting
  if (currentSearchQuery != query) return;

  try {
    final stopwatch = Stopwatch()..start();
    final results = await searchService.searchUsers(query, limit: 50);

    if (!isMounted() || currentSearchQuery != query) return;

    final newResults = areSameResults(currentResults, results)
        ? currentResults
        : results;
    onResultsUpdated(results: newResults, isSearching: false);

    stopwatch.stop();
    AppLogger.i('Messages user search completed',
        category: LogCategory.ui,
        data: {
          'query': query,
          'results': results.length,
          'duration_ms': stopwatch.elapsedMilliseconds,
        });
  } catch (e) {
    AppLogger.e('Error searching users in Firestore',
        category: LogCategory.ui, error: e);
    if (isMounted() && currentSearchQuery == query) {
      onResultsUpdated(results: [], isSearching: false);
    }
  }
}

/// Builds a widget showing a user name, loading from Firestore if not cached.
Widget buildUserNameText({
  required String userId,
  required Map<String, String> userNameCache,
  required Future<String> Function(String userId) getUserName,
}) {
  if (userNameCache.containsKey(userId)) {
    return Text(
      userNameCache[userId]!,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: AppTheme.primaryColor,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  return FutureBuilder<String>(
    future: getUserName(userId),
    builder: (context, snapshot) {
      if (snapshot.hasData &&
          snapshot.data != null &&
          snapshot.data!.isNotEmpty) {
        return Text(
          snapshot.data!,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppTheme.primaryColor,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
      }

      return Container(
        height: 14,
        width: 100,
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppDimensions.radiusSmMd),
        ),
      );
    },
  );
}
