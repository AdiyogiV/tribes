import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';
import 'package:aurogram/core/theme/dashboard_card_theme.dart';
import 'package:aurogram/core/routing/route_names.dart';
import 'package:aurogram/features/astrology/presentation/pages/dashboard/widgets/guest/guest_atoms.dart';

/// The guest hero: brand mark, Indic positioning, the pitch, the primary CTA
/// and a quiet sign-in link. Two-column with a mandala mark on wide panes.
class GuestHeroCard extends StatelessWidget {
  const GuestHeroCard({super.key, required this.isDark, required this.isWide});

  final bool isDark;
  final bool isWide;

  void _toLogin(BuildContext context) {
    HapticFeedback.lightImpact();
    context.push(RouteNames.login);
  }

  @override
  Widget build(BuildContext context) {
    final palette = DashboardCardPalette.forBrightness(isDark);
    return GuestCard(
      isDark: isDark,
      tint: kGuestSaffron,
      padding: EdgeInsets.all(isWide ? 34 : 26),
      child: isWide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(flex: 6, child: _text(context, palette)),
                const SizedBox(width: AppDimensions.spacingSection),
                Expanded(
                  flex: 4,
                  child: Center(
                    child: GuestMandalaMark(size: 210, isDark: isDark),
                  ),
                ),
              ],
            )
          : _text(context, palette),
    );
  }

  Widget _text(BuildContext context, DashboardCardPalette palette) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _BrandRow(isDark: isDark),
        const SizedBox(height: AppDimensions.spacingXl),
        const GuestEyebrow(
          text: 'PANCHANG · JYOTISH · AYURVEDA',
          color: kGuestSaffron,
        ),
        const SizedBox(height: AppDimensions.spacingMd),
        EditorialCardHeader(
          leading: "India's living",
          trailing: ' almanac.',
          palette: palette,
          leadingColor: palette.fgMain,
          titleSize: isWide ? 40 : 33,
        ),
        const SizedBox(height: AppDimensions.spacingLg),
        Text(
          'The timeless Indian sciences of time, sky and self — reunited in '
          'one modern app, and tuned to you. Add your birth details and watch '
          'today align around you.',
          style: TextStyle(
            color: palette.fgMuted,
            fontSize: AppTheme.babaTextSize,
            height: 1.55,
          ),
        ),
        const SizedBox(height: AppDimensions.spacingXl),
        GuestPrimaryCta(
          label: 'Create your free profile',
          icon: Icons.auto_awesome_rounded,
          color: kGuestSaffron,
          onTap: () => _toLogin(context),
        ),
        const SizedBox(height: AppDimensions.spacingMd),
        Align(
          alignment: isWide ? Alignment.centerLeft : Alignment.center,
          child: TextButton(
            onPressed: () => _toLogin(context),
            style: TextButton.styleFrom(
              foregroundColor: palette.fgMuted,
              padding: EdgeInsets.zero,
              textStyle: const TextStyle(
                fontSize: AppTheme.babaTextSize,
                fontWeight: FontWeight.w600,
              ),
            ),
            child: const Text('Already with us?  Sign in'),
          ),
        ),
      ],
    );
  }
}

/// The Aurogram wordmark with a devanagari seal.
class _BrandRow extends StatelessWidget {
  const _BrandRow({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final fg = isDark ? Colors.white : const Color(0xFF1A1A1C);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [kGuestSaffron, kGuestHaldi],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(AppDimensions.radiusMdSm),
          ),
          child: const Text(
            'ॐ',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              height: 1.0,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: AppDimensions.spacingMd),
        Text(
          'aurogram',
          style: TextStyle(
            color: fg,
            fontSize: 20,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}
