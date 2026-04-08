import 'package:flutter/material.dart';
import 'package:aurogram/utils/theme/app_theme.dart';
import 'package:aurogram/pages/onboarding/onboarding_constants.dart';
import 'package:aurogram/pages/onboarding/widgets/zodiac_wheel_painter.dart';
import 'package:aurogram/utils/theme/app_dimensions.dart';

class LoadingPhase extends StatelessWidget {
  final String loadingMessage;
  final Map<String, double>? planetPositions;

  const LoadingPhase({
    super.key,
    required this.loadingMessage,
    this.planetPositions,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Rotating zodiac wheel with icon in center
            LayoutBuilder(
              builder: (context, constraints) {
                // Calculate wheel size based on available space
                final maxSize = constraints.maxWidth < constraints.maxHeight
                    ? constraints.maxWidth
                    : constraints.maxHeight;
                final wheelSize = (maxSize * 0.6).clamp(200.0, 400.0);

                return ZodiacWheelWithIcon(
                  wheelSize: wheelSize,
                  planetPositions: planetPositions,
                  primaryColor: AppTheme.primaryColor,
                  opacity: 0.4,
                  animate: true,
                );
              },
            ),
            const SizedBox(height: AppDimensions.spacingLargeSection),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              child: Text(
                loadingMessage,
                key: ValueKey(loadingMessage),
                style: TextStyle(
                  fontSize: 16,
                  color: OnboardingColors.textSecondary(context),
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.2,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
