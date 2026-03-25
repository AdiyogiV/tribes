import 'dart:async';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:aurogram/widgets/main_player.dart';
import 'package:aurogram/widgets/text_note_player.dart';
import 'package:aurogram/widgets/audio_note_player.dart';
import 'package:aurogram/widgets/image_note_player.dart';
import 'package:aurogram/widgets/context_menu.dart';
import 'package:aurogram/widgets/post_replies.dart';
import 'package:aurogram/utils/dependency_injection.dart';
import 'package:aurogram/services/data/post_db_service.dart';
import 'package:aurogram/services/batch_data_loader.dart';
import 'package:aurogram/controllers/feed_controller.dart';
import 'package:aurogram/utils/logging/app_logger.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:aurogram/utils/time_display.dart';
import 'package:aurogram/widgets/ui/skeleton_widgets.dart';
import 'package:aurogram/widgets/posts/reply_indicator.dart';
import 'package:aurogram/widgets/posts/reposted_by_indicator.dart';
import 'package:aurogram/widgets/posts/repost_indicator.dart';
import 'package:aurogram/widgets/posts/post_action_toolbar.dart';
import 'package:aurogram/widgets/posts/post_options_sheet.dart';
import 'package:aurogram/widgets/post_header.dart';
import 'package:aurogram/services/user_service.dart';
import 'package:aurogram/services/share_service.dart';
import 'package:aurogram/services/share/share_links.dart';
import 'package:aurogram/services/repost_service.dart';
import 'package:aurogram/widgets/common/snack_bar_service.dart';
import 'package:aurogram/utils/performance/image_optimizer.dart';

typedef ReplyCallback = void Function(String post);

class PostData {
  final String? author;
  final String? space;
  final String? contextType;
  final bool? uploading;
  final String? video;
  final String? title;
  final String? thumbnail;
  final String? link;
  final String? content;
  final String? postType;
  final String? audioUrl;
  final int? durationInSeconds;
  final Timestamp? timestamp;
  final String? replyTo;
  final bool isRepost;
  final String? originalPostId;
  final String? originalAuthorId;
  final String? originalAuthorName;
  final String? quotedPostId;
  final Map<String, dynamic>? quotedPostData;

  const PostData({
    required this.author,
    required this.space,
    required this.contextType,
    required this.uploading,
    required this.video,
    required this.title,
    required this.thumbnail,
    required this.link,
    required this.content,
    required this.postType,
    required this.audioUrl,
    required this.durationInSeconds,
    required this.timestamp,
    required this.replyTo,
    this.isRepost = false,
    this.originalPostId,
    this.originalAuthorId,
    this.originalAuthorName,
    this.quotedPostId,
    this.quotedPostData,
  });

  factory PostData.fromSnapshot(DocumentSnapshot snapshot) {
    final data = snapshot.data() as Map<String, dynamic>;
    return PostData(
      author: data['author'] as String?,
      uploading: data['uploading'] as bool? ?? false,
      title: data['title'] as String?,
      space: data['space'] as String?,
      contextType: data['contextType'] as String?,
      timestamp: data['timestamp'] as Timestamp?,
      video: data['video'] as String?,
      thumbnail: data['thumbnail'] as String?,
      link: data['link'] as String?,
      content: data['content'] as String?,
      audioUrl: data['audioUrl'] as String?,
      durationInSeconds: data['duration'] as int?,
      postType: data['postType'] as String? ?? 'video',
      replyTo: data['replyTo'] as String?,
      isRepost: data['isRepost'] as bool? ?? false,
      originalPostId: data['originalPostId'] as String?,
      originalAuthorId: data['originalAuthorId'] as String?,
      originalAuthorName: data['originalAuthorName'] as String?,
      quotedPostId: data['quotedPostId'] as String?,
      quotedPostData: data['quotedPostData'] as Map<String, dynamic>?,
    );
  }

  PostData copyWith({
    String? author,
    String? space,
    String? contextType,
    bool? uploading,
    String? video,
    String? title,
    String? thumbnail,
    String? link,
    String? content,
    String? postType,
    String? audioUrl,
    int? durationInSeconds,
    Timestamp? timestamp,
    String? replyTo,
    bool? isRepost,
    String? originalPostId,
    String? originalAuthorId,
    String? originalAuthorName,
    String? quotedPostId,
    Map<String, dynamic>? quotedPostData,
  }) {
    return PostData(
      author: author ?? this.author,
      space: space ?? this.space,
      contextType: contextType ?? this.contextType,
      uploading: uploading ?? this.uploading,
      video: video ?? this.video,
      title: title ?? this.title,
      thumbnail: thumbnail ?? this.thumbnail,
      link: link ?? this.link,
      content: content ?? this.content,
      postType: postType ?? this.postType,
      audioUrl: audioUrl ?? this.audioUrl,
      durationInSeconds: durationInSeconds ?? this.durationInSeconds,
      timestamp: timestamp ?? this.timestamp,
      replyTo: replyTo ?? this.replyTo,
      isRepost: isRepost ?? this.isRepost,
      originalPostId: originalPostId ?? this.originalPostId,
      originalAuthorId: originalAuthorId ?? this.originalAuthorId,
      originalAuthorName: originalAuthorName ?? this.originalAuthorName,
      quotedPostId: quotedPostId ?? this.quotedPostId,
      quotedPostData: quotedPostData ?? this.quotedPostData,
    );
  }
}

