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
          // 1. The Authentic Wheel, dissolved into the card.
          //
          // Instead of laying an opaque gradient rectangle ON TOP of the wheel
          // (which left a hard visible seam), we fade the WHEEL ITSELF at its
          // edges with a radial ShaderMask (dstIn). The wheel melts organically
          // into the surface on every side — a true watermark, no band.
          Positioned(
            top: isWide ? -120 : -70,
            right: isWide ? -160 : -120,
            child: IgnorePointer(
              child: Opacity(
                opacity: isDark ? 0.30 : 0.12,
                child: ShaderMask(
                  blendMode: BlendMode.dstIn,
                  shaderCallback: (rect) => const RadialGradient(
                    center: Alignment.center,
                    radius: 0.5,
                    colors: [
                      Colors.white,
                      Colors.white,
                      Colors.transparent,
                    ],
                    stops: [0.0, 0.45, 0.95],
                  ).createShader(rect),
                  child: RotatingNakshatraWheel(
                    size: isWide ? 620 : 420,
                    animate: true,
                    enableZoom: false,
                  ),
                ),
              ),
            ),
          ),

          // 2. A soft legibility wash on the text side only. It reaches full
          //    transparency well before the wheel's core, so there is no
          //    perceptible edge between the two.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    palette.surface,
                    palette.surface.withValues(alpha: 0.55),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.5, 0.85],
                ),
              ),
            ),
          ),
          
          // 3. The Content
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
          leading: "Time, sky, pulse. ",
          trailing: 'A framework for self.',
          palette: palette,
          leadingColor: palette.fgMain,
          titleSize: isWide ? 46 : 36,
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
