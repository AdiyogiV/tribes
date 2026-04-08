import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:aurogram/features/notifications/presentation/widgets/added_to_gram_tile.dart';
import 'package:aurogram/features/notifications/presentation/widgets/daily_insight_tile.dart';
import 'package:aurogram/features/notifications/presentation/widgets/group_call_tile.dart';
import 'package:aurogram/features/notifications/presentation/widgets/missed_call_tile.dart';
import 'package:aurogram/features/notifications/presentation/widgets/anonymous_message_tile.dart';
import 'package:aurogram/features/notifications/presentation/widgets/like_tile.dart';
import 'package:aurogram/features/notifications/presentation/widgets/new_post_tile.dart';
import 'package:aurogram/features/notifications/presentation/widgets/follow_request_tile.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:aurogram/features/notifications/presentation/widgets/invite_tile.dart';
import 'package:aurogram/features/notifications/presentation/widgets/namaste_tile.dart';
import 'package:aurogram/features/notifications/presentation/widgets/reply_tile.dart';
import 'package:aurogram/features/notifications/presentation/widgets/request_tile.dart';
import 'package:aurogram/shared/presentation/widgets/loaders/skeleton_widgets.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/core/logging/app_logger.dart';
import 'package:aurogram/core/theme/header_style.dart';
import 'package:aurogram/shared/presentation/responsive/responsive.dart';
import 'package:aurogram/models/notification.dart';
import 'package:aurogram/features/notifications/domain/notification_service.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';
import 'package:aurogram/shared/presentation/widgets/feedback/snack_bar_service.dart';

/// Filter options for notifications (simplified: All + Unread only)
enum NotificationFilter {
  all,
  unread,
}

extension NotificationFilterExtension on NotificationFilter {
  String get displayName {
    switch (this) {
      case NotificationFilter.all:
        return 'All';
      case NotificationFilter.unread:
        return 'Unread';
    }
  }

  IconData get icon {
    switch (this) {
      case NotificationFilter.all:
        return CupertinoIcons.bell;
      case NotificationFilter.unread:
        return CupertinoIcons.circle_fill;
    }
  }
}

class Notifications extends StatefulWidget {
  const Notifications({super.key});

  @override
  NotificationsState createState() => NotificationsState();
}

class NotificationsState extends State<Notifications> {
  final CollectionReference _notificationsCollection =
      FirebaseFirestore.instance.collection('notifications');
  final NotificationService _notificationService = NotificationService();
  final ScrollController _scrollController = ScrollController();
  
  User? user = FirebaseAuth.instance.currentUser;
  
  // Pagination
  static const int _pageSize = 20;
  bool _hasMore = true;
  bool _isLoading = false;
  bool _isRefreshing = false;
  DocumentSnapshot? _lastDocument;
  
  // Data
  List<AppNotification> _notifications = [];
  
  // Filters
  NotificationFilter _currentFilter = NotificationFilter.all;
  
