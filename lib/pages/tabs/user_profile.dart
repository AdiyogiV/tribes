import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:aurogram/pages/helpers/user_settings.dart';
import 'package:aurogram/widgets/dialogs/login_bottom_sheet.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:aurogram/pages/invites.dart';
import 'package:aurogram/pages/helpers/edit_user_profile.dart';
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
import 'package:aurogram/pages/spaces/space_chat_screen.dart';
import 'package:aurogram/pages/namaste_history.dart';
import 'package:aurogram/utils/performance/image_optimizer.dart';
import 'package:aurogram/widgets/astrology/compatibility_badge.dart';
import 'package:aurogram/models/astrology_profile.dart';
import 'package:aurogram/services/astrology_service.dart';
import 'package:aurogram/pages/astrology/astrology_details_page.dart';
import 'package:aurogram/pages/astrology/astrology_setup_page.dart';
import 'package:aurogram/pages/astrology/daily_insight_page.dart';
import 'package:aurogram/models/daily_insight.dart';
import 'package:aurogram/widgets/preview_boxes/preview_box.dart';
import 'package:aurogram/pages/thread_view.dart';
import 'package:aurogram/services/follow_service.dart';
import 'package:aurogram/utils/media_type_selector.dart';
import 'package:aurogram/pages/stories/story_composer_page.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:aurogram/pages/followers_following_page.dart';
import 'package:aurogram/pages/tabs/widgets/profile_stats.dart';
import 'package:aurogram/pages/tabs/widgets/profile_nav_item.dart';
import 'package:aurogram/models/ayurveda_profile.dart';
import 'package:aurogram/services/ayurveda_service.dart';
import 'package:aurogram/pages/ayurveda/widgets/ayurveda_profile_card.dart';
import 'package:aurogram/pages/ayurveda/ayurveda_details_page.dart';
import 'package:aurogram/utils/responsive.dart';
import 'package:aurogram/pages/send_me_something/send_composer_screen.dart';

class UserProfilePage extends StatefulWidget {
  final String? uid;
  const UserProfilePage({super.key, required this.uid});

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

  // Ayurveda
  final AyurvedaService _ayurvedaService = AyurvedaService();
  Stream<AyurvedaProfile?>? _ayurvedaProfileStream;
  AyurvedaProfile? _cachedAyurvedaProfile;

  // Cache profile posts stream and data to prevent refreshes on navigation
  Stream<QuerySnapshot>? _profilePostsStream;
  Stream<QuerySnapshot>? _profileRepostsStream;
  List<QueryDocumentSnapshot>? _cachedProfilePosts;
  List<QueryDocumentSnapshot>? _cachedProfileReposts;
  int _profileTabIndex = 0; // 0 = Posts (originals), 1 = Reposts

  // Timer for auto-refreshing astrology data while calculating
  Timer? _astroRefreshTimer;
  bool _isAstroCalculating = false;
  bool _isRetryingAstro = false;

  // Follow system
  final FollowService _followService = FollowService();
  bool _isFollowing = false;
  bool _theyFollowMe = false; // Does the profile owner follow current user?
  bool _isFollowLoading = false;
  int _followerCount = 0;
  int _followingCount = 0;
  String? _followStatus; // null = not following, 'pending', 'following'
  bool _isPrivateProfile = false;
  bool _hasPendingRequestToMe =
      false; // They've requested to follow current user
  bool _isAcceptingRequest = false; // Loading state for accept/decline

  // Key for compatibility badge to enable refresh
  final GlobalKey<dynamic> _compatibilityBadgeKey = GlobalKey();

  // Auroboard rank (loaded once for Auroboard card)
  Future<int?>? _userRankFuture;

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

