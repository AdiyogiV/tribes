import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:aurogram/pages/tabs/user_profile.dart';
import 'package:aurogram/utils/dependency_injection.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:aurogram/widgets/user_avatar.dart';
import 'package:aurogram/widgets/ui/skeleton_widgets.dart';
import 'package:aurogram/services/data/space_db_service.dart';
import 'package:aurogram/services/user_service.dart';

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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Failed to approve request'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to approve request'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Failed to decline request'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to decline request'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
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
        padding: EdgeInsets.symmetric(vertical: 4, horizontal: 16),
        child: SkeletonListItem(height: 80),
      );
    }

    final primaryColor = AppTheme.primaryColor;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _openProfile,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
              const SizedBox(width: 12),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _userName,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: primaryColor,
                      ),
                    ),
                    if (_username.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        '@$_username',
                        style: TextStyle(
                          fontSize: 13,
                          color: primaryColor.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      'Wants to join this space',
                      style: TextStyle(
                        fontSize: 13,
                        color: primaryColor.withValues(alpha: 0.5),
                      ),
                    ),
                    // Action buttons
                    if (!_isApproved && !_isDeclined) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          // Approve button
                          Expanded(
                            child: GestureDetector(
                              onTap: _isProcessing ? null : _approveRequest,
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: AppTheme.successColor,
                                  borderRadius: BorderRadius.circular(8),
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
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Decline button
                          Expanded(
                            child: GestureDetector(
                              onTap: _isProcessing ? null : _declineRequest,
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: primaryColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Decline',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 13,
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
                      const SizedBox(height: 8),
                      Text(
                        _isApproved ? 'Request approved' : 'Request declined',
                        style: TextStyle(
                          fontSize: 12,
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

