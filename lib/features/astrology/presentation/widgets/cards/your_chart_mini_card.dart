import 'package:flutter/material.dart';
import 'package:aurogram/shared/models/astrology_profile.dart';
import 'package:aurogram/shared/presentation/widgets/universal/transparent_toolbox.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';

/// Compact card showing the user's core astrology triad (Sun, Moon, Rising).
/// Matches the ProfileAstrologyCard style exactly — left-aligned "STARS" label,
/// sign row, chevron. Taps through to full Astrology Details page.
class YourChartMiniCard extends StatelessWidget {
  final AstrologyProfile profile;
  final Color brown;
  final VoidCallback? onTap;

  const YourChartMiniCard({
    super.key,
    required this.profile,
    required this.brown,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.primaryColor;

    final sunSign = profile.sunSign;
    final moonSign = profile.moonSign;
    final ascendant = profile.ascendant;

    // Need at least one sign to show the card
    if (sunSign == null && moonSign == null && ascendant == null) {
      return const SizedBox.shrink();
    }

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
                Text(
                  'YOUR BIRTH STARS',
                  style: AppTheme.cardLabelStyle,
                ),
                const SizedBox(height: AppDimensions.spacingXs),
                Row(
                  children: [
                    if (ascendant != null) ...[
                      _buildSignItem('Rising', ascendant, c),
                      const SizedBox(width: AppDimensions.spacingXxl),
                    ],
                    if (sunSign != null) ...[
                      _buildSignItem('Sun', sunSign, c),
                      const SizedBox(width: AppDimensions.spacingXxl),
                    ],
                    if (moonSign != null)
                      _buildSignItem('Moon', moonSign, c),
                  ],
                ),
              ],
            ),
          ),
          if (onTap != null)
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: AppTheme.primaryLow,
            ),
        ],
      ),
    );
  }

  Widget _buildSignItem(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: color.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: AppDimensions.spacingXxs),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}