class ParentPostData {
  final String? parentAuthorName;
  final int parentChainCount;
  final List<DocumentSnapshot>? parentPostSnapshots;

  const ParentPostData({
    required this.parentAuthorName,
    required this.parentChainCount,
    required this.parentPostSnapshots,
  });

  static const empty = ParentPostData(
      parentAuthorName: null, parentChainCount: 0, parentPostSnapshots: null);
}

/// Main post widget - displays the current post content and owns the full block
/// (header, content, toolbar, caption, optional reply section, time).
class Post extends StatefulWidget {
  final String? post;
  final int? itemIndex;
  final int? itemDepth;
  final ReplyCallback? onReplySelected;
  final bool enableVideoAutoplay;
  final bool prewarmVideo;

  /// When true (default), fetch replies and show "View thread" + thumbnails; time last.
  final bool showReplySection;

  /// When true (default), show reply indicator ("Replying to X") if post is a reply.
  /// Set to false in thread view where the indicator is redundant.
  final bool showReplyIndicator;

  /// When set, show "X reposted" above the post (Twitter-style). Use when viewing
  /// the original post in a repost context (e.g. opened from reposter's profile).
  final String? repostedByName;
  final String? repostedByAvatarUrl;

  const Post({
    this.post,
    this.itemIndex,
    this.itemDepth,
    this.onReplySelected,
    this.enableVideoAutoplay = false,
    this.prewarmVideo = false,
    this.showReplySection = true,
    this.showReplyIndicator = true,
    this.repostedByName,
    this.repostedByAvatarUrl,
    super.key,
  });

  @override
  State<Post> createState() => _PostState();
}

class _PostState extends State<Post> with TickerProviderStateMixin {
  final PostDbService _postDbService = locator<PostDbService>();
  final BatchDataLoader _batchLoader = locator<BatchDataLoader>();

  PostData? _data;
  bool _loading = true;
  bool _missing = false;

  int _replyCount = 0;
  QuerySnapshot? _replySnapshot;
  String? _replyTo; // Parent post ID if this is a reply
  ParentPostData _parentData = ParentPostData.empty;

  // NEW: Store user/space data to pass to children
  UserData? _userData;
  SpaceData? _spaceData;

  // Repost handling: original post data and reposter info
  PostData? _originalPostData;
  UserData? _reposterUserData;
  UserData? _originalAuthorUserData;
  String?
      _reposterName; // Store reposter name from document for immediate display
  String? _reposterId; // Store reposter ID for navigation

  // New architecture: repost data from reposts collection
  DocumentSnapshot?
      _repostSnapshot; // Repost document if this post was reposted

  // Image aspect ratio for image posts (fetched before rendering)
  double? _imageAspectRatio;

  StreamSubscription<PostUpdateEvent>? _postUpdateSubscription;

  @override
  void initState() {
    super.initState();

    // DEBUG: Track first-time post builds to understand scroll-up bounce
    if (widget.itemIndex != null && widget.itemIndex! < 10) {
      print(
          '🏗️ Post ${widget.itemIndex} (${widget.post?.substring(0, 4)}) BUILDING (first time or rebuild after dispose)');
    }

    // Restore state from FeedController (fast - instant)
    if (widget.post != null && mounted) {
      try {
        final feedController = context.read<FeedController>();
        final state = feedController.getPostState(widget.post!);
        _replyCount = state.replyCount;

        // NEW: Also restore user/space data from FeedController if cached
        // This prevents the "User" → "Real Name" flicker on first render
        _userData = feedController.getUserData(widget.post!);
        _spaceData = feedController.getSpaceData(widget.post!);

        if (kDebugMode &&
            widget.itemIndex != null &&
            widget.itemIndex! < 20 &&
            (_userData != null || _spaceData != null)) {
          AppLogger.d(
            'Post: restored user/space data from FeedController',
            category: LogCategory.performance,
            data: {
              'index': widget.itemIndex,
              'postId': widget.post!.substring(0, 4),
              'hasUserData': _userData != null,
              'hasSpaceData': _spaceData != null,
            },
          );
        }
      } catch (e) {
        // FeedController not available yet (first load)
      }
    }

    // Instant render from cache if preloaded
    if (widget.post != null) {
      final cached = _postDbService.peekPost(widget.post!);
      if (cached != null && cached.exists) {
        _data = PostData.fromSnapshot(cached);
        _replyTo = _data?.replyTo;
        _loading = false;

        // Extract reposter name from cached document for reposts
        if (_data?.isRepost == true) {
          final cachedData = cached.data() as Map<String, dynamic>?;
          _reposterName = cachedData?['authorName'] as String?;
        }

        // NEW: If we don't have user/space data yet, try to load it immediately (non-blocking)
        // This kicks off the fetch in the background so it's ready faster
        if (_userData == null && _data?.author != null) {
          _batchLoader.loadUser(_data!.author!).then((userData) {
            if (mounted && userData != null) {
              setState(() {
                if (_data?.isRepost == true) {
                  _reposterUserData = userData;
                } else {
                  _userData = userData;
                }
              });
            }
          });
        }
        if (_spaceData == null && _data?.space != null) {
          _batchLoader.loadSpace(_data!.space!).then((spaceData) {
            if (mounted && spaceData != null) {
              setState(() {
                _spaceData = spaceData;
              });
            }
          });
        }

        // For reposts, also load original post and original author data
        if (_data?.isRepost == true && _data?.originalPostId != null) {
          _postDbService
              .getPost(_data!.originalPostId!)
              .then((originalSnapshot) {
            if (mounted && originalSnapshot.exists) {
              final originalData = PostData.fromSnapshot(originalSnapshot);
              if (_data?.originalAuthorId != null) {
                _batchLoader
                    .loadUser(_data!.originalAuthorId!)
                    .then((originalAuthorData) {
                  if (mounted) {
                    setState(() {
                      _originalPostData = originalData;
                      _originalAuthorUserData = originalAuthorData;
                      if (originalAuthorData != null) {
                        _userData = originalAuthorData;
                      }
                    });
                  }
                });
              }
            }
          });
        }

        if (kDebugMode && widget.itemIndex != null && widget.itemIndex! < 20) {
          AppLogger.d(
            'Post: cache hit for initial render',
            category: LogCategory.performance,
            data: {
              'index': widget.itemIndex,
              'postId': widget.post!.substring(0, 4),
              'type': _data?.postType,
              'hasUserData': _userData != null,
              'hasSpaceData': _spaceData != null,
            },
          );
        }
      }
    }

    _subscribeToPostUpdates();
    _loadPostData();
  }

