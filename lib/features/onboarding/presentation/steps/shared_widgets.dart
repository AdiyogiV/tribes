import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:aurogram/core/theme/app_theme.dart';

/// Ultra-minimalist, sharp editorial continue button
class ContinueButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const ContinueButton({
    super.key,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = AppTheme.primaryColor;
    final textColor = isDark ? Colors.black : Colors.white;

    return Focus(
      autofocus: false,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.numpadEnter)) {
          HapticFeedback.lightImpact();
          onTap();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.zero, // Sharp, brutalist edge
          ),
          child: Text(
            label.toUpperCase(),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: textColor,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 2.0,
            ),
          ),
        ),
      ),
    );
  }
}

/// Minimalist text-only share link
class ShareLink extends StatelessWidget {
  final VoidCallback onTap;

  const ShareLink({
    super.key,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(
          'SHARE BLUEPRINT',
          style: TextStyle(
            color: AppTheme.primaryColor,
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.5,
            decoration: TextDecoration.underline,
          ),
        ),
      ),
    );
  }
}

/// Stark, minimal path button
class PathButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const PathButton({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              width: 1,
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'serif',
                      fontSize: 20,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: AppTheme.primaryColor.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_rounded,
              color: AppTheme.primaryColor.withValues(alpha: 0.3),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
