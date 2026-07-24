import 'package:flutter/material.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/core/theme/dashboard_card_theme.dart';
import 'package:aurogram/features/astrology/presentation/pages/dashboard/widgets/guest/guest_atoms.dart';

/// Renders a beautifully unified editorial card containing the core disciplines.
class GuestFeatureCards extends StatelessWidget {
  const GuestFeatureCards({super.key, required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final palette = DashboardCardPalette.forBrightness(isDark);

    return DashboardCard(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: GuestEyebrow(text: 'WHAT UNFOLDS INSIDE', color: palette.fgMuted),
          ),
          const SizedBox(height: 40),
          _FeatureItem(
            isDark: isDark,
            number: 'I',
            eyebrow: 'SAMVAT',
            eyebrowColor: kGuestHaldi,
            title: 'The Rhythm',
            description: 'The day’s sacred imprint, where celestial rhythm becomes lived time.',
          ),
          _Divider(palette: palette),
          _FeatureItem(
            isDark: isDark,
            number: 'II',
            eyebrow: 'JYOTISH',
            eyebrowColor: kGuestJyotish,
            title: 'The Origin',
            description: 'The celestial imprint of your first breath, translated into a personal map of tendencies, gifts, and growth.',
          ),
          _Divider(palette: palette),
          _FeatureItem(
            isDark: isDark,
            number: 'III',
            eyebrow: 'AYURVEDA',
            eyebrowColor: kGuestAyurveda,
            title: 'The Vessel',
            description: 'Your elemental constitution, clarified into practical signals for balance, energy, and wellbeing.',
          ),
          _Divider(palette: palette),
          _FeatureItem(
            isDark: isDark,
            number: 'IV',
            eyebrow: 'THE GUIDE',
            eyebrowColor: kGuestSaffron,
            title: 'The Oracle',
            description: 'A living guide that holds your context, reads the present sky, and answers in plain language.',
          ),
          _Divider(palette: palette),
          _FeatureItem(
            isDark: isDark,
            number: 'V',
            eyebrow: 'THE MENAGERIE',
            eyebrowColor: kGuestCircles,
            title: 'A Shared Sky',
            description: 'See how nakshatra signatures shape the people around you, and where your paths naturally resonate.',
            isLast: true,
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider({required this.palette});
  final DashboardCardPalette palette;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Divider(
        height: 1,
        thickness: 1,
        color: palette.fgFaint.withValues(alpha: 0.15),
      ),
    );
  }
}

class _FeatureItem extends StatelessWidget {
  const _FeatureItem({
    required this.isDark,
    required this.number,
    required this.eyebrow,
    required this.eyebrowColor,
    required this.title,
    required this.description,
    this.isLast = false,
  });

  final bool isDark;
  final String number;
  final String eyebrow;
  final Color eyebrowColor;
  final String title;
  final String description;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final palette = DashboardCardPalette.forBrightness(isDark);
    
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Huge, chic background watermark number
        Positioned(
          top: -20,
          left: -4,
          child: Text(
            number,
            style: TextStyle(
              fontFamily: 'Georgia',
              fontStyle: FontStyle.italic,
              fontSize: 100,
              color: palette.fgFaint.withValues(alpha: 0.08),
              height: 1.0,
              letterSpacing: -2,
            ),
          ),
        ),
        // Foreground Content
        Padding(
          padding: const EdgeInsets.only(top: 16, left: 16, right: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GuestEyebrow(text: eyebrow, color: eyebrowColor),
              const SizedBox(height: 12),
              Text(
                title,
                style: TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 28,
                  fontWeight: FontWeight.w400,
                  color: palette.fgMain,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                description,
                style: TextStyle(
                  fontSize: AppTheme.babaTextSize,
                  height: 1.6,
                  color: palette.fgMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
