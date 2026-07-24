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
        clipBehavior: Clip.none,
        children: [
          // The beautiful, abstract astrolabe visual restored
          Positioned(
            top: isWide ? -80 : -40,
            right: isWide ? -80 : -40,
            child: GuestMandalaMark(
              size: isWide ? 460 : 300,
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
        const SizedBox(height: 64),
        
        Text(
          'A framework for living.',
          style: TextStyle(
            fontFamily: 'Georgia',
            color: palette.fgMain,
            fontSize: isWide ? 44 : 34,
            fontWeight: FontWeight.w400,
            letterSpacing: -0.5,
            height: 1.15,
          ),
        ),
        const SizedBox(height: AppDimensions.spacingLg),
        
        Text(
          'Sync your daily rhythm with the cosmos through the ancient '
          'Indic sciences. Navigate time, space, and self with elegance.',
          style: TextStyle(
            color: palette.fgMuted,
            fontSize: AppTheme.babaTextSize + 1,
            height: 1.5,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 48),
        
        // Single, incredibly minimal CTA block
        Row(
          children: [
            GuestPrimaryCta(
              label: 'Enter',
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
