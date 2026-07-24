import 'package:flutter/material.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';
import 'package:aurogram/core/theme/dashboard_card_theme.dart';
import 'package:aurogram/features/astrology/presentation/pages/dashboard/widgets/guest/guest_atoms.dart';

/// Pure typographic social proof. 
class GuestCollectiveCard extends StatelessWidget {
  const GuestCollectiveCard({super.key, required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final palette = DashboardCardPalette.forBrightness(isDark);

    return DashboardCard(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 56),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          GuestEyebrow(text: 'THE NETWORK', color: palette.fgMuted),
          const SizedBox(height: AppDimensions.spacingLg),
          
          Text(
            '150,000+ Seekers',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Georgia',
              color: palette.fgMain,
              fontSize: 32,
              fontWeight: FontWeight.w400,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: AppDimensions.spacingMd),
          
          Text(
            'A living network moving in sync with the cosmos.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: palette.fgMuted,
              fontSize: AppTheme.babaTextSize,
              fontStyle: FontStyle.italic,
              fontFamily: 'Georgia',
            ),
          ),
        ],
      ),
    );
  }
}
