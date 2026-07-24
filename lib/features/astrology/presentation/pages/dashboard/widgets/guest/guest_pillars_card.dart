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
              text: 'THE FRAMEWORK', color: palette.fgMuted),
          const SizedBox(height: AppDimensions.spacingSm),
          Text(
            'Alignment, rhythm, and balance.',
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
                  title: 'Alignment',
                  description: 'The celestial geometry of your birth, decoded. Map your elemental nature and understand the architecture that shapes you.',
                  palette: palette,
                )),
                const SizedBox(width: 48),
                Expanded(child: _buildEditorialBlock(
                  number: '02',
                  title: 'Rhythm',
                  description: 'Sacred timing and the movement of the luminaries. Move with the day’s energy, knowing exactly when to act and when to rest.',
                  palette: palette,
                )),
                const SizedBox(width: 48),
                Expanded(child: _buildEditorialBlock(
                  number: '03',
                  title: 'Balance',
                  description: 'Harmonize your inner constitution. A daily practice bridging mind and body through the timeless lens of Ayurveda.',
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
                  title: 'Alignment',
                  description: 'The celestial geometry of your birth, decoded. Map your elemental nature and understand the architecture that shapes you.',
                  palette: palette,
                ),
                const SizedBox(height: 48),
                _buildEditorialBlock(
                  number: '02',
                  title: 'Rhythm',
                  description: 'Sacred timing and the movement of the luminaries. Move with the day’s energy, knowing exactly when to act and when to rest.',
                  palette: palette,
                ),
                const SizedBox(height: 48),
                _buildEditorialBlock(
                  number: '03',
                  title: 'Balance',
                  description: 'Harmonize your inner constitution. A daily practice bridging mind and body through the timeless lens of Ayurveda.',
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
            'A living network of seekers navigating their day.',
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
            'Join over thousands exploring their cosmic nature.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: palette.fgMuted,
              fontSize: AppTheme.babaTextSize,
            ),
          ),
          const SizedBox(height: 48),

          // The Menagerie: A chic, spaced typographic list of spirit animals
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 24,
            runSpacing: 24,
            children: const [
              _AnimalNode(label: 'TIGER'),
              _DotNode(),
              _AnimalNode(label: 'SERPENT'),
              _DotNode(),
              _AnimalNode(label: 'ELEPHANT'),
              _DotNode(),
              _AnimalNode(label: 'HORSE'),
              _DotNode(),
              _AnimalNode(label: 'MONKEY'),
            ],
          ),
        ],
      ),
    );
  }
}

class _AnimalNode extends StatelessWidget {
  final String label;
  const _AnimalNode({required this.label});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? Colors.white70 : Colors.black87;
    return Text(
      label,
      style: TextStyle(
        color: fg,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 3.0,
      ),
    );
  }
}

class _DotNode extends StatelessWidget {
  const _DotNode();
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 4,
      height: 4,
      decoration: BoxDecoration(
        color: isDark ? Colors.white24 : Colors.black26,
        shape: BoxShape.circle,
      ),
    );
  }
}
