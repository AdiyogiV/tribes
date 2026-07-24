import 'package:flutter/material.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';
import 'package:aurogram/core/theme/dashboard_card_theme.dart';
import 'package:aurogram/features/astrology/data/utils/yoni_tribe.dart';
import 'package:aurogram/features/astrology/presentation/pages/dashboard/widgets/guest/guest_atoms.dart';

/// The closing "collective" card.
///
/// Reframes social proof honestly: rather than a fabricated member count, it
/// leans on the real structure of the platform — the collective is organised
/// into *grams* (sub-communities), and every soul belongs to one of the 14
/// yoni tribes mapped across the 27 nakshatras. Tribe data + images come from
/// [YoniTribeData] (single source of truth).
class GuestCollectiveCard extends StatelessWidget {
  const GuestCollectiveCard({super.key, required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final palette = DashboardCardPalette.forBrightness(isDark);
    final tribes = YoniTribeData.all;

    return DashboardCard(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          GuestEyebrow(text: 'THE COLLECTIVE', color: palette.fgMuted),
          const SizedBox(height: AppDimensions.spacingLg),

          Text(
            'Find your gram.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Georgia',
              color: palette.fgMain,
              fontSize: 30,
              fontWeight: FontWeight.w400,
              fontStyle: FontStyle.italic,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: AppDimensions.spacingMd),

          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Text(
              'Every soul belongs to a tribe of kindred stars. Join a gram, '
              'move with your people, and read the sky together.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: palette.fgMuted,
                fontSize: AppTheme.babaTextSize,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Real, honest figures — the structure, not a vanity count.
          _StatRow(palette: palette),
          const SizedBox(height: 40),

          // The tribe directory: every gram, presented as a named avatar.
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 22,
            runSpacing: 24,
            children: [
              for (final tribe in tribes)
                _TribeTile(tribe: tribe, palette: palette, isDark: isDark),
            ],
          ),
        ],
      ),
    );
  }
}

/// Two real figures rendered as an editorial stat strip.
class _StatRow extends StatelessWidget {
  const _StatRow({required this.palette});

  final DashboardCardPalette palette;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Stat(value: '14', label: 'TRIBES', palette: palette),
        Container(
          width: 1,
          height: 36,
          margin: const EdgeInsets.symmetric(horizontal: 28),
          color: palette.fgFaint.withValues(alpha: 0.2),
        ),
        _Stat(value: '27', label: 'NAKSHATRAS', palette: palette),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.value,
    required this.label,
    required this.palette,
  });

  final String value;
  final String label;
  final DashboardCardPalette palette;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            fontFamily: 'Georgia',
            fontSize: 30,
            fontWeight: FontWeight.w400,
            color: palette.fgMain,
            height: 1.0,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            color: palette.fgMuted,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 2.0,
          ),
        ),
      ],
    );
  }
}

/// A single gram: circular tribe avatar with its name beneath.
class _TribeTile extends StatelessWidget {
  const _TribeTile({
    required this.tribe,
    required this.palette,
    required this.isDark,
  });

  final YoniTribe tribe;
  final DashboardCardPalette palette;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 62,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark ? Colors.white10 : Colors.black12,
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.10)
                    : Colors.black.withValues(alpha: 0.06),
                width: 1,
              ),
            ),
            child: ClipOval(
              child: Image.network(
                tribe.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox(),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            tribe.displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: palette.fgMuted,
              fontSize: 11,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
