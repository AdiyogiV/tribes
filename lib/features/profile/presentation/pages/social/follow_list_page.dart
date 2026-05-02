import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:aurogram/features/profile/domain/follow_service.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/shared/presentation/widgets/avatars/user_avatar.dart';
import 'package:aurogram/shared/presentation/widgets/loaders/skeleton_widgets.dart';
import 'package:aurogram/core/logging/app_logger.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';
import 'package:go_router/go_router.dart';

enum FollowListType { followers, following }

/// Reusable list body for followers or following. Used by [FollowListPage] and [FollowersFollowingPage].
class FollowListContent extends StatefulWidget {
  final String userId;
  final FollowListType listType;
  final String? userName;

  const FollowListContent({
    super.key,
    required this.userId,
    required this.listType,
    this.userName,
  });

  @override
  State<FollowListContent> createState() => _FollowListContentState();
}

class _FollowListContentState extends State<FollowListContent> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FollowService _followService = FollowService();
  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;

  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;
  bool _hasMore = true;
  DocumentSnapshot? _lastDoc;
  static const int _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _users = [];
        _lastDoc = null;
        _hasMore = true;
        _isLoading = true;
      });
    }

    if (!_hasMore && !refresh) return;

    try {
      // Get user IDs from the appropriate collection
      Query query;
      if (widget.listType == FollowListType.followers) {
        query = _firestore
            .collection('userFollowers')
            .doc(widget.userId)
            .collection('followers')
            .orderBy('timestamp', descending: true)
            .limit(_pageSize);
      } else {
        query = _firestore
            .collection('userFollowing')
            .doc(widget.userId)
            .collection('following')
            .orderBy('timestamp', descending: true)
            .limit(_pageSize);
      }

      if (_lastDoc != null) {
        query = query.startAfterDocument(_lastDoc!);
      }

      final snapshot = await query.get();
      
      if (snapshot.docs.isEmpty) {
        setState(() {
          _hasMore = false;
          _isLoading = false;
        });
        return;
      }

      _lastDoc = snapshot.docs.last;
      
      // Only load confirmed follows (status = 'following')
      final userIds = snapshot.docs
          .where((doc) {
            final data = doc.data() as Map<String, dynamic>?;
            final status = data?['status'] as String? ?? 'following';
            return status == 'following';
          })
          .map((doc) => doc.id)
          .toList();

      if (userIds.isEmpty) {
        setState(() {
          _hasMore = snapshot.docs.length >= _pageSize;
          _isLoading = false;
        });
        return;
      }

      // Fetch user details in batches (Firestore 'in' query limit is 10)
      // Also check deletedUsers to filter out deleted accounts
      final List<Map<String, dynamic>> newUsers = [];
      for (int i = 0; i < userIds.length; i += 10) {
        final batch = userIds.skip(i).take(10).toList();
        
        // Check deletedUsers in parallel
        final deletedUsersSnapshot = await _firestore
            .collection('deletedUsers')
            .where(FieldPath.documentId, whereIn: batch)
            .get();
        final deletedUserIds = deletedUsersSnapshot.docs.map((d) => d.id).toSet();
        
        // Filter out deleted users
        final activeUserIds = batch.where((id) => !deletedUserIds.contains(id)).toList();
        
        if (activeUserIds.isEmpty) continue;
        
        final usersSnapshot = await _firestore
            .collection('users')
            .where(FieldPath.documentId, whereIn: activeUserIds)
            .get();
        
        for (final doc in usersSnapshot.docs) {
          final data = doc.data();
          newUsers.add({
            'uid': doc.id,
            'name': data['name'] ?? '',
            'nickname': data['nickname'] ?? '',
            'displayPicture': data['displayPicture'] ?? '',
          });
        }
      }

      if (mounted) {
        setState(() {
          _users.addAll(newUsers);
          _hasMore = snapshot.docs.length >= _pageSize;
          _isLoading = false;
        });
      }
    } catch (e) {
      AppLogger.e('Error loading follow list', error: e);
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final isFollowers = widget.listType == FollowListType.followers;

    return _isLoading && _users.isEmpty
        ? _buildLoadingState()
        : _users.isEmpty
            ? _buildEmptyState(isFollowers, primaryColor)
            : _buildUserList(primaryColor);
  }

  Widget _buildLoadingState() {
    return ListView.builder(
      padding: const EdgeInsets.all(AppDimensions.paddingLg),
      itemCount: 8,
      itemBuilder: (context, index) => const Padding(
        padding: EdgeInsets.only(bottom: AppDimensions.paddingMd),
        child: SkeletonListItem(height: 64),
      ),
    );
  }

  Widget _buildEmptyState(bool isFollowers, Color primaryColor) {
    final isOwnProfile = widget.userId == _currentUserId;
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Animated icon container
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    primaryColor.withValues(alpha: 0.08),
                    primaryColor.withValues(alpha: 0.15),
                  ],
                ),
              ),
              child: Icon(
                isFollowers
                    ? CupertinoIcons.person_2_fill
                    : CupertinoIcons.heart_fill,
                size: 44,
                color: primaryColor.withValues(alpha: 0.35),
              ),
            ),
            const SizedBox(height: AppDimensions.spacingXxl),
            Text(
              isFollowers ? 'No followers yet' : 'Not following anyone',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: primaryColor,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: AppDimensions.spacingMdSm),
            Text(
              isFollowers
                  ? (isOwnProfile 
                      ? 'Share your profile to grow your community'
                      : 'When people follow this account, they\'ll appear here')
                  : (isOwnProfile
                      ? 'Find interesting people to follow'
                      : 'When this account follows people, they\'ll appear here'),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: primaryColor.withValues(alpha: 0.55),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserList(Color primaryColor) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollEndNotification &&
            notification.metrics.extentAfter < 200 &&
            _hasMore &&
            !_isLoading) {
          _loadUsers();
        }
        return false;
      },
      child: RefreshIndicator(
        onRefresh: () => _loadUsers(refresh: true),
        color: primaryColor,
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: AppDimensions.paddingSm),
          itemCount: _users.length + (_hasMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index >= _users.length) {
              return const Padding(
                padding: EdgeInsets.all(AppDimensions.paddingLg),
                child: Center(child: CupertinoActivityIndicator()),
              );
            }
            return _buildUserTile(_users[index], primaryColor);
          },
        ),
      ),
    );
  }

  Widget _buildUserTile(Map<String, dynamic> user, Color primaryColor) {
    final uid = user['uid'] as String;
    final name = user['name'] as String;
    final displayPicture = user['displayPicture'] as String?;
    final isCurrentUser = uid == _currentUserId;
    final isViewingOwnList = widget.userId == _currentUserId;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          context.push('/user/$uid');
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingLg, vertical: AppDimensions.paddingMd),
          child: Row(
            children: [
              // Avatar with subtle shadow
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: UserAvatar(
                  userId: uid,
                  imageUrl: displayPicture,
                  size: 50,
                  nameInitials: name.isNotEmpty ? name[0] : null,
                ),
              ),
              const SizedBox(width: AppDimensions.spacingMdLg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.isEmpty ? 'User' : name,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: primaryColor,
                        letterSpacing: -0.2,
                      ),
                    ),
                    if (isCurrentUser) ...[
                      const SizedBox(height: AppDimensions.spacingXxxs),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                        ),
                        child: Text(
                          'You',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: primaryColor.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // Show follow button for non-current users
              // In followers list: allow following back
              // In following list (viewing own): show "Following" indicator
              if (!isCurrentUser) ...[
                if (widget.listType == FollowListType.followers)
                  _FollowButton(
                    userId: uid,
                    followService: _followService,
                  )
                else if (isViewingOwnList)
                  _FollowingIndicator(primaryColor: primaryColor),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Page to display a user's followers or following list
/// Features: Pull-to-refresh, infinite scroll, follow buttons, haptic feedback
class FollowListPage extends StatelessWidget {
  final String userId;
  final FollowListType listType;
  final String? userName;

  const FollowListPage({
    super.key,
    required this.userId,
    required this.listType,
    this.userName,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final scaffoldBg = theme.scaffoldBackgroundColor;
    final isFollowers = listType == FollowListType.followers;
    final title = isFollowers ? 'Followers' : 'Following';

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        backgroundColor: scaffoldBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(CupertinoIcons.back, color: primaryColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: primaryColor,
              ),
            ),
            if (userName != null)
              Text(
                userName!,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: primaryColor.withValues(alpha: 0.5),
                ),
              ),
          ],
        ),
        centerTitle: true,
      ),
      body: FollowListContent(
        userId: userId,
        listType: listType,
        userName: userName,
      ),
    );
  }
}

