import 'package:cloud_firestore/cloud_firestore.dart' show QuerySnapshot;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:aurogram/shared/services/database_service.dart';
import 'package:aurogram/features/feed/data/datasources/space_db_service.dart';
import 'package:aurogram/core/di/injection.dart';
import 'package:aurogram/features/profile/presentation/widgets/preview_boxes/crew_preview.dart';
import 'package:aurogram/shared/presentation/widgets/loaders/skeleton_widgets.dart';
import 'package:aurogram/core/logging/app_logger.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';
import 'package:go_router/go_router.dart';

/// A reusable component for displaying space members consistently throughout the app
class SpaceMembersList extends StatefulWidget {
  /// The ID of the space to display members for
  final String spaceId;

  /// Whether this list is being displayed by a user with admin privileges
  final bool isAdmin;

  /// When true, shows admin actions like remove member or make admin
  final bool showAdminActions;

  /// Optional callback for when a member's role changes
  final Function(String userId, String newRole)? onRoleChanged;

  /// Optional callback for when a member is removed
  final Function(String userId)? onMemberRemoved;

  /// Maximum height for the list
  final double? maxHeight;

  /// Padding for the list container
  final EdgeInsets padding;

  const SpaceMembersList({
    super.key,
    required this.spaceId,
    this.isAdmin = false,
    this.showAdminActions = false,
    this.onRoleChanged,
    this.onMemberRemoved,
    this.maxHeight,
    this.padding = const EdgeInsets.symmetric(horizontal: AppDimensions.paddingLg, vertical: AppDimensions.paddingSm),
  });

  @override
  _SpaceMembersListState createState() => _SpaceMembersListState();
}

class _SpaceMembersListState extends State<SpaceMembersList> {
  final SpaceDbService _spaceDbService = locator<SpaceDbService>();
  final DatabaseService _databaseServiceForMembers = DatabaseService();
  late Future<QuerySnapshot> _membersFuture;

  @override
  void initState() {
    super.initState();
    _membersFuture = _fetchMembers();
  }

  @override
  void didUpdateWidget(covariant SpaceMembersList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.spaceId != widget.spaceId) {
      _membersFuture = _fetchMembers();
    }
  }

  Future<QuerySnapshot> _fetchMembers() {
    return _databaseServiceForMembers.getSpaceMembersWithRoles(
      widget.spaceId,
      ['member', 'creator', 'admin'],
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<QuerySnapshot>(
      future: _membersFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: List.generate(4, (_) => const Padding(
                padding: EdgeInsets.only(bottom: AppDimensions.paddingMd),
                child: SkeletonCompactUser(),
              )),
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Text(
                'Error loading members',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Text(
                'No members found',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
              ),
            ),
          );
        }

        final memberDocs = snapshot.data!.docs;
        final int memberCount = memberDocs.length;

        return Container(
          padding: widget.padding,
          constraints: widget.maxHeight != null
              ? BoxConstraints(maxHeight: widget.maxHeight!)
              : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: AppDimensions.paddingMd),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          CupertinoIcons.person_2,
                          size: 18,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        SizedBox(width: AppDimensions.spacingSmMd),
                        Text(
                          'Members',
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                      ),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        transitionBuilder: (child, anim) => FadeTransition(
                          opacity: anim,
                          child: child,
                        ),
                        child: Text(
                          '$memberCount',
                          key: ValueKey(memberCount),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: AppDimensions.spacingMd),
              Divider(),
              SizedBox(height: AppDimensions.spacingMd),
              Flexible(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: memberDocs.map((document) {
                    return GestureDetector(
                      onTap: () {
                        if (widget.showAdminActions && widget.isAdmin) {
                          _showAdminOptions(document.id, document['role']);
                        } else {
                          _navigateToUserProfile(document.id);
                        }
                      },
                      child: CrewPreview(
                        user: document.id,
                        space: widget.spaceId,
                      ),
                    );
                  }).toList(),
                ),
              ),
              SizedBox(height: 100),
            ],
          ),
        );
      },
    );
  }

  void _navigateToUserProfile(String userId) {
    context.push('/user/profile/$userId');
  }

  void _showAdminOptions(String userId, String currentRole) {
    if (!widget.showAdminActions || !widget.isAdmin) return;

    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) => CupertinoActionSheet(
        title: Text('Manage Member'),
        actions: <Widget>[
          CupertinoActionSheetAction(
            child: Text('View Profile'),
            onPressed: () {
              Navigator.pop(context);
              _navigateToUserProfile(userId);
            },
          ),
          if (currentRole != 'admin' && currentRole != 'creator')
            CupertinoActionSheetAction(
              child: Text('Make Admin'),
              onPressed: () {
                Navigator.pop(context);
                _changeMemberRole(userId, 'admin');
              },
            ),
          if (currentRole != 'creator')
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              onPressed: () {
                Navigator.pop(context);
                _removeMember(userId);
              },
              child: Text('Remove from Group'),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          child: Text('Cancel'),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  void _changeMemberRole(String userId, String newRole) async {
    try {
      await _spaceDbService.makeAdmin(widget.spaceId, userId);
      if (widget.onRoleChanged != null) {
        widget.onRoleChanged!(userId, newRole);
      }
      setState(() {
        _membersFuture = _fetchMembers();
      }); // Refresh UI
    } catch (e) {
      AppLogger.e('Error changing member role',
          category: LogCategory.general, data: {'error': e.toString()});
      _showErrorDialog('Failed to change member role. Please try again.');
    }
  }

  void _removeMember(String userId) async {
    try {
      await _spaceDbService.removeSpaceMember(widget.spaceId, userId);
      if (widget.onMemberRemoved != null) {
        widget.onMemberRemoved!(userId);
      }
      setState(() {
        _membersFuture = _fetchMembers();
      }); // Refresh UI
    } catch (e) {
      AppLogger.e('Error removing member',
          category: LogCategory.general, data: {'error': e.toString()});
      _showErrorDialog('Failed to remove member. Please try again.');
    }
  }

  void _showErrorDialog(String message) {
    showCupertinoDialog(
      context: context,
      builder: (BuildContext context) => CupertinoAlertDialog(
        title: Text('Error'),
        content: Text(message),
        actions: <Widget>[
          CupertinoDialogAction(
            child: Text('OK'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}
