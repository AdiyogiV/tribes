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
          // 1. The Authentic Wheel (Editorial Art Direction)
          // Displayed clearly as a focal piece of the layout, pushed to the right.
          if (isWide)
            Positioned(
              top: -60,
              right: -120,
              child: IgnorePointer(
                child: RotatingNakshatraWheel(
                  size: 580,
                  animate: true,
                  enableZoom: false,
                ),
              ),
            ),
          
          // Gradient to ensure text remains readable over the wheel edge
          if (isWide)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      palette.surface,
                      palette.surface.withValues(alpha: 0.95),
                      palette.surface.withValues(alpha: 0.6),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.45, 0.65, 1.0],
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
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _text(context, palette),
                    const SizedBox(height: 48),
                    // On mobile, show the wheel below the text
                    Center(
                      child: IgnorePointer(
                        child: RotatingNakshatraWheel(
                          size: 320,
                          animate: true,
                          enableZoom: false,
                        ),
                      ),
                    ),
                  ],
                ),
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
        const SizedBox(height: 48),
        
        // A perfectly scaled, grounded headline
        Text(
          'Discover your cosmic nature.',
          style: TextStyle(
            fontFamily: 'Georgia',
            color: palette.fgMain,
            fontSize: isWide ? 40 : 32,
            fontWeight: FontWeight.w400,
            letterSpacing: -0.5,
            height: 1.2,
          ),
        ),
        const SizedBox(height: AppDimensions.spacingLg),
        
        Text(
          'A unified system of ancient wisdom—Panchang, Jyotish, and Ayurveda—'
          'translated for the modern world. Navigate your day with celestial precision.',
          style: TextStyle(
            color: palette.fgMuted,
            fontSize: AppTheme.babaTextSize,
            height: 1.5,
          ),
        ),
        
        const SizedBox(height: 36),
        
        // Social Proof / The Collective woven directly into the hero
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const _HeroAvatarStack(),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                'Join over 150,000 seekers navigating their daily rhythm.',
                style: TextStyle(
                  color: palette.fgMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 48),
        
        // Single, elegant CTA (covers both signup and login)
        Row(
          children: [
            GuestPrimaryCta(
              label: 'Get started',
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
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: 6.0,
      ),
    );
  }
}

/// A compact overlapping row of actual Yoni tribe avatars for the hero card.
class _HeroAvatarStack extends StatelessWidget {
  const _HeroAvatarStack();

  static const _animals = [
    'tiger', 'cobra', 'elephant', 'horse', 'monkey'
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? const Color(0xFF14141A) : Colors.white;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        SizedBox(width: (_animals.length * 22.0) + 14, height: 36),
        ...List.generate(_animals.length, (index) {
          final animal = _animals[index];
          final url = 'https://firebasestorage.googleapis.com/v0/b/ty-dev-516d7.appspot.com/o/yoni_tribes%2F$animal.webp?alt=media';
          
          return Positioned(
            left: index * 22.0,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: borderColor,
                  width: 2,
                ),
                color: isDark ? Colors.white10 : Colors.black12,
              ),
              child: ClipOval(
                child: Image.network(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox(),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}