/// Small "Following" indicator for following list
class _FollowingIndicator extends StatelessWidget {
  final Color primaryColor;
  
  const _FollowingIndicator({required this.primaryColor});
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMdLg),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            CupertinoIcons.checkmark_alt,
            size: 12,
            color: primaryColor.withValues(alpha: 0.6),
          ),
          const SizedBox(width: AppDimensions.spacingXs),
          Text(
            'Following',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: primaryColor.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}

/// Small follow button widget for use in lists
/// Features: Loading state, haptic feedback, smooth animations
class _FollowButton extends StatefulWidget {
  final String userId;
  final FollowService followService;

  const _FollowButton({
    required this.userId,
    required this.followService,
  });

  @override
  State<_FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends State<_FollowButton> with SingleTickerProviderStateMixin {
  bool _isFollowing = false;
  bool _isPending = false;
  bool _isLoading = true;
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );
    _checkFollowStatus();
  }
  
  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  Future<void> _checkFollowStatus() async {
    final status = await widget.followService.getFollowStatus(widget.userId);
    if (mounted) {
      setState(() {
        _isFollowing = status != null;
        _isPending = status == FollowService.statusPending;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleFollow() async {
    if (_isLoading) return;
    
    // Haptic feedback
    HapticFeedback.lightImpact();
    
    // Scale animation
    await _scaleController.forward();
    _scaleController.reverse();
    
    setState(() => _isLoading = true);

    try {
      if (_isFollowing) {
        await widget.followService.unfollowUser(widget.userId);
        if (mounted) {
          setState(() {
            _isFollowing = false;
            _isPending = false;
            _isLoading = false;
          });
        }
      } else {
        await widget.followService.followUser(widget.userId);
        // Re-check actual status after following
        final newStatus = await widget.followService.getFollowStatus(widget.userId);
        if (mounted) {
          setState(() {
            _isFollowing = newStatus != null;
            _isPending = newStatus == FollowService.statusPending;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = AppTheme.primaryColor;

    if (_isLoading) {
      return Container(
        width: 90,
        height: 34,
        decoration: BoxDecoration(
          color: primaryColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(17),
        ),
        child: Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CupertinoActivityIndicator(color: primaryColor),
          ),
        ),
      );
    }

    return ScaleTransition(
      scale: _scaleAnimation,
      child: GestureDetector(
        onTap: _toggleFollow,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingLg, vertical: AppDimensions.paddingSm),
          decoration: BoxDecoration(
            color: _isFollowing
                ? primaryColor.withValues(alpha: 0.1)
                : primaryColor,
            borderRadius: BorderRadius.circular(17),
            border: _isPending 
                ? Border.all(color: AppTheme.honeyAmber.withValues(alpha: 0.5), width: 1.5)
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isPending) ...[
                Icon(
                  CupertinoIcons.clock,
                  size: 12,
                  color: AppTheme.honeyAmber,
                ),
                const SizedBox(width: AppDimensions.spacingXs),
              ] else if (_isFollowing) ...[
                Icon(
                  CupertinoIcons.checkmark_alt,
                  size: 12,
                  color: primaryColor.withValues(alpha: 0.7),
                ),
                const SizedBox(width: AppDimensions.spacingXs),
              ],
              Text(
                _isPending 
                    ? 'Pending' 
                    : (_isFollowing ? 'Following' : 'Follow'),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _isPending
                      ? AppTheme.honeyAmber
                      : (_isFollowing ? primaryColor : Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

