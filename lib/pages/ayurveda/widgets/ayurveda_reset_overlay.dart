import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:flutter/material.dart';

class AyurvedaResetOverlay extends StatelessWidget {
  final bool isDark;

  const AyurvedaResetOverlay({super.key, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Container(
        color: isDark
            ? Colors.black.withValues(alpha: 0.7)
            : Colors.white.withValues(alpha: 0.7),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(AppTheme.primaryColor),
              ),
              const SizedBox(height: 16),
              Text(
                'Resetting Ayurveda profile...',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
