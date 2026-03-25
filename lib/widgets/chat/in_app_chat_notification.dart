import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:async';

/// Beautiful in-app chat notification banner (like WhatsApp/iMessage)
class InAppChatNotification extends StatefulWidget {
  final String title;
  final String body;
  final String? avatarUrl;
  final String? spaceId;
  final VoidCallback? onTap;
  final VoidCallback? onDismiss;

  const InAppChatNotification({
    super.key,
    required this.title,
    required this.body,
    this.avatarUrl,
    this.spaceId,
    this.onTap,
    this.onDismiss,
  });

  @override
  State<InAppChatNotification> createState() => _InAppChatNotificationState();
}

class _InAppChatNotificationState extends State<InAppChatNotification>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  Timer? _autoDismissTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    _controller.forward();

    // Auto-dismiss after 5 seconds
    _autoDismissTimer = Timer(const Duration(seconds: 5), () {
      dismiss();
    });
  }

  void dismiss() {
    _autoDismissTimer?.cancel();
    _controller.reverse().then((_) {
      widget.onDismiss?.call();
    });
  }

  @override
  void dispose() {
    _autoDismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Material(
          color: Colors.transparent,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () {
                dismiss();
                widget.onTap?.call();
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    // Avatar
                    Hero(
                      tag: 'notification_avatar_${widget.spaceId ?? ''}',
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.primaryColor.withValues(alpha: 0.1),
                        ),
                        child: widget.avatarUrl != null &&
                                widget.avatarUrl!.isNotEmpty
                            ? ClipOval(
                                child: CachedNetworkImage(
                                  imageUrl: widget.avatarUrl!,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Container(
                                    color: AppTheme.primaryColor
                                        .withValues(alpha: 0.1),
                                    child: Icon(
                                      CupertinoIcons.person_fill,
                                      color: AppTheme.primaryColor,
                                      size: 24,
                                    ),
                                  ),
                                  errorWidget: (context, url, error) =>
                                      Container(
                                    color: AppTheme.primaryColor
                                        .withValues(alpha: 0.1),
                                    child: Icon(
                                      CupertinoIcons.person_fill,
                                      color: AppTheme.primaryColor,
                                      size: 24,
                                    ),
                                  ),
                                ),
                              )
                            : Icon(
                                CupertinoIcons.chat_bubble_2_fill,
                                color: AppTheme.primaryColor,
                                size: 24,
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Title
                          Text(
                            widget.title,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textLightColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          // Body
                          Text(
                            widget.body,
                            style: TextStyle(
                              fontSize: 13,
                              color: AppTheme.textSecondaryLightColor,
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    // Dismiss button
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      onPressed: dismiss,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.grey[200],
                        ),
                        child: Icon(
                          CupertinoIcons.xmark,
                          size: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Overlay widget to show notifications at the top of the screen
class ChatNotificationOverlay extends StatefulWidget {
  final Widget child;

  const ChatNotificationOverlay({super.key, required this.child});

  @override
  State<ChatNotificationOverlay> createState() =>
      _ChatNotificationOverlayState();

  static _ChatNotificationOverlayState? of(BuildContext context) {
    return context.findAncestorStateOfType<_ChatNotificationOverlayState>();
  }
}

class _ChatNotificationOverlayState extends State<ChatNotificationOverlay> {
  final List<_NotificationItem> _notifications = [];
  OverlayEntry? _overlayEntry;

  void showNotification({
    required String title,
    required String body,
    String? avatarUrl,
    String? spaceId,
    VoidCallback? onTap,
  }) {
    final item = _NotificationItem(
      title: title,
      body: body,
      avatarUrl: avatarUrl,
      spaceId: spaceId,
      onTap: onTap,
    );

    setState(() {
      // Remove old notifications for the same space to prevent spam
      _notifications.removeWhere((n) => n.spaceId == spaceId);
      _notifications.add(item);
    });

    _updateOverlay();
  }

  void dismissNotification(String? spaceId) {
    setState(() {
      if (spaceId != null) {
        _notifications.removeWhere((n) => n.spaceId == spaceId);
      } else {
        _notifications.clear();
      }
    });
    _updateOverlay();
  }

  void _updateOverlay() {
    _overlayEntry?.remove();
    if (_notifications.isEmpty) {
      _overlayEntry = null;
      return;
    }

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 8,
        left: 0,
        right: 0,
        child: SafeArea(
          child: Column(
            children: _notifications.map((item) {
              return InAppChatNotification(
                key: ValueKey(item.spaceId ?? item.title),
                title: item.title,
                body: item.body,
                avatarUrl: item.avatarUrl,
                spaceId: item.spaceId,
                onTap: item.onTap,
                onDismiss: () => dismissNotification(item.spaceId),
              );
            }).toList(),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  @override
  void dispose() {
    _overlayEntry?.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

class _NotificationItem {
  final String title;
  final String body;
  final String? avatarUrl;
  final String? spaceId;
  final VoidCallback? onTap;

  _NotificationItem({
    required this.title,
    required this.body,
    this.avatarUrl,
    this.spaceId,
    this.onTap,
  });
}
