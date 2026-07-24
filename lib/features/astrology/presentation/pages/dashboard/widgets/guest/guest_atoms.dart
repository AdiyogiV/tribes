import 'package:flutter/material.dart';
import 'package:aurogram/core/theme/app_theme.dart';
import 'package:aurogram/core/theme/dashboard_card_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Palette
// ─────────────────────────────────────────────────────────────────────────────

const Color kGuestSaffron = Color(0xFFE2571E);
const Color kGuestHaldi = Color(0xFFD99A00);
Color get kGuestJyotish => AppTheme.cosmicPurple;
Color get kGuestAyurveda => AppTheme.emeraldGreen;
Color get kGuestCircles => AppTheme.skyBlue;

// ─────────────────────────────────────────────────────────────────────────────
// Small atoms
// ─────────────────────────────────────────────────────────────────────────────

class GuestEyebrow extends StatelessWidget {
  const GuestEyebrow({super.key, required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: color,
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 3.0,
      ),
    );
  }
}

class GuestPrimaryCta extends StatelessWidget {
  const GuestPrimaryCta({
    super.key,
    required this.label,
    required this.icon,
    required this.isDark,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = DashboardCardPalette.forBrightness(isDark);
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(100),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 36),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: palette.fgMain.withValues(alpha: 0.2),
            width: 1.0,
          ),
          color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label.toUpperCase(),
              style: TextStyle(
                color: palette.fgMain,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 2.0,
              ),
            ),
            const SizedBox(width: 16),
            Icon(icon, size: 16, color: palette.fgMain),
          ],
        ),
      ),
    );
  }
}
