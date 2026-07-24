import 'package:flutter/material.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/core/theme/dashboard_card_theme.dart';
import 'package:aurogram/features/astrology/presentation/pages/dashboard/widgets/guest/guest_atoms.dart';

/// Renders a list of distinct, minimal cards for each core offering.
/// Breaking them out into multiple cards creates a beautiful scrolling feed.
class GuestFeatureCards extends StatelessWidget {
  const GuestFeatureCards({super.key, required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _FeatureCard(
          isDark: isDark,
          number: '01',
          eyebrow: 'JYOTISH',
          eyebrowColor: kGuestJyotish,
          title: 'The Blueprint',
          description: 'Your elemental nature, decoded from the exact geometry of your birth. We map the sky at your origin to reveal the latent forces shaping your narrative.',
        ),
        const SizedBox(height: 16),
        _FeatureCard(
          isDark: isDark,
          number: '02',
          eyebrow: 'PANCHANG',
          eyebrowColor: kGuestHaldi,
          title: 'The Pulse',
          description: 'Sacred timing and the movement of the luminaries. Move with the day’s current, knowing effortlessly when to act and when to rest.',
        ),
        const SizedBox(height: 16),
        _FeatureCard(
          isDark: isDark,
          number: '03',
          eyebrow: 'AYURVEDA',
          eyebrowColor: kGuestAyurveda,
          title: 'The Equilibrium',
          description: 'The ancient study of inner harmony. Discover your elemental constitution and cultivate a quiet resonance between mind and vessel.',
        ),
        const SizedBox(height: 16),
        _FeatureCard(
          isDark: isDark,
          number: '04',
          eyebrow: 'THE GUIDE',
          eyebrowColor: kGuestSaffron,
          title: 'A Guided Practice',
          description: 'A voice-first intelligence that knows your chart, decodes the sky in real-time, and answers your deepest questions.',
        ),
      ],
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.isDark,
    required this.number,
    required this.eyebrow,
    required this.eyebrowColor,
    required this.title,
    required this.description,
  });

  final bool isDark;
  final String number;
  final String eyebrow;
  final Color eyebrowColor;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final palette = DashboardCardPalette.forBrightness(isDark);
    
    return DashboardCard(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GuestEyebrow(text: eyebrow, color: eyebrowColor),
              Text(
                number,
                style: TextStyle(
                  fontFamily: 'Georgia',
                  fontStyle: FontStyle.italic,
                  fontSize: 16,
                  color: palette.fgFaint,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Text(
            title,
            style: TextStyle(
              fontFamily: 'Georgia',
              fontSize: 24,
              fontWeight: FontWeight.w400,
              color: palette.fgMain,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 16),
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
    );
  }
}