  @override
  void didUpdateWidget(Post oldWidget) {
    super.didUpdateWidget(oldWidget);

    // CRITICAL: Prevent rebuilds when parent rebuilds but our postId hasn't changed
    // This is the #1 optimization for scroll performance - stops cascade rebuilds
    if (oldWidget.post == widget.post) {
      // Same post, no need to reload anything
      return;
    }

    // Post ID changed - this widget was recycled for a different post
    // Cancel old subscriptions and load new data
    _postUpdateSubscription?.cancel();
    _subscribeToPostUpdates();
    _loadPostData();
  }

  @override
  void dispose() {
    // DEBUG: Track post disposal to understand scroll-up bounce
    if (widget.itemIndex != null && widget.itemIndex! < 10) {
      print(
          '🗑️ Post ${widget.itemIndex} (${widget.post?.substring(0, 4)}) DISPOSED');
    }

    _postUpdateSubscription?.cancel();

    // Save state to FeedController before disposing
    if (widget.post != null && mounted) {
      try {
        final feedController = context.read<FeedController>();
        feedController.updateReplyCount(widget.post!, _replyCount);
        feedController.onPostDisposed(widget.post!);
      } catch (e) {
        // FeedController not available or context invalid
      }
    }

    super.dispose();
  }

  void _subscribeToPostUpdates() {
    if (widget.post == null) return;

    _postUpdateSubscription = PostDbService.postUpdates
        .where((event) => event.postId == widget.post)
        .listen((event) {
      if (mounted) {
        _updateFromSnapshot(event.document);
      }
    });
  }

