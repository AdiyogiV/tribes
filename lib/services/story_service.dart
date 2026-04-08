import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aurogram/models/story.dart';
import 'package:aurogram/models/post.dart';
import 'package:aurogram/services/media/media_storage_service.dart';
import 'package:aurogram/services/share/share_media.dart';
import 'package:aurogram/utils/logging/app_logger.dart';

/// Service for creating and loading 24h ephemeral stories.
class StoryService {
  static final StoryService _instance = StoryService._internal();
  factory StoryService() => _instance;
  StoryService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final MediaStorageService _storage = MediaStorageService();

  User? get _currentUser => FirebaseAuth.instance.currentUser;

  /// Create a story from uploaded media bytes.
  /// Uploads to Storage at stories/{uid}/{storyId}.{ext}, writes Firestore doc, updates user's lastStoryExpiresAt.
  Future<String?> createStory({
    required Uint8List bytes,
    required StoryMediaType mediaType,
    String? contentType,
    String? sourceType,
    String? sourceId,
    Function(double)? onProgress,
  }) async {
    final uid = _currentUser?.uid;
    if (uid == null) {
      AppLogger.e('StoryService.createStory: not authenticated',
          category: LogCategory.general);
      return null;
    }

    try {
      final storyRef =
          _firestore.collection('users').doc(uid).collection('stories').doc();
      final storyId = storyRef.id;
      final now = DateTime.now();
      final expiresAt = now.add(const Duration(hours: 24));

      final ext = mediaType == StoryMediaType.video ? 'mp4' : 'jpg';
      final storagePath = 'stories/$uid/$storyId.$ext';
      final effectiveContentType =
          contentType ?? (mediaType == StoryMediaType.video ? 'video/mp4' : 'image/jpeg');

      final mediaUrl = await _storage.uploadFromBytes(
        bytes,
        storagePath,
        contentType: effectiveContentType,
        onProgress: onProgress,
      );
      if (mediaUrl == null) {
        AppLogger.e('StoryService.createStory: upload failed',
            category: LogCategory.media);
        return null;
      }

      final story = Story(
        id: storyId,
        authorId: uid,
        mediaUrl: mediaUrl,
        mediaType: mediaType,
        createdAt: now,
        expiresAt: expiresAt,
        sourceType: sourceType,
        sourceId: sourceId,
      );

      await storyRef.set(story.toMap());

      await _firestore.collection('users').doc(uid).set(
        {'lastStoryExpiresAt': Timestamp.fromDate(expiresAt)},
        SetOptions(merge: true),
      );

      AppLogger.d('Story created',
          category: LogCategory.general,
          data: {
            'storyId': storyId,
            'authorId': uid,
            'mediaUrlLength': mediaUrl.length,
            'mediaUrlPrefix': mediaUrl.length > 80 ? '${mediaUrl.substring(0, 80)}...' : mediaUrl,
            'mediaType': mediaType == StoryMediaType.video ? 'video' : 'image',
          });
      return storyId;
    } catch (e, st) {
      AppLogger.e('StoryService.createStory failed',
          category: LogCategory.general, error: e, stackTrace: st);
      return null;
    }
  }

  /// Create a story from an existing media URL (e.g. reshare post media without re-upload).
  Future<String?> createStoryFromUrl({
    required String mediaUrl,
    required StoryMediaType mediaType,
    String? sourceType,
    String? sourceId,
  }) async {
    final uid = _currentUser?.uid;
    if (uid == null) return null;

    try {
      final storyRef =
          _firestore.collection('users').doc(uid).collection('stories').doc();
      final storyId = storyRef.id;
      final now = DateTime.now();
      final expiresAt = now.add(const Duration(hours: 24));

      final story = Story(
        id: storyId,
        authorId: uid,
        mediaUrl: mediaUrl,
        mediaType: mediaType,
        createdAt: now,
        expiresAt: expiresAt,
        sourceType: sourceType,
        sourceId: sourceId,
      );

      await storyRef.set(story.toMap());

      await _firestore.collection('users').doc(uid).set(
        {'lastStoryExpiresAt': Timestamp.fromDate(expiresAt)},
        SetOptions(merge: true),
      );

      return storyId;
    } catch (e) {
      AppLogger.e('StoryService.createStoryFromUrl failed',
          category: LogCategory.general, error: e);
      return null;
    }
  }

  /// Fetch post and author data for rendering a story card.
  /// Returns a map with 'post', 'authorName', 'authorAvatar' keys,
  /// or null if the post doesn't exist.
  Future<Map<String, dynamic>?> fetchPostStoryData({
    required String postId,
  }) async {
    try {
      final postDoc = await _firestore.collection('posts').doc(postId).get();
      if (!postDoc.exists) {
        AppLogger.e('StoryService.fetchPostStoryData: post not found',
            category: LogCategory.general, data: {'postId': postId});
        return null;
      }

      final post = Post.fromDocument(postDoc);

      final authorDoc = await _firestore.collection('users').doc(post.authorId).get();
      final authorData = authorDoc.data();
      final authorName = authorData?['name'] as String? ??
          authorData?['nickname'] as String? ??
          'Unknown User';
      final authorAvatar = authorData?['displayPicture'] as String?;

      return {
        'post': post,
        'authorName': authorName,
        'authorAvatar': authorAvatar,
      };
    } catch (e, st) {
      AppLogger.e('StoryService.fetchPostStoryData failed',
          category: LogCategory.general,
          error: e,
          stackTrace: st,
          data: {'postId': postId});
      return null;
    }
  }

