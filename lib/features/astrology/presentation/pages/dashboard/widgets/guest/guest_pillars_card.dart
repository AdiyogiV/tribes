import 'package:flutter/material.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';
import 'package:aurogram/core/theme/dashboard_card_theme.dart';
import 'package:aurogram/features/astrology/presentation/pages/dashboard/widgets/guest/guest_atoms.dart';

// ─────────────────────────────────────────────────────────────────────────────
// The three pillars
// ─────────────────────────────────────────────────────────────────────────────

@immutable
class _Pillar {
  const _Pillar(
      this.icon, this.color, this.name, this.sanskrit, this.description);
  final IconData icon;
  final Color color;
  final String name;
  final String sanskrit;
  final String description;
}

/// The core pitch: Aurogram's three timeless sciences.
class GuestPillarsCard extends StatelessWidget {
  const GuestPillarsCard({super.key, required this.isDark, required this.isWide});

  final bool isDark;
  final bool isWide;

  List<_Pillar> get _pillars => [
        _Pillar(Icons.wb_sunny_rounded, kGuestHaldi, 'Panchang', 'पञ्चाङ्ग',
            'The sacred Hindu calendar — tithi, nakshatra and the day\u2019s muhurat, live.'),
        _Pillar(Icons.auto_awesome_rounded, kGuestJyotish, 'Jyotish', 'ज्योतिष',
            'Your Vedic birth chart decoded, and how today\u2019s planets move you.'),
        _Pillar(Icons.spa_rounded, kGuestAyurveda, 'Ayurveda', 'आयुर्वेद',
            'Your dosha constitution and daily balance for body and mind.'),
      ];

  @override
  Widget build(BuildContext context) {
    final palette = DashboardCardPalette.forBrightness(isDark);
    
    return DashboardCard(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          GuestEyebrow(
              text: 'THREE TIMELESS SCIENCES', color: palette.fgMuted),
          const SizedBox(height: AppDimensions.spacingSm),
          Text(
            'Rooted in the Vedas. Built for today.',
            style: TextStyle(
              fontFamily: 'Georgia',
              fontStyle: FontStyle.italic,
              color: palette.fgMain,
              fontSize: 26,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: AppDimensions.spacingLargeSection),
          
          if (isWide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < _pillars.length; i++) ...[
                  Expanded(
                    child: _PillarTile(pillar: _pillars[i], palette: palette),
                  ),
                  if (i != _pillars.length - 1)
                    Container(
                      width: 1,
                      height: 120, // fixed height for editorial vertical divider
                      color: palette.fgFaint.withValues(alpha: 0.1),
                      margin: const EdgeInsets.symmetric(horizontal: 24),
                    ),
                ],
              ],
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < _pillars.length; i++) ...[
                  _PillarTile(pillar: _pillars[i], palette: palette),
                  if (i != _pillars.length - 1)
                    Divider(
                      height: 48,
                      thickness: 1,
                      color: palette.fgFaint.withValues(alpha: 0.1),
                    ),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _PillarTile extends StatelessWidget {
  const _PillarTile({
    required this.pillar,
    required this.palette,
  });

  final _Pillar pillar;
  final DashboardCardPalette palette;

  @override
  Widget build(BuildContext context) {
    // Stark, chic layout: Icon left, content right.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(pillar.icon, size: 28, color: pillar.color),
        const SizedBox(width: AppDimensions.spacingLg),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    pillar.name,
                    style: TextStyle(
                      fontFamily: 'Georgia',
                      color: palette.fgMain,
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    pillar.sanskrit,
                    style: TextStyle(
                      color: pillar.color.withValues(alpha: 0.8),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.spacingSm),
              Text(
                pillar.description,
                style: TextStyle(
                  color: palette.fgMuted,
                  fontSize: AppTheme.babaTextSize,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Companions (Baba + Circles)
// ─────────────────────────────────────────────────────────────────────────────

/// The "you're never alone" card: the AI guide + community.
class GuestCompanionsCard extends StatelessWidget {
  const GuestCompanionsCard(
      {super.key, required this.isDark, required this.isWide});

  final bool isDark;
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final palette = DashboardCardPalette.forBrightness(isDark);
    final baba = _Companion(
      icon: Icons.self_improvement_rounded,
      color: kGuestSaffron,
      title: 'Baba, your guide',
      subtitle: 'A voice-first AI pandit who reads your chart and answers.',
      palette: palette,
    );
    final circles = _Companion(
      icon: Icons.groups_rounded,
      color: kGuestCircles,
      title: 'Your circles',
      subtitle: 'See how the sky moves your people — together.',
      palette: palette,
    );

    return DashboardCard(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          GuestEyebrow(
              text: 'AND YOU\u2019RE NEVER ALONE', color: palette.fgMuted),
          const SizedBox(height: AppDimensions.spacingLg),
          if (isWide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: baba),
                Container(
                  width: 1,
                  height: 60,
                  color: palette.fgFaint.withValues(alpha: 0.1),
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                ),
                Expanded(child: circles),
              ],
            )
          else
            Column(
              children: [
                baba,
                Divider(
                  height: 48,
                  thickness: 1,
                  color: palette.fgFaint.withValues(alpha: 0.1),
                ),
                circles,
              ],
            ),
        ],
      ),
    );
  }
}

class _Companion extends StatelessWidget {
  const _Companion({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.palette,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final DashboardCardPalette palette;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 24, color: color),
        const SizedBox(width: AppDimensions.spacingLg),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontFamily: 'Georgia',
                  color: palette.fgMain,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  color: palette.fgMuted,
                  fontSize: AppTheme.babaTextSize,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