  Future<void> _loadPostData() async {
    if (!mounted || widget.post == null) return;

    final startTime = DateTime.now();
    final postIdShort = widget.post!.substring(0, 4);

    if (kDebugMode && widget.itemIndex != null && widget.itemIndex! < 20) {
      AppLogger.i(
        '📡 Post data fetch START',
        category: LogCategory.performance,
        data: {'index': widget.itemIndex, 'postId': postIdShort},
      );
    }

    try {
      final snapshot = await _postDbService.getPost(widget.post);

      final fetchTime = DateTime.now();
      if (kDebugMode && widget.itemIndex != null && widget.itemIndex! < 20) {
        AppLogger.i(
          '✓ Post data fetch COMPLETE',
          category: LogCategory.performance,
          data: {
            'index': widget.itemIndex,
            'postId': postIdShort,
            'fetch_ms': fetchTime.difference(startTime).inMilliseconds,
          },
        );
      }
      if (!snapshot.exists) {
        _postDbService.markPostAsMissing(widget.post!);
        _postDbService.cleanupMissingPostReferences(widget.post!);
        if (mounted) {
          setState(() {
            _loading = true;
            _missing = true;
          });
        }
        return;
      }

      final data = PostData.fromSnapshot(snapshot);
      final snapshotData = snapshot.data() as Map<String, dynamic>?;
      final isIncomplete =
          data.timestamp == null || data.author == null || data.space == null;
      final replyToId = data.replyTo;

      // Extract reposter name from document for immediate display (before user data loads)
      final reposterName =
          data.isRepost ? (snapshotData?['authorName'] as String?) : null;

      // Debug logging for reposts
      if (kDebugMode &&
          data.isRepost &&
          widget.itemIndex != null &&
          widget.itemIndex! < 10) {
        AppLogger.d(
          'Post: REPOST DETECTED',
          category: LogCategory.ui,
          data: {
            'postId': widget.post!.substring(0, 4),
            'index': widget.itemIndex,
            'originalPostId': data.originalPostId,
            'originalAuthorId': data.originalAuthorId,
            'originalAuthorName': data.originalAuthorName,
            'reposterName': reposterName,
            'author': data.author,
          },
        );
      }

      // NEW: Load user/space data, parent posts, and replies in PARALLEL
      final parentFuture = (replyToId != null && replyToId.isNotEmpty)
          ? _loadParentPostsData(replyToId)
          : Future.value(ParentPostData.empty);

      // For reposts, load replies from the original post, not the repost
      final replyPostId = (data.isRepost && data.originalPostId != null)
          ? data.originalPostId!
          : widget.post;
      final repliesFuture = widget.showReplySection && replyPostId != null
          ? _postDbService.getPostReplies(replyPostId)
          : Future.value(null);

      // Load user and space data via BatchDataLoader (with deduplication!)
      // For reposts: load reposter's data AND original author's data
      final userFuture = data.author != null
          ? _batchLoader.loadUser(data.author!)
          : Future.value(null);
      final spaceFuture = data.space != null
          ? _batchLoader.loadSpace(data.space!)
          : Future.value(null);

      // For reposts (old model: isRepost flag), also load original post and original author data
      Future<DocumentSnapshot>? originalPostSnapshotFuture;
      Future<UserData?>? originalAuthorFuture;
      if (data.isRepost && data.originalPostId != null) {
        originalPostSnapshotFuture =
            _postDbService.getPost(data.originalPostId!);
        if (data.originalAuthorId != null) {
          originalAuthorFuture = _batchLoader.loadUser(data.originalAuthorId!);
        }
      }

      // NEW ARCHITECTURE: Check if this post has been reposted (query reposts collection)
      // This is separate from checking if the post itself IS a repost (old model)
      // Only query if post exists and is not itself a repost
      Future<QuerySnapshot>? repostsQueryFuture;
      if (!data.isRepost && !_missing) {
        // Only check reposts collection if this post is not itself a repost
        // Query for reposts where originalPostId matches this post
        repostsQueryFuture = FirebaseFirestore.instance
            .collection('reposts')
            .where('originalPostId', isEqualTo: widget.post)
            .orderBy('timestamp', descending: true)
            .limit(1)
            .get();
      }

      final futures = <Future<dynamic>>[
        parentFuture,
        repliesFuture,
        userFuture,
        spaceFuture,
      ];
      if (originalPostSnapshotFuture != null)
        futures.add(originalPostSnapshotFuture);
      if (originalAuthorFuture != null) futures.add(originalAuthorFuture);
      if (repostsQueryFuture != null) futures.add(repostsQueryFuture);

      final results = await Future.wait<dynamic>(futures);

      final parentData = results[0] as ParentPostData;
      final replySnap = results[1] as QuerySnapshot?;
      final userData = results[2] as UserData?;
      final spaceData = results[3] as SpaceData?;
      PostData? originalPostData;
      UserData? originalAuthorData;
      String? fallbackOriginalAuthorName;
      DocumentSnapshot? repostSnapshot;

      int resultIndex = 4;
      if (originalPostSnapshotFuture != null) {
        final originalSnapshot = results.length > resultIndex
            ? results[resultIndex] as DocumentSnapshot
            : null;
        resultIndex++;
        if (originalSnapshot != null && originalSnapshot.exists) {
          originalPostData = PostData.fromSnapshot(originalSnapshot);
          // If originalAuthorName is missing from repost doc, get it from original post
          if (data.originalAuthorName == null) {
            final originalDocData =
                originalSnapshot.data() as Map<String, dynamic>?;
            fallbackOriginalAuthorName =
                originalDocData?['authorName'] as String?;
          }
        }
        originalAuthorData = results.length > resultIndex
            ? results[resultIndex] as UserData?
            : null;
        resultIndex++;
      }

      // NEW ARCHITECTURE: Process repost query results
      String? reposterNameFromDoc;
      if (repostsQueryFuture != null && results.length > resultIndex) {
        final repostsSnapshot = results[resultIndex] as QuerySnapshot?;
        if (repostsSnapshot != null && repostsSnapshot.docs.isNotEmpty) {
          repostSnapshot = repostsSnapshot.docs.first;
          final repostData = repostSnapshot.data() as Map<String, dynamic>;

          // Verify original post still exists (could have been deleted)
          // Only show repost indicator if original post exists
          final originalPostId = repostData['originalPostId'] as String?;
          if (originalPostId != null && originalPostId == widget.post) {
            // Extract reposter name and ID from document immediately (for instant display)
            reposterNameFromDoc = repostData['reposterName'] as String?;
            final reposterId = repostData['reposterId'] as String?;

            // Store reposter ID for navigation
            if (reposterId != null) {
              _reposterId = reposterId;
            }

            // Load reposter's user data asynchronously (for avatar and better name)
            // Don't block on this - show indicator immediately with name from doc
            if (reposterId != null && reposterId != userData?.uid) {
              _batchLoader.loadUser(reposterId).then((reposterUserData) {
                if (mounted) {
                  setState(() {
                    _reposterUserData = reposterUserData;
                    // Update name if user data has a better name
                    if (reposterUserData?.displayName != null) {
                      _reposterName = reposterUserData!.displayName;
                    }
                  });
                }
              });
            }
          } else {
            // Repost points to different post or invalid - clear repost data
            repostSnapshot = null;
          }
        }
      }

      // Update data with fallback original author name if needed
      final finalData = (data.isRepost &&
              data.originalAuthorName == null &&
              fallbackOriginalAuthorName != null)
          ? data.copyWith(originalAuthorName: fallbackOriginalAuthorName)
          : data;

      // Fetch image aspect ratio for image posts (non-blocking, after we know the image URL)
      final imageUrl = (finalData.isRepost &&
              originalPostData != null &&
              originalPostData!.postType == 'image')
          ? originalPostData!.video
          : (finalData.postType == 'image' ? finalData.video : null);
      if (imageUrl != null && imageUrl.isNotEmpty) {
        ImageOptimizer.getImageAspectRatio(imageUrl).then((aspectRatio) {
          if (mounted) {
            setState(() {
              _imageAspectRatio = aspectRatio;
            });
          }
        }).catchError((_) {
          // Ignore errors, use default
        });
      }

      if (kDebugMode && widget.itemIndex != null && widget.itemIndex! < 20) {
        AppLogger.d(
          'Post: hydration complete',
          category: LogCategory.performance,
          data: {
            'index': widget.itemIndex,
            'postId': postIdShort,
            'replyCount': replySnap?.docs.length ?? 0,
            'parentChain': parentData.parentChainCount,
            'isRepost': finalData.isRepost,
            'hasOriginalPost': originalPostData != null,
            'hasReposterData': userData != null,
            'hasOriginalAuthorData': originalAuthorData != null,
            'originalAuthorName': finalData.originalAuthorName,
          },
        );
      }

      if (mounted) {
        setState(() {
          _data = finalData;
          _replyTo = replyToId;
          _parentData = parentData;
          // For reposts (old model): _userData is reposter, _originalAuthorUserData is original author
          // For regular posts: _userData is the author
          if (finalData.isRepost) {
            _reposterUserData = userData;
            _originalAuthorUserData = originalAuthorData;
            // Use original author's data for display, but keep reposter data for indicator
            _userData = originalAuthorData ?? userData;
            _originalPostData = originalPostData;
            _reposterName = reposterName ?? userData?.displayName;
            // Store reposter ID for navigation (old model: reposter is the author)
            _reposterId = data.author;
            // Clear new architecture repost data (old model takes precedence)
            _repostSnapshot = null;
          } else {
            _userData = userData;
            // NEW ARCHITECTURE: Store repost data if this post was reposted
            // Set repost snapshot and name immediately so indicator shows right away
            _repostSnapshot = repostSnapshot;
            // Set reposter name from document if available (for instant indicator display)
            if (repostSnapshot != null && reposterNameFromDoc != null) {
              _reposterName = reposterNameFromDoc;
            } else if (repostSnapshot == null) {
              // If we don't have repost data, clear old model fields
              _reposterUserData = null;
              _originalAuthorUserData = null;
              _originalPostData = null;
              _reposterName = null;
              _reposterId = null;
            }
          }
          _spaceData = spaceData;
          if (replySnap != null) {
            _replyCount = replySnap.docs.length;
            _replySnapshot = replySnap;
          }
          _loading = isIncomplete;
          _missing = false;
        });

        // Store user/space data in FeedController for reuse
        if (widget.post != null) {
          try {
            final feedController = context.read<FeedController>();
            if (userData != null)
              feedController.setUserData(widget.post!, userData);
            if (spaceData != null)
              feedController.setSpaceData(widget.post!, spaceData);
          } catch (e) {
            // FeedController not available
          }
        }
      }
      if (kDebugMode && isIncomplete) {
        AppLogger.w(
          'Post: incomplete data, showing placeholder',
          category: LogCategory.performance,
          data: {
            'index': widget.itemIndex,
            'postId': postIdShort,
            'hasAuthor': data.author != null,
            'hasTimestamp': data.timestamp != null,
            'hasSpace': data.space != null,
          },
        );
      }
    } catch (e, stackTrace) {
      AppLogger.e('Error fetching post', error: e, stackTrace: stackTrace);
      if (mounted) {
        setState(() {
          _loading = true;
        });
      }
    }
  }

