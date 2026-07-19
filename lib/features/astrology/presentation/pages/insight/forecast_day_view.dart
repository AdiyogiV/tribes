import 'package:flutter/material.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/features/astrology/domain/forecast_service.dart';
import 'package:aurogram/features/astrology/presentation/pages/insight/energy_detail_cards.dart';
import 'package:aurogram/features/astrology/presentation/pages/insight/insight_reaction_footer.dart';
import 'package:aurogram/shared/models/astrology_profile.dart';

/// Purpose-built presentation for one day from the unified forecast model.
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
    final brown = AppTheme.astroBrown(isDark);
    final guidance = _guidanceItems(forecast);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ForecastHero(forecast: forecast, brown: brown),
        if (forecast.tara?.trim().isNotEmpty == true ||
            forecast.favorable.isNotEmpty ||
            forecast.unfavorable.isNotEmpty) ...[
          const SizedBox(height: AppDimensions.spacingMd),
          EnergyBreakdownCard(energy: forecast, accent: brown),
        ],
        if (guidance.isNotEmpty) ...[
          const SizedBox(height: AppDimensions.spacingMd),
          _GuidanceCard(items: guidance, brown: brown),
        ],
        const SizedBox(height: AppDimensions.spacingMd),
        EnergyMethodCard(accent: brown),
        const SizedBox(height: AppDimensions.spacingMd),
        ForecastReactionFooter(
          forecast: forecast,
          profile: profile,
          uid: uid,
        ),
      ],
    );
  }

  static List<_GuidanceItem> _guidanceItems(ForecastDay day) => [
        if (_hasText(day.action))
          _GuidanceItem(
            icon: Icons.explore_outlined,
            label: 'Focus',
            content: day.action!,
          ),
        if (_hasText(day.caution))
          _GuidanceItem(
            icon: Icons.shield_outlined,
            label: 'Handle gently',
            content: day.caution!,
          ),
        if (_hasText(day.timing))
          _GuidanceItem(
            icon: Icons.schedule_outlined,
            label: 'Timing',
            content: day.timing!,
          ),
        if (_hasText(day.tip))
          _GuidanceItem(
            icon: Icons.lightbulb_outline_rounded,
            label: 'Practical tip',
            content: day.tip!,
          ),
      ];

  static bool _hasText(String? value) => value?.trim().isNotEmpty == true;
}

class _ForecastHero extends StatelessWidget {
  final ForecastDay forecast;
  final Color brown;

  const _ForecastHero({required this.forecast, required this.brown});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final heading = forecast.heading?.trim().isNotEmpty == true
        ? forecast.heading!.trim()
        : "Today's energy";
    final narrative = forecast.narrative?.trim() ?? '';
    final energyLabel =
        _isToday(forecast.date) ? "TODAY'S ENERGY" : 'DAILY ENERGY';

    return Semantics(
      container: true,
      label: [
        heading,
        if (forecast.alignment != null) '${forecast.alignment} percent aligned',
        narrative,
      ].join('. '),
      child: Material(
        color: colorScheme.surface,
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.paddingXl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$energyLabel  •  ${_formatDate(forecast.date).toUpperCase()}',
                          style: TextStyle(
                            color: brown,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.4,
                          ),
                        ),
                        const SizedBox(height: AppDimensions.spacingSm),
                        Text(
                          heading,
                          style: TextStyle(
                            color: colorScheme.onSurface,
                            fontSize: 26,
                            height: 1.15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (forecast.alignment != null) ...[
                    const SizedBox(width: AppDimensions.spacingMd),
                    _AlignmentBadge(
                      alignment: forecast.alignment!,
                      brown: brown,
                    ),
                  ],
                ],
              ),
              if (narrative.isNotEmpty) ...[
                const SizedBox(height: AppDimensions.spacingLg),
                Text(
                  narrative,
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 16,
                    height: 1.55,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static bool _isToday(String value) {
    final now =
        DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));
    return value == ForecastService.dateKey(now);
  }

  static String _formatDate(String value) {
    final date = DateTime.tryParse(value);
    if (date == null) return value;
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}

class _AlignmentBadge extends StatelessWidget {
  final int alignment;
  final Color brown;

  const _AlignmentBadge({required this.alignment, required this.brown});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$alignment percent aligned',
      excludeSemantics: true,
      child: Container(
        constraints: const BoxConstraints(minWidth: 72),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: brown.withValues(alpha: 0.10),
          border: Border.all(color: brown.withValues(alpha: 0.28)),
          borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        ),
        child: Column(
          children: [
            Text(
              '$alignment%',
              style: TextStyle(
                color: brown,
                fontSize: 20,
                height: 1,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'ENERGY',
              style: TextStyle(
                color: brown,
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuidanceCard extends StatelessWidget {
  final List<_GuidanceItem> items;
  final Color brown;

  const _GuidanceCard({required this.items, required this.brown});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.surface,
      elevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingLg),
        child: Column(
          children: [
            for (var index = 0; index < items.length; index++) ...[
              _GuidanceRow(item: items[index], brown: brown),
              if (index < items.length - 1)
                Divider(
                  height: AppDimensions.spacingXxl,
                  color: colorScheme.outlineVariant,
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _GuidanceRow extends StatelessWidget {
  final _GuidanceItem item;
  final Color brown;

  const _GuidanceRow({required this.item, required this.brown});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      label: '${item.label}. ${item.content}',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: brown.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            ),
            child: Icon(item.icon, size: 20, color: brown),
          ),
          const SizedBox(width: AppDimensions.spacingMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.label.toUpperCase(),
                  style: TextStyle(
                    color: brown,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  item.content,
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 14,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GuidanceItem {
  final IconData icon;
  final String label;
  final String content;

  const _GuidanceItem({
    required this.icon,
    required this.label,
    required this.content,
  });
}
