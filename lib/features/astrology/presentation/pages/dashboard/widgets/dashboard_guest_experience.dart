import 'package:flutter/material.dart';
import 'package:aurogram/features/astrology/presentation/pages/dashboard/widgets/guest/guest_hero_card.dart';
import 'package:aurogram/features/astrology/presentation/pages/dashboard/widgets/guest/guest_pillars_card.dart';
import 'package:aurogram/features/astrology/presentation/pages/dashboard/widgets/guest/guest_collective_card.dart';
import 'package:aurogram/features/astrology/presentation/pages/dashboard/widgets/guest/guest_footer.dart';

/// The signed-out home dashboard body.
///
/// A first-time visitor has no saved profile, so the personal astrology cards
/// (Energy wheel, Current Sky, Balance) render as an endless spinner and an
/// empty sky — a broken first impression. This replaces that whole stack with
/// a brand-forward welcome that positions Aurogram as an *Indic platform* —
/// Panchang, Jyotish and Ayurveda in one place — and invites the visitor in:
///
///   1. [GuestHeroCard]         — brand + positioning + primary CTA + sign-in.
///   2. [GuestPillarsCard]      — the three timeless sciences (the core pitch).
///   3. [GuestMadeInIndiaFooter] — trust cues + "Made with love in India".
///
/// The common Vedic date card still sits ABOVE this (owned by
/// `AstroDashboardContent`); this widget is only the swappable body. See
/// `guest_atoms.dart` for the shared chrome and the deliberate Indic palette
/// (the app's `AppTheme.primaryColor` is a leftover farm-era brown we avoid).
class DashboardGuestExperience extends StatelessWidget {
  const DashboardGuestExperience({
    super.key,
    required this.isDark,
    required this.spacing,
  });

  final bool isDark;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 720;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GuestHeroCard(isDark: isDark, isWide: isWide),
            SizedBox(height: spacing),
            GuestPillarsCard(isDark: isDark, isWide: isWide),
            SizedBox(height: spacing + 8),
            const GuestMadeInIndiaFooter(),
          ],
        );
      },
    );
  }
}
