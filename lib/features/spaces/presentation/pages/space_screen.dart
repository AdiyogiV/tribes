import 'package:aurogram/core/theme/app_dimensions.dart';
import 'dart:io';
import 'package:aurogram/shared/presentation/widgets/flash.dart';
import 'package:aurogram/shared/presentation/widgets/dialogs/login_bottom_sheet.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:aurogram/shared/models/space.dart';
import 'package:aurogram/shared/models/space_roles.dart';
import 'package:aurogram/shared/models/space_types.dart';
import 'package:aurogram/shared/presentation/widgets/media/media_type_selector.dart';
import 'package:aurogram/features/spaces/presentation/pages/edit_space.dart';
import 'package:aurogram/features/spaces/presentation/pages/grid_space_view.dart';
import 'package:aurogram/features/spaces/presentation/pages/space_chat_screen.dart';
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
  final SpaceService _spaceService = SpaceService();
  bool _isNavigatingToPost = false;

  @override
  void initState() {
    super.initState();
    _initializationFuture = _initializeSpaceBox();

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
    try {
      user = FirebaseAuth.instance.currentUser;
      space = await _spaceService.getSpace(widget.rid);

      if (user != null) {
        role = await _spaceService.getSpaceRole(widget.rid, user!.uid);
        // Fetch user's name for sharing
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user!.uid)
            .get();
        userName = userDoc.data()?['name']?.toString();
      }

      // Pre-fetch gram image from cache for instant sharing
      if (space?.displayPicture != null) {
        final cacheService = locator<CacheService>();
        _gramImageFile = await cacheService.getFile(space!.displayPicture);
      }

      // Fetch member count for sharing
      try {
        final rolesSnapshot = await FirebaseFirestore.instance
            .collection('spaceRoles')
            .doc(widget.rid)
            .collection('roles')
            .get();
        memberCount = rolesSnapshot.docs.length;
      } catch (e) {
        // Ignore error, use default 0
      }

      return _isMember() || isPublicSpaceType(space!.spaceType);
    } catch (e) {
      AppLogger.e('Error initializing space',
          category: LogCategory.general, data: {'error': e.toString()});
      return false;
    }
  }

  bool _isMember() {
    return role == SpaceRoles.member ||
        role == SpaceRoles.creator ||
        role == SpaceRoles.admin;
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
          return FlashScreen();
        }
        if (snapshot.hasError || space == null) {
          return _buildErrorWidget();
        }
        if (snapshot.data == false) {
          // Navigate to EditSpace for non-members of private/personal spaces
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.of(context).pushReplacement(
              CupertinoPageRoute(
                  builder: (context) => EditSpace(space: widget.rid)),
            );
          });
          return FlashScreen();
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
      _initializationFuture = _initializeSpaceBox();
    });
  }

  void _toggleGridView() {
    setState(() => gridViewOn = !gridViewOn);
  }

  void _navigateToEditSpace() {
    Navigator.push(
      context,
      CupertinoPageRoute(builder: (context) => EditSpace(space: widget.rid)),
    );
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

    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) => SpaceChatScreen(
          spaceId: widget.rid,
          space: space!,
        ),
      ),
    );
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
