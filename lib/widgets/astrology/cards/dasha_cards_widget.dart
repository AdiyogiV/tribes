import 'package:flutter/material.dart';
import 'package:aurogram/models/astrology_profile.dart';
import 'package:aurogram/utils/astrology/dasha_utils.dart';
import 'package:aurogram/utils/astrology/planet_utils.dart';
import 'package:aurogram/utils/theme/app_dimensions.dart';

/// Horizontal scrollable list of current Dasha period cards
class DashaCardsWidget extends StatelessWidget {
  final AstrologyProfile profile;
  final void Function(Map<String, dynamic> level, Map<String, dynamic>? dasha,
      bool isDark)? onDashaTap;

  const DashaCardsWidget({
    super.key,
    required this.profile,
    this.onDashaTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dasha = profile.currentDasha;
    final dashaLevels = DashaUtils.extractDashaLevels(dasha);
    final Color cardColor =
        isDark ? Theme.of(context).colorScheme.surface : Colors.white;

    if (dashaLevels.isEmpty) {
      return const SizedBox.shrink();
    }

    final screenWidth = MediaQuery.of(context).size.width;
    // Cap card width for web - max 220px per card
    final cardWidth = (screenWidth * 3 / 5).clamp(150.0, 220.0);

    return SizedBox(
      height: 100,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        clipBehavior: Clip.none,
        itemCount: dashaLevels.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppDimensions.spacingMd),
        itemBuilder: (context, index) {
          final level = dashaLevels[index];
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: SizedBox(
              width: cardWidth,
              child: Material(
                color: cardColor,
                elevation: 2,
                shadowColor: Colors.black.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                child: InkWell(
                  onTap: onDashaTap != null
                      ? () => onDashaTap!(level, dasha, isDark)
                      : null,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                  child: _DashaLevelCard(level: level, isDark: isDark),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DashaLevelCard extends StatelessWidget {
  final Map<String, dynamic> level;
  final bool isDark;

  const _DashaLevelCard({required this.level, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final _ = level['progress'] as double? ??
        DashaUtils.calculateDashaProgress(
            level['startDate'] as String?, level['endDate'] as String?);
    final shortDateRange = DashaUtils.formatShortDashaDateRange(
        level['startDate'] as String?, level['endDate'] as String?);

    final lord = level['lord'] as String? ?? '—';
    final lordColor = PlanetUtils.getColor(lord, isDark);
    final lordSymbol = PlanetUtils.getSymbol(lord);

    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text:
                            (level['label'] as String? ?? 'Dasha').toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: lordColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                      TextSpan(
                        text: '  $lordSymbol',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: lordColor,
                        ),
                      ),
                    ],
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacingSmMd),
          Text(
            lord,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : Colors.black87,
              height: 1.2,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppDimensions.spacingXs),
          Text(
            shortDateRange,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: lordColor.withValues(alpha: 0.75),
              height: 1.3,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

