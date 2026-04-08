import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:aurogram/core/logging/app_logger.dart';
import 'package:aurogram/shared/services/analytics_service.dart';

/// Service for handling repost and quote post functionality
/// Uses Cloud Functions for repost operations (Twitter-style reference-only model)
class RepostService {
  static final RepostService _instance = RepostService._internal();
  factory RepostService() => _instance;
  RepostService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'asia-southeast2');

  /// Live current user - never cached, so logout/login always uses the active account.
  User? get _currentUser => FirebaseAuth.instance.currentUser;

  /// Repost a post to user's profile
  /// Returns the new repost ID
  Future<String> repostToProfile({
    required String originalPostId,
    required Map<String, dynamic> originalPostData,
    String? additionalComment,
  }) async {
    if (_currentUser == null) {
      throw Exception('User not authenticated');
    }

    try {
      final callable = _functions.httpsCallable('createRepost');
      final result = await callable.call({
        'originalPostId': originalPostId,
        'contextType': 'profile',
        'contextId': null,
      });

      final repostId = result.data['repostId'] as String;

      // Track analytics
      AnalyticsService().trackContentShared(
        contentType: 'repost_to_profile',
        itemId: originalPostId,
      );

      AppLogger.i('Reposted to profile', data: {
        'originalPostId': originalPostId,
        'repostId': repostId,
      });

      return repostId;
    } on FirebaseFunctionsException catch (e) {
      AppLogger.e('Error reposting to profile', error: e);
      throw Exception('Failed to repost: ${e.message}');
    } catch (e) {
      AppLogger.e('Error reposting to profile', error: e);
      rethrow;
    }
  }

  /// Repost a post to a specific gram/space
  /// Returns the new repost ID
  Future<String> repostToGram({
    required String gramId,
    required String originalPostId,
    required Map<String, dynamic> originalPostData,
    String? additionalComment,
  }) async {
    if (_currentUser == null) {
      throw Exception('User not authenticated');
    }

    try {
      final callable = _functions.httpsCallable('createRepost');
      final result = await callable.call({
        'originalPostId': originalPostId,
        'contextType': 'space',
        'contextId': gramId,
      });

      final repostId = result.data['repostId'] as String;

      // Track analytics
      AnalyticsService().trackContentShared(
        contentType: 'repost_to_gram',
        itemId: originalPostId,
      );

      AppLogger.i('Reposted to gram', data: {
        'originalPostId': originalPostId,
        'gramId': gramId,
        'repostId': repostId,
      });

      return repostId;
    } on FirebaseFunctionsException catch (e) {
      AppLogger.e('Error reposting to gram', error: e);
      throw Exception('Failed to repost: ${e.message}');
    } catch (e) {
      AppLogger.e('Error reposting to gram', error: e);
      rethrow;
    }
  }

  /// Create a quote post (repost with your own commentary)
  /// Note: Quote posts are still handled client-side as they create new content
  Future<String> createQuotePost({
    required String quotedPostId,
    required Map<String, dynamic> quotedPostData,
    required String commentary,
    String? targetGramId, // null = post to profile
  }) async {
    if (_currentUser == null) {
      throw Exception('User not authenticated');
    }

    try {
      final userId = _currentUser!.uid;
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final userData = userDoc.data() ?? {};

      // Prepare quoted post data (minimal data for preview)
      final quotedDataForEmbed = {
        'author': quotedPostData['author'],
        'authorName': quotedPostData['authorName'],
        'authorAvatar': quotedPostData['authorAvatar'],
        'postType': quotedPostData['postType'],
        'title': quotedPostData['title'],
        'content': quotedPostData['content'],
        'thumbnail': quotedPostData['thumbnail'],
        'timestamp': quotedPostData['timestamp'],
      };

      // Create quote post document
      final quotePostData = {
        'author': userId,
        'authorName': userData['name'] as String?,
        'authorAvatar': userData['profilePicture'] as String?,
        'contextType': targetGramId != null ? 'space' : 'profile',
        'contextId': targetGramId,
        if (targetGramId != null) 'space': targetGramId,
        'postType': 'text', // Quote posts are text posts with embedded content
        'content': commentary,
        'quotedPostId': quotedPostId,
        'quotedPostData': quotedDataForEmbed,
        'likeCount': 0,
        'replyCount': 0,
        'repostCount': 0,
        'uploading': false,
        'timestamp': FieldValue.serverTimestamp(),
      };

      // Add quote post
      DocumentReference quotePostRef;
      if (targetGramId != null) {
        // Post to gram
        quotePostRef = await _firestore
            .collection('spaces')
            .doc(targetGramId)
            .collection('posts')
            .add(quotePostData);
      } else {
        // Post to user's profile
        quotePostRef = await _firestore
            .collection('posts')
            .doc(userId)
            .collection('userPosts')
            .add(quotePostData);
      }

      // Increment repost count on quoted post (quote posts count as reposts)
      await _incrementRepostCount(quotedPostId, quotedPostData);

      // Track analytics
      AnalyticsService().trackContentShared(
        contentType: 'quote_post',
        itemId: quotedPostId,
      );

      AppLogger.i('Created quote post', data: {
        'quotedPostId': quotedPostId,
        'quotePostId': quotePostRef.id,
        'targetGram': targetGramId,
      });

      return quotePostRef.id;
    } catch (e) {
      AppLogger.e('Error creating quote post', error: e);
      rethrow;
    }
  }

  /// Increment repost count on the original post
  /// Note: This is only used for quote posts now (reposts use Cloud Functions)
  Future<void> _incrementRepostCount(
    String postId,
    Map<String, dynamic> postData,
  ) async {
    try {
      final contextType = postData['contextType'] as String?;
      final spaceId =
          postData['contextId'] as String? ?? postData['space'] as String?;

      if (contextType == 'profile') {
        // Profile posts live in top-level posts collection
        await _firestore.collection('posts').doc(postId).update({
          'repostCount': FieldValue.increment(1),
        });
      } else if (spaceId != null) {
        await _firestore
            .collection('spaces')
            .doc(spaceId)
            .collection('posts')
            .doc(postId)
            .update({
          'repostCount': FieldValue.increment(1),
        });
      }
    } catch (e) {
      AppLogger.w('Failed to increment repost count',
          data: {'postId': postId, 'error': e.toString()});
    }
  }

  /// Check if current user has already reposted this post
  /// Queries the reposts collection (new architecture)
  /// If contextId is null, checks for profile reposts (contextId == null)
  Future<bool> hasUserReposted(String originalPostId, {String? contextId}) async {
    if (_currentUser == null) return false;

    try {
      final userId = _currentUser!.uid;

      Query query = _firestore
          .collection('reposts')
          .where('reposterId', isEqualTo: userId)
          .where('originalPostId', isEqualTo: originalPostId)
          .limit(10); // Get multiple to filter by contextId if needed

      final snapshot = await query.get();
      
      if (snapshot.docs.isEmpty) {
        return false;
      }

      // If contextId is provided, filter by it (for space reposts)
      if (contextId != null) {
        return snapshot.docs.any((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final docContextId = data['contextId'];
          // Check for exact match (handles null, empty string, or actual value)
          return docContextId == contextId;
        });
      } else {
        // For profile reposts, contextId should be null or missing
        return snapshot.docs.any((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final docContextId = data['contextId'];
          // Check if contextId is null, missing, or empty string (all mean profile repost)
          return docContextId == null || docContextId == '';
        });
      }
    } catch (e) {
      AppLogger.e('Error checking repost status', error: e, data: {
        'originalPostId': originalPostId,
        'contextId': contextId,
      });
      return false;
    }
  }

  /// Returns the repost document id for the current user's repost of [originalPostId], or null.
  /// Queries the reposts collection (new architecture)
  /// If contextId is null, returns profile repost (contextId == null)
  Future<String?> getRepostDocId(String originalPostId, {String? contextId}) async {
    if (_currentUser == null) return null;

    try {
      // Query without contextId filter first (to avoid isNull index issues)
      Query query = _firestore
          .collection('reposts')
          .where('reposterId', isEqualTo: _currentUser!.uid)
          .where('originalPostId', isEqualTo: originalPostId)
          .limit(10); // Get multiple to filter by contextId

      final snapshot = await query.get();
      
      if (snapshot.docs.isEmpty) {
        return null;
      }

      // Filter by contextId in memory
      if (contextId != null) {
        // Find repost with matching contextId
        for (final doc in snapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
          if (data['contextId'] == contextId) {
            return doc.id;
          }
        }
      } else {
        // Find profile repost (contextId == null)
        for (final doc in snapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
          if (data['contextId'] == null) {
            return doc.id;
          }
        }
      }

      return null;
    } catch (e) {
      AppLogger.e('Error getting repost doc id', error: e);
      return null;
    }
  }

  /// Remove the current user's repost of [originalPostId]. Idempotent if not reposted.
  /// Uses Cloud Function to delete repost
  /// If contextId is null, tries to find profile repost first, then any repost
  Future<void> undoRepost(
      String originalPostId, Map<String, dynamic>? originalPostData,
      {String? contextId}) async {
    if (_currentUser == null) return;

    // Extract contextId from postData if not provided
    String? effectiveContextId = contextId;
    if (effectiveContextId == null && originalPostData != null) {
      effectiveContextId = originalPostData['contextId'] as String? ?? 
                          originalPostData['space'] as String?;
      // If contextType is profile, ensure contextId is null
      if (originalPostData['contextType'] == 'profile') {
        effectiveContextId = null;
      }
    }

    // Try to find repost - first try with contextId (profile or specific space)
    String? repostId = await getRepostDocId(originalPostId, contextId: effectiveContextId);
    
    // If not found and contextId was null, try finding any repost (fallback)
    if (repostId == null && effectiveContextId == null) {
      // Query for any repost by this user for this post
      try {
        final snapshot = await _firestore
            .collection('reposts')
            .where('reposterId', isEqualTo: _currentUser!.uid)
            .where('originalPostId', isEqualTo: originalPostId)
            .limit(1)
            .get();
        
        if (snapshot.docs.isNotEmpty) {
          repostId = snapshot.docs.first.id;
        }
      } catch (e) {
        AppLogger.w('Error finding repost for undo', data: {'error': e.toString()});
      }
    }

    if (repostId == null) {
      AppLogger.i('No repost found to undo', data: {'originalPostId': originalPostId});
      return;
    }

    try {
      final callable = _functions.httpsCallable('deleteRepost');
      await callable.call({'repostId': repostId});

      AppLogger.i('Removed repost', data: {
        'originalPostId': originalPostId,
        'repostId': repostId,
      });
    } on FirebaseFunctionsException catch (e) {
      AppLogger.e('Error removing repost', error: e);
      throw Exception('Failed to remove repost: ${e.message}');
    } catch (e) {
      AppLogger.e('Error removing repost', error: e);
      rethrow;
    }
  }

  /// Get reposts of a specific post
  Stream<List<Map<String, dynamic>>> getReposts(String postId) {
    return _firestore
        .collection('reposts')
        .where('originalPostId', isEqualTo: postId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            final result = <String, dynamic>{'id': doc.id};
            result.addAll(Map<String, dynamic>.from(data));
            return result;
          }).toList();
        });
  }
}
