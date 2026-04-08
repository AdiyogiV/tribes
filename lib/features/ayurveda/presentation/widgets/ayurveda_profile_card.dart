import 'package:aurogram/core/theme/app_dimensions.dart';
import 'package:flutter/material.dart';
import 'package:aurogram/shared/models/ayurveda_profile.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/widgets/universal/transparent_toolbox.dart';
import 'package:aurogram/features/ayurveda/presentation/widgets/ayurveda_theme.dart';

/// Compact card showing current Vikriti (today's balance) on profile
/// Tappable to open full Ayurveda details page
class AyurvedaProfileCard extends StatelessWidget {
  final AyurvedaProfile profile;
  final VoidCallback? onTap;
  final bool showHeader;

  const AyurvedaProfileCard({
    super.key,
    required this.profile,
    this.onTap,
    this.showHeader = true,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.primaryColor;

    if (!profile.hasData) {
      return const SizedBox.shrink();
    }

    final prakriti = profile.prakriti!;
    final vikriti = profile.vikriti;
    final hasVikriti = vikriti != null;

    return TransparentToolbox.buildCard(
      context: context,
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header label
                if (showHeader) ...[
                  Text('AYURVEDA', style: AppTheme.cardLabelStyle),
                  const SizedBox(height: AppDimensions.spacingSm),
                  // Subtitle
                  Text(
                    hasVikriti ? "Today's Balance" : prakriti.type,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: c.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spacingXs),
                ],

                // Dosha bars - show vikriti comparison if available, else prakriti
                if (hasVikriti) ...[
                  DoshaComparisonBar(
                    label: 'Vata',
                    baseline: prakriti.vata,
                    current: vikriti.vata,
                    color: vataColor,
                    primaryColor: c,
                    compact: true,
                  ),
                  const SizedBox(height: AppDimensions.spacingSm),
                  DoshaComparisonBar(
                    label: 'Pitta',
                    baseline: prakriti.pitta,
                    current: vikriti.pitta,
                    color: pittaColor,
                    primaryColor: c,
                    compact: true,
                  ),
                  const SizedBox(height: AppDimensions.spacingSm),
                  DoshaComparisonBar(
                    label: 'Kapha',
                    baseline: prakriti.kapha,
                    current: vikriti.kapha,
                    color: kaphaColor,
                    primaryColor: c,
                    compact: true,
                  ),
                ] else ...[
                  _buildSimpleDoshaBar('Vata', prakriti.vata, vataColor, c),
                  const SizedBox(height: AppDimensions.spacingSm),
                  _buildSimpleDoshaBar('Pitta', prakriti.pitta, pittaColor, c),
                  const SizedBox(height: AppDimensions.spacingSm),
                  _buildSimpleDoshaBar('Kapha', prakriti.kapha, kaphaColor, c),
                ],

                // Check-in prompt if no vikriti
                if (!hasVikriti) ...[
                  const SizedBox(height: AppDimensions.spacingMd),
                  Text(
                    'Check in for today\'s balance',
                    style: TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: c.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            size: 20,
            color: AppTheme.primaryLow,
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleDoshaBar(String name, int percentage, Color color, Color primaryColor) {
    return Row(
      children: [
        SizedBox(
          width: 50,
          child: Text(
            name,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: primaryColor.withValues(alpha: 0.7),
            ),
          ),
        ),
        const SizedBox(width: AppDimensions.spacingSm),
        Expanded(
          child: Stack(
            children: [
              // Background bar
              Container(
                height: 5,
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
              // Filled bar
              FractionallySizedBox(
                widthFactor: percentage / 100,
                child: Container(
                  height: 5,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppDimensions.spacingSm),
        SizedBox(
          width: 24,
          child: Text(
            '$percentage',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: primaryColor.withValues(alpha: 0.5),
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}
