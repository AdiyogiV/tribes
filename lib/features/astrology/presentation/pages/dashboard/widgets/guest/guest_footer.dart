import 'package:flutter/material.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';
import 'package:aurogram/features/astrology/presentation/pages/dashboard/widgets/guest/guest_atoms.dart';

/// Closing footer for the guest page: a refined, minimal imprint.
class GuestMadeInIndiaFooter extends StatelessWidget {
  const GuestMadeInIndiaFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? Colors.white54 : Colors.black54;

    return Padding(
      padding: const EdgeInsets.only(top: AppDimensions.spacingXl, bottom: AppDimensions.spacingXxl),
      child: Column(
        children: [
          Text(
            'PRIVATE  ·  FREE TO START  ·  AUTHENTIC VEDIC',
            style: TextStyle(
              color: muted,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 2.0,
            ),
          ),
          const SizedBox(height: AppDimensions.spacingLg),
          
          // An ultra-minimal tricolor dot sequence instead of a bar
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _Dot(color: const Color(0xFFFF9933)), // saffron
              const SizedBox(width: 6),
              _Dot(color: muted.withValues(alpha: 0.3)), // center (white/grey)
              const SizedBox(width: 6),
              _Dot(color: const Color(0xFF138808)), // green
            ],
          ),
          
          const SizedBox(height: AppDimensions.spacingLg),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Made with ',
                style: TextStyle(
                  color: muted, 
                  fontFamily: 'Georgia',
                  fontStyle: FontStyle.italic,
                  fontSize: 14,
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(Icons.favorite, size: 14, color: kGuestSaffron),
              ),
              Text(
                ' in India',
                style: TextStyle(
                  color: muted, 
                  fontFamily: 'Georgia',
                  fontStyle: FontStyle.italic,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final Color color;
  const _Dot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 4,
      height: 4,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}
