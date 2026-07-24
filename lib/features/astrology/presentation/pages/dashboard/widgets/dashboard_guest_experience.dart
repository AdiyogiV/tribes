import 'package:flutter/material.dart';
import 'package:aurogram/features/astrology/presentation/pages/dashboard/widgets/guest/guest_hero_card.dart';
import 'package:aurogram/features/astrology/presentation/pages/dashboard/widgets/guest/guest_entry_card.dart';
import 'package:aurogram/features/astrology/presentation/pages/dashboard/widgets/guest/guest_feature_cards.dart';
import 'package:aurogram/features/astrology/presentation/pages/dashboard/widgets/guest/guest_collective_card.dart';
import 'package:aurogram/features/astrology/presentation/pages/dashboard/widgets/guest/guest_footer.dart';

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
            const SizedBox(height: 16),
            GuestEntryCard(isDark: isDark, isWide: isWide),
            const SizedBox(height: 16),
            GuestFeatureCards(isDark: isDark),
            const SizedBox(height: 16),
            GuestCollectiveCard(isDark: isDark, isWide: isWide),
            SizedBox(height: spacing + 128),
            GuestFooter(isDark: isDark, isWide: isWide),
          ],
        );
      },
    );
  }
}
