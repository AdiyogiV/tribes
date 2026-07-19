import 'package:cloud_firestore/cloud_firestore.dart' show FieldValue;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:aurogram/core/di/injection.dart';
import 'package:aurogram/core/logging/app_logger.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/features/astrology/domain/astrology_service.dart';
import 'package:aurogram/features/astrology/domain/forecast_service.dart';
import 'package:aurogram/shared/data/repositories/user_repository.dart';
import 'package:aurogram/shared/models/astrology_profile.dart';
import 'package:aurogram/shared/presentation/widgets/feedback/snack_bar_service.dart';
import 'package:aurogram/shared/services/share/share_service.dart';

/// One action row for the whole daily forecast, rather than repeated controls
/// on every guidance fragment.
class ForecastReactionFooter extends StatefulWidget {
  final ForecastDay forecast;
  final AstrologyProfile? profile;
  final String uid;

  const ForecastReactionFooter({
    super.key,
    required this.forecast,
    required this.profile,
    required this.uid,
  });

  @override
  State<ForecastReactionFooter> createState() => _ForecastReactionFooterState();
}

class _ForecastReactionFooterState extends State<ForecastReactionFooter> {
  final _astrologyService = AstrologyService();
  bool _isAccurate = false;
  bool _isSaved = false;
  bool _isSaving = false;

  String get _documentId => 'forecast_${widget.forecast.date}';

  @override
  void initState() {
    super.initState();
    _loadSavedState();
  }

  @override
  void didUpdateWidget(ForecastReactionFooter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.forecast.date != widget.forecast.date) {
      _isAccurate = false;
      _isSaved = false;
      _loadSavedState();
    }
  }

  Future<void> _loadSavedState() async {
    if (widget.uid.isEmpty) return;
    try {
      final snapshot = await _savedDocument().get();
      if (mounted) setState(() => _isSaved = snapshot.exists);
    } catch (error) {
      AppLogger.w('Could not read saved forecast state',
          category: LogCategory.database, data: {'error': error.toString()});
    }
  }

  dynamic _savedDocument() => locator<UserRepository>()
      .collection
      .doc(widget.uid)
      .collection('savedInsights')
      .doc(_documentId);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final brown = AppTheme.astroBrown(isDark);

    return Semantics(
      container: true,
      label: 'Forecast actions',
      child: Wrap(
        spacing: AppDimensions.spacingSm,
        runSpacing: AppDimensions.spacingSm,
        children: [
          _ActionChip(
            icon:
                _isAccurate ? Icons.auto_awesome : Icons.auto_awesome_outlined,
            label: _isAccurate ? 'Accurate' : 'Feels accurate',
            selected: _isAccurate,
            onPressed: _isAccurate ? null : _markAccurate,
            brown: brown,
          ),
          _ActionChip(
            icon: _isSaved ? Icons.bookmark : Icons.bookmark_outline,
            label: _isSaved ? 'Saved' : 'Save',
            selected: _isSaved,
            onPressed: _isSaving ? null : _toggleSaved,
            brown: brown,
          ),
          _ActionChip(
            icon: Icons.share_outlined,
            label: 'Share',
            selected: false,
            onPressed: _share,
            brown: brown,
          ),
        ],
      ),
    );
  }

  Future<void> _markAccurate() async {
    HapticFeedback.lightImpact();
    final success = await _astrologyService.submitInsightFeedback(
      widget.forecast.date,
      date: widget.forecast.date,
      feedback: 'thumbs_up',
    );
    if (!mounted) return;
    if (success) {
      setState(() => _isAccurate = true);
      showCustomSnackBar(
        context,
        message: 'Thanks for the feedback',
        backgroundColor: AppTheme.astroBrown(
          Theme.of(context).brightness == Brightness.dark,
        ),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      );
    }
  }

  Future<void> _toggleSaved() async {
    if (widget.uid.isEmpty) return;
    HapticFeedback.lightImpact();
    final wasSaved = _isSaved;
    setState(() {
      _isSaved = !wasSaved;
      _isSaving = true;
    });

    try {
      final document = _savedDocument();
      if (wasSaved) {
        await document.delete();
      } else {
        await document.set({
          'title': widget.forecast.heading ?? 'Daily forecast',
          'content': _shareContent,
          'cardType': 'forecast',
          'insightDate': widget.forecast.date,
          'alignment': widget.forecast.alignment,
          'savedAt': FieldValue.serverTimestamp(),
        });
      }
      if (mounted && !wasSaved) {
        showCustomSnackBar(
          context,
          message: 'Forecast saved',
          backgroundColor: AppTheme.astroBrown(
            Theme.of(context).brightness == Brightness.dark,
          ),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        );
      }
    } catch (error, stackTrace) {
      AppLogger.e('Failed to save forecast',
          category: LogCategory.database, error: error, stackTrace: stackTrace);
      if (mounted) setState(() => _isSaved = wasSaved);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _share() {
    HapticFeedback.lightImpact();
    ShareService.shareInsight(
      context: context,
      insightId: _documentId,
      cardType: 'forecast',
      title: widget.forecast.heading ?? 'Daily forecast',
      content: _shareContent,
      userName: null,
      moonSign: widget.profile?.moonSign,
      risingSign: widget.profile?.ascendant,
      sunSign: widget.profile?.sunSign,
    );
  }

  String get _shareContent => [
        if (widget.forecast.narrative?.trim().isNotEmpty == true)
          widget.forecast.narrative!.trim(),
        if (widget.forecast.action?.trim().isNotEmpty == true)
          'Focus: ${widget.forecast.action!.trim()}',
        if (widget.forecast.caution?.trim().isNotEmpty == true)
          'Handle gently: ${widget.forecast.caution!.trim()}',
        if (widget.forecast.timing?.trim().isNotEmpty == true)
          'Timing: ${widget.forecast.timing!.trim()}',
        if (widget.forecast.tip?.trim().isNotEmpty == true)
          'Practical tip: ${widget.forecast.tip!.trim()}',
      ].join('\n\n');
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onPressed;
  final Color brown;

  const _ActionChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onPressed,
    required this.brown,
  });

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 17, color: brown),
      label: Text(label),
      onPressed: onPressed,
      backgroundColor: brown.withValues(alpha: selected ? 0.12 : 0.06),
      side: BorderSide(color: brown.withValues(alpha: selected ? 0.35 : 0.18)),
      labelStyle: TextStyle(
        color: brown,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
      ),
    );
  }
}
