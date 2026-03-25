import 'package:flutter/material.dart';
import 'package:aurogram/models/daily_insight.dart';
import 'package:aurogram/services/astrology_service.dart';
import 'package:aurogram/utils/theme/app_theme.dart';

class DailyInsightCard extends StatefulWidget {
  final DailyInsight? insight;
  final VoidCallback? onTap;
  final bool showDate;
  final bool showActions;

  const DailyInsightCard({
    super.key,
    this.insight,
    this.onTap,
    this.showDate = true,
    this.showActions = true,
  });

  @override
  State<DailyInsightCard> createState() => _DailyInsightCardState();
}

class _DailyInsightCardState extends State<DailyInsightCard> {
  final AstrologyService _astrologyService = AstrologyService();
  bool _isFavorite = false;
  bool _isLoadingFavorite = false;
  bool _hasReacted = false;
  String? _reaction;

  @override
  void initState() {
    super.initState();
    _loadFavoriteStatus();
  }

  @override
  void didUpdateWidget(DailyInsightCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.insight?.dateString != widget.insight?.dateString) {
      _loadFavoriteStatus();
    }
  }

  Future<void> _loadFavoriteStatus() async {
    if (widget.insight?.dateString == null) return;
    final isFavorite =
        await _astrologyService.isInsightFavorite(widget.insight!.dateString);
    if (mounted) {
      setState(() => _isFavorite = isFavorite);
    }
  }

  Future<void> _toggleFavorite() async {
    if (widget.insight?.dateString == null || _isLoadingFavorite) return;

    setState(() => _isLoadingFavorite = true);
    final newStatus = await _astrologyService.toggleFavoriteInsight(
      widget.insight!.dateString,
      date: widget.insight!.dateString,
    );

    if (mounted) {
      setState(() {
        _isFavorite = newStatus ?? !_isFavorite;
        _isLoadingFavorite = false;
      });
    }
  }

  Future<void> _submitReaction(String feedback) async {
    if (widget.insight?.dateString == null || _hasReacted) return;

    final success = await _astrologyService.submitInsightFeedback(
      widget.insight!.dateString,
      date: widget.insight!.dateString,
      feedback: feedback,
    );

    if (mounted && success) {
      setState(() {
        _hasReacted = true;
        _reaction = feedback;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final brownColor = AppTheme.astroBrown(isDark);

    if (widget.insight == null) {
      return _buildEmptyCard(isDark, brownColor);
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.grey.withValues(alpha: 0.15),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header - theme or default title
          Text(
            widget.insight!.displayTheme.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: brownColor,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 12),
          // Insight text - full text, no cutting (uses displayMessage for v3+ compatibility)
          Text(
            widget.insight!.displayMessage,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              height: 1.5,
              color: brownColor.withValues(alpha: 0.9),
            ),
          ),
          // Action buttons
          if (widget.showActions) ...[
            const SizedBox(height: 14),
            Container(
              height: 1,
              color: brownColor.withValues(alpha: 0.15),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                // Reaction buttons
                _buildActionButton(
                  icon: _reaction == 'thumbs_up'
                      ? Icons.thumb_up
                      : Icons.thumb_up_outlined,
                  isActive: _reaction == 'thumbs_up',
                  onTap: _hasReacted ? null : () => _submitReaction('thumbs_up'),
                  brownColor: brownColor,
                  isDark: isDark,
                ),
                const SizedBox(width: 16),
                _buildActionButton(
                  icon: _reaction == 'thumbs_down'
                      ? Icons.thumb_down
                      : Icons.thumb_down_outlined,
                  isActive: _reaction == 'thumbs_down',
                  onTap: _hasReacted ? null : () => _submitReaction('thumbs_down'),
                  brownColor: brownColor,
                  isDark: isDark,
                  isNegative: true,
                ),
                const Spacer(),
                // Bookmark button
                _buildActionButton(
                  icon: _isFavorite ? Icons.bookmark : Icons.bookmark_border,
                  isActive: _isFavorite,
                  onTap: _isLoadingFavorite ? null : _toggleFavorite,
                  brownColor: brownColor,
                  isDark: isDark,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required bool isActive,
    required VoidCallback? onTap,
    required Color brownColor,
    required bool isDark,
    bool isNegative = false,
  }) {
    final activeColor = isNegative
        ? (isDark ? Colors.red.shade300 : Colors.red.shade600)
        : brownColor;

    return GestureDetector(
      onTap: onTap,
      child: Icon(
        icon,
        size: 18,
        color: isActive
            ? activeColor
            : brownColor.withValues(alpha: 0.5),
      ),
    );
  }

  Widget _buildEmptyCard(bool isDark, Color brownColor) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.grey.withValues(alpha: 0.15),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'YOUR INSIGHT',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: brownColor,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Your personalized guidance will appear here.',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: brownColor.withValues(alpha: 0.9),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

}
