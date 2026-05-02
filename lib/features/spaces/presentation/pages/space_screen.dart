import 'package:aurogram/core/theme/app_dimensions.dart';
import 'dart:io';
import 'package:aurogram/shared/presentation/widgets/flash.dart';
import 'package:aurogram/shared/presentation/widgets/dialogs/login_bottom_sheet.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:aurogram/shared/models/space.dart';
import 'package:aurogram/shared/models/space_roles.dart';
import 'package:aurogram/shared/models/space_types.dart';
import 'package:aurogram/shared/presentation/widgets/media/media_type_selector.dart';
import 'package:aurogram/features/spaces/presentation/pages/grid_space_view.dart';
import 'package:aurogram/features/feed/presentation/pages/theatre.dart';
import 'package:aurogram/features/spaces/domain/space_service.dart';
import 'package:aurogram/shared/services/share/share_service.dart';
import 'package:aurogram/shared/services/cache_service.dart';
import 'package:aurogram/core/di/injection.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/core/logging/app_logger.dart';
import 'package:aurogram/shared/presentation/widgets/feedback/snack_bar_service.dart';

class SpaceScreen extends StatefulWidget {
  final String rid;
  final String? postId;

  const SpaceScreen({super.key, required this.rid, this.postId});

  @override
  SpaceScreenState createState() => SpaceScreenState();
}

class SpaceScreenState extends State<SpaceScreen> {
  late Future<bool> _initializationFuture;
  Space? space;
  SpaceRoles? role;
  bool gridViewOn = false;
  int initPage = 0;
  User? user;
  String? userName;
  int memberCount = 0;
  File? _gramImageFile;
  // CRITICAL: use the singleton from the service locator, NOT a fresh
  // instance. A fresh instance has its own empty spaceCache, which means
  // grams.dart's prefetchSpaces (which warms the singleton's cache) has
  // zero benefit when opening a space — every tap incurs a full network
  // round-trip even though the data is already in memory in the singleton.
  final SpaceService _spaceService = locator.isRegistered<SpaceService>()
      ? locator<SpaceService>()
      : SpaceService();
  bool _isNavigatingToPost = false;

  @override
  void initState() {
    super.initState();
    _initializationFuture = _initializeSpaceBox()
        .timeout(const Duration(seconds: 20), onTimeout: () {
      AppLogger.e('SpaceScreen: init timed out after 20s',
          category: LogCategory.navigation,
          data: {'spaceId': widget.rid});
      return false;
    });

    // Set flag to indicate we're navigating to a specific post
    _isNavigatingToPost = widget.postId != null && widget.postId!.isNotEmpty;

    // Log navigation info
    if (_isNavigatingToPost) {
      AppLogger.d('SpaceScreen navigating to specific post',
          category: LogCategory.navigation, data: {'postId': widget.postId});
    }
  }

  @override
  void didUpdateWidget(SpaceScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Handle post ID changes while widget is active
    if (widget.postId != oldWidget.postId &&
        widget.postId != null &&
        widget.postId!.isNotEmpty) {
      _isNavigatingToPost = true;
      AppLogger.d('SpaceScreen post ID updated',
          category: LogCategory.navigation, data: {'postId': widget.postId});
    }
  }

  Future<bool> _initializeSpaceBox() async {
    final stopwatch = Stopwatch()..start();
    try {
      user = FirebaseAuth.instance.currentUser;

      // Step 1: Get the space (required — everything else depends on it)
      space = await _spaceService.getSpace(widget.rid)
          .timeout(const Duration(seconds: 10));
      debugPrint('SpaceScreen: getSpace ${stopwatch.elapsedMilliseconds}ms');

      if (user != null) {
        // Step 2: Run role, userName, image, memberCount ALL in parallel
        await Future.wait([
          _fetchRole(),
          _fetchUserName(),
          _fetchImage(),
          _fetchMemberCount(),
        ]);
      }

      debugPrint('SpaceScreen: init done ${stopwatch.elapsedMilliseconds}ms');
      return _isMember() || isPublicSpaceType(space!.spaceType);
    } catch (e) {
      AppLogger.e('SpaceScreen init failed',
          category: LogCategory.general,
          data: {'spaceId': widget.rid, 'error': e.toString()});
      return false;
    }
  }