  /// Load parent posts data in PARALLEL (major optimization!)
  /// Old approach: serial waterfall (parent 1 → parent 2 → parent 3...)
  /// New approach: build chain first, then load ALL parents in parallel
  Future<ParentPostData> _loadParentPostsData(String replyToId) async {
    if (!mounted) return ParentPostData.empty;

    try {
      final startTime = DateTime.now();

      // STEP 1: Build the chain of parent IDs (fast - just reading replyTo fields)
      final parentIds = <String>[replyToId];
      String? currentId = replyToId;
      const maxChainDepth = 10; // Safety limit

      // Quick BFS to collect all parent IDs
      for (int i = 0; i < maxChainDepth && currentId != null; i++) {
        try {
          final snapshot = await _postDbService.getPost(currentId);
          if (!snapshot.exists || !mounted) break;

          final data = snapshot.data() as Map<String, dynamic>?;
          currentId = data?['replyTo'] as String?;

          if (currentId != null &&
              currentId.isNotEmpty &&
              !parentIds.contains(currentId)) {
            parentIds.add(currentId);
          } else {
            break;
          }
        } catch (e) {
          break;
        }
      }

      if (kDebugMode && widget.itemIndex != null && widget.itemIndex! < 20) {
        AppLogger.d(
          'Post: parent chain identified',
          category: LogCategory.performance,
          data: {
            'index': widget.itemIndex,
            'chainLength': parentIds.length,
          },
        );
      }

      // STEP 2: Load ALL parent posts in PARALLEL (major speedup!)
      final parentSnapshots = await _postDbService.getPosts(parentIds);
      final validSnapshots = <DocumentSnapshot>[];

      for (final id in parentIds.reversed) {
        // Reverse to get oldest → newest
        final snapshot = parentSnapshots[id];
        if (snapshot != null && snapshot.exists) {
          validSnapshots.add(snapshot);
        }
      }

      if (validSnapshots.isEmpty || !mounted) return ParentPostData.empty;

      // STEP 3: Get immediate parent author name
      final immediateParent = validSnapshots.last;
      final parentData = immediateParent.data() as Map<String, dynamic>?;
      final parentAuthorId = parentData?['author'] as String?;

      String? parentAuthorName;
      if (parentAuthorId != null) {
        final userService = locator<UserService>();
        try {
          parentAuthorName =
              await userService.getUserDisplayName(parentAuthorId);
        } catch (_) {
          parentAuthorName = null;
        }
      }

      final duration = DateTime.now().difference(startTime);
      if (kDebugMode && widget.itemIndex != null && widget.itemIndex! < 20) {
        AppLogger.i(
          'Post: parent chain loaded (PARALLEL)',
          category: LogCategory.performance,
          data: {
            'index': widget.itemIndex,
            'chainLength': validSnapshots.length,
            'took_ms': duration.inMilliseconds,
          },
        );
      }

      return ParentPostData(
        parentAuthorName: parentAuthorName,
        parentChainCount: validSnapshots.length - 1, // Exclude immediate parent
        parentPostSnapshots: validSnapshots,
      );
    } catch (e) {
      AppLogger.w('Error loading parent posts',
          data: {'parentPostId': replyToId, 'error': e.toString()});
      return ParentPostData.empty;
    }
  }

