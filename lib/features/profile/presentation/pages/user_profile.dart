import 'package:aurogram/core/theme/app_dimensions.dart';
import 'dart:async';
import 'package:aurogram/shared/presentation/widgets/media/common_widgets.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:aurogram/core/di/injection.dart';
import 'package:aurogram/features/feed/data/datasources/post_db_service.dart';
import 'package:aurogram/shared/data/repositories/user_repository.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/core/theme/header_style.dart';
import 'package:aurogram/core/logging/app_logger.dart';
import 'package:aurogram/shared/presentation/widgets/universal/transparent_toolbox.dart';
import 'package:aurogram/shared/providers/theme_provider.dart';
import 'package:aurogram/features/profile/domain/aura_service.dart';
import 'package:aurogram/features/profile/domain/user_service.dart';
import 'package:aurogram/shared/models/astrology_profile.dart';
import 'package:aurogram/features/astrology/domain/astrology_service.dart';
import 'package:aurogram/shared/models/daily_insight.dart';
import 'package:aurogram/features/profile/domain/follow_service.dart';
import 'package:aurogram/shared/models/ayurveda_profile.dart';
import 'package:aurogram/features/ayurveda/domain/ayurveda_service.dart';
import 'package:aurogram/shared/presentation/responsive/responsive.dart';
import 'package:aurogram/features/profile/presentation/pages/profile/profile_loading_skeleton.dart';
import 'package:aurogram/features/profile/presentation/pages/profile/profile_toolbar_actions.dart';
import 'package:aurogram/features/profile/presentation/pages/profile/profile_user_interactions.dart';
import 'package:aurogram/features/profile/presentation/pages/profile/profile_follow_logic.dart';
import 'package:aurogram/features/profile/presentation/pages/profile/profile_navigation.dart';
import 'package:aurogram/features/profile/presentation/pages/profile/profile_content_body.dart';
import 'package:aurogram/features/profile/presentation/pages/profile/profile_astrology_logic.dart';

class UserProfilePage extends StatefulWidget {
  final String? uid;
  const UserProfilePage({super.key, required this.uid});

  @override
  UserProfilePageState createState() => UserProfilePageState();
}

