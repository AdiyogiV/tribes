import 'package:flutter/material.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';
import 'package:aurogram/core/theme/dashboard_card_theme.dart';
import 'package:aurogram/features/astrology/presentation/pages/dashboard/widgets/guest/guest_atoms.dart';

/// Pure typographic social proof layered with the beautiful Yoni animal avatars.
class GuestCollectiveCard extends StatelessWidget {
  const GuestCollectiveCard({super.key, required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final palette = DashboardCardPalette.forBrightness(isDark);

    return DashboardCard(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 56),
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
              fontSize: 32,
              fontWeight: FontWeight.w400,
              fontStyle: FontStyle.italic,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: AppDimensions.spacingMd),
          
          Text(
            'Join over 150,000 members moving in sync with the cosmos.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: palette.fgMuted,
              fontSize: AppTheme.babaTextSize,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 48),

          // The Menagerie: A chic overlapping row of animal avatars
          const SizedBox(
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
    'tiger', 'cobra', 'elephant', 'horse', 'monkey', 
    'peacock', 'lion', 'panther', 'eagle', 'wolf', 'ram', 'bull'
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? const Color(0xFF14141A) : Colors.white;

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: -16, // overlap
      runSpacing: 16,
      children: List.generate(_animals.length, (index) {
        final animal = _animals[index];
        final url = 'https://firebasestorage.googleapis.com/v0/b/ty-dev-516d7.appspot.com/o/yoni_tribes%2F$animal.webp?alt=media';
        
        return Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: borderColor,
              width: 2.5,
            ),
            color: isDark ? Colors.white10 : Colors.black12,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ClipOval(
            child: Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox(),
            ),
          ),
        );
      }),
    );
  }
}
