import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:aurogram/widgets/ui/common_widgets.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:aurogram/pages/spaces/space_screen.dart';
import 'package:aurogram/pages/tabs/user_profile.dart';
import 'package:aurogram/services/database_service.dart';
import 'package:aurogram/services/space_service.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:aurogram/utils/theme/header_style.dart';
import 'package:aurogram/widgets/ui/skeleton_widgets.dart';
import 'package:aurogram/utils/dependency_injection.dart';
import 'package:aurogram/utils/logging/app_logger.dart';
import 'package:aurogram/utils/theme/app_dimensions.dart';
import 'package:aurogram/widgets/common/snack_bar_service.dart';

class Invites extends StatefulWidget {
  const Invites({
    super.key,
  });
  @override
  InvitesState createState() => InvitesState();
}

class InvitesState extends State<Invites> {
  User? user = FirebaseAuth.instance.currentUser;
  bool _isRefreshing = false;

  Future<void> _handleRefresh() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) {
      setState(() => _isRefreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (user == null) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppHeaderStyle.buildStandardAppBar(
          context: context,
          title: 'gram invites',
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.card_giftcard,
                size: 64,
                color: AppTheme.primaryColor.withValues(alpha: 0.4),
              ),
              const SizedBox(height: AppDimensions.spacingLg),
              Text(
                'Please log in to view invites',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontSize: 18,
                      color: AppTheme.textSecondaryColor,
                    ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      extendBody: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          // Standard header
          AppHeaderStyle.buildStandardHeader(
            context: context,
            title: 'gram invites',
            showSearchField: false,
            isRefreshing: _isRefreshing,
            leadingWidget: IconButton(
              icon: Icon(
                Icons.arrow_back_ios,
                color: AppTheme.primaryColor,
                size: AppHeaderStyle.headerIconSize,
              ),
              onPressed: () => Navigator.of(context).pop(),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
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
            child: Padding(
              padding: EdgeInsets.only(
                top: AppHeaderStyle.contentTopPadding,
                bottom: AppHeaderStyle.contentBottomPadding,
              ),
              child: FutureBuilder<QuerySnapshot>(
                future: FirebaseFirestore.instance
                    .collection('userSpaces')
                    .doc(user!.uid)
                    .collection('spaces')
                    .where('role', isEqualTo: 'invited')
                    .get(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return _buildLoadingState();
                  }

                  if (snapshot.hasError) {
                    return _buildErrorState();
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return _buildEmptyState();
                  }

                  final invites = snapshot.data!.docs;

                  return Column(
                    children: [
                      ...invites.asMap().entries.map((entry) {
                        final index = entry.key;
                        final doc = entry.value;
                        final spaceId = doc.id;
                        final inviterId = (doc.data() as Map<String, dynamic>)
                                .containsKey('inviter')
                            ? doc['inviter'] as String?
                            : null;

                        return Padding(
                          padding: EdgeInsets.fromLTRB(
                            AppHeaderStyle.contentHorizontalPadding,
                            index == 0 ? 0 : AppHeaderStyle.cardVerticalGap,
                            AppHeaderStyle.contentHorizontalPadding,
                            index == invites.length - 1
                                ? 0
                                : AppHeaderStyle.cardVerticalGap,
                          ),
                          child: _InviteCard(
                            spaceId: spaceId,
                            inviterId: inviterId,
                            onRefresh: _handleRefresh,
                          ),
                        );
                      }),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppHeaderStyle.contentHorizontalPadding,
        ),
        child: Column(
          children: List.generate(
            3,
            (index) => Padding(
              padding: EdgeInsets.only(
                bottom: index == 2 ? 0 : AppHeaderStyle.cardVerticalGap,
              ),
              child: const SkeletonListItem(height: 140),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppHeaderStyle.contentHorizontalPadding,
          vertical: 60,
        ),
        child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.card_giftcard,
              size: 64,
              color: AppTheme.primaryColor.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: AppDimensions.spacingXxl),
          Text(
            'No invites yet',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: AppDimensions.spacingSm),
          Text(
            'When someone invites you to join a gram,\nit will appear here',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: AppTheme.textSecondaryColor,
              height: 1.4,
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppHeaderStyle.contentHorizontalPadding,
          vertical: 60,
        ),
        child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: AppTheme.errorColor.withValues(alpha: 0.6),
          ),
          const SizedBox(height: AppDimensions.spacingXxl),
          Text(
            'Something went wrong',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: AppDimensions.spacingSm),
          Text(
            'Please try again later',
            style: TextStyle(
              fontSize: 15,
              color: AppTheme.textSecondaryColor,
            ),
          ),
        ],
      ),
      ),
    );
  }
}

class _InviteCard extends StatefulWidget {
  final String spaceId;
  final String? inviterId;
  final VoidCallback onRefresh;

  const _InviteCard({
    required this.spaceId,
    required this.inviterId,
    required this.onRefresh,
  });

  @override
  State<_InviteCard> createState() => _InviteCardState();
}

class _InviteCardState extends State<_InviteCard> {
  String _spaceName = 'Loading...';
  String? _spacePictureUrl;
  String _inviterName = 'Someone';
  String? _inviterPictureUrl;
  bool _isLoading = true;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final spaceService = locator<SpaceService>();
      final space = await spaceService.getSpace(widget.spaceId);
      
      if (mounted) {
        setState(() {
          _spaceName = space.name ?? 'Unknown Gram';
          _spacePictureUrl = space.displayPicture;
        });
      }

      if (widget.inviterId != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.inviterId)
            .get();
        
        if (mounted && userDoc.exists) {
          final userData = userDoc.data()!;
          setState(() {
            _inviterName = userData['displayName'] as String? ??
                userData['name'] as String? ??
                'Someone';
            _inviterPictureUrl = userData['displayPicture'] as String?;
          });
        }
      }
    } catch (e) {
      AppLogger.e('Error loading invite data',
          category: LogCategory.general, data: {'error': e.toString()});
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _acceptInvite() async {
    if (_isProcessing) return;
    
    setState(() => _isProcessing = true);
    HapticFeedback.mediumImpact();

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      final success = await DatabaseService().approveSpaceMember(
        widget.spaceId,
        currentUser.uid,
      );

      if (!success) {
        throw Exception('Failed to accept invite');
      }

      widget.onRefresh();

      if (mounted) {
        Navigator.of(context).pushReplacement(
          CupertinoPageRoute(
            builder: (context) => SpaceScreen(rid: widget.spaceId),
          ),
        );
      }
    } catch (e) {
      AppLogger.e('Error accepting invite',
          category: LogCategory.general, data: {'error': e.toString()});
      if (mounted) {
        showCustomSnackBar(context, message: 'Failed to accept invite. Please try again.', backgroundColor: AppTheme.errorColor);
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _declineInvite() async {
    if (_isProcessing) return;
    
    setState(() => _isProcessing = true);
    HapticFeedback.lightImpact();

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      final success = await DatabaseService().rejectSpaceMember(
        widget.spaceId,
        currentUser.uid,
      );

      if (!success) {
        throw Exception('Failed to decline invite');
      }

      widget.onRefresh();
    } catch (e) {
      AppLogger.e('Error declining invite',
          category: LogCategory.general, data: {'error': e.toString()});
      if (mounted) {
        showCustomSnackBar(context, message: 'Failed to decline invite. Please try again.', backgroundColor: AppTheme.errorColor);
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    if (_isLoading) {
      return Container(
        height: 140,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppHeaderStyle.cardBorderRadius),
          color: isDark ? AppTheme.cardDarkColor : Colors.white,
        ),
        child: const AppLoadingIndicator(),
      );
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppHeaderStyle.cardBorderRadius),
        boxShadow: AppHeaderStyle.cardBoxShadow(isDark),
      ),
      child: Material(
        elevation: 4,
        color: Colors.transparent,
        shadowColor: Colors.black.withValues(alpha: 0.04),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppHeaderStyle.cardBorderRadius),
        ),
        clipBehavior: Clip.antiAlias,
        child: Container(
          padding: EdgeInsets.all(AppHeaderStyle.cardInternalPaddingH),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.cardDarkColor : Colors.white,
            border: AppHeaderStyle.cardBorder(isDark),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Inviter info and gram preview
              Row(
                children: [
                  // Inviter avatar
                  GestureDetector(
                    onTap: widget.inviterId != null
                        ? () {
                            Navigator.of(context).push(
                              CupertinoPageRoute(
                                builder: (context) =>
                                    UserProfilePage(uid: widget.inviterId!),
                              ),
                            );
                          }
                        : null,
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppTheme.primaryColor.withValues(alpha: 0.2),
                          width: 2,
                        ),
                      ),
                      child: ClipOval(
                        child: _inviterPictureUrl != null &&
                                _inviterPictureUrl!.isNotEmpty
                            ? Image.network(
                                _inviterPictureUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    _buildDefaultAvatar(),
                              )
                            : _buildDefaultAvatar(),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppDimensions.spacingMd),
                  // Invitation text
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RichText(
                          text: TextSpan(
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primaryColor,
                              height: 1.3,
                            ),
                            children: [
                              TextSpan(
                                text: _inviterName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const TextSpan(text: ' invited you to join '),
                              TextSpan(
                                text: _spaceName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppDimensions.spacingXs),
                        Text(
                          'Tap to preview',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.textSecondaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Gram picture preview
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        CupertinoPageRoute(
                          builder: (context) =>
                              SpaceScreen(rid: widget.spaceId),
                        ),
                      );
                    },
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                        border: Border.all(
                          color: AppTheme.primaryColor.withValues(alpha: 0.2),
                          width: 1.5,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10.5),
                        child: _spacePictureUrl != null &&
                                _spacePictureUrl!.isNotEmpty
                            ? Image.network(
                                _spacePictureUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    _buildDefaultGramIcon(),
                              )
                            : _buildDefaultGramIcon(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.spacingLg),
              // Action buttons
              Row(
                children: [
                  // Decline button
                  Expanded(
                    child: _ActionButton(
                      label: 'Decline',
                      icon: Icons.close_rounded,
                      color: AppTheme.errorColor,
                      onTap: _declineInvite,
                      isLoading: _isProcessing,
                    ),
                  ),
                  const SizedBox(width: AppDimensions.spacingMd),
                  // Accept button
                  Expanded(
                    flex: 2,
                    child: _ActionButton(
                      label: 'Accept',
                      icon: Icons.check_circle_rounded,
                      color: AppTheme.successColor,
                      onTap: _acceptInvite,
                      isLoading: _isProcessing,
                      isPrimary: true,
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

  Widget _buildDefaultAvatar() {
    return Container(
      color: AppTheme.primaryColor.withValues(alpha: 0.1),
      child: Icon(
        Icons.person,
        color: AppTheme.primaryColor.withValues(alpha: 0.5),
        size: 24,
      ),
    );
  }

  Widget _buildDefaultGramIcon() {
    return Container(
      color: AppTheme.primaryColor.withValues(alpha: 0.1),
      child: Icon(
        Icons.group,
        color: AppTheme.primaryColor.withValues(alpha: 0.5),
        size: 28,
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool isLoading;
  final bool isPrimary;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.isLoading = false,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: isPrimary
                ? color
                : color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            border: isPrimary
                ? null
                : Border.all(
                    color: color.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isLoading)
                AppLoadingIndicator(
                  size: 16,
                  strokeWidth: 2,
                  color: isPrimary ? Colors.white : color,
                )
              else
                Icon(
                  icon,
                  size: 18,
                  color: isPrimary ? Colors.white : color,
                ),
              const SizedBox(width: AppDimensions.spacingSm),
              Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: isPrimary ? Colors.white : color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
