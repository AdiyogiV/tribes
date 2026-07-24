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
        clipBehavior: Clip.none,
        children: [
          // 1. The Authentic Wheel
          // Brought back, scaled massively, and faded as an elegant watermark.
          Positioned(
            top: isWide ? -100 : -50,
            right: isWide ? -180 : -100,
            child: Opacity(
              opacity: isDark ? 0.35 : 0.15, 
              child: IgnorePointer(
                child: RotatingNakshatraWheel(
                  size: isWide ? 640 : 400,
                  animate: true,
                  enableZoom: false,
                ),
              ),
            ),
          ),
          
          // Gradient fade so the text pops over the wheel lines
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    palette.surface,
                    palette.surface.withValues(alpha: 0.85),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.45, 1.0],
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
                    Expanded(flex: 7, child: _text(context, palette)),
                    const Expanded(flex: 3, child: SizedBox.shrink()),
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
        const SizedBox(height: 64),
        
        const GuestEyebrow(
          text: "THE LIVING ALMANAC",
          color: kGuestSaffron,
        ),
        const SizedBox(height: AppDimensions.spacingMd),
        
        EditorialCardHeader(
          leading: "Time, sky, ",
          trailing: 'and self.',
          palette: palette,
          leadingColor: palette.fgMain,
          titleSize: isWide ? 48 : 38,
        ),
        const SizedBox(height: AppDimensions.spacingLg),
        
        Text(
          'A unified system of ancient wisdom translated for the modern world. '
          'Discover your elemental nature and move in rhythm with the universe.',
          style: TextStyle(
            color: palette.fgMuted,
            fontSize: AppTheme.babaTextSize + 1,
            height: 1.5,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 48),
        
        // Solid, sharp, minimal CTA
        Row(
          children: [
            GuestPrimaryCta(
              label: 'Enter the almanac',
              icon: Icons.arrow_forward_rounded,
              isDark: isDark,
              onTap: () => _toLogin(context),
            ),
          ],
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
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 4.0,
      ),
    );
  }
}
