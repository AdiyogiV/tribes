import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:aurogram/shared/models/daily_insight.dart';
import 'package:aurogram/features/astrology/domain/astrology_service.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';
import 'package:aurogram/shared/presentation/widgets/universal/transparent_toolbox.dart';

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
    final fgMain = isDark ? Colors.white : Colors.black;
    final fgMuted = isDark ? Colors.white54 : Colors.black54;

    if (widget.insight == null) {
      return _buildEmptyCard(isDark, fgMain, fgMuted);
    }

    return TransparentToolbox.buildCard(
      context: context,
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
      onTap: widget.onTap != null ? () {
        HapticFeedback.lightImpact();
        widget.onTap!();
      } : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header - Chic Editorial Theme
          Text(
            widget.insight!.displayTheme.toLowerCase(),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Georgia',
              fontStyle: FontStyle.italic,
              fontSize: 26,
              letterSpacing: -0.5,
              color: fgMain,
              height: 1.1,
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Insight text - airy, editorial style
          Text(
            widget.insight!.displayMessage,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Georgia',
              fontStyle: FontStyle.italic,
              fontSize: 12.5,
              color: fgMuted,
              height: 1.5,
            ),
          ),
          
          // Action buttons
          if (widget.showActions) ...[
            const SizedBox(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildActionButton(
                  icon: _reaction == 'thumbs_up'
                      ? Icons.thumb_up
                      : Icons.thumb_up_outlined,
                  isActive: _reaction == 'thumbs_up',
                  onTap: _hasReacted ? null : () => _submitReaction('thumbs_up'),
                  fgMuted: fgMuted,
                  isDark: isDark,
                ),
                const SizedBox(width: 14),
                Text('·', style: TextStyle(fontSize: 12, color: fgMuted)),
                const SizedBox(width: 14),
                _buildActionButton(
                  icon: _reaction == 'thumbs_down'
                      ? Icons.thumb_down
                      : Icons.thumb_down_outlined,
                  isActive: _reaction == 'thumbs_down',
                  onTap: _hasReacted ? null : () => _submitReaction('thumbs_down'),
                  fgMuted: fgMuted,
                  isDark: isDark,
                  isNegative: true,
                ),
                const SizedBox(width: 14),
                Text('·', style: TextStyle(fontSize: 12, color: fgMuted)),
                const SizedBox(width: 14),
                _buildActionButton(
                  icon: _isFavorite ? Icons.bookmark : Icons.bookmark_border,
                  isActive: _isFavorite,
                  onTap: _isLoadingFavorite ? null : _toggleFavorite,
                  fgMuted: fgMuted,
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
    required Color fgMuted,
    required bool isDark,
    bool isNegative = false,
  }) {
    final activeColor = isNegative
        ? (isDark ? Colors.red.shade300 : Colors.red.shade600)
        : (isDark ? Colors.white : Colors.black);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (onTap != null) {
          HapticFeedback.lightImpact();
          onTap();
        }
      },
      child: Icon(
        icon,
        size: 16,
        color: isActive ? activeColor : fgMuted,
      ),
    );
  }

  Widget _buildEmptyCard(bool isDark, Color fgMain, Color fgMuted) {
    return TransparentToolbox.buildCard(
      context: context,
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Your insight',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Georgia',
              fontStyle: FontStyle.italic,
              fontSize: 26,
              letterSpacing: -0.5,
              color: fgMain,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Your personalized guidance will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Georgia',
              fontStyle: FontStyle.italic,
              fontSize: 12.5,
              color: fgMuted,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
}
