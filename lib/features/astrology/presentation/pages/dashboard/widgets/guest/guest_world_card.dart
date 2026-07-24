import 'package:flutter/material.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/core/theme/dashboard_card_theme.dart';
import 'package:aurogram/features/astrology/data/utils/yoni_tribe.dart';
import 'package:aurogram/features/astrology/presentation/pages/dashboard/widgets/guest/guest_atoms.dart';

/// The "shared world" card.
///
/// Depicts the ecosystem: born under a star, every member is given a spirit
/// (one of the 14 yoni animals) — a living identity. You see how the cosmos
/// moves the people you love and grow together (a Co-Star-like shared sky).
/// This is where the full menagerie of animal DPs lives.
class GuestWorldCard extends StatelessWidget {
  const GuestWorldCard({super.key, required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final palette = DashboardCardPalette.forBrightness(isDark);
    // Single source of truth for the animal set (DRY).
    final animals = [for (final t in YoniTribeData.all) t.animal];

    return DashboardCard(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GuestEyebrow(text: 'A SHARED SKY', color: kGuestCircles),
              Text(
                '05',
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
            'Everyone carries a spirit.',
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
            'Born under a star, you are given a spirit — a living identity drawn '
            'from your nakshatra. See how the cosmos moves the people you love, '
            'and grow together beneath one sky.',
            style: TextStyle(
              fontSize: AppTheme.babaTextSize,
              height: 1.6,
              color: palette.fgMuted,
            ),
          ),
          const SizedBox(height: 40),

          // The full menagerie — overlapping avatars that wrap gracefully.
          Wrap(
            alignment: WrapAlignment.start,
            runSpacing: 12,
            children: [
              for (final animal in animals)
                Align(
                  widthFactor: 0.72,
                  alignment: Alignment.centerLeft,
                  child: GuestAnimalAvatar(
                    animal: animal,
                    size: 46,
                    isDark: isDark,
                    borderWidth: 2,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
