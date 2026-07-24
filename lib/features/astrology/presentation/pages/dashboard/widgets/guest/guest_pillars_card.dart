import 'package:flutter/material.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';
import 'package:aurogram/core/theme/dashboard_card_theme.dart';
import 'package:aurogram/features/astrology/presentation/pages/dashboard/widgets/guest/guest_atoms.dart';

// ─────────────────────────────────────────────────────────────────────────────
// The unified system
// ─────────────────────────────────────────────────────────────────────────────

class GuestPillarsCard extends StatelessWidget {
  const GuestPillarsCard({super.key, required this.isDark, required this.isWide});

  final bool isDark;
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final palette = DashboardCardPalette.forBrightness(isDark);
    
    return DashboardCard(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          GuestEyebrow(
              text: 'THE SCIENCES', color: palette.fgMuted),
          const SizedBox(height: AppDimensions.spacingSm),
          Text(
            'A geometry of the self.',
            style: TextStyle(
              fontFamily: 'Georgia',
              fontStyle: FontStyle.italic,
              color: palette.fgMain,
              fontSize: 26,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 56),
          
          if (isWide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildEditorialBlock(
                  number: '01',
                  title: 'The Blueprint',
                  description: 'The sky at your exact moment of origin. We decode your planetary geometry to reveal the latent forces shaping your narrative.',
                  palette: palette,
                )),
                const SizedBox(width: 48),
                Expanded(child: _buildEditorialBlock(
                  number: '02',
                  title: 'The Pulse',
                  description: 'Time is not merely measured, but felt. Sync with the lunar phases and solar transits to move effortlessly with the day\u2019s current.',
                  palette: palette,
                )),
                const SizedBox(width: 48),
                Expanded(child: _buildEditorialBlock(
                  number: '03',
                  title: 'The Equilibrium',
                  description: 'The ancient study of inner harmony. Discover your elemental constitution and cultivate a quiet resonance between mind and vessel.',
                  palette: palette,
                )),
              ],
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildEditorialBlock(
                  number: '01',
                  title: 'The Blueprint',
                  description: 'The sky at your exact moment of origin. We decode your planetary geometry to reveal the latent forces shaping your narrative.',
                  palette: palette,
                ),
                const SizedBox(height: 48),
                _buildEditorialBlock(
                  number: '02',
                  title: 'The Pulse',
                  description: 'Time is not merely measured, but felt. Sync with the lunar phases and solar transits to move effortlessly with the day\u2019s current.',
                  palette: palette,
                ),
                const SizedBox(height: 48),
                _buildEditorialBlock(
                  number: '03',
                  title: 'The Equilibrium',
                  description: 'The ancient study of inner harmony. Discover your elemental constitution and cultivate a quiet resonance between mind and vessel.',
                  palette: palette,
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildEditorialBlock({
    required String number,
    required String title,
    required String description,
    required DashboardCardPalette palette,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              number,
              style: TextStyle(
                fontFamily: 'Georgia',
                fontStyle: FontStyle.italic,
                fontSize: 16,
                color: palette.fgFaint,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'Georgia',
                      fontSize: 20,
                      fontWeight: FontWeight.w400,
                      color: palette.fgMain,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: AppTheme.babaTextSize - 1,
                      height: 1.5,
                      color: palette.fgMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// The Collective
// ─────────────────────────────────────────────────────────────────────────────

/// The social/animal motif card.
class GuestCollectiveCard extends StatelessWidget {
  const GuestCollectiveCard(
      {super.key, required this.isDark, required this.isWide});

  final bool isDark;
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final palette = DashboardCardPalette.forBrightness(isDark);

    return DashboardCard(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          GuestEyebrow(text: 'THE COLLECTIVE', color: palette.fgMuted),
          const SizedBox(height: AppDimensions.spacingLg),
          
          Text(
            'A constellation of seekers.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Georgia',
              color: palette.fgMain,
              fontSize: 24,
              fontStyle: FontStyle.italic,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: AppDimensions.spacingSm),
          Text(
            'Join over 150,000 members moving in sync with the cosmos.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: palette.fgMuted,
              fontSize: AppTheme.babaTextSize,
            ),
          ),
          const SizedBox(height: 48),

          // The Menagerie: A chic overlapping row of animal avatars
          SizedBox(
            height: 64,
            child: Center(
              child: _AnimalOverlapRow(),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimalOverlapRow extends StatelessWidget {
  const _AnimalOverlapRow();

  static const _animals = [
    'assets/yoni/tiger.webp',
    'assets/yoni/cobra.webp',
    'assets/yoni/elephant.webp',
    'assets/yoni/horse.webp',
    'assets/yoni/monkey.webp',
    'assets/yoni/peacock.webp',
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? const Color(0xFF1A1A1A) : Colors.white;

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        // Create an implicit width container for the stack
        SizedBox(width: (_animals.length * 40.0) + 24),
        ...List.generate(_animals.length, (index) {
          final leftOffset = index * 40.0;
          return Positioned(
            left: leftOffset,
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: borderColor,
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipOval(
                child: Image.asset(
                  _animals[index],
                  fit: BoxFit.cover,
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}