  /// Render a pre-built story card widget to image bytes.
  /// The caller is responsible for constructing the card widget (e.g. PostStoryCard).
  /// Does NOT upload or create story - that happens when user confirms in StoryComposerPage.
  Future<Uint8List?> renderStoryCard({
    required Widget cardWidget,
  }) async {
    try {
      final bytes = await ShareMedia.captureWidgetToBytes(card: cardWidget);
      if (bytes == null) {
        AppLogger.e('StoryService.renderStoryCard: widget capture failed',
            category: LogCategory.general);
        return null;
      }

      AppLogger.d('Story card rendered',
          category: LogCategory.general,
          data: {'bytesLength': bytes.length});

      return bytes;
    } catch (e, st) {
      AppLogger.e('StoryService.renderStoryCard failed',
          category: LogCategory.general,
          error: e,
          stackTrace: st);
      return null;
    }
  }

  static const String _keyViewedStoryUserIds = 'story_viewed_user_ids';

  /// Mark that the current user has viewed stories for [userId] (persisted locally for ring "viewed" state).
  Future<void> markStoriesViewedForUser(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_keyViewedStoryUserIds) ?? [];
      if (!list.contains(userId)) {
        list.add(userId);
        await prefs.setStringList(_keyViewedStoryUserIds, list);
      }
    } catch (e) {
      AppLogger.w('StoryService.markStoriesViewedForUser failed',
          category: LogCategory.general, data: {'error': e.toString()});
    }
  }

  /// Returns set of user IDs whose stories the current user has viewed (for ring gradient: viewed = grey).
  Future<Set<String>> getViewedStoryUserIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_keyViewedStoryUserIds) ?? [];
      return list.toSet();
    } catch (_) {
      return {};
    }
  }

  /// Returns list of user IDs who have at least one unexpired story: self first, then following (confirmed) ordered by lastStoryExpiresAt desc.
  Future<List<String>> getUsersWithStories({bool forceRefresh = false}) async {
    final uid = _currentUser?.uid;
    if (uid == null) return [];

    try {
      final getOpts = forceRefresh
          ? const GetOptions(source: Source.server)
          : const GetOptions(source: Source.serverAndCache);
      
      final followingSnapshot = await _firestore
          .collection('userFollowing')
          .doc(uid)
          .collection('following')
          .where('status', isEqualTo: 'following')
          .get(getOpts);

      final followingIds =
          followingSnapshot.docs.map((d) => d.id).toList();

      final candidateIds = [uid, ...followingIds];
      final now = DateTime.now();
      final results = <_UserStoryHead>[];

      for (var i = 0; i < candidateIds.length; i += 10) {
        final batch = candidateIds.skip(i).take(10).toList();
        final userDocs = await Future.wait(
          batch.map((id) => _firestore.collection('users').doc(id).get(getOpts)),
        );
        for (var j = 0; j < batch.length; j++) {
          final doc = userDocs[j];
          final data = doc.data();
          final lastStoryExpiresAt = data?['lastStoryExpiresAt'] as Timestamp?;
          if (lastStoryExpiresAt != null) {
            final expiresAt = lastStoryExpiresAt.toDate();
            if (expiresAt.isAfter(now)) {
              results.add(_UserStoryHead(
                userId: batch[j],
                lastStoryExpiresAt: expiresAt,
              ));
            }
          }
        }
      }

      results.sort((a, b) {
        if (a.userId == uid) return -1;
        if (b.userId == uid) return 1;
        return b.lastStoryExpiresAt.compareTo(a.lastStoryExpiresAt);
      });

      final userIds = results.map((e) => e.userId).toList();
      AppLogger.i('StoryService.getUsersWithStories',
          category: LogCategory.general,
          data: {
            'count': userIds.length,
            'userIds': userIds.map((id) => '${id.substring(0, 6)}…').toList(),
          });
      return userIds;
    } catch (e) {
      AppLogger.e('StoryService.getUsersWithStories failed',
          category: LogCategory.general, error: e);
      return [];
    }
  }

  /// Load stories for a user (unexpired only), ordered by createdAt descending (newest first).
  /// Returns list in chronological order (oldest first) for playback.
  Future<List<Story>> getStoriesForUser(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('stories')
          .orderBy('createdAt', descending: true)
          .get(const GetOptions(source: Source.serverAndCache));

      final list = snapshot.docs
          .map((d) => Story.fromFirestore(d))
          .where((s) => !s.isExpired)
          .toList();
      list.sort((a, b) => a.createdAt.compareTo(b.createdAt));

      AppLogger.i('StoryService.getStoriesForUser',
          category: LogCategory.general,
          data: {
            'userId': userId,
            'rawDocCount': snapshot.docs.length,
            'afterExpiryFilter': list.length,
            'stories': list.map((s) => {
                  'id': s.id,
                  'mediaUrlLength': s.mediaUrl.length,
                  'mediaUrlEmpty': s.mediaUrl.isEmpty,
                  'mediaType': s.mediaType == StoryMediaType.video ? 'video' : 'image',
                }).toList(),
          });
      return list;
    } catch (e) {
      AppLogger.e('StoryService.getStoriesForUser failed',
          category: LogCategory.general, error: e, data: {'userId': userId});
      return [];
    }
  }

  /// Delete a story. Only the author can delete their own stories.
  /// Removes Firestore doc. Note: doesn't delete from Storage (Storage has auto-deletion rules).
  /// Also updates lastStoryExpiresAt if this was the last story.
  Future<bool> deleteStory({
    required String userId,
    required String storyId,
  }) async {
    final uid = _currentUser?.uid;
    if (uid == null) {
      AppLogger.e('StoryService.deleteStory: not authenticated',
          category: LogCategory.general);
      return false;
    }

    // Only allow deleting own stories
    if (uid != userId) {
      AppLogger.w('StoryService.deleteStory: user cannot delete another user\'s story',
          category: LogCategory.general,
          data: {'currentUid': uid, 'targetUserId': userId, 'storyId': storyId});
      return false;
    }

    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('stories')
          .doc(storyId)
          .delete();

      // Check if there are any remaining unexpired stories
      final remainingStories = await getStoriesForUser(userId);
      
      if (remainingStories.isEmpty) {
        // No more stories - remove lastStoryExpiresAt
        await _firestore.collection('users').doc(userId).update({
          'lastStoryExpiresAt': FieldValue.delete(),
        });
        AppLogger.i('Story deleted, lastStoryExpiresAt removed (no remaining stories)',
            category: LogCategory.general,
            data: {'userId': userId, 'storyId': storyId});
      } else {
        // Update lastStoryExpiresAt to the latest remaining story's expiry
        final latestExpiry = remainingStories.map((s) => s.expiresAt).reduce((a, b) => a.isAfter(b) ? a : b);
        await _firestore.collection('users').doc(userId).set(
          {'lastStoryExpiresAt': Timestamp.fromDate(latestExpiry)},
          SetOptions(merge: true),
        );
        AppLogger.i('Story deleted, lastStoryExpiresAt updated',
            category: LogCategory.general,
            data: {'userId': userId, 'storyId': storyId, 'newExpiry': latestExpiry.toIso8601String()});
      }

      AppLogger.i('Story deleted',
          category: LogCategory.general,
          data: {'userId': userId, 'storyId': storyId});

      // Note: We don't delete from Firebase Storage here.
      // Storage files can be cleaned up by Firebase Storage lifecycle rules.
      return true;
    } catch (e, st) {
      AppLogger.e('StoryService.deleteStory failed',
          category: LogCategory.general,
          error: e,
          stackTrace: st,
          data: {'userId': userId, 'storyId': storyId});
      return false;
    }
  }

  /// Track a view for a story. Stores viewer ID in stories/{userId}/stories/{storyId}/views/{viewerId}.
  /// Only tracks once per viewer per story (idempotent).
  Future<void> trackStoryView({
    required String userId,
    required String storyId,
  }) async {
    final viewerId = _currentUser?.uid;
    if (viewerId == null) return;
    
    // Don't track views of own stories
    if (viewerId == userId) return;
    
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('stories')
          .doc(storyId)
          .collection('views')
          .doc(viewerId)
          .set({
        'viewedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      AppLogger.d('Story view tracked',
          category: LogCategory.general,
          data: {'storyId': storyId, 'viewerId': viewerId, 'authorId': userId});
    } catch (e) {
      AppLogger.w('StoryService.trackStoryView failed',
          category: LogCategory.general, data: {'error': e.toString()});
    }
  }

  /// Get view count for a story.
  Future<int> getStoryViewCount({
    required String userId,
    required String storyId,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('stories')
          .doc(storyId)
          .collection('views')
          .get(const GetOptions(source: Source.serverAndCache));
      
      return snapshot.docs.length;
    } catch (e) {
      AppLogger.w('StoryService.getStoryViewCount failed',
          category: LogCategory.general, data: {'error': e.toString()});
      return 0;
    }
  }

  /// Get list of viewer IDs for a story (for displaying who viewed).
  Future<List<String>> getStoryViewers({
    required String userId,
    required String storyId,
    int limit = 50,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('stories')
          .doc(storyId)
          .collection('views')
          .orderBy('viewedAt', descending: true)
          .limit(limit)
          .get(const GetOptions(source: Source.serverAndCache));
      
      return snapshot.docs.map((doc) => doc.id).toList();
    } catch (e) {
      AppLogger.w('StoryService.getStoryViewers failed',
          category: LogCategory.general, data: {'error': e.toString()});
      return [];
    }
  }
}

class _UserStoryHead {
  final String userId;
  final DateTime lastStoryExpiresAt;
  _UserStoryHead({required this.userId, required this.lastStoryExpiresAt});
}
