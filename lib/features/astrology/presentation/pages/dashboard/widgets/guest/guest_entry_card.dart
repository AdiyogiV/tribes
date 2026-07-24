import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:aurogram/core/routing/route_names.dart';
import 'package:aurogram/core/theme/dashboard_card_theme.dart';
import 'package:aurogram/features/astrology/presentation/pages/dashboard/widgets/guest/guest_atoms.dart';

/// Primary conversion card for signed-out users.
///
/// This is the direct entry point into the guest flow:
/// continue without login, add birth details, and view chart outputs.
class GuestEntryCard extends StatelessWidget {
  const GuestEntryCard({super.key, required this.isDark, required this.isWide});

  final bool isDark;
  final bool isWide;

  void _toGuestSetup(BuildContext context) {
    HapticFeedback.lightImpact();
    context.push(RouteNames.astrologySetup);
  }

  @override
  Widget build(BuildContext context) {
    final palette = DashboardCardPalette.forBrightness(isDark);
    final accent = kGuestSaffron.withValues(alpha: isDark ? 0.92 : 0.84);
    final line = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.black.withValues(alpha: 0.10);

    return DashboardCard(
      padding: const EdgeInsets.symmetric(
        horizontal: 32,
        vertical: 48,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 56,
            height: 3,
            color: accent,
          ),
          SizedBox(height: isWide ? 18 : 14),
          GuestEyebrow(text: 'GUEST ENTRY', color: kGuestSaffron),
          SizedBox(height: isWide ? 14 : 10),
          Text(
            'Explore the Framework.',
            style: TextStyle(
              fontFamily: 'Georgia',
              fontStyle: FontStyle.italic,
              color: palette.fgMain,
              fontSize: isWide ? 34 : 28,
              letterSpacing: -0.8,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Share your birth details and receive your Kundli with an integrated Ayurveda view. Secure your account later.',
            style: TextStyle(
              color: palette.fgMuted,
              fontSize: isWide ? 15.5 : 14,
              height: 1.55,
              letterSpacing: -0.1,
            ),
          ),
          const SizedBox(height: 14),
          Divider(height: 1, thickness: 1, color: line),
          const SizedBox(height: 14),
          Text(
            'NO SIGN-IN RITUAL REQUIRED',
            style: TextStyle(
              color: accent,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 2.0,
            ),
          ),
          SizedBox(height: isWide ? 22 : 18),
          GuestPrimaryCta(
            label: 'Enter as guest',
            icon: Icons.arrow_forward_rounded,
            isDark: isDark,
            onTap: () => _toGuestSetup(context),
          ),
        ],
      ),
    );
  }
}

