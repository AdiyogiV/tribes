import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:aurogram/pages/tabs/userProfile.dart';
import 'package:aurogram/utils/time_display.dart';
import 'package:aurogram/widgets/user_avatar.dart';
import 'package:aurogram/widgets/ui/skeleton_widgets.dart';
import 'package:aurogram/utils/logging/app_logger.dart';
import 'package:aurogram/utils/theme/app_theme.dart';

/// Tile for follow request notifications (type: followRequest)
/// Shows accept/decline buttons for private profile follow requests
class FollowRequestTile extends StatefulWidget {
  final Map<String, dynamic>? data;

  const FollowRequestTile({this.data, Key? key}) : super(key: key);

  @override
  _FollowRequestTileState createState() => _FollowRequestTileState();
}

class _FollowRequestTileState extends State<FollowRequestTile> {
  String _fromUserName = '';
  String _fromUserAvatar = '';
  String _fromUserId = '';
  String _date = '';
  bool _ready = false;
  bool _isProcessing = false;
  bool _isAccepted = false;
  bool _isDeclined = false;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      _fromUserId = widget.data?['fromUserId']?.toString() ?? '';
      _fromUserName = widget.data?['fromUserName']?.toString() ?? 'Someone';
      _fromUserAvatar = widget.data?['fromUserAvatar']?.toString() ?? '';

      // Fetch date
      if (widget.data?['timestamp'] is Timestamp) {
        _date = TimeDisplay.getCompactTimestamp(
            (widget.data!['timestamp'] as Timestamp).toDate());
      } else {
        _date = 'Recently';
      }