  void _updateFromSnapshot(DocumentSnapshot snapshot) {
    if (!snapshot.exists || !mounted) return;
    final oldData = _data;
    final newData = PostData.fromSnapshot(snapshot);

    final shouldRebuild = oldData == null ||
        oldData.uploading != newData.uploading ||
        oldData.video != newData.video ||
        oldData.title != newData.title;

    if (shouldRebuild) {
      if (kDebugMode && widget.itemIndex != null && widget.itemIndex! < 20) {
        AppLogger.d(
          'Post: realtime update applied',
          category: LogCategory.performance,
          data: {
            'index': widget.itemIndex,
            'postId': widget.post?.substring(0, 4),
          },
        );
      }
      setState(() {
        _data = newData;
        _replyTo = newData.replyTo;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_missing) return const PostUnavailableCard();
    if (_loading || _data?.timestamp == null) {
      if (_data != null && _data?.uploading == true) {
        return const PostProcessingCard();
      }
      return _buildLoading();
    }
    // "X reposted" above the entire post (above header), with consistent horizontal padding
    final repostedByIndicator =
        (widget.repostedByName != null && widget.repostedByName!.isNotEmpty)
            ? Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: RepostedByIndicator(
                  reposterName: widget.repostedByName!,
                  reposterAvatarUrl: widget.repostedByAvatarUrl,
                ),
              )
            : null;

    return ContextMenuWrapper(
      items: _buildContextMenuItems(context),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (repostedByIndicator != null) repostedByIndicator,
          _buildContent(_data!),
          if (widget.showReplySection)
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              alignment: Alignment.topCenter,
              child: _replyCount > 0
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 4),
                        InkWell(
                          onTap: () {
                            final postIdToView = (_data?.isRepost == true &&
                                    _data?.originalPostId != null)
                                ? _data!.originalPostId!
                                : widget.post;
                            if (postIdToView != null &&
                                widget.onReplySelected != null) {
                              widget.onReplySelected!(postIdToView);
                            }
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _replyCount == 1
                                      ? 'View one reply'
                                      : 'View $_replyCount replies',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w400,
                                    color: AppTheme.primaryColor
                                        .withValues(alpha: 0.7),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  CupertinoIcons.chevron_right,
                                  size: 14,
                                  color: AppTheme.primaryColor
                                      .withValues(alpha: 0.6),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: PostReplies(
                            post: (_data?.isRepost == true &&
                                    _data?.originalPostId != null)
                                ? _data!.originalPostId!
                                : widget.post,
                            onReplySelected: widget.onReplySelected,
                            initialReplies: _replySnapshot,
                          ),
                        ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
          if (_data?.timestamp != null) _buildTimeRow(),
        ],
      ),
    );
  }

