import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:aurogram/pages/tabs/user_profile.dart';
import 'package:aurogram/services/follow_service.dart';
import 'package:aurogram/utils/time_display.dart';
import 'package:aurogram/widgets/user_avatar.dart';
import 'package:aurogram/widgets/ui/skeleton_widgets.dart';
import 'package:aurogram/utils/logging/app_logger.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:aurogram/widgets/notifications/unified_notification_card.dart';

/// Tile for follow request notifications (type: followRequest)
/// Shows accept/decline buttons for private profile follow requests
class FollowRequestTile extends StatefulWidget {
  final Map<String, dynamic>? data;

  const FollowRequestTile({this.data, super.key});

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

    // Haptic feedback for action
    HapticFeedback.lightImpact();
    
    setState(() => _isProcessing = true);

    try {
      // Call backend function to accept the follow request
      // Backend has Admin SDK access to update the follower's document
      final callable = FirebaseFunctions.instanceFor(region: 'asia-southeast2')
          .httpsCallable('acceptFollowRequest');
      await callable.call({'followerId': _fromUserId});

      // Success haptic
      HapticFeedback.mediumImpact();
      
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
      HapticFeedback.heavyImpact();
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to accept request'),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  Future<void> _declineRequest() async {
    if (_isProcessing || _fromUserId.isEmpty) return;

    final currentUserId = _getCurrentUserId();
    if (currentUserId.isEmpty) return;

    // Haptic feedback for action
    HapticFeedback.lightImpact();
    
    setState(() => _isProcessing = true);

    try {
      // Call backend function to reject the follow request
      // Backend has Admin SDK access to delete the follower's document
      final callable = FirebaseFunctions.instanceFor(region: 'asia-southeast2')
          .httpsCallable('rejectFollowRequest');
      await callable.call({'followerId': _fromUserId});

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
      HapticFeedback.heavyImpact();
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to decline request'),
            backgroundColor: AppTheme.errorColor,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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

    return Container(
      decoration: notificationTileDecoration(isRead: isRead),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _openProfile,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          // Accept button
                          Expanded(
                            child: GestureDetector(
                              onTap: _isProcessing ? null : _acceptRequest,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: primaryColor,
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: [
                                    BoxShadow(
                                      color: primaryColor.withValues(alpha: 0.25),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: _isProcessing
                                      ? const SizedBox(
                                          height: 16,
                                          width: 16,
                                          child: CupertinoActivityIndicator(
                                            color: Colors.white,
                                          ),
                                        )
                                      : Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            const Icon(
                                              CupertinoIcons.checkmark_alt,
                                              size: 14,
                                              color: Colors.white,
                                            ),
                                            const SizedBox(width: 6),
                                            const Text(
                                              'Accept',
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.white,
                                                letterSpacing: -0.2,
                                              ),
                                            ),
                                          ],
                                        ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          // Decline button
                          Expanded(
                            child: GestureDetector(
                              onTap: _isProcessing ? null : _declineRequest,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: primaryColor.withValues(alpha: 0.25),
                                    width: 1.5,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    'Decline',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: primaryColor.withValues(alpha: 0.7),
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      const SizedBox(height: 10),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _isAccepted 
                              ? AppTheme.successColor.withValues(alpha: 0.1)
                              : primaryColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _isAccepted 
                                  ? CupertinoIcons.checkmark_circle_fill 
                                  : CupertinoIcons.xmark_circle_fill,
                              size: 14,
                              color: _isAccepted 
                                  ? AppTheme.successColor
                                  : primaryColor.withValues(alpha: 0.5),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _isAccepted ? 'Accepted' : 'Declined',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _isAccepted
                                    ? AppTheme.successColor
                                    : primaryColor.withValues(alpha: 0.5),
                              ),
                            ),
                          ],
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
    ),
    );
  }
}

/// Tile for follow notifications (type: follow)
/// Shows when someone starts following you (public profile)
/// Includes "Follow Back" button for quick action
class FollowTile extends StatefulWidget {
  final Map<String, dynamic>? data;

  const FollowTile({this.data, super.key});

  @override
  _FollowTileState createState() => _FollowTileState();
}

class _FollowTileState extends State<FollowTile> {
  final FollowService _followService = FollowService();
  String _fromUserName = '';
  String _fromUserAvatar = '';
  String _fromUserId = '';
  String _date = '';
  bool _ready = false;
  bool _isFollowingBack = false;
  bool _isFollowLoading = false;
  bool _isPrivateProfile = false;

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

