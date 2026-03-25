import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:aurogram/pages/helpers/userSettings.dart';
import 'package:aurogram/widgets/Dialogs/login_bottom_sheet.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:aurogram/pages/invites.dart';
import 'package:aurogram/pages/helpers/editUserProfile.dart';
import 'package:aurogram/widgets/user_avatar.dart';
import 'package:aurogram/widgets/ui/skeleton_widgets.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:aurogram/utils/theme/header_style.dart';
import 'package:aurogram/utils/logging/app_logger.dart';
import 'package:aurogram/widgets/universal/transparent_toolbox.dart';
import 'package:aurogram/providers/theme_provider.dart';
import 'package:aurogram/pages/tabs/notifications.dart';
import 'package:aurogram/services/aura_service.dart';
import 'package:aurogram/pages/aura_leaderboard.dart';
import 'package:aurogram/services/user_service.dart';
import 'package:aurogram/services/namaste_service.dart';
import 'package:aurogram/services/chat/space_chat_service.dart';
import 'package:aurogram/models/space.dart';
import 'package:aurogram/models/space_types.dart';
import 'package:aurogram/pages/spaces/spaceChatScreen.dart';
import 'package:aurogram/pages/namaste_history.dart';
import 'package:aurogram/utils/performance/image_optimizer.dart';
import 'package:aurogram/widgets/astrology/compatibility_badge.dart';
import 'package:aurogram/models/astrology_profile.dart';
import 'package:aurogram/services/astrology_service.dart';
import 'package:aurogram/pages/astrology/astrology_details_page.dart';
import 'package:aurogram/pages/astrology/astrology_setup_page.dart';
import 'package:aurogram/pages/astrology/daily_insight_page.dart';
import 'package:aurogram/models/daily_insight.dart';
import 'package:aurogram/widgets/previewBoxes/previewBox.dart';
import 'package:aurogram/pages/theatre.dart';
import 'package:aurogram/services/follow_service.dart';
import 'package:aurogram/utils/media_type_selector.dart';
import 'package:cached_network_image/cached_network_image.dart';

class UserProfilePage extends StatefulWidget {
  final String? uid;
  const UserProfilePage({Key? key, required this.uid}) : super(key: key);

  @override
  UserProfilePageState createState() => UserProfilePageState();
}

