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
      padding: EdgeInsets.zero, // We handle padding inside the stack
      child: Stack(
        children: [
          // 1. The Bleeding Mandala (Art Direction)
          // Pushed off the top right edge to create dramatic negative space
          // and a true editorial magazine feel.
          Positioned(
            top: isWide ? -60 : -40,
            right: isWide ? -60 : -40,
            child: GuestMandalaMark(
              size: isWide ? 420 : 280,
              isDark: isDark,
            ),
          ),
          
          // 2. The Content
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 32.0,
              vertical: 40.0,
            ),
            child: isWide 
              ? Row(
                  children: [
                    Expanded(flex: 6, child: _text(context, palette)),
                    const Expanded(flex: 4, child: SizedBox.shrink()), // Space for mandala
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
        const SizedBox(height: AppDimensions.spacingLargeSection),
        
        const GuestEyebrow(
          text: 'PANCHANG · JYOTISH · AYURVEDA',
          color: kGuestSaffron,
        ),
        const SizedBox(height: AppDimensions.spacingMd),
        
        // Massive editorial typography
        EditorialCardHeader(
          leading: "India's living",
          trailing: ' almanac.',
          palette: palette,
          leadingColor: palette.fgMain,
          titleSize: isWide ? 48 : 38,
        ),
        const SizedBox(height: AppDimensions.spacingLg),
        
        Text(
          'The timeless Indian sciences of time, sky and self — reunited in '
          'one modern app, and tuned to you. Add your birth details and watch '
          'today align around you.',
          style: TextStyle(
            color: palette.fgMuted,
            fontSize: AppTheme.babaTextSize + 1,
            height: 1.5,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: AppDimensions.spacingLargeSection),
        
        GuestPrimaryCta(
          label: 'Create your free profile',
          icon: Icons.auto_awesome_rounded,
          color: kGuestSaffron,
          onTap: () => _toLogin(context),
        ),
        const SizedBox(height: AppDimensions.spacingMd),
        
        Align(
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
      ],
    );
  }
}

/// The Aurogram wordmark with a minimal devanagari seal.
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
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border.all(
              color: kGuestSaffron.withValues(alpha: 0.3),
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Text(
            'ॐ',
            style: TextStyle(
              color: kGuestSaffron,
              fontSize: 18,
              height: 1.0,
            ),
          ),
        ),
        const SizedBox(width: AppDimensions.spacingMd),
        Text(
          'aurogram',
          style: TextStyle(
            color: fg,
            fontSize: 22,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}
