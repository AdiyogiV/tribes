import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';
import 'package:aurogram/core/theme/dashboard_card_theme.dart';
import 'package:aurogram/core/routing/route_names.dart';
import 'package:aurogram/features/astrology/presentation/pages/dashboard/widgets/guest/guest_atoms.dart';

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
          // The Abstract Astrolabe (Art Direction)
          // Pushed off the top right edge to create dramatic negative space
          Positioned(
            top: isWide ? -80 : -40,
            right: isWide ? -80 : -40,
            child: GuestMandalaMark(
              size: isWide ? 500 : 320,
              isDark: isDark,
            ),
          ),
          
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
        const SizedBox(height: AppDimensions.spacingHero),
        
        const GuestEyebrow(
          text: 'THE VEDIC SCIENCES',
          color: kGuestSaffron,
        ),
        const SizedBox(height: AppDimensions.spacingMd),
        
        // Abstract, global, chic headline
        EditorialCardHeader(
          leading: "Time, sky, ",
          trailing: 'and self.',
          palette: palette,
          leadingColor: palette.fgMain,
          titleSize: isWide ? 54 : 42,
        ),
        const SizedBox(height: AppDimensions.spacingLg),
        
        Text(
          'A unified system of ancient wisdom, translated for the modern world. '
          'Discover your elemental nature and move in rhythm with the universe.',
          style: TextStyle(
            color: palette.fgMuted,
            fontSize: AppTheme.babaTextSize + 2,
            height: 1.5,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: AppDimensions.spacingHero),
        
        SizedBox(
          width: isWide ? 320 : double.infinity,
          child: GuestPrimaryCta(
            label: 'Enter the almanac',
            icon: Icons.auto_awesome_rounded,
            color: kGuestSaffron,
            onTap: () => _toLogin(context),
          ),
        ),
        const SizedBox(height: AppDimensions.spacingLg),
        
        SizedBox(
          width: isWide ? 320 : double.infinity,
          child: Align(
            alignment: Alignment.center,
            child: TextButton(
              onPressed: () => _toLogin(context),
              style: TextButton.styleFrom(
                foregroundColor: palette.fgMuted,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                textStyle: const TextStyle(
                  fontFamily: 'Georgia',
                  fontStyle: FontStyle.italic,
                  fontSize: 16,
                ),
              ),
              child: const Text('Already with us? Sign in.'),
            ),
          ),
        ),
      ],
    );
  }
}

/// A clean, minimalist wordmark without explicit symbols.
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
        fontSize: 14,
        fontWeight: FontWeight.w700,
        letterSpacing: 4.0,
      ),
    );
  }
}
