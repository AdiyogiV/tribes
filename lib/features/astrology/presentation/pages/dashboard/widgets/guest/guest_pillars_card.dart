import 'package:flutter/material.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';
import 'package:aurogram/core/theme/dashboard_card_theme.dart';
import 'package:aurogram/features/astrology/presentation/pages/dashboard/widgets/guest/guest_atoms.dart';

/// The core pitch: A deeply editorial, abstract representation of the sciences.
/// Removes the literal "app feature" boxes and uses staggered typographic manifesto.
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
              text: 'THE UNIFIED SYSTEM', color: palette.fgMuted),
          const SizedBox(height: AppDimensions.spacingSm),
          Text(
            'A framework for living.',
            style: TextStyle(
              fontFamily: 'Georgia',
              fontStyle: FontStyle.italic,
              color: palette.fgMain,
              fontSize: 28,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 64),
          
          if (isWide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildEditorialBlock(
                  number: '01',
                  title: 'Alignment',
                  description: 'The celestial geometry of your birth, decoded. Map your elemental nature and understand the cosmic architecture that shapes you.',
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
                  description: 'The celestial geometry of your birth, decoded. Map your elemental nature and understand the cosmic architecture that shapes you.',
                  palette: palette,
                ),
                const SizedBox(height: 56),
                _buildEditorialBlock(
                  number: '02',
                  title: 'Rhythm',
                  description: 'Sacred timing and the movement of the luminaries. Move with the day’s energy, knowing exactly when to act and when to rest.',
                  palette: palette,
                ),
                const SizedBox(height: 56),
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
                fontSize: 18,
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
                      fontSize: 22,
                      fontWeight: FontWeight.w400,
                      color: palette.fgMain,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: AppTheme.babaTextSize,
                      height: 1.6,
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
// Companions (Baba + Circles)
// ─────────────────────────────────────────────────────────────────────────────

/// The "you're never alone" card: the AI guide + community.
class GuestCompanionsCard extends StatelessWidget {
  const GuestCompanionsCard(
      {super.key, required this.isDark, required this.isWide});

  final bool isDark;
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final palette = DashboardCardPalette.forBrightness(isDark);
    
    final baba = _buildCompanion(
      title: 'A Guided Practice',
      description: 'A voice-first intelligence that knows your chart, decodes the sky, and answers your deepest questions.',
      palette: palette,
    );
    
    final circles = _buildCompanion(
      title: 'Shared Journeys',
      description: 'A private space to see how the cosmos moves the people you care about, together.',
      palette: palette,
    );

    return DashboardCard(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          GuestEyebrow(
              text: 'THE EXPERIENCE', color: palette.fgMuted),
          const SizedBox(height: AppDimensions.spacingLg),
          if (isWide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: baba),
                Container(
                  width: 1,
                  height: 80,
                  color: palette.fgFaint.withValues(alpha: 0.2),
                  margin: const EdgeInsets.symmetric(horizontal: 48),
                ),
                Expanded(child: circles),
              ],
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                baba,
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Divider(
                    height: 1,
                    thickness: 1,
                    color: palette.fgFaint.withValues(alpha: 0.2),
                  ),
                ),
                circles,
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildCompanion({
    required String title,
    required String description,
    required DashboardCardPalette palette,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontFamily: 'Georgia',
            color: palette.fgMain,
            fontSize: 20,
            fontWeight: FontWeight.w400,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          description,
          style: TextStyle(
            color: palette.fgMuted,
            fontSize: AppTheme.babaTextSize,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}
