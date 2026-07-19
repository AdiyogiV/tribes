import 'package:flutter/material.dart';
import 'package:aurogram/features/astrology/domain/forecast_service.dart';
import 'package:aurogram/features/astrology/presentation/pages/insight/energy_detail_cards.dart';
import 'package:aurogram/features/astrology/presentation/pages/insight/insight_reaction_footer.dart';
import 'package:aurogram/shared/models/astrology_profile.dart';

/// Art-directed, asymmetrical editorial presentation for one day.
class ForecastDayView extends StatelessWidget {
  final ForecastDay forecast;
  final AstrologyProfile? profile;
  final String uid;

  const ForecastDayView({
    super.key,
    required this.forecast,
    required this.profile,
    required this.uid,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fgColor = isDark ? Colors.white : Colors.black;
    final guidance = _guidanceItems(forecast);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ForecastHero(forecast: forecast, fgColor: fgColor),
        const SizedBox(height: 56),
        if (guidance.isNotEmpty) ...[
          _GuidanceGrid(items: guidance, fgColor: fgColor),
          const SizedBox(height: 56),
        ],
        if (forecast.tara?.trim().isNotEmpty == true ||
            forecast.favorable.isNotEmpty ||
            forecast.unfavorable.isNotEmpty) ...[
          EnergyBreakdownGrid(energy: forecast, fgColor: fgColor),
          const SizedBox(height: 32),
        ],
        EnergyMethodFooter(fgColor: fgColor),
        const SizedBox(height: 48),
        ForecastReactionFooter(
          forecast: forecast,
          profile: profile,
          uid: uid,
        ),
      ],
    );
  }

  static List<_GuidanceItem> _guidanceItems(ForecastDay day) => [
        if (_hasText(day.action)) _GuidanceItem(label: 'Focus', content: day.action!),
        if (_hasText(day.caution)) _GuidanceItem(label: 'Care', content: day.caution!),
        if (_hasText(day.timing)) _GuidanceItem(label: 'Timing', content: day.timing!),
        if (_hasText(day.tip)) _GuidanceItem(label: 'Tip', content: day.tip!),
      ];

  static bool _hasText(String? value) => value?.trim().isNotEmpty == true;
}

class _ForecastHero extends StatelessWidget {
  final ForecastDay forecast;
  final Color fgColor;

  const _ForecastHero({required this.forecast, required this.fgColor});

  @override
  Widget build(BuildContext context) {
    final heading = forecast.heading?.trim().isNotEmpty == true
        ? forecast.heading!.trim()
        : "The Daily Reading.";
    final narrative = forecast.narrative?.trim() ?? '';

    return Semantics(
      container: true,
      label: [
        heading,
        if (forecast.alignment != null) '${forecast.alignment} percent aligned',
        narrative,
      ].join('. '),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _formatDate(forecast.date).toUpperCase(),
            style: TextStyle(
              color: fgColor.withValues(alpha: 0.5),
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 2.5,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            heading,
            style: TextStyle(
              color: fgColor,
              fontSize: 44,
              height: 1.05,
              fontWeight: FontWeight.w300,
              fontFamily: 'Georgia',
              letterSpacing: -1.0,
            ),
          ),
          if (forecast.alignment != null) ...[
            const SizedBox(height: 16),
            Text(
              '${forecast.alignment}% ALIGNED',
              style: TextStyle(
                color: fgColor,
                fontSize: 10,
                letterSpacing: 2.0,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (narrative.isNotEmpty) ...[
            const SizedBox(height: 32),
            Text(
              narrative,
              style: TextStyle(
                color: fgColor.withValues(alpha: 0.8),
                fontSize: 16,
                height: 1.6,
                fontWeight: FontWeight.w400,
                fontFamily: 'Georgia',
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _formatDate(String value) {
    final date = DateTime.tryParse(value);
    if (date == null) return value;
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}

class _GuidanceGrid extends StatelessWidget {
  final List<_GuidanceItem> items;
  final Color fgColor;

  const _GuidanceGrid({required this.items, required this.fgColor});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < items.length; index++) ...[
          _GridRow(
            label: items[index].label,
            content: items[index].content,
            fgColor: fgColor,
          ),
          if (index < items.length - 1)
            const SizedBox(height: 32),
        ],
      ],
    );
  }
}

class _GridRow extends StatelessWidget {
  final String label;
  final String content;
  final Color fgColor;

  const _GridRow({
    required this.label,
    required this.content,
    required this.fgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 85,
          child: Text(
            label.toUpperCase(),
            style: TextStyle(
              color: fgColor.withValues(alpha: 0.5),
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
              height: 1.8,
            ),
          ),
        ),
        Expanded(
          child: Text(
            content,
            style: TextStyle(
              color: fgColor,
              fontSize: 16,
              height: 1.5,
              fontFamily: 'Georgia',
            ),
          ),
        ),
      ],
    );
  }
}

class _GuidanceItem {
  final String label;
  final String content;

  const _GuidanceItem({required this.label, required this.content});
}