class UserProfilePageState extends State<UserProfilePage>
    with SingleTickerProviderStateMixin {
  final _user = FirebaseAuth.instance.currentUser;
  final _userCollection = FirebaseFirestore.instance.collection('users');
  bool _isRefreshing = false;
  final AuraService _auraService = AuraService();
  Map<String, dynamic>? _cachedProfileData;
  bool _isUserBlocked = false;
  int _refreshKey = 0; // Used to force rebuild of FutureBuilders on refresh

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Cache astrology profile future and insight stream to prevent unnecessary rebuilds
  Future<AstrologyProfile?>? _astrologyProfileFuture;
  Stream<DailyInsight?>? _dailyInsightStream;

  // Cache profile posts stream and data to prevent refreshes on navigation
  Stream<QuerySnapshot>? _profilePostsStream;
  List<QueryDocumentSnapshot>? _cachedProfilePosts;

  // Timer for auto-refreshing astrology data while calculating
  Timer? _astroRefreshTimer;
  bool _isAstroCalculating = false;

  // Follow system
  final FollowService _followService = FollowService();
  bool _isFollowing = false;
  bool _theyFollowMe = false; // Does the profile owner follow current user?
  bool _isFollowLoading = false;
  int _followerCount = 0;
  int _followingCount = 0;
  String? _followStatus; // null = not following, 'pending', 'following'
  bool _isPrivateProfile = false;

  // Key for compatibility badge to enable refresh
  final GlobalKey<dynamic> _compatibilityBadgeKey = GlobalKey();

  Stream<DocumentSnapshot>? _getUserStream() {
    if (widget.uid == null) return null;
    return _userCollection.doc(widget.uid).snapshots();
  }

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
    _animationController.forward();

    if (widget.uid == _user?.uid && widget.uid != null) {
      _auraService.checkAndAwardProfileComplete(widget.uid!);
    }

    // Load block status for other users
    if (widget.uid != null && widget.uid != _user?.uid) {
      _loadBlockStatus();
    }

    // Initialize astrology profile future once
    _initAstrologyFuture();

    // Initialize profile posts stream once
    _initProfilePostsStream();

    // Load follow data
    _loadFollowData();
  }

  void _initProfilePostsStream() {
    if (widget.uid == null) return;
    _profilePostsStream = FirebaseFirestore.instance
        .collection('posts')
        .where('author', isEqualTo: widget.uid)
        .where('contextType', isEqualTo: 'profile')
        .orderBy('timestamp', descending: true)
        .limit(12)
        .snapshots();
  }

  Future<void> _loadFollowData() async {
    if (widget.uid == null) return;

    try {
      // Load follower/following counts
      final followerCount = await _followService.getFollowerCount(widget.uid!);
      final followingCount =
          await _followService.getFollowingCount(widget.uid!);

      // Check if current user is following this profile and get detailed status
      String? followStatus;
      bool isFollowing = false;
      bool theyFollowMe = false;
      if (widget.uid != _user?.uid) {
        followStatus = await _followService.getFollowStatus(widget.uid!);
        isFollowing = followStatus != null;
        // Check if they follow the current user (for compatibility badge context)
        theyFollowMe = await _followService.isFollowedBy(widget.uid!);
      }

      // Check if profile is private
      final userService = UserService();
      final isPrivate = await userService.isPrivateProfile(widget.uid);

      if (mounted) {
        setState(() {
          _followerCount = followerCount;
          _followingCount = followingCount;
          _isFollowing = isFollowing;
          _theyFollowMe = theyFollowMe;
          _followStatus = followStatus;
          _isPrivateProfile = isPrivate;
        });
      }
    } catch (e) {
      AppLogger.w('Error loading follow data: $e');
    }
  }

  Future<void> _handleFollowTap() async {
    if (widget.uid == null || _isFollowLoading) return;
    if (_user == null) {
      showLoginBottomSheet(context);
      return;
    }

    setState(() => _isFollowLoading = true);

    try {
      bool success;
      final wasFollowing = _isFollowing;

      if (_isFollowing) {
        // Unfollow or cancel request
        success = await _followService.unfollowUser(widget.uid!);
        if (success && mounted) {
          setState(() {
            _isFollowing = false;
            _followStatus = null;
            // Only decrement count if was confirmed follower (not just pending)
            if (_followStatus == FollowService.statusFollowing) {
              _followerCount -= 1;
            }
          });
        }
      } else {
        // Follow - pass whether target is private so correct status is written
        success = await _followService.followUser(widget.uid!,
            targetIsPrivate: _isPrivateProfile);
        if (success && mounted) {
          setState(() {
            _isFollowing = true;
            _followStatus = _isPrivateProfile
                ? FollowService.statusPending
                : FollowService.statusFollowing;
          });
        }
      }

      // After follow action, check for mutual follow (for compatibility badge)
      if (success && !wasFollowing) {
        // For public profiles: just check if they follow us back (for mutual)
        // For private profiles: poll for status update when they approve
        if (_isPrivateProfile) {
          _pollForFollowStatusUpdate();
        } else {
          // Public profile - just refresh mutual status after a short delay
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              _checkMutualAndRefresh();
            }
          });
        }
      }
    } catch (e) {
      AppLogger.e('Error handling follow tap', error: e);
    } finally {
      if (mounted) {
        setState(() => _isFollowLoading = false);
      }
    }
  }

  /// Poll for follow status update after following a private profile
  /// Waits for them to approve the follow request
  Future<void> _pollForFollowStatusUpdate() async {
    if (widget.uid == null || !mounted) return;

    // Poll up to 5 times with increasing delays
    for (int i = 0; i < 5; i++) {
      await Future.delayed(Duration(milliseconds: 300 + (i * 200)));
      if (!mounted) return;

      // Re-fetch status (cache will be updated by backend within ~1s for public profiles)
      final newStatus = await _followService.getFollowStatus(widget.uid!);
      final theyFollow = await _followService.isFollowedBy(widget.uid!);

      if (!mounted) return;

      // Update state if status changed
      if (newStatus != _followStatus || theyFollow != _theyFollowMe) {
        setState(() {
          _followStatus = newStatus;
          _isFollowing = newStatus != null;
          _theyFollowMe = theyFollow;
          _refreshKey++;
        });

        // If we got confirmed following, no need to poll more
        if (newStatus == FollowService.statusFollowing) {
          break;
        }
      }
    }
  }

  /// Quick check for mutual follow after following a public profile
  /// We already show "following" immediately, just need to check if they follow us back
  Future<void> _checkMutualAndRefresh() async {
    if (widget.uid == null || !mounted) return;

    final theyFollow = await _followService.isFollowedBy(widget.uid!);

    if (!mounted) return;

    if (theyFollow != _theyFollowMe) {
      setState(() {
        _theyFollowMe = theyFollow;
        _refreshKey++; // Refresh compatibility badge
      });
    }
  }

  void _initAstrologyFuture() {
    if (widget.uid != null) {
      _astrologyProfileFuture = AstrologyService().getProfile(widget.uid!);
      _dailyInsightStream = AstrologyService().streamTodayInsight(widget.uid!);

      // Check if astro is calculating and start refresh timer if needed
      _checkAndStartAstroRefreshTimer();

      // For own profile, trigger lazy background sync to upgrade data
      // This runs in background if user has basic but not standard data
      if (widget.uid == _user?.uid) {
        _triggerLazySyncIfNeeded();
      }
    }
  }

  /// Trigger background sync to upgrade astrology data
  /// Only runs if user has basic sync but needs more complete data
  void _triggerLazySyncIfNeeded() async {
    try {
      final profile = await _astrologyProfileFuture;
      if (profile == null || !profile.isEnabled) return;

      // Only trigger if we have basic data but not standard/full
      if (profile.hasCalculatedData && profile.needsFullSync) {
        // Fire and forget - let it run in background
        AstrologyService().triggerLazySync(mode: 'standard');
      }
    } catch (_) {}
  }

  /// Starts a timer to periodically refresh astrology data while calculating
  void _checkAndStartAstroRefreshTimer() async {
    if (widget.uid == null || widget.uid != _user?.uid) return;

    try {
      final profile = await _astrologyProfileFuture;
      final isCalculating =
          profile != null && profile.isEnabled && !profile.hasCalculatedData;

      if (isCalculating && !_isAstroCalculating) {
        _isAstroCalculating = true;
        _startAstroRefreshTimer();
      }
    } catch (_) {}
  }

  void _startAstroRefreshTimer() {
    _astroRefreshTimer?.cancel();
    _astroRefreshTimer =
        Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (!mounted || widget.uid == null) {
        timer.cancel();
        return;
      }

      try {
        // Force refresh to check for updated data
        final profile = await AstrologyService()
            .getProfile(widget.uid!, forceRefresh: true);

        if (profile != null && profile.hasCalculatedData) {
          // Data is ready! Stop timer and refresh UI
          timer.cancel();
          _isAstroCalculating = false;
          if (mounted) {
            setState(() {
              _astrologyProfileFuture = Future.value(profile);
              _refreshKey++;
            });
          }
        }
      } catch (_) {}
    });
  }

  Future<void> _loadBlockStatus() async {
    if (widget.uid == null) return;
    try {
      final userService = UserService();
      final isBlocked = await userService.isUserBlocked(widget.uid!);
      if (mounted) {
        setState(() => _isUserBlocked = isBlocked);
      }
    } catch (e) {
      AppLogger.w('Error loading block status: $e');
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _astroRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _handleRefresh() async {
    if (_isRefreshing || widget.uid == null) return;

    if (mounted) {
      setState(() => _isRefreshing = true);
    }

    // Yield a frame so shimmer appears before work starts
    await Future.delayed(Duration.zero);

    try {
      // Fetch fresh data
      await _userCollection.doc(widget.uid).get();
      // Refresh astrology profile future (force refresh to bypass cache)
      _astrologyProfileFuture =
          AstrologyService().getProfile(widget.uid!, forceRefresh: true);
      // Force rebuild to refresh FutureBuilders (astrology cards, insights)
      if (mounted) {
        setState(() {
          _refreshKey++;
          _cachedProfileData = null;
        });
      }
    } catch (e) {
      AppLogger.e('Error during refresh',
          category: LogCategory.general, error: e);
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  Map<String, dynamic>? _extractProfileData(DocumentSnapshot? snapshot) {
    if (snapshot == null || !snapshot.exists) return null;
    final data = snapshot.data() as Map<String, dynamic>?;
    if (data == null) return null;

    _cachedProfileData = {
      'name': data['name'] ?? '',
      'nickname': data['nickname'] ?? '',
      'displayPicture': data['displayPicture'],
      'profilePictureUrl': data['profilePictureUrl'],
      'auraScore': data['auraScore'] ?? 0,
      'createdAt': data['createdAt'],
      'sunSign': data['sunSign'],
      'moonSign': data['moonSign'],
      'ascendant': data['ascendant'],
    };

    return _cachedProfileData;
  }

  /// Use TransparentToolbox.buildCard() for consistent card styling

  @override
  Widget build(BuildContext context) {
    final bool isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    final primaryColor = AppTheme.primaryColor;

    return Scaffold(
      extendBody: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          // Main scrollable content with standard sliver header
          CustomScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              // Standard header matching other tabs
              AppHeaderStyle.buildStandardHeader(
                context: context,
                title: 'profile',
                showSearchField: false,
                isRefreshing: _isRefreshing,
                leadingWidget: widget.uid != _user?.uid
                    ? IconButton(
                        icon: Icon(Icons.arrow_back_ios,
                            color: primaryColor, size: 22),
                        onPressed: () => Navigator.of(context).pop(),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      )
                    : null,
                actionButton: widget.uid == _user?.uid
                    ? IconButton(
                        icon: Icon(Icons.more_vert, color: primaryColor),
                        onPressed: _showProfileOptions,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        iconSize: 24,
                      )
                    : null,
              ),
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
                child: StreamBuilder<DocumentSnapshot>(
                  stream: _getUserStream(),
                  builder: (context, snapshot) {
                    final profileData = _extractProfileData(snapshot.data);
                    final isLoading =
                        snapshot.connectionState == ConnectionState.waiting &&
                            profileData == null;

                    if (isLoading) {
                      return _buildLoadingStateContent(isDark);
                    }

                    return FadeTransition(
                      opacity: _fadeAnimation,
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: _buildProfileContent(isDark, profileData),
                      ),
                    );
                  },
                ),
              ),
              // Bottom padding for toolbox
              SliverToBoxAdapter(
                child: SizedBox(height: AppHeaderStyle.contentBottomPadding),
              ),
            ],
          ),
          // Bottom toolbox
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: TransparentToolbox.actions(
              alignment: MainAxisAlignment.center,
              actions: widget.uid == _user?.uid
                  ? _buildOwnProfileActions(isDark)
                  : _buildOtherUserProfileActions(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingStateContent(bool isDark) {
    final Color placeholder =
        AppTheme.primaryColor.withValues(alpha: isDark ? 0.12 : 0.08);
    final Color placeholderDark =
        AppTheme.primaryColor.withValues(alpha: isDark ? 0.18 : 0.12);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          const SizedBox(height: 24),
          // Avatar skeleton
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: placeholder,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(height: 20),
          // Name skeleton
          Container(
            width: 150,
            height: 22,
            decoration: BoxDecoration(
              color: placeholderDark,
              borderRadius: BorderRadius.circular(11),
            ),
          ),
          const SizedBox(height: 10),
          // Username skeleton
          Container(
            width: 100,
            height: 14,
            decoration: BoxDecoration(
              color: placeholder,
              borderRadius: BorderRadius.circular(7),
            ),
          ),
          const SizedBox(height: 28),
          // Stats row skeleton
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
                3,
                (i) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        children: [
                          Container(
                            width: 44,
                            height: 20,
                            decoration: BoxDecoration(
                              color: placeholderDark,
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            width: 56,
                            height: 12,
                            decoration: BoxDecoration(
                              color: placeholder,
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ],
                      ),
                    )),
          ),
          const SizedBox(height: 28),
          // Bio skeleton lines
          ...List.generate(
              2,
              (i) => Padding(
                    padding: EdgeInsets.only(
                        bottom: 10,
                        left: i == 1 ? 30 : 0,
                        right: i == 1 ? 30 : 0),
                    child: Container(
                      width: double.infinity,
                      height: 14,
                      decoration: BoxDecoration(
                        color: i == 0 ? placeholderDark : placeholder,
                        borderRadius: BorderRadius.circular(7),
                      ),
                    ),
                  )),
          const SizedBox(height: 16),
          // Action buttons skeleton
          Container(
            width: 200,
            height: 44,
            decoration: BoxDecoration(
              color: placeholder,
              borderRadius: BorderRadius.circular(22),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileContent(bool isDark, Map<String, dynamic>? profileData) {
    final isOwnProfile = widget.uid == _user?.uid;
    final name = profileData?['name'] ?? '';
    final nickname = profileData?['nickname'] ?? '';
    final displayPicture = profileData?['displayPicture'];
    final auraScore = profileData?['auraScore'] ?? 0;

    return Column(
      children: [
        const SizedBox(height: AppHeaderStyle.contentTopPadding),

        // Profile card with avatar and name (has its own horizontal padding)
        _buildHeroSection(
          isDark,
          name,
          nickname,
          displayPicture,
          auraScore,
          isOwnProfile,
        ),

        SizedBox(height: AppHeaderStyle.cardVerticalGap),

        // Other cards with standard horizontal padding
        Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppHeaderStyle.contentHorizontalPadding),
          child: Column(
            key: ValueKey('profile_cards_$_refreshKey'),
            children: [
              // Aura
              _buildAuraCard(isDark, auraScore, isOwnProfile),

              SizedBox(height: AppHeaderStyle.cardVerticalGap),

              // Astrology
              if (widget.uid != null) _buildAstrologyCard(isDark, isOwnProfile),

              // Insights (own profile only)
              if (widget.uid != null && isOwnProfile) ...[
                SizedBox(height: AppHeaderStyle.cardVerticalGap),
                _buildInsightsCard(isDark),
              ],

              // Compatibility (for other users)
              if (widget.uid != null && !isOwnProfile) ...[
                SizedBox(height: AppHeaderStyle.cardVerticalGap),
                _buildCompatibilityCard(isDark),
              ],

              // Profile Posts Section
              if (widget.uid != null) ...[
                SizedBox(height: AppHeaderStyle.cardVerticalGap),
                _buildProfilePostsSection(isDark),
                const SizedBox(height: 200), // Extra spacing after posts
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// Build the profile posts grid section
  Widget _buildProfilePostsSection(bool isDark) {
    final isOwnProfile = widget.uid == _user?.uid;

    // For private profiles of other users, check if we're a confirmed follower
    if (!isOwnProfile && _isPrivateProfile) {
      final isConfirmedFollower =
          _followStatus == FollowService.statusFollowing;
      if (!isConfirmedFollower) {
        return _buildPrivateProfileLockedState(isDark);
      }
    }

    return _buildProfilePostsGrid(isDark);
  }

  /// Build locked state for private profiles (non-followers)
  Widget _buildPrivateProfileLockedState(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : AppTheme.primaryColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              CupertinoIcons.lock_fill,
              size: 32,
              color: AppTheme.primaryColor.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Private Profile',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.9)
                  : AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _followStatus == FollowService.statusPending
                ? 'Follow request pending'
                : 'Follow to see their posts',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.6)
                  : AppTheme.textSecondaryLightColor,
            ),
          ),
        ],
      ),
    );
  }

  /// Build the posts grid from user's profile posts
  Widget _buildProfilePostsGrid(bool isDark) {
    if (widget.uid == null || _profilePostsStream == null) {
      return const SizedBox.shrink();
    }

    // Use cached stream to prevent re-subscription on rebuilds
    return StreamBuilder<QuerySnapshot>(
      stream: _profilePostsStream,
      builder: (context, snapshot) {
        // Update cache when we have data with posts
        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          _cachedProfilePosts = snapshot.data!.docs;
        }

        // Use cached data or current snapshot data
        final posts = _cachedProfilePosts ?? snapshot.data?.docs ?? [];

        // If no posts, show nothing (clean empty state - no skeleton, no message)
        if (posts.isEmpty) {
          return const SizedBox.shrink();
        }

        return GridView.builder(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: AppHeaderStyle.cardVerticalGap,
            crossAxisSpacing: AppHeaderStyle.cardVerticalGap,
            childAspectRatio: 1.0,
          ),
          itemCount: posts.length,
          itemBuilder: (context, index) {
            final postData = posts[index].data() as Map<String, dynamic>;
            final postId = posts[index].id;
            final isUploading = postData['uploading'] as bool? ?? false;

            return GestureDetector(
              onTap: isUploading ? null : () => _openPost(postId, index, posts),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: PreviewBox(
                  key: ValueKey(
                      '$postId-$isUploading'), // Include uploading state in key
                  previewUrl: postData['thumbnail'] as String? ?? '',
                  title: postData['title'] as String?,
                  author: postData['author'] as String?,
                  content: postData['content'] as String?,
                  postType: postData['postType'] as String?,
                  uploading: isUploading,
                  audioUrl: postData['audioUrl'] as String?,
                  durationInSeconds: postData['durationInSeconds'] as int?,
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Open a profile post in theatre view (context-aware)
  void _openPost(String postId, int index, List<QueryDocumentSnapshot> posts) {
    // Open Theatre with profile context - pass post IDs for profile viewing
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (context) => Theatre(
          initpage: index,
          rid: null, // No space ID for profile posts
          profileUserId: widget.uid, // New parameter for profile context
        ),
      ),
    );
  }

  Widget _buildHeroSection(
    bool isDark,
    String name,
    String nickname,
    String? displayPicture,
    int auraScore,
    bool isOwnProfile,
  ) {
    final primaryColor = AppTheme.primaryColor;
    final avatarSize = 56.0;
    final heroTag = 'profile_avatar_${widget.uid ?? 'unknown'}';
    final stableKey = ValueKey('avatar_${widget.uid}_$avatarSize');

    // Match header structure: sideWidth=86, left padding=30
    // Card has 16px outer margin, so internal left padding = 30 - 16 = 14
    const double sideWidth = 70.0; // 86 - 16 (margin)

    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppHeaderStyle.contentHorizontalPadding),
      child: TransparentToolbox.buildCard(
        context: context,
        onTap: isOwnProfile ? _editProfile : null,
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Left avatar area - aligns with header icon (30px from screen edge)
            SizedBox(
              width: sideWidth,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding:
                      const EdgeInsets.only(left: 14), // 16 (margin) + 14 = 30
                  child: widget.uid != null &&
                          displayPicture != null &&
                          displayPicture.isNotEmpty
                      ? Hero(
                          tag: heroTag,
                          // Use flightShuttleBuilder to show a clean image during transition
                          flightShuttleBuilder: (
                            flightContext,
                            animation,
                            flightDirection,
                            fromHeroContext,
                            toHeroContext,
                          ) {
                            return AnimatedBuilder(
                              animation: animation,
                              builder: (context, child) {
                                return Material(
                                  elevation: 2 * (1 - animation.value),
                                  shadowColor: Colors.black
                                      .withValues(alpha: isDark ? 0.5 : 0.3),
                                  shape: const CircleBorder(),
                                  clipBehavior: Clip.antiAlias,
                                  color: Colors.transparent,
                                  child: ClipOval(
                                    child: ImageOptimizer.buildOptimizedImage(
                                      url: displayPicture,
                                      width: avatarSize +
                                          (MediaQuery.of(context).size.width -
                                                  avatarSize) *
                                              animation.value,
                                      height: avatarSize +
                                          (MediaQuery.of(context).size.width -
                                                  avatarSize) *
                                              animation.value,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                          child: Material(
                            elevation: 2,
                            shadowColor: Colors.black
                                .withValues(alpha: isDark ? 0.5 : 0.3),
                            shape: const CircleBorder(),
                            clipBehavior: Clip.antiAlias,
                            color: Theme.of(context).scaffoldBackgroundColor,
                            child: InkWell(
                              onTap: () => _showFullScreenAvatar(
                                  heroTag, displayPicture, name),
                              customBorder: const CircleBorder(),
                              child: UserAvatar(
                                key: stableKey,
                                userId: widget.uid,
                                imageUrl: displayPicture,
                                size: avatarSize,
                                borderRadius:
                                    BorderRadius.circular(avatarSize / 2),
                                nameInitials: name.isNotEmpty
                                    ? name.substring(0, 1)
                                    : null,
                                showBorder: false,
                              ),
                            ),
                          ),
                        )
                      : Material(
                          elevation: 2,
                          shadowColor: Colors.black
                              .withValues(alpha: isDark ? 0.5 : 0.3),
                          shape: const CircleBorder(),
                          clipBehavior: Clip.antiAlias,
                          color: Theme.of(context).scaffoldBackgroundColor,
                          child: SizedBox(
                            width: avatarSize,
                            height: avatarSize,
                            child: Icon(
                              Icons.person_rounded,
                              size: avatarSize * 0.5,
                              color: primaryColor.withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                ),
              ),
            ),

            // Name and username - centered like header title
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            name.isEmpty ? '—' : name,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: primaryColor,
                              height: 1.1,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ),
                        // Private profile indicator
                        if (_isPrivateProfile && !isOwnProfile) ...[
                          const SizedBox(width: 6),
                          Icon(
                            CupertinoIcons.lock_fill,
                            size: 14,
                            color: primaryColor.withValues(alpha: 0.5),
                          ),
                        ],
                      ],
                    ),
                    // Username/nickname display - hidden from UI, kept as backend-only
                    // if (nickname.isNotEmpty) ...[
                    //   const SizedBox(height: 4),
                    //   Text(
                    //     nickname,
                    //     style: TextStyle(
                    //       fontSize: 13,
                    //       fontWeight: FontWeight.w700,
                    //       color: primaryColor.withValues(alpha: 0.5),
                    //     ),
                    //     textAlign: TextAlign.center,
                    //   ),
                    // ],
                  ],
                ),
              ),
            ),

            // Right side - chevron arrow for own profile, spacer for others
            SizedBox(
              width: sideWidth,
              child: isOwnProfile
                  ? Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 14),
                        child: Icon(
                          Icons.chevron_right_rounded,
                          size: 20,
                          color: AppTheme.primaryLow,
                        ),
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAuraCard(bool isDark, int auraScore, bool isOwnProfile) {
    final primaryColor = AppTheme.primaryColor;

    return TransparentToolbox.buildCard(
      context: context,
      onTap: _openLeaderboard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'STATS',
            style: AppTheme.cardLabelStyle,
          ),
          const SizedBox(height: 12),
          // Aura, Followers, Following in a row - matching Stars card layout
          Row(
            children: [
              _buildStatItem('Auro Score', auraScore.toString(), primaryColor),
              const SizedBox(width: 24),
              _buildStatItem('Followers',
                  _followService.getFollowerTier(_followerCount), primaryColor),
              const SizedBox(width: 24),
              _buildStatItem(
                  'Following',
                  _followService.getFollowerTier(_followingCount),
                  primaryColor),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: color.withValues(alpha: 0.45),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildAstrologyCard(bool isDark, bool isOwnProfile) {
    final primaryColor = AppTheme.primaryColor;

    return FutureBuilder<AstrologyProfile?>(
      future: _astrologyProfileFuture,
      builder: (context, snapshot) {
        final isLoading = snapshot.connectionState == ConnectionState.waiting;
        final profile = snapshot.data;

        // Determine profile states
        final hasProfile = profile != null && profile.isEnabled;
        final hasCalculatedData =
            profile != null && profile.isEnabled && profile.hasCalculatedData;
        final isCalculating = hasProfile && !hasCalculatedData;

        // Don't show card if other user has no astrology profile
        if (!hasProfile && !isOwnProfile && !isLoading) {
          return const SizedBox.shrink();
        }

        // Only allow navigation for own profile (basic signs always visible to others)
        return TransparentToolbox.buildCard(
          context: context,
          onTap: isOwnProfile
              ? () {
                  if (hasCalculatedData) {
                    Navigator.of(context, rootNavigator: true).push(
                      CupertinoPageRoute(
                        builder: (context) =>
                            AstrologyDetailsPage(uid: widget.uid!),
                      ),
                    );
                  } else if (!isCalculating) {
                    // Only go to setup if not currently calculating
                    Navigator.of(context, rootNavigator: true).push(
                      CupertinoPageRoute(
                        builder: (context) => const AstrologySetupPage(),
                      ),
                    );
                  }
                }
              : null,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'STARS',
                      style: AppTheme.cardLabelStyle,
                    ),
                    if (isLoading) ...[
                      // Loading state - show skeleton
                      const SizedBox(height: 12),
                      _buildAstroLoadingSkeleton(primaryColor, isDark),
                    ] else if (hasCalculatedData) ...[
                      const SizedBox(height: 12),
                      // Rising, Sun, Moon in a row
                      Row(
                        children: [
                          _buildSignItem(
                              'Rising', profile.ascendant ?? '—', primaryColor),
                          const SizedBox(width: 24),
                          _buildSignItem(
                              'Sun', profile.sunSign ?? '—', primaryColor),
                          const SizedBox(width: 24),
                          _buildSignItem(
                              'Moon', profile.moonSign ?? '—', primaryColor),
                        ],
                      ),
                    ] else if (isCalculating) ...[
                      // Calculating state - show animated indicator
                      const SizedBox(height: 8),
                      _buildCalculatingState(primaryColor, isDark),
                    ] else ...[
                      const SizedBox(height: 4),
                      Text(
                        'Set up your birth chart',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: primaryColor,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // Only show chevron for own profile when not calculating
              if (isOwnProfile && !isCalculating)
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: AppTheme.primaryLow,
                ),
            ],
          ),
        );
      },
    );
  }

  /// Skeleton loading state for astrology card
  Widget _buildAstroLoadingSkeleton(Color primaryColor, bool isDark) {
    final skeletonBase = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : primaryColor.withValues(alpha: 0.1);

    return Row(
      children: [
        _buildSkeletonSignItem(skeletonBase),
        const SizedBox(width: 24),
        _buildSkeletonSignItem(skeletonBase),
        const SizedBox(width: 24),
        _buildSkeletonSignItem(skeletonBase),
      ],
    );
  }

  Widget _buildSkeletonSignItem(Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 36,
          height: 10,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(5),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: 50,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(7),
          ),
        ),
      ],
    );
  }

  /// Calculating state with animated shimmer
  Widget _buildCalculatingState(Color primaryColor, bool isDark) {
    return Row(
      children: [
        // Animated moon/star icon
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 1500),
          builder: (context, value, child) {
            return Transform.rotate(
              angle: value * 0.3,
              child: Icon(
                Icons.nights_stay_rounded,
                size: 18,
                color: const Color(0xFF8B5CF6)
                    .withValues(alpha: 0.7 + (value * 0.3)),
              ),
            );
          },
          onEnd: () {
            // Trigger rebuild to restart animation
            if (mounted) setState(() {});
          },
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Calculating your stars...',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: primaryColor.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Your birth chart is being prepared',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                  color: primaryColor.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSignItem(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: color.withValues(alpha: 0.45),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  /// Build formatted insight text with markdown-style formatting:
  /// - **bold** renders in bold
  /// - _italic_ renders in italic
  Widget _buildFormattedInsightText(String text, Color baseColor) {
    final List<TextSpan> spans = [];
    final RegExp pattern = RegExp(r'\*\*(.+?)\*\*|_(.+?)_|([^*_]+)');

    final baseStyle = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w500,
      color: baseColor.withValues(alpha: 0.85),
      height: 1.5,
    );

    for (final match in pattern.allMatches(text)) {
      if (match.group(1) != null) {
        // **bold**
        spans.add(TextSpan(
          text: match.group(1),
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: baseColor,
          ),
        ));
      } else if (match.group(2) != null) {
        // _italic_
        spans.add(TextSpan(
          text: match.group(2),
          style: TextStyle(
            fontStyle: FontStyle.italic,
            color: baseColor.withValues(alpha: 0.85),
          ),
        ));
      } else if (match.group(3) != null) {
        // Regular text
        spans.add(TextSpan(text: match.group(3)));
      }
    }

    return RichText(
      text: TextSpan(
        style: baseStyle,
        children: spans.isEmpty ? [TextSpan(text: text)] : spans,
      ),
    );
  }

  Widget _buildInsightsCard(bool isDark) {
    final primaryColor = AppTheme.primaryColor;

    return FutureBuilder<AstrologyProfile?>(
      future: _astrologyProfileFuture,
      builder: (context, snapshot) {
        final profile = snapshot.data;
        final hasProfile =
            profile != null && profile.isEnabled && profile.hasCalculatedData;

        if (!hasProfile) {
          return const SizedBox.shrink();
        }

        return TransparentToolbox.buildCard(
          context: context,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => DailyInsightPage(uid: widget.uid!),
              ),
            );
          },
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'INSIGHTS',
                      style: AppTheme.cardLabelStyle,
                    ),
                    const SizedBox(height: 8),
                    StreamBuilder<DailyInsight?>(
                      stream: _dailyInsightStream,
                      builder: (context, insightSnapshot) {
                        final insight = insightSnapshot.data;
                        final isLoading = insightSnapshot.connectionState ==
                            ConnectionState.waiting;

                        if (isLoading) {
                          // Skeleton loading state
                          final skeletonBase = isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : primaryColor.withValues(alpha: 0.1);
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: double.infinity,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: skeletonBase,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                width: MediaQuery.of(context).size.width * 0.7,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: skeletonBase,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                width: MediaQuery.of(context).size.width * 0.5,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: skeletonBase,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                            ],
                          );
                        } else if (insight != null &&
                            insight.message.isNotEmpty) {
                          // Use rich text formatting to handle **bold** and _italic_ markdown
                          return _buildFormattedInsightText(
                              insight.message, primaryColor);
                        } else {
                          return Text(
                            'Tap to generate your personalized insight.',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: primaryColor.withValues(alpha: 0.6),
                              fontStyle: FontStyle.italic,
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: AppTheme.primaryLow,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCompatibilityCard(bool isDark) {
    // Get other user info from cached profile data
    final otherUserName = _cachedProfileData?['name'] as String? ??
        _cachedProfileData?['nickname'] as String?;
    final otherUserPhotoUrl =
        _cachedProfileData?['displayPicture'] as String? ??
            _cachedProfileData?['profilePictureUrl'] as String?;

    // Get other user's sign data from cached profile
    final otherUserSun = _cachedProfileData?['sunSign'] as String?;
    final otherUserMoon = _cachedProfileData?['moonSign'] as String?;
    final otherUserRising = _cachedProfileData?['ascendant'] as String?;

    // Get current user info - use displayName first, fallback to fetching from Firestore
    final currentUserName = _user?.displayName;
    final currentUserPhotoUrl = _user?.photoURL;

    return FutureBuilder<Map<String, String?>>(
      future: _getCurrentUserData(),
      builder: (context, snapshot) {
        final userData = snapshot.data ?? {};
        final resolvedCurrentUserName = currentUserName ?? userData['name'];
        final resolvedCurrentUserPhotoUrl =
            currentUserPhotoUrl ?? userData['profilePictureUrl'];

        return CompatibilityBadge(
          key: _compatibilityBadgeKey,
          otherUserId: widget.uid!,
          followStatus: _followStatus,
          theyFollowYou: _theyFollowMe,
          currentUserName: resolvedCurrentUserName,
          otherUserName: otherUserName,
          currentUserPhotoUrl: resolvedCurrentUserPhotoUrl,
          otherUserPhotoUrl: otherUserPhotoUrl,
          currentUserSun: userData['sunSign'],
          currentUserMoon: userData['moonSign'],
          currentUserRising: userData['ascendant'],
          otherUserSun: otherUserSun,
          otherUserMoon: otherUserMoon,
          otherUserRising: otherUserRising,
        );
      },
    );
  }

  Future<Map<String, String?>> _getCurrentUserData() async {
    if (_user == null) return {};

    try {
      final doc = await _userCollection.doc(_user!.uid).get();
      if (doc.exists) {
        final data = doc.data();
        return {
          'name': _user!.displayName ??
              data?['name'] as String? ??
              data?['nickname'] as String?,
          'profilePictureUrl': data?['displayPicture'] as String? ??
              data?['profilePictureUrl'] as String?,
          'sunSign': data?['sunSign'] as String?,
          'moonSign': data?['moonSign'] as String?,
          'ascendant': data?['ascendant'] as String?,
        };
      }
    } catch (_) {}

    return {
      'name': _user!.displayName,
    };
  }

  void _showFullScreenAvatar(String heroTag, String imageUrl, String name) {
    if (imageUrl.isEmpty) return;

    Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (context, animation, secondaryAnimation) =>
            _FullScreenAvatarViewer(
          imageUrl: imageUrl,
          heroTag: heroTag,
          name: name,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
      ),
    );
  }

  void _openLeaderboard() {
    Navigator.of(context, rootNavigator: true).push(
      CupertinoPageRoute(
        builder: (context) => AuraLeaderboardPage(),
      ),
    );
  }

  void _showProfileOptions() {
    final primaryColor = AppTheme.primaryColor;

    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            child: Text(
              "Edit Profile",
              style: TextStyle(color: primaryColor),
            ),
            onPressed: () {
              Navigator.of(context).pop();
              _editProfile();
            },
          ),
          CupertinoActionSheetAction(
            child: Text(
              "Gram Invites",
              style: TextStyle(color: primaryColor),
            ),
            onPressed: () {
              Navigator.of(context).pop();
              _showInvites();
            },
          ),
          CupertinoActionSheetAction(
            child: Text(
              "App Settings",
              style: TextStyle(color: primaryColor),
            ),
            onPressed: () {
              Navigator.of(context).pop();
              _showSettings();
            },
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          child: Text(
            'Cancel',
            style: TextStyle(color: primaryColor),
          ),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ),
    );
  }

  void _showSettings() {
    Navigator.of(context, rootNavigator: true).push(
      CupertinoPageRoute(builder: (context) => UserSettingsPage()),
    );
  }

  void _editProfile() async {
    if (_user == null || widget.uid == null) {
      showLoginBottomSheet(context);
      return;
    }
    final result = await Navigator.of(context, rootNavigator: true).push(
      CupertinoPageRoute(
        builder: (context) => EditProfile(uid: widget.uid!),
      ),
    );
    if (result == true) {
      _handleRefresh();
    }
  }

  void _showInvites() {
    Navigator.of(context, rootNavigator: true).push(
      CupertinoPageRoute(builder: (context) => Invites()),
    );
  }

  void _addPost() {
    if (_user == null) {
      showLoginBottomSheet(context);
      return;
    }
    // Use special 'profile' context for profile posts
    MediaTypeSelector.showMediaTypeSelection(
      context: context,
      space: 'profile', // Special marker for profile posts
      isProfilePost: true, // New parameter to indicate profile context
    );
  }

  void _openNotifications() {
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (context) => Notifications(),
      ),
    );
  }

  void _openNamasteHistory() {
    Navigator.of(context, rootNavigator: true).push(
      CupertinoPageRoute(
        builder: (context) => NamasteHistoryPage(),
      ),
    );
  }

  List<Widget> _buildOwnProfileActions(bool isDark) {
    final primaryColor = AppTheme.primaryColor.withValues(alpha: 0.85);
    const double iconSize = 26;
    return [
      // 1. Namaste (first)
      _buildNavItem(
        onTap: _openNamasteHistory,
        child: Opacity(
          opacity: 0.85,
          child: Center(
            child: Image.asset(
              'assets/icons/namaste.png',
              width: 40,
              height: 40,
              filterQuality: FilterQuality.high,
            ),
          ),
        ),
      ),
      // 2. Invites (second)
      _buildNavItem(
        onTap: _showInvites,
        child: Icon(
          Icons.mail_outline,
          color: primaryColor,
          size: iconSize,
        ),
      ),
      // 3. Plus (centered)
      _buildNavItem(
        onTap: _addPost,
        child: Icon(
          CupertinoIcons.plus,
          color: primaryColor,
          size: iconSize,
        ),
      ),
      // 4. Notifications (fourth)
      _buildNavItem(
        onTap: _openNotifications,
        child: Icon(
          Icons.notifications_outlined,
          color: primaryColor,
          size: iconSize,
        ),
      ),
      // 5. Settings (last)
      _buildNavItem(
        onTap: _showSettings,
        child: Icon(
          Icons.settings_outlined,
          color: primaryColor,
          size: iconSize,
        ),
      ),
    ];
  }

  /// Navigation item - compact size for spaceBetween layout
  Widget _buildNavItem({
    required VoidCallback onTap,
    required Widget child,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        splashFactory: NoSplash.splashFactory,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
        focusColor: Colors.transparent,
        child: Container(
          height: 50,
          alignment: Alignment.center,
          child: child,
        ),
      ),
    );
  }

  List<Widget> _buildOtherUserProfileActions() {
    final primaryColor = AppTheme.primaryColor.withValues(alpha: 0.85);
    const double iconSize = 26;
    return [
      // Follow/Unfollow/Requested button
      _buildNavItem(
        onTap: _handleFollowTap,
        child: _isFollowLoading
            ? SizedBox(
                width: iconSize,
                height: iconSize,
                child: CupertinoActivityIndicator(),
              )
            : _buildFollowButtonContent(primaryColor, iconSize),
      ),
      _buildNavItem(
        onTap: _sendNamaste,
        child: Opacity(
          opacity: 0.85,
          child: Center(
            child: Image.asset(
              'assets/icons/namaste.png',
              width: 40,
              height: 40,
              filterQuality: FilterQuality.high,
            ),
          ),
        ),
      ),
      _buildNavItem(
        onTap: _openDirectMessage,
        child: Icon(
          CupertinoIcons.paperplane_fill,
          color: primaryColor,
          size: iconSize,
        ),
      ),
      _buildNavItem(
        onTap: _toggleBlockUser,
        child: Icon(
          _isUserBlocked ? Icons.block : Icons.block_outlined,
          color: _isUserBlocked
              ? AppTheme.errorColor.withValues(alpha: 0.85)
              : primaryColor,
          size: iconSize,
        ),
      ),
    ];
  }

  /// Build follow button content based on current follow status
  Widget _buildFollowButtonContent(Color primaryColor, double iconSize) {
    // Not following - show follow icon
    if (!_isFollowing) {
      return Icon(
        CupertinoIcons.person_badge_plus_fill,
        color: primaryColor,
        size: iconSize,
      );
    }

    // Pending request - show clock/hourglass icon
    if (_followStatus == FollowService.statusPending) {
      return Icon(
        CupertinoIcons.clock_fill,
        color: AppTheme.honeyAmber.withValues(alpha: 0.85),
        size: iconSize,
      );
    }

    // Confirmed following - show unfollow icon
    return Icon(
      CupertinoIcons.person_badge_minus_fill,
      color: AppTheme.errorColor.withValues(alpha: 0.7),
      size: iconSize,
    );
  }

  Future<void> _sendNamaste() async {
    if (_user == null || widget.uid == null) {
      showLoginBottomSheet(context);
      return;
    }

    final result = await NamasteService().sendNamaste(widget.uid!);

    if (!mounted) return;

    if (result.success) {
      final remaining = result.remaining ?? 0;
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: Text('Namaste Sent! 🙏'),
          content: Text(remaining > 0
              ? 'Your greeting has been delivered.\n$remaining namaste${remaining == 1 ? '' : 's'} remaining today.'
              : 'Your greeting has been delivered.\nYou\'ve used all namastes for today.'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('OK'),
            ),
          ],
        ),
      );
    } else if (result.quotaExceeded) {
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: Text('Daily Limit Reached'),
          content: Text(
              'You\'ve sent all 3 namastes for today.\nCome back tomorrow to greet more people! 🙏'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('OK'),
            ),
          ],
        ),
      );
    } else if (result.alreadySentToday) {
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: Text('Already Greeted'),
          content: Text('You\'ve already sent namaste to this person today.'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('OK'),
            ),
          ],
        ),
      );
    } else if (result.blocked) {
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: Text('Cannot Send'),
          content: Text('Unable to send namaste to this user.'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('OK'),
            ),
          ],
        ),
      );
    } else {
      AppLogger.e('Error sending namaste: ${result.error}',
          category: LogCategory.general);
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: Text('Error'),
          content: Text('Failed to send namaste. Please try again.'),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _openDirectMessage() async {
    if (_user == null || widget.uid == null) {
      showLoginBottomSheet(context);
      return;
    }

    try {
      final chatService = SpaceChatService();
      final conversationId = await chatService.createDirectMessage(widget.uid!);

      if (mounted) {
        final name = _cachedProfileData?['name'] ?? 'User';
        Navigator.of(context, rootNavigator: true).push(
          CupertinoPageRoute(
            builder: (context) => SpaceChatScreen(
              spaceId: conversationId,
              space: Space(
                id: conversationId,
                name: name,
                searchName: 'dm_${widget.uid}',
                description: 'Direct message conversation',
                spaceType: SpaceType.private,
                limitedVisibility: false,
              ),
              otherUserId: widget.uid,
            ),
          ),
        );
      }
    } catch (e) {
      AppLogger.e('Error opening DM', category: LogCategory.general, error: e);
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: Text('Error'),
            content: Text('Failed to open conversation. Please try again.'),
            actions: [
              CupertinoDialogAction(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  void _toggleBlockUser() {
    if (_isUserBlocked) {
      _unblockUser();
    } else {
      _blockUser();
    }
  }

  Future<void> _blockUser() async {
    if (widget.uid == null) return;

    final confirm = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text('Block User'),
        content: Text('Are you sure you want to block this user?'),
        actions: [
          CupertinoDialogAction(
            child: Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: Text('Block'),
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final userService = UserService();
        await userService.blockUser(widget.uid!);

        if (mounted) {
          setState(() => _isUserBlocked = true);
        }
      } catch (e) {
        AppLogger.e('Error blocking user',
            category: LogCategory.general, error: e);
      }
    }
  }

  Future<void> _unblockUser() async {
    if (widget.uid == null) return;

    try {
      final userService = UserService();
      await userService.unblockUser(widget.uid!);

      if (mounted) {
        setState(() => _isUserBlocked = false);
      }
    } catch (e) {
      AppLogger.e('Error unblocking user',
          category: LogCategory.general, error: e);
    }
  }
}

/// Full-screen avatar viewer with zoom and pan capabilities
class _FullScreenAvatarViewer extends StatefulWidget {
  final String imageUrl;
  final String heroTag;
  final String name;

  const _FullScreenAvatarViewer({
    required this.imageUrl,
    required this.heroTag,
    required this.name,
  });

  @override
  State<_FullScreenAvatarViewer> createState() =>
      _FullScreenAvatarViewerState();
}

class _FullScreenAvatarViewerState extends State<_FullScreenAvatarViewer> {
  final TransformationController _transformationController =
      TransformationController();
  bool _isZoomed = false;

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Use warm tan color for visibility on dark background
    const primaryColor = Color(0xFFD4A574);

    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: 0.95),
      body: Stack(
        children: [
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (!_isZoomed)
                    Flexible(
                      child: Text(
                        widget.name,
                        style: TextStyle(
                          color: primaryColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  IconButton(
                    icon: Icon(Icons.close, color: primaryColor, size: 24),
                    onPressed: () => Navigator.of(context).pop(),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black.withValues(alpha: 0.5),
                      shape: const CircleBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Center(
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: InteractiveViewer(
                transformationController: _transformationController,
                minScale: 1.0,
                maxScale: 4.0,
                onInteractionUpdate: (details) {
                  setState(() {
                    _isZoomed =
                        _transformationController.value.getMaxScaleOnAxis() >
                            1.0;
                  });
                },
                child: Hero(
                  tag: widget.heroTag,
                  child: Material(
                    color: Colors.transparent,
                    child: CachedNetworkImage(
                      imageUrl: widget.imageUrl,
                      width: MediaQuery.of(context).size.width,
                      height: MediaQuery.of(context).size.height,
                      fit: BoxFit.contain,
                      // Request full resolution for fullscreen viewing
                      memCacheWidth:
                          (MediaQuery.of(context).size.width * 3).toInt(),
                      memCacheHeight:
                          (MediaQuery.of(context).size.height * 3).toInt(),
                      placeholder: (context, url) => ShimmerImagePlaceholder(
                        width: MediaQuery.of(context).size.width,
                        height: MediaQuery.of(context).size.height,
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey.shade900,
                        child: Center(
                          child: Icon(
                            Icons.person,
                            size: 100,
                            color: primaryColor.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