  Widget _buildTimeRow() {
    final timestamp = _data?.timestamp;
    if (timestamp == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          'Posted ${TimeDisplay.getTimeAgo(timestamp.toDate())}',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w400,
            color: AppTheme.primaryColor.withValues(alpha: 0.7),
          ),
        ),
      ),
    );
  }

  List<ContextMenuItem> _buildContextMenuItems(BuildContext context) {
    final items = <ContextMenuItem>[
      ContextMenuItems.repost(onTap: () => _handleRepost(context)),
      ContextMenuItems.quote(onTap: () => _handleQuote(context)),
      ContextMenuItems.share(onTap: () => _handleShare(context)),
      ContextMenuItems.copyLink(onTap: () => _handleCopyLink(context)),
      ContextMenuItems.report(onTap: () => _handleReport(context)),
    ];
    return items;
  }

  void _handleShare(BuildContext context) {
    if (widget.post == null) return;
    ShareService.sharePost(
      context: context,
      postId: widget.post!,
    );
  }

  void _handleCopyLink(BuildContext context) {
    if (widget.post == null) return;
    final link = ShareLinks.post(widget.post!);
    Clipboard.setData(ClipboardData(text: link));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Link copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _handleReport(BuildContext context) {
    // TODO: Implement report functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Report feature coming soon'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _handleRepost(BuildContext context) async {
    if (widget.post == null || _data == null) return;

    try {
      final repostService = RepostService();
      final alreadyReposted = await repostService.hasUserReposted(widget.post!);

      if (alreadyReposted) {
        final postData = {
          'author': _data!.author,
          'contextType': _data!.contextType,
          'contextId': _data!.space,
          'space': _data!.space,
        };
        await repostService.undoRepost(widget.post!, postData);
        if (mounted) setState(() {});
        return;
      }

      final postData = {
        'author': _data!.author,
        'authorName': _userData?.displayName,
        'authorAvatar': _userData?.photoUrl,
        'contextType': _data!.contextType,
        'contextId': _data!.space,
        'space': _data!.space,
        'postType': _data!.postType,
        'title': _data!.title,
        'content': _data!.content,
        'video': _data!.video,
        'thumbnail': _data!.thumbnail,
        'audioUrl': _data!.audioUrl,
        'duration': _data!.durationInSeconds,
        'link': _data!.link,
      };
      await repostService.repostToProfile(
        originalPostId: widget.post!,
        originalPostData: postData,
      );
      if (mounted) setState(() {});
    } catch (e) {
      if (context.mounted) {
        showCustomSnackBar(
          context,
          message: 'Failed to repost. Please try again.',
          backgroundColor: AppTheme.errorColor,
          duration: const Duration(seconds: 3),
        );
      }
    }
  }

  void _handleQuote(BuildContext context) {
    if (widget.post == null) return;
    // TODO: Navigate to composer with quoted post
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Quote post feature coming in next update'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  /// Unified post body: one layout for all types (header + media + toolbar + caption).
  Widget _buildContent(PostData data) {
    // A post is a profile post if:
    // 1. contextType is explicitly 'profile', OR
    // 2. space field equals author field (profile posts store space as user's UID)
    final isProfile = data.contextType == 'profile' ||
        (data.space != null && data.space == data.author);

    // For reposts, use original post data if available, otherwise use repost data
    final displayData = (data.isRepost && _originalPostData != null)
        ? _originalPostData!
        : data;

    // Determine which author to show: original author for reposts, regular author otherwise
    final displayAuthor = (data.isRepost && _originalAuthorUserData != null)
        ? data.originalAuthorId ?? data.author
        : data.author;

    // Determine which user data to use for header
    final displayUserData = (data.isRepost && _originalAuthorUserData != null)
        ? _originalAuthorUserData
        : _userData;

    final replyIndicator =
        widget.showReplyIndicator && _replyTo != null && _replyTo!.isNotEmpty
            ? ReplyIndicator(
                parentPostId: _replyTo!,
                parentAuthorName: _parentData.parentAuthorName,
                additionalParentsCount: _parentData.parentChainCount > 0
                    ? _parentData.parentChainCount
                    : null,
                initialParentPosts: _parentData.parentPostSnapshots,
              )
            : null;

    // Show repost indicator if this is a repost
    // Use reposter's name from user data if available, otherwise from stored name
    // Determine reposter display name (old model: isRepost flag, new model: reposts collection)
    final reposterDisplayName = data.isRepost
        ? (_reposterUserData?.displayName ?? _reposterName ?? 'Someone')
        : (_reposterUserData?.displayName ?? _reposterName);

    // Show repost indicator if this is a repost (old model) OR if this post was reposted (new model)
    final bool showRepostIndicator = data.isRepost ||
        (_repostSnapshot != null && reposterDisplayName != null);
    final String? originalAuthorNameForIndicator = data.isRepost
        ? data.originalAuthorName
        : (_originalAuthorUserData?.displayName ??
            displayUserData?.displayName);

    final repostIndicator = showRepostIndicator && reposterDisplayName != null
        ? (originalAuthorNameForIndicator != null &&
                originalAuthorNameForIndicator.isNotEmpty
            ? RepostIndicator(
                reposterName: reposterDisplayName,
                reposterAvatar: _reposterUserData?.photoUrl,
                originalAuthorName: originalAuthorNameForIndicator,
                reposterId: _reposterId,
              )
            : RepostIndicator(
                reposterName: reposterDisplayName,
                reposterAvatar: _reposterUserData?.photoUrl,
                originalAuthorName:
                    'original post', // Fallback if name not available
                reposterId: _reposterId,
              ))
        : null;

    // Reply indicator goes after header (inside media widgets)
    final contentAfterHeader = replyIndicator != null
        ? Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [replyIndicator],
          )
        : null;

    // Media only (no header, no toolbar - we build those once below)
    final showHeader = false;
    final showToolbar = false;

    late Widget mediaWidget;
    // Use displayData (original post for reposts) for content, but keep original postId for navigation
    final contentPostId = (data.isRepost &&
            _originalPostData != null &&
            data.originalPostId != null)
        ? data.originalPostId!
        : widget.post;

    if (displayData.postType == 'text' &&
        displayData.content != null &&
        displayData.content!.isNotEmpty) {
      mediaWidget = TextNotePlayer(
        postId: contentPostId,
        space: displayData.space,
        author: displayAuthor,
        content: displayData.content!,
        title: displayData.title,
        link: displayData.link,
        timestamp: displayData.timestamp,
        isProfilePost: isProfile,
        contentAfterHeader: contentAfterHeader,
        showHeader: showHeader,
        showToolbar: showToolbar,
        userData: displayUserData,
        spaceData: _spaceData,
        quotedPostData: displayData.quotedPostData,
        quotedPostId: displayData.quotedPostId,
      );
    } else if (displayData.postType == 'audio' &&
        displayData.audioUrl != null &&
        displayData.durationInSeconds != null) {
      mediaWidget = AudioNotePlayer(
        postId: contentPostId,
        space: displayData.space,
        author: displayAuthor,
        audioUrl: displayData.audioUrl!,
        durationInSeconds: displayData.durationInSeconds!,
        title: displayData.title,
        timestamp: displayData.timestamp,
        isProfilePost: isProfile,
        contentAfterHeader: contentAfterHeader,
        showHeader: showHeader,
        showToolbar: showToolbar,
        userData: displayUserData,
        spaceData: _spaceData,
      );
    } else if (displayData.postType == 'image' &&
        displayData.video != null &&
        displayData.video!.isNotEmpty) {
      mediaWidget = ImageNotePlayer(
        postId: contentPostId,
        space: displayData.space,
        author: displayAuthor,
        imageUrl: displayData.video!,
        title: displayData.title,
        link: displayData.link,
        timestamp: displayData.timestamp,
        isProfilePost: isProfile,
        contentAfterHeader: contentAfterHeader,
        showHeader: showHeader,
        showToolbar: showToolbar,
        userData: displayUserData,
        spaceData: _spaceData,
        aspectRatio: _imageAspectRatio,
      );
    } else {
      mediaWidget = MainPlayer(
        postId: contentPostId,
        space: displayData.space,
        author: displayAuthor,
        videoUrl: displayData.video,
        uploading: displayData.uploading ?? false,
        title: displayData.title,
        link: displayData.link,
        thumbnail: displayData.thumbnail,
        pageIndex: widget.itemIndex,
        pageDepth: widget.itemDepth,
        isProfilePost: isProfile,
        timestamp: displayData.timestamp,
        enableVideoAutoplay: widget.enableVideoAutoplay,
        prewarmVideo: widget.prewarmVideo &&
            displayData.video != null &&
            displayData.video!.isNotEmpty,
        contentAfterHeader: contentAfterHeader,
        showHeader: showHeader,
        showToolbar: showToolbar,
        showCaption: false, // we render caption once below
        userData: displayUserData,
        spaceData: _spaceData,
      );
    }

    // Single layout: repost indicator (if repost) + header + media + toolbar + caption (for video)
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Repost indicator above header
        if (repostIndicator != null) repostIndicator,
        PostHeader(
          uid: displayAuthor,
          space: displayData.space,
          timestamp: displayData.timestamp,
          label: displayData.contextType == 'reply' ? 'REPLY' : null,
          labelColor: null,
          isProfilePost: isProfile,
          onMoreTap: () => _showPostOptions(context),
          userData: displayUserData,
          spaceData: _spaceData,
        ),
        mediaWidget,
        PostActionToolbar(
          postId: contentPostId,
          author: displayAuthor,
          space: displayData.space,
          link: displayData.link,
        ),
        if (displayData.title != null &&
            displayData.title!.isNotEmpty &&
            displayData.postType != 'text' &&
            displayData.postType != 'audio') ...[
          if (displayData.postType != 'image') const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                displayData.title!,
                textAlign: TextAlign.left,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.primaryColor,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ],
    );
  }

  void _showPostOptions(BuildContext context) {
    if (widget.post == null) return;
    showPostOptionsSheet(
      context: context,
      postId: widget.post!,
      authorId: _data?.author,
    );
  }

  /// Loading: same post-box skeleton as feed so content fills in the same box.
  Widget _buildLoading() {
    final postType = _data?.postType;
    if (postType == 'text') return const PostTextSkeleton();
    if (postType == 'audio') return const PostAudioSkeleton();
    if (postType == 'image') return const PostImageSkeleton();
    if (postType == 'video') return const PostVideoSkeleton();
    return const PostBoxSkeleton();
  }
}
