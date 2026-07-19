import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:aurogram/core/di/injection.dart';
import 'package:aurogram/shared/data/repositories/notification_repository.dart';
import 'package:go_router/go_router.dart';
import 'package:aurogram/core/routing/route_names.dart';
import 'package:aurogram/shared/utils/time_display.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/core/logging/app_logger.dart';
import 'package:aurogram/features/notifications/presentation/widgets/unified_notification_card.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';

class DailyInsightTile extends StatefulWidget {
  final Map<String, dynamic>? data;

  const DailyInsightTile({this.data, super.key});

  @override
  State<DailyInsightTile> createState() => _DailyInsightTileState();
}

class _DailyInsightTileState extends State<DailyInsightTile> {
  bool _isRead = false;

  @override
  void initState() {
    super.initState();
    _isRead = widget.data?['read'] == true;
  }

  String get _title => widget.data?['title'] as String? ?? "Today's Energy";
  String get _preview =>
      widget.data?['preview'] as String? ??
      "Your daily energy reading is ready.";
  String get _date => widget.data?['date'] as String? ?? '';

  /// Unified icon for the daily energy notification.
  IconData get _cardIcon {
    return Icons.nights_stay_outlined;
  }

  void _navigateToInsight() {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      AppLogger.w('Cannot navigate to insight: user not authenticated',
          category: LogCategory.navigation);
      return;
    }

    _markAsRead();

    context.push(
      RouteNames.dailyInsight,
      extra: {
        'uid': userId,
        'insightDate': _date.isNotEmpty ? _date : null,
      },
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
    return Container(
      decoration: notificationTileDecoration(isRead: _isRead),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _navigateToInsight,
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.paddingLg,
                vertical: AppDimensions.paddingMd),
            child: Row(
              children: [
                // Icon container
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                  ),
                  child: Icon(
                    _cardIcon,
                    size: 22,
                    color: AppTheme.primaryColor,
                  ),
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
                              _title,
                              style: TextStyle(
                                fontSize: AppTheme.babaTextSize,
                                fontWeight:
                                    _isRead ? FontWeight.w600 : FontWeight.w700,
                                color: AppTheme.textColor,
                                height: 1.3,
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
                        _preview,
                        style: TextStyle(
                          fontSize: AppTheme.babaTextSize,
                          color: AppTheme.textSecondaryColor,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppDimensions.spacingSmMd),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color:
                                  AppTheme.primaryColor.withValues(alpha: 0.1),
                              borderRadius:
                                  BorderRadius.circular(AppDimensions.radiusXs),
                            ),
                            child: Text(
                              'ENERGY',
                              style: TextStyle(
                                fontSize: AppTheme.babaTextSize,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primaryColor,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppDimensions.spacingSm),
                          Text(
                            '•',
                            style: TextStyle(
                                fontSize: AppTheme.babaTextSize,
                                color: AppTheme.textSecondaryColor),
                          ),
                          const SizedBox(width: AppDimensions.spacingSm),
                          Text(
                            widget.data?['timestamp'] != null
                                ? TimeDisplay.getCompactTimestamp(
                                    (widget.data!['timestamp'] as Timestamp)
                                        .toDate())
                                : _date.isNotEmpty
                                    ? _date
                                    : 'Today',
                            style: TextStyle(
                              fontSize: AppTheme.babaTextSize,
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
