import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:aurogram/core/routing/route_names.dart';
import 'package:aurogram/features/chat/domain/space_chat_service.dart';
import 'package:aurogram/features/feed/data/datasources/space_db_service.dart';
import 'package:aurogram/core/di/injection.dart';
import 'package:aurogram/shared/data/repositories/user_repository.dart';
import 'package:aurogram/features/profile/domain/user_service.dart';
import 'package:aurogram/shared/data/repositories/notification_repository.dart';
import 'package:aurogram/shared/utils/time_display.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/core/logging/app_logger.dart';
import 'package:aurogram/features/notifications/presentation/widgets/unified_notification_card.dart';
import 'package:aurogram/shared/presentation/widgets/avatars/user_avatar.dart';
import 'package:aurogram/shared/presentation/widgets/loaders/skeleton_widgets.dart';
import 'package:aurogram/shared/presentation/widgets/feedback/snack_bar_service.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';

class ChatMessageTile extends StatefulWidget {
  final Map<String, dynamic>? data;

  const ChatMessageTile({this.data, super.key});

  @override
  State<ChatMessageTile> createState() => _ChatMessageTileState();
}

class _ChatMessageTileState extends State<ChatMessageTile> {
  final SpaceDbService _spaceDbService = SpaceDbService();

  String _senderName = 'Someone';
  String _senderId = '';
  String _senderAvatar = '';
  String _spaceName = 'Chat';
  String _spaceId = '';
  String _messageContent = '';
  String _messageType = 'text';
  String _date = '';
  bool _isReady = false;
  bool _isRead = false;
  bool _isDM = false;