class UserProfilePageState extends State<UserProfilePage>
    with SingleTickerProviderStateMixin, ProfileUserInteractions, ProfileFollowLogic, ProfileNavigation, ProfileAstrologyLogic {
  final _user = FirebaseAuth.instance.currentUser;
  final UserRepository _userRepo = locator<UserRepository>();
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

  // Follow system (public for ProfileFollowLogic mixin)
  @override
  final FollowService followService = FollowService();
  @override
  bool isFollowing = false;
  @override
  bool theyFollowMe = false; // Does the profile owner follow current user?
  @override
  bool isFollowLoading = false;
  @override
  int followerCount = 0;
  @override
  int followingCount = 0;
  @override
  String? followStatus; // null = not following, 'pending', 'following'
  @override
  bool isPrivateProfile = false;
  @override
  bool hasPendingRequestToMe = false; // They've requested to follow current user
  @override
  bool isAcceptingRequest = false; // Loading state for accept/decline

  // Key for compatibility badge to enable refresh
  final GlobalKey<dynamic> _compatibilityBadgeKey = GlobalKey();

  // Auroboard rank (loaded once for Auroboard card)
  Future<int?>? _userRankFuture;

  // ProfileFollowLogic mixin interface
  @override
  String? get followTargetUid => widget.uid;
  @override
  User? get followCurrentUser => _user;
  // Trigger a rebuild to update compatibility card and follow-dependent UI.
  // Do NOT increment _refreshKey here — that would destroy all FutureBuilder
  // states in the cards Column (insights, rank, astrology would flash back to
  // loading state).
  @override
  void onFollowChanged() => setState(() {});

  // ProfileNavigation mixin interface
  @override
  String? get navUid => widget.uid;
  @override
  User? get navCurrentUser => _user;
  @override
  Map<String, dynamic>? get navCachedProfileData => _cachedProfileData;
  @override
  Future<void> Function() get navHandleRefresh => _handleRefresh;

  // ProfileAstrologyLogic mixin interface
  @override
  String? get astroUid => widget.uid;
  @override
  String? get astroCurrentUserUid => _user?.uid;
  @override
  Future<AstrologyProfile?>? get astrologyProfileFuture => _astrologyProfileFuture;
  @override
  set astrologyProfileFuture(Future<AstrologyProfile?>? value) => _astrologyProfileFuture = value;
  @override
  Stream<DailyInsight?>? get dailyInsightStream => _dailyInsightStream;
  @override
  set dailyInsightStream(Stream<DailyInsight?>? value) => _dailyInsightStream = value;
  @override
  Stream<AyurvedaProfile?>? get ayurvedaProfileStream => _ayurvedaProfileStream;
  @override
  set ayurvedaProfileStream(Stream<AyurvedaProfile?>? value) => _ayurvedaProfileStream = value;
  @override
  Timer? get astroRefreshTimer => _astroRefreshTimer;
  @override
  set astroRefreshTimer(Timer? value) => _astroRefreshTimer = value;
  @override
  bool get isAstroCalculating => _isAstroCalculating;
  @override
  set isAstroCalculating(bool value) => _isAstroCalculating = value;
  @override
  bool get isRetryingAstro => _isRetryingAstro;
  @override
  set isRetryingAstro(bool value) => _isRetryingAstro = value;
  @override
  int get astroRefreshKey => _refreshKey;
  @override
  set astroRefreshKey(int value) => _refreshKey = value;
  @override
  AyurvedaService get ayurvedaService => _ayurvedaService;

  // ProfileUserInteractions mixin interface
  @override
  String? get interactionTargetUid => widget.uid;
  @override
  User? get interactionCurrentUser => _user;
  @override
  Map<String, dynamic>? get interactionCachedProfileData => _cachedProfileData;
  @override
  bool get interactionIsUserBlocked => _isUserBlocked;
  @override
  set interactionIsUserBlocked(bool value) => _isUserBlocked = value;

  // Cached once in initState — never recreated in build()
  Stream<DocumentSnapshot?>? _userStream;
  bool _profileTimedOut = false;

  @override
  void initState() {
    super.initState();
    // Cache the user stream once to avoid creating new Firestore listeners on rebuild
    if (widget.uid != null) {
      _userStream = _userRepo.userStream(widget.uid!);
      // Safety net: if Firestore never emits (App Check down, network issues),
      // try loading from cache after 4s so the profile doesn't stay in skeleton forever.
      Future.delayed(const Duration(seconds: 4), () {
        if (mounted && _cachedProfileData == null) {
          _loadProfileFromCache();
        }
      });
    }
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
    initAstrologyFuture();

    // Initialize profile posts stream once
    _initProfilePostsStream();

    // Load follow data
    loadFollowData();

    // Load user rank for Auroboard card
    if (widget.uid != null) {
      _userRankFuture = _auraService.getUserRank(widget.uid!);
    }
  }

  /// Fallback: load profile from Firestore cache when the live stream
  /// hangs (App Check down, network issues). This prevents the profile
  /// from staying in skeleton/shimmer state forever.
  Future<void> _loadProfileFromCache() async {
    if (widget.uid == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.uid!)
          .get(GetOptions(source: Source.cache))
          .timeout(const Duration(seconds: 2));
      if (doc.exists && mounted) {
        final data = doc.data();
        if (data != null) {
          setState(() {
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
            _profileTimedOut = true;
          });
          AppLogger.i('Profile loaded from Firestore cache (stream timeout fallback)',
              category: LogCategory.navigation);
        }
      }
    } catch (e) {
      // No cached data available either — profile stays in loading state
      if (mounted) {
        setState(() => _profileTimedOut = true);
      }
      AppLogger.w('Profile cache fallback failed: $e',
          category: LogCategory.navigation);
    }
  }

  void _initProfilePostsStream() {
    if (widget.uid == null) return;
    final uid = widget.uid!;
    // All profile posts (originals + reposts); we filter client-side for Posts tab so
    // documents without isRepost (older posts) are included. Firestore isNotEqualTo
    // excludes missing fields, so originals would disappear otherwise.
    _profilePostsStream =
        locator<PostDbService>().streamProfilePosts(uid, limit: 50);
    // Reposts only
    _profileRepostsStream = locator<PostDbService>()
        .streamProfilePosts(uid, limit: 12, repostsOnly: true);
  }

  // _loadFollowData delegated to ProfileFollowLogic.loadFollowData

  // _handleFollowTap delegated to ProfileFollowLogic.handleFollowTap

  // _acceptFollowRequest delegated to ProfileFollowLogic.acceptFollowRequest

  // _declineFollowRequest delegated to ProfileFollowLogic.declineFollowRequest

  // Astrology init/timer/sync delegated to ProfileAstrologyLogic mixin:
  // initAstrologyFuture, checkAndStartAstroRefreshTimer, startAstroRefreshTimer,
  // _triggerLazySyncIfNeeded

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
    final uid = widget.uid!;

    if (mounted) {
      setState(() => _isRefreshing = true);
    }

    // Yield a frame so the refresh indicator appears before network work.
    await Future.delayed(Duration.zero);

    try {
      // Fire ALL requests in parallel — including the ones whose results we
      // need to wrap as pre-resolved futures afterwards.
      final astroFuture =
          AstrologyService().getProfile(uid, forceRefresh: true);
      final rankFuture = _auraService.getUserRank(uid);

      await Future.wait([
        _userRepo.getUser(uid),
        loadFollowData(forceRefresh: true),
        astroFuture.catchError((_) => null),
        rankFuture.catchError((_) => null),
      ]);

      // By now astroFuture and rankFuture have settled.  Wrap their results
      // as already-completed futures so FutureBuilders receive data on the
      // very first frame — no loading/skeleton flash.
      final resolvedAstro = await astroFuture.catchError((_) => null);
      final resolvedRank = await rankFuture.catchError((_) => null);

      if (mounted) {
        setState(() {
          _astrologyProfileFuture = Future.value(resolvedAstro);
          _userRankFuture = Future.value(resolvedRank);
          // Refresh the daily-insight stream so the inner StreamBuilder
          // gets a fresh subscription (the old stream may have been consumed
          // or closed after the FutureBuilder cycled through loading state).
          _dailyInsightStream =
              AstrologyService().streamTodayInsight(uid).timeout(
            const Duration(seconds: 5),
            onTimeout: (sink) {
              AppLogger.w('dailyInsightStream timed out on refresh',
                  category: LogCategory.general);
              sink.add(null);
            },
          );
          // Refresh ayurveda stream too
          _ayurvedaProfileStream = _ayurvedaService.streamProfile(uid);
          // NOTE: Do NOT clear _cachedProfileData.  The Firestore user-
          // stream will deliver updated data naturally; clearing the cache
          // removes the safety net and can cause the name/avatar to flash
          // empty if the stream is momentarily between snapshots.
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

    final newData = {
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

    // Guard: don't overwrite good cached data with empty name
    // (can happen if Firestore stream delivers a partial/stale snapshot)
    final newName = newData['name'] as String? ?? '';
    final cachedName = _cachedProfileData?['name'] as String? ?? '';
    if (newName.isEmpty && cachedName.isNotEmpty) {
      // Keep the existing cached data – the stream snapshot is degraded
      return _cachedProfileData;
    }

    _cachedProfileData = newData;

    // Update follow counts from real-time stream.
    // Use a post-frame callback to avoid calling setState inside build().
    // The callback is guarded to fire only once per distinct count change.
    final newFollowerCount = (data['followerCount'] as int?) ?? 0;
    final newFollowingCount = (data['followingCount'] as int?) ?? 0;
    if (newFollowerCount != followerCount ||
        newFollowingCount != followingCount) {
      // Capture values to avoid reading stale fields in the callback
      final capturedFollowers = newFollowerCount;
      final capturedFollowing = newFollowingCount;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            followerCount = capturedFollowers;
            followingCount = capturedFollowing;
          });
        }
      });
    }

    return _cachedProfileData;
  }

  // _retryAstrologyCalculation delegated to ProfileAstrologyLogic.retryAstrologyCalculation

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
                        onPressed: addPost,
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
                        onPressed: showProfileOptions,
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
                child: StreamBuilder<DocumentSnapshot?>(
                  stream: _userStream,
                  builder: (context, snapshot) {
                    final profileData = _extractProfileData(snapshot.data)
                        ?? _cachedProfileData; // fallback to cache
                    final isLoading =
                        snapshot.connectionState == ConnectionState.waiting &&
                            profileData == null && !_profileTimedOut;

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
                          AppLoadingIndicator(
                            size: 20,
                            strokeWidth: 2,
                          )
                        else
                          const SizedBox.shrink(),
                        IconButton(
                          onPressed: showProfileOptions,
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
                  const SliverToBoxAdapter(child: SizedBox(height: AppDimensions.spacingLg)),

                  // Content with responsive padding
                  SliverPadding(
                    padding:
                        EdgeInsets.symmetric(horizontal: contentPadding + 16),
                    sliver: SliverToBoxAdapter(
                      child: StreamBuilder<DocumentSnapshot?>(
                        stream: _userStream,
                        builder: (context, snapshot) {
                          final profileData =
                              _extractProfileData(snapshot.data)
                                  ?? _cachedProfileData; // fallback to cache
                          final isLoading = snapshot.connectionState ==
                                  ConnectionState.waiting &&
                              profileData == null && !_profileTimedOut;

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
    return ProfileLoadingSkeleton(isDark: isDark);
  }

  Widget _buildProfileContent(bool isDark, Map<String, dynamic>? profileData) {
    final isOwnProfile = widget.uid == _user?.uid;
    return ProfileContentBody(
      isDark: isDark,
      isOwnProfile: isOwnProfile,
      uid: widget.uid,
      currentUid: _user?.uid,
      profileData: profileData,
      isPrivateProfile: isPrivateProfile,
      theyFollowMe: theyFollowMe,
      hasPendingRequestToMe: hasPendingRequestToMe,
      isAcceptingRequest: isAcceptingRequest,
      refreshKey: _refreshKey,
      followerCount: followerCount,
      followingCount: followingCount,
      followStatus: followStatus,
      postCount: _cachedProfilePosts?.length ?? 0,
      followService: followService,
      astrologyProfileFuture: _astrologyProfileFuture,
      dailyInsightStream: _dailyInsightStream,
      ayurvedaProfileStream: _ayurvedaProfileStream,
      cachedAyurvedaProfile: _cachedAyurvedaProfile,
      userRankFuture: _userRankFuture,
      cachedProfileData: _cachedProfileData,
      compatibilityBadgeKey: _compatibilityBadgeKey,
      profileTabIndex: _profileTabIndex,
      profilePostsStream: _profilePostsStream,
      profileRepostsStream: _profileRepostsStream,
      cachedProfilePosts: _cachedProfilePosts,
      cachedProfileReposts: _cachedProfileReposts,
      onEditProfile: editProfile,
      onAcceptFollowRequest: acceptFollowRequest,
      onDeclineFollowRequest: declineFollowRequest,
      onOpenLeaderboard: openLeaderboard,
      onOpenStats: ({int initialTabIndex = 0}) =>
          openStatsPage(initialTabIndex: initialTabIndex),
      onRetryAstrology: retryAstrologyCalculation,
      onAyurvedaProfileChanged: (profile) {
        setState(() => _cachedAyurvedaProfile = profile);
      },
      onTabChanged: (index) => setState(() => _profileTabIndex = index),
      onPostsCached: (posts) => _cachedProfilePosts = posts,
      onRepostsCached: (reposts) => _cachedProfileReposts = reposts,
    );
  }

  // Navigation methods delegated to ProfileNavigation mixin:
  // openStatsPage, openLeaderboard, showProfileOptions, showSettings,
  // editProfile, showInvites, addPost, createPost, createStory,
  // openNotifications, openNamasteHistory

  List<Widget> _buildOwnProfileActions(bool isDark) {
    return buildOwnProfileActions(
      isDark: isDark,
      onNamaste: openNamasteHistory,
      onInvites: showInvites,
      onAddPost: addPost,
      onNotifications: openNotifications,
      onSettings: showSettings,
    );
  }

  List<Widget> _buildOtherUserProfileActions() {
    return buildOtherUserProfileActions(
      isFollowing: isFollowing,
      isFollowLoading: isFollowLoading,
      followStatus: followStatus,
      theyFollowMe: theyFollowMe,
      isUserBlocked: _isUserBlocked,
      onFollowTap: handleFollowTap,
      onNamaste: sendNamaste,
      onDirectMessage: openDirectMessage,
      onToggleBlock: toggleBlockUser,
    );
  }

}

