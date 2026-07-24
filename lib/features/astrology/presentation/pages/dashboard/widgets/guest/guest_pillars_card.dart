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
    return GuestCard(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          GuestEyebrow(
              text: 'THREE TIMELESS SCIENCES', color: palette.fgMuted),
          const SizedBox(height: AppDimensions.spacingXs),
          Text(
            'Rooted in the Vedas. Built for today.',
            style: TextStyle(
              fontFamily: 'Georgia',
              fontStyle: FontStyle.italic,
              color: palette.fgMain,
              fontSize: 22,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: AppDimensions.spacingXl),
          if (isWide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < _pillars.length; i++) ...[
                  Expanded(
                    child: _PillarTile(
                        pillar: _pillars[i], palette: palette, stacked: true),
                  ),
                  if (i != _pillars.length - 1)
                    const SizedBox(width: AppDimensions.spacingXl),
                ],
              ],
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < _pillars.length; i++) ...[
                  _PillarTile(
                      pillar: _pillars[i], palette: palette, stacked: false),
                  if (i != _pillars.length - 1)
                    const SizedBox(height: AppDimensions.spacingXl),
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
    required this.stacked,
  });

  final _Pillar pillar;
  final DashboardCardPalette palette;

  /// Wide layout stacks icon-above-text; mobile is a horizontal row.
  final bool stacked;

  @override
  Widget build(BuildContext context) {
    final badge = Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: pillar.color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      ),
      child: Icon(pillar.icon, size: 24, color: pillar.color),
    );

    final title = Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Flexible(
          child: Text(
            pillar.name,
            style: TextStyle(
              fontFamily: 'Georgia',
              color: palette.fgMain,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          pillar.sanskrit,
          style: TextStyle(
            color: pillar.color,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );

    final desc = Text(
      pillar.description,
      style: TextStyle(
        color: palette.fgMuted,
        fontSize: AppTheme.babaTextSize - 1,
        height: 1.45,
      ),
    );

    if (stacked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          badge,
          const SizedBox(height: AppDimensions.spacingLg),
          title,
          const SizedBox(height: AppDimensions.spacingSm),
          desc,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        badge,
        const SizedBox(width: AppDimensions.spacingLg),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              title,
              const SizedBox(height: AppDimensions.spacingXs),
              desc,
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

    return GuestCard(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          GuestEyebrow(
              text: 'AND YOU\u2019RE NEVER ALONE', color: palette.fgMuted),
          const SizedBox(height: AppDimensions.spacingXl),
          if (isWide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: baba),
                const SizedBox(width: AppDimensions.spacingXl),
                Expanded(child: circles),
              ],
            )
          else
            Column(
              children: [
                baba,
                const SizedBox(height: AppDimensions.spacingXl),
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
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          ),
          child: Icon(icon, size: 22, color: color),
        ),
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
                  fontSize: 17,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: AppDimensions.spacingXs),
              Text(
                subtitle,
                style: TextStyle(
                  color: palette.fgMuted,
                  fontSize: AppTheme.babaTextSize - 1,
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