      // If we have a fromUserId, try to get latest user info
      if (_fromUserId.isNotEmpty) {
        try {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(_fromUserId)
              .get();
          if (userDoc.exists) {
            final data = userDoc.data();
            _fromUserName = data?['name']?.toString() ?? _fromUserName;
            _fromUserAvatar = data?['displayPicture']?.toString() ?? _fromUserAvatar;
          }
        } catch (_) {}
      }
    } catch (e) {
      AppLogger.e('Error fetching follow request notification data',
          category: LogCategory.general, data: {'error': e.toString()});
      if (_fromUserName.isEmpty) _fromUserName = 'Someone';
      if (_date.isEmpty) _date = 'Recently';
    } finally {
      if (mounted) {
        setState(() => _ready = true);
      }
    }
  }

  Future<void> _acceptRequest() async {
    if (_isProcessing || _fromUserId.isEmpty) return;

    final currentUserId = _getCurrentUserId();
    if (currentUserId.isEmpty) return;

    setState(() => _isProcessing = true);

    try {
      // Update the follow document status to 'following'
      // The backend onFollowApproved will handle creating follower records
      // The fromUserId is the follower, current user is the target
      await FirebaseFirestore.instance
          .collection('userFollowing')
          .doc(_fromUserId)
          .collection('following')
          .doc(currentUserId)
          .update({'status': 'following'});

      if (mounted) {
        setState(() {
          _isAccepted = true;
          _isProcessing = false;
        });
      }

      // Mark notification as read
      _markAsRead();
    } catch (e) {
      AppLogger.e('Error accepting follow request', error: e);
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to accept request'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _declineRequest() async {
    if (_isProcessing || _fromUserId.isEmpty) return;

    final currentUserId = _getCurrentUserId();
    if (currentUserId.isEmpty) return;

    setState(() => _isProcessing = true);

    try {
      // Delete the follow document - this will trigger onUnfollow
      await FirebaseFirestore.instance
          .collection('userFollowing')
          .doc(_fromUserId)
          .collection('following')
          .doc(currentUserId)
          .delete();

      if (mounted) {
        setState(() {
          _isDeclined = true;
          _isProcessing = false;
        });
      }

      // Mark notification as read
      _markAsRead();
    } catch (e) {
      AppLogger.e('Error declining follow request', error: e);
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

  String _getCurrentUserId() {
    return FirebaseAuth.instance.currentUser?.uid ?? '';
  }

  void _markAsRead() {
    try {
      final notificationId = widget.data?['id']?.toString();
      final userId = _getCurrentUserId();
      if (notificationId != null && userId.isNotEmpty) {
        FirebaseFirestore.instance
            .collection('notifications')
            .doc(userId)
            .collection('notifications')
            .doc(notificationId)
            .update({'read': true});
      }
    } catch (_) {}
  }

  void _openProfile() {
    if (_fromUserId.isEmpty) return;
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) => UserProfilePage(uid: _fromUserId),
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
    final bool isRead = widget.data?['read'] == true;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _openProfile,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isRead ? Colors.transparent : primaryColor.withValues(alpha: 0.05),
          ),
        child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar
              UserAvatar(
                userId: _fromUserId,
                imageUrl: _fromUserAvatar,
                size: 44,
                nameInitials: _fromUserName.isNotEmpty ? _fromUserName[0] : null,
              ),
              const SizedBox(width: 12),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        style: TextStyle(
                          fontSize: 14,
                          color: primaryColor,
                          height: 1.3,
                        ),
                        children: [
                          TextSpan(
                            text: _fromUserName,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const TextSpan(text: ' wants to follow you'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _date,
                      style: TextStyle(
                        fontSize: 12,
                        color: primaryColor.withValues(alpha: 0.5),
                      ),
                    ),
                    // Action buttons
                    if (!_isAccepted && !_isDeclined) ...[
                      const SizedBox(height: 10),
                      Row(
          children: [
                          // Accept button
            Expanded(
              child: GestureDetector(
                              onTap: _isProcessing ? null : _acceptRequest,
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: primaryColor,
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
                                        'Accept',
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
                                padding: const EdgeInsets.symmetric(vertical: 8),
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
                        _isAccepted ? 'Request accepted' : 'Request declined',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: _isAccepted
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

/// Tile for follow notifications (type: follow)
/// Shows when someone starts following you (public profile)
class FollowTile extends StatefulWidget {
  final Map<String, dynamic>? data;

  const FollowTile({this.data, Key? key}) : super(key: key);

  @override
  _FollowTileState createState() => _FollowTileState();
}

class _FollowTileState extends State<FollowTile> {
  String _fromUserName = '';
  String _fromUserAvatar = '';
  String _fromUserId = '';
  String _date = '';
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      _fromUserId = widget.data?['fromUserId']?.toString() ?? '';
      _fromUserName = widget.data?['fromUserName']?.toString() ?? 'Someone';
      _fromUserAvatar = widget.data?['fromUserAvatar']?.toString() ?? '';

      if (widget.data?['timestamp'] is Timestamp) {
        _date = TimeDisplay.getCompactTimestamp(
            (widget.data!['timestamp'] as Timestamp).toDate());
      } else {
        _date = 'Recently';
      }

      // Fetch latest user info if possible
      if (_fromUserId.isNotEmpty) {
        try {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(_fromUserId)
              .get();
          if (userDoc.exists) {
            final data = userDoc.data();
            _fromUserName = data?['name']?.toString() ?? _fromUserName;
            _fromUserAvatar = data?['displayPicture']?.toString() ?? _fromUserAvatar;
          }
        } catch (_) {}
      }
    } catch (e) {
      AppLogger.e('Error fetching follow notification data',
          category: LogCategory.general, data: {'error': e.toString()});
    } finally {
      if (mounted) {
        setState(() => _ready = true);
      }
    }
  }

  void _openProfile() {
    if (_fromUserId.isEmpty) return;
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) => UserProfilePage(uid: _fromUserId),
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
    final bool isRead = widget.data?['read'] == true;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _openProfile,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isRead ? Colors.transparent : primaryColor.withValues(alpha: 0.05),
          ),
          child: Row(
            children: [
              // Avatar
              UserAvatar(
                userId: _fromUserId,
                imageUrl: _fromUserAvatar,
                size: 44,
                nameInitials: _fromUserName.isNotEmpty ? _fromUserName[0] : null,
              ),
              const SizedBox(width: 12),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        style: TextStyle(
                          fontSize: 14,
                          color: primaryColor,
                          height: 1.3,
                        ),
                        children: [
                          TextSpan(
                            text: _fromUserName,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const TextSpan(text: ' started following you'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _date,
                        style: TextStyle(
                        fontSize: 12,
                        color: primaryColor.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
              // Follow icon
              Icon(
                CupertinoIcons.person_add_solid,
                color: primaryColor.withValues(alpha: 0.4),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tile for follow accepted notifications (type: followAccepted)
/// Shows when a private profile user accepts your follow request
class FollowAcceptedTile extends StatefulWidget {
  final Map<String, dynamic>? data;

  const FollowAcceptedTile({this.data, Key? key}) : super(key: key);

  @override
  _FollowAcceptedTileState createState() => _FollowAcceptedTileState();
}

class _FollowAcceptedTileState extends State<FollowAcceptedTile> {
  String _fromUserName = '';
  String _fromUserAvatar = '';
  String _fromUserId = '';
  String _date = '';
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      _fromUserId = widget.data?['fromUserId']?.toString() ?? '';
      _fromUserName = widget.data?['fromUserName']?.toString() ?? 'Someone';
      _fromUserAvatar = widget.data?['fromUserAvatar']?.toString() ?? '';

      if (widget.data?['timestamp'] is Timestamp) {
        _date = TimeDisplay.getCompactTimestamp(
            (widget.data!['timestamp'] as Timestamp).toDate());
      } else {
        _date = 'Recently';
      }

      if (_fromUserId.isNotEmpty) {
        try {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(_fromUserId)
              .get();
          if (userDoc.exists) {
            final data = userDoc.data();
            _fromUserName = data?['name']?.toString() ?? _fromUserName;
            _fromUserAvatar = data?['displayPicture']?.toString() ?? _fromUserAvatar;
          }
        } catch (_) {}
      }
    } catch (e) {
      AppLogger.e('Error fetching follow accepted notification data',
          category: LogCategory.general, data: {'error': e.toString()});
    } finally {
      if (mounted) {
        setState(() => _ready = true);
      }
    }
  }

  void _openProfile() {
    if (_fromUserId.isEmpty) return;
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) => UserProfilePage(uid: _fromUserId),
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
    final bool isRead = widget.data?['read'] == true;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _openProfile,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isRead ? Colors.transparent : primaryColor.withValues(alpha: 0.05),
          ),
          child: Row(
            children: [
              // Avatar
              UserAvatar(
                userId: _fromUserId,
                imageUrl: _fromUserAvatar,
                size: 44,
                nameInitials: _fromUserName.isNotEmpty ? _fromUserName[0] : null,
              ),
              const SizedBox(width: 12),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        style: TextStyle(
                          fontSize: 14,
                          color: primaryColor,
                          height: 1.3,
                        ),
                        children: [
                          TextSpan(
                            text: _fromUserName,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const TextSpan(text: ' accepted your follow request'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _date,
                      style: TextStyle(
                        fontSize: 12,
                        color: primaryColor.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
              // Checkmark icon
              Icon(
                CupertinoIcons.checkmark_circle_fill,
                color: AppTheme.successColor.withValues(alpha: 0.7),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tile for mutual follow notification - "You and X are now friends!"
class MutualFollowTile extends StatefulWidget {
  final Map<String, dynamic>? data;

  const MutualFollowTile({this.data, Key? key}) : super(key: key);

  @override
  _MutualFollowTileState createState() => _MutualFollowTileState();
}

class _MutualFollowTileState extends State<MutualFollowTile> {
  String _fromUserName = '';
  String _fromUserAvatar = '';
  String _fromUserId = '';
  String _date = '';
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      _fromUserId = widget.data?['fromUserId']?.toString() ?? '';
      _fromUserName = widget.data?['fromUserName']?.toString() ?? 'Someone';
      _fromUserAvatar = widget.data?['fromUserAvatar']?.toString() ?? '';

      if (widget.data?['timestamp'] is Timestamp) {
        _date = TimeDisplay.getCompactTimestamp(
            (widget.data!['timestamp'] as Timestamp).toDate());
      } else {
        _date = 'Recently';
      }

      if (_fromUserId.isNotEmpty) {
        try {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(_fromUserId)
              .get();
          if (userDoc.exists) {
            final data = userDoc.data();
            _fromUserName = data?['name']?.toString() ?? _fromUserName;
            _fromUserAvatar = data?['displayPicture']?.toString() ?? _fromUserAvatar;
          }
        } catch (_) {}
      }
    } catch (e) {
      AppLogger.e('Error fetching mutual follow notification data',
          category: LogCategory.general, data: {'error': e.toString()});
    } finally {
      if (mounted) {
        setState(() => _ready = true);
      }
    }
  }

  void _openProfile() {
    if (_fromUserId.isEmpty) return;
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) => UserProfilePage(uid: _fromUserId),
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
    final bool isRead = widget.data?['read'] == true;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _openProfile,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isRead ? Colors.transparent : AppTheme.honeyAmber.withValues(alpha: 0.08),
          ),
          child: Row(
            children: [
              // Avatar
              UserAvatar(
                userId: _fromUserId,
                imageUrl: _fromUserAvatar,
                size: 44,
                nameInitials: _fromUserName.isNotEmpty ? _fromUserName[0] : null,
              ),
              const SizedBox(width: 12),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        style: TextStyle(
                          fontSize: 14,
                          color: primaryColor,
                          height: 1.3,
                        ),
                        children: [
                          const TextSpan(
                            text: '🎉 You and ',
                            style: TextStyle(fontWeight: FontWeight.w400),
                          ),
                          TextSpan(
                            text: _fromUserName,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const TextSpan(text: ' are now friends!'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tap to see your compatibility',
                      style: TextStyle(
                        fontSize: 12,
                        color: primaryColor.withValues(alpha: 0.6),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _date,
                      style: TextStyle(
                        fontSize: 11,
                        color: primaryColor.withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                ),
              ),
              // Heart icon to indicate friendship/compatibility unlocked
              Icon(
                CupertinoIcons.heart_fill,
                color: AppTheme.honeyAmber,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
