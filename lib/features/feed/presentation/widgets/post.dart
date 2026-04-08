import 'dart:async';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:aurogram/shared/presentation/widgets/media/context_menu.dart';
import 'package:aurogram/features/feed/presentation/widgets/post_replies.dart' hide ReplyCallback;
import 'package:aurogram/core/di/injection.dart';
import 'package:aurogram/features/feed/data/datasources/post_db_service.dart';
import 'package:aurogram/services/batch_data_loader.dart';
import 'package:aurogram/features/feed/presentation/pages/feed_controller.dart';
import 'package:aurogram/core/logging/app_logger.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/shared/utils/time_display.dart';
import 'package:aurogram/shared/presentation/widgets/loaders/skeleton_widgets.dart';
import 'package:aurogram/features/feed/presentation/widgets/reply_indicator.dart';
import 'package:aurogram/features/feed/presentation/widgets/reposted_by_indicator.dart';
import 'package:aurogram/features/feed/presentation/widgets/repost_indicator.dart';
import 'package:aurogram/features/feed/presentation/widgets/post_action_toolbar.dart';
import 'package:aurogram/features/feed/presentation/widgets/post_options_sheet.dart';
import 'package:aurogram/features/feed/presentation/widgets/post_header.dart';
import 'package:aurogram/features/profile/domain/user_service.dart';
import 'package:aurogram/core/storage/image_optimizer.dart';

// Extracted modules
import 'package:aurogram/features/feed/presentation/widgets/post_data.dart';
import 'package:aurogram/features/feed/presentation/widgets/post_actions.dart' as post_actions;
import 'package:aurogram/features/feed/presentation/widgets/post_media.dart';
import 'package:aurogram/features/feed/presentation/widgets/post_caption.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';