  @override
  void initState() {
    super.initState();
    _isRead = widget.data?['read'] == true;
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      // Extract basic data from notification
      _spaceId = widget.data?['spaceId'] as String? ??
          widget.data?['space'] as String? ??
          '';
      _senderId = widget.data?['senderId'] as String? ?? '';
      _senderName = widget.data?['senderName'] as String? ?? 'Someone';
      _senderAvatar = widget.data?['senderAvatar'] as String? ?? '';
      _messageContent = widget.data?['messageContent'] as String? ??
          widget.data?['content'] as String? ??
          '';
      _messageType = widget.data?['messageType'] as String? ?? 'text';

      // Determine if DM
      final chatService = SpaceChatService();
      _isDM = _spaceId.isNotEmpty && chatService.isDirectMessage(_spaceId);

      // Get space/conversation name
      if (_spaceId.isNotEmpty) {
        if (_isDM) {
          _spaceName = _senderName;
        } else {
          try {
            final space = await _spaceDbService
                .getSpace(_spaceId)
                .timeout(const Duration(seconds: 5));
            _spaceName = space.name ?? 'Chat';
          } catch (e) {
            _spaceName = widget.data?['spaceName'] as String? ?? 'Chat';
          }
        }
      }

      // Get sender info if not already available
      if (_senderId.isNotEmpty &&
          (_senderName == 'Someone' || _senderAvatar.isEmpty)) {
        try {
          final userService = locator<UserService>();
          _senderName = await userService.getUserDisplayName(_senderId);

          // Get avatar separately
          final userDoc = await locator<UserRepository>()
              .getUser(_senderId)
              .timeout(const Duration(seconds: 5));
          if (userDoc.exists) {
            _senderAvatar = userDoc.get('displayPicture')?.toString() ?? '';
          }
        } catch (e) {
          // Keep default values - getUserDisplayName already handles deleted users correctly
          // Don't override with "Deleted User" on errors
          if (_senderName == 'Someone') {
            _senderName = 'Someone';
          }
        }
      }

      // Get timestamp
      if (widget.data?['timestamp'] != null) {
        try {
          _date = TimeDisplay.getCompactTimestamp(
              (widget.data!['timestamp'] as Timestamp).toDate());
        } catch (e) {
          _date = 'Recently';
        }
      } else if (widget.data?['createdAt'] != null) {
        try {
          _date = TimeDisplay.getCompactTimestamp(
              (widget.data!['createdAt'] as Timestamp).toDate());
        } catch (e) {
          _date = 'Recently';
        }
      }

      _isReady = true;
      if (mounted) setState(() {});
    } catch (e) {
      AppLogger.e('Error fetching chat notification data',
          category: LogCategory.general, error: e);
      _isReady = true;
      if (mounted) setState(() {});
    }
  }

  String get _displayMessage {
    switch (_messageType) {
      case 'image':
        return '📷 Photo';
      case 'video':
        return '🎬 Video';
      case 'audio':
        return '🎵 Audio message';
      case 'file':
        return '📎 File';
      default:
        if (_messageContent.length > 60) {
          return '${_messageContent.substring(0, 60)}...';
        }
        return _messageContent;
    }
  }

  void _navigateToChat() {
    if (_spaceId.isEmpty) {
      showCustomSnackBar(context, message: 'Unable to open chat', duration: const Duration(seconds: 2), backgroundColor: AppTheme.errorColor);
      return;
    }

    // Mark as read
    _markAsRead();

    final chatService = SpaceChatService();
    String? otherUserId;

    if (_isDM) {
      otherUserId = chatService.getOtherUserId(_spaceId);
    }

    context.push(
      '${RouteNames.spaceChatScreen}/$_spaceId',
      extra: {'space': null, 'otherUserId': otherUserId},
    );
  }

  Future<void> _markAsRead() async {
    if (_isRead) return;

    final userId = FirebaseAuth.instance.currentUser?.uid;
    final notificationId = widget.data?['id'] as String?;

    if (userId == null || notificationId == null) return;

    await locator<NotificationRepository>().markAsRead(userId, notificationId);
    if (mounted) {
      setState(() => _isRead = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isReady) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppDimensions.paddingXs, horizontal: AppDimensions.paddingLg),
        child: SkeletonListItem(height: 80),
      );
    }

    return Container(
      decoration: notificationTileDecoration(isRead: _isRead),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _navigateToChat,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingLg, vertical: AppDimensions.paddingMd),
            child: Row(
              children: [
                // Avatar
                Stack(
                  children: [
                    UserAvatar(
                      userId: _senderId,
                      imageUrl: _senderAvatar,
                      size: 48,
                      nameInitials: _senderName.isNotEmpty
                          ? _senderName.substring(0, 1)
                          : null,
                    ),
                    // Chat badge
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppTheme.cardColor, width: 2),
                        ),
                        child: const Icon(
                          CupertinoIcons.chat_bubble_fill,
                          size: 10,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: AppDimensions.spacingMd),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _isDM ? _senderName : _spaceName,
                              style: TextStyle(
                                fontSize: AppTheme.holyCowTextSize,
                                fontWeight:
                                    _isRead ? FontWeight.w600 : FontWeight.w700,
                                color: AppTheme.textColor,
                                height: 1.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (!_isRead)
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(left: 8),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: AppDimensions.spacingXs),
                      Text(
                        _isDM
                            ? _displayMessage
                            : '$_senderName: $_displayMessage',
                        style: TextStyle(
                          fontSize: AppTheme.holyCowTextSize,
                          color: _isRead ? AppTheme.textSecondaryColor : AppTheme.textColor,
                          fontWeight:
                              _isRead ? FontWeight.normal : FontWeight.w500,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppDimensions.spacingXs),
                      Row(
                        children: [
                          Icon(
                            _isDM
                                ? CupertinoIcons.person
                                : CupertinoIcons.person_3,
                            size: 12,
                            color: AppTheme.textSecondaryColor,
                          ),
                          const SizedBox(width: AppDimensions.spacingXs),
                          Text(
                            _isDM ? 'Direct Message' : 'Gram Chat',
                            style: TextStyle(
                              fontSize: AppTheme.holyCowTextSize,
                              color: AppTheme.textSecondaryColor,
                            ),
                          ),
                          const SizedBox(width: AppDimensions.spacingSm),
                          Text(
                            '•',
                            style: TextStyle(
                              fontSize: AppTheme.holyCowTextSize,
                              color: AppTheme.textSecondaryColor,
                            ),
                          ),
                          const SizedBox(width: AppDimensions.spacingSm),
                          Text(
                            _date,
                            style: TextStyle(
                              fontSize: AppTheme.holyCowTextSize,
                              color: AppTheme.textSecondaryColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Arrow
                const SizedBox(width: AppDimensions.spacingSm),
                Icon(
                  CupertinoIcons.chevron_right,
                  size: 16,
                  color: AppTheme.textSecondaryColor,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
