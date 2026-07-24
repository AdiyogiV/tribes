import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';
import 'package:aurogram/core/theme/dashboard_card_theme.dart';
import 'package:aurogram/core/routing/route_names.dart';
import 'package:aurogram/features/astrology/presentation/pages/dashboard/widgets/guest/guest_atoms.dart';
import 'package:aurogram/features/astrology/presentation/widgets/rotating_nakshatra_wheel.dart';

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
    
    return DashboardCard(
      padding: EdgeInsets.zero,
      child: Stack(
        children: [
          // 1. The Authentic Wheel (Editorial Art Direction)
          // Clipped and faded into the background. Pushed right and slightly up.
          Positioned(
            top: isWide ? -100 : -50,
            right: isWide ? -180 : -100,
            child: Opacity(
              opacity: isDark ? 0.4 : 0.15, // Subtle watermark effect
              child: IgnorePointer(
                child: RotatingNakshatraWheel(
                  size: isWide ? 600 : 400,
                  animate: true,
                  enableZoom: false,
                ),
              ),
            ),
          ),
          
          // Gradient to fade the wheel softly into the left side text
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    palette.surface,
                    palette.surface.withValues(alpha: 0.8),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.4, 1.0],
                ),
              ),
            ),
          ),
          
          // 2. The Content
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 32.0,
              vertical: 48.0,
            ),
            child: isWide 
              ? Row(
                  children: [
                    Expanded(flex: 6, child: _text(context, palette)),
                    const Expanded(flex: 4, child: SizedBox.shrink()),
                  ],
                )
              : _text(context, palette),
          ),
        ],
      ),
    );
  }

  Widget _text(BuildContext context, DashboardCardPalette palette) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _BrandRow(isDark: isDark),
        const SizedBox(height: AppDimensions.spacingHero),
        
        const GuestEyebrow(
          text: 'THE COSMIC ARCHITECTURE',
          color: kGuestSaffron,
        ),
        const SizedBox(height: AppDimensions.spacingMd),
        
        // Refined, perfectly scaled chic headline
        EditorialCardHeader(
          leading: "A dialogue with ",
          trailing: 'the sky.',
          palette: palette,
          leadingColor: palette.fgMain,
          titleSize: isWide ? 44 : 36,
        ),
        const SizedBox(height: AppDimensions.spacingLg),
        
        Text(
          'Uncover the subtle mechanics of your nature. A living almanac that '
          'translates the silent language of the stars into the rhythm of your day.',
          style: TextStyle(
            color: palette.fgMuted,
            fontSize: AppTheme.babaTextSize + 1,
            height: 1.5,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: AppDimensions.spacingLargeSection),
        
        // Single, elegant CTA (covers both signup and login)
        GuestPrimaryCta(
          label: 'Enter the sanctuary',
          icon: Icons.arrow_forward_rounded,
          isDark: isDark,
          onTap: () => _toLogin(context),
        ),
      ],
    );
  }
}

class _BrandRow extends StatelessWidget {
  const _BrandRow({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final fg = isDark ? Colors.white : const Color(0xFF1A1A1C);
    return Text(
      'A U R O G R A M',
      style: TextStyle(
        color: fg,
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: 6.0,
      ),
    );
  }
}
