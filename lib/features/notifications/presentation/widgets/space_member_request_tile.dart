import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:aurogram/features/profile/presentation/pages/user_profile.dart';
import 'package:aurogram/core/di/injection.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/shared/presentation/widgets/avatars/user_avatar.dart';
import 'package:aurogram/shared/presentation/widgets/loaders/skeleton_widgets.dart';
import 'package:aurogram/features/feed/data/datasources/space_db_service.dart';
import 'package:aurogram/features/profile/domain/user_service.dart';
import 'package:aurogram/shared/presentation/widgets/feedback/snack_bar_service.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';

/// Tile for space membership requests (used in Requests page)
/// Shows accept/decline buttons for users requesting to join a space
class SpaceMemberRequestTile extends StatefulWidget {
  final String space;
  final String uid;
  final VoidCallback? onRefresh;

  const SpaceMemberRequestTile({
    required this.space,
    required this.uid,
    this.onRefresh,
    super.key,
  });

  @override
  _SpaceMemberRequestTileState createState() => _SpaceMemberRequestTileState();
}

class _SpaceMemberRequestTileState extends State<SpaceMemberRequestTile> {
  String _userName = '';
  String _userAvatar = '';
  String _username = '';
  bool _ready = false;
  bool _isProcessing = false;
  bool _isApproved = false;
  bool _isDeclined = false;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    try {
      final userService = locator<UserService>();
      final userDoc = await userService.getUser(widget.uid);

      if (userDoc.exists) {
        _userName = userDoc['name']?.toString() ?? 'Unknown User';
        _username = userDoc['nickname']?.toString() ?? '';
        _userAvatar = userDoc['displayPicture']?.toString() ?? '';
      } else {
        _userName = 'Unknown User';
      }
    } catch (e) {
      _userName = 'Unknown User';
    } finally {
      if (mounted) {
        setState(() => _ready = true);
      }
    }
  }

  Future<void> _approveRequest() async {
    if (_isProcessing) return;

    setState(() => _isProcessing = true);

    try {
      final spaceDbService = locator<SpaceDbService>();
      final success =
          await spaceDbService.approveJoinRequest(widget.space, widget.uid);

      if (mounted) {
        if (success) {
          setState(() {
            _isApproved = true;
            _isProcessing = false;
          });
          widget.onRefresh?.call();
        } else {
          setState(() => _isProcessing = false);
          showCustomSnackBar(context, message: 'Failed to approve request', backgroundColor: AppTheme.errorColor);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        showCustomSnackBar(context, message: 'Failed to approve request', backgroundColor: AppTheme.errorColor);
      }
    }
  }

  Future<void> _declineRequest() async {
    if (_isProcessing) return;

    setState(() => _isProcessing = true);

    try {
      final spaceDbService = locator<SpaceDbService>();
      // Use removeSpaceMember to decline/reject the join request
      final success =
          await spaceDbService.removeSpaceMember(widget.space, widget.uid);

      if (mounted) {
        if (success) {
          setState(() {
            _isDeclined = true;
            _isProcessing = false;
          });
          widget.onRefresh?.call();
        } else {
          setState(() => _isProcessing = false);
          showCustomSnackBar(context, message: 'Failed to decline request', backgroundColor: AppTheme.errorColor);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        showCustomSnackBar(context, message: 'Failed to decline request', backgroundColor: AppTheme.errorColor);
      }
    }
  }

  void _openProfile() {
    if (widget.uid.isEmpty) return;
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) => UserProfilePage(uid: widget.uid),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppDimensions.paddingXs, horizontal: AppDimensions.paddingLg),
        child: SkeletonListItem(height: 80),
      );
    }

    final primaryColor = AppTheme.primaryColor;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _openProfile,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingLg, vertical: AppDimensions.paddingMd),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar
              UserAvatar(
                userId: widget.uid,
                imageUrl: _userAvatar,
                size: 44,
                nameInitials: _userName.isNotEmpty ? _userName[0] : null,
              ),
              const SizedBox(width: AppDimensions.spacingMd),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _userName,
                      style: TextStyle(
                        fontSize: AppTheme.holyCowTextSize,
                        fontWeight: FontWeight.w600,
                        color: primaryColor,
                      ),
                    ),
                    if (_username.isNotEmpty) ...[
                      const SizedBox(height: AppDimensions.spacingXxs),
                      Text(
                        '@$_username',
                        style: TextStyle(
                          fontSize: AppTheme.holyCowTextSize,
                          color: primaryColor.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                    const SizedBox(height: AppDimensions.spacingXs),
                    Text(
                      'Wants to join this space',
                      style: TextStyle(
                        fontSize: AppTheme.holyCowTextSize,
                        color: primaryColor.withValues(alpha: 0.5),
                      ),
                    ),
                    // Action buttons
                    if (!_isApproved && !_isDeclined) ...[
                      const SizedBox(height: AppDimensions.spacingMdSm),
                      Row(
                        children: [
                          // Approve button
                          Expanded(
                            child: GestureDetector(
                              onTap: _isProcessing ? null : _approveRequest,
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: AppDimensions.paddingSm),
                                decoration: BoxDecoration(
                                  color: AppTheme.successColor,
                                  borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                                ),
                                child: _isProcessing
                                    ? const SizedBox(
                                        height: 16,
                                        width: 16,
                                        child: CupertinoActivityIndicator(
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text(
                                        'Approve',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: AppTheme.holyCowTextSize,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppDimensions.spacingSm),
                          // Decline button
                          Expanded(
                            child: GestureDetector(
                              onTap: _isProcessing ? null : _declineRequest,
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: AppDimensions.paddingSm),
                                decoration: BoxDecoration(
                                  color: primaryColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                                ),
                                child: Text(
                                  'Decline',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: AppTheme.holyCowTextSize,
                                    fontWeight: FontWeight.w600,
                                    color: primaryColor,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      const SizedBox(height: AppDimensions.spacingSm),
                      Text(
                        _isApproved ? 'Request approved' : 'Request declined',
                        style: TextStyle(
                          fontSize: AppTheme.holyCowTextSize,
                          fontWeight: FontWeight.w500,
                          color: _isApproved
                              ? AppTheme.successColor
                              : primaryColor.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

