import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:aurogram/pages/astrology/daily_insight_page.dart';
import 'package:aurogram/utils/time_display.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:aurogram/utils/logging/app_logger.dart';
import 'package:aurogram/widgets/notifications/unified_notification_card.dart';

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

  String get _cardType => widget.data?['cardType'] as String? ?? 'insight';
  String get _title => widget.data?['title'] as String? ?? 'Daily Insight';
  String get _preview => widget.data?['preview'] as String? ?? 'Your personalized astrology insight is ready.';
  String get _date => widget.data?['date'] as String? ?? '';
  int get _cardIndex => widget.data?['cardIndex'] as int? ?? 0;

  /// Get icon for insight cards
  /// Unified icon for all insight cards
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

    Navigator.of(context, rootNavigator: true).push(
      CupertinoPageRoute(
        builder: (context) => DailyInsightPage(
          uid: userId,
          highlightCardIndex: _cardIndex,
          insightDate: _date.isNotEmpty ? _date : null,
        ),
      ),
    );
  }

  Future<void> _markAsRead() async {
    if (_isRead) return;
    
    final userId = FirebaseAuth.instance.currentUser?.uid;
    final notificationId = widget.data?['id'] as String?;
    
    if (userId == null || notificationId == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('notifications')
          .doc(userId)
          .collection('notifications')
          .doc(notificationId)
          .update({'read': true});
      
      if (mounted) {
        setState(() => _isRead = true);
      }
    } catch (e) {
      AppLogger.e('Failed to mark notification as read',
          category: LogCategory.general, error: e);
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // Icon container
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _cardIcon,
                    size: 22,
                    color: AppTheme.primaryColor,
                  ),
                ),
                const SizedBox(width: 12),
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
                                fontSize: 15,
                                fontWeight: _isRead ? FontWeight.w600 : FontWeight.w700,
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
                      const SizedBox(height: 4),
                      Text(
                        _preview,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondaryColor,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _cardType.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primaryColor,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '•',
                            style: TextStyle(fontSize: 10, color: AppTheme.textSecondaryColor),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            widget.data?['timestamp'] != null
                                ? TimeDisplay.getCompactTimestamp(
                                    (widget.data!['timestamp'] as Timestamp).toDate())
                                : _date.isNotEmpty ? _date : 'Today',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondaryColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Arrow
                const SizedBox(width: 8),
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