      // Fetch latest user info and check follow status in parallel
      if (_fromUserId.isNotEmpty) {
        try {
          final results = await Future.wait([
            FirebaseFirestore.instance.collection('users').doc(_fromUserId).get(),
            _followService.isFollowing(_fromUserId),
          ]);
          
          final userDoc = results[0] as DocumentSnapshot;
          _isFollowingBack = results[1] as bool;
          
          if (userDoc.exists) {
            final data = userDoc.data() as Map<String, dynamic>?;
            _fromUserName = data?['name']?.toString() ?? _fromUserName;
            _fromUserAvatar = data?['displayPicture']?.toString() ?? _fromUserAvatar;
            _isPrivateProfile = data?['isPrivateProfile'] == true;
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

  Future<void> _followBack() async {
    if (_isFollowLoading || _fromUserId.isEmpty) return;
    
    // Haptic feedback
    HapticFeedback.lightImpact();
    
    setState(() => _isFollowLoading = true);
    
    try {
      // Use FollowService for consistency
      final success = await _followService.followUser(
        _fromUserId, 
        targetIsPrivate: _isPrivateProfile,
      );
      
      if (success) {
        HapticFeedback.mediumImpact();
        if (mounted) {
          setState(() {
            _isFollowingBack = true;
            _isFollowLoading = false;
          });
        }
      } else {
        throw Exception('Follow failed');
      }
    } catch (e) {
      AppLogger.e('Error following back', error: e);
      HapticFeedback.heavyImpact();
      if (mounted) {
        setState(() => _isFollowLoading = false);
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

    return Container(
      decoration: notificationTileDecoration(isRead: isRead),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _openProfile,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                UserAvatar(
                  userId: _fromUserId,
                  imageUrl: _fromUserAvatar,
                  size: 44,
                  nameInitials: _fromUserName.isNotEmpty ? _fromUserName[0] : null,
                ),
                const SizedBox(width: 12),
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
                const SizedBox(width: 8),
                _buildFollowBackButton(primaryColor),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFollowBackButton(Color primaryColor) {
    // Already following - show checkmark
    if (_isFollowingBack) {
      return AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: primaryColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              CupertinoIcons.checkmark_alt,
              size: 12,
              color: primaryColor.withValues(alpha: 0.7),
            ),
            const SizedBox(width: 5),
            Text(
              'Following',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: primaryColor.withValues(alpha: 0.7),
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      );
    }
    
    // Loading state
    if (_isFollowLoading) {
      return Container(
        width: 88,
        height: 34,
        decoration: BoxDecoration(
          color: primaryColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Center(
          child: SizedBox(
            width: 14,
            height: 14,
            child: CupertinoActivityIndicator(color: primaryColor),
          ),
        ),
      );
    }
    
    // Follow Back button
    return GestureDetector(
      onTap: _followBack,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: primaryColor,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: primaryColor.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Text(
          'Follow Back',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.white,
            letterSpacing: -0.2,
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

  const FollowAcceptedTile({this.data, super.key});

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
    HapticFeedback.selectionClick();
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

    return Container(
      decoration: notificationTileDecoration(isRead: isRead),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _openProfile,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
            children: [
              // Avatar with success indicator
              Stack(
                children: [
                  UserAvatar(
                    userId: _fromUserId,
                    imageUrl: _fromUserAvatar,
                    size: 46,
                    nameInitials: _fromUserName.isNotEmpty ? _fromUserName[0] : null,
                  ),
                  // Success badge
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: AppTheme.scaffoldLightColor,
                        shape: BoxShape.circle,
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: AppTheme.successColor,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          CupertinoIcons.checkmark,
                          size: 10,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),
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
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const TextSpan(
                            text: ' accepted your follow request',
                            style: TextStyle(fontWeight: FontWeight.w400),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _date,
                      style: TextStyle(
                        fontSize: 12,
                        color: primaryColor.withValues(alpha: 0.45),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                CupertinoIcons.chevron_right,
                color: primaryColor.withValues(alpha: 0.3),
                size: 16,
              ),
            ],
          ),
        ),
      ),
    ),
    );
  }
}

/// Tile for mutual follow notification - "You and X are now friends!"
/// Special celebration design to highlight this special moment
class MutualFollowTile extends StatefulWidget {
  final Map<String, dynamic>? data;

  const MutualFollowTile({this.data, super.key});

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
    HapticFeedback.selectionClick();
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

    return Container(
      decoration: notificationTileDecoration(isRead: isRead),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _openProfile,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
            children: [
              // Avatar with glow effect
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: isRead ? null : [
                    BoxShadow(
                      color: AppTheme.honeyAmber.withValues(alpha: 0.3),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: UserAvatar(
                  userId: _fromUserId,
                  imageUrl: _fromUserAvatar,
                  size: 48,
                  nameInitials: _fromUserName.isNotEmpty ? _fromUserName[0] : null,
                ),
              ),
              const SizedBox(width: 14),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: RichText(
                            text: TextSpan(
                              style: TextStyle(
                                fontSize: 14,
                                color: primaryColor,
                                height: 1.3,
                              ),
                              children: [
                                const TextSpan(
                                  text: '🎉 ',
                                  style: TextStyle(fontSize: 15),
                                ),
                                const TextSpan(
                                  text: 'You and ',
                                  style: TextStyle(fontWeight: FontWeight.w400),
                                ),
                                TextSpan(
                                  text: _fromUserName,
                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                ),
                                const TextSpan(
                                  text: ' are now friends!',
                                  style: TextStyle(fontWeight: FontWeight.w400),
                                ),
                              ],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // CTA hint
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.honeyAmber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            CupertinoIcons.sparkles,
                            size: 11,
                            color: AppTheme.honeyAmber,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Check compatibility',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.honeyAmber,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
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
              const SizedBox(width: 8),
              // Heart icon with container
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.honeyAmber.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  CupertinoIcons.heart_fill,
                  color: AppTheme.honeyAmber,
                  size: 18,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    );
  }
}
