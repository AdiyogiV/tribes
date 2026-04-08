import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:aurogram/models/daily_insight.dart';
import 'package:aurogram/models/astrology_profile.dart';
import 'package:aurogram/services/share_service.dart';
import 'package:aurogram/utils/logging/app_logger.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:aurogram/utils/theme/app_dimensions.dart';
import 'package:aurogram/widgets/common/snack_bar_service.dart';

/// Inline reaction footer for insight cards (accurate, save, share).
class InsightReactionFooter extends StatefulWidget {
  final InsightSection section;
  final AstrologyProfile? profile;
  final bool isDark;
  final int cardIndex;
  final String insightDate;
  final String uid;

  const InsightReactionFooter({
    super.key,
    required this.section,
    required this.profile,
    required this.isDark,
    required this.cardIndex,
    required this.insightDate,
    required this.uid,
  });

  @override
  State<InsightReactionFooter> createState() => _InsightReactionFooterState();
}

class _InsightReactionFooterState extends State<InsightReactionFooter> {
  bool _isAccurate = false;
  bool _isSaved = false;

  @override
  Widget build(BuildContext context) {
    final brown = AppTheme.astroBrown(widget.isDark);

    // Format date nicely
    String formattedDate = '';
    try {
      final date = DateTime.parse(widget.insightDate);
      formattedDate =
          '${_getMonthName(date.month)} ${date.day}, ${date.year}';
    } catch (_) {
      formattedDate = widget.insightDate;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Date on top
        Text(
          formattedDate,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: brown.withValues(alpha: 0.4),
          ),
        ),
        const SizedBox(height: AppDimensions.spacingSm),

        // Action buttons row
        Row(
          children: [
            // Accurate button
            _buildReactionButton(
              icon: Icons.auto_awesome_outlined,
              label: 'Accurate',
              isSelected: _isAccurate,
              onTap: _handleAccurate,
              brown: brown,
            ),
            const SizedBox(width: AppDimensions.spacingSm),
            // Save button
            _buildReactionButton(
              icon: Icons.bookmark_outline,
              label: _isSaved ? 'Saved' : 'Save',
              isSelected: _isSaved,
              onTap: _handleSave,
              brown: brown,
            ),

            const Spacer(),

            // Share button
            _buildReactionButton(
              icon: Icons.share_outlined,
              label: 'Share',
              isSelected: false,
              onTap: () {
                HapticFeedback.lightImpact();
                ShareService.shareInsight(
                  context: context,
                  insightId:
                      'daily_${widget.insightDate}_${widget.section.cardType}',
                  cardType: widget.section.cardType,
                  title: widget.section.title,
                  content: widget.section.content,
                  userName: null,
                  moonSign: widget.profile?.moonSign,
                  risingSign: widget.profile?.ascendant,
                  sunSign: widget.profile?.sunSign,
                );
              },
              brown: brown,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildReactionButton({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required Color brown,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? brown.withValues(alpha: 0.12)
              : brown.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          border: isSelected
              ? Border.all(color: brown.withValues(alpha: 0.25), width: 1)
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? _getFilledIcon(icon) : icon,
              size: 14,
              color: isSelected ? brown : brown.withValues(alpha: 0.6),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? brown : brown.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getFilledIcon(IconData outlinedIcon) {
    if (outlinedIcon == Icons.auto_awesome_outlined) return Icons.auto_awesome;
    if (outlinedIcon == Icons.bookmark_outline) return Icons.bookmark;
    return outlinedIcon;
  }

  String _getMonthName(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[month - 1];
  }

  void _handleAccurate() {
    HapticFeedback.lightImpact();
    setState(() {
      _isAccurate = !_isAccurate;
    });

    AppLogger.d(
        'Insight marked accurate: card=${widget.cardIndex}, value=$_isAccurate',
        category: LogCategory.general);
  }

  Future<void> _handleSave() async {
    HapticFeedback.lightImpact();

    final wasSaved = _isSaved;

    setState(() {
      _isSaved = !wasSaved;
    });

    try {
      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(widget.uid)
          .collection('savedInsights')
          .doc('${widget.insightDate}_${widget.cardIndex}');

      if (!wasSaved) {
        await docRef.set({
          'title': widget.section.title,
          'content': widget.section.content,
          'cardType': widget.section.cardType,
          'scheduledFor': widget.section.scheduledFor,
          'insightDate': widget.insightDate,
          'savedAt': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          showCustomSnackBar(context, message: 'Insight saved', backgroundColor: AppTheme.astroBrown(
                  Theme.of(context).brightness == Brightness.dark), duration: const Duration(seconds: 2), behavior: SnackBarBehavior.floating);
        }
      } else {
        await docRef.delete();
      }

      AppLogger.d(
          'Insight save toggled: card=${widget.cardIndex}, saved=${!wasSaved}',
          category: LogCategory.general);
    } catch (e) {
      setState(() {
        _isSaved = wasSaved;
      });
      AppLogger.e('Failed to save insight', error: e);
    }
  }
}