// Re-export for backward compatibility (callers importing post.dart get these)
export 'package:aurogram/features/feed/presentation/widgets/post_data.dart';

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

  // Store user/space data to pass to children
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
      AppLogger.d('Post: ${widget.itemIndex} (${widget.post?.substring(0, 4)}) BUILDING (first time or rebuild after dispose)', category: LogCategory.ui);
    }

    // Restore state from FeedController (fast - instant)
    if (widget.post != null && mounted) {
      try {
        final feedController = context.read<FeedController>();
        final state = feedController.getPostState(widget.post!);
        _replyCount = state.replyCount;

        // Also restore user/space data from FeedController if cached
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

        // If we don't have user/space data yet, try to load it immediately (non-blocking)
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

    // Prevent rebuilds when parent rebuilds but our postId hasn't changed
    if (oldWidget.post == widget.post) return;

    // Post ID changed - this widget was recycled for a different post
    _postUpdateSubscription?.cancel();
    _subscribeToPostUpdates();
    _loadPostData();
  }

  @override
  void dispose() {
    if (widget.itemIndex != null && widget.itemIndex! < 10) {
      AppLogger.d('Post: ${widget.itemIndex} (${widget.post?.substring(0, 4)}) DISPOSED', category: LogCategory.ui);
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
      final reposterName =
          data.isRepost ? (snapshotData?['authorName'] as String?) : null;

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

      // Load user/space data, parent posts, and replies in PARALLEL
      final parentFuture = (replyToId != null && replyToId.isNotEmpty)
          ? _loadParentPostsData(replyToId)
          : Future.value(ParentPostData.empty);

      final replyPostId = (data.isRepost && data.originalPostId != null)
          ? data.originalPostId!
          : widget.post;
      final repliesFuture = widget.showReplySection && replyPostId != null
          ? _postDbService.getPostReplies(replyPostId)
          : Future.value(null);

      final userFuture = data.author != null
          ? _batchLoader.loadUser(data.author!)
          : Future.value(null);
      final spaceFuture = data.space != null
          ? _batchLoader.loadSpace(data.space!)
          : Future.value(null);

      Future<DocumentSnapshot>? originalPostSnapshotFuture;
      Future<UserData?>? originalAuthorFuture;
      if (data.isRepost && data.originalPostId != null) {
        originalPostSnapshotFuture =
            _postDbService.getPost(data.originalPostId!);
        if (data.originalAuthorId != null) {
          originalAuthorFuture = _batchLoader.loadUser(data.originalAuthorId!);
        }
      }

      Future<QuerySnapshot>? repostsQueryFuture;
      if (!data.isRepost && !_missing) {
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
      if (originalPostSnapshotFuture != null) {
        futures.add(originalPostSnapshotFuture);
      }
      if (originalAuthorFuture != null) {
        futures.add(originalAuthorFuture);
      }
      if (repostsQueryFuture != null) {
        futures.add(repostsQueryFuture);
      }

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

      String? reposterNameFromDoc;
      if (repostsQueryFuture != null && results.length > resultIndex) {
        final repostsSnapshot = results[resultIndex] as QuerySnapshot?;
        if (repostsSnapshot != null && repostsSnapshot.docs.isNotEmpty) {
          repostSnapshot = repostsSnapshot.docs.first;
          final repostData = repostSnapshot.data() as Map<String, dynamic>;

          final originalPostId = repostData['originalPostId'] as String?;
          if (originalPostId != null && originalPostId == widget.post) {
            reposterNameFromDoc = repostData['reposterName'] as String?;
            final reposterId = repostData['reposterId'] as String?;

            if (reposterId != null) {
              _reposterId = reposterId;
            }

            if (reposterId != null && reposterId != userData?.uid) {
              _batchLoader.loadUser(reposterId).then((reposterUserData) {
                if (mounted) {
                  setState(() {
                    _reposterUserData = reposterUserData;
                    if (reposterUserData?.displayName != null) {
                      _reposterName = reposterUserData!.displayName;
                    }
                  });
                }
              });
            }
          } else {
            repostSnapshot = null;
          }
        }
      }

      final finalData = (data.isRepost &&
              data.originalAuthorName == null &&
              fallbackOriginalAuthorName != null)
          ? data.copyWith(originalAuthorName: fallbackOriginalAuthorName)
          : data;

      // Fetch image aspect ratio for image posts
      final imageUrl = (finalData.isRepost &&
              originalPostData != null &&
              originalPostData.postType == 'image')
          ? originalPostData.video
          : (finalData.postType == 'image' ? finalData.video : null);
      if (imageUrl != null && imageUrl.isNotEmpty) {
        ImageOptimizer.getImageAspectRatio(imageUrl).then((aspectRatio) {
          if (mounted) {
            setState(() {
              _imageAspectRatio = aspectRatio;
            });
          }
        }).catchError((_) {});
      }

      if (mounted) {
        setState(() {
          _data = finalData;
          _replyTo = replyToId;
          _parentData = parentData;
          if (finalData.isRepost) {
            _reposterUserData = userData;
            _originalAuthorUserData = originalAuthorData;
            _userData = originalAuthorData ?? userData;
            _originalPostData = originalPostData;
            _reposterName = reposterName ?? userData?.displayName;
            _reposterId = data.author;
            _repostSnapshot = null;
          } else {
            _userData = userData;
            _repostSnapshot = repostSnapshot;
            if (repostSnapshot != null && reposterNameFromDoc != null) {
              _reposterName = reposterNameFromDoc;
            } else if (repostSnapshot == null) {
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

        if (widget.post != null) {
          try {
            final feedController = context.read<FeedController>();
            if (userData != null) {
              feedController.setUserData(widget.post!, userData);
            }
            if (spaceData != null) {
              feedController.setSpaceData(widget.post!, spaceData);
            }
          } catch (e) {
            // ignore
          }
        }
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

  /// Load parent posts data in PARALLEL.
  Future<ParentPostData> _loadParentPostsData(String replyToId) async {
    if (!mounted) return ParentPostData.empty;

    try {
      final parentIds = <String>[replyToId];
      String? currentId = replyToId;
      const maxChainDepth = 10;

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

      final parentSnapshots = await _postDbService.getPosts(parentIds);
      final validSnapshots = <DocumentSnapshot>[];

      for (final id in parentIds.reversed) {
        final snapshot = parentSnapshots[id];
        if (snapshot != null && snapshot.exists) {
          validSnapshots.add(snapshot);
        }
      }

      if (validSnapshots.isEmpty || !mounted) return ParentPostData.empty;

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

      return ParentPostData(
        parentAuthorName: parentAuthorName,
        parentChainCount: validSnapshots.length - 1,
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

    final repostedByIndicator =
        (widget.repostedByName != null && widget.repostedByName!.isNotEmpty)
            ? Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingMd),
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
                        const SizedBox(height: AppDimensions.spacingXs),
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
                          borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
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
                                const SizedBox(width: AppDimensions.spacingXs),
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
                        const SizedBox(height: AppDimensions.spacingXs),
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
    return <ContextMenuItem>[
      ContextMenuItems.repost(
          onTap: () => post_actions.handlePostRepost(context,
              postId: widget.post,
              data: _data,
              userData: _userData,
              onDone: () {
                if (mounted) setState(() {});
              })),
      ContextMenuItems.quote(
          onTap: () => post_actions.handlePostQuote(context, widget.post)),
      ContextMenuItems.share(
          onTap: () => post_actions.handlePostShare(context, widget.post)),
      ContextMenuItems.copyLink(
          onTap: () => post_actions.handlePostCopyLink(context, widget.post)),
      ContextMenuItems.report(
          onTap: () => post_actions.handlePostReport(context)),
    ];
  }

  /// Unified post body: one layout for all types (header + media + toolbar + caption).
  Widget _buildContent(PostData data) {
    final isProfile = data.contextType == 'profile' ||
        (data.space != null && data.space == data.author);

    final displayData = (data.isRepost && _originalPostData != null)
        ? _originalPostData!
        : data;

    final displayAuthor = (data.isRepost && _originalAuthorUserData != null)
        ? data.originalAuthorId ?? data.author
        : data.author;

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

    final reposterDisplayName = data.isRepost
        ? (_reposterUserData?.displayName ?? _reposterName ?? 'Someone')
        : (_reposterUserData?.displayName ?? _reposterName);

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
                originalAuthorName: 'original post',
                reposterId: _reposterId,
              ))
        : null;

    final contentAfterHeader = replyIndicator != null
        ? Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [replyIndicator],
          )
        : null;

    final contentPostId = (data.isRepost &&
            _originalPostData != null &&
            data.originalPostId != null)
        ? data.originalPostId!
        : widget.post;

    final mediaWidget = buildPostMedia(
      displayData: displayData,
      contentPostId: contentPostId,
      displayAuthor: displayAuthor,
      isProfile: isProfile,
      contentAfterHeader: contentAfterHeader,
      displayUserData: displayUserData,
      spaceData: _spaceData,
      imageAspectRatio: _imageAspectRatio,
      itemIndex: widget.itemIndex,
      itemDepth: widget.itemDepth,
      enableVideoAutoplay: widget.enableVideoAutoplay,
      prewarmVideo: widget.prewarmVideo,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
        PostCaption(displayData: displayData),
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
