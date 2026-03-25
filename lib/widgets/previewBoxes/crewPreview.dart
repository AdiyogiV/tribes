import 'package:flutter/material.dart';
import 'package:aurogram/models/space_roles.dart';
import 'package:aurogram/utils/dependency_injection.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:aurogram/widgets/user_avatar.dart';
import 'package:aurogram/widgets/ui/skeleton_widgets.dart';
import 'package:aurogram/services/data/space_db_service.dart';
import 'package:aurogram/services/user_service.dart';

class CrewPreview extends StatefulWidget {
  final String? user;
  final String? space;
  const CrewPreview({this.user, this.space, Key? key}) : super(key: key);

  @override
  _CrewPreviewState createState() => _CrewPreviewState();
}

class _CrewPreviewState extends State<CrewPreview> {
  late Future<Map<String, dynamic>> _textDataFuture;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _textDataFuture = _loadTextData();
  }

  Future<Map<String, dynamic>> _loadTextData() async {
    final userService = locator<UserService>();
    final userDoc = await userService.getUser(widget.user!);

    final userData = {
      'name': userDoc.exists ? userDoc['name'] : 'Unknown User',
      'username': userDoc.exists ? userDoc['nickname'] : '-',
      'imageUrl': userDoc.exists ? userDoc['displayPicture'] : null,
    };

    SpaceRoles? role;
    if (widget.space != null && widget.user != null) {
      final spaceDbService = locator<SpaceDbService>();
      role = await spaceDbService.getSpaceRole(widget.space!, widget.user!);
    }

    return {
      ...userData,
      'role': role,
    };
  }

  Widget _buildUserTypeWidget(SpaceRoles? role) {
    switch (role) {
      case SpaceRoles.member:
        return _buildRoleContainer(
            'Member', AppTheme.successColor, Icons.check_circle);
      case SpaceRoles.invited:
        return GestureDetector(
          onTap: _uninviteUser,
          child:
              _buildRoleContainer('Invited', Colors.orange, Icons.mail_outline),
        );
      case SpaceRoles.admin:
        return _buildRoleContainer(
            'Admin', AppTheme.primaryColor, Icons.admin_panel_settings);
      case SpaceRoles.creator:
        return _buildRoleContainer(
            'Creator', Colors.purple, Icons.stars_rounded);
      case SpaceRoles.requested:
        return _buildRoleContainer(
            'Pending', AppTheme.warningColor, Icons.schedule);
      default:
        return SizedBox.shrink();
    }
  }

  Widget _buildRoleContainer(String text, Color color, IconData icon) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrailingAction(SpaceRoles? role) {
    // Trailing action based on role
    if (widget.space == null || widget.user == null) return SizedBox.shrink();

    if (_isProcessing) {
      return const SizedBox(
        width: 72,
        height: 32,
        child: Center(
          child: PulsingDots(size: 6),
        ),
      );
    }

    switch (role) {
      case SpaceRoles.none:
      case null:
        return ElevatedButton.icon(
          onPressed: _addSpaceMember,
          icon: Icon(Icons.person_add_rounded, size: 16, color: Colors.white),
          label: Text(
            'Add',
            style: TextStyle(
                color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            minimumSize: Size(80, 36),
            elevation: 0,
          ),
        );
      case SpaceRoles.requested:
        return ElevatedButton.icon(
          onPressed: _approveJoinRequest,
          icon: Icon(Icons.check_circle_rounded, size: 16, color: Colors.white),
          label: Text('Approve',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.successColor,
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            minimumSize: Size(80, 36),
            elevation: 0,
          ),
        );
      case SpaceRoles.invited:
        return OutlinedButton.icon(
          onPressed: _uninviteUser,
          icon: Icon(Icons.remove_circle_outline_rounded,
              size: 16, color: AppTheme.warningColor),
          label: Text('Remove',
              style: TextStyle(
                  color: AppTheme.warningColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: AppTheme.warningColor, width: 1.5),
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            minimumSize: Size(80, 36),
          ),
        );
      default:
        return SizedBox.shrink();
    }
  }

  Future<void> _addSpaceMember() async {
    if (_isProcessing) return;

    setState(() => _isProcessing = true);

    try {
      final spaceDbService = locator<SpaceDbService>();
      final success =
          await spaceDbService.inviteToSpace(widget.space!, widget.user!);

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text('Member invited successfully'),
                ],
              ),
              backgroundColor: AppTheme.successColor,
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 2),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
        setState(() {
          _textDataFuture = _loadTextData();
          _isProcessing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);

        String errorMessage = 'Failed to invite member';
        if (e.toString().contains('permission')) {
          errorMessage = 'Only admins and creators can invite members';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Expanded(child: Text(errorMessage)),
              ],
            ),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 3),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  Future<void> _uninviteUser() async {
    if (_isProcessing) return;

    setState(() => _isProcessing = true);

    try {
      final spaceDbService = locator<SpaceDbService>();
      final success =
          await spaceDbService.removeSpaceMember(widget.space!, widget.user!);

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text('Member removed successfully'),
                ],
              ),
              backgroundColor: AppTheme.successColor,
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 2),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
        setState(() {
          _textDataFuture = _loadTextData();
          _isProcessing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Expanded(child: Text('Failed to remove member')),
              ],
            ),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 3),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  Future<void> _approveJoinRequest() async {
    if (_isProcessing) return;

    setState(() => _isProcessing = true);

    try {
      final spaceDbService = locator<SpaceDbService>();
      final success =
          await spaceDbService.approveJoinRequest(widget.space!, widget.user!);

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text('Join request approved'),
                ],
              ),
              backgroundColor: AppTheme.successColor,
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 2),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
        setState(() {
          _textDataFuture = _loadTextData();
          _isProcessing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Expanded(child: Text('Failed to approve request')),
              ],
            ),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 3),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  Widget _buildLoadingSkeleton(bool isLandscape) {
    return Row(
      children: <Widget>[
        Padding(
          padding: EdgeInsets.all(isLandscape ? 4.0 : 6.0),
          child: Container(
            width: isLandscape ? 56.0 : 64.0,
            height: isLandscape ? 56.0 : 64.0,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              shape: BoxShape.circle,
            ),
          ),
        ),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 120,
                height: 14,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Container(
                width: 80,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: 8),
        Container(
          width: 80,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        SizedBox(width: 8),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    return Container(
      height: isLandscape ? 70 : 80,
      padding: EdgeInsets.symmetric(
          horizontal: isLandscape ? 6.0 : 8.0,
          vertical: isLandscape ? 3.0 : 4.0),
      child: Material(
        borderRadius: BorderRadius.circular(12.0),
        elevation: 1,
        shadowColor: Colors.black.withValues(alpha: 0.05),
        color: Colors.white,
        child: FutureBuilder<Map<String, dynamic>>(
          future: _textDataFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _buildLoadingSkeleton(isLandscape);
            }
            if (!snapshot.hasData) {
              return Center(
                  child: Padding(
                padding: EdgeInsets.all(8.0),
                child: Text('Error loading data',
                    style: TextStyle(color: AppTheme.errorColor, fontSize: 12)),
              ));
            }
            final data = snapshot.data!;
            return Row(
              children: <Widget>[
                Padding(
                  padding: EdgeInsets.all(isLandscape ? 4.0 : 6.0),
                  child: UserAvatar(
                    userId: widget.user,
                    imageUrl: data['imageUrl'],
                    size: isLandscape ? 56.0 : 64.0,
                    showBorder: true,
                    borderColor: AppTheme.primaryColor.withValues(alpha: 0.3),
                    nameInitials: data['name'] != null
                        ? (data['name'] as String).isNotEmpty
                            ? (data['name'] as String)[0]
                            : null
                        : null,
                  ),
                ),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 3),
                        child: Text(
                          data['name'] ?? '',
                          style: TextStyle(
                            fontSize: isLandscape ? 14 : 15,
                            color: AppTheme.textLightColor,
                            overflow: TextOverflow.ellipsis,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Padding(
                              padding: EdgeInsets.only(
                                  bottom: isLandscape ? 3.0 : 5.0, left: 3.0),
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '@${data['username'] ?? ''}',
                                  style: TextStyle(
                                    fontSize: isLandscape ? 10 : 11,
                                    color: AppTheme.primaryColor,
                                    overflow: TextOverflow.ellipsis,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 8),
                          _buildUserTypeWidget(data['role']),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 8),
                Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: _buildTrailingAction(data['role']),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