  /// Fetch role: try server, fall back to assuming member on failure.
  Future<void> _fetchRole() async {
    try {
      role = await _spaceService.getSpaceRole(widget.rid, user!.uid)
          .timeout(const Duration(seconds: 8));
    } catch (_) {
      // Network/timeout — assume member so the user isn't locked out.
      role = SpaceRoles.member;
    }
  }

  /// Fetch current user's display name.
  Future<void> _fetchUserName() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users').doc(user!.uid)
          .get().timeout(const Duration(seconds: 5));
      userName = doc.data()?['name']?.toString();
    } catch (_) {}
  }

  /// Pre-cache the space display picture.
  Future<void> _fetchImage() async {
    if (space?.displayPicture == null) return;
    try {
      _gramImageFile = await locator<CacheService>()
          .getFile(space!.displayPicture)
          .timeout(const Duration(seconds: 3));
    } catch (_) {}
  }

  /// Fetch member count for the space header.
  Future<void> _fetchMemberCount() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('spaceRoles').doc(widget.rid)
          .collection('roles').get()
          .timeout(const Duration(seconds: 5));
      memberCount = snap.docs.length;
    } catch (_) {}
  }

  bool _isMember() {
    return role == SpaceRoles.member ||
        role == SpaceRoles.creator ||
        role == SpaceRoles.admin ||
        role == SpaceRoles.owner;
  }

  bool _isPublicOrOpen() {
    if (space?.spaceType == null) return false;
    return isPublicSpaceType(space!.spaceType);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _initializationFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          // Show loading with a back button so user can escape
          return Scaffold(
            backgroundColor: AppTheme.scaffoldLightColor,
            appBar: CupertinoNavigationBar(
              backgroundColor: Colors.transparent,
              border: null,
            ),
            body: const FlashScreen(),
          );
        }
        if (snapshot.hasError || space == null) {
          return _buildErrorWidget();
        }
        if (snapshot.data == false) {
          // Navigate to EditSpace for non-members of private/personal spaces
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.pushReplacement('/space/edit/${widget.rid}');
          });
          return const FlashScreen();
        }
        return _buildSpaceContent();
      },
    );
  }

  Widget _buildSpaceContent() {
    // For grid view, keep the old navigation bar style
    if (gridViewOn) {
      return Scaffold(
        resizeToAvoidBottomInset: false,
        floatingActionButton: _buildFloatingActionButton(),
        appBar: _buildCompactNavigationBar(),
        body: GridSpaceView(rid: widget.rid, setPageView: _setPageView),
      );
    }

    // For Theatre (vertical scroll), use the integrated header
    return Scaffold(
      resizeToAvoidBottomInset: false,
      floatingActionButton: _buildFloatingActionButton(),
      body: Theatre(
        initpage: initPage,
        rid: widget.rid,
        postId: widget.postId,
        space: space,
        onRefresh: _refreshSpace,
        onToggleGridView: _toggleGridView,
        onOpenChat: _openChat,
        onNavigateToSettings: _navigateToEditSpace,
        onShare: _shareGram,
        gridViewOn: gridViewOn,
      ),
    );
  }

  PreferredSizeWidget _buildCompactNavigationBar() {
    return CupertinoNavigationBar(
      middle: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: GestureDetector(
              onTap: _navigateToEditSpace,
              child: Text(
                space?.name ?? '',
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildIconButton(CupertinoIcons.list_bullet, _toggleGridView),
              const SizedBox(width: AppDimensions.spacingXs),
              _buildIconButton(CupertinoIcons.chat_bubble_2, _openChat),
              const SizedBox(width: AppDimensions.spacingXs),
              _buildIconButton(Icons.open_in_new_rounded, _shareGram),
              const SizedBox(width: AppDimensions.spacingXs),
              _buildIconButton(CupertinoIcons.settings, _navigateToEditSpace),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIconButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6.0),
        child: Icon(
          icon,
          size: 22,
          color: AppTheme.primaryColor,
        ),
      ),
    );
  }

  Widget? _buildFloatingActionButton() {
    if (_isMember()) {
      if (!space!.adminOnlyPosting ||
          role == SpaceRoles.admin ||
          role == SpaceRoles.creator) {
        return FloatingActionButton(
          onPressed: () => MediaTypeSelector.showMediaTypeSelection(
            context: context,
            space: widget.rid,
          ),
          backgroundColor: AppTheme.primaryColor,
          child: Icon(CupertinoIcons.add, color: AppTheme.textDarkColor),
        );
      }
    } else if (_isPublicOrOpen()) {
      return FloatingActionButton.extended(
        onPressed: _joinSpace,
        elevation: 2,
        backgroundColor: AppTheme.primaryLightColor,
        foregroundColor: AppTheme.textDarkColor,
        icon: Icon(CupertinoIcons.add),
        label: Text('Join'),
      );
    }
    return null;
  }

  void _joinSpace() async {
    if (user == null) {
      showLoginBottomSheet(context);
      return;
    }

    try {
      await _spaceService.addToSpace(widget.rid, user!.uid);
      _refreshSpace();
    } catch (e) {
      AppLogger.e('Error joining space',
          category: LogCategory.general, data: {'error': e.toString()});
      if (!mounted) return;
      showCustomSnackBar(context, message: 'Failed to join space. Please try again.', behavior: SnackBarBehavior.fixed);
    }
  }

  void _setPageView(int pageIndex) {
    setState(() {
      initPage = pageIndex;
      gridViewOn = false;
    });
  }

  void _refreshSpace() {
    setState(() {
      _initializationFuture = _initializeSpaceBox()
          .timeout(const Duration(seconds: 20), onTimeout: () {
        AppLogger.e('SpaceScreen: refresh timed out after 20s',
            category: LogCategory.navigation,
            data: {'spaceId': widget.rid});
        return false;
      });
    });
  }

  void _toggleGridView() {
    setState(() => gridViewOn = !gridViewOn);
  }

  void _navigateToEditSpace() {
    context.push('/space/edit/${widget.rid}');
  }

  void _shareGram() {
    if (space == null) return;
    ShareService.showGramCardPreview(
      context: context,
      spaceId: widget.rid,
      gramName: space!.name ?? 'Gram',
      description: space!.description,
      displayPicture: _gramImageFile,
      displayPictureUrl: space!.displayPicture,
      memberCount: memberCount,
      isPrivate: isPrivateSpaceType(space!.spaceType),
      inviterName: userName,
      inviterId: user?.uid,
    );
  }

  void _openChat() {
    // Check if user can access chat
    if (!_isMember() && !_isPublicOrOpen()) {
      showCustomSnackBar(context, message: 'You need to be a member to access chat', backgroundColor: AppTheme.errorColor);
      return;
    }

    context.push('/space/chat/${widget.rid}', extra: {
      'space': space!,
    });
  }

  Widget _buildErrorWidget() {
    return Scaffold(
      appBar: CupertinoNavigationBar(
        middle: Text('Error'),
        backgroundColor: AppTheme.scaffoldLightColor,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'An error occurred. Please try again.',
              style: TextStyle(color: AppTheme.textLightColor),
            ),
            SizedBox(height: AppDimensions.spacingLg),
            CupertinoButton(
              onPressed: _refreshSpace,
              color: AppTheme.primaryColor,
              child: Text('Retry'),
            ),
          ],
        ),
      ),
      backgroundColor: AppTheme.scaffoldLightColor,
    );
  }
}