    // Load user rank for Auroboard card
    if (widget.uid != null) {
      _userRankFuture = _auraService.getUserRank(widget.uid!);
    }
  }

  void _initProfilePostsStream() {
    if (widget.uid == null) return;
    final uid = widget.uid!;
    final col = FirebaseFirestore.instance.collection('posts');
    // All profile posts (originals + reposts); we filter client-side for Posts tab so
    // documents without isRepost (older posts) are included. Firestore isNotEqualTo
    // excludes missing fields, so originals would disappear otherwise.
    _profilePostsStream = col
        .where('author', isEqualTo: uid)
        .where('contextType', isEqualTo: 'profile')
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots();
    // Reposts only
    _profileRepostsStream = col
        .where('author', isEqualTo: uid)
        .where('contextType', isEqualTo: 'profile')
        .where('isRepost', isEqualTo: true)
        .orderBy('timestamp', descending: true)
        .limit(12)
        .snapshots();
  }

  /// Loads follow relationship data (not counts - those come from stream)
  Future<void> _loadFollowData({bool forceRefresh = false}) async {
    if (widget.uid == null) return;

    try {
      // For other users' profiles, load relationship data in parallel
      if (widget.uid != _user?.uid) {
        final results = await Future.wait([
          _followService.getFollowStatus(widget.uid!),
          _followService.isFollowedBy(widget.uid!),
          _followService.hasPendingRequestToMe(widget.uid!),
          UserService().isPrivateProfile(widget.uid),
        ]);

        if (mounted) {
          setState(() {
            _followStatus = results[0] as String?;
            _isFollowing = _followStatus != null;
            _theyFollowMe = results[1] as bool;
            _hasPendingRequestToMe = results[2] as bool;
            _isPrivateProfile = results[3] as bool;
          });
        }
      } else {
        // Own profile - just check privacy setting
        final isPrivate = await UserService().isPrivateProfile(widget.uid);
        if (mounted) {
          setState(() => _isPrivateProfile = isPrivate);
        }
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
        // Save previous status to check if was confirmed follower
        final wasConfirmedFollower =
            _followStatus == FollowService.statusFollowing;
        success = await _followService.unfollowUser(widget.uid!);
        if (success && mounted) {
          setState(() {
            _isFollowing = false;
            _followStatus = null;
            // Only decrement count if was confirmed follower (not just pending)
            if (wasConfirmedFollower) {
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

      // After successful follow, update compatibility badge immediately
      if (success && !wasFollowing && mounted) {
        _refreshKey++; // Trigger compatibility refresh
      }
    } catch (e) {
      AppLogger.e('Error handling follow tap', error: e);
    } finally {
      if (mounted) {
        setState(() => _isFollowLoading = false);
      }
    }
  }

  /// Accept a pending follow request from this user
  Future<void> _acceptFollowRequest() async {
    if (widget.uid == null || _isAcceptingRequest) return;

    setState(() => _isAcceptingRequest = true);
    HapticFeedback.lightImpact();

    try {
      final callable = FirebaseFunctions.instanceFor(region: 'asia-southeast2')
          .httpsCallable('acceptFollowRequest');
      await callable.call({'followerId': widget.uid});

      HapticFeedback.mediumImpact();

      if (mounted) {
        setState(() {
          _hasPendingRequestToMe = false;
          _theyFollowMe = true; // They now follow us
          _isAcceptingRequest = false;
          _followerCount += 1; // Update count
          _refreshKey++; // Refresh compatibility badge
        });
      }
    } catch (e) {
      AppLogger.e('Error accepting follow request', error: e);
      HapticFeedback.heavyImpact();
      if (mounted) {
        setState(() => _isAcceptingRequest = false);
      }
    }
  }

  /// Decline a pending follow request from this user
  Future<void> _declineFollowRequest() async {
    if (widget.uid == null || _isAcceptingRequest) return;

    setState(() => _isAcceptingRequest = true);
    HapticFeedback.lightImpact();

    try {
      final callable = FirebaseFunctions.instanceFor(region: 'asia-southeast2')
          .httpsCallable('rejectFollowRequest');
      await callable.call({'followerId': widget.uid});

      if (mounted) {
        setState(() {
          _hasPendingRequestToMe = false;
          _isAcceptingRequest = false;
        });
      }
    } catch (e) {
      AppLogger.e('Error declining follow request', error: e);
      HapticFeedback.heavyImpact();
      if (mounted) {
        setState(() => _isAcceptingRequest = false);
      }
    }
  }

  void _initAstrologyFuture() {
    if (widget.uid != null) {
      _astrologyProfileFuture = AstrologyService().getProfile(widget.uid!);
      _dailyInsightStream = AstrologyService().streamTodayInsight(widget.uid!);
      _ayurvedaProfileStream = _ayurvedaService.streamProfile(widget.uid!);

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
      // Fetch fresh data in parallel
      await Future.wait([
        _userCollection.doc(widget.uid).get(),
        _loadFollowData(forceRefresh: true), // Refresh follow counts
      ]);

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

    // Update follow counts from real-time stream (keeps UI in sync automatically)
    final newFollowerCount = (data['followerCount'] as int?) ?? 0;
    final newFollowingCount = (data['followingCount'] as int?) ?? 0;
    if (newFollowerCount != _followerCount ||
        newFollowingCount != _followingCount) {
      // Schedule state update after current build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _followerCount = newFollowerCount;
            _followingCount = newFollowingCount;
          });
        }
      });
    }

    return _cachedProfileData;
  }

  Future<void> _retryAstrologyCalculation() async {
    if (!mounted || widget.uid == null || _isRetryingAstro) return;
    _isRetryingAstro = true;
    HapticFeedback.lightImpact();

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Recalculating your stars...'),
          backgroundColor: Colors.blueGrey.shade700,
        ),
      );

      final success = await AstrologyService().calculateAndSaveAll(widget.uid!);

      // Force refresh to pick up any updates
      if (mounted) {
        setState(() {
          _astrologyProfileFuture =
              AstrologyService().getProfile(widget.uid!, forceRefresh: true);
          _refreshKey++;
        });
      }

      if (!success && AstrologyService().lastAuthFailure && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Session expired. Please log in again.'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not recalculate: $e'),
            backgroundColor: Colors.red.shade600,
          ),
        );
      }
    } finally {
      _isRetryingAstro = false;
    }
  }

  /// Use TransparentToolbox.buildCard() for consistent card styling

  @override
  Widget build(BuildContext context) {
    final bool isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    final primaryColor = AppTheme.primaryColor;
    final bool isOwnProfileTab = widget.uid == _user?.uid;

    // In wide layout for own profile, use enhanced layout with header
    if (Responsive.isWideLayout(context) && isOwnProfileTab) {
      return Scaffold(
        extendBody: true,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: _buildDesktopLayout(isDark),
      );
    }

    // Mobile layout or other user's profile
    return Scaffold(
      extendBody: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          // Full-width scroll view
          CustomScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              // Standard header
              AppHeaderStyle.buildStandardHeader(
                context: context,
                title: 'profile',
                showSearchField: false,
                isRefreshing: _isRefreshing,
                leadingWidget: widget.uid != _user?.uid
                    ? IconButton(
                        icon: Icon(Icons.arrow_back_ios,
                            color: primaryColor, size: AppHeaderStyle.headerIconSize),
                        onPressed: () => Navigator.of(context).pop(),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      )
                    : IconButton(
                        onPressed: _addPost,
                        icon: Icon(
                          CupertinoIcons.plus,
                          color: primaryColor,
                          size: AppHeaderStyle.headerIconSize,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                actionButton: widget.uid == _user?.uid
                    ? IconButton(
                        icon: Icon(Icons.more_vert, color: primaryColor, size: AppHeaderStyle.headerIconSize),
                        onPressed: _showProfileOptions,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      )
                    : null,
              ),
              // Pull to refresh
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

  /// Build desktop layout with floating header and centered content
  Widget _buildDesktopLayout(bool isDark) {
    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _handleRefresh,
          color: AppTheme.primaryColor,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final contentPadding = Responsive.horizontalPaddingFor(
                constraints.maxWidth,
                700,
              );

              return CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  AppHeaderStyle.buildWideLayoutHeaderSliver(
                    context,
                    title: 'Profile',
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_isRefreshing)
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  AppTheme.primaryColor),
                            ),
                          )
                        else
                          const SizedBox.shrink(),
                        IconButton(
                          onPressed: _showProfileOptions,
                          icon: Icon(
                            Icons.settings_outlined,
                            color: isDark ? Colors.white70 : Colors.black54,
                            size: 22,
                          ),
                          tooltip: 'Settings',
                        ),
                      ],
                    ),
                  ),
                  // Top padding
                  const SliverToBoxAdapter(child: SizedBox(height: 16)),

                  // Content with responsive padding
                  SliverPadding(
                    padding:
                        EdgeInsets.symmetric(horizontal: contentPadding + 16),
                    sliver: SliverToBoxAdapter(
                      child: StreamBuilder<DocumentSnapshot>(
                        stream: _getUserStream(),
                        builder: (context, snapshot) {
                          final profileData =
                              _extractProfileData(snapshot.data);
                          final isLoading = snapshot.connectionState ==
                                  ConnectionState.waiting &&
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
                  ),

                  // Bottom padding
                  SliverToBoxAdapter(
                    child:
                        SizedBox(height: AppHeaderStyle.contentBottomPadding),
                  ),
                ],
              );
            },
          ),
        ),

        // Bottom toolbox
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final contentPadding = Responsive.horizontalPaddingFor(
                constraints.maxWidth,
                700,
              );
              return Padding(
                padding: EdgeInsets.symmetric(horizontal: contentPadding),
                child: TransparentToolbox.actions(
                  alignment: MainAxisAlignment.center,
                  actions: _buildOwnProfileActions(isDark),
                ),
              );
            },
          ),
        ),
      ],
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

        // Follow Request Card - shows when this user has requested to follow current user
        // Placed at top of cards section for prominence
        if (!isOwnProfile && _hasPendingRequestToMe) ...[
          _buildFollowRequestBanner(name),
          SizedBox(height: AppHeaderStyle.cardVerticalGap),
        ],

        // Other cards with standard horizontal padding
        Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppHeaderStyle.contentHorizontalPadding),
          child: Column(
            key: ValueKey('profile_cards_$_refreshKey'),
            children: [
              // Auroboard (rank, score) – whole card tappable to leaderboard
              _buildAuroboardCard(isDark, auraScore),

              SizedBox(height: AppHeaderStyle.cardVerticalGap),

              // Stats (posts, followers, following) – not tappable
              _buildStatsCard(isDark),

              SizedBox(height: AppHeaderStyle.cardVerticalGap),

              // Insights (own profile only) — above stars
              if (widget.uid != null && isOwnProfile) ...[
                _buildInsightsCard(isDark),
                SizedBox(height: AppHeaderStyle.cardVerticalGap),
              ],

              // Astrology (stars)
              if (widget.uid != null) _buildAstrologyCard(isDark, isOwnProfile),

              // Ayurveda (own profile only, shows if astrology is setup)
              if (widget.uid != null && isOwnProfile) ...[
                SizedBox(height: AppHeaderStyle.cardVerticalGap),
                _buildAyurvedaCard(isDark),
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

  /// Build the profile posts grid section with Posts | Reposts tabs
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildProfilePostsTabBar(isDark),
        SizedBox(height: AppHeaderStyle.cardVerticalGap),
        _buildProfilePostsGrid(isDark, _profileTabIndex),
      ],
    );
  }

  Widget _buildProfilePostsTabBar(bool isDark) {
    final c = AppTheme.primaryColor;
    final activeColor = c;
    final inactiveColor = c.withValues(alpha: 0.5);
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppHeaderStyle.contentHorizontalPadding),
      child: Row(
        children: [
          _ProfileTabChip(
            label: 'Posts',
            isSelected: _profileTabIndex == 0,
            onTap: () => setState(() => _profileTabIndex = 0),
            activeColor: activeColor,
            inactiveColor: inactiveColor,
          ),
          const SizedBox(width: 12),
          _ProfileTabChip(
            label: 'Reposts',
            icon: CupertinoIcons.arrow_2_squarepath,
            isSelected: _profileTabIndex == 1,
            onTap: () => setState(() => _profileTabIndex = 1),
            activeColor: AppTheme.successColor,
            inactiveColor: inactiveColor,
          ),
        ],
      ),
    );
  }

  /// Build locked state for private profiles (non-followers)
  /// Styled consistently with compatibility card
  Widget _buildPrivateProfileLockedState(bool isDark) {
    final c = AppTheme.primaryColor;

    // Contextual message based on follow status
    final String message;
    final IconData icon;
    final Color iconColor;

    if (_followStatus == FollowService.statusPending) {
      message = 'Request pending';
      icon = CupertinoIcons.hourglass;
      iconColor = c.withValues(alpha: 0.5);
    } else {
      message = 'Follow to see their posts';
      icon = CupertinoIcons.lock_fill;
      iconColor = c.withValues(alpha: 0.5);
    }

    return TransparentToolbox.buildCard(
      context: context,
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'POSTS PRIVATE',
              style: AppTheme.cardLabelStyle,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Text(
                    message,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: c.withValues(alpha: 0.7),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  icon,
                  size: 14,
                  color: iconColor,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Build the posts grid from user's profile posts (tab 0 = originals, tab 1 = reposts)
  Widget _buildProfilePostsGrid(bool isDark, int tabIndex) {
    if (widget.uid == null) return const SizedBox.shrink();
    final isRepostsTab = tabIndex == 1;
    final stream = isRepostsTab ? _profileRepostsStream : _profilePostsStream;
    if (stream == null) return const SizedBox.shrink();

    // Key so switching tabs gives a fresh StreamBuilder and we don't show the other tab's snapshot
    return StreamBuilder<QuerySnapshot>(
      key: ValueKey<bool>(isRepostsTab),
      stream: stream,
      builder: (context, snapshot) {
        final List<QueryDocumentSnapshot> posts;
        if (snapshot.hasData && snapshot.data != null) {
          final docs = snapshot.data!.docs;
          if (isRepostsTab) {
            _cachedProfileReposts = docs;
            posts = docs;
          } else {
            // Posts tab: originals only (isRepost != true; includes docs with missing isRepost)
            posts = docs
                .where((d) =>
                    (d.data() as Map<String, dynamic>)['isRepost'] != true)
                .toList();
            _cachedProfilePosts = posts;
          }
        } else {
          posts = isRepostsTab
              ? (_cachedProfileReposts ?? [])
              : (_cachedProfilePosts ?? []);
        }

        if (posts.isEmpty) {
          if (isRepostsTab) {
            return _buildProfileEmptyState(
              icon: CupertinoIcons.arrow_2_squarepath,
              message: 'No reposts yet',
            );
          }
          return _buildProfileEmptyState(
            icon: CupertinoIcons.doc_text,
            message: 'No posts yet',
          );
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
            final postType = postData['postType'] as String?;

            String previewUrl = '';
            if (postType == 'image') {
              previewUrl = postData['video'] as String? ?? '';
            } else {
              previewUrl = postData['thumbnail'] as String? ?? '';
            }

            return GestureDetector(
              onTap: isUploading ? null : () => _openPost(postId, index, posts),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: PreviewBox(
                  key: ValueKey('$postId-$isUploading'),
                  previewUrl: previewUrl,
                  title: postData['title'] as String?,
                  author: postData['author'] as String?,
                  content: postData['content'] as String?,
                  postType: postType,
                  uploading: isUploading,
                  audioUrl: postData['audioUrl'] as String?,
                  durationInSeconds: postData['durationInSeconds'] as int?,
                  showAuthorPicture: false,
                  isRepost: false,
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildProfileEmptyState(
      {required IconData icon, required String message}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 40, color: AppTheme.primaryColor.withValues(alpha: 0.4)),
            const SizedBox(height: 12),
            Text(
              message,
              style: TextStyle(
                fontSize: 15,
                color: AppTheme.primaryColor.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Open a profile post in thread view. For reposts, open the original post (same post, like Twitter)
  /// and pass reposter info so the post shows "X reposted" at the top.
  void _openPost(String postId, int index, List<QueryDocumentSnapshot> posts) {
    final postData = posts[index].data() as Map<String, dynamic>;
    final isRepost = postData['isRepost'] as bool? ?? false;
    final originalPostId = postData['originalPostId'] as String?;
    final idToOpen =
        (isRepost && originalPostId != null && originalPostId.isNotEmpty)
            ? originalPostId
            : postId;
    final reposterName = postData['authorName'] as String?;
    final reposterAvatar = postData['authorAvatar'] as String?;
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (context) => ThreadView(
          postId: idToOpen,
          repostedByName: isRepost ? (reposterName ?? '') : null,
          repostedByAvatarUrl: isRepost ? reposterAvatar : null,
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
                    // "Follows You" badge - shows when they follow the current user
                    if (!isOwnProfile && _theyFollowMe) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Follows you',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: primaryColor.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                    ],
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

  /// Builds a card to accept/decline a follow request from this user
  /// Styled consistently with compatibility card
  Widget _buildFollowRequestBanner(String userName) {
    final c = AppTheme.primaryColor;
    final displayName = userName.isNotEmpty ? userName : 'Someone';

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppHeaderStyle.contentHorizontalPadding,
      ),
      child: TransparentToolbox.buildCard(
        context: context,
        child: SizedBox(
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Label
              Text(
                'FOLLOW REQUEST',
                style: AppTheme.cardLabelStyle,
              ),
              const SizedBox(height: 4),
              // Subtitle
              Text(
                '$displayName has requested to follow you',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: c.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 12),
              // Action buttons
              Row(
                children: [
                  // Accept button
                  Expanded(
                    child: GestureDetector(
                      onTap: _isAcceptingRequest ? null : _acceptFollowRequest,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: c,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: _isAcceptingRequest
                              ? const SizedBox(
                                  height: 16,
                                  width: 16,
                                  child: CupertinoActivityIndicator(
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Accept',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Decline button
                  Expanded(
                    child: GestureDetector(
                      onTap: _isAcceptingRequest ? null : _declineFollowRequest,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: c.withValues(alpha: 0.2),
                            width: 1.5,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            'Decline',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: c.withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Stats card: posts, followers, following. Whole card navigates to stats page only for own profile or mutual friends.
  Widget _buildStatsCard(bool isDark) {
    final primaryColor = AppTheme.primaryColor;
    final postCount = _cachedProfilePosts?.length ?? 0;
    final isOwnProfile = widget.uid == _user?.uid;
    final isMutual =
        _followStatus == FollowService.statusFollowing && _theyFollowMe;
    final canOpenStats = isOwnProfile || isMutual;

    return TransparentToolbox.buildCard(
      context: context,
      onTap: canOpenStats ? _openStatsPage : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'STATS',
            style: AppTheme.cardLabelStyle,
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              ProfileStatItem(
                label: 'Posts',
                value: postCount.toString(),
                color: primaryColor,
              ),
              const SizedBox(width: 24),
              canOpenStats
                  ? ProfileTappableStatItem(
                      label: 'Followers',
                      value: _followService.getFollowerTier(_followerCount),
                      color: primaryColor,
                      onTap: () => _openStatsPage(initialTabIndex: 0),
                    )
                  : ProfileStatItem(
                      label: 'Followers',
                      value: _followService.getFollowerTier(_followerCount),
                      color: primaryColor,
                    ),
              const SizedBox(width: 24),
              canOpenStats
                  ? ProfileTappableStatItem(
                      label: 'Following',
                      value: _followService.getFollowerTier(_followingCount),
                      color: primaryColor,
                      onTap: () => _openStatsPage(initialTabIndex: 1),
                    )
                  : ProfileStatItem(
                      label: 'Following',
                      value: _followService.getFollowerTier(_followingCount),
                      color: primaryColor,
                    ),
            ],
          ),
        ],
      ),
    );
  }

  /// Auroboard card: rank and score. Whole card is tappable and opens leaderboard.
  Widget _buildAuroboardCard(bool isDark, int auraScore) {
    final primaryColor = AppTheme.primaryColor;

    return TransparentToolbox.buildCard(
      context: context,
      onTap: _openLeaderboard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'AUROBOARD',
            style: AppTheme.cardLabelStyle,
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              if (_userRankFuture != null)
                FutureBuilder<int?>(
                  future: _userRankFuture,
                  builder: (context, snapshot) {
                    final rank = snapshot.data;
                    final value = rank != null ? rank.toString() : '—';
                    return ProfileStatItem(
                      label: 'Rank',
                      value: value,
                      color: primaryColor,
                    );
                  },
                ),
              if (_userRankFuture != null) const SizedBox(width: 24),
              ProfileStatItem(
                label: 'Score',
                value: auraScore.toString(),
                color: primaryColor,
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _openStatsPage({int initialTabIndex = 0}) {
    if (widget.uid == null) return;
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) => FollowersFollowingPage(
          userId: widget.uid!,
          userName: _cachedProfileData?['name'] as String?,
          initialTabIndex: initialTabIndex,
        ),
      ),
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
                  } else if (isCalculating) {
                    _retryAstrologyCalculation();
                  } else {
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
                      const SizedBox(height: 4),
                      _buildAstroLoadingSkeleton(primaryColor, isDark),
                    ] else if (hasCalculatedData) ...[
                      const SizedBox(height: 4),
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
                      const SizedBox(height: 6),
                      Text(
                        'Tap to retry',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: primaryColor.withValues(alpha: 0.8),
                        ),
                      ),
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
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: color.withValues(alpha: 0.7),
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

  Widget _buildAyurvedaCard(bool isDark) {
    final primaryColor = AppTheme.primaryColor;

    return FutureBuilder<AstrologyProfile?>(
      future: _astrologyProfileFuture,
      builder: (context, astroSnapshot) {
        final astroProfile = astroSnapshot.data;
        final hasAstrology = astroProfile != null &&
            astroProfile.isEnabled &&
            astroProfile.hasCalculatedData;

        // Only show if astrology is set up
        if (!hasAstrology) {
          return const SizedBox.shrink();
        }

        return StreamBuilder<AyurvedaProfile?>(
          stream: _ayurvedaProfileStream,
          builder: (context, ayurSnapshot) {
            _cachedAyurvedaProfile =
                ayurSnapshot.data ?? _cachedAyurvedaProfile;
            final ayurProfile = _cachedAyurvedaProfile;
            final hasAyurveda = ayurProfile != null && ayurProfile.hasData;
            final isLoading =
                ayurSnapshot.connectionState == ConnectionState.waiting &&
                    ayurProfile == null;

            if (isLoading) {
              return _buildAyurvedaLoadingSkeleton(isDark, primaryColor);
            }

            if (hasAyurveda) {
              // Show the Ayurveda profile card
              return AyurvedaProfileCard(
                profile: ayurProfile,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) =>
                          AyurvedaDetailsPage(uid: widget.uid!),
                    ),
                  );
                },
              );
            } else {
              // Show setup card
              return _buildAyurvedaSetupCard(isDark);
            }
          },
        );
      },
    );
  }

  Widget _buildAyurvedaLoadingSkeleton(bool isDark, Color primaryColor) {
    final skeletonBase = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.green.withValues(alpha: 0.1);
    return TransparentToolbox.buildCard(
      context: context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('AYURVEDA', style: AppTheme.cardLabelStyle),
          const SizedBox(height: 8),
          Container(
            width: 120,
            height: 16,
            decoration: BoxDecoration(
              color: skeletonBase,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (int i = 0; i < 3; i++) ...[
                Expanded(
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: skeletonBase,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                if (i < 2) const SizedBox(width: 8),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAyurvedaSetupCard(bool isDark) {
    final c = AppTheme.primaryColor;
    return TransparentToolbox.buildCard(
      context: context,
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => AyurvedaDetailsPage(uid: widget.uid!),
          ),
        );
      },
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: c.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.spa_outlined,
              color: c,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AYURVEDA',
                  style: AppTheme.cardLabelStyle,
                ),
                const SizedBox(height: 4),
                Text(
                  'Discover your constitution',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.arrow_forward_ios,
            size: 14,
            color: isDark ? Colors.white38 : Colors.black26,
          ),
        ],
      ),
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
    // Show selection dialog first (story or post)
    _showCreateSelectionDialog();
  }

  void _showCreateSelectionDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext context) => Container(
        decoration: BoxDecoration(
          color: isDark ? Colors.black : Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  height: 4,
                  width: 36,
                  decoration: BoxDecoration(
                    color: (isDark ? Colors.white : Colors.black)
                        .withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Post option
                _CreationOptionCard(
                  icon: CupertinoIcons.square_grid_2x2,
                  title: 'Create Post',
                  subtitle: 'Share photos, videos, or notes',
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF6366F1), // Indigo
                      Color(0xFFEC4899), // Pink
                    ],
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    _createPost();
                  },
                ),

                const SizedBox(height: 24),

                // Story option
                _CreationOptionCard(
                  icon: CupertinoIcons.camera_fill,
                  title: 'Create Story',
                  subtitle: 'Share moments that disappear in 24h',
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF0EA5E9), // Sky blue
                      Color(0xFF10B981), // Green
                    ],
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    _createStory();
                  },
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _createPost() {
    // Use special 'profile' context for profile posts
    MediaTypeSelector.showMediaTypeSelection(
      context: context,
      space: 'profile', // Special marker for profile posts
      isProfilePost: true, // New parameter to indicate profile context
    );
  }

  void _createStory() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const StoryComposerPage(),
      ),
    );
    if (result == true && mounted) {
      // Story was posted, could refresh profile if needed
    }
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
      ProfileNavItem(
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
      ProfileNavItem(
        onTap: _showInvites,
        child: Icon(
          Icons.mail_outline,
          color: primaryColor,
          size: iconSize,
        ),
      ),
      // 3. Plus (centered)
      ProfileNavItem(
        onTap: _addPost,
        child: Icon(
          CupertinoIcons.plus,
          color: primaryColor,
          size: iconSize,
        ),
      ),
      // 4. Notifications (fourth)
      ProfileNavItem(
        onTap: _openNotifications,
        child: Icon(
          Icons.notifications_outlined,
          color: primaryColor,
          size: iconSize,
        ),
      ),
      // 5. Settings (last)
      ProfileNavItem(
        onTap: _showSettings,
        child: Icon(
          Icons.settings_outlined,
          color: primaryColor,
          size: iconSize,
        ),
      ),
    ];
  }

  List<Widget> _buildOtherUserProfileActions() {
    final primaryColor = AppTheme.primaryColor.withValues(alpha: 0.85);
    const double iconSize = 26;
    return [
      // Follow/Unfollow/Requested button
      ProfileNavItem(
        onTap: _handleFollowTap,
        child: _isFollowLoading
            ? SizedBox(
                width: iconSize,
                height: iconSize,
                child: CupertinoActivityIndicator(),
              )
            : _buildFollowButtonContent(primaryColor, iconSize),
      ),
      ProfileNavItem(
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
      ProfileNavItem(
        onTap: _openDirectMessage,
        child: Icon(
          CupertinoIcons.paperplane_fill,
          color: primaryColor,
          size: iconSize,
        ),
      ),
      ProfileNavItem(
        onTap: _openSendAnonymousMessage,
        child: Icon(
          Icons.visibility_off_outlined,
          color: primaryColor,
          size: iconSize,
        ),
      ),
      ProfileNavItem(
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
    // Not following - show follow button with label
    if (!_isFollowing) {
      // If they follow you, show "Follow Back" as more actionable CTA
      final label = _theyFollowMe ? 'Follow\nBack' : 'Follow';
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            CupertinoIcons.person_badge_plus_fill,
            color: _theyFollowMe ? AppTheme.honeyAmber : primaryColor,
            size: iconSize - 4,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: _theyFollowMe
                  ? AppTheme.honeyAmber.withValues(alpha: 0.9)
                  : primaryColor.withValues(alpha: 0.7),
              height: 1.1,
            ),
          ),
        ],
      );
    }

    // Pending request - show clock/hourglass icon with label
    if (_followStatus == FollowService.statusPending) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            CupertinoIcons.clock_fill,
            color: AppTheme.honeyAmber.withValues(alpha: 0.85),
            size: iconSize - 4,
          ),
          const SizedBox(height: 2),
          Text(
            'Requested',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: AppTheme.honeyAmber.withValues(alpha: 0.7),
            ),
          ),
        ],
      );
    }

    // Confirmed following - show following status
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          CupertinoIcons.checkmark_circle_fill,
          color: AppTheme.successColor.withValues(alpha: 0.7),
          size: iconSize - 4,
        ),
        const SizedBox(height: 2),
        Text(
          'Following',
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            color: AppTheme.successColor.withValues(alpha: 0.7),
          ),
        ),
      ],
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
      final points = result.senderPointsAwarded ?? 0;
      final pointsLine =
          points > 0 ? '+$points Auro for sending Namaste!\n\n' : '';
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: Text('Namaste Sent! 🙏'),
          content: Text(
              '${pointsLine}Your greeting has been delivered.\n${remaining > 0 ? "$remaining namaste${remaining == 1 ? '' : 's'} remaining today." : "You've used all namastes for today."}'),
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

  void _openSendAnonymousMessage() {
    if (widget.uid == null) return;
    final name = _cachedProfileData?['name'] ?? 'User';
    Navigator.of(context, rootNavigator: true).push(
      CupertinoPageRoute(
        builder: (context) => SecretMessageSendComposer(
          recipientId: widget.uid!,
          recipientName: name,
        ),
      ),
    );
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

/// Tab chip for profile Posts | Reposts
class _ProfileTabChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool isSelected;
  final VoidCallback onTap;
  final Color activeColor;
  final Color inactiveColor;

  const _ProfileTabChip({
    required this.label,
    this.icon,
    required this.isSelected,
    required this.onTap,
    required this.activeColor,
    required this.inactiveColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? activeColor : inactiveColor;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreationOptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Gradient gradient;
  final VoidCallback onTap;

  const _CreationOptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 140,
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryColor.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  // Icon
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      icon,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 20),
                  // Text content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Arrow icon
                  Icon(
                    CupertinoIcons.chevron_right,
                    color: Colors.white.withValues(alpha: 0.8),
                    size: 24,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