  // Unread count
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadNotifications();
    _listenToUnreadCount();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent - 200) {
      _loadMoreNotifications();
    }
  }

  void _listenToUnreadCount() {
    if (user == null) return;
    
    _notificationsCollection
        .doc(user!.uid)
        .collection('notifications')
        .where('read', isEqualTo: false)
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          _unreadCount = snapshot.docs.length;
        });
      }
    });
  }

  Future<void> _loadNotifications({bool isRefresh = false}) async {
    if (_isLoading) return;
    if (user == null) return;

    if (isRefresh) {
      setState(() {
        _isRefreshing = true;
        _lastDocument = null;
        _notifications = [];
        _hasMore = true;
      });
      // Yield a frame so shimmer appears before work starts
      await Future.delayed(Duration.zero);
    } else {
      setState(() => _isLoading = true);
    }

    try {
      Query query = _notificationsCollection
          .doc(user!.uid)
          .collection('notifications')
          .orderBy('timestamp', descending: true)
          .limit(_pageSize);

      // Apply filter
      query = _applyFilter(query);

      final snapshot = await query.get();

      if (snapshot.docs.isEmpty) {
        setState(() {
          _hasMore = false;
          _isLoading = false;
          _isRefreshing = false;
        });
        return;
      }

      final rawNotifications = snapshot.docs
          .map((doc) => AppNotification.fromFirestore(doc))
          .toList();
      
      // Apply client-side filtering (e.g., exclude astro from "All")
      final newNotifications = _filterNotificationsClientSide(rawNotifications);

      setState(() {
        _notifications = newNotifications;
        _lastDocument = snapshot.docs.last;
        _hasMore = snapshot.docs.length >= _pageSize;
        _isLoading = false;
        _isRefreshing = false;
      });
    } catch (e) {
      AppLogger.e('Error loading notifications',
          category: LogCategory.general, error: e);
      setState(() {
        _isLoading = false;
        _isRefreshing = false;
      });
    }
  }

  Future<void> _loadMoreNotifications() async {
    if (_isLoading || !_hasMore || _lastDocument == null) return;
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      Query query = _notificationsCollection
          .doc(user!.uid)
          .collection('notifications')
          .orderBy('timestamp', descending: true)
          .startAfterDocument(_lastDocument!)
          .limit(_pageSize);

      // Apply filter
      query = _applyFilter(query);

      final snapshot = await query.get();

      if (snapshot.docs.isEmpty) {
        setState(() {
          _hasMore = false;
          _isLoading = false;
        });
        return;
      }

      final rawNotifications = snapshot.docs
          .map((doc) => AppNotification.fromFirestore(doc))
          .toList();
      
      // Apply client-side filtering (e.g., exclude astro from "All")
      final newNotifications = _filterNotificationsClientSide(rawNotifications);

      setState(() {
        _notifications.addAll(newNotifications);
        _lastDocument = snapshot.docs.last;
        _hasMore = snapshot.docs.length >= _pageSize;
        _isLoading = false;
      });
    } catch (e) {
      AppLogger.e('Error loading more notifications',
          category: LogCategory.general, error: e);
      setState(() => _isLoading = false);
    }
  }

  Query _applyFilter(Query query) {
    switch (_currentFilter) {
      case NotificationFilter.unread:
        return query.where('read', isEqualTo: false);
      case NotificationFilter.all:
        return query;
    }
  }

  /// Filter notifications for Alerts list: exclude astro from "All"; never show chat/message (Messages tab + push only)
  List<AppNotification> _filterNotificationsClientSide(List<AppNotification> notifications) {
    var list = notifications;
    // Alerts list does not show chat/message (handled in Messages tab + push only)
    list = list.where((n) =>
        n.type != NotificationType.chat && n.type != NotificationType.message).toList();
    if (_currentFilter == NotificationFilter.all) {
      list = list.where((n) => n.type != NotificationType.dailyAstroInsight).toList();
    }
    return list;
  }

  void _onFilterChanged(NotificationFilter filter) {
    if (_currentFilter == filter) return;
    
    setState(() {
      _currentFilter = filter;
    });
    _loadNotifications(isRefresh: true);
  }

  Future<void> _handleRefresh() async {
    await _loadNotifications(isRefresh: true);
  }

  Future<void> _markAllAsRead() async {
    try {
      await _notificationService.markAllAsRead();
      
      // Update local state
      setState(() {
        _notifications = _notifications.map((n) => n.copyWith(read: true)).toList();
      });
      
      if (mounted) {
        showCustomSnackBar(context, message: 'All notifications marked as read', backgroundColor: AppTheme.primaryColor, duration: const Duration(seconds: 2), behavior: SnackBarBehavior.floating);
      }
    } catch (e) {
      AppLogger.e('Failed to mark all as read', category: LogCategory.general, error: e);
    }
  }

  Widget _buildNotificationTile(AppNotification notification) {
    final data = notification.data;
    data['id'] = notification.id;

    switch (notification.type) {
      case NotificationType.reply:
        return ReplyTile(data: data, key: ValueKey(notification.id));
      case NotificationType.namaste:
        return NamasteTile(data: data, key: ValueKey(notification.id));
      case NotificationType.invite:
        return InviteTile(data: data, key: ValueKey(notification.id));
      case NotificationType.request:
        return RequestTile(data: data, key: ValueKey(notification.id));
      case NotificationType.like:
        return LikeTile(data: data, key: ValueKey(notification.id));
      case NotificationType.newSpacePost:
        return NewPostTile(data: data, key: ValueKey(notification.id));
      case NotificationType.addedToGroup:
        return AddedToGramTile(data: data, key: ValueKey(notification.id));
      case NotificationType.dailyAstroInsight:
        return DailyInsightTile(data: data, key: ValueKey(notification.id));
      case NotificationType.follow:
        return FollowTile(data: data, key: ValueKey(notification.id));
      case NotificationType.followRequest:
        return FollowRequestTile(data: data, key: ValueKey(notification.id));
      case NotificationType.followAccepted:
        return FollowAcceptedTile(data: data, key: ValueKey(notification.id));
      case NotificationType.mutualFollow:
        return MutualFollowTile(data: data, key: ValueKey(notification.id));
      case NotificationType.missedCall:
        return MissedCallTile(data: data, key: ValueKey(notification.id));
      case NotificationType.groupCall:
        return GroupCallTile(data: data, key: ValueKey(notification.id));
      case NotificationType.anonymousMessage:
        return AnonymousMessageTile(data: data, key: ValueKey(notification.id));
      case NotificationType.chat:
      case NotificationType.message:
        // Filtered out from Alerts; fallback if any legacy doc appears
        return _buildUnknownNotificationTile(notification);
      case NotificationType.unknown:
      default:
        // Generic fallback tile
        return _buildUnknownNotificationTile(notification);
    }
  }

  Widget _buildUnknownNotificationTile(AppNotification notification) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: AppDimensions.paddingXs, horizontal: AppDimensions.paddingLg),
      padding: const EdgeInsets.all(AppDimensions.paddingLg),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.15), width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              CupertinoIcons.bell_fill,
              color: AppTheme.primaryColor.withValues(alpha: 0.7),
              size: 20,
            ),
          ),
          const SizedBox(width: AppDimensions.spacingMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notification.displayTitle,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textColor,
                  ),
                ),
                const SizedBox(height: AppDimensions.spacingXs),
                Text(
                  notification.displayBody,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondaryColor,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return Container(
      height: 44,
      margin: const EdgeInsets.only(bottom: AppDimensions.paddingSm),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingLg),
        itemCount: NotificationFilter.values.length,
        itemBuilder: (context, index) {
          final filter = NotificationFilter.values[index];
          final isSelected = _currentFilter == filter;
          final surfaceColor = AppTheme.surfaceColor;
          final textColor = AppTheme.textColor;
          final secondaryColor = AppTheme.textSecondaryColor;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              selected: isSelected,
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    filter.icon,
                    size: 14,
                    color: isSelected ? AppTheme.primaryColor.withValues(alpha: 0.9) : secondaryColor,
                  ),
                  const SizedBox(width: AppDimensions.spacingSmMd),
                  Text(filter.displayName),
                  if (filter == NotificationFilter.unread && _unreadCount > 0) ...[
                    const SizedBox(width: AppDimensions.spacingSmMd),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isSelected ? AppTheme.primaryColor.withValues(alpha: 0.25) : AppTheme.primaryColor,
                        borderRadius: BorderRadius.circular(AppDimensions.radiusMdSm),
                      ),
                      child: Text(
                        _unreadCount > 99 ? '99+' : _unreadCount.toString(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? AppTheme.primaryColor : Colors.white,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              labelStyle: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isSelected ? AppTheme.primaryColor : textColor,
              ),
              backgroundColor: surfaceColor,
              selectedColor: AppTheme.primaryColor.withValues(alpha: 0.15),
              checkmarkColor: AppTheme.primaryColor,
              showCheckmark: false,
              padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingMd),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
              ),
              side: BorderSide(
                color: isSelected ? AppTheme.primaryColor : AppTheme.primaryColor.withValues(alpha: 0.2),
                width: 0.5,
              ),
              onSelected: (_) => _onFilterChanged(filter),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    final String message;
    final IconData icon;
    switch (_currentFilter) {
      case NotificationFilter.unread:
        message = 'All caught up! 🎉\nNo unread notifications.';
        icon = CupertinoIcons.checkmark_circle;
        break;
      default:
        message = 'No notifications yet.\nYour activity will appear here!';
        icon = CupertinoIcons.bell;
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 36,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: AppDimensions.spacingXl),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: AppTheme.textSecondaryColor,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldColor,
      // Full-width scroll view so scrollbar appears at viewport edge
      // Use LayoutBuilder to get actual available width (accounts for sidebar)
      body: LayoutBuilder(
        builder: (context, constraints) {
          final contentPadding = Responsive.horizontalPaddingFor(constraints.maxWidth, 600);
          return CustomScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              // Header handles its own centering
              _buildSliverAppBar(),
              // Pull to refresh - hidden indicator, title shimmers instead
              CupertinoSliverRefreshControl(
                onRefresh: _handleRefresh,
                builder: (context, refreshState, pulledExtent, refreshTriggerPullDistance, refreshIndicatorExtent) {
                  return const SizedBox.shrink();
                },
              ),
              
              // Filter chips with responsive padding
              SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: contentPadding),
                sliver: SliverToBoxAdapter(
                  child: _buildFilterChips(),
                ),
              ),
              
              // Notification list with responsive padding - show skeletons during refresh for visual feedback
              if (_isRefreshing)
                // Show skeletons during refresh
                SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: contentPadding),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      children: List.generate(6, (_) => SkeletonNotification()),
                    ),
                  ),
                )
              else if (_notifications.isEmpty && !_isLoading)
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: MediaQuery.of(context).size.height - 200,
                    child: _buildEmptyState(),
                  ),
                )
              else if (_notifications.isEmpty && _isLoading)
                // Initial loading skeleton - instant display
                SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: contentPadding),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      children: List.generate(6, (_) => SkeletonNotification()),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: contentPadding),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        if (index < _notifications.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 4, bottom: 4),
                            child: _buildNotificationTile(_notifications[index]),
                          );
                        }
                        
                        // Loading indicator at the bottom
                        if (_hasMore) {
                          return _isLoading
                              ? const PaginationLoader()
                              : const SizedBox(height: AppDimensions.spacingHero); // Placeholder for next load trigger
                        }
                        
                        // Fallback - should not reach here with correct childCount
                        return const SizedBox.shrink();
                      },
                      childCount: _notifications.length + (_hasMore ? 1 : 0),
                    ),
                  ),
                ),
              
              // Bottom padding
              const SliverToBoxAdapter(
                child: SizedBox(height: 100),
              ),
            ],
          );
        },
      ),
    );
  }

  SliverAppBar _buildSliverAppBar() {
    return AppHeaderStyle.buildStandardHeader(
      context: context,
      title: 'alerts',
      actionButton: _unreadCount > 0
          ? AppHeaderStyle.buildCompactIconButton(
              icon: CupertinoIcons.checkmark_circle,
              tooltip: 'Mark all as read',
              onPressed: _markAllAsRead,
            )
          : null,
      leadingWidget: const SizedBox.shrink(),
      showSearchField: false,
      isRefreshing: _isRefreshing,
    );
  }
}




