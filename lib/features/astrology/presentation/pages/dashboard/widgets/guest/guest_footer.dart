import 'package:flutter/material.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/core/theme/app_dimensions.dart';
import 'package:aurogram/features/astrology/presentation/pages/dashboard/widgets/guest/guest_atoms.dart';

/// Closing footer for the guest page: a row of trust cues, a slim tricolour
/// rule and a "Made with (heart) in India" line.
class GuestMadeInIndiaFooter extends StatelessWidget {
  const GuestMadeInIndiaFooter({super.key});

  static const _cues = <(IconData, String)>[
    (Icons.verified_outlined, 'Authentic Vedic'),
    (Icons.lock_outline_rounded, 'Private'),
    (Icons.bolt_outlined, 'Free to start'),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? Colors.white54 : Colors.black54;
    final faint = isDark ? Colors.white38 : Colors.black38;

    return Column(
      children: [
        Wrap(
          alignment: WrapAlignment.center,
          spacing: AppDimensions.spacingXl,
          runSpacing: AppDimensions.spacingSm,
          children: [
            for (final (icon, label) in _cues)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 15, color: muted),
                  const SizedBox(width: AppDimensions.spacingSm),
                  Text(
                    label,
                    style: TextStyle(
                      color: muted,
                      fontSize: AppTheme.babaTextSize - 2,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: AppDimensions.spacingXl),
        // A slim tricolour rule — a quiet nod to the flag.
        Container(
          width: 54,
          height: 3,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDimensions.radiusFull),
            gradient: const LinearGradient(
              colors: [
                Color(0xFFFF9933), // saffron
                Color(0xFFEFEFEF), // white
                Color(0xFF138808), // green
              ],
            ),
          ),
        ),
        const SizedBox(height: AppDimensions.spacingMd),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.max,
          children: [
            Text(
              'Made with ',
              style:
                  TextStyle(color: faint, fontSize: AppTheme.babaTextSize - 1),
            ),
            const Icon(Icons.favorite, size: 13, color: kGuestSaffron),
            Text(
              ' in India',
              style:
                  TextStyle(color: faint, fontSize: AppTheme.babaTextSize - 1),
            ),
          ],
        ),
      ],
    );
  }
}
